/******************************************************************************/
/*                                                                            */
/* createToc.js - Generate a Table of Contents for paged.js documents         */
/* ===================================================================        */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260304    0.5  First version.  Based on the paged.js TOC plugin.         */
/*                                                                            */
/******************************************************************************/

/*
  Usage:

  1. Place a <div id="toc"></div> in your HTML where the TOC should appear.
     In Markdown, use a fenced div:

       ::: {#toc .toc-exclude}
       ## Contents {.toc-exclude}
       :::

  2. Load this script after paged.polyfill.js (Print pipeline), or embed
     it inline in the HTML (as md2pdf does automatically for the Render
     pipeline).

  3. The CSS for TOC entries uses target-counter() for page numbers:

       .toc-entry a::after {
         content: target-counter(attr(href url), page);
       }

  Headings with the class "toc-exclude" (or inside a parent with that
  class) are excluded from the TOC.  The title-page and closing-page
  are automatically excluded.

  Dual-mode operation:

  - If Paged is available (Print pipeline in the browser), the TOC is
    built via a Paged.Handler hook (beforeParsed), which runs before
    paged.js paginates the document.

  - If Paged is not available (Render pipeline via pagedjs-cli), the
    TOC is built immediately as an IIFE.  The script must be placed
    at the end of the body so that the DOM is complete.  pagedjs-cli
    will then paginate the document including the generated TOC.
*/

(function() {

  /* -----------------------------------------------------------------------*/
  /* buildToc — the core logic, shared by both modes                        */
  /* -----------------------------------------------------------------------*/

  function buildToc(content) {

    var tocContainer = content.querySelector("#toc");
    if (!tocContainer) return;

    var nav = document.createElement("nav");
    nav.className = "toc-nav";
    tocContainer.appendChild(nav);

    /* Select headings to include — h1 through h3 by default               */
    var headings = content.querySelectorAll("h1, h2, h3");

    for (var i = 0; i < headings.length; i++) {
      var heading = headings[i];

      /* Skip excluded headings                                            */
      if (heading.classList.contains("toc-exclude"))          continue;
      if (heading.closest(".toc-exclude"))                    continue;
      if (heading.closest(".title-page"))                     continue;
      if (heading.closest(".closing-page"))                   continue;

      /* Ensure the heading has an id for linking                          */
      if (!heading.id) {
        heading.id = "toc-h-" +
          heading.textContent.trim()
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, "-")
            .replace(/(^-|-$)/g, "");
      }

      /* Determine indentation level                                       */
      var tag   = heading.tagName;
      var level = "toc-level-1";
      if (tag === "H2") level = "toc-level-2";
      if (tag === "H3") level = "toc-level-3";

      /* Build the TOC entry                                               */
      var entry = document.createElement("div");
      entry.className = "toc-entry " + level;

      var link = document.createElement("a");
      link.href = "#" + heading.id;
      link.textContent = heading.textContent;

      entry.appendChild(link);
      nav.appendChild(entry);
    }
  }

  /* -----------------------------------------------------------------------*/
  /* Mode selection                                                         */
  /* -----------------------------------------------------------------------*/

  if (typeof Paged !== "undefined") {

    /* Print pipeline — register a paged.js handler                        */

    class TocHandler extends Paged.Handler {
      constructor(chunker, polisher, caller) {
        super(chunker, polisher, caller);
      }
      beforeParsed(content) {
        buildToc(content);
      }
    }

    Paged.registerHandlers(TocHandler);

  } else {

    /* Render pipeline — build the TOC immediately                         */

    buildToc(document);

  }

})();
