import {makeSyntheticMultiview,project3D} from "./research-geometry-core.mjs";
import {parseResearchCSV,normalizeFrameManifest,normalizeLocalTracks,normalizeLocalEvents,
  selectScopedFrame,selectVisibleTracks,framePtsToVideoTime} from "./research-local-core.mjs";
const $=id=>document.getElementById(id),NS="http://www.w3.org/2000/svg";
let state=null,localVideos=[],clockTimes=[],syntheticMode=false;
const svg=(tag,props={},text)=>{const el=document.createElementNS(NS,tag);for(const [k,v] of Object.entries(props))el.setAttribute(k,String(v));if(text!==undefined)el.textContent=String(text);return el;};
const color=k=>["#89dfec","#f6ce89","#c7aaee","#86dbaa","#ff9d9f","#b4c9ef"][k%6];
const currentSession=()=>$("session").value;
const currentTime=()=>Number($("timeline").value)||0;
const tolerance=()=>Math.max(.001,Math.min(2,Number($("tolerance").value)||.055));
async function localCSV(id,optional=false){
  const f=$(id).files?.[0];
  if(!f){if(optional)return [];throw Error("Missing required original frame manifest");}
  if(f.size>10*1024*1024)throw Error("CSV exceeds 10 MB: "+id);
  return parseResearchCSV(await f.text());
}
function clearVideos(){
  for(const url of localVideos)URL.revokeObjectURL(url);
  localVideos=[];
  for(const id of ["videoA","videoB"]){
    const vid=$(id);vid.pause();vid.removeAttribute("src");vid.load();
  }
}
function clearAll(){
  clearVideos();state=null;clockTimes=[];syntheticMode=false;
  ["framesFile","tracksFile","xyzFile","eventsFile","videoAFile","videoBFile"].forEach(x=>$(x).value="");
  $("session").replaceChildren();
  $("timeline").min="0";$("timeline").max="1";$("timeline").value="0";
  for(const k of ["overlayA","overlayB","xyzItems"])$(k).replaceChildren();
  for(const k of ["cameraAReadout","cameraBReadout","xyzReadout","eventReadout"])$(k).textContent="";
  $("sourceStatus").textContent="All local research data and selected media references cleared.";
  $("timeReadout").textContent="—";
}
function populate(data,isSynthetic){
  state=data;syntheticMode=isSynthetic;
  const sessions=[...new Set(state.frames.map(x=>x.session_id))].sort();
  $("session").replaceChildren();
  for(const name of sessions){const o=document.createElement("option");o.value=name;o.textContent=name;$("session").append(o);}
  initializeClock();
  $("sourceStatus").textContent=(isSynthetic?"SYNTHETIC teaching records. ":"Local user-selected files. ")+
    data.frames.length+" source frame rows; "+data.tracks2d.length+" 2D observations; "+
    data.tracks3d.length+" XYZ rows; "+data.events.length+" event rows. No uploaded files or independently certified biological identities.";
}
function scopedFrames(){return !state?[]:state.frames.filter(x=>x.session_id===currentSession());}
function availableCameras(){return [...new Set(scopedFrames().map(f=>f.camera_id))].sort().slice(0,2);}
function initializeClock(){
  const frames=scopedFrames(),ts=[...new Set(frames.map(f=>f.time_s))].sort((a,b)=>a-b);
  clockTimes=ts;
  $("timeline").min=String(ts[0]??0);$("timeline").max=String(ts.at(-1)??1);
  $("timeline").value=String(ts[0]??0);
  render();
}
function overlay(camera,viewBoxId,readoutId,labelId,t){
  const target=$(viewBoxId),name=$(labelId),readout=$(readoutId);
  target.replaceChildren();
  name.textContent=camera||"No camera";
  if(!camera){readout.textContent="No second source camera in this session";return;}
  const f=selectScopedFrame(state.frames,currentSession(),camera,t,tolerance());
  if(!f){readout.textContent="Missing aligned manifest frame at selected time; no position inferred.";return;}
  target.setAttribute("viewBox","0 0 "+f.width_px+" "+f.height_px);
  const tracks=selectVisibleTracks(state.tracks2d,currentSession(),camera,f.time_s,tolerance());
  tracks.forEach((p,i)=>{
    if(p.x<0||p.y<0||p.x>f.width_px||p.y>f.height_px)return;
    const hue=color(i);
    target.append(svg("circle",{cx:p.x,cy:p.y,r:Math.max(5,f.width_px/140),fill:hue,stroke:"#143044","stroke-width":2}));
    target.append(svg("text",{x:p.x+Math.max(7,f.width_px/130),y:p.y-8,fill:"#fff",
      "font-size":Math.max(10,f.width_px/85),stroke:"#18394a","paint-order":"stroke","stroke-width":2},p.track_id));
  });
  readout.textContent="Source frame "+f.frame_id+" · aligned "+f.time_s.toFixed(4)+" s · original raw PTS "+
    f.raw_time_s.toFixed(4)+" s · alignment residual "+f.alignment_residual_s.toFixed(4)+
    " s · "+tracks.length+" supplied 2D points. No identity verification implied.";
}
function sceneXYZ(t){
  const root=$("xyzItems");root.replaceChildren();
  const data=state.tracks3d.filter(x=>x.session_id===currentSession()&&x.observed&&x.z!==null);
  if(!data.length){$("xyzReadout").textContent="No source-provided XYZ for this session; no 3D positions fabricated.";return;}
  const w=Math.max(.05,Math.min(60,Number($("history").value)||2));
  const recent=data.filter(x=>x.time_s<=t+1e-8&&x.time_s>=t-w);
  if(!recent.length){$("xyzReadout").textContent="No XYZ observations in this history window.";return;}
  const lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
  for(const p of data){[p.x,p.y,p.z].forEach((v,i)=>{lo[i]=Math.min(lo[i],v);hi[i]=Math.max(hi[i],v);});}
  const centre=lo.map((v,i)=>(v+hi[i])/2);
  const span=Math.max(...lo.map((v,i)=>hi[i]-v),1);
  const gain=Math.min(14,700/span),yaw=+$("yaw").value,pitch=+$("pitch").value;
  const project=p=>project3D([p.x,p.y,p.z],yaw,pitch,centre,gain,[500,240]);
  root.append(svg("text",{x:20,y:30,fill:"#a8e4f1","font-size":17},"SOURCE-PROVIDED XYZ · UNVERIFIED PHYSICAL UNITS"));
  const groups=new Map();
  for(const p of recent){
    const key=JSON.stringify([p.camera_id,p.track_id]);if(!groups.has(key))groups.set(key,[]);
    groups.get(key).push(p);
  }
  let k=0;
  for(const [key,points] of groups){
    const sorted=points.sort((a,b)=>a.time_s-b.time_s),stroke=color(k++);
    for(let i=1;i<sorted.length;i++){
      const maxGap=Math.max(.1,4*tolerance());
      if(sorted[i].time_s-sorted[i-1].time_s>maxGap)continue;
      const a=project(sorted[i-1]),b=project(sorted[i]);
      root.append(svg("line",{x1:a.x,y1:a.y,x2:b.x,y2:b.y,stroke,"stroke-width":2,opacity:.7}));
    }
    const current=sorted.at(-1),xy=project(current);
    root.append(svg("circle",{cx:xy.x,cy:xy.y,r:6,fill:stroke,stroke:"#fff","stroke-width":1}));
    root.append(svg("text",{x:xy.x+10,y:xy.y-9,fill:"#fff","font-size":13},JSON.parse(key)[1]));
  }
  $("xyzReadout").textContent=recent.length+" source XYZ points, "+groups.size+" scoped paths in "+w+
    " s. Paths stop across gaps; no interpolated fish travel or independent XYZ metrology.";
}
function render(){
  if(!state)return;
  const t=currentTime(),cameraIds=availableCameras();
  $("timeReadout").textContent=t.toFixed(3)+" s · "+currentSession();
  $("yawOut").textContent=$("yaw").value;$("pitchOut").textContent=$("pitch").value;
  overlay(cameraIds[0],"overlayA","cameraAReadout","cameraAName",t);
  overlay(cameraIds[1],"overlayB","cameraBReadout","cameraBName",t);
  sceneXYZ(t);
  const near=state.events.filter(e=>Math.abs(e.time_s-t)<=tolerance());
  $("eventReadout").textContent=near.length
    ? "Source event markers: "+near.map(e=>e.event_id+" ("+e.event_type+")").join("; ")+" · event alignment is not causal evidence"
    : "No event within the chosen matching tolerance.";
}
function videoAt(camera,slot,t){
  const vid=$(slot);if(!camera||!vid.src)return;
  const f=selectScopedFrame(state.frames,currentSession(),camera,t,tolerance());
  if(!f)return;
  try{
    const seek=framePtsToVideoTime(state.frames,f);
    const apply=()=>{if(Number.isFinite(vid.duration)&&vid.duration>0)vid.currentTime=Math.min(seek,Math.max(0,vid.duration-.002));};
    if(vid.readyState>=1)apply();else vid.addEventListener("loadedmetadata",apply,{once:true});
  }catch(e){$("sourceStatus").textContent="Local video seek failed: "+String(e.message||e);}
}
function seekVideos(){if(!state)return;const cams=availableCameras(),t=currentTime();videoAt(cams[0],"videoA",t);videoAt(cams[1],"videoB",t);}
$("synthetic").addEventListener("click",()=>{clearAll();populate(makeSyntheticMultiview({frames:100,fish:5}),true);});
$("clear").addEventListener("click",clearAll);
$("loadFiles").addEventListener("click",async()=>{
  try{
    const [rawFrames,rawTracks,rawXYZ,rawEvents]=await Promise.all([
      localCSV("framesFile"),localCSV("tracksFile",true),localCSV("xyzFile",true),localCSV("eventsFile",true)]);
    const data={frames:normalizeFrameManifest(rawFrames),
      tracks2d:rawTracks.length?normalizeLocalTracks(rawTracks):[],
      tracks3d:rawXYZ.length?normalizeLocalTracks(rawXYZ,{requireZ:true}):[],
      events:normalizeLocalEvents(rawEvents)};
    clearVideos();state=null;
    for(const [id,slot] of [["videoAFile","videoA"],["videoBFile","videoB"]]){
      const f=$(id).files?.[0];if(!f)continue;
      if(!f.type.startsWith("video/"))throw Error("Select video media for "+id);
      const url=URL.createObjectURL(f);localVideos.push(url);
      $(slot).src=url;$(slot).load();
    }
    populate(data,false);
    $("sourceStatus").textContent+=" File bytes remain in this browser tab. Video A/B map to the first two alphabetically sorted camera identifiers.";
  }catch(e){$("sourceStatus").textContent="Local import rejected: "+String(e.message||e);}
});
$("session").addEventListener("change",initializeClock);
$("tolerance").addEventListener("change",render);
$("history").addEventListener("change",render);
$("timeline").addEventListener("input",render);
$("timeline").addEventListener("change",seekVideos);
["yaw","pitch"].forEach(x=>$(x).addEventListener("input",render));
function advance(dir){
 if(!state||!clockTimes.length)return;
 const now=currentTime(),eps=1e-7;
 const next=dir>0?clockTimes.find(t=>t>now+eps):[...clockTimes].reverse().find(t=>t<now-eps);
 if(next!==undefined){$("timeline").value=String(next);render();seekVideos();}
}
$("stepPrev").addEventListener("click",()=>advance(-1));
$("stepNext").addEventListener("click",()=>advance(1));
$("snapVideos").addEventListener("click",seekVideos);
$("downloadExample").addEventListener("click",()=>{
 const csv="session_id,camera_id,frame_id,time_s,raw_time_s,width_px,height_px\nSYNTH,CAM1,0,0,0,800,450\nSYNTH,CAM2,0,0,0.035,800,450\nSYNTH,CAM1,1,0.05,0.05,800,450\nSYNTH,CAM2,1,0.05,0.085,800,450\n";
 const blob=new Blob([csv],{type:"text/csv;charset=utf-8"}),url=URL.createObjectURL(blob),a=document.createElement("a");
 a.href=url;a.download="AquaTrajectories-SYNTHETIC-frame-manifest.csv";
 document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
});
