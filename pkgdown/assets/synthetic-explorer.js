
"use strict";
(function () {
  const svgNS = "http://www.w3.org/2000/svg";
  const palette = ["#65d8e0", "#f0c575", "#b1baf1", "#80dea0", "#f0a6bd"];
  const count = 5, totalFrames = 300;
  const tracks = Array.from({length:count}, function (_, i) {
    return Array.from({length:totalFrames+1}, function (_, t) {
      const p = t / 28;
      return {
        x: 0.5 + 0.19*Math.sin(p*0.73 + i*1.42) + 0.07*Math.sin(p*1.8 + i*0.8),
        y: 0.5 + 0.21*Math.cos(p*0.57 + i*1.31) + 0.05*Math.sin(p*2.25 + i*0.5),
        z: 0.5 + 0.23*Math.sin(p*0.41 + i*1.74) + 0.05*Math.cos(p*1.48 + i*1.2)
      };
    });
  });
  const $ = function (id) {return document.getElementById(id);};
  const grid = $("grid"), paths = $("paths"), heads = $("heads");
  const frameSlider = $("frame"), trailSlider = $("trail"), playButton = $("play");
  let frame = 0, projection = "iso", trail = 60, playing = false, last = 0;
  const visible = new Array(count).fill(true);
  const pathNodes = [], headNodes = [], labels = [];
  function create(name, parent, attrs) {
    const el = document.createElementNS(svgNS, name);
    Object.keys(attrs || {}).forEach(function (k) {el.setAttribute(k,attrs[k]);});
    parent.appendChild(el);
    return el;
  }
  function point(p) {
    if (projection === "xy") return [120 + 715*p.x, 470 - 360*p.y];
    if (projection === "xz") return [120 + 715*p.x, 470 - 360*p.z];
    if (projection === "yz") return [120 + 715*p.y, 470 - 360*p.z];
    const x = (p.x - .5)*2, y = (p.y - .5)*2, z = (p.z - .5)*2;
    return [472 + x*260 - y*153, 282 + x*71 + y*111 - z*175];
  }
  function drawLine(a,b,color,width,alpha,dash) {
    const pa=point(a),pb=point(b);
    return create("line",grid,{x1:pa[0],y1:pa[1],x2:pb[0],y2:pb[1],
      stroke:color,"stroke-width":width,opacity:alpha||1,
      "stroke-dasharray":dash||"none"});
  }
  function renderGrid() {
    grid.replaceChildren();
    if (projection==="iso") {
      const corners=[];
      for(let x=0;x<=1;x++)for(let y=0;y<=1;y++)for(let z=0;z<=1;z++)corners.push({x,y,z});
      corners.forEach(function(a){
        corners.forEach(function(b){
          const dif=Number(a.x!==b.x)+Number(a.y!==b.y)+Number(a.z!==b.z);
          if(dif===1 && (a.x*4+a.y*2+a.z)<(b.x*4+b.y*2+b.z))
            drawLine(a,b,"#5a8298",2,.65);
        });
      });
      drawLine({x:0,y:0,z:0},{x:1,y:0,z:0},"#61d9e0",4,1);
      drawLine({x:0,y:0,z:0},{x:0,y:1,z:0},"#f1cb7a",4,1);
      drawLine({x:0,y:0,z:0},{x:0,y:0,z:1},"#b9baff",4,1);
    } else {
      const a = {x:0,y:0,z:0},b={x:1,y:1,z:1},top=point({x:0,y:1,z:1}),left=point(a),right=point(b);
      create("rect",grid,{x:120,y:110,width:715,height:360,fill:"none",stroke:"#5a8298","stroke-width":2});
      for(let i=1;i<5;i++){
        const xx=120+715*i/5,yy=110+360*i/5;
        create("line",grid,{x1:xx,y1:110,x2:xx,y2:470,stroke:"#30516b"});
        create("line",grid,{x1:120,y1:yy,x2:835,y2:yy,stroke:"#30516b"});
      }
    }
  }
  function render() {
    renderGrid();
    for(let i=0;i<count;i++) {
      const pts=[],begin=Math.max(0,frame-trail);
      for(let t=begin;t<=frame;t++) {
        const p=point(tracks[i][t]); pts.push(p[0].toFixed(2)+","+p[1].toFixed(2));
      }
      pathNodes[i].setAttribute("points",pts.join(" "));
      const p=point(tracks[i][frame]);
      headNodes[i].setAttribute("cx",p[0]);headNodes[i].setAttribute("cy",p[1]);
      labels[i].setAttribute("x",p[0]+13);labels[i].setAttribute("y",p[1]-10);
      const show=visible[i]?"":"none";
      pathNodes[i].style.display=show;headNodes[i].style.display=show;labels[i].style.display=show;
    }
    frameSlider.value=frame;
    $("frameValue").textContent=(frame/30).toFixed(1)+" s / 10.0 s";
    $("trailValue").textContent=String(trail);
    $("status").textContent=(playing?"Playing":"Paused")+" · frame "+frame;
    const titles={iso:"Isometric 3D projection",xy:"Top view · XY",xz:"Side view · XZ",yz:"Front view · YZ"};
    $("viewTitle").textContent=titles[projection];
    playButton.textContent=playing?"Ⅱ Pause":"▶ Play";
  }
  function animate(now) {
    if(!playing)return;
    if(!last)last=now;
    const steps=Math.floor((now-last)/(1000/30));
    if(steps>=1) {
      frame=(frame+steps)%(totalFrames+1);
      last=now;
      render();
    }
    requestAnimationFrame(animate);
  }
  for(let i=0;i<count;i++) {
    const color=palette[i];
    pathNodes.push(create("polyline",paths,{fill:"none",stroke:color,
      "stroke-width":4,"stroke-linejoin":"round","stroke-linecap":"round",opacity:.85}));
    headNodes.push(create("circle",heads,{r:9,fill:color,stroke:"#edfaff","stroke-width":2}));
    labels.push(create("text",heads,{fill:color,"font-family":"Arial, sans-serif",
      "font-size":16,"font-weight":700}));
    labels[i].textContent="F"+(i+1);
    const filter=document.createElement("label");
    const name=document.createElement("span");
    const check=document.createElement("input");
    check.type="checkbox";check.checked=true;check.setAttribute("aria-label","Show fish "+(i+1));
    check.addEventListener("change",function(){visible[i]=check.checked;render();});
    const dot=document.createElement("i");dot.className="dot";dot.style.backgroundColor=color;
    name.append(check,dot,document.createTextNode("Synthetic fish "+(i+1)));
    filter.append(name);
    $("fishfilters").appendChild(filter);
    const legend=document.createElement("span"),circle=document.createElement("i");
    circle.style.backgroundColor=color;legend.append(circle,document.createTextNode("F"+(i+1)));
    $("legend").appendChild(legend);
  }
  document.querySelectorAll('input[name="view"]').forEach(function(radio) {
    radio.addEventListener("change",function(){if(radio.checked){projection=radio.value;render();}});
  });
  frameSlider.addEventListener("input",function(){frame=Number(frameSlider.value);render();});
  trailSlider.addEventListener("input",function(){trail=Number(trailSlider.value);render();});
  playButton.addEventListener("click",function(){
    playing=!playing;last=0;render();if(playing)requestAnimationFrame(animate);
  });
  $("reset").addEventListener("click",function(){playing=false;frame=0;last=0;render();});
  render();
}());
