# Wave 14H — same frozen model, two trackers, real crowded fish and error strata

This wave compares actual **ByteTrack** against a second deterministic
IoU/Hungarian tracker on **the exact same new fish detector boxes** from
Wave 14G, and re-evaluates both against original Fraunhofer ricefish A
human-reviewed (but potentially model-assisted) persistent ID labels.

It deliberately separates three experiments:
1. **Detection:** frozen Oxford fish-specific EfficientDet-D2 output
   compared with source HHI ricefish boxes, including total and
   density-stratified IoU=0.50 precision/recall.
2. **Tracking:** both algorithms receive **identical model-produced
   fish detections** rather than oracle source GT boxes. The original
   fish identity values are withheld from both tracker inputs.
3. **2D box-overlap probe:** GT fish rectangles with >=0.10 IoU
   between two source-labelled fish are counted as overlapping.
   Independent manual labels for occlusion do not exist in the input;
   this is explicitly **an overlap proxy**, not biological occlusion truth.

## Reusing actual source evidence

The CI locates and downloads the successful prior Wave 14G original
fish-image inference artifact using the GitHub Actions API, then
**verifies every exported CSV against the SHA256 recorded in the
previous qualified model-inference evidence**. It also requires:
- Original Fraunhofer A source archive SHA-256
  `18c39619b1f84ea774f16fedfac5911d92de86ab7da4aa03cf365b9b4be58ceb`.
- Original HHI source GT SHA-256
  `b70a699b4e41cbec636e5f4b500482451d40ddad29fb387dc36dc0c6392021d3`.
- Source original image frame IDs 43450–43550, remapped locally to
  1–101 only after confirming exact original image frame coverage.
- Exactly 9214 GT fish rows, 260 distinct source identities.
- Source model output must affirm model/ByteTrack had no access to
  source GT identity and must preserve the real source original frame
  offsets and original 101-frame count.

The official metrics use original
[JonathonLuiten/TrackEval](https://github.com/JonathonLuiten/TrackEval)
at frozen commit `12c8791b303e0a0b50f753af204249e622d0281a`.
The complete 101-frame fish identity series are compared separately
for the two association methods; **no oracle detection boxes are
supplied to either method**.

A CI job refuses to continue unless a **successful** prior Wave14G
fish detector execution artifact exists. If the upstream source
inference has not qualified, this downstream task is blocked, not
fabricated or marked passed.

## Exactly what this does not show

These are one video and one out-of-domain fish detector.
Fraunhofer HHI's original dataset is semi-automatically annotated,
and source peer TLS fails default Ubuntu CA chain verification;
the original archive hash is frozen for reproducibility, but
peer/source independently authenticated origin remains a limitation.

Spatial box overlaps **must not** be labelled expert ethological
occlusions. Differences in IDSW/HOTA between the two algorithms
are not evidence of stress, welfare, enrichment success or 3D
reconstruction accuracy. Multi-camera exposure, physical 3D target
metrology, joint uncertainty coverage and tank-replicated animal
intervention experiments remain entirely separate scientific gates.

Source gate: [#46](https://github.com/stefanosbalaskas/AquaTrajectories/issues/46).
Full scientific gate: [#51](https://github.com/stefanosbalaskas/AquaTrajectories/issues/51).
