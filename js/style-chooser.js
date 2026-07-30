/******************************************************************************/
/*                                                                            */
/* style-chooser.js -- Client-side Rexx highlight style chooser               */
/* ============================================================               */
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
/* 20260730    0.6  Adopted into the Rexx Parser; storage key renamed.        */
/* 20260730         Merged chooser.js: ?style= layer and print button.        */
/*                                                                            */
/* Stylesheets are lazy-loaded: every rexx-<style>.css link but the default   */
/* ships with media="not all", so the browser does not fetch it until the     */
/* reader picks that style. Once fetched it stays in the browser cache.       */
/*                                                                            */
/******************************************************************************/

(function () {
  "use strict";

  /* The URL carries the style only when it differs from the page's default, */
  /* so an ordinary URL stays clean and shareable: what you send someone is  */
  /* the document, not your personal colour scheme. Once it does carry a     */
  /* style it keeps telling the truth, because every change rewrites it.     */
  function setStyleParam(url, style, defaultStyle) {
    if (style === "" || style === defaultStyle) url.searchParams.delete("style");
    else url.searchParams.set("style", style);
  }

  document.addEventListener("DOMContentLoaded", function () {
    var chooser = document.getElementById("rexx-style-chooser");

    /* The page default is whatever the generator rendered. It supplies it   */
    /* explicitly when it can; falling back to the selected option is        */
    /* best-effort, and wrong on a page reached through ?style=, where the   */
    /* generator marks the URL's style as selected.                          */
    var defaultStyle = chooser
      ? chooser.getAttribute("data-rexx-default-style") || chooser.value
      : "";

    /* Print is a server round-trip: the PDF is rendered by the CGI, not in  */
    /* the browser. So whatever style the reader is looking at has to travel */
    /* in the URL, or the PDF comes back in the page default instead. This   */
    /* is why the button belongs here and not in a file of its own -- it is  */
    /* the one thing that has to serialise the chooser's live state.         */
    /* Wired before the guards below: a page with no code still prints.      */
    var printButton = document.getElementById("print-button");
    if (printButton) {
      printButton.addEventListener("click", function () {
        var url = new URL(window.location.href);
        if (chooser) setStyleParam(url, chooser.value, defaultStyle);
        url.searchParams.set("print", "pdf");
        window.location.href = url.toString();
      });
    }

    if (!chooser) return;

    /* The chooser only means anything if the page actually has highlighted    */
    /* Rexx blocks to restyle. Without the Parser (or on a page with no code   */
    /* at all) there are none, so the bar ships hidden and we reveal it here   */
    /* only when there is something to act on. Revealing (rather than hiding)  */
    /* avoids a flash of an empty control on code-less pages.                  */
    var hasBlocks = document.querySelector('[class*="highlight-rexx-"]') !== null;
    if (!hasBlocks) return;

    var bar = chooser.closest(".code-style-bar");
    if (bar) bar.hidden = false;

    /* Activate a lazily-linked stylesheet by clearing its media guard.       */
    /* The <link> carries data-rexx-style="<name>"; flipping media to "all"   */
    /* is what triggers the actual network fetch (once; cached thereafter).   */
    function activateSheet(style) {
      var link = document.querySelector(
        'link[data-rexx-style="' + style + '"]'
      );
      if (link && link.media !== "all") link.media = "all";
    }

    /* Relabel the outer div on every free block on the page. Blocks the      */
    /* author pinned to a style (marked data-rexx-style-locked by the          */
    /* highlighter) are left untouched, so their colours stay put.             */
    function relabel(style) {
      var blocks = document.querySelectorAll(
        '[class*="highlight-rexx-"]:not([data-rexx-style-locked])'
      );
      for (var i = 0; i < blocks.length; i++) {
        blocks[i].className = blocks[i].className.replace(
          /highlight-rexx-[A-Za-z0-9._-]+/g,
          "highlight-rexx-" + style
        );
      }
    }

    function apply(style) {
      activateSheet(style);
      relabel(style);
    }

    /* Persist the choice so it survives reloads and navigation, and apply     */
    /* it explicitly on every load. A page always arrives rendered in          */
    /* whatever style its generator chose -- a server default, YAML front      */
    /* matter, or the DocBook toolchain's -- which need not be the reader's,   */
    /* so the stored preference has to be reasserted, never assumed.           */
    var STORAGE_KEY = "rexx-parser.codeStyle";

    function savedStyle() {
      try {
        return window.localStorage.getItem(STORAGE_KEY);
      } catch (e) {
        return null; /* storage disabled (private mode, etc.) — no persistence */
      }
    }

    function saveStyle(style) {
      try {
        window.localStorage.setItem(STORAGE_KEY, style);
      } catch (e) {
        /* ignore: persistence is best-effort */
      }
    }

    chooser.addEventListener("change", function () {
      saveStyle(chooser.value);
      apply(chooser.value);
      /* Keep the URL in step, but with replaceState: this is the whole    */
      /* point of the merge. The old chooser reached the same URL by       */
      /* navigating to it, which made the server re-highlight the whole    */
      /* document to change one class name.                                */
      try {
        var url = new URL(window.location.href);
        setStyleParam(url, chooser.value, defaultStyle);
        window.history.replaceState(null, "", url.toString());
      } catch (e) {
        /* ignore: the style is applied either way, the URL is a courtesy */
      }
    });

    /* Activate the stylesheets that author-locked blocks depend on. These      */
    /* blocks keep their own highlight-rexx-<style> class, but that class only   */
    /* paints if the matching (lazily-linked) sheet is active. The dropdown      */
    /* never selects these styles, so nothing else would switch them on.         */
    function activateLockedSheets() {
      var locked = document.querySelectorAll("[data-rexx-style-locked]");
      for (var i = 0; i < locked.length; i++) {
        var m = locked[i].className.match(/highlight-rexx-([A-Za-z0-9._-]+)/);
        if (m) activateSheet(m[1]);
      }
    }

    /* Only styles this page actually offers are honoured, whatever their    */
    /* source: a stale stored value or a hand-edited URL must not leave the  */
    /* page labelled for a sheet that was never linked.                      */
    function isOffered(style) {
      if (!style) return false;
      return chooser.querySelector('option[value="' + style + '"]') !== null;
    }

    /* Precedence on load: ?style= beats the stored preference, because      */
    /* following such a link is a deliberate act aimed at this page; the     */
    /* stored preference beats the page default, because it is the reader's  */
    /* standing choice and the default is only a suggestion. Blocks the      */
    /* author pinned outrank all of it, and relabel() never touches them.    */
    /*                                                                       */
    /* A ?style= link is a view, not a new setting, so it is deliberately    */
    /* NOT written to storage: a link someone sent you should not quietly    */
    /* rewrite what you chose for yourself.                                  */
    var urlStyle = null;
    try {
      urlStyle = new URL(window.location.href).searchParams.get("style");
    } catch (e) {
      urlStyle = null; /* no URL API -- fall through to the stored value */
    }

    var initial = urlStyle;
    if (!isOffered(initial)) initial = savedStyle();
    if (!isOffered(initial)) initial = defaultStyle;
    if (!isOffered(initial)) initial = chooser.value;
    chooser.value = initial;
    apply(initial);
    activateLockedSheets();
  });
})();
