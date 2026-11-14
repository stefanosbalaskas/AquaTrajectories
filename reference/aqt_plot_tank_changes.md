# Visualize independent tank-level before/after changes

Draws one line per tank within the two treatment groups. This plot
displays the actual unit of replication; it does not draw uncertainty
bands from frame-level pseudo-replicates.

## Usage

``` r
aqt_plot_tank_changes(fit, ylab = "Behavioural measurement")
```

## Arguments

- fit:

  Result from aqt_tank_event_contrast().

- ylab:

  Label for the behavioural metric.

## Value

The per-tank summary, invisibly; opens a base-R plot.
