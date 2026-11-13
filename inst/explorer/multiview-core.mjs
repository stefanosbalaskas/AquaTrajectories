/** Fully local AquaTrajectories multi-camera/3D research data primitives.
 * Browser-selected original video files only; no server, telemetry, hardware
 * access or fabricated 3D, hardware synchronization or animal-welfare truth.
 */
import {normalizeTracks,normalizeFrames,normalizeEvents,project3D}
  from "./core.mjs";

export function validateMultiviewFrames(raw) {
  const standard=normalizeFrames(raw);
  const lookup=new Map();
  for(const r of raw) {
    const k=JSON.stringify([r.session_id,r.camera_id,Number(r.frame_id)]);
    if(lookup.has(k))throw new Error("Duplicated original frame manifest");
    const source=(r.raw_time_s===undefined || r.raw_time_s==="") ?
      Number(r.time_s):Number(r.raw_time_s);
    if(!Number.isFinite(source)||source<0)
      throw new Error("Original source raw video timestamp must be finite nonnegative");
    lookup.set(k,source);
  }
  const aligned=standard.map(f=>({
    ...f,raw_time_s:lookup.get(JSON.stringify([
      f.session_id,f.camera_id,f.frame_id]))}));
  const scopes=new Map();
  for(const f of aligned) {
    const k=JSON.stringify([f.session_id,f.camera_id]);
    if(!scopes.has(k))scopes.set(k,[]);
    scopes.get(k).push(f);
  }
  for(const rows of scopes.values()) {
    rows.sort((a,b)=>a.frame_id-b.frame_id);
    for(let i=1;i<rows.length;i++) {
      if(rows[i].time_s<=rows[i-1].time_s ||
         rows[i].raw_time_s<=rows[i-1].raw_time_s)
        throw new Error("Camera frame PTS and aligned timestamps must increase");
    }
  }
  return aligned;
}

export function cameraClockAt(frames,seconds,session,camera,
                               tolerance_s=.05) {
  if(!Number.isFinite(seconds)||!Number.isFinite(tolerance_s)||
     tolerance_s<0)throw new Error("Invalid synchronized time/tolerance");
  const rows=frames.filter(f=>f.session_id===session&&f.camera_id===camera);
  if(!rows.length)return null;
  let closest=null,diff=Infinity;
  for(const f of rows) {
    const d=Math.abs(f.time_s-seconds);
    if(d<diff){closest=f;diff=d;}
  }
  return diff<=tolerance_s?{...closest,alignment_residual_s:diff}:null;
}

export function masterSourcePTSAt(frames,rawSeconds,session,camera,
                                  tolerance_s=.05) {
  if(!Number.isFinite(rawSeconds)||!Number.isFinite(tolerance_s)||
     tolerance_s<0)throw new Error("Invalid source video PTS");
  let closest=null,diff=Infinity;
  for(const f of frames) {
    if(f.session_id!==session||f.camera_id!==camera)continue;
    const d=Math.abs(f.raw_time_s-rawSeconds);
    if(d<diff){closest=f;diff=d;}
  }
  return diff<=tolerance_s?{...closest,source_clock_error_s:diff}:null;
}

export function normalizeSceneTracks(rows) {
  const source=normalizeTracks(rows);
  return source.filter(x=>x.observed&&x.z!==null);
}

export function normalizeCameraLinks(rows) {
  if(!Array.isArray(rows))throw new Error("Source cross-camera links required");
  const unique=new Set();
  return rows.map((r,i)=>{
    for(const f of ["session_id","id_a","id_b","fish_id",
                   "camera_a","camera_b"])
      if(!r[f]?.trim())throw new Error("Invalid original cross-camera "+f);
    if(r.camera_a===r.camera_b)
      throw new Error("Source association needs two distinct cameras");
    const key=JSON.stringify([r.session_id,r.camera_a,r.camera_b,r.fish_id]);
    if(unique.has(key))throw new Error("Duplicate fused fish identity");
    unique.add(key);
    const support=Number(r.n_supported_observations);
    const error=Number(r.median_geometry_error);
    if(!Number.isInteger(support)||support<1||
       !Number.isFinite(error)||error<0)
      throw new Error("Invalid original geometric matching evidence");
    return {...r,n_supported_observations:support,
      median_geometry_error:error,
      source_index:i,independent_biological_identity_certified:false};
  });
}

