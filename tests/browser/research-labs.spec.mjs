import {test,expect} from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import {Buffer} from "node:buffer";
const labs=["research-geometry.html","research-webr.html","research-multiview.html","research-data-inspector.html"];
async function noModuleErrors(page,fn){
 const errors=[];page.on("pageerror",e=>errors.push(String(e)));
 await fn();
 expect(errors,"Browser module exception").toEqual([]);
}
test("geometry: sliders recompute valid synthetic XYZ without page error",async({page})=>{
 await noModuleErrors(page,async()=>{
  await page.goto("/research-geometry.html");
  await expect(page.locator("#validReadout")).toContainText("Admissible");
  const before=await page.locator("#gapReadout").innerText();
  await page.locator("#noisePx").fill("7");
  await expect(page.locator("#noisePxOut")).toHaveText("7");
  expect(await page.locator("#gapReadout").innerText()).not.toBe(before);
  await page.locator("#reset").click();
  await expect(page.locator("#noisePxOut")).toHaveText("1");
  await expect(page.locator("#pointReadout")).not.toHaveText("—");
  await page.screenshot({path:"site-qualification/geometry-browser.png"});
 });
});
test("inspector: local synthetic and user CSV generate audit without uploading rows",async({page})=>{
 const uploads=[];page.on("request",r=>{if(!["GET","HEAD"].includes(r.method()))uploads.push(r.url());});
 await noModuleErrors(page,async()=>{
  await page.goto("/research-data-inspector.html");
  await page.locator("#demo").click();
  await expect(page.locator("#rowCount")).toHaveText("8");
  await expect(page.locator("#missingCount")).toHaveText("1");
  await expect(page.locator("#downloadAudit")).toBeEnabled();
  const download=page.waitForEvent("download");await page.locator("#downloadAudit").click();
  expect((await download).suggestedFilename()).toContain("local-qc");
  const csv="session_id,camera_id,track_id,time_s,x,y,observed\nS,C,fish1,0,4,3,TRUE\nS,C,fish1,1,8,5,TRUE\n";
  await page.locator("#csvFile").setInputFiles({name:"private-example.csv",mimeType:"text/csv",buffer:Buffer.from(csv)});
  await page.locator("#inspect").click();
  await expect(page.locator("#rowCount")).toHaveText("2");
  await expect(page.locator("#gapCount")).toHaveText("1");
  await page.locator("#reset").click();
  await expect(page.locator("#rowCount")).toHaveText("—");
 });
 expect(uploads).toEqual([]);
});
test("multiview: synthetic frame alignment and XYZ seek",async({page})=>{
 const requests=[];page.on("request",r=>{if(!["GET","HEAD"].includes(r.method()))requests.push(r.url());});
 await noModuleErrors(page,async()=>{
  await page.goto("/research-multiview.html");
  await page.locator("#synthetic").click();
  await expect(page.locator("#sourceStatus")).toContainText("SYNTHETIC");
  await expect(page.locator("#cameraAReadout")).toContainText("Source frame");
  await expect(page.locator("#cameraBReadout")).toContainText("Source frame");
  await page.locator("#stepNext").click();
  await expect(page.locator("#timeReadout")).toContainText("s");
  await page.locator("#yaw").fill("80");
  await expect(page.locator("#yawOut")).toHaveText("80");
  await expect(page.locator("#xyzReadout")).toContainText("source XYZ points");
  await page.locator("#clear").click();
  await expect(page.locator("#sourceStatus")).toContainText("cleared");
 });
 expect(requests).toEqual([]);
});
test("webR: runtime lazy and source responsive",async({page})=>{
 await noModuleErrors(page,async()=>{
  const external=[];page.on("request",r=>{if(r.url().includes("r-wasm.org"))external.push(r.url());});
  await page.goto("/research-webr.html");
  await expect(page.locator("#runtimeStatus")).toContainText("not initialized");
  expect(external).toEqual([]);
  await page.locator("#preset").selectOption("school");
  await expect(page.locator("#rSource")).toContainText("polarization");
  await page.locator("#n").fill("8");
  await expect(page.locator("#rSource")).toContainText("8L");
  await expect(page.locator("#run")).toBeDisabled();
 });
});
test("webR: real interpreter executes an example after explicit consent",async({page})=>{
 test.skip(process.env.RUN_WEBR_NETWORK!=="1","Network runtime requires explicit CI opt-in");
 test.setTimeout(180_000);
 await page.goto("/research-webr.html");
 await page.locator("#initialize").click();
 await expect(page.locator("#runtimeStatus")).toContainText("initialized",{timeout:145_000});
 await page.locator("#run").click();
 await expect(page.locator("#rOutput")).toContainText("Synthetic",{timeout:60_000});
});
test("four labs: mobile layout has no horizontal overflow",async({page})=>{
 await page.setViewportSize({width:390,height:844});
 for(const url of labs){
  await page.goto("/"+url);
  const w=await page.evaluate(()=>({scroll:document.documentElement.scrollWidth,inner:window.innerWidth}));
  expect(w.scroll,"Horizontal overflow on "+url).toBeLessThanOrEqual(w.inner+2);
 }
});
test("four labs: automated WCAG 2.2 semantics/contrast checks",async({page})=>{
 for(const url of labs){
  await page.goto("/"+url);
  const results=await new AxeBuilder({page}).withTags(["wcag2a","wcag2aa","wcag21a","wcag21aa","wcag22aa"]).analyze();
  const issues=results.violations.map(x=>({id:x.id,impact:x.impact,nodes:x.nodes.length}));
  expect(results.violations,"WCAG issues on "+url+": "+JSON.stringify(issues)).toEqual([]);
 }
});
