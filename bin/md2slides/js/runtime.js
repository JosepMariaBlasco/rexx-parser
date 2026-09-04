/******************************************************************************/
/*                                                                            */
/*  deck-runtime.js -- Presentation deck runtime                              */
/*                                                                            */
/*  Adds to a RexxPub-generated document the things the scrolling HTML output  */
/*  does not have: viewport pagination, key/click navigation, stepped reveal   */
/*  of fragments, an any-page jump overlay, screen blanking, and optional      */
/*  time-driven animation.                                                     */
/*                                                                            */
/*  No dependencies. Runs from file:// with no server.                        */
/*                                                                            */
/*  Navigation model: a "step" is either advancing to the next unrevealed      */
/*  fragment on the current slide, or moving to the next slide when there      */
/*  are none left. Backwards is the exact inverse, so the deck is fully        */
/*  reversible -- you can walk back through a build the way you walked in.     */
/*                                                                            */
/*  Within a slide, Home shows it at its start (no fragments revealed) and     */
/*  End shows it fully built (all fragments revealed) -- skipping animations,   */
/*  as Rony asked. Slide-to-slide first/last are on Ctrl+Home / Ctrl+End.      */
/*                                                                            */
/******************************************************************************/

(function () {
  "use strict";

  var stage, slides, current = 0;

  /* ---------------------------------------------------------------------- */
  /* Scaling.                                                                */
  /* ---------------------------------------------------------------------- */

  function readGeometry() {
    var cs = getComputedStyle(document.documentElement);
    var w = parseFloat(cs.getPropertyValue("--deck-w")) || 1280;
    var h = parseFloat(cs.getPropertyValue("--deck-h")) || 720;
    return { w: w, h: h };
  }

  function rescale() {
    var g = readGeometry();
    var scale = Math.min(window.innerWidth / g.w, window.innerHeight / g.h);
    document.documentElement.style.setProperty("--deck-scale", scale);
  }

  /* ---------------------------------------------------------------------- */
  /* Fragments                                                               */
  /* ---------------------------------------------------------------------- */

  function fragmentsOf(slide) {
    return Array.prototype.slice.call(slide.querySelectorAll(".fragment"));
  }

  function revealNext(slide) {
    var frags = fragmentsOf(slide);
    for (var i = 0; i < frags.length; i++) {
      if (!frags[i].classList.contains("revealed")) {
        applyAnimDuration(frags[i]);
        frags[i].classList.add("revealed");
        return true;
      }
    }
    return false;
  }

  function hideLast(slide) {
    var frags = fragmentsOf(slide);
    for (var i = frags.length - 1; i >= 0; i--) {
      if (frags[i].classList.contains("revealed")) {
        frags[i].classList.remove("revealed");
        return true;
      }
    }
    return false;
  }

  function setAllFragments(slide, revealed) {
    fragmentsOf(slide).forEach(function (f) {
      f.classList.toggle("revealed", revealed);
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Slide navigation                                                        */
  /* ---------------------------------------------------------------------- */

  /* ---------------------------------------------------------------------- */
  /* Animation catalogue support. The effects themselves are CSS; the runtime */
  /* only sets the per-element duration and (re)triggers the page animation.   */
  /* ---------------------------------------------------------------------- */

  /* Durations are SECONDS, the same unit as every other time in a deck. This   */
  /* is deliberate: an author who writes wait-before=0.9 must not have to       */
  /* switch units to write anim-duration next to it. timeAttr() does the        */
  /* conversion and still honours an explicit "ms" suffix.                      */
  function applyAnimDuration(el) {
    var ms = timeAttr(el, "data-anim-duration");
    if (ms !== null) el.style.setProperty("--anim-dur", ms + "ms");
  }

  /* Page animations may be direction-aware. Going forward, a "slide" effect     */
  /* enters from the right; going back, from the left -- the phone-gallery       */
  /* gesture, where the direction of travel is what tells the audience whether   */
  /* we are advancing or returning. Symmetric effects (fade, fade-color, cut)    */
  /* ignore the flag; only the "slide" family reads it, so the cost is one       */
  /* class. dir > 0 is forward, dir < 0 is backward, 0 is a jump (no bias).      */
  function triggerPageAnim(slide, dir) {
    applyAnimDuration(slide);
    /* Remove then re-add on the next frame so the animation restarts even when */
    /* returning to a slide already seen.                                       */
    slide.classList.remove("anim-in", "anim-back");
    /* force reflow */
    void slide.offsetWidth;
    if (dir < 0) slide.classList.add("anim-back");
    slide.classList.add("anim-in");
  }

  /* ---------------------------------------------------------------------- */
  /* Vertical fit.                                                           */
  /*                                                                         */
  /* The generator fits code to the WIDTH of its box, because a wrapped line  */
  /* may be a syntax error and must never happen. Height it cannot know: how  */
  /* tall a block ends up depends on the identity's line-height, on what else */
  /* shares the slide, and on how the browser broke the prose above it. So    */
  /* the last word on height is taken here, once the slide is laid out.       */
  /*                                                                         */
  /* Shrinking stops at a floor. Below it the text is too small to read from  */
  /* the back of a lecture hall, and silently shrinking past that point would */
  /* turn an authoring problem into an illegible slide -- the reader would be */
  /* the one to discover it, mid-talk. Instead the slide is marked, so the    */
  /* build can say plainly that it does not fit and should be split.          */
  /* ---------------------------------------------------------------------- */

  function contentBottom(slide) {
    var max = 0;
    for (var i = 0; i < slide.children.length; i++) {
      var c = slide.children[i];
      if (c.classList.contains("deck-footer")) continue;
      var b = c.offsetTop + c.offsetHeight;
      if (b > max) max = b;
    }
    return max;
  }

  /* Code is a fixed size now (the fitter is gone), so nothing is shrunk to fit:
     a block that overflows its slide is an authoring problem to surface, not to
     paper over by shrinking type. We only flag it. */
  function fitHeight(slide) {
    if (slide.hasAttribute("data-fitted")) return;
    slide.setAttribute("data-fitted", "1");

    var limit = slide.clientHeight - footerBand();   /* keep the band clear   */
    if (contentBottom(slide) > limit) slide.setAttribute("data-overflows", "1");
  }

  /* dir: +1 forward, -1 backward, 0 for a jump with no direction (the overlay,  */
  /* a hash landing, first/last). Callers that know the gesture say so; the rest */
  /* let it be derived from the index, which is right for ordinary stepping.     */
  function showSlide(n, enterFromEnd, dir) {
    if (n < 0 || n >= slides.length) return;
    if (dir === undefined) dir = (n > current) ? 1 : (n < current ? -1 : 0);
    cancelTimers();                     /* leaving a slide stops its timers   */
    slides[current].classList.remove("current", "anim-in", "anim-back");
    current = n;
    var slide = slides[current];
    slide.classList.add("current");
    triggerPageAnim(slide, dir);

    setAllFragments(slide, !!enterFromEnd);
    fitHeight(slide);                   /* only measurable once it is visible */

    updateProgress();
    updateHash();
    if (!enterFromEnd) scheduleTimers(slide);   /* time-driven reveal, if any */
  }

  function next() {
    if (revealNext(slides[current])) { cancelTimers(); return; }
    if (current < slides.length - 1) showSlide(current + 1, false);
  }

  function prev() {
    if (hideLast(slides[current])) { cancelTimers(); return; }
    if (current > 0) showSlide(current - 1, true);
  }

  /* Slide-to-slide extremes (Ctrl+Home / Ctrl+End). */
  function firstSlide() { showSlide(0, false, 0); }
  function lastSlide()  { showSlide(slides.length - 1, true, 0); }

  /* Intra-slide extremes (Home / End): show this slide at its start or end,   */
  /* skipping every animation. This is Rony's KISS answer to indexed builds:   */
  /* no arbitrary jump, just "beginning" and "end" of the current slide.       */
  function slideToStart() {
    cancelTimers();
    setAllFragments(slides[current], false);
  }
  function slideToEnd() {
    cancelTimers();
    setAllFragments(slides[current], true);
  }

  /* ---------------------------------------------------------------------- */
  /* Time-driven animation (optional, per slide).                            */
  /*                                                                         */
  /* A slide may drive its own build from the clock instead of from keys.     */
  /*                                                                         */
  /* Declared with data attributes, all in SECONDS -- the unit a human thinks  */
  /* a talk in. Fractions are allowed and mean what they say: 1.5 is a second  */
  /* and a half, 0.25 a quarter of one. Milliseconds were what the machine     */
  /* wanted, not what the author wanted, and nobody writes a slide in them.    */
  /*                                                                         */
  /*   data-wait        gap before AND after each fragment (shorthand)   */
  /*   data-wait-before gap before revealing the next fragment           */
  /*   data-wait-after  extra gap after a fragment before the next       */
  /*   data-duration    total budget; if set, overrides the per-step     */
  /*                         waits by spreading fragments evenly across it     */
  /*                                                                         */
  /* Keys always win: any manual step or navigation cancels the timers, so     */
  /* the presenter can override the clock at any moment (Rony's requirement).  */
  /* ---------------------------------------------------------------------- */

  var timers = [];

  function cancelTimers() {
    timers.forEach(clearTimeout);
    timers = [];
  }

  /* Author-facing times are seconds; setTimeout wants milliseconds. A bare     */
  /* "2" is two seconds. An explicit "500ms" is still honoured, so anyone who   */
  /* really wants sub-second precision can spell it out rather than guess.     */
  function timeAttr(el, name) {
    var v = el.getAttribute(name);
    if (v === null || v === "") return null;
    var n = parseFloat(v);
    if (isNaN(n)) return null;
    return /ms\s*$/i.test(v) ? n : n * 1000;
  }

  /* Reduced motion is a request not to be shown things that move by            */
  /* themselves, and a clock-driven build is exactly that: content appearing     */
  /* unbidden, at a pace the viewer did not choose. The CSS already neutralises  */
  /* the transitions; without this, the reveals would still fire, silently, and  */
  /* the setting would be only half honoured. So the slide falls back to being   */
  /* key-driven: nothing is lost -- every fragment is still reachable with the   */
  /* space bar -- and the author's build order is preserved rather than dumped   */
  /* on screen at once, which would destroy the point of building at all.       */
  function prefersReducedMotion() {
    return !!(window.matchMedia &&
              window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  }

  function scheduleTimers(slide) {
    cancelTimers();
    if (prefersReducedMotion()) return;      /* key-driven instead of clock-driven */
    var frags = fragmentsOf(slide);
    if (!frags.length) return;

    var wait   = timeAttr(slide, "data-wait");
    var before = timeAttr(slide, "data-wait-before");
    var after  = timeAttr(slide, "data-wait-after");
    var total  = timeAttr(slide, "data-duration");

    /* Nothing declared -> slide stays key-driven. */
    if (wait === null && before === null && after === null && total === null) return;

    var stepDelay;
    if (total !== null) {
      /* Even spread across the whole budget. */
      stepDelay = total / frags.length;
    } else {
      var b = before !== null ? before : (wait !== null ? wait : 0);
      var a = after  !== null ? after  : (wait !== null ? wait : 0);
      stepDelay = b + a;
      if (stepDelay <= 0) stepDelay = 800;   /* a sane floor if only wait:0    */
    }

    var acc = 0;
    frags.forEach(function (_, i) {
      acc += stepDelay;
      timers.push(setTimeout(function () {
        /* Only act if we are still on this slide. */
        if (slides[current] === slide) revealNext(slide);
      }, acc));
    });
  }

  /* ---------------------------------------------------------------------- */
  /* The footer.                                                             */
  /*                                                                         */
  /* One rule decides everything here: the FORMAT is the identity's and the   */
  /* FIELDS are the document's. An institution says that its footer carries   */
  /* the institute on the left, the page number in the middle and the         */
  /* presenter on the right; the deck says who the presenter is. Neither      */
  /* knows the other's business, which is why the same Markdown builds for    */
  /* another institution without a word changed -- and why a presenter's name */
  /* never again ends up written into a stylesheet, as it was here before.    */
  /*                                                                         */
  /* Composition happens at run time rather than at build time because two of */
  /* the fields cannot exist any earlier: {page} and {total-pages} are the    */
  /* runtime's own, computed from document order, and were deliberately taken */
  /* away from the generator when hand-written numbers proved to drift. One   */
  /* mechanism that can serve every field beats two that each serve half.     */
  /* ---------------------------------------------------------------------- */

  /* Self-documenting names, expanded to what a reader can actually act on.   */
  /* A licence is not a trait of an institution -- CC BY-SA reads the same in */
  /* Vienna and in Barcelona -- so the table lives here and not in a CI.      */
  var LICENCES = {
    "cc-by":               "CC BY 4.0",
    "cc-by-sa":            "CC BY-SA 4.0",
    "cc-by-nc":            "CC BY-NC 4.0",
    "cc-by-nc-sa":         "CC BY-NC-SA 4.0",
    "cc-by-nd":            "CC BY-ND 4.0",
    "cc-by-nc-nd":         "CC BY-NC-ND 4.0",
    "cc0":                 "CC0 1.0",
    "public-domain":       "Public domain",
    "all-rights-reserved": "All rights reserved",
    "gfdl":                "GFDL 1.3",
    "apache-2.0":          "Apache License 2.0"
  };

  /* A name may pin a version: cc-by-sa-3.0 is CC BY-SA 3.0. Anything the     */
  /* table does not know is shown verbatim, so a jurisdiction port or an odd  */
  /* wording is never blocked; the build is what warns about a likely typo.   */
  function expandLicence(value) {
    if (LICENCES[value]) return LICENCES[value];
    var m = /^(.*)-(\d+(?:\.\d+)?)$/.exec(value);
    if (m && LICENCES[m[1]]) {
      return LICENCES[m[1]].replace(/\s\d+(\.\d+)?$/, " " + m[2]);
    }
    return value;
  }

  /* The content must not climb into the bottom band; fitHeight subtracts this */
  /* to know where the usable area ends. This is LAYOUT geometry (how much air */
  /* the body gets), not a footer concept -- the band exists whether or not    */
  /* anything is painted in it. --theme-footer-height is the theme's to set.   */
  function footerBand() {
    var css = getComputedStyle(document.documentElement);
    return parseFloat(css.getPropertyValue("--theme-footer-height")) || 64;
  }


  /* ---------------------------------------------------------------------- */
  /* Page numbering.                                                         */
  /*                                                                         */
  /* The runtime owns the numbers. Before, they were literals emitted by the  */
  /* generator, which is how the PoC ended up showing 3, 5, 14, 15, 17, 19,   */
  /* 19, 21 for nine slides: those were the page numbers of the ORIGINAL      */
  /* MODUL deck the sample slides were lifted from, kept as set dressing.     */
  /* Whoever authors a deck must never have to keep numbers in sync, so they  */
  /* are computed here from document order and written on load.               */
  /*                                                                         */
  /* Semantics are PowerPoint's, which is what an audience expects: one       */
  /* number per SLIDE, counting from 1, and it does not move while fragments  */
  /* are revealed. A slide may hide its number (the title page does, via CSS) */
  /* but it still occupies a position, so the numbers stay contiguous.        */
  /* ---------------------------------------------------------------------- */

  /* Numbering publishes the two RAW numbers the runtime alone can know -- the
     slide's position and the deck total -- in BOTH forms the CSS may want:
     as data-* attributes (for `content: attr(data-page)`) and as custom
     properties (for use in calc() or wherever a variable is handier). It never
     composes a string and never decides placement: "19", "19 / 42", hidden on
     the title page -- all of that is the theme/master's CSS. One datum, two
     spellings, zero opinions about the footer. */
  function numberSlides() {
    var total = slides.length;
    slides.forEach(function (s, i) {
      var page = i + 1;
      s.setAttribute("data-page", String(page));
      s.setAttribute("data-total", String(total));
      s.style.setProperty("--page", String(page));
      s.style.setProperty("--total", String(total));
    });
  }

  /* ---------------------------------------------------------------------- */
  /* Progress and location                                                   */
  /* ---------------------------------------------------------------------- */

  function updateProgress() {
    var bar = document.getElementById("progress");
    if (!bar) return;
    var pct = slides.length > 1 ? (current / (slides.length - 1)) * 100 : 100;
    bar.style.width = pct + "%";
  }

  function updateHash() {
    try {
      var id = slides[current].id || String(current + 1);
      if (window.history && window.history.replaceState) {
        window.history.replaceState(null, "", "#" + id);
      }
    } catch (e) { /* file:// in some browsers dislikes this; harmless */ }
  }

  function slideFromHash() {
    var h = (window.location.hash || "").replace(/^#/, "");
    if (!h) return 0;
    for (var i = 0; i < slides.length; i++) {
      if (slides[i].id === h) return i;
    }
    var n = parseInt(h, 10);
    return (!isNaN(n) && n >= 1 && n <= slides.length) ? n - 1 : 0;
  }

  /* ---------------------------------------------------------------------- */
  /* Screen blanking (b = black, w = white). Toggle off with the same key,    */
  /* Escape, or Enter. A blank screen swallows navigation until cleared, the   */
  /* way PowerPoint and Impress behave.                                        */
  /* ---------------------------------------------------------------------- */

  var blanker = null;

  function setBlank(color) {
    if (!blanker) {
      blanker = document.createElement("div");
      blanker.id = "blanker";
      blanker.style.cssText =
        "position:fixed;inset:0;z-index:9999;display:none;";
      document.body.appendChild(blanker);
    }
    if (color) {
      blanker.style.background = color;
      blanker.style.display = "block";
    } else {
      blanker.style.display = "none";
    }
  }
  function isBlank() { return blanker && blanker.style.display === "block"; }

  /* ---------------------------------------------------------------------- */
  /* Jump overlay. Lists every page as a target and takes a typed page        */
  /* number + Enter, the way PowerPoint/Impress do in presentation mode.       */
  /* ---------------------------------------------------------------------- */

  var overlay = null, jumpInput = null;

  function buildOverlay() {
    overlay = document.createElement("div");
    overlay.id = "jump-overlay";
    overlay.innerHTML =
      '<div class="jo-panel">' +
        '<div class="jo-head">' +
          '<span>Go to slide</span>' +
          '<input id="jo-input" type="text" inputmode="numeric" ' +
                 'autocomplete="off" placeholder="type a number, Enter">' +
        '</div>' +
        '<div class="jo-list" id="jo-list"></div>' +
        '<div class="jo-hint">Enter jump &middot; Esc close &middot; ' +
          'b black &middot; w white</div>' +
      '</div>';
    document.body.appendChild(overlay);
    jumpInput = overlay.querySelector("#jo-input");

    var list = overlay.querySelector("#jo-list");
    slides.forEach(function (s, i) {
      var item = document.createElement("button");
      item.type = "button";
      item.className = "jo-item";
      var label = s.getAttribute("data-title") ||
                  s.getAttribute("data-section") || s.id || ("Slide " + (i + 1));
      var kind = s.classList.contains("section") ? "section" : "slide";
      item.innerHTML = '<span class="jo-num">' + (i + 1) + '</span>' +
                       '<span class="jo-label">' + label + '</span>' +
                       '<span class="jo-kind">' + kind + '</span>';
      item.addEventListener("click", function () {
        goTo(i); closeOverlay();
      });
      list.appendChild(item);
    });

    overlay.addEventListener("click", function (e) {
      if (e.target === overlay) closeOverlay();
    });
    jumpInput.addEventListener("keydown", function (e) {
      e.stopPropagation();   /* keep the global handler out while typing */
      if (e.key === "Enter") {
        var n = parseInt(jumpInput.value, 10);
        if (!isNaN(n) && n >= 1 && n <= slides.length) { goTo(n - 1); closeOverlay(); }
      } else if (e.key === "Escape") {
        closeOverlay();
      }
    });
  }

  function openOverlay() {
    if (!overlay) buildOverlay();
    highlightCurrent();
    overlay.classList.add("open");
    jumpInput.value = "";
    setTimeout(function () { jumpInput.focus(); }, 0);
  }
  function closeOverlay() {
    if (overlay) overlay.classList.remove("open");
    if (jumpInput) jumpInput.blur();
    focusStage();
  }
  function overlayOpen() { return overlay && overlay.classList.contains("open"); }
  function highlightCurrent() {
    if (!overlay) return;
    var items = overlay.querySelectorAll(".jo-item");
    for (var i = 0; i < items.length; i++) {
      items[i].classList.toggle("here", i === current);
    }
  }

  function goTo(n) {
    setBlank(null);           /* any jump clears a blank screen */
    showSlide(n, false, 0);   /* a jump has no direction of travel */
  }

  /* ---------------------------------------------------------------------- */
  /* Input                                                                   */
  /* ---------------------------------------------------------------------- */

  /* Returning focus to the stage after using a control is what stops the      */
  /* "trapped on the slide" bug: once a <select> has focus, arrow keys cycle    */
  /* its options instead of navigating. We blur controls back to the body.     */
  function focusStage() {
    if (document.activeElement &&
        /^(INPUT|SELECT|TEXTAREA)$/.test(document.activeElement.tagName)) {
      document.activeElement.blur();
    }
  }

  function onKey(e) {
    if (e.defaultPrevented) return;

    /* The jump input handles its own keys (and stops propagation), but guard   */
    /* other controls the same way the original did.                           */
    if (e.target && /^(INPUT|SELECT|TEXTAREA)$/.test(e.target.tagName)) return;

    /* While the overlay is open, only Escape (handled on the input) and clicks */
    /* matter; swallow stray keys so they do not navigate underneath.          */
    if (overlayOpen()) {
      if (e.key === "Escape") { closeOverlay(); e.preventDefault(); }
      return;
    }

    /* A blank screen swallows everything except the keys that clear it.        */
    if (isBlank()) {
      if (e.key === "b" || e.key === "B" || e.key === "w" || e.key === "W" ||
          e.key === "Enter" || e.key === "Escape" || e.key === " ") {
        setBlank(null); e.preventDefault();
      }
      return;
    }

    switch (e.key) {
      case "ArrowRight": case "ArrowDown": case "PageDown":
      case " ":
        next(); e.preventDefault(); break;
      case "ArrowLeft": case "ArrowUp": case "PageUp":
      case "Backspace":
        prev(); e.preventDefault(); break;

      /* Home/End act within the slide (skip animations to start / end).        */
      /* Ctrl adds the deck-wide jump to first / last slide.                    */
      case "Home":
        e.ctrlKey ? firstSlide() : slideToStart(); e.preventDefault(); break;
      case "End":
        e.ctrlKey ? lastSlide() : slideToEnd(); e.preventDefault(); break;

      case "g": case "G":
        openOverlay(); e.preventDefault(); break;

      case "b": case "B":
        setBlank(isBlank() ? null : "#000"); e.preventDefault(); break;
      case "w": case "W":
        setBlank(isBlank() ? null : "#fff"); e.preventDefault(); break;

      case "f": case "F":
        toggleFullscreen(); e.preventDefault(); break;

      case "F8":
        toggleControls(); e.preventDefault(); break;

      case "Escape":
        setBlank(null); break;

      default:
        /* A bare digit opens the overlay pre-filled, so typing "12<Enter>"      */
        /* works straight from the slide, PowerPoint-style.                     */
        if (/^[0-9]$/.test(e.key)) {
          openOverlay();
          jumpInput.value = e.key;
          e.preventDefault();
        }
    }
  }

  /* Where the pointer went down, so a click can be told apart from a drag.    */
  var downX = null, downY = null;

  function onMouseDown(e) { downX = e.clientX; downY = e.clientY; }

  /* A click advances the deck -- but selecting text with the mouse ends in a  */
  /* click too, and advancing there threw the selection away the moment the    */
  /* button came up (Rony could never copy anything off a slide). Two guards:  */
  /* the pointer must not have travelled (a drag is a selection gesture, not   */
  /* navigation), and there must be no live selection left behind by it.       */
  function isDragGesture(e) {
    if (downX === null) return false;
    return Math.abs(e.clientX - downX) > 4 || Math.abs(e.clientY - downY) > 4;
  }

  function hasSelection() {
    var sel = window.getSelection();
    return !!(sel && !sel.isCollapsed && String(sel).length);
  }

  function onClick(e) {
    if (typeof e.button === "number" && e.button !== 0) return;  /* primary only */
    if (e.target.closest && e.target.closest("#controls, a, #jump-overlay")) return;
    if (isBlank()) { setBlank(null); return; }
    if (isDragGesture(e) || hasSelection()) return;
    if (e.clientX < window.innerWidth / 8) prev();
    else next();
  }

  function toggleFullscreen() {
    var el = document.documentElement;
    if (!document.fullscreenElement) {
      if (el.requestFullscreen) el.requestFullscreen();
    } else if (document.exitFullscreen) {
      document.exitFullscreen();
    }
  }

  /* F8 shows/hides the control box. It is born hidden (.controls-hidden set in  */
  /* the template) so it never covers the slide footer during a talk; the        */
  /* selects stay wired the whole time, so toggling visibility changes nothing   */
  /* about how jump / code-style behave -- only whether they are on screen.      */
  function toggleControls() {
    var c = document.getElementById("controls");
    if (c) c.classList.toggle("controls-hidden");
  }

  /* ---------------------------------------------------------------------- */
  /* Init                                                                    */
  /* ---------------------------------------------------------------------- */

  function init() {
    stage  = document.getElementById("stage");
    slides = Array.prototype.slice.call(document.querySelectorAll(".slide"));
    if (!slides.length) return;

    slides.forEach(function (s) { setAllFragments(s, false); });
    numberSlides();

    current = slideFromHash();
    slides.forEach(function (s, i) {
      s.classList.toggle("current", i === current);
    });
    triggerPageAnim(slides[current]);

    rescale();
    fitHeight(slides[current]);
    updateProgress();
    scheduleTimers(slides[current]);

    window.addEventListener("resize", rescale);
    document.addEventListener("keydown", onKey);
    document.addEventListener("mousedown", onMouseDown, true);
    document.addEventListener("click", onClick);

    window.addEventListener("hashchange", function () {
      var n = slideFromHash();
      if (n !== current) showSlide(n, false, 0);   /* landing, not stepping */
    });

    var x0 = null;
    document.addEventListener("touchstart", function (e) {
      x0 = e.changedTouches[0].clientX;
    }, { passive: true });
    document.addEventListener("touchend", function (e) {
      if (x0 === null) return;
      var dx = e.changedTouches[0].clientX - x0;
      if (Math.abs(dx) > 40) { dx < 0 ? next() : prev(); }
      x0 = null;
    }, { passive: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

