# Export a complete, auditable scientific-analysis result without recomputation

Creates a new directory of input lineage, stage-level CSV outputs,
serialized scientific objects and SHA-256 artifact manifest. Does not
overwrite existing outputs; RDS retains scientific model objects.

## Usage

``` r
aqt_research_export(study, directory)
```

## Arguments

- study:

  Aqt_scientific_analysis returned by aqt_research_analyze.

- directory:

  New output directory; parent must already exist.

## Value

Output path invisibly.
