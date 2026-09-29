/******************************************************************************/
/*                                                                            */
/*  spotlight.js - beats that light up lines of a listing                     */
/*                                                                            */
/*  A BEAT is a named group of things that happen on the same click. Anything */
/*  can join a beat: lines of a listing, and prose fragments. That is the     */
/*  whole model, and it is why "synchronise a fragment with a spotlight" is   */
/*  not a feature of its own -- a fragment simply joins the beat.             */
/*                                                                            */
/*      ::: {.fragment spot=init}                                             */
/*      This line builds the object...                                        */
/*      :::                                                                   */
/*                                                                            */
/*      ~~~rexx   {.numberLines spot="init:2"}                                */
/*      ~~~output {.numberLines spot="init:1"}                                */
/*                                                                            */
/*  One click: the sentence appears AND line 2 of the program AND line 1 of   */
/*  the output light up.                                                      */
/*                                                                            */
/*  The name is an IDENTIFIER, never an ordinal. "init" does not mean "first";*/
/*  order comes from document position, not from the name. Numbers would      */
/*  invite the opposite reading and break silently on a reorder, so names.    */
/*                                                                            */
/*  TWO EMITTERS, ONE SHAPE. Rexx listings are ours and come out as           */
/*  <span id="rxN-M">; everything else (output, python, plain text) is        */
/*  Pandoc's and comes out as <span id="cbN-M">. We never branch on which:    */
/*  in BOTH, the number after the last dash is the line number the audience   */
/*  sees -- with startFrom=97 the first span really is id="rx1-97". So the id */
/*  suffix IS the normalisation, and it costs nothing.                        */
/*                                                                            */
/******************************************************************************/

