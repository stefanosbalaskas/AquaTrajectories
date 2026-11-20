# Source-locked M08 complete science run (Windows; no model retraining).
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$docs = Join-Path $env:USERPROFILE 'Documents'
$py = Join-Path $docs 'AQT_M06_FISH_ENV\Scripts\python.exe'
$input = Join-Path $docs 'AquaTrajectories_M07_REAL_INPUT'
$report = Join-Path $docs 'AquaTrajectories_M08_REFERENCE_MEASUREMENT'
$rreport = Join-Path $docs 'AquaTrajectories_M08_NATIVE_R_REPORT'
$independent = Join-Path $docs 'AquaTrajectories_M08_INDEPENDENT_SOURCE_AUDIT.json'
if(!(Test-Path $py)) { throw 'Original isolated Python runtime missing' }
if(!(Test-Path (Join-Path $input 'M07_PROVENANCE.json'))) { throw 'Original verified M07 real source missing' }
foreach($output in @($report,$rreport,$independent,(Join-Path $docs 'M08_REAL_R_PYTHON_PARITY.json'),(Join-Path $docs 'M08_R_PYTHON_PARITY_65.csv'))) {
 if(Test-Path $output) { throw "An original output already exists; preserve it, use a new destination: $output" }
}
& $py (Join-Path $repo 'inst\python\aqt_m08_reference_measurement.py') --input $input --out $report
if($LASTEXITCODE -ne 0){ throw 'M08 published-reference measurement computation failed' }
& $py (Join-Path $repo 'inst\python\aqt_m08_independent_oracle.py') --input $input --result $report --out $independent
if($LASTEXITCODE -ne 0){ throw 'M08 independent sparse/source oracle failed' }
Rscript --vanilla (Join-Path $repo 'scripts\m08_real_reference_parity.R') $input $report $rreport
if($LASTEXITCODE -ne 0){ throw 'Native R real-source measurement parity failed' }
Write-Host 'M08_SOURCE_REFERENCE_AND_R_PYTHON_PARITY_PASS' $report $rreport
