// Browser-only identity demonstration, tested without a DOM dependency.
import fs from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

class Node {
  constructor(name = "div") {
    this.name=name; this.children=[]; this.events={}; this.attributes={};
    this.style={}; this.textContent=""; this.checked=false; this.value="";
  }
  setAttribute(name,value) {this.attributes[name]=String(value);}
  appendChild(child) {this.children.push(child);return child;}
  append(...children) {this.children.push(...children);}
  replaceChildren(...children) {this.children=[...children];}
  addEventListener(event,handler) {this.events[event]=handler;}
  fire(event) {assert.equal(typeof this.events[event],"function");this.events[event]();}
}
const nodes={};
for(const key of ["grid","paths","heads","frame","trail","play","reset",
                  "frameValue","trailValue","status","viewTitle",
                  "fishfilters","legend","learningStatus",
                  "occlusion-demo","idswitch-demo"]) {
  nodes[key]=new Node(key);
}
nodes.trail.value="60";nodes.frame.value="0";
const radioViews=["iso","xy","xz","yz"].map(value=>{
 const n=new Node("input");n.value=value;n.checked=value==="iso";return n;
});
const document={
 getElementById(id){assert.ok(nodes[id],"Missing DOM mock "+id);return nodes[id]},
 createElementNS(_ns,name){return new Node(name)},
 createElement(name){return new Node(name)},
 createTextNode(value){const n=new Node("textNode");n.textContent=value;return n},
 querySelectorAll(query){assert.equal(query,'input[name="view"]');return radioViews}
};
const js=fs.readFileSync("pkgdown/assets/synthetic-explorer.js","utf8");
vm.runInNewContext(js,{document,requestAnimationFrame(){}},{timeout:2000});
assert.equal(nodes.paths.children.length,5);
assert.equal(nodes.heads.children.filter(n=>n.name==="circle").length,5);
assert.equal(nodes.heads.children.filter(n=>n.name==="text").length,5);
const paths=nodes.paths.children;
const heads=nodes.heads.children.filter(n=>n.name==="circle");
const labels=nodes.heads.children.filter(n=>n.name==="text");
assert.equal(labels[0].textContent,"F1");

// A visible fish should disappear only in the deliberately simulated occlusion.
nodes["occlusion-demo"].checked=true;
nodes["occlusion-demo"].fire("change");
nodes.frame.value=105;
nodes.frame.fire("input");
assert.equal(heads[0].style.display,"none");
assert.equal(heads[1].style.display,"");
assert.match(nodes.learningStatus.textContent,/missing/i);

// Resumption must be a NEW SVG subpath, not an interpolated line across frames.
nodes.frame.value=130;
nodes.frame.fire("input");
const firstTrackD=paths[0].attributes.d;
assert.equal((firstTrackD.match(/M/g)||[]).length,2,"Missing segment was bridged");
assert.equal((paths[1].attributes.d.match(/M/g)||[]).length,1);

// An identity error exchanges labels only, not underlying synthetic positions.
const originalFirstPath=paths[0].attributes.d;
nodes["idswitch-demo"].checked=true;
nodes["idswitch-demo"].fire("change");
assert.equal(labels[0].textContent,"F2?");
assert.equal(labels[1].textContent,"F1?");
assert.equal(paths[0].attributes.d,originalFirstPath);

// Clearing toggles must restore continuous labels and positions.
nodes["idswitch-demo"].checked=false;nodes["idswitch-demo"].fire("change");
nodes["occlusion-demo"].checked=false;nodes["occlusion-demo"].fire("change");
assert.equal(labels[0].textContent,"F1");
assert.equal((paths[0].attributes.d.match(/M/g)||[]).length,1);
console.log("SYNTHETIC_EXPLORER_BEHAVIOR_PASS: five tracks, no missing interpolation, label-only ID switch");
