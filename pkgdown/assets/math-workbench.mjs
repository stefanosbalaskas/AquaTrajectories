import {stepKinematics,polarization,clockTransform} from "./scientific-teaching-core.mjs";
const $=id=>document.getElementById(id),NS="http://www.w3.org/2000/svg";
function el(tag,props,text){const e=document.createElementNS(NS,tag);for(const [k,v] of Object.entries(props))e.setAttribute(k,String(v));if(text!==undefined)e.textContent=text;return e;}
const ids=["dx","dy","dt","spread","clockTime","offset","drift"];
function render(){
  for(const id of ids)$(id+"Out").textContent=$(id).value;
  const dx=+$("dx").value,dy=+$("dy").value,dt=+$("dt").value;
  const k=stepKinematics(dx,dy,dt);
  $("speedReadout").textContent="Displacement = "+k.distance.toFixed(2)+" cm; vx = "+k.vx.toFixed(2)+" cm/s; vy = "+k.vy.toFixed(2)+" cm/s; speed = "+k.speed.toFixed(2)+" cm/s.";
  const g=$("vectorItems");g.replaceChildren();
  const cx=230,cy=170,scale=7;
  for(let t=-20;t<=20;t+=5){
    g.append(el("line",{x1:cx-20*scale,y1:cy-t*scale,x2:cx+20*scale,y2:cy-t*scale,stroke:"#24526c","stroke-width":1}));
    g.append(el("line",{x1:cx+t*scale,y1:cy-20*scale,x2:cx+t*scale,y2:cy+20*scale,stroke:"#24526c","stroke-width":1}));
  }
  g.append(el("line",{x1:cx-150,y1:cy,x2:cx+150,y2:cy,stroke:"#abcbd4","stroke-width":2}));
  g.append(el("line",{x1:cx,y1:cy+150,x2:cx,y2:cy-150,stroke:"#abcbd4","stroke-width":2}));
  g.append(el("line",{x1:cx,y1:cy,x2:cx+dx*scale,y2:cy-dy*scale,stroke:"#f9bb67","stroke-width":4,"stroke-linecap":"round"}));
  g.append(el("circle",{cx:cx+dx*scale,cy:cy-dy*scale,r:6,fill:"#f9bb67"}));
  g.append(el("text",{x:cx+dx*scale+8,y:cy-dy*scale-7,fill:"#fff","font-size":13},"p₂"));
  g.append(el("text",{x:cx+6,y:cy+17,fill:"#fff","font-size":13},"p₁"));
  const spread=+$("spread").value,ang=[-spread,-spread/2,0,spread/2,spread];
  const p=polarization(ang);
  $("polarizationReadout").textContent="P = "+p.value.toFixed(3)+"; resultant unit-heading mean = ("+p.x.toFixed(3)+", "+p.y.toFixed(3)+").";
  const school=$("schoolItems");school.replaceChildren();
  const sx=155,sy=170,colors=["#88e0e7","#b5cfed","#ffcb72","#b5cfed","#88e0e7"];
  for(let i=0;i<ang.length;i++){
    const rad=ang[i]*Math.PI/180;
    school.append(el("line",{x1:sx,y1:sy,x2:sx+90*Math.cos(rad),y2:sy-90*Math.sin(rad),stroke:colors[i],"stroke-width":3,"stroke-linecap":"round"}));
    school.append(el("circle",{cx:sx+90*Math.cos(rad),cy:sy-90*Math.sin(rad),r:4,fill:colors[i]}));
  }
  school.append(el("line",{x1:sx,y1:sy,x2:sx+145*p.x,y2:sy-145*p.y,stroke:"#ff8384","stroke-width":6}));
  school.append(el("circle",{cx:sx,cy:sy,r:4,fill:"#fff"}));
  school.append(el("text",{x:15,y:25,fill:"#d8f2f5","font-size":15},"Red = mean heading vector"));
  const time=+$("clockTime").value,a=+$("offset").value,d=+$("drift").value;
  const mapped=clockTransform(time,a,d);
  $("clockReadout").textContent="Camera time "+time.toFixed(1)+" s → reference time "+mapped.toFixed(4)+" s; offset from camera time = "+(mapped-time).toFixed(4)+" s.";
}
ids.forEach(id=>$(id).addEventListener("input",render));render();
