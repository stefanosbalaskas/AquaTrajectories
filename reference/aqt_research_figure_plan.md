# Plan source-supported scientific publication figures

Returns all candidate figures, including ones that must be withheld
because the selected scientific analysis did not support them. No
interpolation, estimation, or source-data modification takes place.

## Usage

``` r
aqt_research_figure_plan(study, max_scopes = 3L)
```

## Arguments

- study:

  Source-verified aqt_scientific_analysis.

- max_scopes:

  Maximum camera/session panels, 1..8.

## Value

Figure eligibility catalogue with evidence counts and captions.
