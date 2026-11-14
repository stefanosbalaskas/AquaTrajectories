# Rank cross-view geometry candidates and flag ambiguous matches

A good reprojection fit is only a hypothesis. The function never returns
confirmed fish IDs. Use aqt_correspondences_from_review() for explicitly
human-verified selections. Rankings are scoped by source fish detection.

## Usage

``` r
aqt_candidate_rank(candidates, max_reprojection_px = 2)
```

## Arguments

- candidates:

  Candidate table from aqt_view_candidates().

- max_reprojection_px:

  Maximum tolerated reprojection error.

## Value

Candidate table with eligible, rank_a, n_eligible_a and second-best
margin, all purely geometric.
