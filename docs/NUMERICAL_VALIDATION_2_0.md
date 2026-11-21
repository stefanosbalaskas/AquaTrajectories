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

The sparse adapter reference is a comparison to an external maintained **same estimator implementation**, not a second independently derived sparse FPCA estimator. A separate, independently specified 100-curve rank-one Gaussian process tests population mean-curve RMSE (<0.4 coordinate units) and sign-invariant leading-eigenfunction correlation (>0.7), alongside finite eigenvalues and explicit observed support. The data-generation process defines the truth independently of the PACE code, but it represents favourable independent observation schedules and does **not** establish frequentist interval coverage or robustness to nonrandom biological occlusion.

The matrix is marked passed only when every source test file and pre-existing mathematical reference/backend test has actually executed without errors. Tests do **not** certify the full input domain of advanced estimators.

## Pixel-level visual regression

`scripts/nv2_pixel_golden.R` renders three actual native package plots: paths, recurrence and dense-grid PCA, at 600 × 480 pixels using the reproducible `ragg` device. It:

1. Re-renders each plot and requires **exact identity at every decoded foreground pixel** within each operating system.
2. Encodes a full-resolution binary foreground mask using run-length encoding, not a simple file hash or downsampled thumbnail.
3. In verified mode, compares each of 288,000 foreground pixels per image to a **checked-in, frozen** source-control reference generated from a reviewed baseline run.
4. Records per-pixel disagreement and foreground intersection-over-union (IoU), allowing limited cross-operating-system font/antialiasing variance (at most 4% disagreeing pixels and foreground IoU at least .60).
5. Writes actual PNGs, summary CSV and SHA-256 evidence.

The first successful Linux candidate was frozen under `tests/golden/nv2_pixel_masks.csv` on the PR branch; the cross-platform verification job is the release gate. Capture alone is not cross-platform evidence; only actual successful verification on all three systems qualifies the numerical mask comparison. Full RGBA byte-for-byte identity across OS is **not** required or claimed. The prior 22-function render execution coverage remains separate: these pixel-level golden tests select three representative renderers.

## Real-world multi-fish performance (three original 3D-ZeF20 sequences)

The original Fraunhofer HHI A/B archive URLs were probed in CI but returned
`curl: (7) Could not connect to server`. A failed download is never
represented as a completed real-world benchmark. The Fraunhofer adapter remains
available for researchers possessing those original files, but is **not** used
to claim results in this workflow.

The active real-data gate uses the Aalborg University Visual Analysis and
Perception Lab **3D-ZeF** benchmark (Pedersen et al., CVPR 2020), sequences
`ZebraFish-01`, `ZebraFish-04`, and `ZebraFish-08`, crossing train,
validation and test splits. These are genuine manually annotated zebrafish
recordings with a top and front GoPro view. The workflow downloads only original
small per-sequence `gt/gt.txt` files over verified HTTPS from:

https://huggingface.co/datasets/vapaau/3D-ZeF

Dataset license declared by the hosting original laboratory: MIT.
Read the original 19-column schema before inferring coordinate semantics:

https://huggingface.co/datasets/vapaau/3D-ZeF/blob/main/data/ZebraFish-01/readme.txt

The converter `scripts/nv2_zef_to_csv.py` explicitly takes
`camT_x` and `camT_y`: **original top-view head-point image pixel
annotations**, not derived 3D XYZ and not bounding-box centroids. It retains
original fish IDs and row numbers, excludes invalid head annotations with an
explicit exclusion table, and rejects duplicate frame/ID keys or malformed
annotations. Its source digest, origin URL, frame and individual counts are
included in `SOURCE_PROVENANCE.json`.

**Original annotation accuracy limitation:** Manual 3D-ZeF head labels
include estimated head locations when fish are occluded. An existing benchmark
label is not an independent biological identity certification, and a 2D head
point is not a physical underwater measurement.

The original GT rows contain frame indices but not independent exposure
timestamps. `time_s` is an **explicit ordinal frame proxy** used only
to group simultaneous samples; it is **not a real seconds measurement**.
The profiler therefore makes no claims about movement speeds, durations,
physical path lengths or animal welfare. It calculates descriptive same-frame
group geometry only. At each original recorded frame, the R analysis is
separately checked against base-R centroids and nearest-neighbor Euclidean
distances on the same real points.

The `REAL_GROUP_PERFORMANCE.csv` files record runtime, `object.size`,
original row count, original frame count, fish ID subsets and same-frame
visibility. Rows are never generated to fill excluded time points or identities.
This is a real external annotation computation benchmark with transparent
provenance, **not** independent evidence of tracker or estimator accuracy.

Run manually with the source CSV and matching provenance JSON:

~~~sh
Rscript --vanilla scripts/nv2_real_group_profile.R \
  /data/SOURCE_FRAME_CENTER_TRACKS.csv \
  /data/SOURCE_PROVENANCE.json \
  /data/NEW_PROFILE_FOLDER
~~~

No original imagery, recordings, raw annotation tables or separate full fish
identities are republished in CI artifacts. Only aggregates and original
source SHA-256 references are uploaded. A frame-proxy calculation must never
be mislabeled as calibrated timing.


### Observed CI performance — original annotations (21 November 2026)

The first successful CI benchmark preserved exact upstream source-file digests
and produced the following measured whole-call `aqt_group_metrics()` elapsed
times on its Linux GitHub runner. These are **observations**, not predictions,
speedups, statistical confidence intervals or cross-hardware performance limits.

| Sequence | Source rows | Frames | IDs | First call (s) | Second call (s) | R track object bytes |
|---|---:|---:|---:|---:|---:|---:|
| ZebraFish-01 | 14,376 | 7,188 | 2 | 4.885 | 4.969 | 980,440 |
| ZebraFish-04 | 4,550 | 910 | 5 | 0.664 | 0.651 | 312,440 |
| ZebraFish-08 | 9,000 | 900 | 10 | 0.677 | 0.665 | 615,320 |

These are full-sequence calculations of descriptive same-frame group geometry.
Comparisons between sequences are **not** controlled scaling comparisons:
they differ in number of frames, number of fish and trajectory content.

Downloaded original GT SHA-256:

- ZebraFish-01: `a582584c3d312cffe264cf642297f5311e929df4af76fe5ee3a8e33ac9c9bb74`.
- ZebraFish-04: `f84b3d2fe01ea3f9e376e8023f2a7a664c8f07a4792d1a8a537d1d4924bbeeab`.
- ZebraFish-08: `245de975cbeead9b0ddcc4dec63351b367f263845d80521cc16d54765ce01467`.

The source text was acquired via TLS-verified HTTPS and hashed. These hashes
identify the exact downloaded bytes but do not, without an independent source
hash signature, certify the biological correctness of annotations.

## Required qualification

- Exact numerical and deliberate failure tests pass in a clean R environment with external fdapace/nlme installed.
- Source-control image goldens are locked and all three OSes pass actual pixel-mask comparisons.
- Original 3D-ZeF01/04/08 annotation files are actually downloaded over verified HTTPS and passed through the source converter and R profiler, or are explicitly reported **not run**; never substitute synthetic data.
- No original input or existing source code is modified by the tests.
- R CMD check, website/API registry and previously merged 173-function scientific baseline remain intact.

Measured runtimes are local CI observations, **not** cross-machine latency service-level agreements. True real-world performance generalization still needs larger independent recordings, equipment and repeatability beyond the three selected independent 3D-ZeF source sequences.
