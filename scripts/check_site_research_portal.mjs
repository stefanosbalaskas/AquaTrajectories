// Research website smoke test. Read-only and deterministic; no network access.
import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";

const site = path.resolve("site");
const pages = [
  "index.html",
  "articles/aquaTrajectories.html",
  "articles/quickstart-five-minutes.html",
  "articles/plan-your-experiment.html",
  "articles/scientific-teaching.html",
  "articles/research-laboratory.html",
  "articles/real-fish-data-walkthrough.html",
  "research-geometry.html",
  "research-webr.html",
  "research-multiview.html",
  "research-data-inspector.html",
  "scientific-tracking-lab.html",
  "math-workbench.html",
  "plot-playground.html",
  "experiment-protocol-builder.html",
  "articles/capabilities-and-validation.html",
  "articles/video-to-results.html",
  "articles/experiment-starter-kit.html",
  "articles/identity-occlusion-tutorial.html",
  "articles/research-evidence-dashboard.html",
  "articles/all-plot-functions.html",
  "synthetic-explorer.html"
];
const extras = [
  "AquaTrajectories-research-starter-v1.zip",
  "AquaTrajectories-v0.1.1.bib",
  "starter-README.txt",
  "starter-tracks.csv",
  "starter-events.csv",
  "starter-sync-markers.csv",
  "starter-reference-boxes.csv",
  "starter-reference-tracks.csv",
  "starter-physical-xyz-targets.csv",
  "starter-camera-inventory.csv",
  "starter-study-design.csv",
  "synthetic-explorer.js",
  "synthetic-lab.js",
  "plot-gallery-filter.js",
  "scientific-teaching-core.mjs",
  "scientific-tracking-lab.mjs",
  "math-workbench.mjs",
  "plot-playground.mjs",
  "experiment-protocol-builder.mjs",
  "scientific-teaching.css",
  "research-lab.css",
  "research-geometry-core.mjs",
  "research-geometry.mjs",
  "research-webr.mjs",
  "research-multiview.mjs",
  "research-local-core.mjs",
  "research-inspector.mjs",
  "synthetic-experiment-protocol.md",
  "synthetic-session-manifest.csv",
  "synthetic-explorer.css"
];
const read = p => fs.readFileSync(path.join(site,p), "utf8");
for(const f of [...pages,...extras]) {
  assert.ok(fs.existsSync(path.join(site,f)), "Missing generated site resource: "+f);
  assert.ok(fs.statSync(path.join(site,f)).size > 0,"Empty site resource: "+f);
}
const home=read("index.html");
assert.match(home,/official v0\.1\.1 release/i);
assert.match(home,/10\.5281\/zenodo\.24262905/i);
assert.match(home,/quickstart-five-minutes/);
assert.match(home,/experiment-starter-kit/);
assert.match(home,/capabilities-and-validation/);
const start=read("articles/aquaTrajectories.html");
assert.match(start,/v0\.1\.1/);
assert.doesNotMatch(start, /ref\s*=\s*(?:(?:<[^>]*>)*[\s"]*)?v0\.1\.0/, "Get-started guide still asks for old release");
const demo=read("synthetic-explorer.html");
for(const id of ["occlusion-demo","idswitch-demo","learningStatus","frame","fishfilters","lessonPreset","cameraXY","cameraXZ","speedChart","focusFish","quizYes","quizNo","exportCsv","exportSvg"]) {
 assert.ok(demo.includes('id="'+id+'"'),"Missing accessible explorer feature: "+id);
}
assert.match(read("synthetic-explorer.js"),/isMissing/);
assert.match(read("synthetic-explorer.js"),/segmentOpen/);
assert.match(read("synthetic-lab.js"),/AQTExplorerExtension/);
assert.match(demo,/synthetic-lab\.js/);
const csv=read("starter-tracks.csv").trim().split(/\r?\n/);
assert.equal(csv.length,61,"Expected 60 synthetic observations and a header");
assert.ok(csv.some(x=>x.includes("fish03")&&x.includes("FALSE")), "Missing observation fixture absent");
assert.ok(csv[0].includes("observed"));
const xyz=read("starter-physical-xyz-targets.csv").trim().split(/\r?\n/);
assert.equal(xyz.length,1, "XYZ target template must NOT fake surveyed coordinates");

// Audit all locally linked documents and assets in the new generated pages.
// Absolute external links, anchors, data URIs and mailto are deliberately out of scope.
for(const page of pages) {
 const html=read(page);
 assert.match(html,/<h1[ >]/i, "Page lacks an H1: "+page);
 const pageDir=path.posix.dirname(page);
 for(const m of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
   const u=m[1].split(/[?#]/)[0];
   if(!u||/^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(u))continue;
   const normalized=path.posix.normalize(path.posix.join(pageDir,decodeURIComponent(u)));
   assert.ok(!normalized.startsWith("../"), "Unsafe relative link "+page+" -> "+u);
   const p=path.join(site,normalized);
   if(u.endsWith("/"))assert.ok(fs.existsSync(path.join(p,"index.html")), "Broken internal directory "+page+" -> "+u);
   else assert.ok(fs.existsSync(p), "Broken internal file "+page+" -> "+u);
 }
}

// Validate the actual downloadable, uncompressed ZIP central directory.
// Prevents advertising an incomplete or corrupt research starter archive.
const zipped=fs.readFileSync(path.join(site,"AquaTrajectories-research-starter-v1.zip"));
const readU16=(i)=>zipped.readUInt16LE(i), readU32=(i)=>zipped.readUInt32LE(i);
let tail=-1;for(let i=zipped.length-22;i>=Math.max(0,zipped.length-65557);i--){
 if(readU32(i)===0x06054b50){tail=i;break}
}
assert.ok(tail>=0,"Missing ZIP end-of-directory");
const nEntries=readU16(tail+10), directoryOffset=readU32(tail+16);
assert.equal(nEntries,9,"Unexpected ZIP starter file count");
let off=directoryOffset;const entries=new Set();
for(let i=0;i<nEntries;i++){
 assert.equal(readU32(off),0x02014b50,"Bad ZIP central directory");
 assert.equal(readU16(off+10),0,"Non-store compressed ZIP entry");
 const size=readU32(off+24),len=readU16(off+28),extra=readU16(off+30),comment=readU16(off+32);
 const name=zipped.toString("utf8",off+46,off+46+len);
 entries.add(name);
 assert.ok(size>0,"Empty ZIP entry "+name);
 off+=46+len+extra+comment;
}
assert.ok(entries.has("starter-tracks.csv")&&entries.has("starter-README.txt"));
const gallery=read("articles/all-plot-functions.html");
const galleryFunctions=Array.from(new Set(
  [...gallery.matchAll(/id="fig-(plot-[a-z0-9-]+)"/g)].map(m=>m[1])));
assert.equal(galleryFunctions.length,22,"Gallery must cover all 22 native plot exports");
assert.match(gallery,/16 native base-R outputs/);
assert.ok(gallery.includes('option value="rgl"'),"3D mode filter missing");
const cards=[...gallery.matchAll(/class="aqt-plot-entry"/g)].length;
assert.equal(cards,22,"Every plot function must have a visible card");
const nativeCards=[...gallery.matchAll(/data-mode="native"/g)].length;
const rglCards=[...gallery.matchAll(/data-mode="rgl"/g)].length;
assert.equal(nativeCards,16,"Expected 16 native figure cards");
assert.equal(rglCards,6,"Expected six explicitly marked rgl input preview cards");
const figures=[...gallery.matchAll(/<img[^>]*>/gi)];
assert.ok(figures.length>=23,"22 figure outputs plus the site logo must be present");
const figureAlts=figures.map(m=>m[0]).join(" ");
assert.match(figureAlts,/Actual plot rendered by aqt_plot_paths/);
assert.match(figureAlts,/Clearly labeled two-dimensional input projection for optional rgl function aqt_plot_voxel3d/);
assert.match(gallery,/plot-gallery-filter\.js/);
const planner=read("articles/plan-your-experiment.html");
for(const id of ["one-camera","two-cameras","existing-recordings","before-recording"]) {
 assert.ok(planner.includes('id="'+id+'"'),"Experiment guide missing "+id);
}
assert.match(home,/plan-your-experiment/);
assert.match(home,/synthetic-explorer/);
assert.ok(home.includes('<meta name="description" content="AquaTrajectories v0.1.1:'),"Homepage concise description missing");
assert.equal((home.match(/name="viewport"/g)||[]).length,1);
assert.equal([...gallery.matchAll(/id="code-plot-[a-z0-9-]+"/g)].length,22);
assert.equal([...gallery.matchAll(/data-code-link="true"/g)].length,22);
assert.equal(gallery.split("https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/").length-1,22,"Expected 22 pinned release source links");
for(const file of ["scientific-tracking-lab.html","math-workbench.html","plot-playground.html","experiment-protocol-builder.html"]){
  const source=read(file);
  assert.match(source,/synthetic/i,"Lab missing synthetic-data disclaimer: "+file);
  assert.match(source,/type="module"/,"Lab missing executable teaching script: "+file);
}
const plotted=read("articles/all-plot-functions.html");
for(const mode of ["paths","ensemble","school"]){
  assert.ok(plotted.includes("../plot-playground.html?mode="+mode),"Missing parameter playground link: "+mode);
}
const exampleManifest=read("synthetic-session-manifest.csv").trim().split(/\r?\n/);
assert.equal(exampleManifest.length,9,"Expected header plus eight blank-valued planning rows");
assert.ok(exampleManifest[0].includes("source_sha256"));

const researchPages=["research-geometry.html","research-webr.html","research-multiview.html","research-data-inspector.html"];
for(const page of researchPages){
 const html=read(page);
 assert.match(html,/synthetic|source/i,"Research lab lacks a limitation label "+page);
 assert.match(html,/type="module"/,"Research lab lacks executable client module "+page);
}
assert.match(home,/research-geometry.html/);
assert.match(home,/research-webr.html/);
assert.match(home,/research-multiview.html/);
assert.match(home,/research-data-inspector.html/);
assert.ok(read("research-webr.mjs").includes("https://webr.r-wasm.org/v0.6.1/webr.mjs"),"Pinned webR CDN import missing");
assert.match(read("research-webr.mjs"),/PostMessage/);
for(const name of ["research-multiview.mjs","research-inspector.mjs"]){
 const content=read(name);
 for(const forbidden of ["fetch(", "XMLHttpRequest", "sendBeacon"]) assert.ok(!content.includes(forbidden),"Local research module must not upload files: "+name);
}
console.log("AQT_WEBSITE_RESEARCH_SMOKE_PASS: 11 core pages, 15 assets, 22 plotted functions, internal links and synthetic data guarantees");
