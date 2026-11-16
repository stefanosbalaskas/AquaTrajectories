/* Curated BASE R only. No arbitrary user-authored R is executed.
 * External pinned CDN initiated only on explicit click; no research file access.
 */
const $=id=>document.getElementById(id);
let runtime=null,busy=false;
const presets={
 speed:({n,frames,seed})=>[
  "# Actual R (base stats): synthetic finite differences",
  "set.seed("+seed+")",
  "n <- "+n+"L",
  "dt <- 0.1",
  "x <- cumsum(rnorm("+frames+"L, sd=0.5))",
  "y <- cumsum(rnorm("+frames+"L, sd=0.5))",
  "vx <- diff(x)/dt; vy <- diff(y)/dt",
  "speed <- sqrt(vx^2+vy^2)",
  "print(data.frame(n_fish_parameter=n,frames=length(x),intervals=length(speed)))",
  "print(summary(speed))",
  "cat('These are invented mathematical walks, not biological fish measurements.')"
 ].join("\n"),
 school:({n,seed})=>[
  "# Actual R: normalized headings and school polarization",
  "set.seed("+seed+")",
  "angles <- runif("+n+"L, -pi/3, pi/3)",
  "heading <- cbind(cos(angles), sin(angles))",
  "P <- sqrt(sum(colMeans(heading)^2))",
  "print(round(angles*180/pi, 2))",
  "print(data.frame(fish=nrow(heading),polarization=round(P,6)))",
  "cat('One synthetic timestamp; headings are nonzero by construction.')"
 ].join("\n"),
 clock:({frames})=>[
  "# Actual R: declared affine clock mapping, not fitted physical synchronization",
  "raw_s <- seq(0, ("+frames+"-1)/30, length.out="+frames+"L)",
  "offset_s <- 0.12",
  "drift_ppm <- 75",
  "reference_s <- offset_s + (1+drift_ppm*1e-6)*raw_s",
  "print(head(data.frame(raw_s,reference_s),5))",
  "print(data.frame(last_raw=tail(raw_s,1),last_reference=tail(reference_s,1)))",
  "cat('No independent hardware synchronization markers were supplied.')"
 ].join("\n"),
 summary:({n,frames,seed})=>[
  "# Actual base R: fabricated multi-fish trajectory table",
  "set.seed("+seed+")",
  "n_fish <- "+n+"L; n_frames <- "+frames+"L",
  "tracks <- do.call(rbind,lapply(seq_len(n_fish),function(i) {",
  " data.frame(track_id=paste0('fish',i),time_s=(0:(n_frames-1))/10,",
  " x=cumsum(rnorm(n_frames,sd=.3)),y=cumsum(rnorm(n_frames,sd=.3)))",
  "}))",
  "displacement <- aggregate(cbind(x,y)~track_id,tracks,function(z)tail(z,1)-z[1])",
  "print(data.frame(rows=nrow(tracks),fish=length(unique(tracks$track_id))))",
  "print(displacement,row.names=FALSE)"
 ].join("\n")
};
function params(){return {n:+$("n").value,frames:+$("frames").value,seed:Math.max(1,Math.min(999999,Math.round(+$("seed").value||53)))}} 
function updateSource(){
 const p=params();$("nOut").textContent=p.n;$("framesOut").textContent=p.frames;
 $("rSource").textContent=presets[$("preset").value](p);
}
["n","frames","seed","preset"].forEach(x=>$(x).addEventListener("input",updateSource));
$("initialize").addEventListener("click",async()=>{
 if(runtime||busy)return;busy=true;$("initialize").disabled=true;
 $("runtimeStatus").textContent="Downloading pinned webR 0.6.1 and initializing local R worker…";
 try{
   const {WebR,ChannelType}=await import("https://webr.r-wasm.org/v0.6.1/webr.mjs");
   const instance=new WebR({channelType:ChannelType.PostMessage,interactive:false});
   await instance.init();
   runtime=instance;$("run").disabled=false;
   $("runtimeStatus").textContent="webR initialized. Curated R code executes in this browser.";
 }catch(e){
   $("runtimeStatus").textContent="webR failed to initialize: "+String(e.message||e)+". Check CDN/browser support.";
   $("initialize").disabled=false;
 }finally{busy=false;}
});
$("run").addEventListener("click",async()=>{
 if(!runtime||busy)return;
 busy=true;$("run").disabled=true;$("rOutput").textContent="Executing actual R…";
 let shelter=null;
 try{
   shelter=await new runtime.Shelter();
   const result=await shelter.captureR($("rSource").textContent);
   const lines=(result.output||[]).filter(x=>x.type==="stdout"||x.type==="stderr").map(x=>x.data);
   $("rOutput").textContent=lines.join("\n")||"R completed without console output.";
   $("runtimeStatus").textContent="R execution completed in WebAssembly. Synthetic demonstration only.";
 }catch(e){
   $("rOutput").textContent="R execution failed: "+String(e.message||e);
   $("runtimeStatus").textContent="R execution was not successful; no output is certified.";
 }finally{
   if(shelter)try{await shelter.purge();}catch{}
   busy=false;$("run").disabled=false;
 }
});
updateSource();
