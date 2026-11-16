// Browser -> published AquaTrajectories v0.1.1 numerical cross-language fixtures.
// Deliberately no R implementation copied into JavaScript test oracle.
import fs from "node:fs";
import path from "node:path";
import {reconstructScenario} from "../pkgdown/assets/research-geometry-core.mjs";
import {stepKinematics,polarization} from "../pkgdown/assets/scientific-teaching-core.mjs";
const directory=process.argv[2]||"site-qualification/parity";
fs.mkdirSync(directory,{recursive:true});
const csv=(filename,columns,items)=>{
 const rows=[columns.join(",")];
 for(const x of items)rows.push(columns.map(k=>{
  const v=x[k];if(typeof v==="number"&&!Number.isFinite(v))throw Error("Invalid fixture number "+k);
  return typeof v==="number"?v.toPrecision(17):String(v??"");
 }).join(","));
 fs.writeFileSync(path.join(directory,filename),rows.join("\n")+"\n");
};
const geometric=[
 {baseline:40,height:20,depth:30,fishX:0,fishY:0,nWater:1.333,focalPx:900,noisePx:0},
 {baseline:60,height:25,depth:20,fishX:5,fishY:3,nWater:1.333,focalPx:1000,noisePx:0},
 {baseline:80,height:16,depth:40,fishX:-11,fishY:7,nWater:1.34,focalPx:1250,noisePx:.2},
 {baseline:45,height:32,depth:35,fishX:8,fishY:-12,nWater:1.28,focalPx:800,noisePx:.5},
 {baseline:100,height:48,depth:55,fishX:-6,fishY:5,nWater:1.4,focalPx:1400,noisePx:1}
].map((o,i)=>{
 const r=reconstructScenario(o);
 if(!r.result.valid)throw Error("Fixture requires admissible rays: "+i);
 const a=r.ray1.incidentDirection,b=r.ray2.incidentDirection;
 return {id:"g"+(i+1),...o,inc1x:a[0],inc1y:a[1],inc1z:a[2],inc2x:b[0],inc2y:b[1],inc2z:b[2],
  expectedX:r.result.midpoint[0],expectedY:r.result.midpoint[1],expectedZ:r.result.midpoint[2],expectedGap:r.result.rayGap};
});
csv("geometry.csv",Object.keys(geometric[0]),geometric);
const speed=[
 [3,4,2],[-8,6,.25],[0,2,1.5],[5,-12,.4],[0,0,.1]
].map(([dx,dy,dt],i)=>({id:"v"+i,dx,dy,dt,...stepKinematics(dx,dy,dt)}));
csv("kinematics.csv",Object.keys(speed[0]),speed);
const angles=[[0,0],[0,180],[12,23,34,45],[-40,-20,0,20,40]];
const pol=angles.map((a,i)=>({id:"p"+i,n:a.length,a1:a[0],a2:a[1],a3:a[2]??"",a4:a[3]??"",a5:a[4]??"",expected:polarization(a).value}));
csv("polarization.csv",Object.keys(pol[0]),pol);
console.log("AQT_PARITY_FIXTURES_PASS: five R/JS refractive scenarios, five kinematics, four group polarization cases");
