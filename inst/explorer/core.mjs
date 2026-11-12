/** AquaTrajectories offline explorer data primitives.
 * Exact observed time_s only; never manufacture camera synchronization or XYZ.
 * No browser calls, network, telemetry or welfare models in this module.
 */
export function parseCSV(text) {
  if (typeof text !== "string" || text.length > 50_000_000)
    throw new Error("CSV must be a bounded string");
  const rows = [], row = [];
  let cell = "", inQuote = false;
  const emitCell = () => { row.push(cell); cell = ""; };
  const emitRow = () => {
    emitCell();
    if (row.length !== 1 || row[0] !== "") rows.push(row.splice(0));
    else row.length = 0;
  };
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuote) {
      if (c === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (c === '"') inQuote = false;
      else cell += c;
    } else if (c === '"' && cell === "") inQuote = true;
    else if (c === ",") emitCell();
    else if (c === "\n") emitRow();
    else if (c === "\r") {
      emitRow();
      if (text[i + 1] === "\n") i++;
    } else cell += c;
  }
  if (inQuote) throw new Error("Unterminated quoted field");
  if (cell !== "" || row.length) emitRow();
  if (!rows.length) throw new Error("Empty CSV");
  const [header, ...body] = rows;
  if (header[0]?.charCodeAt(0) === 0xfeff) header[0] = header[0].slice(1);
  if (header.some(x => !x || x.trim() !== x) ||
      new Set(header).size !== header.length)
    throw new Error("Invalid or duplicated CSV headings");
  return body.map((row, index) => {
    if (row.length !== header.length)
      throw new Error("CSV width mismatch at record " + (index + 1));
    return Object.fromEntries(header.map((key, i) => [key, row[i]]));
  });
}
function requireCols(rows, cols, name) {
  if (!rows.length) throw new Error(name + " has no records");
  for (const col of cols) if (!(col in rows[0]))
    throw new Error(name + " missing " + col);
}
function number(value, field) {
  if (typeof value !== "string" || !value.trim() || !Number.isFinite(+value))
    throw new Error("Invalid numeric " + field);
  return +value;
}
export function normalizeTracks(rows) {
  requireCols(rows, ["session_id", "camera_id", "track_id",
                     "time_s", "x", "y"], "tracks");
  const seen = new Set();
  return rows.map((r) => {
    const ids = ["session_id","camera_id","track_id"];
    for (const col of ids) if (!r[col]?.trim()) throw new Error("Empty " + col);
    const t = number(r.time_s, "time_s");
    const observed = (r.observed === undefined || r.observed === "") ? true :
      r.observed.toLowerCase() === "true";
    if (r.observed !== undefined && r.observed !== "" &&
        !["true","false"].includes(r.observed.toLowerCase()))
      throw new Error("observed must be true or false");
    let x = null, y = null, z = null;
    if (observed) {
      x = number(r.x, "x");
      y = number(r.y, "y");
      if (r.z !== undefined && r.z.trim()) z = number(r.z, "z");
    } else if (r.x.trim() || r.y.trim() || (r.z || "").trim()) {
      throw new Error("Unobserved track row cannot have position");
    }
    const key = JSON.stringify([r.session_id, r.camera_id, r.track_id, t]);
    if (seen.has(key)) throw new Error("Duplicate scoped fish-time observation");
    seen.add(key);
    return {session_id:r.session_id,camera_id:r.camera_id,
      track_id:r.track_id,time_s:t,x,y,z,observed};
  }).sort((a,b)=>a.time_s-b.time_s ||
    a.camera_id.localeCompare(b.camera_id) ||
    a.track_id.localeCompare(b.track_id));
}
export function normalizeFrames(rows) {
  requireCols(rows, ["session_id","camera_id","frame_id",
    "time_s","width_px","height_px"], "frame manifest");
  const seen = new Set();
  return rows.map(r=>{
    const frame_id=number(r.frame_id,"frame_id");
    const time_s=number(r.time_s,"time_s");
    const width_px=number(r.width_px,"width_px");
    const height_px=number(r.height_px,"height_px");
    if (!Number.isInteger(frame_id) || frame_id<0 ||
        width_px<=0 || height_px<=0 ||
        !r.session_id?.trim() || !r.camera_id?.trim())
      throw new Error("Invalid frame identity or source geometry");
    const key=JSON.stringify([r.session_id,r.camera_id,frame_id]);
    if(seen.has(key)) throw new Error("Duplicate scoped decoded frame");
    seen.add(key);
    return {session_id:r.session_id,camera_id:r.camera_id,frame_id,
      time_s,width_px,height_px};
  }).sort((a,b)=>a.time_s-b.time_s);
}
export function normalizeEvents(rows) {
  if (!rows.length) return [];
  requireCols(rows,["event_id","time_s","event_type"],"events");
  const keys=new Set();
  return rows.map(r=>{
    if(!r.event_id?.trim() || !r.event_type?.trim() ||
       keys.has(r.event_id)) throw new Error("Missing/duplicate event identity");
    keys.add(r.event_id);
    return {event_id:r.event_id,time_s:number(r.time_s,"event time_s"),
      event_type:r.event_type};
  }).sort((a,b)=>a.time_s-b.time_s);
}
export function sourceFrameAt(frames,seconds,session,camera,maxSkew=0.2) {
  if(!Number.isFinite(seconds)||!(maxSkew>=0))throw new Error("Invalid time");
  let best=null,delta=Infinity;
  for(const f of frames)if(f.session_id===session&&f.camera_id===camera){
    const d=Math.abs(f.time_s-seconds);
    if(d<delta){delta=d;best=f;}
  }
  // Nearest without silent interpolation, bounded by explicit tolerance.
  return best&&delta<=maxSkew?{...best,clock_difference_s:delta}:null;
}
export function observationsAt(tracks,seconds,session,camera,maxSkew=0.08){
  if(!Number.isFinite(seconds)||!(maxSkew>=0))throw new Error("Invalid time");
  const result=new Map();
  for(const p of tracks){
    if(p.session_id!==session||p.camera_id!==camera||!p.observed)continue;
    const d=Math.abs(p.time_s-seconds);
    const previous=result.get(p.track_id);
    if(d<=maxSkew&&(!previous||d<previous.time_difference_s)){
      result.set(p.track_id,{...p,time_difference_s:d});
    }
  }
  return [...result.values()];
}
export function project3D(point,yaw=0,pitch=0) {
  if([point.x,point.y,point.z,yaw,pitch].some(v=>!Number.isFinite(v)))
    throw new Error("3D scene requires observed finite XYZ");
  const cy=Math.cos(yaw),sy=Math.sin(yaw),cp=Math.cos(pitch),sp=Math.sin(pitch);
  const x=cy*point.x+sy*point.z,depth=-sy*point.x+cy*point.z;
  const y=cp*point.y-sp*depth;
  const z=sp*point.y+cp*depth;
  return {x,y,z};
}
export function localAuditSummary(tracks,frames,events){
  return {
    n_track_rows:tracks.length,n_observed_track_rows:tracks.filter(r=>r.observed).length,
    n_frame_clock_rows:frames.length,n_event_rows:events.length,
    n_camera_scopes:new Set(tracks.map(r=>JSON.stringify([r.session_id,r.camera_id]))).size,
    positions_from_source_only:true,
    automatically_inferred_fish_id_accuracy:false,
    camera_hardware_exposure_synced:false,
    underwater_physical_xyz_certified:false,
    animal_welfare_validated:false,
    ACI_device_controlled:false
  };
}
