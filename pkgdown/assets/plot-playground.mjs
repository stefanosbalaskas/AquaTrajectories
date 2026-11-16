import {rngFromSeed,polarization} from "./scientific-teaching-core.mjs";
const $=id=>document.getElementById(id),NS="http://www.w3.org/2000/svg";
function el(tag,attrs,text){const x=document.createElementNS(NS,tag);for(const [k,v] of Object.entries(attrs))x.setAttribute(k,String(v));if(text!==undefined)x.textContent=text;return x;}
function download(name,contents){const blob=new Blob([contents],{type:"text/plain;charset=utf-8"}),url=URL.createObjectURL(blob),a=document.createElement("a");a.href=url;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);}
const defaults={mode:"paths",fish:5,nframes:90,sigma:.2,rho:.4,seed:33};
const fields=Object.keys(defaults);
function generate(){
  const mode=$("mode").value,n=+$("fish").value,N=+$("nframes").value,seed=Math.max(1,Math.min(2147483647,+$("seed").value||33)),sigma=+$("sigma").value,rho=+$("rho").value;
  for(const key of fields){const out=$(key+"Out");if(out)out.textContent=$(key).value;}
  $("graphTitle").textContent={paths:"Synthetic path geometry",ensemble:"Illustrative conditional position sensitivity",school:"Synthetic school-radius trajectory"}[mode];
  const g=$("plotItems");g.replaceChildren();
  const rand=rngFromSeed(seed);
  const series=[];
  for(let fish=0;fish<n;fish++){
    let x=400+(fish-n/2)*24,y=220+(fish-n/2)*8;
    const points=[];
    for(let t=0;t<N;t++){
      x=Math.min(780,Math.max(40,x+Math.cos(t*.13+fish*2.1)*2.2+(rand()-.5)*13));
      y=Math.min(425,Math.max(35,y+Math.sin(t*.11+fish*1.7)*2.2+(rand()-.5)*11));
      points.push([x,y]);
    }
    series.push(points);
  }
  const colors=["#70d9e5","#facc85","#c4a9f4","#77d9af","#fa9696","#bdd7ed","#ffd979","#a4becf","#ff9db7","#afce82"];
  function poly(points,color,width=2,opacity=1){
    g.append(el("polyline",{points:points.map(p=>p.map(v=>v.toFixed(2)).join(",")).join(" "),fill:"none",stroke:color,"stroke-width":width,opacity,"stroke-linejoin":"round"}));
  }
  if(mode==="paths"){
    series.forEach((points,i)=>poly(points,colors[i%colors.length],2.4));
  }else if(mode==="ensemble"){
    const base=series[0];const noiseScale=18*sigma;
    for(let draw=0;draw<18;draw++){
      let sx=0,sy=0;
      const q=base.map(([x,y])=>{
        sx=rho*sx+(rand()-.5)*2*noiseScale*Math.sqrt(1-rho*rho);
        sy=rho*sy+(rand()-.5)*2*noiseScale*Math.sqrt(1-rho*rho);
        return [x+sx,y+sy];
      });
      poly(q,"#8fd9f0",1.2,.28);
    }
    poly(base,"#ffce83",3);
  }else{
    const values=[];
    for(let t=0;t<N;t++){
      const cx=series.reduce((s,a)=>s+a[t][0],0)/n;
      const cy=series.reduce((s,a)=>s+a[t][1],0)/n;
      values.push(Math.sqrt(series.reduce((s,a)=>s+(a[t][0]-cx)**2+(a[t][1]-cy)**2,0)/n));
    }
    const hi=Math.max(1,...values),lo=Math.min(...values);
    poly(values.map((v,i)=>[45+i*(730/Math.max(1,N-1)),410-350*(v-lo)/Math.max(1e-8,hi-lo)]),"#facc85",3);
    g.append(el("text",{x:34,y:28,fill:"#d5eef5","font-size":14},"Synthetic instantaneous radial dispersion (arbitrary units)"));
    g.append(el("text",{x:34,y:440,fill:"#d5eef5","font-size":14},"Frame index →"));
  }
  let code=['# AquaTrajectories v0.1.1 — synthetic example; run locally in R','remotes::install_github("stefanosbalaskas/AquaTrajectories", ref = "v0.1.1")','library(aquaTrajectories)',''];
  if(mode==="school"){
    code.push('x <- aqt_simulate_tracks(n_fish = '+n+'L, n_frames = '+N+'L, fps = 10, dimension = 3L, seed = '+seed+'L)',
      'group <- aqt_group_spatial_summary(x)','aqt_plot_school_dynamics(group, "S01", "SIM")');
  }else{
    code.push('x <- aqt_simulate_tracks(n_fish = '+n+'L, n_frames = '+N+'L, fps = 10, dimension = 2L, seed = '+seed+'L)');
    if(mode==="paths")code.push('aqt_plot_paths(x)');
    else code.push('one <- aqt_tracks(as.data.frame(x)[x$track_id == "fish1", ], units = "cm", coordinate_system = "tank")',
      'ensemble <- aqt_trajectory_ensemble(one, sigma = '+sigma.toFixed(2)+', rho = '+rho.toFixed(2)+', draws = 40L, seed = 21L)',
      'aqt_plot_ensemble2d(ensemble, "S01", "SIM", "fish1", n_draws = 20L)');
  }
  $("rcode").textContent=code.join("\n")+"\n";
}
fields.forEach(key=>$(key).addEventListener("input",generate));
$("reset").addEventListener("click",()=>{for(const [k,v] of Object.entries(defaults))$(k).value=String(v);generate();});
$("copy").addEventListener("click",async()=>{
  try{await navigator.clipboard.writeText($("rcode").textContent);$("copyStatus").textContent="R code copied.";}
  catch{$("copyStatus").textContent="Copy unavailable; select the visible R code instead.";}
});
$("download").addEventListener("click",()=>download("AquaTrajectories-synthetic-plot-recipe.R",$("rcode").textContent));
const qs=new URLSearchParams(location.search),mode=qs.get("mode");if(["paths","ensemble","school"].includes(mode))$("mode").value=mode;
generate();
