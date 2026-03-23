/******************************************************************************/
/*                                                                            */
/* numberSections.js - Inject section numbers for paged.js documents          */
/* =================================================================          */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>       */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260309    0.5  First version.  Works around paged.js CSS counter issues. */
/* 20260310         Number chapters (arabic) and parts (Roman), as in LaTeX.  */
/* 20260322         data-chapter support: prefix section numbers with "N.",    */
/*                  skip h1 (chapter title), number h2..h4 as sections.       */
/*                                                                            */
/******************************************************************************/

/*
  Purpose:

  CSS counters (counter-reset, counter-increment) do not work reliably
  with paged.js because the polyfill intercepts them and replaces them
  with its own JavaScript-based mechanism, which fails for user-defined
  counters in fragmented content.

  This script solves the problem by:

  1. Detecting the section-numbers-N class on div.content.
  2. Walking all headings and computing the numbers in JavaScript.
  3. Injecting the numbers as <span class="section-number"> elements
     into the heading text, BEFORE paged.js paginates.
  4. Removing the CSS counter-reset and counter-increment declarations
     from the stylesheet so that they do not conflict.

  The ::before rules in the CSS (content: counter(...)) are also
  neutralized: this script adds a class "sections-numbered" to
  div.content, and the CSS should include a rule that suppresses
  the ::before content when that class is present.  Alternatively,
  this script removes the ::before content rules directly.

  Numbering follows the LaTeX book convention:

  - Parts are numbered with uppercase Roman numerals ("Part I",
    "Part II", etc.).  Parts do not affect the chapter counter.
  - Chapters are numbered with Arabic numerals ("1.", "2.", etc.).
    Sections within a chapter are numbered as "1.1.", "1.2.", etc.
  - Headings with .unnumbered, or inside .title-page, .toc-exclude,
    or .abstract containers, are skipped entirely.

  Chapter mode (rexxdoc-chapter):

  When div.content has a data-chapter="N" attribute, the script enters
  chapter mode:

  - h1 is treated as the chapter title and is NOT numbered.
  - h2..h4 are numbered with "N." as a prefix: h2 → "N.1.", "N.2.",
    h3 → "N.1.1.", h4 → "N.1.1.1.", etc.
  - The heading levels are effectively shifted by 1 (h2 counts as
    level 1, h3 as level 2, h4 as level 3).

  Dual-mode operation (same pattern as createToc.js):

  - If Paged is available (Print pipeline), the numbering is done
    via a beforeParsed handler.

  - If Paged is not available (Render pipeline via pagedjs-cli),
    the numbering is done immediately as an IIFE.
*/