export function sceneSegments(tracks,session,maxGap_s=.3) {
  if(!Number.isFinite(maxGap_s)||maxGap_s<=0)
    throw new Error("Invalid 3D gap threshold");
  const byFish=new Map();
  for(const p of tracks) {
    if(p.session_id!==session||p.z===null||!p.observed)continue;
    if(!byFish.has(p.track_id))byFish.set(p.track_id,[]);
    byFish.get(p.track_id).push(p);
  }
  const segments=[];
  for(const [fish,points] of byFish) {
    points.sort((a,b)=>a.time_s-b.time_s);
    let group=[];
    for(const p of points) {
      if(group.length&&p.time_s-group[group.length-1].time_s>maxGap_s) {
        if(group.length)segments.push({fish_id:fish,points:group});
        group=[];
      }
      if(group.length&&p.time_s<=group[group.length-1].time_s)
        throw new Error("Source fish 3D track repeats/nonincreasing time");
      group.push(p);
    }
    if(group.length)segments.push({fish_id:fish,points:group});
  }
  return segments;
}

export function eventsAt(events,seconds,window_s=.15) {
  if(!Number.isFinite(seconds)||!Number.isFinite(window_s)||window_s<0)
    throw new Error("Invalid reviewer timeline");
  return events.filter(e=>Math.abs(e.time_s-seconds)<=window_s);
}

export function validate3DSourceAudit(report,observed3DCount){
  if(report==null)return null;
  if(!report||report.schema_version!=="1.0"||
     !["cm","m"].includes(report.source_3d_units)||
     !Number.isInteger(report.n_3d_rows)||report.n_3d_rows!==observed3DCount||
     report.biological_identity_certified!==false||
     report.underwater_physical_xyz_accuracy_certified!==false)
    throw new Error("3D source origin, physical units, or provisional identity audit mismatched");
  return {xyz_units:report.source_3d_units,
    n_3d_rows:report.n_3d_rows,
    original_source_scientifically_certified:false,
    video_camera_hardware_sync_certified:false};
}

export function validateEmpiricalUncertainty(report,expectedUnits=null) {
  if(report==null)return {available:false,radius:null,
    calibrated_from_source:false,independent_XYZ_verified:false};
  if(!report||report.schema!=="aqt_empirical_joint_fish_uncertainty_v1")
    throw new Error("Unknown joint-uncertainty empirical report");
  const radius=report.finite_sample_group_max_radial_radius;
  if(radius!==null&&(!Number.isFinite(radius)||radius<0))
    throw new Error("Invalid source empirical uncertainty radius");
  if(radius!==null&&(!["cm","m"].includes(expectedUnits)||
     !["cm","m"].includes(report.radius_units)||
     report.radius_units!==expectedUnits))
    throw new Error("Missing or mismatched physically declared source XYZ/uncertainty units");
  const shape={
    available:radius!==null,
    radius:radius??null,
    alpha:report.alpha,
    radius_units:report.radius_units,
    n_original_train_tanks:report.n_original_train_tanks,
    n_original_holdout_tanks:report.n_original_holdout_tanks,
    calibrated_from_source:report.finite_sample_unconditional_joint_interval_available===true,
    independent_XYZ_verified:report.original_physical_XYZ_independent_survey_authenticated===true,
    biological_ID_verified:report.source_fish_ID_ground_truth_independently_adjudicated===true};
  if(shape.available!==shape.calibrated_from_source)
    throw new Error("Scientific source uncertainty radius/coverage flags inconsistent");
  return shape;
}

export function multiviewAudit(tracks,scene,frames,links,events,uncertainty) {
  const session=new Set(tracks.map(x=>x.session_id));
  const cameras=new Set(tracks.map(x=>x.camera_id));
  const evidence=uncertainty||{available:false};
  return {
    n_sessions:session.size,
    n_original_camera_scopes:cameras.size,
    n_original_2d_tracks:tracks.length,
    n_original_clock_frames:frames.length,
    n_source_3d_observations:scene.length,
    n_auto_provisional_crossview_ID_links:links.length,
    n_external_intervention_event_rows:events.length,
    joint_uncertainty_empirical_radius_available:!!evidence.available,
    browser_rendering_is_source_only:true,
    source_video_files_user_selected_locally:true,
    hardware_exposure_sync_certified:false,
    external_fish_ID_blind_certified:false,
    physically_surveyed_XYZ_certified:false,
    user_interface_researcher_usability_certified:false,
    physical_ACI_device_contacted:false,
    actual_animal_welfare_validated:false};
}

export {normalizeTracks,normalizeFrames,normalizeEvents,project3D};