(function (global) {
  "use strict";

  /* Author-facing diagnostics. Deliberately a warning and never an exception: */
  /* a malformed spec must not stop a lecture, but it must not pass unnoticed  */
  /* either. Collected in Spotlight.warnings as well as logged, so a test can  */
  /* assert on them without scraping the console. FINDINGS keeps the element a */
  /* warning is about, so the slide runtime's diagnose mode (d) can say which  */
  /* slide it is on: an author who builds by double click never sees a        */
  /* console, and a mark that silently fails to appear looks like a deck that */
  /* works.                                                                   */
  var warnings = [];
  var findings = [];
  var reading  = null;           /* the element whose spot= is being parsed */
  function warn(msg, el) {
    warnings.push(msg);
    findings.push({ el: el || reading, message: msg });
    if (global.console && global.console.warn) global.console.warn(msg);
  }

  /* --------------------------------------------------------------------     */
  /* Spec parsing.  spot="init:2 salary:5-7,9 trap:[NOVALUE NAME ANY],5[ANY:]"*/
  /*                                                                          */
  /*   name:items    name is a beat name; items is a comma list of            */
  /*                   N or N-M       whole lines (inclusive), and            */
  /*                   [text]         that text, wherever it is in the block, */
  /*                   N[text]        that text, on line N only.              */
  /*                                                                          */
  /*   caseless      not a beat: the texts of this spot= are found ignoring  */
  /*                 case. Without it a text is found as written (v224; it    */
  /*                 used to ignore case always, when the Highlighter lowered */
  /*                 a Rexx fence's spot= and the text could not be trusted). */
  /*                                                                          */
  /* On a FRAGMENT the spec is just names, with no ":items" -- a fragment     */
  /* has nothing to mark.  Same attribute, one rule: "spot= says which        */
  /* beats I take part in; if I am a listing, I also say what lights up".     */
  /*                                                                          */
  /* A text may hold blanks, commas, semicolons and colons: every separator   */
  /* is only a separator OUTSIDE square brackets. Brackets pair up, so        */
  /* [a[1]] is the text a[1].                                                 */
  /* --------------------------------------------------------------------     */

  /* Split s at every character of `seps` that is outside square brackets.    */
  /* Returns null when the brackets do not pair up, so the caller can say so. */
  function splitOutside(s, seps) {
    var out = [], cur = "", depth = 0;
    for (var i = 0; i < s.length; i++) {
      var c = s.charAt(i);
      if (c === "[") depth++;
      else if (c === "]") { if (!depth) return null; depth--; }
      if (!depth && seps.indexOf(c) >= 0) { out.push(cur); cur = ""; }
      else cur += c;
    }
    if (depth) return null;
    out.push(cur);
    return out;
  }

  function parseSpec(spec) {
    var out = [];
    /* Terms separate on whitespace OR semicolons, and a semicolon may be      */
    /* followed by a space: spot="init:2 salary:5" and spot="init:2; salary:5" */
    /* are the same thing. Both are accepted because both read naturally and   */
    /* neither is ambiguous -- a beat name can contain neither character. The  */
    /* semicolon earns its place on a long spec, where it groups the eye.      */
    var terms = splitOutside((spec || "").trim(), " \t\r\n;");
    if (!terms) {
      warn('spot=: the square brackets do not pair up in "' + spec + '"');
      return out;
    }
    terms.forEach(function (term) {
      if (!term) return;
      if (term.toLowerCase() === "caseless") { out.caseless = true; return; }
      var i = term.indexOf(":");
      var b = term.indexOf("[");
      if (b >= 0 && (i < 0 || b < i)) i = -1;         /* ':' inside a text   */
      /* Beat names ignore case, as Rexx symbols do. Not a nicety: a Rexx     */
      /* listing's spot= used to reach us LOWERCASED (the Highlighter lowered */
      /* every option value but caption=; since v222 it keeps spot= too),     */
      /* while a fragment's spot= comes from Pandoc untouched. So             */
      /* spot="Init:1" on a ~~~rexx fence and {.fragment spot=Init} were two  */
      /* beats, "init" and "Init", firing on two clicks -- and nothing said   */
      /* so. Folding here, where every name is read, makes both spellings one */
      /* beat.                                                                */
      var name = (i < 0 ? term : term.slice(0, i)).trim().toLowerCase();
      if (!name || name.indexOf("[") >= 0) {
        warn('spot=: "' + term + '" names no beat (write name:[text])');
        return;
      }
      var lines = [], texts = [];
      if (i >= 0) {
        splitOutside(term.slice(i + 1), ",").forEach(function (r) {
          var item = r.trim();
          var m = /^(\d+)(?:-(\d+))?$/.exec(item);
          var t = /^(\d+)?\[([\s\S]*)\]$/.exec(item);
          if (m) {
            var a = +m[1], z = m[2] ? +m[2] : a;
            if (z < a) { var tmp = a; a = z; z = tmp; }
            for (var n = a; n <= z; n++) lines.push(n);
          } else if (t && t[2] !== "") {
            texts.push({ line: t[1] ? +t[1] : null, text: t[2] });
          } else {
            /* Say so. Silence here cost a real bug: before semicolons were   */
            /* accepted, spot="init:2; salary:5" left "init" with no lines at */
            /* all -- "2;" failed this test, was dropped, and the deck looked */
            /* like it had worked. A spec that does not parse is an author's  */
            /* typo, and an author who is told fixes it in ten seconds.       */
            warn('spot=: cannot read "' + item + '" as a line, a range' +
                 ' or a [text] (in "' + spec + '")');
          }
        });
      }
      out.push({ beat: name, lines: lines, texts: texts });
    });
    return out;
  }

  /* Line elements of a listing, keyed by the number the audience sees.       */
  function linesOf(block) {
    var map = {};
    var spans = block.querySelectorAll("code > span[id]");
    for (var i = 0; i < spans.length; i++) {
      var m = /-(\d+)$/.exec(spans[i].id);
      if (m) map[+m[1]] = spans[i];
    }
    return map;
  }

  /* --------------------------------------------------------------------     */
  /* Marking a TEXT: spot="trap:[NOVALUE NAME ANY]"                           */
  /*                                                                          */
  /* The text is the address, so the author copies from the listing what to   */
  /* mark and counts nothing. Matching rules, each for a reason:              */
  /*   - case counts, unless the spot= says `caseless` (Rony, 28-Sep: he     */
  /*     copies the text from the listing, and a word that must be marked    */
  /*     everywhere in any case is the exception);                           */
  /*   - whole words: a text that starts (ends) with a letter, digit or _     */
  /*     does not match right after (before) another one, so [say] is not    */
  /*     found inside say2stderr, nor [ANY] inside MANY;                      */
  /*   - one line at most: the text cannot hold a line end, so neither can a  */
  /*     match. A run of lines is what a whole-line mark is for.              */
  /*                                                                          */
  /* The match is done on the block's TEXT, across however many elements the  */
  /* emitter split it into -- a Rexx string is three spans, "ANY:" is two --  */
  /* and each piece of text it covers is wrapped in a <mark>. The token spans */
  /* stay as they were, so the colouring survives under the wash. It is a     */
  /* <mark> and not a <span> so that it can never be taken for a LINE: a      */
  /* line is a span whose parent is <code>, and in a block without line spans */
  /* (an unnumbered ~~~output) a span wrapped at the top would be exactly     */
  /* that.                                                                    */
  /* --------------------------------------------------------------------     */
  var WORD = /[\p{L}\p{N}_]/u;

  function textNodesOf(code) {
    var nodes = [], full = "";
    var walk = document.createTreeWalker(code, NodeFilter.SHOW_TEXT, null);
    for (var n = walk.nextNode(); n; n = walk.nextNode()) {
      nodes.push({ node: n, start: full.length });
      full += n.data;
    }
    return { nodes: nodes, full: full };
  }

  /* The [from, to) offsets of line `n` in the block's text, or null.         */
  function lineRange(tn, lineEl, n) {
    if (lineEl) {                               /* numbered: its own span     */
      var from = -1, to = -1;
      tn.nodes.forEach(function (x) {
        if (lineEl.contains(x.node)) {
          if (from < 0) from = x.start;
          to = x.start + x.node.data.length;
        }
      });
      return from < 0 ? null : [from, to];
    }
    var rows = tn.full.split("\n"), at = 0;     /* unnumbered: count them    */
    for (var i = 1; i <= rows.length; i++) {
      if (i === n) return [at, at + rows[i - 1].length];
      at += rows[i - 1].length + 1;
    }
    return null;
  }

  function escapeRegExp(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  /* Wrap [a, b) of one text node in a <mark>; returns the mark.              */
  function wrapPiece(node, a, b, beat) {
    var mid = a > 0 ? node.splitText(a) : node;
    if (b - a < mid.data.length) mid.splitText(b - a);
    var mark = document.createElement("mark");
    mark.className = "spot-mark";
    mark.setAttribute("data-spot-beat", beat);
    mid.parentNode.insertBefore(mark, mid);
    mark.appendChild(mid);
    return mark;
  }

  /* The [from, to) offsets of every whole-word match of item.text in the     */
  /* block's text (restricted to item.line when it has one). Shared by the    */
  /* marks, which wrap each match, and by locate(), which only measures them. */
  function findText(tn, lines, item) {
    var from = 0, to = tn.full.length;
    if (item.line !== null) {
      var r = lineRange(tn, lines ? lines[item.line] || null : null, item.line);
      if (!r || (lines && !lines[item.line])) return [];
      from = r[0]; to = r[1];
    }
    var hay = tn.full.slice(from, to);
    var re  = new RegExp(escapeRegExp(item.text), item.caseless ? "gi" : "g");
    var first = item.text.charAt(0), last = item.text.charAt(item.text.length - 1);
    var hits = [], m;
    while ((m = re.exec(hay)) !== null) {
      var s = m.index, e = s + m[0].length;
      var before = s > 0 ? hay.charAt(s - 1) : "";
      var after  = e < hay.length ? hay.charAt(e) : "";
      if ((WORD.test(first) && before && WORD.test(before)) ||
          (WORD.test(last)  && after  && WORD.test(after))) {
        re.lastIndex = s + 1;                 /* not a whole word: go on    */
        continue;
      }
      hits.push([from + s, from + e]);
    }
    return hits;
  }

  /* Mark every match of item.text in `code`; returns how many were marked.   */
  function markText(block, code, lines, item, beat) {
    var tn   = textNodesOf(code);
    var hits = findText(tn, lines, item);
    /* Wrap from the END backwards: splitting a text node leaves the node     */
    /* object holding the part BEFORE the split, so every offset still to be  */
    /* used, which lies before it, stays valid.                              */
    for (var h = hits.length - 1; h >= 0; h--) {
      var pieces = [];
      for (var k = tn.nodes.length - 1; k >= 0; k--) {
        var x = tn.nodes[k], len = x.node.data.length;
        var a = Math.max(hits[h][0], x.start) - x.start;
        var z = Math.min(hits[h][1], x.start + len) - x.start;
        if (a < z) pieces.unshift(wrapPiece(x.node, a, z, beat));
      }
      /* The ends of a mark are rounded; a mark cut into pieces by the token  */
      /* spans must still read as one stroke, so only its first and last     */
      /* piece get the round corner.                                          */
      if (pieces.length) {
        pieces[0].classList.add("spot-mark-first");
        pieces[pieces.length - 1].classList.add("spot-mark-last");
      }
    }
    return hits.length;
  }

  /* --------------------------------------------------------------------     */
  /* locate(block, items) -> { ranges, missing, bad, nocode }                 */
  /*                                                                          */
  /* The addresses of spot=, used to POINT at part of a block instead of      */
  /* marking it: the end of an arrow, to="cmd[2>myerrors.txt]" or to=cmd:1.  */
  /* `items` is what follows the beat name in spot= -- 1, 2-3, [text],        */
  /* 5[text], comma separated -- and it reads the same way: whole words,      */
  /* case ignored, one line at most, and line numbers are the ones the        */
  /* audience sees (or counted from 1 in a block that shows none, since here  */
  /* nobody has to read them off the screen: the author wrote the block).     */
  /*                                                                          */
  /* Nothing is wrapped. Each hit comes back as a DOM Range for the caller to */
  /* measure. A whole line is trimmed of its blanks first, so an indented     */
  /* line is pointed at where its text is, not where its indentation starts.  */
  /* What could not be found is in `missing` (for the caller to report, with  */
  /* the arrow it belongs to), what could not be read in `bad`, and `nocode`  */
  /* says the block is not a listing at all.                                  */
  /* --------------------------------------------------------------------     */
  function rangeOf(tn, s, e) {
    var range = document.createRange(), set = false;
    for (var i = 0; i < tn.nodes.length; i++) {
      var x = tn.nodes[i], end = x.start + x.node.data.length;
      if (!set && s >= x.start && s < end) { range.setStart(x.node, s - x.start); set = true; }
      if (set && e > x.start && e <= end) { range.setEnd(x.node, e - x.start); return range; }
    }
    return null;
  }

  function locate(block, items) {
    var out = { ranges: [], missing: [], bad: [], nocode: false };
    var parts = splitOutside(items || "", ",");
    if (!parts) { out.bad.push(items); return out; }
    var code = block.querySelector("pre code");
    if (!code) { out.nocode = true; return out; }
    var tn = textNodesOf(code);
    var lines = linesOf(block);
    var numbered = Object.keys(lines).length > 0;
    parts.forEach(function (r) {
      var item = r.trim();
      var m = /^(\d+)(?:-(\d+))?$/.exec(item);
      var t = /^(\d+)?\[([\s\S]*)\]$/.exec(item);
      if (m) {
        var a = +m[1], z = m[2] ? +m[2] : a;
        if (z < a) { var tmp = a; a = z; z = tmp; }
        for (var n = a; n <= z; n++) {
          var lr = (numbered && !lines[n]) ? null
                 : lineRange(tn, numbered ? lines[n] : null, n);
          var s = lr ? lr[0] : 0, e = lr ? lr[1] : 0;
          while (s < e && /\s/.test(tn.full.charAt(s)))     s++;
          while (e > s && /\s/.test(tn.full.charAt(e - 1))) e--;
          var rg = s < e ? rangeOf(tn, s, e) : null;
          if (rg) out.ranges.push(rg);
          else    out.missing.push("line " + n);
        }
      } else if (t && t[2] !== "") {
        /* An arrow's end ignores case, as it always has: it points, it does  */
        /* not mark, and to= has no room for the `caseless` word of spot=.     */
        var item2 = { line: t[1] ? +t[1] : null, text: t[2], caseless: true };
        var hits = findText(tn, numbered ? lines : null, item2);
        if (!hits.length) {
          out.missing.push('"' + t[2] + '"' +
                           (item2.line !== null ? " (line " + item2.line + ")" : ""));
        }
        hits.forEach(function (h) {
          var hr = rangeOf(tn, h[0], h[1]);
          if (hr) out.ranges.push(hr);
        });
      } else {
        out.bad.push(item);
      }
    });
    return out;
  }

  /* --------------------------------------------------------------------     */
  /* prepare(root)                                                            */
  /*                                                                          */
  /* Walks every element carrying data-spot and marks the participants:       */
  /*   - a listing line joins a beat  -> data-spot-beat="name ..." on the span*/
  /*   - a text of a block joins one  -> a <mark data-spot-beat> around it    */
  /*   - a fragment joins a beat      -> data-spot-beat="name ..." on the div */
  /*                                                                          */
  /* Returns nothing; the DOM now carries everything the reveal needs.        */
  /* --------------------------------------------------------------------     */
  function prepare(root) {
    var carriers = root.querySelectorAll("[data-spot]");
    for (var i = 0; i < carriers.length; i++) {
      var el = carriers[i];
      if (el.hasAttribute("data-spot-ready")) continue;   /* once, ever:     */
      el.setAttribute("data-spot-ready", "");              /* marks nest     */
      reading = el;
      var specs = parseSpec(el.getAttribute("data-spot"));
      reading = null;
      if (!specs.length) continue;

      var code  = el.querySelector("pre code");
      var lines = code ? linesOf(el) : null;
      var numbered = !!(lines && Object.keys(lines).length);

      for (var s = 0; s < specs.length; s++) {
        var spec = specs[s];
        if (!spec.lines.length && !spec.texts.length) {
          addBeat(el, spec.beat);                 /* fragment (or whole block)*/
          continue;
        }
        if (!code) {
          warn('spot="' + el.getAttribute("data-spot") + '": only a code' +
               ' block has lines or texts to mark', el);
          continue;
        }
        if (spec.lines.length && !numbered) {
          /* Used to join the beat as a whole block and light nothing. A line */
          /* number the audience cannot see is not an address: say so, and   */
          /* point at the form that needs no numbers.                        */
          warn('spot="' + el.getAttribute("data-spot") + '": whole lines' +
               ' need .numberLines; to mark a text, write ' + spec.beat +
               ':[text]', el);
        }
        for (var k = 0; numbered && k < spec.lines.length; k++) {
          var span = lines[spec.lines[k]];
          if (span) addBeat(span, spec.beat);     /* a line out of range is a */
        }                                         /* no-op, not an error      */
        for (var t = 0; t < spec.texts.length; t++) {
          var item = spec.texts[t];
          item.caseless = !!specs.caseless;
          if (!markText(el, code, numbered ? lines : null, item, spec.beat)) {
            warn('spot=: "' + item.text + '" is not in this block' +
                 (item.line !== null ? ' (line ' + item.line + ')' : '') +
                 ' as a whole word', el);
          }
        }
      }
    }
  }

  function addBeat(el, beat) {
    var cur = el.getAttribute("data-spot-beat");
    var set = cur ? cur.split(/\s+/) : [];
    if (set.indexOf(beat) < 0) set.push(beat);
    el.setAttribute("data-spot-beat", set.join(" "));
  }

  /* --------------------------------------------------------------------     */
  /* beatsOf(slide) -> ordered array of beat names                            */
  /*                                                                          */
  /* A beat fires only once EVERY listing it touches has already appeared     */
  /* bare, so its position is that of its LAST participant in document        */
  /* order.  This is what makes the teaching gesture come out right: the      */
  /* program appears, the output appears, and only then does the pen strike.  */
  /*                                                                          */
  /* It also has a consequence worth knowing: because a prose fragment is a   */
  /* participant like any other, writing that fragment late in the slide      */
  /* moves the beat late.  Usually exactly what you want (the sentence IS     */
  /* the moment), but it means WHERE you write the fragment changes WHEN the  */
  /* pen strikes.  Documented, not accidental.                                */
  /* --------------------------------------------------------------------     */
  function beatsOf(slide) {
    var seen = Object.create(null);
    var els = slide.querySelectorAll("[data-spot-beat]");
    for (var i = 0; i < els.length; i++) {          /* querySelectorAll is in */
      var names = els[i].getAttribute("data-spot-beat").split(/\s+/);
      for (var j = 0; j < names.length; j++) {
        seen[names[j]] = i;                          /* keep the LAST index   */
      }
    }
    return Object.keys(seen).sort(function (a, b) {
      return seen[a] - seen[b];
    });
  }

  /* Members of a beat inside a slide.                                        */
  function membersOf(slide, beat) {
    return Array.prototype.slice.call(
      slide.querySelectorAll('[data-spot-beat~="' + beat + '"]')
    );
  }

  /* --------------------------------------------------------------------     */
  /* Reveal / hide a beat.  Highlights ACCUMULATE: firing a beat never        */
  /* clears the one before it.  That is the deliberate default -- two live    */
  /* correspondences in two colours read better than one that keeps moving,   */
  /* and nobody has asked for the other behaviour yet.                        */
  /* --------------------------------------------------------------------     */
  function showBeat(slide, beat) { setBeat(slide, beat, true); }
  function hideBeat(slide, beat) { setBeat(slide, beat, false); }

  function setBeat(slide, beat, on) {
    membersOf(slide, beat).forEach(function (el) {
      el.classList.toggle("spot-on", on);
      /* A fragment in a beat is still a fragment: it uses the runtime's own  */
      /* reveal class, so the animation catalogue keeps working untouched.    */
      if (el.classList.contains("fragment")) {
        el.classList.toggle("revealed", on);
      }
    });
    /* The colour is chosen by ordinal position of the beat, so the first     */
    /* correspondence on a slide is always pen 1, the second pen 2 -- stable  */
    /* whatever the author named them.                                        */
  }

  function setAllBeats(slide, on) {
    beatsOf(slide).forEach(function (b) { setBeat(slide, b, on); });
  }

  var PEN_COUNT = 4;

  /* ----------------------------------------------------------------------   */
  /* paint(slide)                                                             */
  /*                                                                          */
  /* Two jobs.                                                                */
  /*                                                                          */
  /* 1. Assign a pen number per beat, by the beat's order on the slide. This  */
  /*    is what makes the program line and the output line of the SAME beat   */
  /*    come out the same colour without the author asking: they share the    */
  /*    beat, so they share the pen.                                          */
  /*                                                                          */
  /* 2. Carry the palette across the emitter boundary. The pens are declared  */
  /*    by each style on .highlight-rexx-<name>, and custom properties only   */
  /*    inherit DOWNWARDS -- so a Rexx listing picks them up, but a ~~~output */
  /*    or ~~~python block does not: those are Pandoc's, they carry no style  */
  /*    class, and they are siblings rather than descendants. Left alone they */
  /*    fall back to the neutral pen, and the correspondence breaks: the      */
  /*    program line goes peach and the output line goes yellow, so the two   */
  /*    stop saying they belong together, which is the entire point.          */
  /*    So we read the resolved values off a Rexx listing on this slide and   */
  /*    set them on the blocks that are out of scope.                         */
  /* ----------------------------------------------------------------------   */
  function paint(slide) {
    beatsOf(slide).forEach(function (beat, i) {
      membersOf(slide, beat).forEach(function (el) {
        if (!el.hasAttribute("data-spot-pen")) {
          el.setAttribute("data-spot-pen", (i % PEN_COUNT) + 1);
        }
      });
    });
    carryPalette(slide);
    measureStroke(slide);
  }

  /* ---------------------------------------------------------------------- */
  /* measureStroke(slide)                                                     */
  /*                                                                          */
  /* Where the stroke starts and how far past its own box it must run. Both   */
  /* ends are off, and for the same reason.                                   */
  /*                                                                          */
  /* A numbered listing slides its line spans left over the number gutter:    */
  /*                                                                          */
  /*     pre.rx-numbered { margin-left: 3em; padding-left: 4px; }             */
  /*     code > span     { position: relative; left: -4em; }                   */
  /*                                                                          */
  /* Relative positioning moves what is PAINTED and leaves the layout box      */
  /* where it was, so the span keeps the width it had -- the width of the      */
  /* <pre>'s content area -- and is simply drawn 4em to the left. Nothing      */
  /* revealed that until something painted a background on it: the line ends   */
  /* short on the right by exactly what it gained on the left, plus the        */
  /* <pre>'s own right padding.                                                */
  /*                                                                          */
  /* The same shift drags the LEFT edge the other way, out of div.code's      */
  /* padding box, and div.code scrolls, so the bar drawn by border-left is    */
  /* clipped away. --spot-bar-x is how much of the box lies outside: give an  */
  /* inset shadow that width and the clip trims it to the 3px that show.     */
  /*                                                                          */
  /* Every number is read off the page rather than written down here. They    */
  /* belong to the style (the gutter is 4em today, in a sheet we do not own   */
  /* and that a new style may set differently), and this file holds no style  */
  /* values by design. Measuring also means a style that changes its gutter   */
  /* tomorrow needs no change here. They are computed-style lengths, in CSS   */
  /* pixels, so a deck scaled by a transform needs no correction -- a rect    */
  /* would have needed one.                                                   */
  /* ---------------------------------------------------------------------- */
  function measureStroke(slide) {
    var blocks = slide.querySelectorAll("[data-spot]");
    for (var i = 0; i < blocks.length; i++) {
      var blk  = blocks[i];
      var pre  = blk.querySelector("pre");
      var line = blk.querySelector("code > span[id]");
      if (!pre || !line) continue;
      var wrap  = pre.parentElement;
      var csL   = getComputedStyle(line);
      var csP   = getComputedStyle(pre);
      var px    = function (v) { return parseFloat(v) || 0; };
      var shift = Math.abs(px(csL.left));                         /* 4em, px */
      var bar   = px(csL.borderLeftWidth);
      var padR  = px(csP.paddingRight);
      /* How far the clipping edge sits to the right of div.code's border.   */
      var inset = px(getComputedStyle(wrap).paddingLeft) +
                  px(csP.marginLeft) + px(csP.borderLeftWidth) +
                  px(csP.paddingLeft);
      blk.style.setProperty("--spot-bleed-r", (shift + padR) + "px");
      blk.style.setProperty("--spot-bar-x",
                            Math.max(0, shift + bar - inset) + "px");
    }
  }

  function carryPalette(slide) {
    /* The donor: any element that actually sits in a style scope.            */
    var donor = slide.querySelector('[class*="highlight-rexx-"]');
    if (!donor) return;
    var cs = getComputedStyle(donor), vals = [];
    for (var i = 1; i <= PEN_COUNT; i++) {
      vals.push([
        cs.getPropertyValue("--spot-pen-" + i + "-bg").trim(),
        cs.getPropertyValue("--spot-pen-" + i + "-bar").trim()
      ]);
    }
    if (!vals[0][0] && !vals[0][1]) return;   /* style declares none: leave   */
                                              /* fallback pen alone           */
    var blocks = slide.querySelectorAll("[data-spot]");
    for (var b = 0; b < blocks.length; b++) {
      var blk = blocks[b];
      if (blk.closest('[class*="highlight-rexx-"]')) continue;  /* in scope   */
      for (var j = 0; j < PEN_COUNT; j++) {
        var v = "--spot-pen-" + (j + 1);
        if (vals[j][0]) blk.style.setProperty(v + "-bg",  vals[j][0]);
        if (vals[j][1]) blk.style.setProperty(v + "-bar", vals[j][1]);
      }
    }
  }

  /* ---------------------------------------------------------------------- */
  /* mount(slide) -- prepare, paint, and give every beat something the host   */
  /* runtime can already advance through.                                    */
  /*                                                                         */
  /* The host walks .fragment elements in document order and reveals them one */
  /* at a time. A beat that contains a prose fragment therefore needs NOTHING */
  /* from us: that fragment is the beat's anchor, the host reaches it on its  */
  /* own, and "synchronise a fragment with a spotlight" falls out for free.   */
  /*                                                                         */
  /* A beat made only of listing lines has no such anchor, so we insert an    */
  /* empty, hidden .fragment after its LAST participant. Last, not first:     */
  /* a beat must not fire until every listing it touches has appeared bare.   */
  /* ---------------------------------------------------------------------- */
  /* ---------------------------------------------------------------------- */
  /* cues(slide) -- an EMPTY element with spot= is a cue: "the beat fires     */
  /* here", with whatever timing word it carries.                            */
  /*                                                                         */
  /*     []{spot=trap .afterPrevious}                                        */
  /*                                                                         */
  /* It has nothing to show and nothing to mark, so it can mean nothing else, */
  /* and it needs no .fragment written: it becomes one here, hidden like the  */
  /* sentinel below. Everything else is the host's ordinary rules -- no word  */
  /* is a press, .afterPrevious chains (and as the first step of a slide, it  */
  /* fires on arrival), .withPrevious joins the step before, group= works.    */
  /* The timing words are read off the element's classes by the host, so     */
  /* they only have to be there when it first counts fragments: mount runs   */
  /* before that.                                                            */
  /* ---------------------------------------------------------------------- */
  /* An ARROW is empty too ([]{.arrow from=a to=b spot=redir}), but it has    */
  /* something to show: the slide runtime draws it. With spot= it joins the   */
  /* beat and comes in with the marks, so it becomes a fragment -- the beat's */
  /* anchor, like a prose fragment -- and stays visible.                      */
  function cues(slide) {
    var els = slide.querySelectorAll("[data-spot]");
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      if (el.children.length || el.textContent.trim()) continue;
      /* An <img> is empty too, and it is a picture to show (v224).          */
      if (el.tagName !== "P" && el.tagName !== "SPAN") continue;
      if (el.classList.contains("arrow")) { el.classList.add("fragment"); continue; }
      if (el.classList.contains("fragment")) continue;
      el.classList.add("fragment", "spot-cue");
      el.setAttribute("aria-hidden", "true");
      el.style.display = "none";
    }
  }

  /* ---------------------------------------------------------------------- */
  /* How a beat's marks come in (v224). Its empty trigger,                    */
  /*                                                                         */
  /*     []{spot=trap .afterPrev anim=pen anim-duration=3}                   */
  /*                                                                         */
  /* has nothing to animate itself, so what it says is for the marks (Rony,  */
  /* 28-Sep: "wherever animation related information is supplied, as a      */
  /* human I would expect it to be honored"): anim-duration= is the time     */
  /* they take, and anim= how they come -- fade (the wash fades in, the      */
  /* default), pen (drawn from left to right) or cut (at once). The CSS side */
  /* is in spotlight.css; here each mark gets --spot-dur and, for the pen,   */
  /* .spot-stroke. A text cut into several <mark>s is one stroke: each piece */
  /* gets its share of the time, by length, and waits for the ones before.  */
  /* ---------------------------------------------------------------------- */
  var MARK_ANIMS = { fade: 1, pen: 1, cut: 1 };

  function isTrigger(el) {
    /* A <p> or a <span>: an <img> in a beat is empty too, and is a picture. */
    return (el.tagName === "P" || el.tagName === "SPAN") &&
           !el.children.length && !el.textContent.trim() &&
           !el.classList.contains("arrow") && el.hasAttribute("data-spot");
  }

  function secondsMs(v) {
    if (v === null || v === "") return null;
    var n = parseFloat(v);
    if (isNaN(n)) return null;
    return /ms\s*$/i.test(v) ? n : n * 1000;
  }

  function animateMarks(slide) {
    beatsOf(slide).forEach(function (beat) {
      var members = membersOf(slide, beat);
      var trigger = null;
      members.forEach(function (el) { if (!trigger && isTrigger(el)) trigger = el; });
      if (!trigger) return;
      var anim = (trigger.getAttribute("data-anim") || "").toLowerCase();
      var ms   = secondsMs(trigger.getAttribute("data-anim-duration"));
      if (anim && !MARK_ANIMS[anim]) {
        warn('spot=' + beat + ': anim=' + anim + ' is not a way for marks to' +
             ' come in (fade, pen or cut)', trigger);
        anim = "";
      }
      if (anim === "cut") ms = 0;
      if (!anim && ms === null) return;
      var dur = ms === null ? 280 : ms;
      var marks = members.filter(function (el) { return !isTrigger(el) &&
        (el.tagName === "MARK" || (el.parentElement && el.parentElement.tagName === "CODE")); });
      if (anim !== "pen") {
        marks.forEach(function (m) { m.style.setProperty("--spot-dur", dur + "ms"); });
        return;
      }
      /* The pen: one stroke per run of marks, first to last, by length.     */
      var run = [];
      function flush() {
        var total = 0;
        run.forEach(function (m) { total += m.textContent.length || 1; });
        var at = 0;
        run.forEach(function (m) {
          var len = m.textContent.length || 1;
          m.classList.add("spot-stroke");
          m.style.setProperty("--spot-dur", (dur * len / total) + "ms");
          m.style.transitionDelay = (dur * at / total) + "ms";
          at += len;
        });
        run = [];
      }
      marks.forEach(function (m) {
        if (m.tagName !== "MARK") { run.push(m); flush(); return; }
        run.push(m);
        if (m.classList.contains("spot-mark-last")) flush();
      });
      if (run.length) flush();
    });
  }

  function mount(slide) {
    cues(slide);
    prepare(slide);
    paint(slide);
    animateMarks(slide);
    beatsOf(slide).forEach(function (beat) {
      var members = membersOf(slide, beat);
      var hasAnchor = members.some(function (el) {
        return el.classList.contains("fragment");
      });
      if (hasAnchor) return;

      /* Anchor on the last participant. For a marked LINE that is its own   */
      /* listing, not the line: the sentinel has to sit after the whole      */
      /* block, or it would land inside <code> and break the listing.        */
      var last = null;
      members.forEach(function (el) {
        var block = el.closest("[data-spot]") || el;
        if (!last || (last.compareDocumentPosition(block) &
                      Node.DOCUMENT_POSITION_FOLLOWING)) {
          last = block;
        }
      });
      if (!last) return;

      var sentinel = document.createElement("span");
      sentinel.className = "fragment spot-sentinel";
      sentinel.setAttribute("data-spot-beat", beat);
      sentinel.setAttribute("aria-hidden", "true");
      sentinel.style.display = "none";
      last.parentNode.insertBefore(sentinel, last.nextSibling);
    });
    sync(slide);
  }

  /* ---------------------------------------------------------------------- */
  /* sync(slide) -- push the host's reveal state onto the marked lines.       */
  /*                                                                         */
  /* The host owns "how far are we", and it expresses that by adding or       */
  /* removing .revealed on fragments. We never second-guess it: we read that  */
  /* state and light the lines to match. So Home, End, going back a step, and */
  /* jumping to a slide from the overlay all keep working without the host    */
  /* knowing a beat exists -- it only has to tell us that something moved.    */
  /* ---------------------------------------------------------------------- */
  function sync(slide) {
    beatsOf(slide).forEach(function (beat) {
      var members = membersOf(slide, beat);
      var on = members.some(function (el) {
        return el.classList.contains("fragment") &&
               el.classList.contains("revealed");
      });
      members.forEach(function (el) {
        if ((el.tagName === "SPAN" && el.parentNode &&
             el.parentNode.tagName === "CODE") ||
            el.classList.contains("spot-mark")) {
          el.classList.toggle("spot-on", on);
        }
      });
    });
  }

  global.Spotlight = {
    mount: mount,
    sync: sync,
    prepare: prepare,
    paint: paint,
    beatsOf: beatsOf,
    membersOf: membersOf,
    showBeat: showBeat,
    hideBeat: hideBeat,
    setAllBeats: setAllBeats,
    locate: locate,                 /* an arrow's end, by address  */
    parseSpec: parseSpec,           /* exported for the test group */
    warnings: warnings,             /* what the author got wrong   */
    findings: findings              /* ...and where, for d         */
  };
})(this);