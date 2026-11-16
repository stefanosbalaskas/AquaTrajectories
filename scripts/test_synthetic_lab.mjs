// Deterministic no-network behavioral test of the full browser teaching lab.
import fs from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

class MockNode {
  constructor(tag="div") {
    this.tagName=tag.toUpperCase();this.children=[];this.attrs={};this.events={};
    this.style={};this.textContent="";this.checked=false;this.value="";this.hidden=false;
  }
  setAttribute(key,val){this.attrs[key]=String(val);}
  getAttribute(key){return this.attrs[key];}
  appendChild(child){this.children.push(child);return child;}
  append(...args){this.children.push(...args);}
  replaceChildren(...args){this.children=[...args];}
  addEventListener(k,fn){this.events[k]=fn;}
  fire(k,extra={}){assert.equal(typeof this.events[k],"function",this.tagName+" lacks "+k);this.events[k]({target:this,...extra});}
  click(){if(this.events.click)this.fire("click");}
  remove(){this.removed=true;}
  cloneNode(){const n=new MockNode(this.tagName);n.attrs={...this.attrs};n.textContent=this.textContent;return n;}
  querySelector(tag){return tag==="title"?new MockNode("title"):null;}
}
const ids=[
 "grid","paths","heads","frame","trail","play","reset","frameValue","trailValue",
 "status","viewTitle","fishfilters","legend","learningStatus","occlusion-demo","idswitch-demo",
 "lessonPreset","lessonText","nextLesson","azimuth","azimuthValue","focusFish",
 "showBoxes","showVectors","showCameras","showEvent","noise","noiseValue",
 "eventReadout","stepBack","stepForward","playbackRate","jumpOcclusion","jumpSwitch",
 "jumpEvent","teachingOverlays","cameraPanel","cameraXY","cameraXZ",
 "speedChart","speedTitle","metricObserved","metricSpeed","metricNearest","metricEvent",
 "quizQuestion","lessonProgress","quizFeedback","quizYes","quizNo","exportCsv","exportSvg",
 "tank"
];
const nodes=Object.fromEntries(ids.map(id=>[id,new MockNode(id)]));
Object.assign(nodes.frame,{value:"0"});
Object.assign(nodes.trail,{value:"60"});
Object.assign(nodes.azimuth,{value:"30"});
Object.assign(nodes.noise,{value:"0"});
Object.assign(nodes.focusFish,{value:"0"});
Object.assign(nodes.lessonPreset,{value:"baseline"});
Object.assign(nodes.playbackRate,{value:"1"});
nodes.showCameras.checked=true;nodes.showEvent.checked=true;
const viewInputs=["iso","xy","xz","yz"].map(value=>{const r=new MockNode("input");r.value=value;r.checked=value==="iso";return r;});
const body=new MockNode("body");
const document={
  body,
  getElementById(id){assert.ok(nodes[id],"Missing element "+id);return nodes[id];},
  createElementNS(_ns,tag){return new MockNode(tag);},
  createElement(tag){return new MockNode(tag);},
  createTextNode(s){const n=new MockNode("#text");n.textContent=s;return n;},
  querySelectorAll(q){assert.equal(q,'input[name="view"]');return viewInputs;},
  addEventListener(k,fn){this.keyEvents=this.keyEvents||{};this.keyEvents[k]=fn;}
};
const downloads=[];
const context={document,window:{},Blob,URL:{
  createObjectURL(blob){downloads.push(blob);return "blob:synthetic-file";},
  revokeObjectURL(){}
},XMLSerializer:class{serializeToString(){return "<svg><title>SYNTHETIC</title></svg>";}},
setTimeout(fn){fn();},requestAnimationFrame(){},console};
vm.runInNewContext(fs.readFileSync("pkgdown/assets/synthetic-explorer.js","utf8"),context,{timeout:2500});
vm.runInNewContext(fs.readFileSync("pkgdown/assets/synthetic-lab.js","utf8"),context,{timeout:2500});
const api=context.window.AQTExplorer;
assert.ok(api);
assert.equal(api.count,5);
assert.equal(nodes.paths.children.length,5);
assert.equal(nodes.cameraXY.children.filter(n=>n.tagName==="PATH").length,5);
assert.equal(nodes.cameraXZ.children.filter(n=>n.tagName==="CIRCLE").length,5);
assert.equal(nodes.metricObserved.textContent,"5 / 5");
assert.match(nodes.quizQuestion.textContent,/invented paths/);
assert.ok(nodes.speedChart.children.length>10);

