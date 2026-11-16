import {reconstructScenario,project3D} from "./research-geometry-core.mjs";
const $=id=>document.getElementById(id),NS="http://www.w3.org/2000/svg";
const ids=["baseline","height","depth","fishX","fishY","nWater","noisePx","focalPx","yaw","pitch"];
const defaultValues={baseline:55,height:22,depth:27,fishX:5,fishY:6,nWater:1.333,noisePx:1,focalPx:1000,yaw:30,pitch:25};
const svgEl=(tag,attrs={},str)=>{const el=document.createElementNS(NS,tag);for(const [k,v] of Object.entries(attrs))el.setAttribute(k,String(v));if(str!==undefined)el.textContent=String(str);return el;};
const rgb={a:"#78e3ea",b:"#ffc681",water:"#37779c",truth:"#87e8a9",prediction:"#ff8e9c",axes:"#8caabb"};
function line(group,p,q,color,thickness=2,dash=null){const a=project3D(p,+$("yaw").value,+$("pitch").value,[0,0,-10],5.3,[500,320]),b=project3D(q,+$("yaw").value,+$("pitch").value,[0,0,-10],5.3,[500,320]);group.append(svgEl("line",{x1:a.x,y1:a.y,x2:b.x,y2:b.y,stroke:color,"stroke-width":thickness,...(dash?{"stroke-dasharray":dash}:{})}));}
function point(group,p,color,label,r=6){const q=project3D(p,+$("yaw").value,+$("pitch").value,[0,0,-10],5.3,[500,320]);group.append(svgEl("circle",{cx:q.x,cy:q.y,r,fill:color,stroke:"#e9faff","stroke-width":1}));group.append(svgEl("text",{x:q.x+11,y:q.y-8,fill:"#e4f4f8","font-size":13},label));}
function draw(){
  for(const id of ids)$(id+"Out").textContent=$(id).value;
  const o=Object.fromEntries(ids.map(id=>[id,+$(id).value]));
  const root=$("geometryItems");root.replaceChildren();
  const corners=[[-75,-55,0],[75,-55,0],[75,55,0],[-75,55,0]];
  for(let i=0;i<4;i++){line(root,corners[i],corners[(i+1)%4],rgb.water,1.5);}
  line(root,[0,0,0],[0,0,43],rgb.axes,1.4,"6 5");
  line(root,[0,0,0],[0,0,-80],rgb.axes,1.4,"6 5");
  root.append(svgEl("text",{x:28,y:35,fill:"#9fdde8","font-size":16},"ONE PLANAR AIR–WATER SURFACE · SYNTHETIC"));
  root.append(svgEl("text",{x:28,y:57,fill:"#b9d0da","font-size":13},"Two above-surface pinhole cameras; no flat-port housing"));
  try{
    const m=reconstructScenario(o),a=m.camera1,b=m.camera2,t=m.truth;
    line(root,a,m.interfaceA,rgb.a,3);line(root,b,m.interfaceB,rgb.b,3);
    const reach=ray=>[0,1,2].map(i=>ray.origin[i]+130*ray.direction[i]);
    line(root,m.ray1.origin,reach(m.ray1),rgb.a,2,"7 4");line(root,m.ray2.origin,reach(m.ray2),rgb.b,2,"7 4");
    line(root,m.interfaceA,t,rgb.a,1,"2 5");line(root,m.interfaceB,t,rgb.b,1,"2 5");
    point(root,a,rgb.a,"Camera A",7);point(root,b,rgb.b,"Camera B",7);
    point(root,m.interfaceA,rgb.a,"Interface A",4);point(root,m.interfaceB,rgb.b,"Interface B",4);
    point(root,t,rgb.truth,"Synthetic truth",8);
    if(m.result.valid){
      const p=m.result.midpoint;point(root,p,rgb.prediction,"Estimated XYZ",6);line(root,m.result.pointA,m.result.pointB,rgb.prediction,4);
      $("pointReadout").textContent=p.map(x=>x.toFixed(2)).join(", ");
      $("gapReadout").textContent=m.result.rayGap.toFixed(4);
      $("errorReadout").textContent=m.reconstructedError.toFixed(4);
      $("validReadout").textContent="Admissible";
      $("geometryStatus").textContent="Valid closest-ray solution under the stated single-interface assumptions. The error is only simulated reconstruction error against known synthetic truth.";
    }else{
      $("pointReadout").textContent="Abstained";$("gapReadout").textContent="—";$("errorReadout").textContent="—";$("validReadout").textContent="Invalid";
      $("geometryStatus").textContent="Reconstruction abstention: "+m.result.reason+". No XYZ coordinate has been manufactured.";
    }
  }catch(e){
    $("pointReadout").textContent="—";$("gapReadout").textContent="—";$("errorReadout").textContent="—";$("validReadout").textContent="Error";
    $("geometryStatus").textContent="Geometry could not be evaluated: "+String(e.message);
  }
}
ids.forEach(id=>$(id).addEventListener("input",draw));
$("reset").addEventListener("click",()=>{for(const [k,v] of Object.entries(defaultValues))$(k).value=String(v);draw();});
draw();
