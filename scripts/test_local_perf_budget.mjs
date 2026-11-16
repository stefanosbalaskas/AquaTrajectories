// Browser-local CSV parsing and data-inspector performance budget.
// These are invented rows for resource limits, not fisheries observations.
import assert from "node:assert/strict";
import {performance} from "node:perf_hooks";
import {parseResearchCSV,inspectTracks} from "../pkgdown/assets/research-local-core.mjs";
const header="session_id,camera_id,track_id,time_s,x,y,observed\n";
let rows=header;
for(let fish=0;fish<80;fish++){
 for(let frame=0;frame<250;frame++){
   rows+="S,C,F"+fish+","+(frame*.05).toFixed(4)+","+fish+","+frame+",TRUE\n";
 }
}
assert.ok(rows.length<10*1024*1024);
const before=process.memoryUsage().heapUsed;
const start=performance.now();
const parsed=parseResearchCSV(rows);
const analysis=inspectTracks(parsed,.1);
const elapsed=performance.now()-start;
const growth=(process.memoryUsage().heapUsed-before)/1024/1024;
assert.equal(parsed.length,20000);
assert.equal(analysis.stats.scopedTracks,80);
assert.equal(analysis.stats.longGaps,0);
assert.ok(elapsed<15000,"20,000-row parse/QC exceeded 15 seconds: "+elapsed);
assert.ok(growth<220,"CSV parse/QC heap growth exceeded 220MB: "+growth);
console.log("AQT_LOCAL_PERF_PASS: 20k synthetic rows, elapsed_ms="+elapsed.toFixed(1)+", net_heap_MiB="+growth.toFixed(1));
