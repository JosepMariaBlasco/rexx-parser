/******************************************************************************/
/*                                                                            */
/*  deck-runtime.js -- Presentation deck runtime                              */
/*                                                                            */
/*  Adds to a RexxPub-generated document the things the scrolling HTML output  */
/*  does not have: viewport pagination, key/click navigation, stepped reveal   */
/*  of fragments, an any-page jump overlay (g), a code-style modal (s), screen  */
/*  blanking, and optional time-driven animation.                              */
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

  /* The code-style list, one entry per shipped rexx-<style>.css, emitted by    */
  /* md2slides.rex (RexxStyleData) as a JS array literal. Each entry is         */
  /* { v: "<style>", d: <isDefault> }. Drives the code-style modal (key s);     */
  /* replaces the old <select id="rexx-style"> that lived in the F8 control box. */
  var REXX_STYLES = %rexxStyleData%;

  var stage, slides, current = 0;

  /* ---------------------------------------------------------------------- */
  /* Pictures used more than once.                                           */
  /* ---------------------------------------------------------------------- */

  /* md2slides embeds a picture once, however many times the deck shows it:  */
  /* the first <img> carries the bytes and data-pic="n", and every repeat a  */
  /* 1x1 placeholder and data-pic-copy="n". The src is copied across here,   */
  /* at load and before anything else runs, so nothing below ever sees a     */
  /* placeholder -- including the clones the overview makes of the slides.   */
  Array.prototype.forEach.call(document.querySelectorAll("img[data-pic-copy]"),
    function (img) {
      var from = document.querySelector('img[data-pic="' +
                                        img.getAttribute("data-pic-copy") + '"]');
      if (from) img.setAttribute("src", from.getAttribute("src"));
    });

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

  /* The spotlight (js/spotlight.js) marks lines of a listing and groups them */
  /* into named BEATS with the prose fragments they belong to. It is optional */
  /* -- a deck that loads no spotlight.js keeps every behaviour below intact, */
  /* which is why every call is guarded.                                      */
  /*                                                                          */
  /* The division of labour: THIS file owns "how far are we" and says so by   */
  /* adding and removing .revealed, exactly as before. The spotlight only     */
  /* reads that state back and lights the lines to match. So we do not have   */
  /* to teach revealNext, Home, End, the overlay jump or the auto-advance     */
  /* about beats at all -- each just says "something moved" when it is done.  */
  function spotSync(slide) {
    if (window.Spotlight) window.Spotlight.sync(slide);
  }

  function fragmentsOf(slide) {
    return Array.prototype.slice.call(slide.querySelectorAll(".fragment"));
  }

  /* A STEP is what one key press reveals. Usually one fragment; several ways  */
  /* let fragments share, or auto-chain from, a step:                          */
  /*                                                                          */
  /*   - class "withPrevious": a fragment belongs to the step of the fragment  */
  /*     right before it in document order (the contiguous case) and appears   */
  /*     AT THE SAME TIME. The generator marks empty table cells this way so a */
  /*     press never shows nothing. A "withPrevious" with nothing before it    */
  /*     opens a step by itself.                                               */
  /*                                                                          */
  /*   - class "afterPrevious": a fragment opens its OWN step (so it is a      */
  /*     separate moment in time), but that step fires AUTOMATICALLY once the  */
  /*     previous step has finished animating -- no press of its own. A run of */
  /*     afterPrevious fragments thus cascades one after another from a single */
  /*     press. Marked on the step so revealNext can chain it (see below). A   */
  /*     press always still forces the next step immediately, so the presenter */
  /*     is never stuck waiting for the clock (a "with nothing revealed yet"   */
  /*     never happens). This is the eye's counterpart to withPrevious: same   */
  /*     zero-press cost, but sequential instead of simultaneous.              */
  /*                                                                          */
  /*   - data-group="NAME": every fragment with the same group name shares    */
  /*     one step, WHETHER OR NOT they are contiguous. The step lands at the   */
  /*     position of the group's FIRST member in document order: the press     */
  /*     that would have revealed the first member reveals the whole group at  */
  /*     once, and later members cost no press of their own. This is how you   */
  /*     show A and B together, then fill in A's sub-items, then B's: A and B  */
  /*     share a group, their sub-items do not. A group whose members are      */
  /*     afterPrevious instead cascades (see the group note in stepsOf).       */
  /*                                                                          */
  /* "withPrevious" is really the anonymous case of a group ("join the step    */
  /* next to me"); a named group just lets the joined fragments be non-adjacent*/
  /*                                                                          */
  /* A step carries .after = true when the fragment that opened it asked to    */
  /* auto-chain (afterPrevious). revealNext reads that flag to decide whether  */
  /* to schedule the following step by itself.                                 */
  function stepsOf(slide) {
    var steps = [];
    var groupStep = {};              /* group name -> the step array it anchors */
    fragmentsOf(slide).forEach(function (f) {
      var g     = f.getAttribute("data-group");
      var after = f.classList.contains("afterPrevious");
      /* Precedence: afterPrevious > group membership > withPrevious.           */
      /* afterPrevious is checked FIRST so a group can be made SEQUENTIAL: mark  */
      /* every member afterPrevious and each opens its own auto-chained step     */
      /* (one after another) instead of folding into the group's single step    */
      /* (all at once). This is exactly Rony's ask -- a group animated either    */
      /* together (plain group=, or withPrevious) OR one after the other         */
      /* (group= + afterPrevious). Without this the group merge would swallow    */
      /* the afterPrevious and the members would all fire on one press.          */
      if (after) {                   /* auto-chained: always its own step */
        var astep = [f];
        astep.after = true;
        steps.push(astep);
      } else if (g && groupStep[g]) { /* a later member of a known (simultaneous) group */
        groupStep[g].push(f);
      } else if (f.classList.contains("withPrevious") && steps.length) {
        steps[steps.length - 1].push(f);   /* contiguous "withPrevious" */
      } else {
        var step = [f];              /* opens a new step ... */
        steps.push(step);
        if (g) groupStep[g] = step;  /* ... and, if named, anchors the group here */
      }
    });
    return steps;
  }

  /* Timers that carry an afterPrevious cascade forward on their own. Kept apart */
  /* from revealNext's own recursion so a manual press (or any navigation) can   */
  /* cancel a running cascade and take over -- the presenter always wins, and a  */
  /* press is never swallowed while the clock is mid-chain (Rony's ask, and the  */
  /* "a press always shows something" rule). cancelChain runs from every manual  */
  /* entry point (revealNext-by-key, hideLast, slide change, jumps).             */
  var chainTimers = [];
  function cancelChain() {
    chainTimers.forEach(clearTimeout);
    chainTimers = [];
  }

  /* The effective reveal duration of a step, in ms: the max --anim-dur among    */
  /* its fragments (a step may hold several, e.g. a group). Read from the        */
  /* computed style so it reflects the skin default (--skin-anim-duration-elem)  */
  /* as well as any per-fragment anim-duration the runtime wrote inline. A "cut" */
  /* fragment has no transition, so it contributes 0 and the chain fires at once.*/
  function stepDurationMs(step) {
    var maxMs = 0;
    step.forEach(function (f) {
      if (f.getAttribute("data-anim") === "cut") return;
      var cs = getComputedStyle(f);
      var v = cs.getPropertyValue("--anim-dur").trim();   /* e.g. "1000ms" or "1s" */
      var n = parseFloat(v);
      if (!isNaN(n)) {
        if (/ms\s*$/i.test(v)) { /* already ms */ }
        else if (/s\s*$/i.test(v)) n *= 1000;
        if (n > maxMs) maxMs = n;
      }
    });
    return maxMs;
  }

  /* A step's own waits, in ms (v224; Rony, 28-Sep: "wherever animation        */
  /* related information is supplied, I would expect it to be honored"). On a   */
  /* fragment, wait-before= is a pause before its step and wait-after= a pause  */
  /* after it, and wait= is both, as on a slide. They time the steps that come  */
  /* by themselves (.afterPrevious): a press shows its step at once, because     */
  /* the presenter always wins. A step's wait is the longest of its fragments'. */
  function stepWaitMs(step, which) {
    var ms = 0;
    step.forEach(function (f) {
      var v = timeAttr(f, "data-wait-" + which);
      if (v === null) v = timeAttr(f, "data-wait");
      if (v !== null && v > ms) ms = v;
    });
    return ms;
  }

  /* Reveal one step (all its fragments) and, if the NEXT step is an             */
  /* afterPrevious auto-chain, schedule it once this step's animation is done.   */
  /* The scheduled reveal calls back here, so the chain continues as long as     */
  /* each following step is afterPrevious. reduced-motion skips the scheduling   */
  /* (the CSS collapses the animation anyway), leaving the run key-driven.       */
  function revealStep(slide, steps, i) {
    steps[i].forEach(function (f) {
      applyAnimDuration(f);
      /* Commit the hidden state first. A transition runs from the style the  */
      /* browser last COMPUTED; if nothing has computed it since the slide     */
      /* came back (a busy or throttled frame -- going full screen, say), the  */
      /* fragment has no "before" and simply appears. Rony saw a leading      */
      /* afterPrevious come in without its animation, "sometimes".            */
      void getComputedStyle(f).opacity;
      f.classList.add("revealed");
    });
    spotSync(slide);
    var next = steps[i + 1];
    if (next && next.after && !prefersReducedMotion()) {
      var delay = stepDurationMs(steps[i]) + stepWaitMs(steps[i], "after") +
                  stepWaitMs(next, "before");
      chainTimers.push(setTimeout(function () {
        if (slides[current] !== slide) return;         /* left the slide */
        if (next[0].classList.contains("revealed")) return; /* a press got there first */
        revealStep(slide, steps, i + 1);
      }, delay));
    }
  }

  /* A slide whose FIRST step is afterPrevious starts its cascade by itself:  */
  /* the slide comes up with its title and margins, and a beat later the      */
  /* first fragment animates in -- no press. "After the previous" has nothing */
  /* before it but the slide itself, so it follows the slide (Rony's ask).    */
  /* The beat is the page's own transition, so the fragment never races the  */
  /* slide in; with a cut (no transition) it is ENTRY_BEAT_MS, long enough to */
  /* see the empty slide as a moment of its own. Only on entering a slide from*/
  /* its start: coming back into it from the end shows it complete already.   */
  var ENTRY_BEAT_MS = 300;
  function pageDurationMs(slide) {
    var a = slide.getAttribute("data-anim");
    if (!a || a === "cut") return 0;
    var v = getComputedStyle(slide).getPropertyValue("--anim-dur").trim();
    var n = parseFloat(v);
    if (isNaN(n)) return 0;
    return /ms\s*$/i.test(v) ? n : n * 1000;
  }
  function startEntryChain(slide) {
    var steps = stepsOf(slide);
    if (!steps.length || !steps[0].after || prefersReducedMotion()) return;
    var delay = Math.max(pageDurationMs(slide), ENTRY_BEAT_MS) +
                stepWaitMs(steps[0], "before");
    chainTimers.push(setTimeout(function () {
      if (slides[current] !== slide) return;
      if (steps[0][0].classList.contains("revealed")) return;
      revealStep(slide, steps, 0);
    }, delay));
  }

  function revealNext(slide) {
    cancelChain();                 /* a manual advance takes over any cascade */
    var steps = stepsOf(slide);
    for (var i = 0; i < steps.length; i++) {
      if (!steps[i][0].classList.contains("revealed")) {
        revealStep(slide, steps, i);
        return true;
      }
    }
    return false;
  }

  function hideLast(slide) {
    cancelChain();                 /* going back also takes over any cascade */
    var steps = stepsOf(slide);
    for (var i = steps.length - 1; i >= 0; i--) {
      if (steps[i][0].classList.contains("revealed")) {
        steps[i].forEach(function (f) { f.classList.remove("revealed"); });
        spotSync(slide);
        return true;
      }
    }
    return false;
  }

  function setAllFragments(slide, revealed) {
    fragmentsOf(slide).forEach(function (f) {
      f.classList.toggle("revealed", revealed);
    });
    spotSync(slide);
  }

  /* ---------------------------------------------------------------------- */
  /* Arrows.                                                                 */
  /*                                                                         */
  /*     []{.arrow .fragment from=cmd to=errors}                             */
  /*                                                                         */
  /* An empty span that says where an arrow leaves and where it lands. Pandoc */
  /* lifts a span that is alone in its paragraph onto the <p>, so what we get */
  /* is <p class="arrow fragment" data-from="cmd" data-to="errors">; two      */
  /* spans in one paragraph stay spans, and both forms are carriers.          */
  /*                                                                         */
  /* THE CARRIER IS THE ARROW. Its SVG is drawn INSIDE it, so the arrow is a  */
  /* step like any other with nothing taught to anybody: .fragment, timing    */
  /* words, group=, anim=, anim-duration=, reduced motion, leafing, printing  */
  /* (every fragment shown), and spot= (the spotlight makes it the beat's     */
  /* anchor) all act on the carrier, and the drawing goes with it. Rony's own */
  /* arrows come in with the same "ascend" as the rest of his slide, which is */
  /* what anim="fade-up" on the carrier gives. The carrier is taken out of    */
  /* the flow (runtime.css: absolute, no size), and its SVG is as big as the  */
  /* slide and shifted back to the slide's corner, so the drawing is in slide */
  /* coordinates wherever the author wrote the span. Where it is written only */
  /* decides WHEN it appears (document order), never where.                  */
  /*                                                                         */
  /* THE ENDS are ids on the same slide (```output {#cmd}, ::: {#errors}).    */
  /* An end can be narrowed with the addresses of spot=: to="cmd[2>x.txt]"    */
  /* points at that text of the block, to=cmd:1 at its first line (see        */
  /* Spotlight.locate). An id is looked up exactly, then ignoring case, as    */
  /* beat names are.                                                         */
  /*                                                                         */
  /* THE GEOMETRY is chosen, never written:                                  */
  /*   - side by side (the heights overlap): horizontal, at the middle of the */
  /*     overlap -- in Rony's slides, the height of the command;              */
  /*   - one above the other (the widths overlap): vertical, the same way;   */
  /*   - otherwise: centre to centre, cut at the border of each box.         */
  /* Each end stops --skin-arrow-gap short of its box.                        */
  /*                                                                         */
  /* MEASURING. Everything is in the slide's own pixels, taken from LAYOUT    */
  /* (offsetLeft/Top up to the slide), not from getBoundingClientRect: a      */
  /* fragment that is still flying in (fade-up) is painted somewhere it does  */
  /* not live, and an arrow measured then would point at where the box was   */
  /* mid-flight. A text end needs a Range, which only has painted rects, so  */
  /* it is measured relative to its block's painted rect and placed on the   */
  /* block's layout position -- the flight cancels out. Slide pixels also    */
  /* mean the stage's scaling never enters: a resize changes nothing here,   */
  /* and paper (the same 1280x720 canvas) gets the same drawing.             */
  /*                                                                         */
  /* What goes wrong (an id that is not there, a text not found, two ends     */
  /* that overlap) is kept on the carrier and listed by d.                   */
  /* ---------------------------------------------------------------------- */
  var SVGNS = "http://www.w3.org/2000/svg";

  function arrowsOf(slide) {
    return Array.prototype.slice.call(
      slide.querySelectorAll(".arrow[data-from], .arrow[data-to]"));
  }

  /* An arrow's position in the slide, from layout. null if not laid out.    */
  function offsetIn(el, slide) {
    var x = 0, y = 0, n = el;
    while (n && n !== slide) {
      x += n.offsetLeft;
      y += n.offsetTop;
      var p = n.offsetParent;
      if (p && p !== slide) { x += p.clientLeft; y += p.clientTop; }
      n = p;
    }
    return n === slide ? { x: x, y: y } : null;
  }

  /* The layout box of an element that is NOT inline. offsetLeft/Top of an    */
  /* inline element are not the same thing in every browser: Firefox gives   */
  /* every line span of a numbered listing offsetTop 0, so an arrow from its */
  /* line 2 or 3 left from line 1 (Rony, 27-Sep, v219).                      */
  function layoutBox(el, slide) {
    var o = offsetIn(el, slide);
    if (!o || (!el.offsetWidth && !el.offsetHeight)) return null;
    return { l: o.x, t: o.y, r: o.x + el.offsetWidth, b: o.y + el.offsetHeight };
  }

  /* The nearest element, from el up, that lays out a box of its own: not    */
  /* inline, not display: contents. Its offsets can be trusted.              */
  function blockOf(el, slide) {
    while (el && el !== slide && el.nodeType === 1) {
      var d = getComputedStyle(el).display;
      if (d !== "inline" && d !== "contents") return el;
      el = el.parentNode;
    }
    return el;
  }

  /* Painted rects, laid in the slide: each one relative to the painted rect */
  /* of `anchor` (a block), placed on anchor's layout box (see MEASURING     */
  /* above). The anchor must be the NEAREST block, not the arrow's end: a    */
  /* hidden fade-up fragment inside the end is painted a tenth of the slide  */
  /* lower than it lives, and so is its text -- the two cancel only when     */
  /* they are measured against each other.                                   */
  function rectsBox(rects, anchor, slide) {
    var box = layoutBox(anchor, slide);
    if (!box) return null;
    var er = anchor.getBoundingClientRect();
    var k  = er.width / anchor.offsetWidth;      /* stage scale, and any flight */
    if (!k) return null;
    var u = null;
    Array.prototype.forEach.call(rects, function (r) {
      if (!r.width && !r.height) return;
      var b = { l: box.l + (r.left - er.left) / k, t: box.t + (r.top - er.top) / k,
                r: box.l + (r.right - er.left) / k, b: box.t + (r.bottom - er.top) / k };
      u = u ? { l: Math.min(u.l, b.l), t: Math.min(u.t, b.t),
                r: Math.max(u.r, b.r), b: Math.max(u.b, b.b) } : b;
    });
    return u;
  }

  /* An element's box in the slide: its layout box, or, for an inline one   */
  /* (a chip in a sentence), its painted rects against its block.            */
  function boxOf(el, slide) {
    var anchor = blockOf(el, slide);
    if (anchor === el) return layoutBox(el, slide);
    if (!anchor || anchor.nodeType !== 1) return null;
    return rectsBox(el.getClientRects(), anchor, slide);
  }

  /* The box of some Ranges (a line, a text of a block).                     */
  function rangesBox(ranges, slide) {
    var u = null;
    ranges.forEach(function (rg) {
      var el = rg.commonAncestorContainer;
      if (el.nodeType !== 1) el = el.parentNode;
      var anchor = blockOf(el, slide);
      if (!anchor || anchor.nodeType !== 1) return;
      var b = rectsBox(rg.getClientRects(), anchor, slide);
      if (!b) return;
      u = u ? { l: Math.min(u.l, b.l), t: Math.min(u.t, b.t),
                r: Math.max(u.r, b.r), b: Math.max(u.b, b.b) } : b;
    });
    return u;
  }

  /* Does el paint a box of its own -- a background, a border, a shadow, or   */
  /* is it a picture? Then its box is what the eye sees as "the box".         */
  function paintsBox(el) {
    if (/^(IMG|SVG|VIDEO|CANVAS|IFRAME|OBJECT)$/i.test(el.tagName)) return true;
    var cs = getComputedStyle(el);
    if (cs.backgroundImage !== "none" || cs.boxShadow !== "none") return true;
    var bg = cs.backgroundColor;
    if (bg && bg !== "transparent" && !/rgba\(.*,\s*0\)$/.test(bg)) return true;
    return ["Top", "Right", "Bottom", "Left"].some(function (s) {
      return cs["border" + s + "Style"] !== "none" && parseFloat(cs["border" + s + "Width"]) > 0;
    });
  }

  /* What the eye takes for an element: its box if it paints one; otherwise  */
  /* the union of its text and of the boxes painted inside it. A ::: {#c}     */
  /* holding one word is a block as wide as its column, and an arrow aimed at */
  /* that box lands in empty space -- 70px short of the word on the first     */
  /* test slide. A block that paints (an output with its grey ground, a       */
  /* picture) is its box, which is what Rony's file boxes are.                */
  function inkBox(el, slide) {
    if (paintsBox(el)) return boxOf(el, slide);
    var ranges = [], u = null;
    var add = function (b) {
      if (!b) return;
      u = u ? { l: Math.min(u.l, b.l), t: Math.min(u.t, b.t),
                r: Math.max(u.r, b.r), b: Math.max(u.b, b.b) } : b;
    };
    (function walk(node) {
      for (var n = node.firstChild; n; n = n.nextSibling) {
        if (n.nodeType === 3) {
          if (n.data.trim()) {
            var rg = document.createRange();
            rg.selectNodeContents(n);
            ranges.push(rg);
          }
        } else if (n.nodeType === 1) {
          if (n.classList.contains("arrow") || n.classList.contains("arrow-svg")) continue;
          if (getComputedStyle(n).display === "none") continue;
          if (paintsBox(n)) add(boxOf(n, slide));
          else walk(n);
        }
      }
    })(el);
    if (ranges.length) add(rangesBox(ranges, slide));
    return u || boxOf(el, slide);
  }

  /* Resolve one end, "id", "id[text]", "id:1", "id:2[text]"... to a box.     */
  /* Returns { box } or { problem }.                                          */
  function arrowEnd(slide, which, addr) {
    var m = /^\s*([^\[:\s]+)\s*:?\s*([\s\S]*?)\s*$/.exec(addr || "");
    if (!m) return { problem: which + "= is empty" };
    var id = m[1], items = m[2];
    var el = null;
    try { el = slide.querySelector("#" + CSS.escape(id)); } catch (e) { el = null; }
    if (!el) {
      var lower = id.toLowerCase();
      el = Array.prototype.filter.call(slide.querySelectorAll("[id]"), function (x) {
        return x.id.toLowerCase() === lower;
      })[0] || null;
    }
    if (!el) {
      var elsewhere = document.getElementById(id);
      var s = elsewhere && elsewhere.closest ? elsewhere.closest(".slide") : null;
      return { problem: which + '="' + addr + '": there is no #' + id +
               " on this slide" + (s ? " (it is on slide " + (slides.indexOf(s) + 1) + ")" : "") };
    }
    if (!items) {
      var bx = inkBox(el, slide);
      return bx ? { box: bx } : { problem: which + '="' + addr + '": #' + id + " is not laid out" };
    }
    if (!window.Spotlight || !window.Spotlight.locate) {
      return { box: boxOf(el, slide) };           /* no addresses: the block */
    }
    var loc = window.Spotlight.locate(el, items);
    if (loc.nocode) {
      return { problem: which + '="' + addr + '": #' + id +
               " is not a listing, so it has no lines or texts to point at" };
    }
    if (loc.bad.length) {
      return { problem: which + '="' + addr + '": cannot read "' + loc.bad.join(", ") +
               '" as a line, a range or a [text]' };
    }
    if (!loc.ranges.length) {
      return { problem: which + '="' + addr + '": ' + loc.missing.join(", ") +
               " is not in #" + id + (loc.missing[0].charAt(0) === '"' ? " as a whole word" : "") };
    }
    var rb = rangesBox(loc.ranges, slide);
    var out = rb ? { box: rb } : { problem: which + '="' + addr + '": #' + id + " is not laid out" };
    if (rb && loc.missing.length) {
      out.problem = which + '="' + addr + '": ' + loc.missing.join(", ") + " is not in #" + id;
    }
    return out;
  }

  /* The segment [x1, y1, x2, y2] from box A to box B, or null when the two   */
  /* boxes overlap or touch and there is no room for an arrow between them.   */
  function arrowSegment(A, B, gap) {
    var oy = Math.min(A.b, B.b) - Math.max(A.t, B.t);
    var ox = Math.min(A.r, B.r) - Math.max(A.l, B.l);
    var seg;
    if (oy > 0 && ox <= 0) {                                   /* side by side */
      var y = (Math.max(A.t, B.t) + Math.min(A.b, B.b)) / 2;
      seg = A.r <= B.l ? [A.r + gap, y, B.l - gap, y] : [A.l - gap, y, B.r + gap, y];
    } else if (ox > 0 && oy <= 0) {                            /* stacked      */
      var x = (Math.max(A.l, B.l) + Math.min(A.r, B.r)) / 2;
      seg = A.b <= B.t ? [x, A.b + gap, x, B.t - gap] : [x, A.t - gap, x, B.b + gap];
    } else if (ox > 0 && oy > 0) {
      return null;                                             /* overlapping  */
    } else {                                                   /* diagonal     */
      var ax = (A.l + A.r) / 2, ay = (A.t + A.b) / 2;
      var bx = (B.l + B.r) / 2, by = (B.t + B.b) / 2;
      var dx = bx - ax, dy = by - ay, len = Math.sqrt(dx * dx + dy * dy);
      if (!len) return null;
      /* How far along the centre line each box ends: the nearer of the two   */
      /* borders the line crosses, as a fraction of the centre distance.      */
      var out = function (Bx) {
        var hw = (Bx.r - Bx.l) / 2, hh = (Bx.b - Bx.t) / 2;
        return Math.min(dx ? hw / Math.abs(dx) : Infinity,
                        dy ? hh / Math.abs(dy) : Infinity);
      };
      var ta = out(A) + gap / len, tb = 1 - out(B) - gap / len;
      if (tb <= ta) return null;
      seg = [ax + dx * ta, ay + dy * ta, ax + dx * tb, ay + dy * tb];
    }
    var sx = seg[2] - seg[0], sy = seg[3] - seg[1];
    /* Too close: the ends would cross over. */
    if ((oy > 0 && ox <= 0 && (A.r <= B.l ? sx : -sx) <= 0) ||
        (ox > 0 && oy <= 0 && (A.b <= B.t ? sy : -sy) <= 0)) return null;
    return seg;
  }

  function px(v, dflt) {
    var n = parseFloat(v);
    return isNaN(n) ? dflt : n;
  }

  function drawArrow(slide, el) {
    var problems = [];
    var A = arrowEnd(slide, "from", el.getAttribute("data-from"));
    var B = arrowEnd(slide, "to",   el.getAttribute("data-to"));
    if (!el.hasAttribute("data-from")) A = { problem: "an arrow needs from=" };
    if (!el.hasAttribute("data-to"))   B = { problem: "an arrow needs to=" };
    if (A.problem) problems.push(A.problem);
    if (B.problem) problems.push(B.problem);

    var cs  = getComputedStyle(el);
    var w   = px(cs.getPropertyValue("--arrow-width"), 3);
    var gap = px(cs.getPropertyValue("--arrow-gap"), 4);
    var seg = (A.box && B.box) ? arrowSegment(A.box, B.box, gap) : null;
    if (A.box && B.box && !seg) {
      problems.push('the arrow from "' + el.getAttribute("data-from") + '" to "' +
                    el.getAttribute("data-to") + '" has no room: the two ends overlap or touch');
    }
    el.arrowProblems = problems;

    var svg = null;
    for (var c = el.firstChild; c; c = c.nextSibling) {
      if (c.nodeName.toLowerCase() === "svg") { svg = c; break; }
    }
    var o = seg ? offsetIn(el, slide) : null;
    if (!seg || !o) {
      if (svg) svg.style.display = "none";
      return;
    }
    if (!svg) {
      svg = document.createElementNS(SVGNS, "svg");
      svg.setAttribute("class", "arrow-svg");
      svg.setAttribute("aria-hidden", "true");
      var shaft = document.createElementNS(SVGNS, "path");
      shaft.setAttribute("class", "arrow-shaft");
      var head = document.createElementNS(SVGNS, "path");
      head.setAttribute("class", "arrow-head");
      svg.appendChild(shaft);
      svg.appendChild(head);
      el.appendChild(svg);
    }
    var W = slide.clientWidth, H = slide.clientHeight;
    svg.style.display = "";
    svg.style.left = (-o.x) + "px";
    svg.style.top  = (-o.y) + "px";
    svg.setAttribute("width", W);
    svg.setAttribute("height", H);
    svg.setAttribute("viewBox", "0 0 " + W + " " + H);

    /* The head: a filled triangle, tip on the end point, 4.5 strokes long  */
    /* (Rony's LibreOffice arrows are about 4.3) and never under 12px, but   */
    /* never more than 60% of a short arrow. The shaft stops inside the head */
    /* so its square end cannot show past the point.                        */
    var x1 = seg[0], y1 = seg[1], x2 = seg[2], y2 = seg[3];
    var dx = x2 - x1, dy = y2 - y1, len = Math.sqrt(dx * dx + dy * dy);
    var ux = dx / len, uy = dy / len;
    var L  = Math.min(Math.max(4.5 * w, 12), 0.6 * len), half = 0.45 * L;
    var bx = x2 - ux * L, by = y2 - uy * L;
    var ex = x2 - ux * L * 0.8, ey = y2 - uy * L * 0.8;
    var f = function (n) { return Math.round(n * 100) / 100; };
    svg.childNodes[0].setAttribute("d", "M" + f(x1) + " " + f(y1) + "L" + f(ex) + " " + f(ey));
    svg.childNodes[1].setAttribute("d",
      "M" + f(x2) + " " + f(y2) +
      "L" + f(bx - uy * half) + " " + f(by + ux * half) +
      "L" + f(bx + uy * half) + " " + f(by - ux * half) + "Z");
  }

  /* A paragraph that holds only arrows (two spans on consecutive lines are   */
  /* one paragraph) must not keep a blank line in the slide.                 */
  function mountArrows(slide) {
    arrowsOf(slide).forEach(function (el) {
      var p = el.parentElement;
      if (!p || p.tagName !== "P" || p.classList.contains("arrow")) return;
      var onlyArrows = Array.prototype.every.call(p.childNodes, function (n) {
        return n.nodeType === 1 ? n.classList.contains("arrow")
                                : !(n.nodeType === 3 && n.data.trim());
      });
      if (onlyArrows) p.classList.add("arrow-holder");
    });
  }

  function drawArrows(slide) {
    arrowsOf(slide).forEach(function (el) { drawArrow(slide, el); });
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

  /* Content is what FLOWS: title, body, code, tables. The furniture a master   */
  /* paints at the edges -- footer lines (presenter/affiliation/date), the logo */
  /* chrome, any deck-footer -- is positioned absolutely and is NOT content, so */
  /* it must not count toward the bottom. Testing for absolute positioning is   */
  /* the general rule (it is exactly what takes a box out of the flow), so this */
  /* stays correct whatever a master names its furniture, instead of chasing a  */
  /* class list. Before this, the footer's own lines were measured as overflow, */
  /* which is why fitHeight flagged slides that fit fine.                       */
  function contentBottom(slide) {
    var max = 0;
    for (var i = 0; i < slide.children.length; i++) {
      var c = slide.children[i];
      if (c.classList.contains("deck-footer")) continue;
      if (getComputedStyle(c).position === "absolute") continue;
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
    recClose();                         /* the visit to the slide left ends   */
    cancelTimers();                     /* leaving a slide stops its timers   */
    cancelChain();                      /* ...and any afterPrevious cascade   */
    slides[current].classList.remove("current", "anim-in", "anim-back");
    current = n;
    var slide = slides[current];
    slide.classList.add("current");
    slidePause(slide);                  /* a .pause slide stops the timer     */
    slideShownAt = Date.now();
    recOpen();                          /* ...and the visit to this one starts */
    if (clockOn) drawClock();
    noteSection();
    triggerPageAnim(slide, dir);

    setAllFragments(slide, !!enterFromEnd);
    fitHeight(slide);                   /* only measurable once it is visible */
    fitBoxes(slide);

    updateProgress();
    updateHash();
    updateLive();
    if (!enterFromEnd) {
      scheduleTimers(slide);            /* time-driven reveal, if any         */
      startEntryChain(slide);           /* a leading afterPrevious, if any    */
    }
  }

  function next() {
    talkGoesOn();
    if (revealNext(slides[current])) { cancelTimers(); return; }
    if (current < slides.length - 1) showSlide(current + 1, false);
  }

  function prev() {
    talkGoesOn();
    if (hideLast(slides[current])) { cancelTimers(); return; }
    if (current > 0) showSlide(current - 1, true);
  }

  /* Slide-to-slide extremes (Ctrl+Home / Ctrl+End). */
  /* Leafing (Alt+PageDown / Alt+PageUp): the slide next door, finished --    */
  /* every fragment shown -- and still: the deck carries .leafing for the     */
  /* moment of the change, and anim.css turns every transition off under it.  */
  /* Nothing is scheduled on arrival (a finished slide has no timers left),   */
  /* so the next plain key goes on from the end of that slide.                */
  var leafTimer = null;
  function leaf(step) {
    var n = current + step;
    if (n < 0 || n >= slides.length) return;
    talkGoesOn();
    var root = document.documentElement;
    root.classList.add("leafing");
    showSlide(n, true, 0);
    /* The page animation is a class, not a moment: left on, it would start  */
    /* as soon as .leafing came off.                                         */
    slides[n].classList.remove("anim-in", "anim-back");
    clearTimeout(leafTimer);
    leafTimer = setTimeout(function () { root.classList.remove("leafing"); }, 60);
  }

  function firstSlide() { talkGoesOn(); showSlide(0, false, 0); }
  function lastSlide()  { talkGoesOn(); showSlide(slides.length - 1, true, 0); }

  /* Intra-slide extremes (Home / End): show this slide at its start or end,   */
  /* skipping every animation. This is Rony's KISS answer to indexed builds:   */
  /* no arbitrary jump, just "beginning" and "end" of the current slide.       */
  function slideToStart() {
    talkGoesOn();
    cancelTimers();
    setAllFragments(slides[current], false);
  }
  function slideToEnd() {
    talkGoesOn();
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
    var frags = stepsOf(slide);           /* the clock counts presses, not fragments */
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

  /* The content must not climb into the bottom band; fitHeight subtracts this */
  /* to know where the usable area ends. This is LAYOUT geometry (how much air */
  /* the body gets), not a footer concept -- the band exists whether or not    */
  /* anything is painted in it. --skin-footer-height is the skin's to set.   */
  function footerBand() {
    var css = getComputedStyle(document.documentElement);
    return parseFloat(css.getPropertyValue("--skin-footer-height")) || 64;
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
     the title page -- all of that is the skin/master's CSS. One datum, two
     spellings, zero opinions about the footer. */
  function numberSlides() {
    var total = slides.length;
    slides.forEach(function (s, i) {
      var page = i + 1;
      s.setAttribute("data-page", String(page));
      s.setAttribute("data-total", String(total));
      s.style.setProperty("--page", String(page));
      s.style.setProperty("--total", String(total));
      fillPagePlaceholders(s, page, total);
    });
  }

  /* The margin boxes (header/footer x left/center/right) carry their text with
     {page}/{total} left as literal placeholders by the build -- those are the
     two values only the runtime knows, and they change on renumbering. Here we
     substitute them in each box's text. The box's ORIGINAL template (with the
     braces) is stashed in data-tmpl on first pass, so re-numbering always
     substitutes from the template and never from an already-filled string.
     A box with no placeholder is left untouched. {pages} is the number of
     slides ({total-pages} and {totalpages} are accepted spellings of it);
     {total} is the talk's length, from the timer: block (Rony, 25-Sep). */
  function fillPagePlaceholders(slide, page, total) {
    var boxes = slide.querySelectorAll(".margin .m-left, .margin .m-center, .margin .m-right");
    boxes.forEach(function (b) {
      /* A box may carry markup (a skin template like {presenter}<br>{page}), so
         read and write innerHTML, not textContent -- textContent would flatten
         the <br> into a literal and the two-line footers would collapse onto one
         line. The original template (with the braces) is stashed in data-tmpl on
         first pass so re-numbering always substitutes from the template. */
      var tmpl = b.getAttribute("data-tmpl");
      if (tmpl === null) {                 /* first pass: remember the template */
        tmpl = b.innerHTML;
        if (tmpl.indexOf("{") < 0) return; /* nothing to fill, ever */
        b.setAttribute("data-tmpl", tmpl);
      }
      var sec = sectionAt(page - 1);
      readTimer();
      b.innerHTML = tmpl
        .replace(/\{(clock|elapsed|remaining|section-remaining|section-elapsed)\}/gi, function (m, name) {
          return '<span class="live" data-live="' + name.toLowerCase() + '"></span>';
        })
        /* The section fields that do not tick: known from the deck alone, so  */
        /* written as text, like {page}, and printed.                          */
        .replace(/\{section\}/gi, sec && sec.num ? String(sec.num) : "")
        .replace(/\{sections\}/gi, sec ? String(sec.count) : "")
        .replace(/\{section-total\}/gi, sec ? fmtLength(sec.dur) : "")
        .replace(/\{total\}/gi, TIMER.total !== null ? fmtLength(TIMER.total) : "")
        .replace(/\{page\}/gi, String(page))
        .replace(/\{total-pages\}/gi, String(total))
        .replace(/\{totalpages\}/gi, String(total))
        .replace(/\{pages\}/gi, String(total));
    });
  }

  /* Margin boxes that do not fit their band are shrunk until they do: a      */
  /* footer that says more than the skin planned for -- a long credit, three  */
  /* lines where the band holds two, the authors of a slide piling up over    */
  /* the years -- stays inside the band, smaller, instead of spilling off the */
  /* slide or over the content. The shrink is CSS zoom, so everything in the  */
  /* box scales together, including parts a master sized in px (WU's          */
  /* affiliation line). It stops at MARGIN_FLOOR of the box's own size: past  */
  /* that the text is not worth reading, and the box is left marked           */
  /* data-clipped for the diagnose mode to report (the fix is the author's:   */
  /* less text, or header:/footer: font-size, or a taller band in the skin).  */
  /* Measured on the current slide only (the others are display:none), each  */
  /* time it is shown -- six boxes, a few layouts, and the web fonts may have */
  /* arrived since the last time.                                             */
  var MARGIN_FLOOR = 0.5;
  function boxOverflows(b, region) {
    var rb = b.getBoundingClientRect(), rr = region.getBoundingClientRect();
    if (rb.height > rr.height + 1) return true;          /* taller than the band */
    return b.scrollWidth > b.clientWidth + 1;            /* a word wider than it */
  }
  function fitMargins(slide) {
    slide.querySelectorAll(".margin").forEach(function (region) {
      if (!region.getBoundingClientRect().height) return;  /* no band (header 0) */
      /* All three back to full size first, then the centre, then the sides: */
      /* the centre column is sized by its content and takes its width from   */
      /* theirs, so a side measured beside an unfitted centre would shrink for */
      /* room the centre is about to give back. One order, one result.        */
      var boxes = [".m-center", ".m-left", ".m-right"].map(function (q) {
        return region.querySelector(q);
      }).filter(Boolean);
      boxes.forEach(function (b) {
        b.style.zoom = "";
        b.removeAttribute("data-fit");
        b.removeAttribute("data-clipped");
      });
      boxes.forEach(function (b) {
        if (!b.textContent.trim()) return;
        var z = 1;
        while (boxOverflows(b, region) && z > MARGIN_FLOOR) {
          z = Math.max(MARGIN_FLOOR, z * 0.92);
          b.style.zoom = z.toFixed(3);
        }
        if (z < 1) b.setAttribute("data-fit", Math.round(z * 100));
        if (boxOverflows(b, region)) b.setAttribute("data-clipped", "1");
      });
      /* One size for the whole band: every box takes the smallest zoom any  */
      /* of them needed. Three boxes of a footer in three sizes read as three */
      /* footers (Rony); smaller than needed only ever makes more room.       */
      var zmin = 1;
      boxes.forEach(function (b) {
        if (b.style.zoom) zmin = Math.min(zmin, parseFloat(b.style.zoom));
      });
      if (zmin < 1) boxes.forEach(function (b) {
        if (!b.textContent.trim()) return;
        b.style.zoom = zmin.toFixed(3);
        b.setAttribute("data-fit", Math.round(zmin * 100));
      });
    });
  }

  /* Titles that do not fit their zone are shrunk too, by the same rule.     */
  /* A master gives the title a FIXED zone (the band whose rule, or filled    */
  /* background, must not move), and places the kicker and, on a cover, the  */
  /* subtitle beside it out of the flow. A title with more lines than the    */
  /* zone was drawn for used to spill out of it -- upwards, over the kicker   */
  /* and the header, when the master sits the text on the band's base (Rony: */
  /* a three-line title "distorted and reaching" the top of the slide).       */
  /* Now the title's CONTENT is zoomed down until it is inside its zone and   */
  /* clear of the kicker and subtitle; the zone itself never moves, so the    */
  /* rule stays where every other slide has it. The same floor as the margin  */
  /* boxes: past half size the title is left marked data-clipped for the     */
  /* diagnose mode (the fix is the author's -- a shorter title). The subtitle */
  /* gets the same treatment against the title and the kicker, and before    */
  /* the title does.                                                          */
  var TITLE_FLOOR = 0.5;
  /* Where a box's text is: its lines' boxes top to bottom (the blocks it    */
  /* holds, or itself), and the ink left to right (a block is as wide as its */
  /* zone, the words are not). A Range's own top and bottom are the font's   */
  /* full ascent and descent, taller than the line box the master sized the  */
  /* zone for, so they would flag every title as too tall.                    */
  function textRect(el) {
    var r = document.createRange();
    r.selectNodeContents(el);
    var ink = r.getBoundingClientRect();
    var blocks = el.children.length ? el.children : [el];
    var top = Infinity, bottom = -Infinity;
    Array.prototype.forEach.call(blocks, function (b) {
      var br = b.getBoundingClientRect();
      if (!br.height) return;
      top = Math.min(top, br.top);
      bottom = Math.max(bottom, br.bottom);
    });
    if (top === Infinity) return { left: 0, right: 0, top: 0, bottom: 0, width: 0, height: 0 };
    return { left: ink.left, right: ink.right, top: top, bottom: bottom,
             width: ink.width, height: bottom - top };
  }
  /* Two boxes of text meet when their lines overlap by more than tol. A    */
  /* line box carries half-leading above and below the letters, so two       */
  /* lines a master set flush can overlap by a pixel or two with no letter   */
  /* touching (WU's cover: subtitle and title, 2px); tol absorbs that.       */
  function rectsMeet(a, b, tol) {
    if (!a.width || !a.height || !b.width || !b.height) return false;
    return a.left < b.right - 1 && b.left < a.right - 1 &&
           a.top < b.bottom - tol && b.top < a.bottom - tol;
  }
  function zoneOverflows(box, others) {
    var br = box.getBoundingClientRect();
    if (!box.offsetHeight) return false;
    var k = br.height / box.offsetHeight;            /* the stage's scale   */
    var cs = getComputedStyle(box);
    var top    = br.top    + k * (parseFloat(cs.borderTopWidth) + parseFloat(cs.paddingTop));
    var bottom = br.bottom - k * (parseFloat(cs.borderBottomWidth) + parseFloat(cs.paddingBottom));
    var t = textRect(box);
    if (t.height && (t.top < top - 1 || t.bottom > bottom + 1)) return true;
    if (box.scrollWidth > box.clientWidth + 1) return true;  /* a long word */
    for (var i = 0; i < others.length; i++) {
      if (rectsMeet(t, textRect(others[i]), 4 * k)) return true;
    }
    return false;
  }
  function fitTitles(slide) {
    var zones = [], placed = [];
    for (var i = 0; i < slide.children.length; i++) {
      var c = slide.children[i];
      /* The subtitle gives way first: on a cover where the two meet, the    */
      /* secondary line shrinks (often back to one line) before the title   */
      /* does. (WU's cover: a two-line subtitle ran down into the title.)    */
      if (c.classList.contains("subtitle")) zones.unshift(c);
      else if (c.classList.contains("title")) zones.push(c);
      if (c.classList.contains("kicker")) placed.push(c);
    }
    zones.forEach(function (box) {
      box.removeAttribute("data-fit");
      box.removeAttribute("data-clipped");
      Array.prototype.forEach.call(box.children, function (ch) { ch.style.zoom = ""; });
    });
    zones.forEach(function (box) {
      if (!box.textContent.trim() || !box.children.length) return;
      var others = placed.concat(zones.filter(function (z) { return z !== box; }));
      var z = 1;
      while (zoneOverflows(box, others) && z > TITLE_FLOOR) {
        z = Math.max(TITLE_FLOOR, z * 0.92);
        Array.prototype.forEach.call(box.children, function (ch) {
          ch.style.zoom = z.toFixed(3);
        });
      }
      if (z < 1) box.setAttribute("data-fit", Math.round(z * 100));
      if (zoneOverflows(box, others)) box.setAttribute("data-clipped", "1");
    });
  }

  /* The boxes a slide fits to their room: margins, then title and subtitle. */
  /* Arrows come last: they are drawn between boxes, so they must be measured */
  /* once everything else on the slide has settled. fitBoxes already runs     */
  /* wherever a slide's layout can change -- shown, fonts in, printing, the   */
  /* health scan -- so that is exactly where an arrow has to be redrawn.     */
  function fitBoxes(slide) {
    fitMargins(slide);
    fitTitles(slide);
    drawArrows(slide);
  }

  /* Every slide at once, for paper: printing lays out all the slides, and a  */
  /* box fitted only when its slide was on screen would print unfitted. A     */
  /* slide can only be measured while it is .current (the others are         */
  /* display:none), so each takes a turn, as in scanHealth, and the deck is   */
  /* left on the slide it was on. Run at start-up, when the fonts arrive, and */
  /* just before printing.                                                    */
  function fitAllBoxes() {
    var start = current;
    slides.forEach(function (s) {
      if (s !== slides[start]) {
        slides[start].classList.remove("current");
        s.classList.add("current");
      }
      fitBoxes(s);
      if (s !== slides[start]) {
        s.classList.remove("current");
        slides[start].classList.add("current");
      }
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
  /* Help (F1). The keys of the deck, in one place.                           */
  /*                                                                          */
  /* F1 and not "?" or "h". A letter cannot be a command here: the go overlay  */
  /* takes words now, so "h" typed into it is an h. F1 is not a character      */
  /* anyone types, which is what lets this one key work everywhere, including  */
  /* inside the two overlays -- and that matters, because a dialog is exactly  */
  /* where somebody wonders what the keys are.                                 */
  /*                                                                          */
  /* The list is a table and not prose so that a test can read it: a key       */
  /* added to the handler and forgotten here is caught by Spotlight.testGroup, */
  /* which is the only thing standing between this and the drift that left     */
  /* "s" undocumented until Rony had to discover it for himself.               */
  /* ---------------------------------------------------------------------- */

  var HELP = [
    ["&rarr; &darr; PageDown Space", "Advance: next fragment, then next slide"],
    ["&larr; &uarr; PageUp Backspace", "Go back"],
    ["Alt+PageDown / Alt+PageUp", "Next / previous slide at once, complete, no animations"],
    ["Home / End", "Start / end of this slide"],
    ["Ctrl+Home / Ctrl+End", "First / last slide"],
    ["g", "Go to a slide: pick one, type its number, or search the deck"],
    ["0-9", "The same, with the number already typed"],
    ["s", "Choose the Rexx highlighting style"],
    ["d", "Diagnose: show deck-health problems (overflowing slides)"],
    ["a", "About this deck: the file, the build, the tools"],
    ["t", "Timer: time elapsed and left (it starts with full screen, and goes on through a reload)"],
    ["Esc / t on a red popup", "Over time: no more overtime popups until the timer restarts"],
    ["r", "Restart the timer from 0:00 (press twice)"],
    ["p", "Pause the timer (it asks how long: minutes, a time, only a message, or none), or resume it; going on resumes it too"],
    ["c", "Countdown over the slide: minutes (5) or a time of day (17:00); none takes it away"],
    ["m", "Measure: the time on this slide, in the top left corner (rehearsing)"],
    ["h", "How the time went: per slide and section, most and least, runs compared"],
    ["b / w", "Blank the screen to black / white"],
    ["f", "Fullscreen"],
    ["Esc", "Clear a blank screen, or close what is open"],
    ["F1", "This list"]
  ];

  /* The go dialog has keys of its OWN, and they are not the deck's: inside a  */
  /* list, PageDown is a listful and not a slide. They were not written down   */
  /* anywhere, which is the same hole the "s" key fell through -- the arrows   */
  /* and Enter are guessable, but nobody guesses that Ctrl+Right walks the     */
  /* sections. So they are a table too, listed under their own subhead.        */
  /*                                                                          */
  /* The third column is not shown: it is the raw e.key names the row covers,  */
  /* so Spotlight.testGroup can hold this table to the handler the way it      */
  /* already holds HELP to the deck's switch. A key answered in the overlay    */
  /* and missing here fails the build.                                        */
  var HELP_GO = [
    ["&uarr; &darr;", "Select the previous / next entry",
     "ArrowUp ArrowDown"],
    ["PageUp / PageDown", "A listful at a time",
     "PageUp PageDown"],
    ["Home / End <span class='hk-alt'>(or with Ctrl)</span>",
     "First / last entry of the list", "Home End"],
    ["Ctrl+&larr; / Ctrl+&rarr;", "Previous / next section entry",
     "ArrowLeft ArrowRight"],
    ["Enter", "Go to the selected entry (or to the number you typed)", "Enter"],
    ["Esc", "Close the dialog", "Escape"]
  ];

  var helpBox = null;

  function helpRows(table) {
    var rows = "";
    for (var i = 0; i < table.length; i++) {
      rows += '<div class="hk-row"><span class="hk-keys">' + table[i][0] +
              '</span><span class="hk-what">' + table[i][1] + '</span></div>';
    }
    return rows;
  }

  function buildHelp() {
    helpBox = document.createElement("div");
    helpBox.id = "help-overlay";
    helpBox.innerHTML =
      '<div class="jo-panel">' +
        '<div class="jo-head"><span>Keys</span></div>' +
        /* Two columns, because the two tables together are taller than the    */
        /* panel and the panel's own scrollbar is the one thing this list must */
        /* not depend on: whatever falls below the fold here is, by            */
        /* definition, a key nobody knows to look for. They wrap to one        */
        /* column when there is no width for two.                             */
        '<div class="jo-list"><div class="hk-cols">' +
          '<div class="hk-col">' + helpRows(HELP) + '</div>' +
          '<div class="hk-col">' +
            '<div class="hk-sub">In the go dialog (g)</div>' + helpRows(HELP_GO) +
            /* The mouse paragraph closes the SHORTER column: it belongs to    */
            /* neither table, and hanging it under the longer one is what      */
            /* pushed the whole panel past the fold.                          */
            '<div class="hk-note">A click advances the slide; a click on the ' +
            'left eighth goes back. Selecting text with the mouse does not ' +
            'navigate, so what is on a slide stays copyable.</div>' +
            '<div class="hk-note"><a href="#" class="hk-about">About this deck</a> ' +
            '(a): the file, the build, the tools.</div>' +
          '</div>' +
        '</div></div>' +
        '<div class="jo-hint">F1 or Esc to close</div>' +
      '</div>';
    document.body.appendChild(helpBox);
    helpBox.addEventListener("click", function (e) {
      if (e.target === helpBox) closeHelp();
    });
    helpBox.querySelector(".hk-about").addEventListener("click", function (e) {
      e.preventDefault();
      openAbout();
    });
  }

  function helpOpen() { return helpBox && helpBox.classList.contains("open"); }

  function closeHelp() {
    if (helpBox) helpBox.classList.remove("open");
    /* Hand the keyboard back to whatever raised the help, so F1 in the middle */
    /* of a search does not cost the search.                                   */
    if (overlayOpen() && jumpInput) jumpInput.focus();
    else if (!styleOverlayOpen()) focusStage();
  }

  function toggleHelp() {
    if (!helpBox) buildHelp();
    if (helpOpen()) closeHelp();
    else helpBox.classList.add("open");
  }


  /* ---------------------------------------------------------------------- */
  /* About (a, or the link at the foot of F1). What this deck is and how it   */
  /* was made: the file, the build, the tools and their versions, the        */
  /* command, where to get it all -- and the counts, made here from the deck  */
  /* itself. md2slides writes only what the deck's about: block lets out     */
  /* (#deck-about, JSON); a group turned off is not in the file at all.       */
  /* about: print: yes adds the same page after the last slide, on paper.     */
  /* ---------------------------------------------------------------------- */

  var aboutBox = null;

  function aboutFacts() {
    var el = document.getElementById("deck-about");
    if (!el) return null;
    try { return JSON.parse(el.textContent); } catch (e) { return null; }
  }

  function esc(t) {
    return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  function kb(bytes) {
    var n = parseInt(bytes, 10);
    if (isNaN(n)) return "";
    return (n < 1024 ? n + " bytes" : (n / 1024).toFixed(1) + " KB") +
           " (" + n.toLocaleString("en-US") + " bytes)";
  }

  /* The counts: what anyone could count by walking the deck. */
  function deckCounts() {
    var steps = 0, code = 0, pics = 0, tables = 0;
    slides.forEach(function (s) {
      steps  += stepsOf(s).length;
      code   += s.querySelectorAll(".code").length;
      pics   += s.querySelectorAll("img").length;
      tables += s.querySelectorAll("table").length;
    });
    return [["Slides", slides.length],
            ["Steps", steps + " (key presses that reveal a fragment)"],
            ["Program listings", code],
            ["Pictures", pics],
            ["Tables", tables]];
  }

  function aboutRows(rows) {
    var h = "";
    rows.forEach(function (r) {
      if (r[1] === undefined || r[1] === null || r[1] === "") return;
      h += '<div class="ab-row"><span class="ab-key">' + esc(r[0]) +
           '</span><span class="ab-val">' + r[1] + '</span></div>';
    });
    return h;
  }

  function aboutHTML(facts) {
    var h = '<div class="ab-title">' + esc(document.title) + '</div>';
    var d = facts.deck;
    if (d) {
      h += '<div class="ab-sub">The deck</div>' + aboutRows([
        ["File", esc(d.file)],
        ["Size", esc(kb(d.size))],
        ["Last changed", esc(d.modified)],
        ["Built", esc(d.built) + (d.seconds ? " (in " + esc(d.seconds) + " s)" : "")],
        ["Skin", esc(d.skin)],
        ["Masters", esc(d.masters)]
      ]);
    }
    h += '<div class="ab-sub">Contents</div>' +
         aboutRows(deckCounts().map(function (r) { return [r[0], esc(r[1])]; }));
    var y = facts.system;
    if (y) {
      h += '<div class="ab-sub">Built with</div>' + aboutRows([
        ["Operating system", esc(y.os)],
        ["ooRexx", esc(y.oorexx)],
        ["Pandoc", esc(y.pandoc)],
        ["md2slides", esc(y.parser)]
      ]);
    }
    if (!facts.groups || facts.groups.timing !== false) h += aboutTiming();
    if (facts.command) {
      h += '<div class="ab-sub">Command</div>' +
           '<div class="ab-cmd">' + esc(facts.command) + '</div>';
    }
    if (facts.links) {
      h += '<div class="ab-sub">Where to get it</div>' + aboutRows(
        facts.links.map(function (l) {
          return [l[0], '<a href="' + esc(l[1]) + '" target="_blank" rel="noopener">' +
                        esc(l[1]) + '</a>'];
        }));
    }
    return h;
  }

  /* Timing (Rony, 23-Sep): the plan of the talk, as the deck sets it -- the */
  /* total, the warnings, each section with its time and its slides, and    */
  /* the .pause slides. Nothing at all for a deck with no timing in it.     */
  function minutes(sec) {
    var m = sec / 60;
    return (Math.round(m) === m ? String(m) : fmtTime(sec)) + " min";
  }
  function slideRange(a, b) {            /* 0-based, inclusive */
    return a === b ? "slide " + (a + 1) : "slides " + (a + 1) + "–" + (b + 1);
  }
  function aboutTiming() {
    readTimer();
    var tab = sectionTable(), timed = tab.timed, rows = [];
    var pauses = [], counts = [];
    slides.forEach(function (s, i) {
      if (isPauseSlide(s)) pauses.push(i);
      var c = s.getAttribute("data-countdown");
      var cs = c && parseCountdown(c);
      if (cs) counts.push("slide " + (i + 1) + " (" + c + (cs.clock ? "" : " min") + ")");
    });
    if (TIMER.total === null && !timed.length && !pauses.length && !counts.length) return "";
    if (TIMER.total !== null) rows.push(["Total", esc(minutes(TIMER.total))]);
    if (TIMER.total !== null && TIMER.warn.length)
      rows.push(["Warnings", esc(TIMER.warn.map(function (w) { return minutes(w).slice(0, -4); })
                 .join(", ").replace(/, ([^,]*)$/, " and $1") + " min before the end")]);
    function pausesIn(a, b) {
      var p = pauses.filter(function (i) { return i >= a && i <= b; });
      return p.length ? "; pause on " + (p.length === 1 ? "slide " : "slides ") +
                        p.map(function (i) { return i + 1; }).join(", ") : "";
    }
    if (timed.length && timed[0].i > 0)
      rows.push(["Before the sections", esc((tab.pre > 0 ? minutes(tab.pre) + ", " : "") +
                 slideRange(0, timed[0].i - 1) + pausesIn(0, timed[0].i - 1))]);
    timed.forEach(function (t, k) {
      var last = k + 1 < timed.length ? timed[k + 1].i - 1 : slides.length - 1;
      rows.push(["Section " + t.num, esc("“" + t.name + "”: " + minutes(t.dur) + ", " +
                 slideRange(t.i, last) + pausesIn(t.i, last))]);
    });
    if (!timed.length && pauses.length)
      rows.push(["Pauses", esc((pauses.length === 1 ? "slide " : "slides ") +
                 pauses.map(function (i) { return i + 1; }).join(", "))]);
    if (counts.length) rows.push(["Countdowns", esc(counts.join(", "))]);
    return '<div class="ab-sub">Timing</div>' + aboutRows(rows);
  }

  function buildAbout() {
    var facts = aboutFacts();
    aboutBox = document.createElement("div");
    aboutBox.id = "about-overlay";
    aboutBox.innerHTML =
      '<div class="jo-panel">' +
        '<div class="jo-head"><span>About this deck</span></div>' +
        '<div class="jo-list">' +
          (facts ? aboutHTML(facts)
                 : '<div class="ab-row">This deck was built without an about page ' +
                   '(<code>about: no</code>).</div>') +
        '</div>' +
        '<div class="jo-hint">a or Esc to close</div>' +
      '</div>';
    document.body.appendChild(aboutBox);
    aboutBox.addEventListener("click", function (e) {
      if (e.target === aboutBox) closeAbout();
    });
  }

  function aboutOpen() { return aboutBox && aboutBox.classList.contains("open"); }
  function closeAbout() {
    if (aboutBox) aboutBox.classList.remove("open");
    focusStage();
  }
  function openAbout() {
    if (helpOpen()) closeHelp();
    if (!aboutBox) buildAbout();
    aboutBox.classList.add("open");
  }

  /* On paper, after the last slide: a page of the deck's own size, never a  */
  /* slide (it is not in `slides`, so nothing walks, numbers or fits it).    */
  function mountAboutSheet() {
    var facts = aboutFacts();
    if (!facts || !facts.print) return;
    var sheet = document.createElement("section");
    sheet.className = "slide about-sheet";
    sheet.innerHTML = '<div class="ab-page">' + aboutHTML(facts) + '</div>';
    stage.appendChild(sheet);
  }


  /* ---------------------------------------------------------------------- */
  /* The presenter's timer (Rony, 23-Sep).                                   */
  /*                                                                        */
  /* It starts the first time the deck goes full screen (the f key, or the  */
  /* browser's own F11), and from then on it runs: leaving full screen, a   */
  /* black or white screen, going back and forth -- none of that touches it.*/
  /* Only R restarts it (pressed twice, so a stray key cannot cost the      */
  /* presenter the talk's timing). It survives a reload of the page, in the */
  /* same tab.                                                              */
  /*                                                                        */
  /* The deck's timer: block (#deck-timer) may give a total, warning marks  */
  /* before the end, and the interval for the last minute; a slide may open */
  /* a section with time=N. Then: a popup at each mark ("5 minutes left");  */
  /* in the last minute, one every `interval` seconds; once the time is up, */
  /* a red one with the overtime, once a minute, for as long as the talk    */
  /* goes on (Esc or T on one: no more). A popup goes away with the next   */
  /* key or click, which still does what it always does. T shows where the */
  /* talk stands, the same way. And {clock}, {elapsed}, {remaining},       */
  /* {section-remaining},                                                   */
  /* {section-elapsed} can be put in any header or footer box: they are    */
  /* kept live, and blank until the timer starts. {total}, {section},       */
  /* {sections} and {section-total} do not tick: they are written once,     */
  /* like {page}. With no time= anywhere, the whole talk is one section.    */
  /*                                                                        */
  /* Pausing (Rony, 23-Sep, for intermissions): P pauses and resumes; a     */
  /* slide with .pause (or .startPause) pauses when it is shown, and the    */
  /* talk going on -- the next step or slide, by key or click, a jump --    */
  /* resumes, whoever made the pause, and takes the break panel away        */
  /* (Rony, 26-Sep: a P pause used to wait for P, and its panel stayed up   */
  /* over a slide that was moving on under it). Showing a slide is not the */
  /* talk going on: a reload keeps the pause. While paused every timed      */
  /* value stands still, on screen; only {clock}, the time of day, goes on. */
  /* ---------------------------------------------------------------------- */

  var TIMER = { total: null, warn: [300, 60], interval: 10, where: "footer",
                seconds: 180, sound: false, pauseMessage: "", countdownMessage: "",
                record: false };
  var tStart = null, tFired = {}, tBeat = null, tTick = null;
  /* Overtime: the last whole minute over that was announced, and whether  */
  /* the presenter said "I know" (Esc or T over a red popup). See timerTick.*/
  var tOver = null, tMuted = false;
  var tPaused = null, tPauseKind = "", timerRead = false;
  var tSecIn = {};                      /* section number -> elapsed() on entry */
  var toastEl = null, toastKind = "", resetArmed = 0;
  var TKEY = "md2slides.timer:" + location.pathname;

  function readTimer() {
    if (timerRead) return;
    timerRead = true;
    var el = document.getElementById("deck-timer");
    if (!el) return;
    try {
      var j = JSON.parse(el.textContent);
      for (var k in j) if (j.hasOwnProperty(k)) TIMER[k] = j[k];
    } catch (e) { /* a deck without a usable timer: block keeps the defaults */ }
  }

  function pad2(n) { return (n < 10 ? "0" : "") + n; }
  function fmtTime(sec) {
    sec = Math.max(0, Math.round(sec));
    var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
    return (h ? h + ":" + pad2(m) : String(m)) + ":" + pad2(s);
  }
  function elapsed() {
    if (tStart === null) return 0;
    return ((tPaused !== null ? tPaused : Date.now()) - tStart) / 1000;
  }
  function remaining() { return TIMER.total === null ? null : TIMER.total - elapsed(); }
  function signed(rem) {
    rem = Math.round(rem);
    return rem >= 0 ? fmtTime(rem) : "+" + fmtTime(-rem);
  }

  /* What moves on screen moves once a minute, with the seconds at 00, and  */
  /* every second only in the last TIMER.seconds (3 minutes by default) and */
  /* in the overtime (Rony, 24-Sep: a figure changing every second draws    */
  /* the eye while one explains). null: always seconds; 0: never.          */
  function inSeconds(rem) {
    if (TIMER.seconds === null) return true;
    return rem !== null && rem <= TIMER.seconds;
  }
  /* Whole minutes are written as a bare number of minutes, "45" -- not    */
  /* "45:00", and not "0:45" as hours, which would read like minutes and   */
  /* seconds (Rony, 25-Sep). Minutes and seconds, "2:59", only when the    */
  /* seconds are shown (the last switch-to-seconds: minutes, the overtime).*/
  /* A time left: rounded up to the minute (it never shows less than there */
  /* is); the overtime, signed and in seconds.                             */
  function fmtLeft(rem) {
    if (rem <= 0) return rem > -0.5 ? "0:00" : "+" + fmtMS(-rem);
    if (inSeconds(rem)) return fmtMS(Math.ceil(rem));
    return String(Math.ceil(rem / 60));
  }
  /* A time used: rounded down to the minute unless `rem`, the time left    */
  /* against it, is in its last minutes.                                    */
  function fmtUsed(used, rem) {
    if (inSeconds(rem)) return fmtMS(Math.floor(used));
    return String(Math.floor(used / 60));
  }
  /* A planned length ({total}, {section-total}): minutes, "20"; "7:30"    */
  /* if it is not a whole number of them.                                  */
  function fmtLength(sec) {
    return sec % 60 === 0 ? String(sec / 60) : fmtMS(sec);
  }
  /* Minutes and seconds, with no hours: 87 minutes go "87", "87:01"...    */
  /* (the popups and T keep fmtTime, with hours).                          */
  function fmtMS(sec) {
    sec = Math.max(0, Math.round(sec));
    return Math.floor(sec / 60) + ":" + pad2(sec % 60);
  }

  /* The sections: each slide with a time= opens one, which runs to the    */
  /* next. Numbered from 1, with their planned start and end counted from  */
  /* the start of the talk. Slides before the first section get what the   */
  /* total leaves over, as a section 0 with no number of its own.          */
  var sectionList = null;
  function sectionTable() {
    if (sectionList) return sectionList;
    readTimer();
    var timed = [];
    slides.forEach(function (s, i) {
      var t = parseFloat(s.getAttribute("data-time"));
      if (t > 0) timed.push({ i: i, dur: t * 60, slide: s });
    });
    var sum = 0;
    timed.forEach(function (t) { sum += t.dur; });
    var pre = (timed.length && timed[0].i > 0 && TIMER.total !== null) ?
              Math.max(0, TIMER.total - sum) : 0;
    var at = pre;
    timed.forEach(function (t, k) {
      t.num = k + 1; t.start = at; at += t.dur; t.end = at;
      t.name = t.slide.getAttribute("data-section") || t.slide.getAttribute("data-title") ||
               ("slide " + (t.i + 1));
    });
    sectionList = { timed: timed, pre: pre };
    return sectionList;
  }
  /* The section slide i is in, or null. A talk with a total and no time= */
  /* anywhere is one section, all of it (Rony, 25-Sep): {section} 1 of     */
  /* {sections} 1, and the section's fields are the talk's.                */
  function sectionAt(i) {
    var tab = sectionTable(), timed = tab.timed;
    if (!timed.length)
      return TIMER.total !== null ? { num: 1, count: 1, start: 0, end: TIMER.total,
                                      dur: TIMER.total, name: "the talk", whole: true } : null;
    if (i < timed[0].i)
      return tab.pre > 0 ? { num: 0, count: timed.length, start: 0, end: tab.pre,
                             dur: tab.pre, name: "before the first section" } : null;
    for (var k = timed.length - 1; k >= 0; k--)
      if (timed[k].i <= i) {
        var t = timed[k];
        return { num: t.num, count: timed.length, start: t.start, end: t.end,
                 dur: t.dur, name: t.name };
      }
    return null;
  }
  function sectionNow() { return sectionAt(current); }

  function saveTimer() {
    try {
      if (tStart === null) sessionStorage.removeItem(TKEY);
      else sessionStorage.setItem(TKEY, JSON.stringify(
        { start: tStart, paused: tPaused, kind: tPauseKind, sections: tSecIn,
          muted: tMuted }));
    } catch (e) { /* no storage: the timer just does not survive a reload */ }
  }
  function loadTimer() {
    var v = null, j = null;
    try { v = sessionStorage.getItem(TKEY); } catch (e) { v = null; }
    if (!v) return;
    try { j = JSON.parse(v); } catch (e) { j = null; }
    if (typeof j === "number") j = { start: j, paused: null, kind: "" };
    if (!j || typeof j.start !== "number") return;
    tStart = j.start;
    tPaused = typeof j.paused === "number" ? j.paused : null;
    tPauseKind = tPaused !== null ? (j.kind || "key") : "";
    tSecIn = (j.sections && typeof j.sections === "object") ? j.sections : {};
    tMuted = j.muted === true;
    passMarks();
    ensureTick();
  }
  /* Marks already behind us are not announced again (a reload, a restart). */
  function passMarks() {
    var rem = remaining();
    tFired = {}; tBeat = null; tOver = null;
    if (rem === null) return;
    TIMER.warn.forEach(function (w) { if (rem < w) tFired[w] = 1; });
    if (rem <= 60) tBeat = Math.floor((60 - rem) / TIMER.interval);
    if (rem <= 0) tOver = Math.floor(-rem / 60);
  }
  /* The first time the talk reaches a section, on the timer's clock (so a  */
  /* pause does not count): where {section-elapsed} counts from.            */
  function noteSection() {
    if (tStart === null || !slides) return;
    var sec = sectionNow();
    if (!sec || tSecIn.hasOwnProperty(sec.num)) return;
    tSecIn[sec.num] = elapsed();
    saveTimer();
  }
  function startTimer() {
    if (tStart !== null) return;
    tHeld = false;
    tStart = Date.now();
    tSecIn = {};
    tMuted = false;
    recOpen();
    noteSection();
    passMarks();
    saveTimer();
    ensureTick();
    updateLive();
  }
  function restartTimer() {
    tStart = Date.now();
    tPaused = null; tPauseKind = "";
    tSecIn = {};
    tMuted = false;
    recRestart();
    noteSection();
    passMarks();
    saveTimer();
    ensureTick();
    updateLive();
    showToast("Timer restarted: 0:00", "info");
  }
  /* kind: "slide" (a .pause slide) or "key" (P). Both end when the talk   */
  /* goes on, or with P.                                                     */
  function pauseTimer(kind) {
    if (tStart === null || tPaused !== null) return false;
    recClose();
    tPaused = Date.now(); tPauseKind = kind;
    saveTimer();
    updateLive();
    return true;
  }
  function resumeTimer() {
    if (tPaused === null) return false;
    tStart += Date.now() - tPaused;
    tPaused = null; tPauseKind = "";
    recOpen();
    saveTimer();
    updateLive();
    if (CD && CD.kind === "pause") endCountdown();
    return true;
  }
  /* The talk goes on (a step, a slide, a jump): the pause is over. */
  function talkGoesOn() {
    if (tPaused !== null) resumeTimer();
    countdownTalkGoesOn();
  }
  function isPauseSlide(s) {
    return !!s && (s.classList.contains("pause") || s.classList.contains("startPause") ||
                   s.classList.contains("startpause") || s.hasAttribute("data-pause"));
  }
  /* The slide just shown: a .pause slide pauses, any other ends its pause. */
  function slidePause(s) {
    if (isPauseSlide(s)) {
      if (pauseTimer("slide")) {
        var v = s.getAttribute("data-pause"), spec = parseCountdown(v);
        /* pause="Questions": a message and no time, a break that counts up */
        if (!spec && v && v.trim() && !/^[\d.:]/.test(v.trim()))
          spec = { target: null, clock: false, text: "", msg: v.trim() };
        if (spec) startCountdown(spec, "pause");
      }
    }
    /* Only the pause a slide made ends here: a countdown waits for the    */
    /* talk to go on (next/prev), not for a slide to be shown (a reload).  */
    else if (tPauseKind === "slide") resumeTimer();
    slideCountdown(s);
  }

  function ensureTick() {
    if (!tTick) tTick = setInterval(timerTick, 1000);
  }

  function timerTick() {
    updateLive();
    if (tPaused !== null) return;       /* nothing moves: nothing to announce */
    var rem = remaining();
    if (rem === null) return;
    TIMER.warn.forEach(function (w) {
      if (!tFired[w] && rem <= w && rem > 60) {
        tFired[w] = 1;
        var m = Math.round(rem / 60);
        showToast(m + (m === 1 ? " minute" : " minutes") + " left", "warn");
      }
    });
    /* The last minute: one popup per interval (popup-every:). The 1-minute  */
    /* mark is the first of them, if the deck asks for it.                   */
    if (rem > 0 && rem <= 60) {
      var beat = Math.floor((60 - rem) / TIMER.interval);
      if (tBeat === null || beat !== tBeat) {
        var first = tBeat === null;
        tBeat = beat;
        if (first && TIMER.warn.indexOf(60) < 0 && rem > 60 - TIMER.interval) return;
        showToast(rem > 59.5 ? "1 minute left" : fmtTime(rem) + " left", "warn");
      }
    }
    /* Overtime: "Time is up", and then one popup per whole minute over --   */
    /* not one per interval, which is a countdown's pace: every 10 seconds   */
    /* (or every second, with popup-every: 1) for as long as the talk ran    */
    /* on, a popup that was back before the key that closed it was up       */
    /* (Rony, 27-Sep). Esc or T over one says "I know": no more until the    */
    /* timer restarts. The overtime is still on screen wherever the deck     */
    /* shows {remaining}, and T tells it.                                    */
    else if (rem <= 0) {
      var over = Math.floor(-rem / 60);
      if (tOver === null || over !== tOver) {
        tOver = over;
        if (!tMuted)
          showToast(over === 0 ? "Time is up" : fmtTime(over * 60) + " over", "over");
      }
    }
  }
  /* Esc or T over a red popup: no more overtime popups until R R. */
  function muteOvertime() {
    tMuted = true;
    saveTimer();
  }

  /* Live fields in the margin boxes: the runtime fills {page} and puts a   */
  /* span in place of each live field (fillPagePlaceholders); here they get */
  /* their text, on the slide being shown.                                  */
  function liveValue(name) {
    if (tStart === null) return { text: "", over: false };
    var rem;
    switch (name) {
      case "clock":
        var d = new Date();
        return { text: pad2(d.getHours()) + ":" + pad2(d.getMinutes()), over: false };
      case "elapsed":
        return { text: fmtUsed(elapsed(), remaining()), over: false };
      case "remaining":
        rem = remaining();
        return rem === null ? { text: "", over: false } : { text: fmtLeft(rem), over: rem <= -0.5 };
      case "section-remaining":
        var sec = sectionNow();
        if (!sec) return { text: "", over: false };
        rem = sec.end - elapsed();
        return { text: fmtLeft(rem), over: rem <= -0.5 };
      /* Since the talk first reached the section (pauses left out); red   */
      /* once that is more than the section's time.                        */
      case "section-elapsed":
        var se = sectionNow();
        if (!se) return { text: "", over: false };
        var used = tSecIn.hasOwnProperty(se.num) ? Math.max(0, elapsed() - tSecIn[se.num]) : 0;
        return { text: fmtUsed(used, se.dur - used), over: used >= se.dur + 0.5 };
    }
    return { text: "", over: false };
  }
  function updateLive() {
    if (!slides || !slides[current]) return;
    slides[current].querySelectorAll(".live").forEach(function (sp) {
      var v = liveValue(sp.getAttribute("data-live"));
      if (sp.textContent !== v.text) sp.textContent = v.text;
      sp.classList.toggle("over", v.over);
      sp.classList.toggle("paused", tPaused !== null && sp.getAttribute("data-live") !== "clock");
    });
  }

  /* Where the talk stands, for T. */
  function timerStatus() {
    if (tStart === null)
      return "The timer has not started: it starts with full screen (f), or press R";
    var parts = [(tPaused !== null ? "Paused · " : "") + fmtTime(elapsed()) + " elapsed"];
    var rem = remaining();
    if (rem !== null) parts.push(rem >= 0 ? fmtTime(rem) + " left" : fmtTime(-rem) + " over");
    var sec = sectionNow();
    if (sec && !sec.whole) {
      var sr = sec.end - elapsed();
      parts.push("section " + (sec.num ? sec.num + "/" + sec.count + " " : "") +
                 "“" + sec.name + "”: " +
                 (sr >= 0 ? fmtTime(sr) + " left" : fmtTime(-sr) + " over"));
    }
    return parts.join(" · ");
  }

  /* The popup. Fixed to the window, not inside the stage, so that a blank */
  /* screen does not hide it; placed over the stage's footer (or header)   */
  /* band, and sized with the deck.                                        */
  function showToast(text, kind) {
    if (!toastEl) {
      toastEl = document.createElement("div");
      toastEl.id = "timer-toast";
      document.body.appendChild(toastEl);
    }
    var r = stage.getBoundingClientRect();
    var k = r.width / readGeometry().w;
    var band = footerBand() * k;
    toastEl.textContent = text;
    toastEl.className = "open " + kind;
    toastKind = kind;
    toastEl.style.fontSize = (26 * k) + "px";
    toastEl.style.left = (r.left + r.width / 2) + "px";
    if (TIMER.where === "header") {
      toastEl.style.top = (r.top + band * 0.15) + "px";
      toastEl.style.bottom = "";
    } else {
      toastEl.style.top = "";
      toastEl.style.bottom = (window.innerHeight - r.bottom + band * 0.15) + "px";
    }
  }
  function toastOpen() { return toastEl && toastEl.classList.contains("open"); }
  function hideToast() { if (toastEl) toastEl.classList.remove("open"); toastKind = ""; }

  function onTimerKey(key) {
    if (key === "t" || key === "T") {
      /* Over a red popup, T is "I know": it silences the overtime popups    */
      /* and shows where the talk stands. Unlike Esc, it keeps full screen.  */
      if (toastOpen() && toastKind === "over") {
        muteOvertime();
        showToast(timerStatus() + " · overtime popups off (R twice restarts the timer)", "info");
      }
      else if (toastOpen() && toastKind === "info") hideToast();
      else showToast(timerStatus(), "info");
      return true;
    }
    if (key === "p" || key === "P") {
      if (tStart === null)
        showToast("The timer has not started: it starts with full screen (f), or press R", "info");
      else if (resumeTimer()) showToast("Timer resumed", "info");
      else askCountdown("Pause: for how long? Minutes (10) or until a time (15:30)," +
                        " and a message if you like (10 Coffee break), or only a message" +
                        " (Questions) \u00b7 Enter: pause, no panel \u00b7 Esc: no pause",
        function (spec) {
          if (!pauseTimer("key")) return;
          if (spec) startCountdown(spec, "pause");
          else showToast("Timer paused at " + fmtTime(elapsed()) +
                         ": P, or going on, resumes it", "info");
        }, true);
      return true;
    }
    if (key === "c" || key === "C") {
      askCountdown("Countdown: minutes (5) or a time of day (17:00)," +
                   " and a message if you like (5 We start soon)" +
                   " \u00b7 Enter: none \u00b7 Esc: leave as it is",
        function (spec) {
          if (!spec) { endCountdown(); return; }
          startCountdown(spec, CD && CD.kind === "pause" ? "pause" :
                               (tStart === null ? "start" : "free"));
        });
      return true;
    }
    if (key === "m" || key === "M") { toggleClock(); return true; }
    if (key === "h" || key === "H") { openStats(); return true; }
    if (key === "r" || key === "R") {
      if (tStart === null) { startTimer(); showToast("Timer started: 0:00", "info"); }
      else if (Date.now() - resetArmed < 3000) { resetArmed = 0; restartTimer(); }
      else {
        resetArmed = Date.now();
        showToast("Press R again to restart the timer from 0:00", "info");
      }
      return true;
    }
    return false;
  }

  function initTimer() {
    readTimer();
    loadTimer();
    loadCountdown();
    document.addEventListener("fullscreenchange", function () {
      if (document.fullscreenElement) presentingStarts();
    });
    /* F11 is the browser's own full screen and fires no fullscreenchange:  */
    /* a window as big as the screen is taken to be it.                     */
    window.addEventListener("resize", function () {
      if (bigWindow()) presentingStarts();
      if (CD) drawCountdown();
    });
  }
  function bigWindow() {
    return window.innerWidth >= screen.width - 1 && window.innerHeight >= screen.height - 1;
  }
  function presenting() { return !!document.fullscreenElement || bigWindow(); }
  /* Full screen: the talk is being given. A countdown on the slide shown   */
  /* comes up, and the timer waits for it; otherwise the timer starts.     */
  function presentingStarts() {
    if (tStart !== null) return;
    if (slides && slideCountdown(slides[current])) return;
    if (!tHeld) startTimer();
  }

  /* ---------------------------------------------------------------------- */
  /* Countdowns (Rony, 24-Sep).                                              */
  /*                                                                        */
  /* A big countdown over the slide, for an audience waiting: before the   */
  /* talk starts, or during a break. countdown=5 (minutes) or              */
  /* countdown=17:00 (a time of day) on a slide shows one when the slide   */
  /* is presented (full screen), once; C starts one on any slide, or takes */
  /* it away. A break gets one from P (it asks how long) or from pause=10  */
  /* or pause=15:30 on a pause slide.                                       */
  /*                                                                        */
  /* Minutes: the time left, blue, moving once a minute (every second in  */
  /* the last timer: seconds:); then red, with the overtime. A time of day:*/
  /* the clock, blue, and the time left under it; then the clock red,     */
  /* with the overtime under it. timer: sound: yes chimes at 0.            */
  /*                                                                        */
  /* It goes away when the talk goes on (the next step or slide), or, in a */
  /* break, when the break ends. Before the talk, the timer waits for it:  */
  /* the talk starts when the countdown is over and the presenter goes on. */
  /* ---------------------------------------------------------------------- */

  var CD = null, cdEl = null, cdTick = null, cdDone = {}, tHeld = false;
  var CKEY = "md2slides.countdown:" + location.pathname;

  /* "5", "7.5" -> minutes from now; "17:00" -> that time of day (today;   */
  /* tomorrow if it was more than 6 hours ago). null if neither. Words     */
  /* after it are a message, shown with the countdown: "15 Coffee break"   */
  /* (Rony, 25-Sep).                                                       */
  function parseCountdown(v) {
    if (v === null || v === undefined) return null;
    v = String(v).trim();
    var sp = v.search(/\s/), msg = "";
    if (sp > 0) { msg = v.slice(sp).trim(); v = v.slice(0, sp); }
    var m;
    if (/^(\d+(\.\d*)?|\.\d+)$/.test(v) && parseFloat(v) > 0)
      return { target: Date.now() + parseFloat(v) * 60000, clock: false, text: v, msg: msg };
    if ((m = /^(\d{1,2}):(\d\d)$/.exec(v)) && +m[1] < 24 && +m[2] < 60) {
      var d = new Date();
      d.setHours(+m[1], +m[2], 0, 0);
      if (d.getTime() < Date.now() - 6 * 3600000) d.setDate(d.getDate() + 1);
      return { target: d.getTime(), clock: true, text: v, msg: msg };
    }
    return null;
  }
  /* A bare number of minutes, big on its own, says what it counts: "12 min". */
  function withUnit(t) { return /^\d+$/.test(t) ? t + " min" : t; }
  function hhmm(t) { var d = new Date(t); return pad2(d.getHours()) + ":" + pad2(d.getMinutes()); }
  function hhmmss(t) { return hhmm(t) + ":" + pad2(new Date(t).getSeconds()); }

  /* kind: "start" (before the talk: the timer waits), "pause" (a break: it */
  /* ends with the break), "free" (any other: it ends when the talk goes on). */
  /* A break's panel also says when the break began and how long it has   */
  /* lasted (Rony, 26-Sep); a break with no time to it (P, then only a     */
  /* message) has only that: it counts up. No typed message: the deck's    */
  /* timer: pause-message: (or countdown-message:), if it has one.         */
  function startCountdown(spec, kind) {
    var brk = kind === "pause";
    CD = { target: spec.target, clock: spec.clock, kind: kind,
           rang: spec.target === null || spec.target <= Date.now(),
           since: brk ? (tPaused !== null ? tPaused : Date.now()) : null,
           msg: spec.msg || (brk ? TIMER.pauseMessage : TIMER.countdownMessage) || "" };
    if (kind === "start") tHeld = true;
    saveCountdown();
    drawCountdown();
    if (!cdTick) cdTick = setInterval(countdownTick, 250);
  }
  function endCountdown() {
    CD = null;
    if (cdEl) cdEl.classList.remove("open");
    clearInterval(cdTick); cdTick = null;
    saveCountdown();
  }
  /* A countdown=... on the slide shown, if it is presented and has not    */
  /* shown its countdown yet. Returns true when one comes up.               */
  function slideCountdown(s) {
    if (!s || !presenting() || CD) return false;
    var i = slides.indexOf(s);
    if (cdDone[i]) return false;
    var spec = parseCountdown(s.getAttribute("data-countdown"));
    if (!spec) return false;
    cdDone[i] = 1;
    startCountdown(spec, tStart === null ? "start" : "free");
    return true;
  }
  /* The next step or slide: a countdown that is not a break's goes away,  */
  /* and a talk that was waiting for it starts.                             */
  function countdownTalkGoesOn() {
    if (CD && CD.kind !== "pause") endCountdown();
    if (tHeld && tStart === null && presenting()) startTimer();
  }
  function countdownTick() {
    if (!CD) return;
    if (!CD.rang && CD.target !== null && Date.now() >= CD.target) {
      CD.rang = true;
      saveCountdown();
      if (TIMER.sound) chime();
    }
    drawCountdown();
  }
  function drawCountdown() {
    if (!CD) return;
    if (!cdEl) {
      cdEl = document.createElement("div");
      cdEl.id = "countdown";
      cdEl.innerHTML = '<div class="cd-msg"></div><div class="cd-main"></div>' +
                       '<div class="cd-sub"></div><div class="cd-since"></div>';
      document.body.appendChild(cdEl);
    }
    var now = Date.now(), open = CD.target === null;
    var rem = open ? 0 : (CD.target - now) / 1000, over = !open && rem <= -0.5;
    var main, sub, since = "";
    var brk = CD.kind === "pause";
    if (brk && CD.since) {
      var sofar = fmtMS((now - CD.since) / 1000);
      since = "paused at " + hhmmss(CD.since) + " \u00b7 " + sofar + " so far";
    }
    if (open) {                         /* a break with no end: it counts up */
      main = fmtMS((now - (CD.since || now)) / 1000);
      sub = "paused at " + hhmmss(CD.since || now) + " \u00b7 P or going on ends it";
      since = "";
    }
    else if (CD.clock) {
      main = hhmm(now);
      sub = over ? (brk ? "break over at " + hhmm(CD.target) + " \u00b7 " : "") + "+" + fmtMS(-rem)
                 : (brk ? "break until " : "until ") + hhmm(CD.target) + " \u00b7 " +
                   withUnit(fmtLeft(rem)) + " to go";
    } else {
      main = withUnit(fmtLeft(rem));
      sub = over ? (brk ? "break over at " : "since ") + hhmm(CD.target)
                 : (brk ? "break until " : "until ") + hhmm(CD.target);
    }
    var gEl = cdEl.querySelector(".cd-msg"), mEl = cdEl.querySelector(".cd-main"),
        sEl = cdEl.querySelector(".cd-sub"), iEl = cdEl.querySelector(".cd-since"),
        msg = CD.msg || "";
    if (iEl.textContent !== since) iEl.textContent = since;
    if (gEl.textContent !== msg) gEl.textContent = msg;
    if (mEl.textContent !== main) mEl.textContent = main;
    if (sEl.textContent !== sub) sEl.textContent = sub;
    cdEl.className = "open " + (over ? "over" : "go") + (CD.kind === "pause" ? " break" : "");
    /* Over the stage, sized with the deck; fixed to the window, like the   */
    /* popups, so that a blank screen does not hide it.                     */
    var r = stage.getBoundingClientRect(), k = r.width / readGeometry().w;
    cdEl.style.left = (r.left + r.width / 2) + "px";
    cdEl.style.top = (r.top + r.height / 2) + "px";
    cdEl.style.fontSize = (40 * k) + "px";
  }
  /* A short chime, made on the spot (no sound file in the deck). */
  function chime() {
    try {
      var A = window.AudioContext || window.webkitAudioContext;
      if (!A) return;
      var ac = new A();
      [0, 0.35, 0.7].forEach(function (t, i) {
        var o = ac.createOscillator(), g = ac.createGain();
        o.type = "sine";
        o.frequency.value = [880, 660, 880][i];
        g.gain.setValueAtTime(0.0001, ac.currentTime + t);
        g.gain.exponentialRampToValueAtTime(0.4, ac.currentTime + t + 0.02);
        g.gain.exponentialRampToValueAtTime(0.0001, ac.currentTime + t + 0.3);
        o.connect(g); g.connect(ac.destination);
        o.start(ac.currentTime + t); o.stop(ac.currentTime + t + 0.32);
      });
    } catch (e) { /* no sound: the colour still says it */ }
  }
  function saveCountdown() {
    try {
      sessionStorage.setItem(CKEY, JSON.stringify({ cd: CD, done: cdDone, held: tHeld }));
    } catch (e) { /* no storage: a reload forgets the countdown */ }
  }
  function loadCountdown() {
    var j = null;
    try { j = JSON.parse(sessionStorage.getItem(CKEY)); } catch (e) { j = null; }
    if (!j) return;
    cdDone = j.done || {};
    tHeld = !!j.held && tStart === null;
    if (j.cd && (typeof j.cd.target === "number" || j.cd.target === null)) {
      CD = j.cd;
      if (!cdTick) cdTick = setInterval(countdownTick, 250);
      setTimeout(drawCountdown, 0);
    }
  }

  /* ---------------------------------------------------------------------- */
  /* Rehearsal: the time spent on each slide (Rony, 26-Sep).                 */
  /*                                                                        */
  /* While the timer runs, every visit to a slide is written down: which    */
  /* slide, when it came up, when it went (a pause ends a visit, and going  */
  /* on starts another; so does coming back to a slide). A RUN is one go at */
  /* the talk: from the timer's start to its restart (R, twice).            */
  /*                                                                        */
  /* M puts the time on this slide in the top left corner (a rehearsal     */
  /* aid: it counts from 0:00 at each visit, with the slide's total beside  */
  /* it when it has been shown before). H shows what the run adds up to:   */
  /* the time per slide, per section, against the talk and against the     */
  /* plan, the slides that took the most and the least, and another run    */
  /* beside it to compare.                                                  */
  /*                                                                        */
  /* The run in progress survives a reload (sessionStorage). With          */
  /* timer: record: yes the runs are KEPT (localStorage, in this browser,  */
  /* for this file): the next time the deck is given, H has them all, each */
  /* with the audience it was given to, if the presenter says. Export and  */
  /* Import move them between browsers and machines as a JSON file.        */
  /* ---------------------------------------------------------------------- */

  var REC = { run: null, open: null };
  var RKEY = "md2slides.run:" + location.pathname;
  var HKEY = "md2slides.history:" + location.pathname;
  var slideShownAt = Date.now(), clockOn = false, clockEl = null, clockTick = null;
  var MKEY = "md2slides.clock:" + location.pathname;

  function recRunning() { return tStart !== null && tPaused === null; }
  function slideTitles() {
    return slides.map(function (s, i) {
      return s.getAttribute("data-title") || s.id || ("Slide " + (i + 1));
    });
  }
  function runSections() {
    var tab = sectionTable(), out = [];
    tab.timed.forEach(function (t, k) {
      out.push({ num: t.num, name: t.name, dur: t.dur, from: t.i,
                 to: k + 1 < tab.timed.length ? tab.timed[k + 1].i - 1 : slides.length - 1 });
    });
    if (tab.timed.length && tab.timed[0].i > 0)
      out.unshift({ num: 0, name: "Before the sections", dur: tab.pre || null,
                    from: 0, to: tab.timed[0].i - 1 });
    return out;
  }
  function newRun() {
    readTimer();
    var deck = (location.pathname.split("/").pop() || "deck").replace(/\.html?$/i, "");
    REC.run = { v: 1, id: Date.now(), deck: deck, started: Date.now(), audience: "",
                planned: TIMER.total, titles: slideTitles(), sections: runSections(),
                visits: [] };
  }
  function recOpen() {
    if (!slides || !recRunning() || REC.open) return;
    if (!REC.run) newRun();
    REC.open = { i: current, t: Date.now() };
    saveRun();
  }
  function recClose() {
    if (!REC.open) return;
    var now = Date.now();
    if (now - REC.open.t >= 500) REC.run.visits.push([REC.open.i, REC.open.t, now]);
    REC.open = null;
    saveRun();
  }
  /* A new run: the timer restarted. The old one stays in the history. */
  function recRestart() {
    recClose();
    REC.run = null;
    saveRun();
    recOpen();
  }
  function saveRun() {
    try {
      sessionStorage.setItem(RKEY, JSON.stringify(REC));
    } catch (e) { /* no storage: the run lives as long as the page */ }
    if (TIMER.record && REC.run && REC.run.visits.length) {
      var h = loadHistory(), k;
      for (k = 0; k < h.length && h[k].id !== REC.run.id; k++);
      h[k] = REC.run;
      saveHistory(h);
    }
  }
  function loadRun() {
    try {
      var j = JSON.parse(sessionStorage.getItem(RKEY));
      if (j && j.run && j.run.visits) { REC.run = j.run; REC.open = j.open || null; }
    } catch (e) { /* nothing kept */ }
    /* A visit left open by a page that went away ends where it was last seen */
    if (REC.open) { REC.open = null; }
  }
  function loadHistory() {
    try {
      var h = JSON.parse(localStorage.getItem(HKEY));
      return Array.isArray(h) ? h : [];
    } catch (e) { return []; }
  }
  function saveHistory(h) {
    try { localStorage.setItem(HKEY, JSON.stringify(h)); }
    catch (e) { /* no storage, or full: the runs are not kept */ }
  }
  /* Every run H knows: the kept ones, and the one in progress. */
  function allRuns() {
    /* the run in progress is the live one, not its last saved copy */
    var h = loadHistory().filter(function (r) { return !REC.run || r.id !== REC.run.id; });
    if (REC.run) h.push(REC.run);
    h.sort(function (a, b) { return a.started - b.started; });
    return h;
  }
  /* The run's visits, with the open one counted up to now. */
  function visitsOf(run) {
    var v = run.visits.slice();
    if (run === REC.run && REC.open) v.push([REC.open.i, REC.open.t, Date.now()]);
    return v;
  }
  function perSlide(run) {
    var n = run.titles.length, t = [], c = [];
    for (var i = 0; i < n; i++) { t.push(0); c.push(0); }
    visitsOf(run).forEach(function (v) {
      if (v[0] < n) { t[v[0]] += (v[2] - v[1]) / 1000; c[v[0]] += 1; }
    });
    return { time: t, count: c };
  }

  /* -- M: the time on this slide ------------------------------------------ */

  function toggleClock() {
    clockOn = !clockOn;
    try { sessionStorage.setItem(MKEY, clockOn ? "1" : ""); } catch (e) { /* */ }
    drawClock();
    showToast(clockOn ? "Time on this slide: shown (M hides it)" : "Time on this slide: hidden", "info");
  }
  function drawClock() {
    if (!clockOn) {
      if (clockEl) clockEl.classList.remove("open");
      clearInterval(clockTick); clockTick = null;
      return;
    }
    if (!clockEl) {
      clockEl = document.createElement("div");
      clockEl.id = "slide-clock";
      document.body.appendChild(clockEl);
    }
    if (!clockTick) clockTick = setInterval(drawClock, 500);
    var now = Date.now(), here, before = 0;
    if (REC.open && REC.open.i === current) here = (now - REC.open.t) / 1000;
    else here = tPaused !== null ? 0 : (now - slideShownAt) / 1000;
    if (REC.run) REC.run.visits.forEach(function (v) {
      if (v[0] === current) before += (v[2] - v[1]) / 1000;
    });
    var txt = fmtMS(here) + (before >= 1 ? "  ·  " + fmtMS(here + before) + " in all" : "");
    if (tPaused !== null) txt = "paused · " + txt;
    else if (tStart === null) txt += "  ·  timer off";
    if (clockEl.textContent !== txt) clockEl.textContent = txt;
    clockEl.classList.add("open");
    var r = stage.getBoundingClientRect(), k = r.width / readGeometry().w;
    clockEl.style.left = (r.left + 8 * k) + "px";
    clockEl.style.top = (r.top + 8 * k) + "px";
    clockEl.style.fontSize = (18 * k) + "px";
  }

  /* -- H: what a run adds up to -------------------------------------------- */

  var statsBox = null, statsSel = null, statsCmp = "", statsTop = 5, delArmed = 0;
  function statsOpen() { return statsBox && statsBox.classList.contains("open"); }
  function closeStats() {
    if (statsBox) statsBox.classList.remove("open");
    focusStage();
  }
  function openStats() {
    if (helpOpen()) closeHelp();
    if (!statsBox) {
      statsBox = document.createElement("div");
      statsBox.id = "stats-overlay";
      document.body.appendChild(statsBox);
      statsBox.addEventListener("click", function (e) {
        if (e.target === statsBox) closeStats();
      });
    }
    if (REC.run) statsSel = REC.run.id;
    drawStats();
    statsBox.classList.add("open");
  }
  function runLabel(r) {
    var d = new Date(r.started);
    var tot = 0;
    visitsOf(r).forEach(function (v) { tot += (v[2] - v[1]) / 1000; });
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) + " " +
           hhmm(r.started) + (r.audience ? " · " + r.audience : "") +
           " · " + fmtTime(tot) + (REC.run && r.id === REC.run.id ? " (this run)" : "");
  }
  function pct(a, b) { return b ? Math.round(100 * a / b) + "%" : ""; }
  function drawStats() {
    var runs = allRuns();
    var run = null, cmp = null;
    runs.forEach(function (r) {
      if (r.id === statsSel) run = r;
      if (String(r.id) === String(statsCmp)) cmp = r;
    });
    if (!run && runs.length) { run = runs[runs.length - 1]; statsSel = run.id; }
    var h = '<div class="jo-panel st-panel"><div class="jo-head"><span>Time per slide</span></div>' +
            '<div class="jo-list">';
    if (!run) {
      h += '<div class="ab-row">Nothing recorded yet. Slides are timed while the timer runs: ' +
           'it starts with full screen (f), or with R.' +
           (TIMER.record ? '' : ' To keep the runs from one talk to the next, the deck needs ' +
           '<code>timer: record: yes</code>.') + '</div>';
    } else {
      var opts = function (withNone) {
        return (withNone ? '<option value="">(none)</option>' : '') + runs.map(function (r) {
          return '<option value="' + r.id + '">' + esc(runLabel(r)) + '</option>';
        }).join("");
      };
      h += '<div class="st-bar">' +
           '<label>Run <select class="st-run">' + opts(false) + '</select></label>' +
           '<label>Audience <input class="st-aud" type="text" placeholder="beginners, Python programmers..." value="' +
             esc(run.audience || "") + '"></label>' +
           '<label>Compare with <select class="st-cmp">' + opts(true) + '</select></label>' +
           '</div>';
      var ps = perSlide(run), n = run.titles.length, total = 0, shown = 0;
      ps.time.forEach(function (t) { total += t; if (t > 0) shown++; });
      var cs = cmp ? perSlide(cmp) : null, cmpTotal = 0;
      if (cs) cs.time.forEach(function (t) { cmpTotal += t; });
      /* a slide of the compared run: the same title, else the same place */
      var cmpOf = function (i) {
        if (!cs) return null;
        var k = cmp.titles.indexOf(run.titles[i]);
        if (k < 0 && cmp.titles.length === n) k = i;
        return k < 0 ? null : cs.time[k];
      };
      var planned = run.planned;
      h += '<div class="st-sum">' +
           '<b>' + fmtTime(total) + '</b> presenting' +
           (planned ? ' of ' + minutes(planned) + ' planned (' + pct(total, planned) + ')' : '') +
           ' · ' + shown + ' of ' + n + ' slides shown' +
           (shown ? ' · <b>' + fmtMS(total / shown) + '</b> a slide on average' : '') +
           (cmp ? ' · compared run: ' + fmtTime(cmpTotal) : '') + '</div>';

      /* the table, section by section */
      var secs = run.sections && run.sections.length ? run.sections :
                 [{ num: null, name: "", dur: planned, from: 0, to: n - 1 }];
      h += '<table class="st-table"><thead><tr><th>#</th><th>Slide</th><th>Time</th>' +
           '<th>Visits</th><th>% of talk</th>' + (planned ? '<th>% of plan</th>' : '') +
           (cmp ? '<th>Compared</th><th>Δ</th>' : '') + '</tr></thead><tbody>';
      secs.forEach(function (s) {
        var st = 0, sc = 0;
        for (var i = s.from; i <= s.to && i < n; i++) { st += ps.time[i]; sc += cmpOf(i) || 0; }
        if (s.num !== null) {
          h += '<tr class="st-sec"><td colspan="2">' +
               (s.num ? 'Section ' + s.num + ': ' : '') + esc(s.name) +
               (s.dur ? ' (' + minutes(s.dur) + ' planned, ' + pct(st, s.dur) + ')' : '') +
               '</td><td>' + fmtMS(st) + '</td><td></td><td>' + pct(st, total) + '</td>' +
               (planned ? '<td>' + pct(st, planned) + '</td>' : '') +
               (cmp ? '<td>' + fmtMS(sc) + '</td><td>' + delta(st - sc) + '</td>' : '') + '</tr>';
        }
        for (i = s.from; i <= s.to && i < n; i++) {
          var c = cmpOf(i);
          h += '<tr' + (ps.time[i] ? '' : ' class="st-none"') + '><td>' + (i + 1) + '</td><td>' +
               esc(run.titles[i]) + '</td><td>' + (ps.time[i] ? fmtMS(ps.time[i]) : '–') +
               '</td><td>' + (ps.count[i] || '') + '</td><td>' + pct(ps.time[i], total) + '</td>' +
               (planned ? '<td>' + pct(ps.time[i], planned) + '</td>' : '') +
               (cmp ? '<td>' + (c === null ? '' : c ? fmtMS(c) : '–') + '</td><td>' +
                      (c === null ? '' : delta(ps.time[i] - c)) + '</td>' : '') + '</tr>';
        }
      });
      h += '</tbody></table>';

      /* the most and the least */
      var idx = [];
      for (var i = 0; i < n; i++) if (ps.time[i] > 0) idx.push(i);
      idx.sort(function (a, b) { return ps.time[b] - ps.time[a]; });
      var line = function (list) {
        return list.map(function (i) {
          return '<li>' + fmtMS(ps.time[i]) + ' · ' + (i + 1) + '. ' + esc(run.titles[i]) + '</li>';
        }).join("");
      };
      if (idx.length > 1) {
        var k = Math.min(statsTop, Math.floor(idx.length / 2) || 1);
        h += '<div class="st-top"><div><div class="ab-sub">Most time</div><ol>' +
             line(idx.slice(0, k)) + '</ol></div><div><div class="ab-sub">Least time</div><ol>' +
             line(idx.slice(-k).reverse()) + '</ol></div></div>';
      }
      h += '<div class="st-bar st-actions">' +
           '<button class="st-topn">Show ' + (statsTop === 5 ? 10 : 5) + ' most / least</button>' +
           '<button class="st-export">Export runs</button>' +
           '<button class="st-import">Import runs</button>' +
           '<button class="st-del">Delete this run</button>' +
           '<input class="st-file" type="file" accept=".json,application/json" hidden>' +
           '</div>' +
           (TIMER.record ? '' : '<div class="ab-row st-note">This run is not kept after the ' +
           'browser tab closes: the deck does not have <code>timer: record: yes</code>. ' +
           'Export keeps it anyway.</div>');
    }
    h += '</div><div class="jo-hint">h or Esc to close</div></div>';
    statsBox.innerHTML = h;
    wireStats(runs, run);
  }
  function delta(d) {
    if (Math.abs(d) < 1) return "0:00";
    return (d > 0 ? "+" : "−") + fmtMS(Math.abs(d));
  }
  function wireStats(runs, run) {
    if (!run) return;
    var q = function (c) { return statsBox.querySelector(c); };
    q(".st-run").value = String(run.id);
    q(".st-cmp").value = String(statsCmp);
    q(".st-run").addEventListener("change", function (e) {
      statsSel = +e.target.value; drawStats();
    });
    q(".st-cmp").addEventListener("change", function (e) {
      statsCmp = e.target.value; drawStats();
    });
    q(".st-aud").addEventListener("change", function (e) {
      run.audience = e.target.value.trim();
      if (REC.run && run.id === REC.run.id) { REC.run.audience = run.audience; saveRun(); }
      else {
        var h = loadHistory();
        h.forEach(function (r) { if (r.id === run.id) r.audience = run.audience; });
        saveHistory(h);
      }
      drawStats();
    });
    q(".st-topn").addEventListener("click", function () {
      statsTop = statsTop === 5 ? 10 : 5; drawStats();
    });
    q(".st-export").addEventListener("click", function () {
      var blob = new Blob([JSON.stringify({ md2slides: "timings", runs: allRuns() }, null, 1)],
                          { type: "application/json" });
      var a = document.createElement("a"), d = new Date();
      a.href = URL.createObjectURL(blob);
      a.download = (run.deck || "deck") + "-timings-" + d.getFullYear() +
                   pad2(d.getMonth() + 1) + pad2(d.getDate()) + ".json";
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
    });
    q(".st-import").addEventListener("click", function () { q(".st-file").click(); });
    q(".st-file").addEventListener("change", function (e) {
      var f = e.target.files && e.target.files[0];
      if (!f) return;
      var rd = new FileReader();
      rd.onload = function () {
        var got = 0;
        try {
          var j = JSON.parse(rd.result), h = loadHistory();
          (j.runs || []).forEach(function (r) {
            if (!r || !r.id || !Array.isArray(r.visits) || !Array.isArray(r.titles)) return;
            if (!h.some(function (x) { return x.id === r.id; })) { h.push(r); got++; }
          });
          saveHistory(h);
        } catch (err) { got = -1; }
        showToast(got < 0 ? "That file is not an export of runs" :
                  got + (got === 1 ? " run" : " runs") + " imported", "info");
        drawStats();
      };
      rd.readAsText(f);
    });
    q(".st-del").addEventListener("click", function (e) {
      if (Date.now() - delArmed > 3000) {
        delArmed = Date.now();
        e.target.textContent = "Click again to delete";
        return;
      }
      delArmed = 0;
      saveHistory(loadHistory().filter(function (r) { return r.id !== run.id; }));
      if (REC.run && run.id === REC.run.id) {
        REC.run = null; REC.open = null; saveRun(); recOpen();
      }
      statsSel = null;
      if (String(statsCmp) === String(run.id)) statsCmp = "";
      drawStats();
    });
  }

  function initRehearsal() {
    loadRun();
    try { clockOn = sessionStorage.getItem(MKEY) === "1"; } catch (e) { clockOn = false; }
    window.addEventListener("pagehide", function () { recClose(); });
    window.addEventListener("resize", function () { if (clockOn) drawClock(); });
  }

  /* The little dialog of P and C: one line to type in. */
  var askEl = null, askDone = null, askOpenEnded = false;
  function askOpen() { return askEl && askEl.classList.contains("open"); }
  /* openEnded: a line that is only words (no minutes, no time) is taken   */
  /* as a message with no time to it (P: a break that counts up).          */
  function askCountdown(label, done, openEnded) {
    if (!askEl) {
      askEl = document.createElement("div");
      askEl.id = "countdown-ask";
      askEl.innerHTML = '<div class="ca-panel"><div class="ca-label"></div>' +
        '<input type="text" autocomplete="off" spellcheck="false">' +
        '<div class="ca-error"></div></div>';
      document.body.appendChild(askEl);
      var input = askEl.querySelector("input");
      input.addEventListener("keydown", function (e) {
        e.stopPropagation();
        if (e.key === "Escape") { e.preventDefault(); closeAsk(); }
        else if (e.key === "Enter") {
          e.preventDefault();
          var v = input.value.trim(), spec = null;
          if (v) {
            spec = parseCountdown(v);
            if (!spec && askOpenEnded && !/^[\d.:]/.test(v))
              spec = { target: null, clock: false, text: "", msg: v };
            if (!spec) {
              askEl.querySelector(".ca-error").textContent =
                "\u201c" + v + "\u201d does not start with minutes (10) or a time of day (15:30)";
              return;
            }
          }
          var f = askDone;
          closeAsk();
          f(spec);
        }
      });
    }
    askDone = done;
    askOpenEnded = !!openEnded;
    askEl.querySelector(".ca-label").textContent = label;
    askEl.querySelector(".ca-error").textContent = "";
    var input = askEl.querySelector("input");
    input.value = "";
    askEl.classList.add("open");
    input.focus();
  }
  function closeAsk() {
    if (askEl) askEl.classList.remove("open");
    askDone = null;
    focusStage();
  }

  /* ---------------------------------------------------------------------- */
  /* Jump overlay. Lists every page as a target and takes a typed page        */
  /* number + Enter, the way PowerPoint/Impress do in presentation mode.       */
  /* ---------------------------------------------------------------------- */

  /* selIndex points into VISIBLE, not into slides: with a filter on, the two  */
  /* are different lists and the arrows must walk the one on screen.           */
  var overlay = null, jumpInput = null, selIndex = 0;
  var items = [], visible = [], joCount = null, joEmpty = null, haystack = null;

  function buildOverlay() {
    overlay = document.createElement("div");
    overlay.id = "jump-overlay";
    /* The hint lists what works HERE and nothing else. It used to advertise  */
    /* b and w, which are keys of the deck: with the field focused they never  */
    /* reached the handler and merely typed "bw" into the box. Now that the    */
    /* field takes words that is not a bug to fix but a rule -- no letter can  */
    /* be a command in a dialog you type into.                                 */
    overlay.innerHTML =
      '<div class="jo-panel">' +
        '<div class="jo-head">' +
          '<span id="jo-count">Go to slide</span>' +
          '<input id="jo-input" type="text" autocomplete="off" ' +
                 'spellcheck="false" ' +
                 'placeholder="a number, or words to find">' +
        '</div>' +
        '<div class="jo-list" id="jo-list"></div>' +
        '<div class="jo-hint">&uarr;&darr; select &middot; PgUp/PgDn page ' +
          '&middot; Enter go &middot; Esc close &middot; F1 keys</div>' +
      '</div>';
    document.body.appendChild(overlay);
    jumpInput = overlay.querySelector("#jo-input");

    var list = overlay.querySelector("#jo-list");
    joCount = overlay.querySelector("#jo-count");
    slides.forEach(function (s, i) {
      var item = document.createElement("button");
      item.type = "button";
      var isSection = s.classList.contains("section");
      /* jo-section / jo-child drive the outline marking in overlay.css: section  */
      /* pages stand out (bold, brighter, a rule above) and the plain slides that */
      /* follow are indented under them, so the deck structure reads at a glance   */
      /* -- the kind tag on the right stays too (JMB asked for both).            */
      item.className = "jo-item " + (isSection ? "jo-section" : "jo-child");
      var label = s.getAttribute("data-title") ||
                  s.getAttribute("data-section") || s.id || ("Slide " + (i + 1));
      var kind = isSection ? "section" : "slide";
      item.innerHTML = '<span class="jo-num">' + (i + 1) + '</span>' +
                       '<span class="jo-body">' +
                         '<span class="jo-label">' + esc(label) + '</span>' +
                         '<span class="jo-snip"></span>' +
                       '</span>' +
                       '<span class="jo-kind">' + kind + '</span>';
      item.addEventListener("click", function () {
        goTo(i); closeOverlay();
      });
      list.appendChild(item);
      items.push(item);
    });
    joEmpty = document.createElement("div");
    joEmpty.className = "jo-empty";
    list.appendChild(joEmpty);
    applyFilter("");

    overlay.addEventListener("click", function (e) {
      if (e.target === overlay) closeOverlay();
    });
    jumpInput.addEventListener("input", function () {
      applyFilter(jumpInput.value);
    });
    jumpInput.addEventListener("keydown", function (e) {
      e.stopPropagation();   /* keep the global handler out while typing */
      if (e.key === "F1") { toggleHelp(); e.preventDefault(); return; }
      /* The field keeps the keyboard while the help is up, so the help has to */
      /* be answered from here too -- otherwise Escape would close the search  */
      /* underneath it and leave the help sitting on nothing.                  */
      if (helpOpen()) {
        if (e.key === "Escape") { closeHelp(); e.preventDefault(); }
        return;
      }
      if (e.key === "Enter") {
        /* A typed page number still wins, PowerPoint-style. Anything else is  */
        /* a search, and Enter takes whatever the list has selected.           */
        var typed = jumpInput.value.trim();
        if (isPageNumber(typed)) {
          var n = parseInt(typed, 10);
          if (n >= 1 && n <= slides.length) { goTo(n - 1); closeOverlay(); }
        } else if (visible.length) {
          goTo(visible[selIndex]); closeOverlay();
        }
        e.preventDefault();
      } else if (e.key === "ArrowDown" || e.key === "ArrowUp"   ||
                 e.key === "PageDown"  || e.key === "PageUp"    ||
                 e.key === "Home"      || e.key === "End") {
        /* Ctrl+Home / Ctrl+End arrive here as plain Home / End with a          */
        /* modifier nobody reads: the list has one top and one end, so the      */
        /* chord Rony asked for and the bare key mean the same thing rather     */
        /* than one of them meaning nothing.                                    */
        moveSel(e.key); e.preventDefault();
      } else if (e.ctrlKey &&
                 (e.key === "ArrowRight" || e.key === "ArrowLeft")) {
        /* Only WITH Ctrl: bare Left/Right stay the caret's, because this is a  */
        /* field you type a search into and the caret has to be able to move.   */
        moveSection(e.key === "ArrowRight" ? 1 : -1); e.preventDefault();
      } else if (e.key === "Escape") {
        closeOverlay();
      }
    });
  }

  /* ---------------------------------------------------------------------- */
  /* The search.                                                              */
  /*                                                                          */
  /* The unit of a match is the SLIDE. "abc def" finds the slides that hold    */
  /* BOTH; abc on one page and def on the next is not a hit.                   */
  /*                                                                          */
  /* Quoting needs no second code path. "a phrase" parses into ONE term that   */
  /* happens to contain spaces, bare words parse into several, and from there  */
  /* the same rule -- every term must appear -- gives both behaviours, and     */
  /* gives the extracts too: one per term, so a phrase shows one and two loose */
  /* words show two.                                                           */
  /*                                                                          */
  /* All digits and nothing else is not a search: it is the page number the    */
  /* overlay has always taken, so the list is left alone and Enter jumps.      */
  /* ---------------------------------------------------------------------- */

  var PAD = 40;            /* characters of context kept either side of a hit */

  function esc(t) {
    return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;");
  }

  function isPageNumber(q) { return /^\d+$/.test(q); }

  /* Case and accents are folded away before anything is compared, so a deck   */
  /* in Spanish answers to "funcion" as well as to "funcion" with its accent.  */
  /*                                                                          */
  /* The fold runs CHARACTER BY CHARACTER on purpose. The one-liner for this   */
  /* is normalize("NFD") over the whole string with the combining marks        */
  /* stripped, and it cannot be used here: it makes the string shorter, while  */
  /* every offset the extracts are cut and marked with indexes the ORIGINAL    */
  /* text. Folding one character at a time keeps the two strings the same      */
  /* length, so a hit found in the folded copy slices the accented original,   */
  /* and that is what the reader sees in bold.                                 */
  /*                                                                          */
  /* The base is only taken when what follows it is a combining diacritic.     */
  /* Hangul decomposes into jamo and would be destroyed by a blind charAt(0);  */
  /* this way it, and everything else that decomposes differently, is left     */
  /* alone. Known limit: NFD does not touch the likes of the German sharp s    */
  /* or the Scandinavian ligatures, so "Grusse" does not find its spelling     */
  /* with the sharp s -- folding those changes the length, which is the one    */
  /* thing this cannot do.                                                     */
  var CAN_FOLD = typeof "".normalize === "function";
  var COMBINING = /[\u0300-\u036f]/;

  function fold(t) {
    if (!CAN_FOLD) return t.toLowerCase();
    var out = "", i, c;
    for (i = 0; i < t.length; i++) {
      c = t.charAt(i).normalize("NFD");
      out += (c.length > 1 && COMBINING.test(c.charAt(1))) ? c.charAt(0)
                                                           : t.charAt(i);
    }
    return out.toLowerCase();
  }

  /* What a slide is searched ON. The identity chrome is excluded: presenter,  */
  /* affiliation and date are deck-level and identical on every page, so       */
  /* leaving them in would make the presenter's own name match the whole deck. */
  /* An authored ::: footer stays -- that one was typed slide by slide. The    */
  /* six margin boxes go too: the build writes the deck's fields into them on  */
  /* every slide (they are the chrome now), and the presenter's name in the    */
  /* footer matched every page (found 26-Sep).                                 */
  var CHROME = ".presenter, .affiliation, .date, .chrome, .margin";

  /* The title is taken from the attribute and its element is dropped, so it   */
  /* is in the haystack exactly once: left in twice, every hit in a title      */
  /* produced an extract that just read the row's own label back, twice.       */
  /* titled is how far the title reaches, and extract() uses it to prefer a    */
  /* hit in the body -- a word that is in both the title and the prose is      */
  /* more useful shown in the prose, and one that is only in the title still   */
  /* falls back to it.                                                        */
  function buildHaystack() {
    haystack = slides.map(function (s) {
      var clone = s.cloneNode(true);
      var junk = clone.querySelectorAll(CHROME + ", .title");
      for (var i = 0; i < junk.length; i++) junk[i].parentNode.removeChild(junk[i]);
      var title = (s.getAttribute("data-title") ||
                   s.getAttribute("data-section") || "").replace(/\s+/g, " ").trim();
      var body = (clone.textContent || "").replace(/\s+/g, " ").trim();
      var text = title ? (title + " " + body) : body;
      return { text: text, lower: fold(text),
               titled: title ? title.length + 1 : 0 };
    });
  }

  /* A quoted run is one term; anything else splits on whitespace. An unclosed */
  /* quote is treated as a phrase still being typed, so the list does not jump */
  /* about between the opening quote and the closing one.                     */
  function parseQuery(q) {
    var terms = [], re = /"([^"]*)"?|(\S+)/g, m;
    while ((m = re.exec(q)) !== null) {
      var t = fold((m[1] !== undefined ? m[1] : m[2]).trim());
      if (t) terms.push(t);
      if (re.lastIndex === m.index) re.lastIndex++;   /* never spin on ""     */
    }
    return terms;
  }

  function hitsOf(lower, term) {
    var out = [], i = 0;
    while ((i = lower.indexOf(term, i)) !== -1) {
      out.push({ s: i, e: i + term.length });
      i += term.length;
    }
    return out;
  }

  /* An extract per term, around its first occurrence, widened to whole words. */
  /* Windows that run into each other are merged, so two words a few           */
  /* characters apart read as one piece of prose rather than two overlapping   */
  /* ones. Every hit inside a window is marked, not just the one that opened   */
  /* it.                                                                      */
  function extract(hay, terms) {
    var all = [], firsts = [], i, j;
    for (i = 0; i < terms.length; i++) {
      var h = hitsOf(hay.lower, terms[i]);
      if (!h.length) return "";
      all = all.concat(h);
      firsts.push(inBody(h, hay.titled));
    }
    firsts.sort(function (a, b) { return a.s - b.s; });

    var wins = [];
    for (i = 0; i < firsts.length; i++) {
      var w = { s: wordEdge(hay.text, firsts[i].s - PAD, -1),
                e: wordEdge(hay.text, firsts[i].e + PAD, +1) };
      if (wins.length && w.s <= wins[wins.length - 1].e) {
        wins[wins.length - 1].e = Math.max(wins[wins.length - 1].e, w.e);
      } else wins.push(w);
    }

    all.sort(function (a, b) { return a.s - b.s; });
    var out = "";
    for (i = 0; i < wins.length; i++) {
      out += (i ? " &hellip; " : (wins[i].s > 0 ? "&hellip; " : ""));
      var at = wins[i].s;
      for (j = 0; j < all.length; j++) {
        if (all[j].s < at || all[j].e > wins[i].e) continue;
        out += esc(hay.text.slice(at, all[j].s)) +
               "<b>" + esc(hay.text.slice(all[j].s, all[j].e)) + "</b>";
        at = all[j].e;
      }
      out += esc(hay.text.slice(at, wins[i].e));
      if (i === wins.length - 1 && wins[i].e < hay.text.length) out += " &hellip;";
    }
    return out;
  }

  /* The first hit that is past the title, or the first hit at all.            */
  function inBody(hits, titled) {
    for (var i = 0; i < hits.length; i++) if (hits[i].s >= titled) return hits[i];
    return hits[0];
  }

  /* Walk to the nearest space so an extract never opens or closes mid-word.   */
  function wordEdge(text, at, dir) {
    if (at <= 0) return 0;
    if (at >= text.length) return text.length;
    var limit = 14, i = at;
    while (limit-- > 0 && i > 0 && i < text.length && text.charAt(i) !== " ") i += dir;
    return text.charAt(i) === " " ? (dir < 0 ? i + 1 : i) : at;
  }

  function applyFilter(q) {
    if (!haystack) buildHaystack();
    q = q.trim();
    var terms = (q === "" || isPageNumber(q)) ? [] : parseQuery(q);
    var filtering = terms.length > 0;
    visible = [];

    for (var i = 0; i < items.length; i++) {
      var snip = "";
      var ok = true;
      if (filtering) {
        snip = extract(haystack[i], terms);
        ok = snip !== "";
      }
      items[i].style.display = ok ? "" : "none";
      items[i].querySelector(".jo-snip").innerHTML = snip;
      if (ok) visible.push(i);
    }

    overlay.querySelector("#jo-list").classList.toggle("filtering", filtering);
    joEmpty.style.display = visible.length ? "none" : "block";
    joEmpty.textContent = "No slide holds all of that.";
    joCount.textContent = !filtering ? "Go to slide"
                        : visible.length === 0 ? "No match"
                        : visible.length === 1 ? "1 slide"
                        : visible.length + " slides";

    /* Keep the cursor on the current page while it is still on screen, so     */
    /* opening the overlay and typing nothing leaves you where you are.        */
    var at = visible.indexOf(current);
    selIndex = at !== -1 ? at : 0;
    paintSel();
  }

  /* Move the highlighted selection in the jump list and keep it in view. Shared  */
  /* by the arrow keys whether the numeric input has focus or not, so the list is  */
  /* navigable exactly the way a menu should be.                                   */
  function moveSel(key) {
    var n = visible.length;
    if (!n) return;
    if (key === "ArrowDown") selIndex = (selIndex + 1) % n;
    else if (key === "ArrowUp") selIndex = (selIndex - 1 + n) % n;
    else if (key === "Home") selIndex = 0;
    else if (key === "End") selIndex = n - 1;
    /* A page CLAMPS where an arrow wraps. Wrapping one entry past the end is a */
    /* step you can see and undo; wrapping a whole listful lands you somewhere  */
    /* unrelated with no sense of having moved, and in a fifty-slide deck that  */
    /* is exactly the deck you were trying to find your way around.            */
    else if (key === "PageDown") selIndex = Math.min(n - 1, selIndex + pageSpan(1));
    else if (key === "PageUp")   selIndex = Math.max(0,     selIndex - pageSpan(-1));
    paintSel();
  }

  /* How far a page reaches, MEASURED: entries are not all the same height (a   */
  /* section sits on a rule, a filtered entry carries an extract underneath),   */
  /* so a count of pixels divided by an assumed row height would page by the    */
  /* wrong amount in exactly the lists worth paging through. Walk from the      */
  /* selection instead, adding real heights until the viewport is full.         */
  /* At least one, or PageDown on a list with one tall entry would do nothing.  */
  function pageSpan(dir) {
    var list = overlay && overlay.querySelector("#jo-list");
    if (!list) return 1;
    var room = list.clientHeight, used = 0, span = 0, i = selIndex;
    while (true) {
      i += dir;
      if (i < 0 || i >= visible.length) break;
      var h = items[visible[i]].offsetHeight;
      if (used + h > room && span > 0) break;
      used += h;
      span++;
    }
    return Math.max(1, span);
  }

  /* Ctrl+Left / Ctrl+Right: the next entry that opens a section, so a long     */
  /* deck is navigable by its structure and not only by its length. Clamps at   */
  /* both ends (same reason as the page), and a deck with no section slides     */
  /* simply has nowhere to go -- it does not jump to the first or the last.     */
  function moveSection(dir) {
    if (!visible.length) return;
    var i = selIndex;
    while (true) {
      i += dir;
      if (i < 0 || i >= visible.length) return;
      if (items[visible[i]].classList.contains("jo-section")) {
        selIndex = i;
        paintSel();
        return;
      }
    }
  }
  function paintSel() {
    if (!overlay) return;
    var pick = visible[selIndex];
    for (var i = 0; i < items.length; i++) {
      items[i].classList.toggle("sel", i === pick);
    }
    if (items[pick]) items[pick].scrollIntoView({ block: "nearest" });
  }

  function openOverlay() {
    if (!overlay) buildOverlay();
    highlightCurrent();
    overlay.classList.add("open");
    jumpInput.value = "";
    applyFilter("");      /* clears any previous search and parks the cursor  */
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
    talkGoesOn();             /* ...and ends a pause: the talk goes on */
    showSlide(n, false, 0);   /* a jump has no direction of travel */
  }

  /* ---------------------------------------------------------------------- */
  /* Code-style modal. Same chrome as the jump overlay (the jo-* classes),   */
  /* opened with the s key. It lists the shipped code styles as clickable     */
  /* items and swaps the highlight-rexx-<style> class on every code block,    */
  /* persisting the choice in localStorage. This is the logic that used to     */
  /* live in chooser.js behind a <select>; the F8 control box that held that   */
  /* select is gone, so the behaviour moved here and the overlay carries it.   */
  /* ---------------------------------------------------------------------- */

  var STYLE_KEY = "rexxpub.deck.rexxStyle";
  var styleOverlay = null, currentStyle = null, styleSel = 0;

  function applyStyle(style) {
    /* Skip blocks whose style the author fixed with style= : the HTML driver  */
    /* marks them with data-rexx-style-locked so a client-side chooser leaves   */
    /* them alone. Their inner tokens inherit colour by descent and carry no    */
    /* highlight-rexx- class of their own, so excluding the container suffices.  */
    var blocks = document.querySelectorAll(
      '[class*="highlight-rexx-"]:not([data-rexx-style-locked])');
    for (var i = 0; i < blocks.length; i++) {
      blocks[i].className = blocks[i].className.replace(
        /highlight-rexx-[A-Za-z0-9._-]+/g, "highlight-rexx-" + style);
    }
    currentStyle = style;
    try { localStorage.setItem(STYLE_KEY, style); } catch (e) {}
    highlightCurrentStyle();
  }

  function buildStyleOverlay() {
    styleOverlay = document.createElement("div");
    styleOverlay.id = "style-overlay";
    /* Reuse the jump overlay's jo-panel chrome verbatim so the two modals are  */
    /* visually identical (JMB: "idéntico"). Only the head label and hint text   */
    /* differ; there is no typed-input field here, styles are picked by click.  */
    styleOverlay.innerHTML =
      '<div class="jo-panel">' +
        '<div class="jo-head">' +
          '<span>Code style</span>' +
        '</div>' +
        '<div class="jo-list" id="so-list"></div>' +
        '<div class="jo-hint">&uarr;&darr; select &middot; Enter apply &middot; ' +
          'Esc close &middot; F1 keys</div>' +
      '</div>';
    document.body.appendChild(styleOverlay);

    var list = styleOverlay.querySelector("#so-list");
    REXX_STYLES.forEach(function (st, i) {
      var item = document.createElement("button");
      item.type = "button";
      item.className = "jo-item";
      item.setAttribute("data-style", st.v);
      item.innerHTML = '<span class="jo-label">' + st.v + '</span>' +
                       (st.d ? '<span class="jo-kind">default</span>' : '');
      item.addEventListener("click", function () {
        styleSel = i; applyStyle(st.v); closeStyleOverlay();
      });
      list.appendChild(item);
    });

    styleOverlay.addEventListener("click", function (e) {
      if (e.target === styleOverlay) closeStyleOverlay();
    });
  }

  function openStyleOverlay() {
    if (!styleOverlay) buildStyleOverlay();
    highlightCurrentStyle();
    /* Selection starts on the active style, so Arrow-down steps to the next one. */
    styleSel = 0;
    for (var i = 0; i < REXX_STYLES.length; i++) {
      if (REXX_STYLES[i].v === currentStyle) { styleSel = i; break; }
    }
    paintStyleSel();
    styleOverlay.classList.add("open");
  }
  function closeStyleOverlay() {
    if (styleOverlay) styleOverlay.classList.remove("open");
    focusStage();
  }
  function styleOverlayOpen() {
    return styleOverlay && styleOverlay.classList.contains("open");
  }
  function highlightCurrentStyle() {
    if (!styleOverlay) return;
    var items = styleOverlay.querySelectorAll(".jo-item");
    for (var i = 0; i < items.length; i++) {
      items[i].classList.toggle(
        "here", items[i].getAttribute("data-style") === currentStyle);
    }
  }
  function moveStyleSel(key) {
    var n = REXX_STYLES.length;
    if (key === "ArrowDown") styleSel = (styleSel + 1) % n;
    else if (key === "ArrowUp") styleSel = (styleSel - 1 + n) % n;
    else if (key === "Home") styleSel = 0;
    else if (key === "End") styleSel = n - 1;
    paintStyleSel();
  }
  function paintStyleSel() {
    if (!styleOverlay) return;
    var items = styleOverlay.querySelectorAll(".jo-item");
    for (var i = 0; i < items.length; i++) {
      items[i].classList.toggle("sel", i === styleSel);
    }
    if (items[styleSel]) {
      items[styleSel].scrollIntoView({ block: "nearest" });
    }
  }

  /* Restore a saved style at load, before any modal is opened, so the deck     */
  /* comes up in the last-chosen style; falls back to the deck default (the      */
  /* entry flagged d:true), which is what the server already rendered.          */
  function initStyle() {
    var saved = null;
    try { saved = localStorage.getItem(STYLE_KEY); } catch (e) {}
    if (saved) {
      applyStyle(saved);
    } else {
      for (var i = 0; i < REXX_STYLES.length; i++) {
        if (REXX_STYLES[i].d) { currentStyle = REXX_STYLES[i].v; break; }
      }
    }
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

    /* Esc over a red overtime popup: "I know" -- no more of them until the */
    /* timer restarts (see timerTick). Esc is what one tries; T does the    */
    /* same without leaving full screen, which Esc also does when the deck  */
    /* went full screen with F.                                             */
    if (e.key === "Escape" && toastOpen() && toastKind === "over") {
      muteOvertime();
      showToast("Overtime popups off · R twice restarts the timer", "info");
      e.preventDefault(); return;
    }

    /* A timer popup goes away with the next key, which still does its job. */
    /* T and R are the timer's own, and answer even over a blank screen.     */
    if (!/^(Shift|Control|Alt|Meta)$/.test(e.key) && e.key !== "t" && e.key !== "T") hideToast();
    if (!helpOpen() && !aboutOpen() && !statsOpen() && !overlayOpen() && !styleOverlayOpen() &&
        !(e.target && /^(INPUT|SELECT|TEXTAREA)$/.test(e.target.tagName)) &&
        !e.ctrlKey && !e.metaKey && !e.altKey && onTimerKey(e.key)) {
      e.preventDefault(); return;
    }

    /* Before everything, including the guard on text fields below: F1 is not  */
    /* a character, so it is the one key that can mean the same thing wherever */
    /* the keyboard happens to be.                                            */
    if (e.key === "F1") { toggleHelp(); e.preventDefault(); return; }
    if (helpOpen()) {
      if (e.key === "Escape") { closeHelp(); e.preventDefault(); }
      else if (e.key === "a" || e.key === "A") { openAbout(); e.preventDefault(); }
      return;                      /* help is modal: nothing moves behind it  */
    }
    if (statsOpen()) {             /* and the time per slide; its fields type  */
      if (e.target && /^(INPUT|SELECT|TEXTAREA)$/.test(e.target.tagName)) {
        if (e.key === "Escape") { e.target.blur(); e.preventDefault(); }
        return;
      }
      if (e.key === "Escape" || e.key === "h" || e.key === "H") {
        closeStats(); e.preventDefault();
      }
      return;
    }
    if (aboutOpen()) {             /* so is the about page                     */
      if (e.key === "Escape" || e.key === "a" || e.key === "A") {
        closeAbout(); e.preventDefault();
      }
      return;
    }

    /* The jump input handles its own keys (and stops propagation), but guard   */
    /* other controls the same way the original did.                           */
    if (e.target && /^(INPUT|SELECT|TEXTAREA)$/.test(e.target.tagName)) return;

    /* While the jump overlay is open, only Escape (handled on the input) and   */
    /* clicks matter; swallow stray keys so they do not navigate underneath.    */
    if (overlayOpen()) {
      if (e.key === "Escape") { closeOverlay(); e.preventDefault(); }
      return;
    }

    /* The code-style modal has no text field, so its arrow/Enter navigation is  */
    /* driven here: arrows move the highlighted style, Enter applies it, Escape   */
    /* closes. Styles can still be picked by click. Everything else is swallowed  */
    /* so it cannot navigate the deck underneath.                                 */
    if (styleOverlayOpen()) {
      if (e.key === "Escape") { closeStyleOverlay(); e.preventDefault(); }
      else if (e.key === "ArrowDown" || e.key === "ArrowUp" ||
               e.key === "Home"      || e.key === "End") {
        moveStyleSel(e.key); e.preventDefault();
      } else if (e.key === "Enter") {
        var st = REXX_STYLES[styleSel];
        if (st) { applyStyle(st.v); closeStyleOverlay(); }
        e.preventDefault();
      }
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

    /* Alt+PageDown / Alt+PageUp leaf through the deck: the next or previous */
    /* slide at once, complete, with no page transition and no fragment       */
    /* animation (Rony: "quick scrolling full-page through the presentation   */
    /* ad hoc"). Before the switch, which would take them for plain paging.   */
    if (e.altKey && (e.key === "PageDown" || e.key === "PageUp")) {
      leaf(e.key === "PageDown" ? 1 : -1); e.preventDefault(); return;
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

      case "s": case "S":
        openStyleOverlay(); e.preventDefault(); break;

      case "d": case "D":
        toggleDiagnose(); e.preventDefault(); break;

      case "a": case "A":
        openAbout(); e.preventDefault(); break;

      case "b": case "B":
        setBlank(isBlank() ? null : "#000"); e.preventDefault(); break;
      case "w": case "W":
        setBlank(isBlank() ? null : "#fff"); e.preventDefault(); break;

      case "f": case "F":
        toggleFullscreen(); e.preventDefault(); break;

      case "Escape":
        setBlank(null); break;

      default:
        /* A bare digit opens the overlay pre-filled, so typing "12<Enter>"      */
        /* works straight from the slide, PowerPoint-style.                     */
        if (/^[0-9]$/.test(e.key)) {
          openOverlay();
          jumpInput.value = e.key;
          applyFilter(jumpInput.value);
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
    hideToast();                        /* a timer popup goes with the click  */
    if (e.target.closest &&
        e.target.closest("a, #jump-overlay, #style-overlay, #help-overlay, #about-overlay, #stats-overlay, #countdown-ask")) return;
    if (askOpen()) { closeAsk(); return; }  /* a click outside the dialog: never mind */
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

  /* ---------------------------------------------------------------------- */
  /* Diagnose (d). A deck-HEALTH mode the author turns on to find problems   */
  /* that are invisible by default -- starting with slides whose content     */
  /* overflows the footer band. fitHeight already computes that per visited   */
  /* slide and writes data-overflows, but nothing painted it and only the     */
  /* current slide was ever measured; Rony found the overflows by eye, one    */
  /* slide at a time. Diagnose is the place that surfaces them all at once.   */
  /*                                                                          */
  /* It is EPHEMERAL on purpose: a session toggle, never in the URL or        */
  /* persisted. A deck cannot get stuck in diagnose, so it can never reach a  */
  /* projector wearing warning marks -- which is the one thing the author     */
  /* must be able to trust. @media print drops it too (runtime.css), so a     */
  /* handout printed with the mode still on comes out clean regardless.       */
  /*                                                                          */
  /* The panel is a CONTAINER: overflow is its first check, but the shape     */
  /* (scan -> findings -> HUD list + in-situ marks) takes any future health   */
  /* check the same way -- content past the slide edge, orphaned fragments,   */
  /* over-wide tables. Add a checker to scanHealth(); the HUD and the key do  */
  /* not change.                                                              */
  /* ---------------------------------------------------------------------- */

  var diagnoseOn = false, diagHud = null, diagFindings = [];

  /* One health pass over the whole deck. Each finding is {slide, index,      */
  /* kind, label}. Measuring needs real layout, so a slide is momentarily    */
  /* shown off-screen if it is not the current one -- cheaper than it looks   */
  /* (layout only, no paint) and done once per toggle, not per frame.        */
  /* A slide is only measurable as .current: that is the one that is display    */
  /* :block and laid out (the comment on fitHeight says as much). So the scan    */
  /* makes each slide current in turn, measures it with all its fragments        */
  /* revealed -- the fullest the slide ever gets -- then restores the deck to    */
  /* exactly the slide and fragment state it started in. Layout only, no paint,  */
  /* once per toggle.                                                           */
  function scanHealth() {
    diagFindings = [];
    var band = footerBand();
    var start = current;

    slides.forEach(function (s, i) {
      slides[start].classList.remove("current");
      s.classList.add("current");

      var revealed = [];
      s.querySelectorAll(".fragment:not(.revealed)").forEach(function (f) {
        f.classList.add("revealed"); revealed.push(f);
      });

      /* Read every measurement WHILE the slide is current: off current it is    */
      /* display:none, so clientHeight would read 0 and every slide would look   */
      /* like an overflow. Capture height and bottom first, THEN restore.        */
      var slideH = s.clientHeight;
      var bottom = contentBottom(s);
      var limit  = slideH - band;
      fitBoxes(s);
      var clipped = [];
      s.querySelectorAll(".margin [data-clipped]").forEach(function (b) {
        var edge = b.parentElement.classList.contains("header") ? "header" : "footer";
        var side = b.classList.contains("m-left") ? "left" :
                   (b.classList.contains("m-center") ? "center" : "right");
        clipped.push(edge + "-" + side);
      });
      var titleClipped = [];
      s.querySelectorAll(":scope > .title[data-clipped], :scope > .subtitle[data-clipped]").forEach(function (b) {
        titleClipped.push(b.classList.contains("title") ? "title" : "subtitle");
      });

      revealed.forEach(function (f) { f.classList.remove("revealed"); });
      s.classList.remove("current");

      if (bottom > slideH) {
        diagFindings.push({ slide: s, index: i, kind: "overflow-slide",
          label: "content runs off the slide" });
        s.setAttribute("data-diag", "overflow-slide");
      } else if (bottom > limit) {
        diagFindings.push({ slide: s, index: i, kind: "overflow-footer",
          label: "content runs into the footer band" });
        s.setAttribute("data-diag", "overflow-footer");
      } else {
        s.removeAttribute("data-diag");
      }
      /* fitBoxes, above, has just drawn the slide's arrows: whatever they    */
      /* could not resolve is on their carriers.                              */
      arrowsOf(s).forEach(function (a) {
        (a.arrowProblems || []).forEach(function (msg) {
          diagFindings.push({ slide: s, index: i, kind: "arrow", label: msg });
        });
      });
      titleClipped.forEach(function (box) {
        diagFindings.push({ slide: s, index: i, kind: "title-clipped",
          label: "the " + box + " does not fit its zone, even at " +
                 Math.round(TITLE_FLOOR * 100) + "% size" });
      });
      clipped.forEach(function (box) {
        diagFindings.push({ slide: s, index: i, kind: "margin-clipped",
          label: "the " + box + " box does not show all its text, even at " +
                 Math.round(MARGIN_FLOOR * 100) + "% size" });
      });
    });

    /* Put the slide we were on back as current, with its own fragment state.  */
    slides[start].classList.add("current");

    /* The build's own warnings (unbalanced ':::', stray fences, missing      */
    /* fields...), embedded by md2slides. They are listed here too because   */
    /* an author who builds from a double click or an editor never sees the  */
    /* console -- Rony read "no warnings" off a deck that had seven.         */
    buildWarnings().forEach(function (w) {
      var m = /\(slide (\d+)\)|^slide (\d+):/.exec(w);
      var n = m ? parseInt(m[1] || m[2], 10) : 0;
      var i = (n >= 1 && n <= slides.length) ? n - 1 : -1;
      diagFindings.push({ slide: i >= 0 ? slides[i] : null, index: i,
        kind: "build", label: "build: " + w });
    });

    /* The spotlight's own findings: a [text] that is not in its block, lines */
    /* on a block without numbers... They are only known once the deck has    */
    /* been mounted in the browser, and a mark that fails to appear otherwise */
    /* looks exactly like a deck that works.                                 */
    if (window.Spotlight && window.Spotlight.findings) {
      window.Spotlight.findings.forEach(function (f) {
        var s = f.el && f.el.closest ? f.el.closest(".slide") : null;
        var i = s ? slides.indexOf(s) : -1;
        diagFindings.push({ slide: s, index: i, kind: "spot", label: f.message });
      });
    }
    return diagFindings;
  }

  function buildWarnings() {
    var el = document.getElementById("build-warnings");
    if (!el) return [];
    try { var w = JSON.parse(el.textContent); return Array.isArray(w) ? w : []; }
    catch (e) { return []; }
  }

  function escapeHTML(t) {
    return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;");
  }

  function buildDiagHud() {
    diagHud = document.createElement("div");
    diagHud.id = "diag-hud";
    diagHud.innerHTML =
      '<div class="dg-bar">' +
        '<button class="dg-toggle" title="Collapse / expand">' +
          '<span class="dg-count"></span>' +
        '</button>' +
        '<span class="dg-title">Deck health</span>' +
        '<button class="dg-close" title="Close (d)">×</button>' +
      '</div>' +
      '<div class="dg-list"></div>';
    document.body.appendChild(diagHud);

    diagHud.querySelector(".dg-toggle").addEventListener("click", function () {
      diagHud.classList.toggle("collapsed");
    });
    diagHud.querySelector(".dg-close").addEventListener("click", function () {
      toggleDiagnose();
    });
    diagHud.querySelector(".dg-list").addEventListener("click", function (e) {
      var row = e.target.closest(".dg-row");
      if (!row) return;
      var i = parseInt(row.getAttribute("data-i"), 10);
      if (i >= 0) showSlide(i, false, 0);
    });
  }

  function renderDiagHud() {
    if (!diagHud) buildDiagHud();
    var n = diagFindings.length;
    diagHud.querySelector(".dg-count").textContent =
      (n ? "⚠ " : "✓ ") + n;
    diagHud.classList.toggle("clean", n === 0);
    var list = diagHud.querySelector(".dg-list");
    if (!n) {
      list.innerHTML = '<div class="dg-empty">No problems found.</div>';
      return;
    }
    var html = "";
    for (var i = 0; i < diagFindings.length; i++) {
      var f = diagFindings[i];
      html += '<div class="dg-row dg-' + f.kind + '" data-i="' + f.index + '">' +
                '<span class="dg-slide">' + (f.index >= 0 ? f.index + 1 : "–") +
                '</span>' +
                '<span class="dg-label">' + escapeHTML(f.label) + '</span>' +
              '</div>';
    }
    list.innerHTML = html;
  }

  function toggleDiagnose() {
    diagnoseOn = !diagnoseOn;
    if (diagnoseOn) {
      /* Measure BEFORE turning the mode on, so the diagnose CSS (marks, the    */
      /* footer-band overlay) cannot perturb the very layout we are measuring.  */
      scanHealth();
      document.body.classList.add("diagnose");
      renderDiagHud();
      if (diagHud) diagHud.classList.add("open");
    } else {
      document.body.classList.remove("diagnose");
      if (diagHud) diagHud.classList.remove("open");
      /* Leave data-diag marks in the DOM off when the mode is off: the CSS   */
      /* only paints them under body.diagnose, so nothing shows, but clearing  */
      /* them keeps a stale mark from surviving a source edit + toggle.        */
      slides.forEach(function (s) { s.removeAttribute("data-diag"); });
    }
  }

  /* ---------------------------------------------------------------------- */
  /* Init                                                                    */
  /* ---------------------------------------------------------------------- */

  function init() {
    stage  = document.getElementById("stage");
    slides = Array.prototype.slice.call(document.querySelectorAll(".slide"));
    if (!slides.length) return;

    /* Mount the spotlight BEFORE the first setAllFragments: mounting can    */
    /* insert a hidden .fragment sentinel for a beat that has no prose       */
    /* fragment of its own, and those sentinels must be in the DOM before    */
    /* anything counts or clears fragments.                                  */
    if (window.Spotlight) slides.forEach(window.Spotlight.mount);
    slides.forEach(mountArrows);        /* after the spotlight: see cues()    */

    slides.forEach(function (s) { setAllFragments(s, false); });
    numberSlides();
    initStyle();
    mountAboutSheet();                  /* after `slides`: it is not one      */
    initTimer();
    initRehearsal();

    current = slideFromHash();
    slidePause(slides[current]);        /* landing on a .pause slide, too     */
    recOpen();                          /* a run going on goes on (a reload)   */
    if (clockOn) setTimeout(drawClock, 0);
    noteSection();
    slides.forEach(function (s, i) {
      s.classList.toggle("current", i === current);
    });
    triggerPageAnim(slides[current]);

    rescale();
    fitHeight(slides[current]);
    fitAllBoxes();
    /* The web fonts land after init; boxes fitted with the fallback face may */
    /* no longer fit (or may have room to grow back). Refit once they are in. */
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(fitAllBoxes);
    }
    window.addEventListener("beforeprint", fitAllBoxes);
    updateProgress();
    scheduleTimers(slides[current]);
    startEntryChain(slides[current]);

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