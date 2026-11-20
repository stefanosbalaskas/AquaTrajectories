# Validate fish trajectory measurements against declared reference annotations

Compare image-pixel coordinates, adjacent-frame displacement and matched
group geometry after external evaluation-only one-to-one IoU matching.
The source observations remain unchanged and original fish references
are NOT claimed as independently re-adjudicated biological identity
truth.

## Usage

``` r
aqt_reference_measurement_validate(
  frames,
  observations,
  matched,
  iou_threshold = 0.5
)
```

## Arguments

- frames:

  Original M07 acquisition-frame table with unknown time_s.

- observations:

  Original M07 separate reference and model observation rows.

- matched:

  Evaluator one-to-one bbox associations with 1-based
  reference_source_row/model_source_row source-line indices.

- iou_threshold:

  Declared matching threshold in (0,1\], default .5.

## Value

A list containing source-preserving matching, complete reference
adjacent-step ledger, matched-subset spatial geometry, a per-sequence
measurement summary and explicit blocked physical/biological claims.
