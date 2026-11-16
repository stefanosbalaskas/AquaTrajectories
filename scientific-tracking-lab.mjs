import {simulateTracking} from "./scientific-teaching-core.mjs";
const $=id=>document.getElementById(id), NS="http://www.w3.org/2000/svg";
const defaults={fishCount:5,frames:80,missRate:16,falsePositiveRate:10,idSwitchRate:6,noisePx:2,iouThreshold:50,seed:20261116};
const ids=Object.keys(defaults);
function shape(tag,attrs,text){
  const el=document.createElementNS(NS,tag);
  for(const [k,v] of Object.entries(attrs))el.setAttribute(k,String(v));
  if(text!==undefined)el.textContent=String(text);
  return el;
}
function download(filename,content,type="text/csv;charset=utf-8"){
  const blob=new Blob([content],{type});
  const url=URL.createObjectURL(blob);
  const a=document.createElement("a");
  a.href=url;a.download=filename;a.hidden=true;document.body.append(a);a.click();a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
}
let model=null,frameIndex=0;
function settings(){
  return {fishCount:+$("fishCount").value,frames:+$("frames").value,
    missRate:+$("missRate").value/100,falsePositiveRate:+$("falsePositiveRate").value/100,
    idSwitchRate:+$("idSwitchRate").value/100,noisePx:+$("noisePx").value,
    iouThreshold:+$("iouThreshold").value/100,seed:+$("seed").value||20261116};
}
function draw(){
  const s=model.evaluation.byFrame[frameIndex],root=$("sceneItems");
  root.replaceChildren();
  const matched=new Set(s.matches.map(m=>m.detectionIndex));
  for(const fish of s.truth){
    root.append(shape("rect",{x:fish.x,y:fish.y,width:fish.w,height:fish.h,rx:3,fill:"none",stroke:"#61d8e6","stroke-width":2,"stroke-dasharray":"5 4"}));
    root.append(shape("text",{x:fish.x,y:fish.y-5,fill:"#d0f7ff","font-size":11},fish.id));
  }
  s.detections.forEach((det,index)=>{
    const ok=matched.has(index);
    root.append(shape("rect",{x:det.x,y:det.y,width:det.w,height:det.h,rx:3,fill:"none",stroke:ok?"#ffd17e":"#ff7779","stroke-width":2.5}));
    root.append(shape("text",{x:det.x,y:det.y+det.h+13,fill:ok?"#ffe4b6":"#ffb8ba","font-size":11},det.trackId));
  });
  $("frame").value=String(frameIndex);
  $("frameOut").textContent=(frameIndex+1)+" / "+model.scenes.length;
  $("frameStatus").textContent="Frame "+(frameIndex+1)+": "+s.tp+" matched boxes; "+s.fp+" false positives; "+s.fn+" missed fish. Labels and locations are synthetic.";
}
function update(){
  ids.forEach(id=>{
    const el=$(id),out=$(id+"Out");
    if(out)out.textContent=["missRate","falsePositiveRate","idSwitchRate"].includes(id)?el.value+"%":id==="iouThreshold"?(+el.value/100).toFixed(2):el.value;
  });
  model=simulateTracking(settings());
  frameIndex=Math.min(frameIndex,model.scenes.length-1);
  $("frame").max=String(model.scenes.length-1);
  for(const [id,value] of Object.entries({
    precision:model.evaluation.precision,recall:model.evaluation.recall,f1:model.evaluation.f1
  }))$(id).textContent=(100*value).toFixed(1)+"%";
  for(const [id,key] of Object.entries({tp:"TP",fp:"FP",fn:"FN",switches:"idSwitches",transitions:"matchedTransitions"}))
    $(id).textContent=String(model.evaluation[key]);
  draw();
}
ids.forEach(id=>$(id).addEventListener("input",update));
$("frame").addEventListener("input",()=>{frameIndex=+$("frame").value;draw();});
$("previous").addEventListener("click",()=>{frameIndex=Math.max(0,frameIndex-1);draw();});
$("next").addEventListener("click",()=>{frameIndex=Math.min(model.scenes.length-1,frameIndex+1);draw();});
$("reset").addEventListener("click",()=>{for(const [k,v] of Object.entries(defaults))$(k).value=String(v);frameIndex=0;update();});
$("download").addEventListener("click",()=>{
  const rows=["frame,record_type,truth_id,tracker_id,x_px,y_px,width_px,height_px,matched_iou,synthetic"];
  for(const s of model.evaluation.byFrame){
    const matches=new Map(s.matches.map(x=>[x.detectionIndex,x]));
    for(let i=0;i<s.detections.length;i++){
      const d=s.detections[i],m=matches.get(i);
      rows.push([s.frame,m?"matched_prediction":"unmatched_prediction",m?.truthId||"",d.trackId,
        d.x.toFixed(3),d.y.toFixed(3),d.w,d.h,m?.iou.toFixed(4)||"","TRUE"].join(","));
    }
    // Export EVERY ground-truth box, not only misses. This makes detection
    // precision/recall independently recomputable from the synthetic CSV.
    s.truth.forEach(d=>rows.push([s.frame,"ground_truth",d.id,"",
      d.x.toFixed(3),d.y.toFixed(3),d.w,d.h,"","TRUE"].join(",")));
  }
  download("AquaTrajectories-synthetic-box-evaluation.csv",rows.join("\n")+"\n");
});
update();