// Orbital control affects only the scene projection, not the mathematical data.
const truth=JSON.stringify(api.tracks[0][105]);
const initial=api.project(api.tracks[0][105],"iso")[0];
nodes.azimuth.value="120";nodes.azimuth.fire("input");
assert.equal(api.getState().azimuth,120);
assert.notEqual(api.project(api.tracks[0][105],"iso")[0],initial);
assert.equal(JSON.stringify(api.tracks[0][105]),truth);

// A preset jumps to the missing observation and preserves the missingness.
nodes.lessonPreset.value="occlusion";nodes.lessonPreset.fire("change");
assert.equal(api.getState().frame,105);
assert.equal(nodes.metricObserved.textContent,"4 / 5");
assert.equal(nodes.metricSpeed.textContent,"—");
assert.equal(nodes.heads.children[0].style.display,"none");
assert.ok(nodes.teachingOverlays.children.some(n=>n.tagName==="RECT"));
assert.match(nodes.quizQuestion.textContent,/interpolate/);

// Step beyond the disappearance: track path must remain discontinuous.
nodes.stepForward.fire("click");
assert.equal(api.getState().frame,106);
nodes.jumpSwitch.fire("click");
assert.equal(api.getState().frame,130);
assert.equal((nodes.paths.children[0].attrs.d.match(/M/g)||[]).length,2);

// Identity lesson swaps displayed labels only.
nodes.lessonPreset.value="identity";nodes.lessonPreset.fire("change");
assert.equal(api.getState().frame,137);
assert.equal(nodes.heads.children[1].textContent,"F2?");
assert.equal(nodes.heads.children[3].textContent,"F1?");
assert.equal(JSON.stringify(api.tracks[0][105]),truth);
nodes.quizYes.fire("click");assert.match(nodes.quizFeedback.textContent,/Not quite/);
nodes.quizNo.fire("click");assert.match(nodes.quizFeedback.textContent,/Correct/);

// Two view panels share time but use different XY and XZ geometry.
const XY=nodes.cameraXY.children.map(n=>n.attrs.d).filter(Boolean).join("");
const XZ=nodes.cameraXZ.children.map(n=>n.attrs.d).filter(Boolean).join("");
assert.notEqual(XY,XZ);
nodes.showCameras.checked=false;nodes.showCameras.fire("change");
assert.equal(nodes.cameraPanel.hidden,true);
nodes.showCameras.checked=true;nodes.showCameras.fire("change");
assert.equal(nodes.cameraPanel.hidden,false);

// Playback and frame stepping are bounded and do not affect the source tracks.
nodes.playbackRate.value="2";nodes.playbackRate.fire("change");
assert.equal(context.window.AQTExplorerRate,2);
api.setFrame(300);nodes.stepForward.fire("click");assert.equal(api.getState().frame,300);
api.setFrame(0);nodes.stepBack.fire("click");assert.equal(api.getState().frame,0);

// Event lesson represents an annotation marker, not a treatment simulator.
nodes.lessonPreset.value="event";nodes.lessonPreset.fire("change");
assert.equal(api.getState().frame,166);
assert.match(nodes.eventReadout.textContent,/not causal evidence/);
assert.match(nodes.quizQuestion.textContent,/causal/);
nodes.jumpEvent.fire("click");assert.equal(nodes.metricEvent.textContent,"0.00 s");

// Export 1505 synthetic rows, including explicit known synthetic truth and missing flags.
const originalDocumentCreate=document.createElement;
document.createElement=(tag)=>{
  const n=originalDocumentCreate(tag);
  if(tag==="a"){n.click=function(){downloads.filename=this.download;};}
  return n;
};
nodes.lessonPreset.value="identity";nodes.lessonPreset.fire("change");
nodes.exportCsv.fire("click");
assert.equal(downloads.filename,"AquaTrajectories_SYNTHETIC_tracking_exercise.csv");
const csv=await downloads.at(-1).text();
const lines=csv.trim().split(/\r?\n/);
assert.equal(lines.length,1+5*301);
assert.ok(lines[0].includes("synthetic_true_id"));
assert.ok(lines.some(s=>s.includes("F1,F2?,")&&s.includes("TRUE")));
assert.ok(lines.some(s=>s.includes("F1,F1,,,,FALSE")));
nodes.exportSvg.fire("click");
assert.equal(downloads.filename,"AquaTrajectories_SYNTHETIC_scene.svg");

// Learning-mode navigation remains usable.
nodes.nextLesson.fire("click");
assert.equal(nodes.lessonPreset.value,"multiview");
assert.match(nodes.lessonProgress.textContent,/Lesson 4/);
console.log("AQT_SYNTHETIC_LAB_PASS: orbit, camera projections, frame gaps, label truth, metrics, quizzes, event, playback, CSV and SVG exports");
