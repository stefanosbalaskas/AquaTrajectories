# Turn documented human-reviewed candidate selections into correspondences

This method does not choose which matches are correct. It only checks
the review file and ensures a source observation is not assigned to
several fish. The reviewer remains responsible for biological identity
claims.

## Usage

``` r
aqt_correspondences_from_review(candidates, review)
```

## Arguments

- candidates:

  Candidate table from aqt_view_candidates().

- review:

  Data frame with candidate_id, fish_id, reviewer, reason.

## Value

Explicit correspondences acceptable to aqt_reconstruct_3d().
