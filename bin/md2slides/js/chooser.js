
(function () {
  var sel = document.getElementById("rexx-style");
  if (!sel) return;
  var KEY = "rexxpub.deck.rexxStyle";
  function apply(style) {
    var blocks = document.querySelectorAll('[class*="highlight-rexx-"]');
    for (var i = 0; i < blocks.length; i++) {
      blocks[i].className = blocks[i].className.replace(
        /highlight-rexx-[A-Za-z0-9._-]+/g, "highlight-rexx-" + style);
    }
    try { localStorage.setItem(KEY, style); } catch (e) {}
  }
  try {
    var saved = localStorage.getItem(KEY);
    if (saved) { sel.value = saved; apply(saved); }
  } catch (e) {}
  sel.addEventListener("change", function () {
    apply(sel.value);
    /* Return focus to the document, or the arrow keys stay captured by this   */
    /* <select> and only cycle its options -- the "trapped on the slide" bug.  */
    sel.blur();
  });
})();
