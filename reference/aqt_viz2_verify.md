# Verify a published figure's source-row evidence and file hashes

Checks every file declared by VIZ2_MANIFEST.json without recomputing
scientific estimates or trusting plain filenames. SHA-256 is a
corruption and provenance check, not a cryptographic authorship
signature.

## Usage

``` r
aqt_viz2_verify(directory, source_file = NULL)
```

## Arguments

- directory:

  Existing aqt_viz2_export() directory.

- source_file:

  Optional original input file to recheck against the recorded source
  SHA-256, including after figures have been published.

## Value

TRUE invisibly or an error naming the failed file.
