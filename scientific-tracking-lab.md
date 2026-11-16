# Fish detection ≠ fish identity

Scientific teaching · synthetic demonstration only · v0.1.1

# Fish detection ≠ fish identity

A frame-by-frame synthetic benchmark that separates finding fish-shaped
objects from maintaining their tracker labels. Adjust the error scenario
and inspect its consequences. These metrics refer only to invented
ground-truth boxes and synthetic predictions.

## Design a test scenario

Number of fish

5

Frames

80

Missed-detection probability

16%

False-positive chance per frame

10%

Tracker-ID change chance per visible fish

6%

Localization perturbation (maximum ± px)

2

IoU match threshold

0.50

Deterministic random seed

Restore baseline scenario

## Synthetic observation and predicted boxes

Dashed cyan boxes = known synthetic fish. Solid gold boxes = predicted
matches. Solid red boxes = unmatched predictions. Tracked IDs are
algorithmic labels, not independently known animal identities.

![](data:image/svg+xml;base64,PHN2ZyBpZD0ic2NlbmUiIHZpZXdib3g9IjAgMCA4MjAgNDQ1IiByb2xlPSJpbWciIGFyaWEtbGFiZWxsZWRieT0ic2NlbmVUaXRsZSBzY2VuZURlc2MiPjx0aXRsZSBpZD0ic2NlbmVUaXRsZSI+U3ludGhldGljIGZpc2ggYm94ZXMgYW5kIHRyYWNrZXIgcHJlZGljdGlvbnM8L3RpdGxlPgo8ZGVzYyBpZD0ic2NlbmVEZXNjIj5GaXNoIGxvY2F0aW9ucyBhbmQgcHJlZGljdGVkIGJveGVzIGNoYW5nZSB3aXRoIGZyYW1lIGFuZCB1c2VyLWRlZmluZWQgc2ltdWxhdGlvbiBzZXR0aW5ncy48L2Rlc2M+PHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjgyMCIgaGVpZ2h0PSI0NDUiIHJ4PSIxNCIgZmlsbD0iIzBlMmIzZiIgLz48ZyBpZD0ic2NlbmVJdGVtcyI+PC9nPjwvc3ZnPg==)Review
synthetic frame

1 / 80

Previous frame

Next frame

Download synthetic prediction CSV

## Computed evaluation

Precision**—**

Recall**—**

F1**—**

Matched true boxes**—**

False positives**—**

Missed true boxes**—**

Tracker-ID changes**—**

Matched frame transitions**—**

Detection boxes are paired greedily in descending IoU with a one-to-one
constraint. The displayed ID-change count compares assigned labels for
the same synthetic fish in adjacent matched frames. **It is not official
HOTA, IDF1, TrackEval, or an independent tracking benchmark.** When no
predictions exist, precision is defined as zero for this teaching
dashboard.

[Explore the underlying
equations](https://stefanosbalaskas.github.io/AquaTrajectories/math-workbench.md)
· [Source example: released
kinematics](https://github.com/stefanosbalaskas/AquaTrajectories/blob/v0.1.1/R/kinematics.R)
· [Actual validation
requirements](https://stefanosbalaskas.github.io/AquaTrajectories/articles/validation-and-benchmarks.md)
