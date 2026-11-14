# Audit between-tank treatment replication and experimental-unit independence

This assumes each tank has one treatment throughout the analyzed period.
Crossover or split-plot designs need a different inferential model.
n_rows and n_fish never replace the number of independently treated
tanks.

## Usage

``` r
aqt_design_audit(data, treatment_col = "treatment", tank_col = "tank_id")
```

## Arguments

- data:

  Table with treatment and tank identifiers.

- treatment_col:

  Treatment assignment column.

- tank_col:

  Independent experimental tank/cluster column.

## Value

Per-treatment independent-tank and row counts with replication flag.
