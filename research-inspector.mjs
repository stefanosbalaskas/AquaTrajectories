import {parseResearchCSV,inspectTracks} from "./research-local-core.mjs";
const $=id=>document.getElementById(id);
let rows=null,summary=null,sourceKind="";
const demoCSV=[
 "session_id,camera_id,track_id,time_s,x,y,z,observed",
 "S01,CAM1,fish01,0,15,20,,TRUE",
 "S01,CAM1,fish01,0.1,16,20.2,,TRUE",
 "S01,CAM1,fish01,0.2,,,,FALSE",
 "S01,CAM1,fish01,1.5,17,20.5,,TRUE",
 "S01,CAM1,fish02,0,30,15,,TRUE",
 "S01,CAM1,fish02,0.1,31,16,,TRUE",
 "S01,CAM1,fish02,0.1,31.1,16.2,,TRUE",
 "S01,CAM1,fish02,0.05,31.3,16.1,,TRUE"
].join("\n")+"\n";
function render(){
 const ids=["rowCount","scopeCount","missingCount","gapCount"];
 if(!rows){for(const id of ids)$(id).textContent="—";$("issues").replaceChildren();$("downloadAudit").disabled=true;return;}
 summary=inspectTracks(rows,+$("gap").value);
 const s=summary.stats;
 for(const [id,value] of [["rowCount",s.rows],["scopeCount",s.scopedTracks],["missingCount",s.unobserved],["gapCount",s.longGaps]])$(id).textContent=String(value);
 $("gapOut").textContent=(+$("gap").value).toFixed(2);
 $("issues").replaceChildren();
 if(!summary.issues.length){
   const good=document.createElement("p");good.className="audit-row audit-good";good.textContent="No schema or timing flags under the selected rules. Biological or physical scientific validity is not certified.";$("issues").append(good);
 }
 for(const issue of summary.issues.slice(0,30)){
   const row=document.createElement("p");row.className="audit-row";
   row.textContent="Row "+issue.row+" · "+issue.code+": "+issue.message;
   $("issues").append(row);
 }
 if(summary.issues.length>30){
   const more=document.createElement("p");more.textContent=String(summary.issues.length-30)+" additional flags available in the JSON audit.";$("issues").append(more);
 }
 $("downloadAudit").disabled=false;
 $("inspectorStatus").textContent=sourceKind+": "+s.rows+" records, "+s.scopedTracks+" scoped tracks; "+summary.issues.length+" flagged conditions. No files were uploaded.";
}
$("gap").addEventListener("input",render);
$("demo").addEventListener("click",()=>{rows=parseResearchCSV(demoCSV);sourceKind="Invented synthetic example";render();});
$("inspect").addEventListener("click",async()=>{
 const file=$("csvFile").files?.[0];
 if(!file){$("inspectorStatus").textContent="Choose a local CSV before inspecting.";return;}
 if(file.size>10*1024*1024){$("inspectorStatus").textContent="Refused: local input larger than 10 MB.";return;}
 try{
   const parsed=parseResearchCSV(await file.text());
   inspectTracks(parsed,+$("gap").value);
   rows=parsed;sourceKind="Locally selected research CSV";render();
 }catch(e){
   rows=null;summary=null;render();$("inspectorStatus").textContent="Data inspection error: "+String(e.message||e);
 }
});
$("reset").addEventListener("click",()=>{
 rows=null;summary=null;sourceKind="";$("csvFile").value="";render();$("inspectorStatus").textContent="Input cleared from this application state; no file uploaded.";
});
$("downloadAudit").addEventListener("click",()=>{
 if(!summary)return;
 const report=JSON.stringify({source:"browser-local-audit",synthetic_example:sourceKind.startsWith("Invented"),schema:"AQT_UI_QC_v1",gap_threshold_s:summary.gapThreshold,
  stats:summary.stats,issues:summary.issues,track_summary:summary.trackSummaries,independent_scientific_validation_certified:false},null,2)+"\n";
 const blob=new Blob([report],{type:"application/json"}),url=URL.createObjectURL(blob),a=document.createElement("a");
 a.href=url;a.download="aquatrajectories-local-qc-audit.json";document.body.append(a);a.click();a.remove();
 setTimeout(()=>URL.revokeObjectURL(url),1000);
});
$("gapOut").textContent=$("gap").value;
