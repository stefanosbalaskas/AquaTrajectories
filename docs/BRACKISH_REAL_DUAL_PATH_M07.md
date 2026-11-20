# Milestone 07 — Real BrackishMOT dual-path scientific demonstration

## Motivation and truth hierarchy

Milestone 06 generated frozen real fish detections and ByteTrack output on five
BrackishMOT *test* sequences. The recorded external model shows very low fish
recall and identity tracking performance. That does **not** invalidate the
native AquaTrajectories scientific estimators when supplied with reliable
external trajectories. Milestone 07 therefore uses a **controlled dual-path
comparison of the same original footage**:

1. **Published reference**: the original publisher's fish boxes and persistent
   source identities. These are real published labels, **not independent blinded
   human re-adjudication** of biological identity.
2. **Real model**: genuine frozen NMFS-OSI fish YOLO11n predictions associated
   by genuine ByteTrack, with the source GT withheld during inference.

This is a descriptive software and source-quality case study, not a feeding,
stress, welfare, randomized aquaculture intervention, or biological animal
identity certification. Detector accuracy belongs to the separately audited
M06 model-scoring results; M07 does not recompute metrics using oracle boxes.

### Time and spatial qualification

BrackishMOT source frames here lack **measured image presentation/exposure
timestamps**. The publisher provides nominal `seqinfo.ini` frame rate, which
is not independent evidence of camera exposure time. A physically meaningful
speed (px/s or cm/s), acceleration, feeding time, or time-weighted model would
be fabricated if we divided frame numbers by 15.

The M07 workflow therefore deliberately works **in frame-index space**:

- Image-space XY and 2D occupancy are in pixels and normalized image fractions.
- A step is computed **only when the same camera-local ID appears in two
  consecutive recorded frames**. Its magnitude is px/adjacent-frame step,
  not px/s. Gaps remain missing and do not create long jumps.
- Group geometry and nearest-neighbour distances require simultaneously
  observed fish within the **same source and sequence**.
- Published reference and model IDs never match by mere numeric equality.
- Empty frames remain present in frame coverage. A false-positive detection
  can *increase* coverage; coverage is not recall.
- Event alignment, HMM duration inference, physical 3D, calibrated noise,
  treatment effects, welfare and causality remain blocked.

## Frozen real evidence, source restrictions

Original published BrackishMOT test clips: `23`, `55`, `74`, `93`, `98`.
Total 868 original frames; 6,621 source fish boxes; 645 reference non-fish
boxes; 2,830 actual ByteTrack fish-track rows. The five-clip subset was
selected prior to viewing this model's outputs, is not random, and contains
only published fish identity annotations (not reverified biological IDs).

The original frozen source ZIP, full images, publisher source annotations,
external YOLO weights and private local real inference outputs are **not
committed to the GitHub repository**. Users must provide the actual independently
verified sources. This repository supplies reproducible adapters and synthetic
CI tests, not a disguised copy of source data.

## Full local real-data execution

Given the prior M06 directory layout:

```powershell
$dl = "$env:USERPROFILE\Downloads"
$root = "$env:USERPROFILE\Documents"
$py = "$root\AQT_M06_FISH_ENV\Scripts\python.exe"
$repo = "$root\AquaTrajectories" # local clone of this repository
$holdout = "$root\AquaTrajectories_M06_BRACKISH_FROZEN_TEST_V2"
$model = "$root\AquaTrajectories_M06_BRACKISH_MODEL_RUN_V4_CLEAN"
$input = "$root\AquaTrajectories_M07_REAL_INPUT"
$output = "$root\AquaTrajectories_M07_R_SCIENCE"

& $py "$repo\inst\python\aqt_m07_brackish_dual_path.py" `
  --holdout $holdout --model-run $model --out $input

# R is required for native scientific analysis and publication graphics.
Rscript --vanilla "$repo\tests\integration\brackish_real_dual_path_m07.R" `
  $input $output
```

Run the source-pinned independent Python oracle/report for cross-language
comparison (in a new directory, not over the native R publication):

```powershell
& $py "$repo\inst\python\aqt_m07_independent_frame_oracle.py" `
  --input $input --out "$root\AquaTrajectories_M07_INDEPENDENT_ORACLE"
```

To use an installed package before the PR is merged, source only the new
`R/frame-index-research.R` into the current R session and call the two
functions manually. The integration R script above requires the repository
package to have been installed with the new functions included.

## Output contract

`aqt_frame_index_analyze()` returns unchanged original frames and observations,
frame coverage including zero-observation frames, individual adjacent-frame
XY displacement, missing-interval flags, group/nearest-neighbour geometry,
8×8 source-separated occupancy and full-denominator descriptive summaries.

`aqt_frame_index_publish()` exports CSV, RDS, 20 paired figure families
as both vector PDF/SVG and PNG, HTML with embedded SVG and Markdown with
identical scientific claims. The generated SHA-256 inventory names all
report outputs. A new destination is compulsory and prior artifacts are
never overwritten. The independent Python numerical oracle produces the
same primary metric definitions for numerical parity review.

### Empirical findings are conditional on observation quality

The real external model has far fewer reference-matched fish tracks and
may show *more frames containing predictions* than the reference, because
false positive fish detections exist. Even when a path summary from the
predicted tracks is numerically precise, it is not evidence of the movement
of biologically verified fish. Model-tracking errors and incomplete reference
labels limit the interpretation; this workflow is a demonstration of how
software makes those limitations visible.

## Independent qualification and GitHub acceptance

- Hash-verify all 906 frozen source files; source and model output hashes must
  agree with M06 provenance; no original raw ZIP, weights or images uploaded.
- Reject duplicated scoped identities, unknown frames, nonfinite or outside
  image positions, source index drift and false timestamp injection.
- The native R engine never computes physical speed or joins adjacent
  observations across missing acquisition frames.
- A reference vs model scope collision (same numeric ID) cannot merge paths.
- Preserve reference and model source denominators; publish blocked scientific
  claims explicitly.
- Compare Python independent arithmetic to R figures and CSV summaries on the
  *real* source where available. CI uses minimal **synthetic** cases to test
  mathematical invariants; it does not present fixtures as real fish evidence.

The existing M03–M05 research-workflow, QC and publication APIs remain in place
for recordings with genuine source timestamps. This new source-adapted branch
fills an explicitly missing research need without weakening their time gates.


## One-command native R + independent Python replay on Windows

From a local checkout of this feature branch, with the previously frozen M06
sources already in the user's Documents directory, run:

~~~powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\m07_real_brackish_windows.ps1"
~~~

The launcher checks the previous evidence is present, refuses existing
destinations, authenticates source hashes, creates both separate analysis paths,
executes `scripts/m07_real_brackish_native.R` on real data, builds native
R publication figures and an independent Python report, then runs
`aqt_m07_cross_language_parity.py` on ten real source/sequence scopes.
Only a successful result from the *local* original M06 evidence may be reported
as real-data R/Python parity; no CI fixture can substitute for this gate.

Use `Rscript --vanilla scripts/m07_real_brackish_native.R INPUT_DIR NEW_OUTPUT_DIR`
to re-run the R phase after the authenticated input stage if needed.
