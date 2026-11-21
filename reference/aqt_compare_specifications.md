# Compare descriptive trajectory estimates across weighting and QC specifications

A source-column-aware, descriptive sensitivity analysis. Numeric-looking
recording and track labels are always identifiers, not list positions.
Pooled steps, fragment-equal medians and time-window-equal medians are
contrasted without treating steps or fragments as independent animals.

## Usage

``` r
aqt_compare_specifications(
  data,
  group_col = "recording",
  phase_col = "phase",
  time_col = "time_s",
  value_col = "speed",
  track_col = "track_id",
  fragment_col = NULL,
  eligible_col = NULL,
  policy_col = NULL,
  window_widths = c(1, 3, 6),
  reference_phase = "Before",
  min_steps = 3L,
  min_steps_per_window = 1L
)
```

## Arguments

- data:

  Data frame containing eligible or policy-tagged movement steps.

- group_col, phase_col, time_col, value_col, track_col:

  Source column names.

- fragment_col:

  Optional audited continuous fragment identifier. When absent, the
  software track identifier is weighted equally instead; that is never
  silently described as fragment-equal weighting.

- eligible_col:

  Optional logical step eligibility column.

- policy_col:

  Optional QC policy identifier; policies remain separate.

- window_widths:

  Positive widths in declared source-time units.

- reference_phase:

  Explicit reference phase label.

- min_steps:

  Minimum eligible rows per recording/phase/policy.

- min_steps_per_window:

  Minimum rows per window included in the time-balanced estimator;
  unsupported windows are omitted.

## Value

List with estimates, contrasts, sign-stability flags, and provenance.
