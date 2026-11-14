# Prespecify a random time-stratified video annotation frame sample

Samples only from independently acquired video PTS manifests, not YOLO
predictions, detections, tracker confidence or inferred fish presence.
Frames are split into equal-duration time strata WITHIN each camera
recording, and a balanced number of acquired frames is sampled per
stratum using an RNG state that is restored before returning. Required
strata without frames or enough acquired frames fail closed, rather than
silently reducing or shifting the annotation sample.

## Usage

``` r
aqt_annotation_frame_plan(frames, per_video = 60L, strata = 6L, seed = 11L)
```

## Arguments

- frames:

  Verified aqt_frame_manifest including zero-fish frames.

- per_video:

  Number of acquired frames to sample independently for every
  camera-local recording; positive integer.

- strata:

  Number of equal-duration temporal strata per recording, \<= per_video
  and \>=2. Each must supply its allocated frames.

- seed:

  Explicit nonnegative integer RNG seed.

## Value

aqt_annotation_plan frame table with sample probabilities, inverse
selection weights and an unannotated status marker.

## Details

A plan is NOT a list of already annotated frames. Its annotation_status
is "planned_not_annotated" until real manual annotation is completed;
the bundle scorer explicitly rejects it. After actual independent
full-frame annotation, the caller may set annotation_status to
"fully_annotated" for those reviewed frames.
