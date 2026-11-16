/** AquaTrajectories Phase 3: exact synthetic planar-interface ray geometry.
 * Above-water cameras through ONE flat air/water interface at z=0;
 * this is NOT the underwater flat-port housing or calibrated v0.1.1 model.
 * All positions cm; refractive indices are unitless.
 */
const vec=(x,y,z)=>[x,y,z];
const add=(a,b)=>a.map((x,i)=>x+b[i]);
const sub=(a,b)=>a.map((x,i)=>x-b[i]);
const scale=(a,s)=>a.map(x=>x*s);
const dot=(a,b)=>a.reduce((s,x,i)=>s+x*b[i],0);
const norm=a=>Math.hypot(...a);
const unit=a=>scale(a,1/norm(a));
export const distance=(a,b)=>norm(sub(a,b));
export function interfacePoint(camera,fish,nWater=1.333){
  if(camera[2]<=0||fish[2]>=0||!(nWater>=1&&nWater<=2))throw Error("Camera must lie above, fish below, with valid water index");
  const u=sub(fish,camera),r=Math.hypot(u[0],u[1]);
  if(r<1e-12)return vec(camera[0],camera[1],0);
  const heightAir=camera[2],heightWater=-fish[2];
  let lo=0,hi=1;
  for(let i=0;i<90;i++){
    const mid=(lo+hi)/2,a=r*mid,b=r*(1-mid);
    const left=a/Math.hypot(heightAir,a);
    const right=nWater*b/Math.hypot(heightWater,b);
    if(left>right)hi=mid;else lo=mid;
  }
  const frac=(lo+hi)/2;
  return vec(camera[0]+u[0]*frac,camera[1]+u[1]*frac,0);
}
export function apparentAirRay(camera,fish,nWater=1.333){
  const p=interfacePoint(camera,fish,nWater);
  return {camera,interfacePoint:p,direction:unit(sub(p,camera))};
}
export function refractedRay(camera,incidentDirection,nWater=1.333){
  if(!(nWater>=1&&nWater<=2))throw Error("Valid water index required");
  const d=unit(incidentDirection);
  if(d[2]>=-1e-9)throw Error("Ray does not intersect the water surface");
  const t=-camera[2]/d[2];
  if(t<0)throw Error("Surface intersection is behind camera");
  const origin=add(camera,scale(d,t));
  const ratio=1/nWater,dx=d[0]*ratio,dy=d[1]*ratio;
  const horizontal=dx*dx+dy*dy;
  if(horizontal>=1)throw Error("Invalid transmitted ray");
  return {origin,direction:vec(dx,dy,-Math.sqrt(1-horizontal)),incidentDirection:d};
}
export function closestRayPair(a,b){
  const u=a.direction,v=b.direction,w=sub(a.origin,b.origin);
  const aa=dot(u,u),bb=dot(u,v),cc=dot(v,v),dd=dot(u,w),ee=dot(v,w);
  const denominator=aa*cc-bb*bb;
  if(denominator<1e-8)return {valid:false,reason:"Nearly parallel refracted rays",denominator};
  const t=(bb*ee-cc*dd)/denominator;
  const s=(aa*ee-bb*dd)/denominator;
  if(t<0||s<0)return {valid:false,reason:"Closest point lies behind an interface",denominator,t,s};
  const p=add(a.origin,scale(u,t)),q=add(b.origin,scale(v,s));
  return {valid:true,midpoint:scale(add(p,q),.5),pointA:p,pointB:q,rayGap:distance(p,q),denominator,t,s};
}
function clamp(x,min,max){return Math.min(max,Math.max(min,Number(x)));}
export function reconstructScenario(options={}){
  const baseline=clamp(options.baseline??50,4,180);
  const height=clamp(options.height??22,3,150);
  const depth=clamp(options.depth??28,1,150);
  const x=clamp(options.fishX??6,-50,50),y=clamp(options.fishY??4,-50,50);
  const nWater=clamp(options.nWater??1.333,1,1.6);
  const focalPx=clamp(options.focalPx??1000,200,5000);
  const noisePx=clamp(options.noisePx??0,0,20);
  const camera1=[-baseline/2,0,height],camera2=[baseline/2,0,height],truth=[x,y,-depth];
  const a=apparentAirRay(camera1,truth,nWater),b=apparentAirRay(camera2,truth,nWater);
  // Fixed signed angular perturbations; no stochastic claims.
  const perturb=(d,s)=>unit(add(d,[s*noisePx/focalPx,-.7*s*noisePx/focalPx,0]));
  const ray1=refractedRay(camera1,perturb(a.direction,1),nWater);
  const ray2=refractedRay(camera2,perturb(b.direction,-1),nWater);
  const result=closestRayPair(ray1,ray2);
  return {camera1,camera2,truth,interfaceA:a.interfacePoint,interfaceB:b.interfacePoint,
    ray1,ray2,result,nWater,noisePx,baseline,depth,height,
    reconstructedError:result.valid?distance(result.midpoint,truth):null};
}
export function project3D(point,yawDeg=25,pitchDeg=20,centre=[0,0,0],scalePx=4.5,offset=[460,310]){
  const yaw=yawDeg*Math.PI/180,pitch=pitchDeg*Math.PI/180,p=sub(point,centre);
  const x=Math.cos(yaw)*p[0]-Math.sin(yaw)*p[1];
  const y=Math.sin(yaw)*p[0]+Math.cos(yaw)*p[1];
  const depth=Math.cos(pitch)*y-Math.sin(pitch)*p[2];
  const height=Math.sin(pitch)*y+Math.cos(pitch)*p[2];
  return {x:offset[0]+x*scalePx,y:offset[1]-height*scalePx,depth};
}
export function makeSyntheticMultiview(options={}){
  const frames=+(options.frames??100),fishCount=+(options.fish??5);
  if(!Number.isInteger(frames)||frames<3||frames>500||!Number.isInteger(fishCount)||fishCount<1||fishCount>20)throw Error("Synthetic scene bounds");
  const out={frames:[],tracks2d:[],tracks3d:[],events:[{event_id:"E01",time_s:frames/40,event_type:"illustrative intervention marker"}]};
  for(let k=0;k<frames;k++){
    const t=k/20;
    for(const camera of ["CAM1","CAM2"]){
      const raw=t+(camera==="CAM2"?.035:0);
      out.frames.push({session_id:"SYNTH",camera_id:camera,frame_id:k,time_s:t,raw_time_s:raw,width_px:800,height_px:450});
      for(let id=1;id<=fishCount;id++){
        if((k+id*5)%31===0)continue;
        const x=400+220*Math.sin(.06*k+id*1.3)+(camera==="CAM2"?14:-14);
        const y=215+100*Math.cos(.035*k+id*.9)+(camera==="CAM2"?5:-5);
        out.tracks2d.push({session_id:"SYNTH",camera_id:camera,track_id:"fish"+id,time_s:t,x,y,observed:true});
      }
    }
    for(let id=1;id<=fishCount;id++){
      out.tracks3d.push({session_id:"SYNTH",camera_id:"SYNTHETIC_XYZ",track_id:"fish"+id,
        time_s:t,x:8*Math.sin(.04*k+id),y:7*Math.cos(.036*k+id),z:-10-3*Math.sin(.03*k+id),observed:true});
    }
  }
  return out;
}