(function() {

  /* -----------------------------------------------------------------------*/
  /* toRoman — convert an integer to uppercase Roman numerals               */
  /* -----------------------------------------------------------------------*/

  function toRoman(n) {
    var lookup = [
      [1000, "M"], [900, "CM"], [500, "D"], [400, "CD"],
      [100, "C"],  [90, "XC"],  [50, "L"],  [40, "XL"],
      [10, "X"],   [9, "IX"],   [5, "V"],   [4, "IV"],
      [1, "I"]
    ];
    var result = "";
    for (var i = 0; i < lookup.length; i++) {
      while (n >= lookup[i][0]) {
        result += lookup[i][1];
        n -= lookup[i][0];
      }
    }
    return result;
  }

  /* -----------------------------------------------------------------------*/
  /* partLabel — "Part" in the document language                           */
  /* -----------------------------------------------------------------------*/

  function partLabel(content) {
    var root = content.documentElement
            || (content.ownerDocument && content.ownerDocument.documentElement)
            || document.documentElement;
    var lang = (root && root.getAttribute("lang")) || "en";
    lang = lang.toLowerCase().substring(0, 2);
    var labels = {
      "en": "Part",   "es": "Parte",  "fr": "Partie",
      "de": "Teil",   "it": "Parte",  "pt": "Parte",
      "nl": "Deel",   "ca": "Part",   "gl": "Parte"
    };
    return labels[lang] || "Part";
  }

  /* -----------------------------------------------------------------------*/
  /* numberSections — the core logic                                        */
  /* -----------------------------------------------------------------------*/

  function numberSections(content) {

    /* Determine the localized label for parts                              */
    var partWord = partLabel(content);

    /* Find div.content with a section-numbers-N class                      */
    var container = content.querySelector(
      "div.content[class*='section-numbers-']"
    );
    if (!container) return;

    /* Determine the maximum depth from the class name                      */
    var maxDepth = 0;
    var match = container.className.match(/section-numbers-(\d)/);
    if (match) maxDepth = parseInt(match[1], 10);
    if (maxDepth < 1 || maxDepth > 4) return;

    /* Chapter prefix for rexxdoc-chapter: data-chapter="N" on div.content  */
    /* When present, all section numbers are prefixed with "N." so that    */
    /* h1 numbers become "N.1.", "N.2.", h2 becomes "N.1.1.", etc.         */
    var chapterPrefix = "";
    if (container.dataset.chapter) {
      chapterPrefix = container.dataset.chapter + ".";
    }

    /* Counters                                                             */
    var partCounter = 0;
    var counters = [0, 0, 0, 0];  /* h1, h2, h3, h4                        */

    /* Headings to skip entirely (no counting, no numbering)                */
    function isExcluded(heading) {
      if (heading.classList.contains("unnumbered")) return true;
      if (heading.closest(".title-page"))           return true;
      if (heading.closest(".toc-exclude"))          return true;
      if (heading.closest(".abstract"))             return true;
      return false;
    }

    /* Build a selector for all headings up to maxDepth                     */
    var tags = [];
    for (var d = 1; d <= maxDepth; d++) tags.push("h" + d);
    /* Also include deeper headings so we can skip them correctly           */
    var allTags = ["h1", "h2", "h3", "h4"];
    var headings = container.querySelectorAll(allTags.join(", "));

    for (var i = 0; i < headings.length; i++) {
      var h = headings[i];
      var level = parseInt(h.tagName.charAt(1), 10);  /* 1..4              */

      if (isExcluded(h)) continue;

      /* Parts: separate counter, Roman numerals, no effect on chapters    */
      if (h.classList.contains("part")) {
        partCounter++;
        var partSpan = document.createElement("span");
        partSpan.className = "section-number";
        partSpan.textContent = partWord + "\u00A0" + toRoman(partCounter);
        /* Hidden separator: included in textContent for the TOC,         */
        /* but hidden on the part page via CSS                            */
        var sep = document.createElement("span");
        sep.className = "section-number-sep";
        sep.textContent = ".\u2003";
        partSpan.appendChild(sep);
        h.insertBefore(partSpan, h.firstChild);
        continue;
      }

      /* Chapters: increment h1 counter, reset deeper levels               */
      if (h.classList.contains("chapter")) {
        counters[0]++;
        for (var r = 1; r < 4; r++) counters[r] = 0;
        /* Number the chapter heading itself                               */
        if (maxDepth >= 1) {
          var chapStr = counters[0] + ".\u2003";
          var chapSpan = document.createElement("span");
          chapSpan.className = "section-number";
          chapSpan.textContent = chapStr;
          h.insertBefore(chapSpan, h.firstChild);
        }
        continue;
      }

      /* Regular headings                                                   */

      /* With data-chapter, h1 is the chapter title (skip it), and           */
      /* h2..h4 are numbered as if they were h1..h3, prefixed with           */
      /* the chapter number.  Without data-chapter, the standard             */
      /* h1..h4 numbering applies.                                           */

      var effectiveLevel = chapterPrefix ? level - 1 : level;

      /* Skip h1 when in chapter mode (it is the chapter title)              */
      if (chapterPrefix && level === 1) continue;

      /* Skip headings below h2 (effectiveLevel < 1) — should not happen    */
      if (effectiveLevel < 1) continue;

      /* Increment the counter for this level, reset deeper levels          */
      counters[effectiveLevel - 1]++;
      for (var r = effectiveLevel; r < 4; r++) counters[r] = 0;

      /* Only number up to maxDepth                                         */
      if (effectiveLevel > maxDepth) continue;

      /* Build the number string: "1.", "2.3.", "2.3.1.", "2.3.1.4."       */
      /* With chapterPrefix: "1.1.", "1.2.3.", "1.2.3.1.", etc.            */
      var parts = [];
      for (var p = 0; p < effectiveLevel; p++) parts.push(counters[p]);
      var numberStr = chapterPrefix + parts.join(".") + ".\u2003";
      /* \u2003 is an em-space, matching the original CSS                   */

      /* Inject a <span> at the beginning of the heading                    */
      var span = document.createElement("span");
      span.className = "section-number";
      span.textContent = numberStr;
      h.insertBefore(span, h.firstChild);
    }

    /* Mark the container so CSS can suppress ::before content              */
    container.classList.add("sections-numbered");
  }

  /* -----------------------------------------------------------------------*/
  /* Mode selection                                                         */
  /* -----------------------------------------------------------------------*/

  if (typeof Paged !== "undefined") {

    /* Print pipeline — register a paged.js handler                        */

    class SectionNumberHandler extends Paged.Handler {
      constructor(chunker, polisher, caller) {
        super(chunker, polisher, caller);
      }
      beforeParsed(content) {
        numberSections(content);
      }
    }

    Paged.registerHandlers(SectionNumberHandler);

  } else {

    /* Render pipeline — number sections immediately                       */

    numberSections(document);

  }

})();