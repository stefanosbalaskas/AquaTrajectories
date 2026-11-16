import {buildProtocol} from "./scientific-teaching-core.mjs";
const $=id=>document.getElementById(id);
const fields=["study","cameras","tanks","fish","sessions","minutes","fps"];
const defaults={study:"AQT-SYNTHETIC-PLAN",cameras:2,tanks:4,fish:5,sessions:3,minutes:20,fps:30};
let current;
function build(){
  const options={};
  for(const key of fields){
    options[key]=key==="study"?$(key).value:+$(key).value;
    const out=$(key+"Out");if(out)out.textContent=$(key).value;
  }
  current=buildProtocol(options);
  $("protocolStats").textContent=current.rows+" planned tank–session–camera records; "+
    current.options.tanks+" independent tanks; "+current.options.cameras+" camera(s)/tank.";
  $("preview").textContent=current.markdown;
}
function download(filename,text,type){
  const blob=new Blob([text],{type}),url=URL.createObjectURL(blob),a=document.createElement("a");
  a.href=url;a.download=filename;document.body.append(a);a.click();a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
}
fields.forEach(id=>$(id).addEventListener("input",build));
$("reset").addEventListener("click",()=>{for(const [k,v] of Object.entries(defaults))$(k).value=String(v);build();});
$("downloadMd").addEventListener("click",()=>download(current.study+"-protocol.md",current.markdown,"text/markdown;charset=utf-8"));
$("downloadCsv").addEventListener("click",()=>download(current.study+"-session-manifest.csv",current.manifest,"text/csv;charset=utf-8"));
build();
