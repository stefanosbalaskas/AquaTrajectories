# Diagnose camera-geometry association and common-support exclusions

Diagnose camera-geometry association and common-support exclusions

## Usage

``` r
aqt_geometry_bias_audit(
  data,
  group_col = "recording",
  phase_col = "phase",
  speed_col = "speed",
  area_col = "bbox_area",
  x_col = NULL,
  y_col = NULL,
  confidence_col = NULL,
  reference_phase = "Before",
  n_strata = 5L,
  min_per_stratum = 10L
)
```

## Arguments

- data:

  Source step table.

- group_col, phase_col, speed_col, area_col:

  Column names.

- x_col, y_col, confidence_col:

  Optional image position and detector confidence columns for additional
  descriptive Spearman correlations.

- reference_phase:

  Phase defining the reference comparison.

- n_strata:

  Number of pooled bounding-box-area quantile strata.

- min_per_stratum:

  Minimum observations per phase in an overlap stratum.

## Value

Descriptive Spearman correlations and overlap coverage diagnostics.
