import {test} from "node:test";
import assert from "node:assert/strict";
import {parseCSV,normalizeTracks,normalizeSceneTracks,
        normalizeCameraLinks,validateMultiviewFrames,normalizeEvents,
        cameraClockAt,masterSourcePTSAt,sceneSegments,eventsAt,
        validate3DSourceAudit,validateEmpiricalUncertainty,multiviewAudit}
  from "../../inst/explorer/multiview-core.mjs";

const sourceFrames=parseCSV(
  "session_id,camera_id,frame_id,time_s,raw_time_s,width_px,height_px\n"+
  "S1,TOP,0,0,0,1920,1080\n"+
  "S1,TOP,1,.04,.04,1920,1080\n"+
  "S1,SIDE,0,0.01,0,1920,1080\n"+
  "S1,SIDE,1,.05,.04,1920,1080");
const fish2D=parseCSV(
  "session_id,camera_id,track_id,time_s,x,y,observed\n"+
  "S1,TOP,1,0,100,200,TRUE\n"+
  "S1,SIDE,101,.01,102,199,TRUE");
const fish3D=parseCSV(
  "session_id,camera_id,track_id,time_s,x,y,z,observed\n"+
  "S1,REFRACTIVE3D,AUTO1,0,1,2,5,TRUE\n"+
  "S1,REFRACTIVE3D,AUTO1,.04,1.1,2,5,TRUE\n"+
  "S1,REFRACTIVE3D,AUTO1,2,2,2,5,TRUE");
const linkCSV=parseCSV(
  "session_id,camera_a,camera_b,id_a,id_b,fish_id,n_supported_observations,median_geometry_error\n"+
  "S1,TOP,SIDE,1,101,AUTO1,3,.01");

test("two camera original frame-PTS clocks are mapped without inventing shutter sync",()=>{
  const f=validateMultiviewFrames(sourceFrames);
  assert.equal(f.length,4);
  assert.equal(cameraClockAt(f,.045,"S1","SIDE",.02).raw_time_s,.04);
  assert.equal(cameraClockAt(f,1,"S1","SIDE",.02),null);
  assert.equal(masterSourcePTSAt(f,.04,"S1","TOP",.02).time_s,.04);
  assert.equal(masterSourcePTSAt(f,123,"S1","TOP",.01),null);
  assert.throws(()=>validateMultiviewFrames([
    {...sourceFrames[0],raw_time_s:"1"},
    {...sourceFrames[1],raw_time_s:"0"}]),/must increase/);
  assert.throws(()=>validateMultiviewFrames([
    {...sourceFrames[0],raw_time_s:"NaN"}]),/raw video timestamp/);
});

test("source 3D segments split source fish time gaps; never fill missing fish",()=>{
  const scene=normalizeSceneTracks(fish3D);
  const paths=sceneSegments(scene,"S1",.3);
  assert.equal(paths.length,2);
  assert.equal(paths[0].points.length,2);
  assert.equal(paths[1].points.length,1);
  assert.throws(()=>sceneSegments(scene,"S1",0),/gap threshold/);
  const no3d=normalizeSceneTracks([
    {...fish3D[0],observed:"false",x:"",y:"",z:""}]);
  assert.equal(no3d.length,0);
});

test("source crossview IDs remain provisional and cannot repeat within a pair",()=>{
  const pair=normalizeCameraLinks(linkCSV);
  assert.equal(pair[0].n_supported_observations,3);
  assert.equal(pair[0].independent_biological_identity_certified,false);
  assert.throws(()=>normalizeCameraLinks([...linkCSV,...linkCSV]),
                /Duplicate fused fish/);
  assert.throws(()=>normalizeCameraLinks([{...linkCSV[0],
     camera_b:"TOP"}]),/two distinct cameras/);
});

test("joint uncertainty source radius visible without invented physical validation",()=>{
  const source={
    schema:"aqt_empirical_joint_fish_uncertainty_v1",
    finite_sample_group_max_radial_radius:.25,
    finite_sample_unconditional_joint_interval_available:true,
    alpha:.05,radius_units:"cm",
    n_original_train_tanks:25,n_original_holdout_tanks:5,
    original_physical_XYZ_independent_survey_authenticated:false,
    source_fish_ID_ground_truth_independently_adjudicated:false
  };
  const v=validateEmpiricalUncertainty(source,"cm");
  assert.equal(v.radius,.25);
  assert.equal(v.independent_XYZ_verified,false);
  assert.equal(v.biological_ID_verified,false);
  assert.throws(()=>validateEmpiricalUncertainty(source,"m"),
                /mismatched physically declared/);
  assert.throws(()=>validateEmpiricalUncertainty(source),
                /mismatched physically declared/);
  const audit=validate3DSourceAudit({
    schema_version:"1.0",source_3d_units:"cm",n_3d_rows:3,
    biological_identity_certified:false,
    underwater_physical_xyz_accuracy_certified:false},3);
  assert.equal(audit.xyz_units,"cm");
  assert.throws(()=>validate3DSourceAudit({
    schema_version:"1.0",source_3d_units:"m",n_3d_rows:5,
    biological_identity_certified:false,
    underwater_physical_xyz_accuracy_certified:false},3),/audit mismatched/);
  assert.throws(()=>validate3DSourceAudit({
    schema_version:"1.0",source_3d_units:"cm",n_3d_rows:3,
    biological_identity_certified:true,
    underwater_physical_xyz_accuracy_certified:true},3),/audit mismatched/);
  assert.throws(()=>validateEmpiricalUncertainty({
    ...source,finite_sample_group_max_radial_radius:null},"cm"),
    /inconsistent/);
});

test("event annotations are source-only; independent camera/welfare/hardware remain false",()=>{
  const events=normalizeEvents(parseCSV(
    "event_id,time_s,event_type\nE1,.04,aci_choice_request"));
  const observed=eventsAt(events,.04,.01);
  assert.equal(observed.length,1);
  const out=multiviewAudit(normalizeTracks(fish2D),
    normalizeSceneTracks(fish3D),
    validateMultiviewFrames(sourceFrames),
    normalizeCameraLinks(linkCSV),events,null);
  assert.equal(out.n_original_camera_scopes,2);
  assert.equal(out.n_source_3d_observations,3);
  assert.equal(out.hardware_exposure_sync_certified,false);
  assert.equal(out.physically_surveyed_XYZ_certified,false);
  assert.equal(out.physical_ACI_device_contacted,false);
  assert.equal(out.actual_animal_welfare_validated,false);
});
