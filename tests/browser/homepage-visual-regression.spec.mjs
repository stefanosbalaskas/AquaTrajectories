import {test,expect} from "@playwright/test";

// Regression: the light-theme evidence CTA links were white on white.
// Check actual rendered colors, not just the presence of labels in source HTML.
const contrast=(a,b)=>{
 const rgb=s=>{const x=s.match(/\d+(?:\.\d+)?/g);return x?.slice(0,3).map(Number)||[];};
 const l=c=>{const x=rgb(c).map(v=>v/255).map(v=>v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4);return x.length===3?0.2126*x[0]+0.7152*x[1]+0.0722*x[2]:NaN;};
 const x=l(a),y=l(b);return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05);
};
for(const width of [390,953,1280]){
 test(`homepage: evidence CTA labels, contrast and card headings at ${width}px`,async({page})=>{
  await page.setViewportSize({width,height:900});
  await page.goto("/index.html");
  const result=await page.evaluate(()=>{
   const sections=[...document.querySelectorAll(".aqt-cta")].filter(x=>!x.closest(".aqt-hero"));
   const links=sections.flatMap(section=>[...section.querySelectorAll("a")]).map(el=>{
    const css=getComputedStyle(el),rect=el.getBoundingClientRect();
    return {label:el.textContent.trim(),color:css.color,rect:{left:rect.left,right:rect.right,width:rect.width},minHeight:parseFloat(css.minHeight)};
   });
   const body=getComputedStyle(document.body).backgroundColor;
   const cards=[...document.querySelectorAll(".aqt-cardgrid .aqt-card h3")].slice(0,5).map(el=>{
    const css=getComputedStyle(el);
    return {label:el.textContent.trim(),fontSize:parseFloat(css.fontSize),lineHeight:parseFloat(css.lineHeight),letterSpacing:css.letterSpacing};
   });
   return {links,cards,body};
  });
  expect(result.links.length).toBeGreaterThanOrEqual(3);
  for(const x of result.links){
   expect(x.label.length,"Empty CTA label").toBeGreaterThan(3);
   expect(contrast(x.color,result.body),`Unreadable CTA "${x.label}" against ${result.body}: ${x.color}`).toBeGreaterThanOrEqual(4.5);
   expect(x.rect.left,`CTA left clipping: ${x.label}`).toBeGreaterThanOrEqual(-2);
   expect(x.rect.right,`CTA right clipping: ${x.label}`).toBeLessThanOrEqual(width+2);
   expect(x.minHeight).toBeGreaterThanOrEqual(44);
  }
  expect(result.cards.length).toBe(5);
  for(const x of result.cards){
   expect(x.lineHeight / x.fontSize,`Crowded card heading: ${x.label}`).toBeGreaterThanOrEqual(1.3);
   expect(["normal","0px"].includes(x.letterSpacing),`Condensed card heading: ${x.label}`).toBeTruthy();
  }
 });
}
test("homepage secondary CTA readable in dark theme",async({page})=>{
 await page.goto("/index.html");
 await page.evaluate(()=>{document.documentElement.setAttribute("data-bs-theme","dark");});
 const result=await page.evaluate(()=>{
  const link=[...document.querySelectorAll(".aqt-cta a+a")].find(el=>!el.closest(".aqt-hero"));
  return {label:link?.textContent.trim(),color:link?getComputedStyle(link).color:"",background:getComputedStyle(document.body).backgroundColor};
 });
 expect(result.label).toBeTruthy();
 expect(contrast(result.color,result.background),"Dark mode CTA contrast").toBeGreaterThanOrEqual(4.5);
});
