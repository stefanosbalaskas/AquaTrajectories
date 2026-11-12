import {test} from "node:test";
import assert from "node:assert/strict";
import {parseCSV,normalizeTracks,normalizeFrames,normalizeEvents,
        sourceFrameAt,observationsAt,project3D,localAuditSummary,dryRunACI}
  from "../../inst/explorer/core.mjs";

test("valid RFC-style quoted comma and source frame time survive",()=>{
  const data=parseCSV('frame_id,time_s,description\r\n0,0,"fish, top view"\r\n1,.041,"A ""fish"""');
  assert.equal(data.length,2);
  assert.equal(data[0].description,"fish, top view");
  assert.equal(data[1].description,'A "fish"');
  assert.throws(()=>parseCSV('a,b\n1\n'),/width mismatch/);
  assert.throws(()=>parseCSV('a,b\n"unclosed,2'),/Unterminated/);
  assert.throws(()=>parseCSV('a,a\n1,2'),/duplicated/);
});
test("scope and missing fish cannot be silently converted to observations",()=>{
  const raw=parseCSV(
    "session_id,camera_id,track_id,time_s,x,y,z,observed\n"+
    "s1,top,2,.000,10,20,,true\n"+
    "s1,top,2,.042,11,19,,true\n"+
    "s1,side,2,.042,22,25,,true\n"+
    "s1,top,3,.042,,,,false");
  const tracks=normalizeTracks(raw);
  assert.equal(tracks.length,4);
  assert.equal(observationsAt(tracks,.042,"s1","top",.005).length,1);
  assert.equal(observationsAt(tracks,.042,"s1","side",.005).length,1);
  assert.equal(observationsAt(tracks,.002,"s1","top",.0001).length,0);
  assert.throws(()=>normalizeTracks([raw[0],raw[0]]),/Duplicate scoped/);
  assert.throws(()=>normalizeTracks([{...raw[0],time_s:""}]),/Invalid numeric/);
  assert.throws(()=>normalizeTracks([{...raw[3],x:"1"}]),/Unobserved track/);
});
test("external original frame time lookup has explicit tolerance",()=>{
  const rows=normalizeFrames(parseCSV(
    "session_id,camera_id,frame_id,time_s,width_px,height_px\n"+
    "s1,top,0,0,1920,1080\n"+
    "s1,top,1,.041,1920,1080\n"+
    "s1,side,0,.011,1920,1080"));
  assert.equal(sourceFrameAt(rows,.04,"s1","top",.01).frame_id,1);
  assert.equal(sourceFrameAt(rows,.04,"s1","side",.005),null);
  assert.equal(sourceFrameAt(rows,100,"s1","top",.1),null);
  assert.throws(()=>normalizeFrames([rows[0],rows[0]].map(x=>({
    ...x,frame_id:String(x.frame_id),time_s:String(x.time_s),
    width_px:String(x.width_px),height_px:String(x.height_px)}))),/Duplicate scoped/);
});
test("3D screen projection is visualization only and never changes source",()=>{
  const p={x:10,y:20,z:30};
  assert.deepEqual(project3D(p,0,0),p);
  assert.throws(()=>project3D({x:1,y:2,z:null}),/requires observed finite/);
  const events=normalizeEvents(parseCSV("event_id,time_s,event_type\ne2,4,feeding\ne1,2,barrier"));
  assert.equal(events[0].event_id,"e1");
  const tracks=normalizeTracks(parseCSV(
    "session_id,camera_id,track_id,time_s,x,y,z,observed\n"+
    "s,3D,1,2,1,2,3,true"));
  const result=localAuditSummary(tracks,[],events);
  assert.equal(result.n_observed_track_rows,1);
  assert.equal(result.n_event_rows,2);
  assert.equal(result.camera_hardware_exposure_synced,false);
  assert.equal(result.underwater_physical_xyz_certified,false);
  assert.equal(result.ACI_device_controlled,false);
});


test("ACI dry-run enforces explicit limits, cooldown and emergency stop",()=>{
  const events=[
    {event_id:"a",time_s:1,event_type:"aci_choice_request"},
    {event_id:"b",time_s:2,event_type:"aci_choice_request"},
    {event_id:"c",time_s:8,event_type:"aci_choice_request"},
    {event_id:"feed",time_s:9,event_type:"feeding"},
    {event_id:"d",time_s:15,event_type:"aci_choice_request"}];
  const options={approval_reference:"protocolA",device_id:"offline-virtual",
    action_type:"simulated_light",cooldown_s:5,max_commands:2,
    duration_s:.5,max_duration_s:1,intensity:.3,max_intensity:.5,
    emergency_stop:false};
  const result=dryRunACI(events,options);
  assert.deepEqual(result.commands.map(x=>x.event_id),["a","c"]);
  assert.deepEqual(result.rejected.map(x=>x.reason),
    ["cooldown_active","maximum_command_count"]);
  assert.equal(result.hardware_device_contacted,false);
  assert.equal(result.biological_safety_certified,false);
  assert.ok(result.commands.every(x=>x.execution_status==="SIMULATED_ONLY"));
  const stopped=dryRunACI(events,{...options,emergency_stop:true});
  assert.equal(stopped.commands.length,0);
  assert.throws(()=>dryRunACI(events,{...options,intensity:5}),/limits violated/);
  assert.throws(()=>dryRunACI(events,{...options,approval_reference:""}),/approval/);
  assert.throws(()=>dryRunACI(events,{...options,emergency_stop:null}),/emergency stop/);
});
