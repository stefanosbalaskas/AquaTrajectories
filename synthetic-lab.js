/* AquaTrajectories: synthetic teaching overlays (no datasets, detectors or network calls).
   Source-generated mathematical trajectories are accessed through AQTExplorer.
   Display labels and pixel jitter intentionally never alter underlying fish coordinates. */
"use strict";
(function () {
  const api = window.AQTExplorer;
  if (!api) return;
  const $ = id => document.getElementById(id);
  const ns = "http://www.w3.org/2000/svg";
  const colors = api.colors;
  const lessonKeys = ["baseline", "occlusion", "identity", "multiview", "event"];
  const lessons = {
    baseline: {
      title: "Observe continuous synthetic paths", frame: 0, view: "iso", fish: 0,
      occlusion: false, switching: false, boxes: false, vectors: false, cameras: true,
      text: "Rotate the schematic tank and inspect the same invented positions in top and side views. No physical calibration is implied.",
      question: "Can these invented paths help you learn the interface without providing any real fish measurements?",
      answer: true,
      explanation: "Yes. They make a reproducible teaching dataset, but they are not validated biological observations."
    },
    occlusion: {
      title: "Inspect missing observations", frame: 105, view: "xy", fish: 0,
      occlusion: true, switching: false, boxes: true, vectors: false, cameras: true,
      text: "F1 is unobserved during frames 90–125. Its underlying mathematical path still exists, but visible track segments must not be joined across that gap.",
      question: "Should a visualized fish track interpolate the unobserved interval without clearly recording the assumption?",
      answer: false,
      explanation: "No. Preserve missingness. Any interpolation needs an explicit model and uncertainty treatment."
    },
    identity: {
      title: "Distinguish track labels from biological identity", frame: 137, view: "iso", fish: 0,
      occlusion: true, switching: true, boxes: true, vectors: true, cameras: true,
      text: "After frame 125 the displayed F1 and F2 labels exchange, but their invented underlying coordinates do not. The question mark flags a possible label error.",
      question: "Did exchanging the displayed F1/F2 labels change the underlying simulated fish positions?",
      answer: false,
      explanation: "No. A track label is not a biological ID. External fish-identity reference labels are needed to adjudicate real switches."
    },
    multiview: {
      title: "Compare two simultaneous projections", frame: 192, view: "iso", fish: 2,
      occlusion: false, switching: false, boxes: false, vectors: true, cameras: true,
      text: "Compare XY (top) and XZ (side) projections while orbiting the main drawing. These are idealized projections of the same invented points, not calibrated cameras.",
      question: "Do top and side projections show different coordinate components of the same invented 3D positions?",
      answer: true,
      explanation: "Yes, conceptually. Real camera fusion additionally needs calibrated intrinsics, refraction, synchronization and verified correspondences."
    },
    event: {
      title: "Align movement with a logged event", frame: 166, view: "xy", fish: 3,
      occlusion: false, switching: false, boxes: false, vectors: true, cameras: true,
      text: "The yellow marker is an invented event log at 5.0 seconds (frame 150). Moving past it does not change the simulator or establish a treatment effect.",
      question: "Does a change in the synthetic movement curve after an event marker establish a causal feeding or stress response?",
      answer: false,
      explanation: "No. A timestamp is not a randomized treatment. Valid inference requires appropriate replicated experimental design and biological evidence."
    }
  };
  let focused = 0;
  const iso = () => api.getState();
  const clamp = (x,a,b) => Math.max(a,Math.min(b,x));
  const setText = (id, value) => {$(id).textContent = value;};
  const text = (n,x,y,label,attrs = {}) => svgNode(n,"text",Object.assign({
    x, y, fill:"#afcfde","font-family":"system-ui, sans-serif","font-size":12
  },attrs),label);
  function svgNode(parent, tag, attrs, content) {
    const el = document.createElementNS(ns,tag);
    Object.entries(attrs || {}).forEach(([key,val])=>el.setAttribute(key,String(val)));
    if(content!==undefined)el.textContent=content;
    parent.appendChild(el);
    return el;
  }
  function distance(a,b) {
    return Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z);
  }
  function observed(f,t) {return !api.isMissing(f,t);}
  function shownLabel(f,t) {
    return $("idswitch-demo").checked && t>=126 && f<2 ?
      "F"+(f===0?2:1)+"?" : "F"+(f+1);
  }
  function rate(f,t) {
    if(t===0||!observed(f,t)||!observed(f,t-1))return null;
    return 30*distance(api.tracks[f][t],api.tracks[f][t-1]);
  }
  function svgPoint(p,view,w=420,h=250) {
    const x = view==="xz"?p.x:p.x;
    const y = view==="xz"?p.z:p.y;
    return [26+x*(w-52),h-24-y*(h-54)];
  }
  function renderMini(svg,view,state) {
    svg.replaceChildren();
    svgNode(svg,"rect",{x:22,y:21,width:376,height:205,rx:9,fill:"#0c2c43",stroke:"#43677c"});
    for(let k=1;k<=3;k++) {
      const y=21+205*k/4;
      svgNode(svg,"line",{x1:22,y1:y,x2:398,y2:y,stroke:"#31576a","stroke-width":.75});
    }
    for(let f=0;f<api.count;f++) {
      if(!state.visible[f])continue;
      let d="",open=false;
      for(let t=Math.max(0,state.frame-state.trail);t<=state.frame;t++) {
        if(!observed(f,t)){open=false;continue;}
        const p=svgPoint(api.tracks[f][t],view);
        d+=(open?" L":" M")+p[0].toFixed(1)+" "+p[1].toFixed(1);
        open=true;
      }
      svgNode(svg,"path",{d,fill:"none",stroke:colors[f],"stroke-width":f===focused?3.7:2,
        opacity:f===focused?1:.68,"stroke-linecap":"round","stroke-linejoin":"round"});
      if(!observed(f,state.frame))continue;
      const p=svgPoint(api.tracks[f][state.frame],view);
      svgNode(svg,"circle",{cx:p[0],cy:p[1],r:f===focused?7:5,fill:colors[f],stroke:"#eefaff","stroke-width":1.5});
      text(svg,p[0]+10,p[1]-8,shownLabel(f,state.frame),{fill:colors[f],"font-size":f===focused?14:11});
    }
    text(svg,28,16,view==="xz"?"XZ · synthetic side projection":"XY · synthetic top projection",{"font-size":11});
  }
  function renderSpeed(state) {
    const svg=$("speedChart");
    svg.replaceChildren();
    const left=42,right=809,top=22,bottom=153;
    const speeds=api.tracks[focused].map((_,t)=>rate(focused,t));
    const valid=speeds.filter(v=>v!==null);
    const max=Math.max(.01,...valid);
    svgNode(svg,"rect",{x:left,y:top,width:right-left,height:bottom-top,rx:4,fill:"#0e3043"});
    for(let k=0;k<=3;k++) {
      const y=bottom-(bottom-top)*k/3;
      svgNode(svg,"line",{x1:left,y1:y,x2:right,y2:y,stroke:"#335769","stroke-width":.8});
      text(svg,6,y+4,(max*k/3).toFixed(2),{"font-size":12});
    }
    const ex=left+(right-left)*150/300;
    if($("showEvent").checked) {
      svgNode(svg,"line",{x1:ex,y1:top,x2:ex,y2:bottom,stroke:"#eac47a",
        "stroke-dasharray":"5 4","stroke-width":1.7});
      text(svg,ex+5,top+13,"Event 5.0s",{"font-size":12,fill:"#f4d78f"});
    }
    let d="",drawing=false;
    speeds.forEach((v,t)=>{
      if(v===null){drawing=false;return;}
      const x=left+(right-left)*t/300;
      const y=bottom-(bottom-top)*(v/max);
      d+=(drawing?" L":" M")+x.toFixed(1)+" "+y.toFixed(1);drawing=true;
    });
    svgNode(svg,"path",{d,stroke:colors[focused],fill:"none","stroke-width":2.4,"stroke-linejoin":"round"});
    const cursor=left+(right-left)*state.frame/300;
    svgNode(svg,"line",{x1:cursor,y1:top,x2:cursor,y2:bottom,stroke:"#ffffff",
      "stroke-width":1.5,opacity:.9});
    if(speeds[state.frame]!==null) {
      const yy=bottom-(bottom-top)*speeds[state.frame]/max;
      svgNode(svg,"circle",{cx:cursor,cy:yy,r:5,fill:colors[focused],stroke:"#ffffff","stroke-width":1.4});
    }
    text(svg,left,bottom+23,"0 s");
    text(svg,ex-14,bottom+23,"5 s");
    text(svg,right-27,bottom+23,"10 s");
    setText("speedTitle","F"+(focused+1)+" · illustrative movement-rate history");
  }
  function renderOverlay(state) {
    const group=$("teachingOverlays");
    group.replaceChildren();
    if($("showEvent").checked) {
      const past=state.frame>=150;
      svgNode(group,"rect",{x:707,y:14,width:230,height:37,rx:10,
        fill:past?"#2a5347":"#3a3950","fill-opacity":.9,stroke:past?"#77daa7":"#d9b772","stroke-width":1.1});
      text(group,720,39,past?"AFTER logged event · 5.0s":"BEFORE logged event · 5.0s",
        {fill:"#f6eed1","font-size":16,"font-weight":700});
    }
    for(let f=0;f<api.count;f++) {
      if(!state.visible[f]||!observed(f,state.frame))continue;
      const p=api.project(api.tracks[f][state.frame],state.projection);
      if($("showBoxes").checked) {
        const n=Number($("noise").value);
        const dx=Math.sin((state.frame+1)*(f+2)*.731)*n;
        const dy=Math.cos((state.frame+1)*(f+4)*.417)*n;
        svgNode(group,"rect",{x:p[0]-17+dx,y:p[1]-13+dy,width:34,height:26,rx:4,
          fill:"none",stroke:colors[f],"stroke-width":2,opacity:.95,
          "stroke-dasharray":n>0?"5 3":"none"});
      }
      if($("showVectors").checked && state.frame>0 && observed(f,state.frame-1)) {
        const prev=api.project(api.tracks[f][state.frame-1],state.projection);
        const dx=(p[0]-prev[0])*9,dy=(p[1]-prev[1])*9;
        const length=Math.hypot(dx,dy);
        if(length>.05) {
          const fac=Math.min(1,64/length),x=p[0]+dx*fac,y=p[1]+dy*fac;
          svgNode(group,"line",{x1:p[0],y1:p[1],x2:x,y2:y,stroke:colors[f],"stroke-width":3});
          const angle=Math.atan2(y-p[1],x-p[0]);
          const wing=8;
          const p1=[x-wing*Math.cos(angle-.6),y-wing*Math.sin(angle-.6)];
          const p2=[x-wing*Math.cos(angle+.6),y-wing*Math.sin(angle+.6)];
          svgNode(group,"path",{d:"M"+p1.join(" ")+" L"+x+" "+y+" L"+p2.join(" "),
            fill:"none",stroke:colors[f],"stroke-width":2.5});
        }
      }
    }
  }
  function renderMetrics(state) {
    const actual=api.tracks.map((_,f)=>observed(f,state.frame)).filter(Boolean).length;
    setText("metricObserved",actual+" / "+api.count);
    const s=rate(focused,state.frame);
    setText("metricSpeed",s===null?"—":s.toFixed(3));
    let nearest=null;
    if(observed(focused,state.frame)) {
      for(let i=0;i<api.count;i++){
        if(i===focused||!observed(i,state.frame))continue;
        const d=distance(api.tracks[focused][state.frame],api.tracks[i][state.frame]);
        nearest=nearest===null?d:Math.min(nearest,d);
      }
    }
    setText("metricNearest",nearest===null?"—":nearest.toFixed(3));
    const delta=state.frame/30-5;
    setText("metricEvent",(delta>0?"+":"")+delta.toFixed(2)+" s");
    setText("eventReadout",delta<0?"Pre-event · "+(-delta).toFixed(2)+" s to illustrative log":
      delta===0?"Illustrative event logged now (t = 5.0 s)":
      "Post-event · +"+delta.toFixed(2)+" s (not causal evidence)");
  }
  function applyFocus() {
    const state=iso();
    const pathNodes=Array.from($("paths").children),headNodes=Array.from($("heads").children);
    pathNodes.forEach((n,i)=>{n.style.opacity=i===focused?".98":".43";
      n.setAttribute("stroke-width",i===focused?"5.4":"2.8");});
    headNodes.forEach((n,index)=>{
      const i=Math.floor(index/2);
      n.style.opacity=i===focused?"1":".68";
    });
    $("focusFish").value=String(focused);
    // The selected fish marker remains visible only when the original visibility filter allows it.
  }
  function render() {
    const state=iso();
    setText("azimuthValue",String(state.azimuth)+"°");
    $("cameraPanel").hidden=!$("showCameras").checked;
    if($("showCameras").checked) {
      renderMini($("cameraXY"),"xy",state);
      renderMini($("cameraXZ"),"xz",state);
    }
    renderOverlay(state);
    renderMetrics(state);
    renderSpeed(state);
    applyFocus();
  }
  function selectFish(i) {
    focused=clamp(Math.round(i),0,api.count-1);
    api.refresh();
  }
  window.AQTExplorerExtension={render,selectFish};
  window.AQTExplorerRate=1;

  function showQuiz(answer) {
    const lesson=lessons[$("lessonPreset").value];
    const correct=lesson.answer===answer;
    const out=$("quizFeedback");
    out.className=correct?"correct":"incorrect";
    out.textContent=(correct?"Correct. ":"Not quite. ")+lesson.explanation;
  }
  function applyLesson(name) {
    const lesson=lessons[name]||lessons.baseline;
    $("lessonPreset").value=name;
    $("occlusion-demo").checked=lesson.occlusion;
    $("idswitch-demo").checked=lesson.switching;
    $("showBoxes").checked=lesson.boxes;
    $("showVectors").checked=lesson.vectors;
    $("showCameras").checked=lesson.cameras;
    $("showEvent").checked=true;
    $("noise").value="0";setText("noiseValue","0 px");
    setText("lessonText",lesson.text);
    setText("quizQuestion",lesson.question);
    const n=lessonKeys.indexOf(name);
    setText("lessonProgress","Lesson "+(n+1)+" of "+lessonKeys.length);
    $("quizFeedback").className="";
    setText("quizFeedback","Choose Yes or No, then examine the explanation.");
    api.pause();
    focused=lesson.fish;
    $("azimuth").value="30";
    api.setOrbit(30);
    api.setProjection(lesson.view);
    api.setFrame(lesson.frame);
  }
  function download(name,content,type) {
    const blob=new Blob([content],{type});
    const u=URL.createObjectURL(blob);
    const a=document.createElement("a");
    a.href=u;a.download=name;
    document.body.appendChild(a);a.click();a.remove();
    setTimeout(()=>URL.revokeObjectURL(u),1000);
  }
  function exportCSV() {
    const rows=["source,session_id,frame,time_s,synthetic_true_id,displayed_track_label,x_arbitrary,y_arbitrary,z_arbitrary,observed"];
    for(let t=0;t<=api.totalFrames;t++){
      for(let f=0;f<api.count;f++){
        const v=api.tracks[f][t],on=observed(f,t);
        rows.push(["synthetic_teaching_only","SYNTHETIC01",t,(t/30).toFixed(6),
          "F"+(f+1),shownLabel(f,t),on?v.x.toFixed(6):"",on?v.y.toFixed(6):"",
          on?v.z.toFixed(6):"",on?"TRUE":"FALSE"].join(","));
      }
    }
    download("AquaTrajectories_SYNTHETIC_tracking_exercise.csv",rows.join("\r\n")+"\r\n","text/csv;charset=utf-8");
  }
  function exportSVG() {
    const cloned=$("tank").cloneNode(true);
    cloned.setAttribute("xmlns",ns);
    const title=cloned.querySelector("title");
    if(title)title.textContent="SYNTHETIC AquaTrajectories teaching scene — not real fish data";
    const markup=new XMLSerializer().serializeToString(cloned);
    download("AquaTrajectories_SYNTHETIC_scene.svg",markup,"image/svg+xml;charset=utf-8");
  }
  $("lessonPreset").addEventListener("change",()=>applyLesson($("lessonPreset").value));
  $("nextLesson").addEventListener("click",()=>{
    const i=lessonKeys.indexOf($("lessonPreset").value);
    applyLesson(lessonKeys[(i+1)%lessonKeys.length]);
  });
  $("focusFish").addEventListener("change",()=>selectFish(Number($("focusFish").value)));
  $("azimuth").addEventListener("input",()=>api.setOrbit(Number($("azimuth").value)));
  ["showBoxes","showVectors","showCameras","showEvent","noise"].forEach(id=>
    $(id).addEventListener(id==="noise"?"input":"change",()=>{
      setText("noiseValue",$("noise").value+" px");
      api.refresh();
    }));
  $("playbackRate").addEventListener("change",()=>{
    window.AQTExplorerRate=Number($("playbackRate").value);
    api.refresh();
  });
  function step(delta) {api.pause();api.setFrame(api.getState().frame+delta);}
  $("stepBack").addEventListener("click",()=>step(-1));
  $("stepForward").addEventListener("click",()=>step(1));
  $("jumpOcclusion").addEventListener("click",()=>{api.pause();api.setFrame(105);});
  $("jumpSwitch").addEventListener("click",()=>{api.pause();api.setFrame(130);});
  $("jumpEvent").addEventListener("click",()=>{api.pause();api.setFrame(150);});
  $("quizYes").addEventListener("click",()=>showQuiz(true));
  $("quizNo").addEventListener("click",()=>showQuiz(false));
  $("exportCsv").addEventListener("click",exportCSV);
  $("exportSvg").addEventListener("click",exportSVG);
  document.addEventListener("keydown",evt=>{
    const tag=(evt.target&&evt.target.tagName||"").toUpperCase();
    if(["INPUT","SELECT","TEXTAREA","BUTTON"].includes(tag)||evt.altKey||evt.ctrlKey||evt.metaKey)return;
    if(evt.key==="ArrowRight") {evt.preventDefault();step(1);}
    else if(evt.key==="ArrowLeft"){evt.preventDefault();step(-1);}
    else if(evt.code==="Space"){evt.preventDefault();api.togglePlay();}
  });
  Array.from($("heads").children).forEach((el,index)=>
    el.addEventListener("click",()=>selectFish(Math.floor(index/2))));
  // Underlying SVG circles are not accessible buttons: keyboard focus is provided by focusFish.
  applyLesson("baseline");
}());
