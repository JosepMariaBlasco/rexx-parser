/* Section jump -- navigate to an intermediate title page (Rony's guide
   indicator, structural half). Reads data-section markers, offers them in a
   dropdown, and jumps by setting the hash. The runtime's hashchange listener
   does the actual navigation, so there is a single navigation path. */
(function () {
  var sel = document.getElementById("section-jump");
  if (!sel) return;
  var sections = Array.prototype.slice.call(
    document.querySelectorAll(".slide[data-section]"));
  sections.forEach(function (s) {
    var o = document.createElement("option");
    o.value = s.id; o.textContent = s.getAttribute("data-section");
    sel.appendChild(o);
  });
  sel.addEventListener("change", function () {
    if (!sel.value) return;
    if (("#" + sel.value) === window.location.hash) {
      /* Same target as the current hash: assigning it fires no hashchange,
         so navigate directly by round-tripping through an empty hash. */
      window.location.hash = "";
    }
    window.location.hash = "#" + sel.value;
    sel.selectedIndex = 0;
  });
})();