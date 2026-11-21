# Numerical Validation 2.0 — independent mathematical evidence and image/real-source performance

## Scientific scope and release policy

This upgrade checks numerical software behaviour for **pre-existing, externally supplied 2D/3D tracks**. It does not retrain fish detectors, infer biological stress, reconstruct calibrated underwater XYZ, or establish causal treatment effects. All numerical test inputs are synthetic; any separately downloaded real annotated-fish positions are labeled as such and **do not automatically become biological ground truth**.

No new public R function exports are required: development main retains 173 exported functions. The tagged v0.1.1 release is unchanged until a separately qualified release.

## Reference matrix (executed, not API mentions)

The fail-closed entrypoint `Rscript --vanilla scripts/nv2_reference_matrix.R NEW_DIR` executes tests, then records `NV2_REFERENCE_MATRIX.csv` with one row per method:

| Domain | Independent numerical oracle | Metamorphic/property test | Deliberate failure |
|---|---|---|---|
| Kinematics | Manually computed Euclidean displacements, durations, speeds | Rigid translation and 90° rotation | Duplicate time, nonpositive gap |
| School geometry | Exhaustive nearest neighbors and mean centroids | Label permutation and position shift | Invalid minimum group size |
| DTW | Exhaustive admissible paths, no DP reuse | Symmetry, translation, common scaling | Invalid warping band, missing coordinates |
| Recurrence | Independently indexed threshold/line matrix | Spatial translation invariance | Negative radius, missing sample |
| HMM | Full enumeration of 2^4 latent paths | Joint shift of observations and emission means | Non-stochastic transition, insufficient contiguous segment |
| Dense functional PCA | Independent base R SVD of known design matrix | Starting-position translation | Missing/non-observed sample |
| Hierarchical event inference | Direct nlme fit, fish-level balanced DID | Renamed fish IDs | Insufficient independent tanks |
| Conditional trajectory uncertainty | Exact zero-error scenario, independent quantiles | RNG preservation, source equivalence | Invalid AR parameter, duplicate draw |
| Sparse FPCA | Independent temporal-support counts, direct fdapace reference | Affine recording-clock change | Missing sparse design; inadequate observed support |

The sparse adapter reference is a comparison to an external maintained **same estimator implementation**, not a second independently derived sparse FPCA estimator. A simulated rank-one-with-noise design checks finite nonnegative eigenvalues and observed sample retention; no frequentist confidence-interval coverage or biologically representative missingness is certified.

The matrix is marked passed only when every source test file and pre-existing mathematical reference/backend test has actually executed without errors. Tests do **not** certify the full input domain of advanced estimators.

## Pixel-level visual regression

`scripts/nv2_pixel_golden.R` renders three actual native package plots: paths, recurrence and dense-grid PCA, at 480 × 320 pixels using the reproducible `ragg` device. It:

1. Re-renders each plot and requires **exact identity at every decoded foreground pixel** within each operating system.
2. Encodes a full-resolution binary foreground mask using run-length encoding, not a simple file hash or downsampled thumbnail.
3. In verified mode, compares each of 153,600 foreground pixels per image to a **checked-in, frozen** source-control reference generated from a reviewed baseline run.
4. Records per-pixel disagreement and foreground intersection-over-union (IoU), allowing limited cross-operating-system font/antialiasing variance (at most 4% disagreeing pixels and foreground IoU at least .65).
5. Writes actual PNGs, summary CSV and SHA-256 evidence.

A first candidate-capture workflow is *not* cross-platform golden regression. Only after the candidate text is frozen as `tests/golden/nv2_pixel_masks.csv` and all Linux, Windows and macOS verification jobs succeed may the cross-platform golden stage be called qualified. Full RGBA byte-for-byte identity across OS is **not** required or claimed. The prior 22-function render execution coverage remains separate: these pixel-level golden tests select three representative renderers.

## Real-world multi-fish performance (two A/B source sequences)

`scripts/nv2_fraunhofer_mot_to_csv.py` reads the actual official Fraunhofer HHI ricefish MOT A/B annotation ZIPs from:

- https://cvg.hhi.fraunhofer.de/FishTrackingData/video_a/mot_a.zip
- https://cvg.hhi.fraunhofer.de/FishTrackingData/video_b/mot_b.zip

It validates ZIP membership, missing/corrupt GT source, duplicate frame/track labels, finite bounding boxes and positive sizes. It extracts original MOT **bounding-box centres**, not tracker predictions, labeled biological identities or surveyed XYZ, into a canonical source-row-linked CSV. Original source ZIP SHA-256, native GT member digest and exact conversion rules are written to JSON.

**Important provenance limitation:** the original site has an invalid certificate chain on the GitHub runners. The existing Fraunhofer source workflow uses `curl --insecure`; new tests retain `transport_tls_peer_verified=false` and `origin_verified_by_independent_frozen_digest=false`. The downloaded annotation data are real provided the downloaded contents are genuine, but the transport alone does not authenticate them. Verify the original ZIPs against independent trusted digests before making strong provenance claims.

The original MOT rows contain frame indices but not independently verified image-exposure timestamps. The package's time_s column therefore contains an **explicit ordinal frame proxy** solely to group simultaneous samples; it is **not a seconds measurement**. The profiler excludes movement speed, duration, path-length inference and biomechanical rate claims. Its `REAL_GROUP_PERFORMANCE.csv` records execution time, R object sizes, actual per-frame visible counts and real annotated input-row counts for multiple real-ID subsets. It independently recomputes sampled centroids and nearest-neighbor distances from base R Euclidean matrices. It does not measure full operating-system peak RSS, tracker throughput or statistically representative treatment effects.

Run manually with previously acquired genuine source annotation CSV and matching provenance JSON:

~~~sh
Rscript --vanilla scripts/nv2_real_group_profile.R \
  /data/SOURCE_FRAME_CENTER_TRACKS.csv \
  /data/SOURCE_PROVENANCE.json \
  /data/NEW_PROFILE_FOLDER
~~~

No original copyrighted imagery, recordings or full annotation tables are uploaded as benchmark artifacts. GitHub Actions archives only aggregated performance/provenance evidence.

## Required qualification

- Exact numerical and deliberate failure tests pass in a clean R environment with external fdapace/nlme installed.
- Source-control image goldens are locked and all three OSes pass actual pixel-mask comparisons.
- Real A/B annotation files are actually downloaded and passed through the separate converter and R profiler, or are explicitly reported **not run** (a synthetic substitute must never be relabeled real).
- No original input or existing source code is modified by the tests.
- R CMD check, website/API registry and previously merged 173-function scientific baseline remain intact.

Measured runtimes are local CI observations, **not** cross-machine latency service-level agreements. True real-world performance generalization still needs larger independent recordings, equipment and repeatability beyond the two short A/B source sequences.
