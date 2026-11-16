import assert from "node:assert/strict";
import {parseResearchCSV,inspectTracks,normalizeFrameManifest,normalizeLocalTracks,normalizeLocalEvents,nearestAt,selectScopedFrame,selectVisibleTracks,framePtsToVideoTime} from "../pkgdown/assets/research-local-core.mjs";
const parsed=parseResearchCSV('session_id,camera_id,track_id,time_s,x,y,observed\r\n"S,1",C,T,0,1,2,TRUE\r\n"S,1",C,T,1,,,FALSE\r\n');
assert.equal(parsed.length,2);assert.equal(parsed[0].session_id,"S,1");assert.equal(parsed[1].x,"");
assert.throws(()=>parseResearchCSV('x,y\n"bad"x,2\n'));
assert.throws(()=>parseResearchCSV("a,a\n1,2\n"));
assert.throws(()=>parseResearchCSV('x,y\n"a,1\n'));
const audit=inspectTracks([
 {session_id:"S",camera_id:"C",track_id:"1",time_s:"0",x:"1",y:"2",observed:"TRUE"},
 {session_id:"S",camera_id:"C",track_id:"1",time_s:"1",x:"",y:"",observed:"FALSE"},
 {session_id:"S",camera_id:"C",track_id:"1",time_s:"1",x:"2",y:"3",observed:"TRUE"},
 {session_id:"S",camera_id:"C",track_id:"1",time_s:"0.5",x:"3",y:"4",observed:"TRUE"}
],.2);
assert.equal(audit.stats.duplicates,1);assert.equal(audit.stats.unobserved,1);
assert.ok(audit.stats.backwards>=1);assert.ok(audit.stats.longGaps>=1);
const frames=normalizeFrameManifest([
 {session_id:"S",camera_id:"A",frame_id:"0",time_s:"0",raw_time_s:"11",width_px:"800",height_px:"450"},
 {session_id:"S",camera_id:"A",frame_id:"1",time_s:"0.1",raw_time_s:"11.1",width_px:"800",height_px:"450"},
 {session_id:"S",camera_id:"B",frame_id:"0",time_s:"0.04",raw_time_s:"21",width_px:"800",height_px:"450"}
]);
assert.equal(selectScopedFrame(frames,"S","A",.09,.02).frame_id,1);
assert.equal(selectScopedFrame(frames,"S","B",.2,.02),null);
assert.ok(Math.abs(framePtsToVideoTime(frames,frames.find(f=>f.camera_id==="A"&&f.frame_id===1))-.1)<1e-9);
assert.throws(()=>normalizeFrameManifest([{session_id:"S",camera_id:"A",frame_id:"0",time_s:"0",raw_time_s:"0",width_px:"800",height_px:"450"},{session_id:"S",camera_id:"A",frame_id:"1",time_s:"0",raw_time_s:"1",width_px:"800",height_px:"450"}]));
const tracks=normalizeLocalTracks([{session_id:"S",camera_id:"A",track_id:"fish01",time_s:"0.1",x:"100",y:"200",observed:"TRUE"}]);
assert.equal(selectVisibleTracks(tracks,"S","A",.1,.01).length,1);
assert.throws(()=>normalizeLocalTracks([{session_id:"S",camera_id:"A",track_id:"fish01",time_s:"0.1",x:"",y:"",observed:"TRUE"}]));
assert.equal(normalizeLocalEvents([{event_id:"ev1",time_s:"1",event_type:"feeding"}]).length,1);
assert.equal(nearestAt([],1),null);
console.log("AQT_LOCAL_DATA_PASS: RFC CSV quoting, observed-missing semantics, scoped time, frame PTS and local QC");
