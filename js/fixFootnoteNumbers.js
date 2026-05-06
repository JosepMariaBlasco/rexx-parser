/******************************************************************************/
/*                                                                            */
/* fixFootnoteNumbers.js - Continuous footnote numbering for paged.js         */
/* ==================================================================        */
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
/* 20260409    0.5  First version.                                            */
/*                                                                            */
/******************************************************************************/

/*
  Purpose:

  Paged.js resets the footnote counter on every page, following the
  CSS Paged Media default (footnotes numbered per page).  This script
  renumbers all footnote calls (superscripts in the body text) and
  footnote markers (numbers at the bottom of each page) sequentially
  across the entire document after paged.js has finished rendering.

  It uses the same dual-mode pattern as createToc.js, numberSections.js,
  and numberFigures.js:

  - If Paged is available (Print pipeline), the renumbering is done
    via an afterRendered handler, which runs after paged.js has
    finished paginating.

  - If Paged is not available (Render pipeline via pagedjs-cli), the
    script does nothing — pagedjs-cli already produces correct
    continuous numbering.

  Load this script AFTER paged.polyfill.js:

    <script src='/js/paged.polyfill.js'></script>
    <script src='/rexx-parser/js/fixFootnoteNumbers.js'></script>
*/

(function() {

  /* -----------------------------------------------------------------------*/
  /* fixFootnoteNumbers — the core logic                                    */
  /* -----------------------------------------------------------------------*/

  function fixFootnoteNumbers() {

    /* Renumber footnote calls (superscripts in the body text)              */
    var calls = document.querySelectorAll("[data-footnote-call]");
    for (var i = 0; i < calls.length; i++) {
      calls[i].dataset.footnoteNumber = i + 1;
    }

    /* Renumber footnote markers (numbers at the bottom of each page)       */
    var markers = document.querySelectorAll(
      "[data-footnote-marker]:not([data-split-from])"
    );
    for (var j = 0; j < markers.length; j++) {
      markers[j].dataset.footnoteNumber = j + 1;
    }

    /* Inject a stylesheet that uses the data attribute for numbering       */
    var style = document.createElement("style");
    style.textContent =
      "[data-footnote-call]::after " +
        "{ content: attr(data-footnote-number) !important; }\n" +
      "[data-footnote-marker]::marker " +
        "{ content: attr(data-footnote-number) \". \" !important; }\n";
    document.head.appendChild(style);
  }

  /* -----------------------------------------------------------------------*/
  /* Mode selection                                                         */
  /* -----------------------------------------------------------------------*/

  if (typeof Paged !== "undefined") {

    /* Print pipeline — register a paged.js handler                        */

    class FootnoteFixHandler extends Paged.Handler {
      constructor(chunker, polisher, caller) {
        super(chunker, polisher, caller);
      }
      afterRendered(pages) {
        fixFootnoteNumbers();
      }
    }

    Paged.registerHandlers(FootnoteFixHandler);

  }

  /* Render pipeline — do nothing (pagedjs-cli numbers correctly)          */

})();