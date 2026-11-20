# AquaTrajectories Milestone 07: real video reference vs real model outputs.
# No inference/training, no video extraction, no fabricated frame times.
# All newly generated folders must be absent to protect existing evidence.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$documents = Join-Path $env:USERPROFILE 'Documents'
$py = Join-Path $documents 'AQT_M06_FISH_ENV\Scripts\python.exe'
$holdout = Join-Path $documents 'AquaTrajectories_M06_BRACKISH_FROZEN_TEST_V2'
$model = Join-Path $documents 'AquaTrajectories_M06_BRACKISH_MODEL_RUN_V4_CLEAN'
$input = Join-Path $documents 'AquaTrajectories_M07_REAL_INPUT'
$rOutput = Join-Path $documents 'AquaTrajectories_M07_NATIVE_R_REPORT'
$pyOutput = Join-Path $documents 'AquaTrajectories_M07_PYTHON_ORACLE_REPORT'
$parity = Join-Path $documents 'AquaTrajectories_M07_R_PYTHON_PARITY.json'
foreach ($p in @($py, (Join-Path $holdout 'FROZEN_BENCHMARK_PROTOCOL.json'),
  (Join-Path $model 'PREDICTION_PROVENANCE.json'))) {
  if (!(Test-Path -LiteralPath $p)) { throw "Missing required frozen evidence: $p" }
}
foreach ($p in @($input,$rOutput,$pyOutput,$parity)) {
  if (Test-Path -LiteralPath $p) {
    throw "Destination already exists; preserve previous evidence and select a new run: $p"
  }
}
$RScript = Get-Command 'Rscript.exe' -ErrorAction SilentlyContinue
if ($RScript) { $rbin = $RScript.Source }
else {
  $rCandidate = Get-ChildItem 'C:\Program Files\R' -Filter 'Rscript.exe' -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1
  if (!$rCandidate) {throw 'Rscript.exe was not found; install R or invoke run_m07_native.R manually from RStudio.'}
  $rbin = $rCandidate.FullName
}
Write-Host 'M07 SOURCE INTAKE: verifying all original 906 frozen files and V4 prediction digests'
& $py (Join-Path $root 'inst\python\aqt_m07_brackish_dual_path.py') `
  --holdout $holdout --model-run $model --out $input
if ($LASTEXITCODE -ne 0) {throw 'M07 source proof failed'}
Write-Host 'M07 NATIVE R: real data descriptive scientific analysis and vector-figure publication'
& $rbin --vanilla (Join-Path $root 'run_m07_native.R') $root $input $rOutput
if ($LASTEXITCODE -ne 0) {throw 'M07 native R analysis failed; preserve full console log'}
Write-Host 'M07 INDEPENDENT PYTHON NUMERICAL ORACLE (separate output, no R results used)'
& $py (Join-Path $root 'inst\python\aqt_m07_independent_frame_oracle.py') `
  --input $input --out $pyOutput
if ($LASTEXITCODE -ne 0) {throw 'M07 independent Python oracle failed'}
Write-Host 'M07 INDEPENDENT R/PYTHON DATASET MATH PARITY'
& $py (Join-Path $root 'inst\python\aqt_m07_cross_language_parity.py') `
  --r-report $rOutput --python-report $pyOutput --out $parity
if ($LASTEXITCODE -ne 0) {throw 'M07 cross-language scientific parity failed'}
Write-Host 'M07 REAL FISH END-TO-END COMPLETE. REPORT:' (Join-Path $rOutput 'REPORT.html')
Write-Host 'PARITY:' $parity
