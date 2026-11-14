# Describe delay from a logged event to the next observed change point

Searches first mean change after event onset within max_delay_s. The
returned delay is a descriptive temporal association, not physiological
response latency or evidence of an intervention effect.

## Usage

``` r
aqt_changepoint_event_delay(fit, events, max_delay_s = 30)
```

## Arguments

- fit:

  aqt_changepoints from one scoped session/camera/fish.

- events:

  Canonical event log for the same session.

- max_delay_s:

  Nonnegative finite window after each event onset.

## Value

Per-event observed change time and delay, NA if absent.
