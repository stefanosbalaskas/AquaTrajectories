# Understand the mathematics behind aquatic trajectories

Scientific teaching · synthetic demonstration only · v0.1.1

# Understand the mathematics behind aquatic trajectories

Change the inputs and watch mathematical quantities update. These
illustrations are deterministic, low-dimensional teaching examples—not a
browser implementation of every v0.1.1 method or a camera calibration.

## 1. Timestamp-aware swimming speed

Δx (cm)

Δy (cm)

Δt (seconds)

v = (p₂ − p₁)/Δt; speed = √(Δx²+Δy²)/Δt

Matches the finite-difference concept in
[aqt_kinematics()](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_kinematics.md).
The released function also requires valid observed positions, positive
timestamps, and permitted time gaps.

## Displacement vector

![](data:image/svg+xml;base64,PHN2ZyBpZD0idmVjdG9yU2NlbmUiIHZpZXdib3g9IjAgMCA0NjAgMzQwIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9IlN5bnRoZXRpYyBkaXNwbGFjZW1lbnQgYXJyb3cgd2l0aCBDYXJ0ZXNpYW4gYXhlcyI+PHJlY3Qgd2lkdGg9IjQ2MCIgaGVpZ2h0PSIzNDAiIHJ4PSIxNCIgZmlsbD0iIzBlMmIzZiIgLz48ZyBpZD0idmVjdG9ySXRlbXMiPjwvZz48L3N2Zz4=)

## 2. Group directional polarization

Angular spread of five fish (degrees)

P = ‖(1/N) Σ \[vᵢ / ‖vᵢ‖\]‖

This visualization uses five nonzero unit headings, so polarization lies
between 0 and 1.
[aqt_group_metrics()](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_group_metrics.md)
additionally requires simultaneous valid observations.

## Five synthetic headings

![](data:image/svg+xml;base64,PHN2ZyBpZD0ic2Nob29sU2NlbmUiIHZpZXdib3g9IjAgMCA0NjAgMzQwIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9IkZpdmUgc2ltdWxhdGVkIGRpcmVjdGlvbiBhcnJvd3MgYW5kIHRoZWlyIHJlc3VsdGFudCBwb2xhcml6YXRpb24iPjxyZWN0IHdpZHRoPSI0NjAiIGhlaWdodD0iMzQwIiByeD0iMTQiIGZpbGw9IiMwZTJiM2YiIC8+PGcgaWQ9InNjaG9vbEl0ZW1zIj48L2c+PC9zdmc+)

## 3. Cross-camera affine clock relationship

Camera timestamp (s)

Reference offset (s)

Clock drift (ppm)

t_reference = a + (1 + d · 10⁻⁶) × t_camera

The displayed mapping is algebraic. Fitted and holdout pulse residuals
require independently corresponding physical synchronization events. See
[aqt_sync_holdout_fit()](https://stefanosbalaskas.github.io/AquaTrajectories/reference/aqt_sync_holdout_fit.md).

[Try the tracking evaluation
simulator](https://stefanosbalaskas.github.io/AquaTrajectories/scientific-tracking-lab.md)
· [Explore synthetic
graphics](https://stefanosbalaskas.github.io/AquaTrajectories/plot-playground.md)
