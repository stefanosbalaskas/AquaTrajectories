// Post-build homepage metadata cleanup; never edits source package metadata.
import fs from "node:fs";
import assert from "node:assert/strict";
const path="site/index.html";
assert.ok(fs.existsSync(path),"Run pkgdown build before metadata cleanup");
let s=fs.readFileSync(path,"utf8");
const desc="AquaTrajectories v0.2.1: 188 R functions, 100% tested-expression coverage, source-preserving aquatic movement analysis and bounded M10 real-data numerical replay.";
const meta=/<meta name="description" content="[^"]*"\s*\/?\s*>/i;
const og=/<meta property="og:description" content="[^"]*"\s*\/?\s*>/i;
assert.ok(meta.test(s)&&og.test(s),"Expected homepage metadata");
s=s.replace(meta,'<meta name="description" content="'+desc+'">');
s=s.replace(og,'<meta property="og:description" content="'+desc+'">');
assert.match(s,/<meta name="viewport"/);
s=s.replace(/<meta name="viewport" content="[^"]*"\s*\/?\s*>/gi,"");
s=s.replace(/<meta charset="UTF-8">/i,m=>m+'<meta name="viewport" content="width=device-width, initial-scale=1">');
assert.equal((s.match(/name="viewport"/g)||[]).length,1);
fs.writeFileSync(path,s);
console.log("AQT_METADATA_PASS");
