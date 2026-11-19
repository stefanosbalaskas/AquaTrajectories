# Export a complete, immutable, provenance-linked trajectory QC audit

Writes raw observations, frame manifest, row-level flags, reviewed
tracks, available annotation accuracy, derived measurements, and a
manifest of SHA-256 output hashes. Refuses existing output paths. No
source video or tracker weights are copied to the report.

## Usage

``` r
aqt_qc_report(review, derived = NULL, directory)
```

## Arguments

- review:

  An aqt_qc_review.

- derived:

  Optional aqt_qc_derived built from this review.

- directory:

  New output directory (parent must exist).

## Value

Export directory invisibly.
