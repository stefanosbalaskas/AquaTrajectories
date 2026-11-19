# Export an unchanged, verified research bundle without losing provenance

Byte-preserving export intentionally does not silently reserialize a
scientific dataset. To alter observations, create a new versioned bundle
with independently declared provenance and a new checksum manifest.

## Usage

``` r
aqt_research_bundle_export(bundle, directory)
```

## Arguments

- bundle:

  Imported `aqt_research_bundle`.

- directory:

  New, nonexistent output directory.

## Value

Output directory invisibly.
