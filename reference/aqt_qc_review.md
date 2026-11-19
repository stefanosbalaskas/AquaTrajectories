# Apply documented review decisions without changing the original trajectories

Decisions have raw_row,decision ("exclude" or "accept"),reason. An
explicit acceptance can overturn only a quality-warning (low score,
jump, speed); structural invalidities, missing coordinates or ambiguous
duplicate IDs can never be silently accepted. Rows rejected by quality
rules are retained in the screened track object with observed=FALSE to
prevent gap bridging.

## Usage

``` r
aqt_qc_review(qc, decisions = NULL)
```

## Arguments

- qc:

  Output of aqt_trajectory_qc.

- decisions:

  Optional manual review table; row ids identify source rows.

## Value

aqt_qc_review with original qc, review ledger and screened tracks.
