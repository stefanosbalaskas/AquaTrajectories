# Priority A — independent numerical and plotting qualification

## Scope and evidence definitions

This qualification is for the scientific calculations and native plotting functions
of **aquaTrajectories 0.1.1** on the exact checked-out source revision.
It is independent of fish detector weights, identity-model training and video
inference. Source inputs for the primary automated comparisons are invented,
fully disclosed known-answer mathematical fixtures. This does **not** validate
real fish behaviour, lens or underwater camera calibration, fish identity
persistence, welfare states or causal effects.

The full API currently contains 155 public functions and 22 `aqt_plot_*`
functions. **API inventory is not independent scientific certification**.
The CI artifact `FUNCTION_VALIDATION_MATRIX.csv` explicitly lists every
public export and distinguishes:

- `independent_mathematical_oracle`: new independent reference checks for
  a mathematical calculation; success must be confirmed against exact-head CI.
- `native_render_example_only`: an actual function-generated base R figure
  in the complete plot atlas; numerical and perceptual accuracy are distinct.
- `2D_preview_only__rgl_requires_separate_test`: a static preview of inputs;
  the six optional native rgl renderers have a separate headless execution test.
- `existing_test_mentions__not_independent_oracle`: previous tests refer to
  the export; a lexical mention does not establish coverage or correctness.
- `not_independently_qualified`: no named independent oracle in this phase.

## Newly added reference comparisons

| Family | Comparator | Exact claims tested |
|---|---|---|
| Camera clocks | `stats::lm` on distinct marker arrays | Affine intercept/slope and synchronized timestamps |
| Finite-grid trajectory PCA | Independently assembled matrix and `stats::prcomp` | Scores up to sign, eigenvalue fractions, mean path |
| DTW | Exhaustive enumeration of admissible alignments | Global minimum cost and mean alignment cost |
| Recurrence | Explicit pairwise Euclidean calculations | Eligible pairs, recurrence matrix and recurrence rate |
| School geometry | `stats::dist` and centroid/dispersion formulas | Distances, radii, means, scoped sample exclusion |
| Occupancy and entropy | Independent cell counts and Shannon formula | Sample denominators, out-of-grid samples, entropy |
| Events | Arithmetic and trapezoid integration | Actual event windows, missingness and time-gap masks |
| Tank comparison | Independent tank-only resampling | Difference of changes, bootstrap percentile limits |
| Gaussian HMM | Exhaustive enumeration of all latent state paths | Posterior state probabilities, total likelihood, Viterbi |
| Pinhole 3D | Closed-form disparity depth | XYZ, reprojection, rig geometry (ideal air-only scenario) |
| Brown lens | Explicit radial/tangential algebra | Forward pixels, numerical roundtrip, missingness |
| Conditional uncertainty | Zero-noise exact solution | No artificial variation; no statistical coverage claim |
| Measurement scenarios | Zero-perturbation identity | Preserved coordinates, flags, units, caller RNG |
| Hierarchical event modelling | Direct `nlme::lme` fit | Fixed effects and log likelihood of tank/fish nested model |
| Sparse FPCA adapter | Direct `fdapace::FPCA` fit | Backend eigenvalues, mean, conditional scores and input-preserving adapters |
| 2D path graphics | Explicit observed/gap segment references | Never draw unobserved or long-unsampled motion |

The reference implementations are *not* independent physical measurements.
Some comparators intentionally reuse established base R numerical primitives
that the package also uses: such comparisons verify interfaces and data handling
rather than certify independently coded numerical engines.

## Reproducible plotting gate

The plot atlas at `vignettes/articles/all-plot-functions.Rmd` runs all 16 native
base R plot functions with synthetic data and includes six clearly identified
2D input projections for optional 3D rgl plotters. The separate rgl test runs
**each of those six actual optional 3D functions** with `RGL_USE_NULL=TRUE`.
A null graphics device confirms API execution and scene construction, not
pixel-level screenshot agreement or GPU/browser equivalence.

The exact-source workflow at
`.github/workflows/priority-a-independent-validation.yml` uploads:

- `FUNCTION_VALIDATION_MATRIX.csv`: one row for each exported function;
- `QUALIFICATION_COUNTS.csv`: denominators, named reference cases and plot modes;
- `atlas/RENDERED_PLOT_ATLAS.md` with image files from native plotting chunks;
- `SESSION_INFO.txt` and `README_EVIDENCE.md`.

Do not mark any of the above PASS unless the corresponding exact SHA workflow
is green and the evidence artifact exists. The existing whole-package R
qualification and full release gate are **additional** requirements.

## Run without any camera or detector

Install the exact branch locally first and then run:

```r
library(aquaTrajectories)
testthat::test_file(
  "tests/testthat/test-priority-a-independent-references.R",
  reporter = "summary", stop_on_failure = TRUE
)
testthat::test_file(
  "tests/testthat/test-priority-a-optics-uncertainty-references.R",
  reporter = "summary", stop_on_failure = TRUE
)
testthat::test_file(
  "tests/testthat/test-priority-a-rgl-plot-contracts.R",
  reporter = "summary", stop_on_failure = TRUE
)
```

From the repository root run
`Rscript scripts/priority_a_validation_matrix.R priority-a-evidence`.
The evidence destination must be new. Do not upload private or copyrighted
videos to this repository.

Researchers who already have trajectories can separately run the merged
`inst/scripts/aqt_qualify_existing_csv.R`, declaring actual coordinate units
and actual timestamp assumptions. A successful import, distance comparison
and PDF render says that calculations match the *supplied coordinates*;
it does not establish their biological truth.

## Residual scientific work

- Numeric equivalence for all functional and hierarchical model subclasses
  against externally controlled alternative implementations;
- Repeated-simulation calibration of interval coverage, empirical bias and
  estimators under missing-not-at-random trajectories;
- Cross-platform physical camera calibration, verified time alignment and
  external fish-level ground truth;
- Independent visual-review / pixel-level checks and browser/GPU performance
  for interactive rgl scenes.

None of these remaining validations is implicitly supplied by a green
package build or by displaying an attractive figure.
