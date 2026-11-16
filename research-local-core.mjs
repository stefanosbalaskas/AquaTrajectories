/** Local-first scientific CSV inspection and multiview source contracts.
 * No fetch, network, storage or telemetry. All original user-selected data
 * remains inside the current browser document.
 */
const MAX_CSV_CHARS=10*1024*1024;
export function parseResearchCSV(text){
  if(typeof text!=="string"||text.length>MAX_CSV_CHARS)throw Error("CSV text exceeds 10 MB or is invalid");
  const rows=[],fields=[];let value="",quoted=false,closing=false;
  const addCell=()=>{fields.push(value);value="";closing=false;};
  const addRow=()=>{
    addCell();
    if(fields.length>1||fields[0]!=="")rows.push(fields.splice(0));
    else fields.length=0;
    if(rows.length>200001)throw Error("Maximum 200,000 CSV rows");
  };
  const str=text.charCodeAt(0)===0xfeff?text.slice(1):text;
  for(let i=0;i<str.length;i++){
    const c=str[i];
    if(quoted){
      if(c==='"'&&str[i+1]==='"'){value+='"';i++;continue;}
      if(c==='"'){quoted=false;closing=true;continue;}
      value+=c;continue;
    }
    if(closing&&!["\r","\n",","].includes(c))throw Error("Unexpected characters after quoted field");
    if(c==='"'&&value===""){quoted=true;continue;}
    if(c==='"')throw Error("Unexpected quote in CSV field");
    if(c===","){addCell();continue;}
    if(c==="\r"||c==="\n"){
      addRow();if(c==="\r"&&str[i+1]==="\n")i++;continue;
    }
    value+=c;
  }
  if(quoted)throw Error("Unterminated CSV quoted field");
  if(value!==""||fields.length||closing)addRow();
  if(rows.length<1)throw Error("Empty CSV");
  const headers=rows.shift();
  if(headers.length>100||headers.some(x=>!x.trim()||x.trim()!==x)||new Set(headers).size!==headers.length)throw Error("Missing, duplicated or malformed column headings");
  return rows.map((cells,i)=>{
    if(cells.length!==headers.length)throw Error("CSV width mismatch at row "+(i+2));
    return Object.fromEntries(headers.map((h,j)=>[h,cells[j]]));
  });
}
export function finiteNumber(v){
  if(v===null||v===undefined||String(v).trim()==="")return null;
  const num=Number(v);return Number.isFinite(num)?num:null;
}
function required(rows,cols){
  if(!Array.isArray(rows)||!rows.length)throw Error("CSV requires at least one data record");
  for(const c of cols)if(!(c in rows[0]))throw Error("Required column absent: "+c);
}
export function inspectTracks(rows,gapThreshold=.5){
  required(rows,["session_id","camera_id","track_id","time_s","x","y"]);
  if(!Number.isFinite(gapThreshold)||gapThreshold<=0)throw Error("Positive gap threshold required");
  const groups=new Map(),keys=new Set(),issues=[];let missing=0,dup=0;
  const warn=(row,code,message)=>{if(issues.length<1500)issues.push({row,code,message});};
  rows.forEach((r,i)=>{
    const row=i+2,scope=[r.session_id,r.camera_id,r.track_id];
    if(scope.some(x=>!String(x??"").trim())){warn(row,"EMPTY_SCOPE","A session, camera or track ID is empty");return;}
    const t=finiteNumber(r.time_s);
    if(t===null){warn(row,"INVALID_TIME","Recording time is missing/nonfinite");return;}
    const rawObserved=(r.observed??"TRUE").trim().toUpperCase();
    if(rawObserved!==""&&!["TRUE","FALSE"].includes(rawObserved))warn(row,"BAD_OBSERVED","Observed must be TRUE or FALSE");
    const observed=rawObserved!=="FALSE";
    const x=finiteNumber(r.x),y=finiteNumber(r.y),z=finiteNumber(r.z);
    if(!observed){
      missing++;
      if(x!==null||y!==null||z!==null)warn(row,"MISSING_WITH_POSITION","Unobserved row cannot contain a coordinate");
    }else{
      if(x===null||y===null)warn(row,"INVALID_POSITION","Observed row requires valid x and y");
      if(r.z!==undefined&&String(r.z).trim()!==""&&z===null)warn(row,"INVALID_Z","The optional z must be numeric");
    }
    const key=JSON.stringify([...scope,t]);if(keys.has(key)){dup++;warn(row,"DUPLICATE_SCOPE_TIME","Duplicate session/camera/track/time");}keys.add(key);
    const name=JSON.stringify(scope);
    if(!groups.has(name))groups.set(name,[]);
    groups.get(name).push({row,t,observed,hasXY:x!==null&&y!==null,coords:[x,y,z]});
  });
  let longGaps=0,backwards=0,nonpositive=0,shortGaps=0;
  const trackSummaries=[];
  for(const [key,points] of groups){
    for(let i=1;i<points.length;i++){
      if(points[i].t<points[i-1].t){backwards++;warn(points[i].row,"OUT_OF_ORDER","Input row order has decreasing times within scope");}
    }
    const sorted=[...points].sort((a,b)=>a.t-b.t||a.row-b.row);
    for(let i=1;i<sorted.length;i++){
      const dt=sorted[i].t-sorted[i-1].t;
      if(dt<=0){nonpositive++;continue;}
      if(dt>gapThreshold){longGaps++;warn(sorted[i].row,"LONG_GAP","Interval exceeds chosen threshold: "+dt.toFixed(5)+" s");}
      else shortGaps++;
    }
    trackSummaries.push({scope:JSON.parse(key),rows:points.length,observed:points.filter(p=>p.observed&&p.hasXY).length,first_s:sorted[0].t,last_s:sorted[sorted.length-1].t});
  }
  const stats={rows:rows.length,scopedTracks:groups.size,unobserved:missing,duplicates:dup,longGaps,backwards,nonpositive,positiveIntervals:longGaps+shortGaps};
  return {stats,issues,trackSummaries,gapThreshold,scientific_validation_certified:false};
}
export function normalizeFrameManifest(rows){
  required(rows,["session_id","camera_id","frame_id","time_s","raw_time_s","width_px","height_px"]);
  if(rows.length>50000)throw Error("Frame manifest limited to 50,000 rows");
  const groups=new Map(),seen=new Set(),out=[];
  for(const r of rows){
    if(!String(r.session_id).trim()||!String(r.camera_id).trim())throw Error("Empty frame session or camera ID");
    const frame=finiteNumber(r.frame_id),t=finiteNumber(r.time_s),raw=finiteNumber(r.raw_time_s),w=finiteNumber(r.width_px),h=finiteNumber(r.height_px);
    if(frame===null||frame<0||!Number.isInteger(frame)||t===null||t<0||raw===null||raw<0||w===null||w<=0||h===null||h<=0)throw Error("Invalid source frame or PTS numeric field");
    const key=JSON.stringify([r.session_id,r.camera_id,frame]);if(seen.has(key))throw Error("Duplicated camera frame ID");seen.add(key);
    const x={session_id:r.session_id,camera_id:r.camera_id,frame_id:frame,time_s:t,raw_time_s:raw,width_px:w,height_px:h};
    out.push(x);
    const scope=JSON.stringify([r.session_id,r.camera_id]);if(!groups.has(scope))groups.set(scope,[]);groups.get(scope).push(x);
  }
  for(const frames of groups.values()){
    frames.sort((a,b)=>a.frame_id-b.frame_id);
    for(let k=1;k<frames.length;k++){
      if(frames[k].time_s<=frames[k-1].time_s||frames[k].raw_time_s<=frames[k-1].raw_time_s)throw Error("Camera source PTS/aligned times must increase with frame ID");
    }
  }
  return out.sort((a,b)=>a.time_s-b.time_s||a.camera_id.localeCompare(b.camera_id));
}
export function normalizeLocalTracks(rows,{requireZ=false}={}){
  required(rows,["session_id","camera_id","track_id","time_s","x","y"]);
  if(rows.length>50000)throw Error("Tracks limited to 50,000 rows in viewer");
  const seen=new Set(),out=[];
  for(const r of rows){
    if(!r.session_id?.trim()||!r.camera_id?.trim()||!r.track_id?.trim())throw Error("Empty scoped track identifiers");
    const t=finiteNumber(r.time_s);if(t===null||t<0)throw Error("Invalid track time");
    const raw=(r.observed??"TRUE").trim().toUpperCase(),obs=raw===""||raw==="TRUE";
    if(!["","TRUE","FALSE"].includes(raw))throw Error("Invalid observed value");
    const x=finiteNumber(r.x),y=finiteNumber(r.y),z=finiteNumber(r.z);
    if(obs&&(x===null||y===null||(requireZ&&z===null)))throw Error("Observed track has missing numeric position");
    if(!obs&&(x!==null||y!==null||z!==null))throw Error("Unobserved track has coordinates");
    const key=JSON.stringify([r.session_id,r.camera_id,r.track_id,t]);if(seen.has(key))throw Error("Duplicated scoped track timestamp");seen.add(key);
    out.push({session_id:r.session_id,camera_id:r.camera_id,track_id:r.track_id,time_s:t,x,y,z,observed:obs});
  }
  return out.sort((a,b)=>a.time_s-b.time_s);
}
export function normalizeLocalEvents(rows){
  if(!rows?.length)return [];
  required(rows,["event_id","time_s","event_type"]);
  const seen=new Set();
  return rows.map(r=>{
    const t=finiteNumber(r.time_s);
    if(!r.event_id?.trim()||!r.event_type?.trim()||t===null||seen.has(r.event_id))throw Error("Invalid or duplicate event");
    seen.add(r.event_id);return {event_id:r.event_id,time_s:t,event_type:r.event_type};
  });
}
export function nearestAt(rows,time,tolerance=.05){
  if(!Number.isFinite(time)||!Number.isFinite(tolerance)||tolerance<0)throw Error("Invalid clock/tolerance");
  let best=null,bestGap=Infinity;
  for(const x of rows){
    const delta=Math.abs(x.time_s-time);
    if(delta<bestGap){best=x;bestGap=delta;}
  }
  return best&&bestGap<=tolerance?{...best,alignment_residual_s:bestGap}:null;
}
export function selectScopedFrame(frames,session,camera,time,tolerance=.05){
  return nearestAt(frames.filter(f=>f.session_id===session&&f.camera_id===camera),time,tolerance);
}
export function selectVisibleTracks(tracks,session,camera,time,tolerance=.05){
  const candidates=tracks.filter(x=>x.session_id===session&&x.camera_id===camera&&x.observed);
  const by=new Map();
  for(const t of candidates){
    const delta=Math.abs(t.time_s-time);
    if(delta>tolerance)continue;
    const prev=by.get(t.track_id);
    if(!prev||Math.abs(prev.time_s-time)>delta)by.set(t.track_id,t);
  }
  return [...by.values()];
}
export function framePtsToVideoTime(frames,frame){
  const scoped=frames.filter(x=>x.session_id===frame.session_id&&x.camera_id===frame.camera_id);
  const first=Math.min(...scoped.map(x=>x.raw_time_s));
  const seek=frame.raw_time_s-first;
  if(!Number.isFinite(seek)||seek<0)throw Error("Inconsistent video PTS");
  return seek;
}
