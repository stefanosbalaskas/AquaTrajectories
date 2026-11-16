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
  // Expand linked example panels and reveal hidden cards on hash navigation.
  function revealHash() {
    const id=decodeURIComponent(window.location.hash.slice(1));
    const target=id && document.getElementById(id);
    if (!target) return;
    const card=target.closest(".aqt-plot-entry");
    if (card && card.hidden) {
      search.value=""; category.value="all"; mode.value="all"; update();
    }
    if (target.tagName==="DETAILS") target.open=true;
  }
  document.querySelectorAll("[data-code-link]").forEach(link=>{
    link.addEventListener("click",()=>{
      const target=document.getElementById(link.hash.substring(1));
      if (target && target.tagName==="DETAILS") target.open=true;
    });
  });
  window.addEventListener("hashchange",revealHash);
  update();
  revealHash();
}());
