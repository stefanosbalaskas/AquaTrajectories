# Wave 14E — original 3D-ZeF zebrafish source: 3D-position oracle ID tracking

## Experimental objective and exact data provenance

Acquire the original publicly published
[3D-ZeF20](https://motchallenge.net/data/3DZeF20Lables.zip)
zebrafish reconstructed 3D labels, already verified in Wave 12A
(4 training/validation sequences, 27,026 total fish-ID+XYZ
observations), and **withhold the true fish IDs** while an independently
written temporal assignment algorithm matches positions between frames.

- Input to tracker: original reconstructed XYZ *positions*, in source
  centimetres; **true fish identity IDs are withheld**.
- Algorithm: Euclidean-distance nearest-neighbour Hungarian with
  prespecified distance gate 5 cm and maximum five missing frames;
  new IDs for unmatched incoming positions, no ID relabelling using GT.
- Evaluation: original published GT IDs and positions, scoring the
  **new tracker IDs** using pinned unmodified official TrackEval HOTA,
  DetA, AssA, IDF1, CLEAR MOTA and IDSW classes.
- Source similarity: `max(0,1-Euclidean_cm/2cm)`; therefore matching
  threshold 0.5 corresponds to distance at most 1cm.
- All source frames up to last known GT frame are included in the metric
  arrays, but their annotation completeness has **not** been separately
  verified from independently reviewed original videos.

CI verifies original public ZIP SHA-256 and original member hashes,
4 native source GT files, 27,026 source observations, no identity IDs
in tracker inputs, exact frozen TrackEval implementation and derived
per-sequence metrics.

## Important interpretation

This is a genuine **real source fish association** benchmark under
**oracle 3D localization**. It DOES NOT re-detect fish from the
original two GoPro video pixel streams or reconstruct physical 3D.
It cannot establish performance when fish are missed/detector boxes
are wrong, nor demonstrate physically surveyed underwater XYZ RMSE.
Original 3D ZeF published XYZ are dataset tracking labels, not
independently surveyed calibration targets.

This Wave differs from an official organizer 3D-ZeF benchmark entry:
HOTA/IDF1 are computed using official **metric code**, but 3D
localization similarity and frame preprocessing are declared research
choices, not certified as the challenge's exact hidden-test
submission protocol. These results must be described as **source-label
oracle ID association**, not leaderboard scores or scientifically
certified physical metrology.

For real detector-to-tracker HOTA, first execute frozen models on
original fish pixels and compare to independent multi-fish GT.
Fraunhofer ricefish archive acquisition and oracle association
are developed in Waves 14C/14D; SFISHTRACK adds field
generalization when source verified.

Scientific acceptance is still open in issues #46 and #51.
