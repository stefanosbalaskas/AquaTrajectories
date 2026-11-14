# Import a SHA-256-verified 3D-ZeF published-label agreement report

Verifies Python agreement report digests, row accounting, source
coordinate units, scope and matched 3D Euclidean errors in centimetres.
The source labels are published tracking annotations, not independently
surveyed fish positions. Unkeyed SHA-256 cannot authenticate the model
or reviewer.

## Usage

``` r
aqt_3dzef_agreement_import(directory)
```

## Arguments

- directory:

  Existing folder containing `summary.json`, `per_frame.csv`, and
  `matches.csv` produced by `aqt_3dzef_agreement.py`.

## Value

An `aqt_3dzef_label_agreement` list containing `summary`, `per_frame`,
`matches`, and `software_integrity_verified = TRUE`; never a claim that
independent physical underwater XYZ or fish model accuracy was verified.

## Details

Only original 3D-ZeF published-label agreement is imported. This
operation does not calculate official ZF3D MOTA or TrackEval HOTA, does
not establish cross-camera hardware synchronization, and cannot infer
animal welfare or stress from the imported information.
