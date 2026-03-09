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

  Dual-mode operation (same pattern as createToc.js):

  - If Paged is available (Print pipeline), the numbering is done
    via a beforeParsed handler.

  - If Paged is not available (Render pipeline via pagedjs-cli),
    the numbering is done immediately as an IIFE.
*/

(function() {

  /* -----------------------------------------------------------------------*/
  /* numberSections — the core logic                                        */
  /* -----------------------------------------------------------------------*/

  function numberSections(content) {

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

    /* Counters                                                             */
    var counters = [0, 0, 0, 0];  /* h1, h2, h3, h4                        */

    /* Selectors for headings to exclude                                    */
    function isExcluded(heading) {
      if (heading.classList.contains("unnumbered")) return true;
      if (heading.classList.contains("part"))       return true;
      if (heading.classList.contains("chapter"))    return true;
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

      /* Increment the counter for this level, reset deeper levels          */
      counters[level - 1]++;
      for (var r = level; r < 4; r++) counters[r] = 0;

      /* Only number up to maxDepth                                         */
      if (level > maxDepth) continue;

      /* Build the number string: "1.", "2.3", "2.3.1", "2.3.1.4"          */
      var parts = [];
      for (var p = 0; p < level; p++) parts.push(counters[p]);
      var numberStr = parts.join(".") + ".\u2003";
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