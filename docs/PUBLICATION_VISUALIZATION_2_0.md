# Publication Visualization 2.0

**Scope:** Unified, source-linked manuscript figure specifications for existing,
validated 2D/3D fish trajectories. The 22 existing public \`aqt_plot_*\` functions
are retained; a separate gallery and scene qualification confirms their actual
native output. This does **not** add an unvalidated fish detector or invent fish
positions, FPS or cross-view identity.

## 1. Six public APIs

- \`aqt_viz2_presets()\`: generic single-/double-column manuscript, manuscript
  and presentation size/resolution presets. They are not an assertion that a
  specific journal has approved the output. Check its latest technical guide.
- \`aqt_viz2_gallery()\`: exact namespace inventory of all 22 public
  \`aqt_plot_*\` exports, including six optional native \`rgl\` scenes.
- \`aqt_viz2_spec()\`: fail-closed figure definition from unmodified
  \`aqt_tracks\` or \`aqt_qc2_report\`, with explicit session/camera and QC
  policy selection where ambiguous.
- \`aqt_viz2_draw()\`: source-row-linked 2D plot, excluding every rejected
  movement edge and every unobserved coordinate.
- \`aqt_viz2_export()\`: transactional, non-overwriting SVG/PDF/PNG/TIFF
  export with exact plotted observation, QC and file manifests.
- \`aqt_viz2_verify()\`: file SHA-256 and all plotted source-row/segment ledger
  verification. It detects unrecorded changes but is not a cryptographic
  statement of authorship or an independent scientific measurement oracle.

## 2. Reproducible usage

~~~r
library(aquaTrajectories)

# Tracks must have declared units, coordinate system and actual time_s.
# Explicit finite gap policy for raw tracks; never silently assume infinity.
spec <- aqt_viz2_spec(
  my_tracks,
  figure = "paths",
  gap_limit_s = 0.2,
  preset = "journal_double",
  caption = "Observed trajectories: QC-qualified consecutive steps"
)
aqt_viz2_export(spec, "reviewer_figure_1",
                formats=c("pdf", "svg", "png", "tiff"))
stopifnot(aqt_viz2_verify("reviewer_figure_1"))

# If multiple sensitivity policies were audited, select one by ID.
qc <- aqt_qc2_report(my_tracks,
  gap_limits_s=c(.1,.2,.5), speed_limits=c(10,20))
figure <- aqt_viz2_spec(qc,figure="speed",policy_id="QC003",
                        preset="journal_single")
aqt_viz2_export(figure,"reviewer_speed",formats=c("pdf","tiff"))
~~~

For independently supplied CSV data:
\`aqt_qc2_report(path, gap_limits_s=..., units="cm",
coordinate_system="tank")\` and then
\`aqt_viz2_spec(qc, source_file=path,...)\` will bind the actual file's SHA-256
and refuse rendering if the file changes before export.

## 3. Exact, scientific source-to-figure traceability

Each exported figure contains:

| Artifact | Reproducible purpose |
|---|---|
| \`figure.pdf\` / \`figure.svg\` | Vector representation |
| \`figure.png\` / \`figure.tiff\` | Resolution-prescribed raster artwork |
| \`FIGURE_MANIFEST.json\` | Existing core exporter per-file digests |
| \`VIZ2_MANIFEST.json\` | Full source scientific signature, policy, target camera/session, plane, preset, every file SHA-256 |
| \`PLOTTED_SOURCE_POINTS.csv\` | Every original scoped position row, observed flag and source-row ID |
| \`ELIGIBLE_SOURCE_SEGMENTS.csv\` | Only accepted source-row pairs; two exact endpoints, time, full 2D/3D displacement and speed |
| \`ALL_QC_ROW_DECISIONS.csv\` | Every original row's policy outcome and omission reason |
| \`SELECTED_QC_POLICY.csv\` | Exact gap, speed, step and units policy |

A figure is **not** reconstructed from an arbitrary re-exported tracker CSV
without the original QC row ledger. Data source hashes and figure-file hashes
bind the audit record to the exact observations used. Figure specs are sealed
against post-construction alterations and output directories are created only
after successful rendering and evidence verification.

New figures are:

| \`figure\` | Meaning and exclusions |
|---|---|
| \`paths\` | All observed points; lines only for QC-eligible predecessor-successor rows |
| \`speed\` | Eligible movement displacement divided by measured source time; no gap-bridging line |
| \`qc_coverage\` | Eligible, policy-excluded, and not-estimable row counts per fish (max 30 visible fish for legibility) |
| \`qc_reasons\` | Full per-source-row QC exclusion and non-estimability reason distribution |

The \`plane="xz"\` and \`plane="yz"\` options are explicitly **projections** of
genuine 3D data, never assumed zero depth. Speed always uses **full Euclidean
2D/3D step length** and never incorrectly uses the projected step length.
Different image cameras and independently recorded sessions are not plotted
together without explicit scope selection. Frame gaps are honored by the QC
ledger, even when neighboring source timestamps happen to be close.

## 4. Gallery completeness and regression

The separately maintained \`vignettes/articles/all-plot-functions.Rmd\`
provides source-supported examples and code for all **22 native public plot
functions**, not screenshots pretending to be native 3D. The executable
\`scripts/viz2_gallery_matrix.R\` first executes all 22 public functions,
creates actual PDFs from 16 native 2D renderers and checks six native optional
rgl plotting calls. It then re-executes all six 3D scenes twice and checks
nonempty scene primitives, finite nondegenerate bounding boxes, stable primitive
type signatures and repeated geometric extents. The test retains the gallery
fixture hash, per-output hashes, and 3D geometry evidence.

\`scripts/viz2_pixel_golden.R\` generates **four** native Publication 2.0 plots
from a fixed, documented synthetic 3-fish fixture containing an explicitly
missing observation, a source-frame skip and QC-rejected movement steps.
Each figure is rendered twice at 600 × 480 pixels and verified for identical
per-pixel foreground masks on the same OS. The source-controlled Linux mask
is compared against all 288,000 pixels per figure on Linux, Windows and macOS,
reporting pixel disagreement and foreground IoU. The tolerance accounts for
system font and antialiasing differences; **identical PDF/SVG/PNG/TIFF bytes
across operating systems are not claimed**.

Prior NV2 pixel-golden tests for three traditional plot functions continue
separately; the combined public plot execution coverage remains 22 of 22
when its CI run succeeds. Gallery code must not rename chart functions or
alter biological inferences merely to satisfy appearance tests.

## 5. Scientific boundaries

The reference input may be real externally annotated fish positions, but this
figure layer does not certify biological identity, original clock accuracy,
aquarium camera/refraction calibration, event causal identification, welfare
or treatment-effect inference. \`aqt_viz2_spec\` refuses silently interpolating
missing rows, ignoring a policy, mixing camera scopes or substituting a 2D
projection for validated 3D position truth.

Release gate: all new functional and format outputs, docs/exports congruence,
gallery completeness, meaningful 3D scene geometry tests, frozen four-figure
pixel-golden tests on three operating systems, and unchanged full-package CI.
