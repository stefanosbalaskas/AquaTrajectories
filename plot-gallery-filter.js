/* Filter the 22 documented AquaTrajectories plotting functions.
   This only filters existing rendered plot cards; no network or dynamic data. */
"use strict";
(function () {
  const cards = Array.from(document.querySelectorAll(".aqt-plot-entry"));
  const search = document.getElementById("aqtPlotSearch");
  const category = document.getElementById("aqtPlotCategory");
  const mode = document.getElementById("aqtPlotMode");
  const count = document.getElementById("aqtPlotCount");
  const reset = document.getElementById("aqtPlotReset");
  if (!cards.length || !search || !category || !mode || !count || !reset) return;
  function update() {
    const query = search.value.trim().toLocaleLowerCase();
    let shown=0;
    cards.forEach(card => {
      const text=(card.getAttribute("data-search") || "").toLocaleLowerCase();
      const cat=card.getAttribute("data-category");
      const r=card.getAttribute("data-mode");
      const ok=(!query || text.includes(query)) &&
        (category.value==="all" || cat===category.value) &&
        (mode.value==="all" || r===mode.value);
      card.hidden=!ok;
      if (ok) shown++;
    });
    count.textContent="Showing "+shown+" of "+cards.length+" plotting functions";
  }
  search.addEventListener("input",update);
  category.addEventListener("change",update);
  mode.addEventListener("change",update);
  reset.addEventListener("click",()=>{
    search.value="";
    category.value="all";
    mode.value="all";
    update();
    search.focus();
  });
  // Deep links unhide a previously filtered card and preserve its anchor.
  window.addEventListener("hashchange",()=>{
    const id=window.location.hash.substring(1);
    const target=document.getElementById(id);
    if (!target) return;
    const card=target.closest(".aqt-plot-entry");
    if (card && card.hidden){
      search.value="";category.value="all";mode.value="all";
      update();
    }
  });
  update();
}());
