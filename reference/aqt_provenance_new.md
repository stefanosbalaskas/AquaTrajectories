# Create an immutable-input inventory for a fish-tracking analysis

Captures path, byte size, modification time and MD5 content hash for
input videos, detector weights, annotations and reference truth files.
This does not embed the files or claim scientific reproducibility by
itself.

## Usage

``` r
aqt_provenance_new(paths, metadata = list())
```

## Arguments

- paths:

  Existing local files to inventory.

- metadata:

  Named list of processing settings, version strings, etc.

## Value

An aqt_provenance list with files and metadata.
