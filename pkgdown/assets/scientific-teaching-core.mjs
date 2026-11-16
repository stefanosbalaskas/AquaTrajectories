/* AquaTrajectories public teaching simulator — synthetic only.
   Deterministic illustrative geometry; no real video, biological model, or official MOT score. */
const clamp = (v,lo,hi) => Math.min(hi,Math.max(lo,Number(v)));
export function rngFromSeed(seed=20261116) {
  let state = (Number(seed) >>> 0) || 1;
  return () => ((state = (Math.imul(1664525,state) + 1013904223) >>> 0) / 4294967296);
}
export function iou(a,b) {
  const w=Math.max(0,Math.min(a.x+a.w,b.x+b.w)-Math.max(a.x,b.x));
  const h=Math.max(0,Math.min(a.y+a.h,b.y+b.h)-Math.max(a.y,b.y));
  const area=w*h, union=a.w*a.h+b.w*b.h-area;
  return union>0?area/union:0;
}
function rect(cx,cy) { return {x:cx-20,y:cy-11,w:40,h:22}; }
export function simulateTracking(options={}) {
  const n=Math.round(clamp(options.fishCount??5,2,12));
  const count=Math.round(clamp(options.frames??80,3,240));
  const miss=clamp(options.missRate??.16,0,1);
  const spurious=clamp(options.falsePositiveRate??.10,0,1);
  const swap=clamp(options.idSwitchRate??.06,0,1);
  const noise=clamp(options.noisePx??2,0,24);
  const threshold=clamp(options.iouThreshold??.5,.1,.95);
  const random=rngFromSeed(options.seed??20261116);
  const alt=Array(n).fill(false);
  const scenes=[];
  for(let frame=0;frame<count;frame++){
    const truth=[],detections=[];
    for(let fish=0;fish<n;fish++){
      const phase=fish*2.39996;
      const cx=410+260*Math.sin(.049*frame+phase)+18*Math.sin(.15*frame+fish);
      const cy=210+128*Math.sin(.033*frame+phase*.69)+12*Math.cos(.13*frame+fish);
      const target={...rect(cx,cy),id:"fish"+(fish+1)};
      truth.push(target);
      if(random()<miss) continue;
      if(random()<swap) alt[fish]=!alt[fish];
      const u=(random()-.5)*2*noise, v=(random()-.5)*2*noise;
      detections.push({...rect(cx+u,cy+v),trackId:"trk"+(fish+1)+(alt[fish]?"b":"a"),kind:"predicted"});
    }
    if(random()<spurious){
      detections.push({...rect(50+random()*715,35+random()*350),trackId:"noise"+frame,kind:"spurious"});
    }
    scenes.push({frame,truth,detections});
  }
  const evaluation=evaluateScenes(scenes,threshold);
  return {scenes,evaluation,options:{fishCount:n,frames:count,missRate:miss,falsePositiveRate:spurious,idSwitchRate:swap,noisePx:noise,iouThreshold:threshold,seed:options.seed??20261116}};
}
export function evaluateScenes(scenes,threshold=.5) {
  let TP=0,FP=0,FN=0,idSwitches=0,matchedTransitions=0;
  const previous=new Map(),byFrame=[];
  for(const scene of scenes){
    const candidates=[];
    scene.truth.forEach((gt,g)=>scene.detections.forEach((det,d)=>{
      const overlap=iou(gt,det);
      if(overlap>=threshold)candidates.push({g,d,overlap});
    }));
    candidates.sort((a,b)=>b.overlap-a.overlap||a.g-b.g||a.d-b.d);
    const usedG=new Set(),usedD=new Set(),matches=[];
    for(const c of candidates){
      if(usedG.has(c.g)||usedD.has(c.d))continue;
      usedG.add(c.g);usedD.add(c.d);
      matches.push({truthId:scene.truth[c.g].id,trackId:scene.detections[c.d].trackId,truthIndex:c.g,detectionIndex:c.d,iou:c.overlap});
    }
    const tp=matches.length,fp=scene.detections.length-tp,fn=scene.truth.length-tp;
    TP+=tp;FP+=fp;FN+=fn;
    for(const m of matches){
      const earlier=previous.get(m.truthId);
      if(earlier&&earlier.frame===scene.frame-1){
        matchedTransitions++;
        if(earlier.trackId!==m.trackId)idSwitches++;
      }
      previous.set(m.truthId,{frame:scene.frame,trackId:m.trackId});
    }
    byFrame.push({...scene,matches,tp,fp,fn});
  }
  const precision=TP+FP?TP/(TP+FP):0;
  const recall=TP+FN?TP/(TP+FN):0;
  const f1=precision+recall?2*precision*recall/(precision+recall):0;
  return {TP,FP,FN,precision,recall,f1,idSwitches,matchedTransitions,byFrame,threshold};
}
export function stepKinematics(dx,dy,dt) {
  const t=Number(dt);
  if(!Number.isFinite(t)||t<=0)throw Error("dt must be positive");
  const x=Number(dx),y=Number(dy);
  const distance=Math.hypot(x,y);
  return {distance,vx:x/t,vy:y/t,speed:distance/t};
}
export function polarization(anglesDeg) {
  if(!Array.isArray(anglesDeg)||anglesDeg.length<2)throw Error("At least two headings");
  const x=anglesDeg.reduce((s,a)=>s+Math.cos(Number(a)*Math.PI/180),0)/anglesDeg.length;
  const y=anglesDeg.reduce((s,a)=>s+Math.sin(Number(a)*Math.PI/180),0)/anglesDeg.length;
  return {x,y,value:Math.hypot(x,y)};
}
export function clockTransform(t,offset,driftPpm) {
  return Number(offset)+(1+Number(driftPpm)*1e-6)*Number(t);
}
function integer(v,min,max){return Math.round(clamp(v,min,max));}
function csv(s){const q=String(s??"");return /[,"\r\n]/.test(q)?'"'+q.replace(/"/g,'""')+'"':q;}
export function buildProtocol(opts={}) {
  const cameras=Number(opts.cameras)===1?1:2;
  const tanks=integer(opts.tanks??4,1,30);
  const fish=integer(opts.fish??5,1,40);
  const sessions=integer(opts.sessions??3,1,30);
  const minutes=integer(opts.minutes??20,1,180);
  const fps=integer(opts.fps??30,1,120);
  const study=String(opts.study??"AQT-SYNTHETIC-PLAN").trim().replace(/[^A-Za-z0-9_-]/g,"-").slice(0,40)||"AQT-SYNTHETIC-PLAN";
  const rows=[["planned_session_id","tank_id","camera_id","fish_planned","duration_min_planned","fps_nominal_planned","source_filename","source_sha256","physical_sync_verified","surveyed_xyz_truth_available"]];
  for(let t=1;t<=tanks;t++)for(let s=1;s<=sessions;s++)for(let c=1;c<=cameras;c++){
    const p=n=>String(n).padStart(2,"0");
    rows.push([study+"-S"+p(s),study+"-T"+p(t),"CAM"+p(c),fish,minutes,fps,"","","",""]);
  }
  const manifest=rows.map(row=>row.map(csv).join(",")).join("\n")+"\n";
  const markdown=[
    "# AquaTrajectories — SYNTHETIC EXPERIMENT PLANNING TEMPLATE",
    "",
    "> Planning metadata only. No recordings, animal IDs, camera calibration or scientific data are generated or asserted.",
    "",
    "- Study code: "+study,
    "- Intended cameras per tank: "+cameras,
    "- Planned independent tanks: "+tanks,
    "- Planned fish per tank: "+fish,
    "- Planned sessions per tank: "+sessions,
    "- Planned recording duration: "+minutes+" min/session",
    "- Nominal recording rate: "+fps+" frames/s (verify actual presentation timestamps)",
    "- Planned session-camera records: "+(cameras*tanks*sessions),
    "",
    "## Acquisition and metadata", "- [ ] Original recordings, source hashes and camera/exposure settings",
    "- [ ] Actual frame IDs and presentation timestamps; preserve missing frames",
    "- [ ] Camera-scoped tracker IDs and prediction-blind annotation with reviewed empty frames",
    "- [ ] Log lighting, camera pose, species, density and tank environment",
    "## Multiview requirements",
    cameras===2?"- [ ] Independent shared physical sync markers and separate clock holdouts":"- One camera chosen; do not infer unconstrained 3D depth",
    cameras===2?"- [ ] Intrinsics, extrinsics, lens/port/refraction information":"- [ ] Explicit image-plane scale if converting pixels to physical units",
    cameras===2?"- [ ] Independent surveyed underwater XYZ targets outside calibration fit":"- Physical XYZ from a single image is not established",
    "- [ ] Allow unresolved cross-camera identities and invalid geometry",
    "## Scientific design and reporting",
    "- [ ] Define primary estimands, quality thresholds and a heldout recording strategy",
    "- [ ] Document independent tank allocation; frames and fish are not independent tank replicates",
    "- [ ] Obtain appropriate animal ethics approval before live-animal experiments",
    "- [ ] Clearly distinguish software tests, source-label comparisons and independent physical evidence",
    "",
    "## Software and references",
    "- AquaTrajectories v0.1.1: https://doi.org/10.5281/zenodo.24262905",
    "- Documentation: https://stefanosbalaskas.github.io/AquaTrajectories/",
    "- Accompanying manifest contains blank fields for real acquisition artifacts; do not interpret them as missing observations.",
    ""
  ].join("\n");
  return {markdown,manifest,rows:rows.length-1,study,options:{cameras,tanks,fish,sessions,minutes,fps}};
}
