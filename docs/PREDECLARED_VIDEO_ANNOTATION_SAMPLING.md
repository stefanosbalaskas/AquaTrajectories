# Wave 11E — prespecified independent fish-video annotation sampling

## Why this matters

It is invalid to evaluate fish trackers only on the images in which
YOLO/ByteTrack found identifiable fish. That systematically excludes
missed fish, no-fish frames and difficult conditions, distorting
precision/recall and potential fish identity stability.

The sampling frame must come from **video acquisition records before
inspecting the predictions**. AquaTrajectories now supports an
explicit time-stratified design based on the acquired frame PTS,
not nominal FPS or the detector's selected frame IDs.

## Creating a sampling plan

~~~r
library(aquaTrajectories)
# Contains every actual decoded/acquired frame, including zero-fish ones.
frames <- aqt_frame_manifest(
  read.csv("/path/to/tank1_top.frames.csv"))

plan <- aqt_annotation_frame_plan(
  frames,per_video=60L,strata=6L,seed=31L)
print(plan[,c("session_id","camera_id","frame_id","time_s",
             "temporal_stratum","selection_probability",
             "annotation_status")])
print(aqt_annotation_plan_audit(plan,frames)$per_video)
write.csv(plan,"prespecified_frames_for_human_review.csv",
          row.names=FALSE)
~~~

Frames are independently selected for each (session,camera) recording.
Time spans are divided into six equal-duration intervals in this example.
The number of sample frames per stratum is as even as possible; when
it is not perfectly divisible, remainder samples go to the earliest
strata under the documented deterministic rule.

Selection is random **among actually acquired frames within each
stratum**, preserving the caller's global R RNG state. If a duration
stratum contains too few acquired frames, the sampler fails rather
than substituting frames from easier periods. A large missing-video
interval may require a revised registered sample design.

## Data contracts

Every selected frame is initially marked:
\`annotation_status = "planned_not_annotated"\`.

These are NOT reference ground truth. Human reviewers must inspect
full-resolution raw footage and mark each selected frame as fully
annotated only after completing all fish boxes and identity labels,
including confirmed zero-fish frames. The external review protocol
must record reviewers, masking, adjudication, species-class mapping,
uncertainty and raw-footage provenance. The bundle scorer refuses
non-fully-annotated rows when this status column is supplied.

After review, the fully annotated frame table can be used as
\`evaluated_frames\` for \`aqt_video_bundle_benchmark()\`. The
\`annotation_status\` column must be changed only after actual review,
never as a shortcut to bypass scoring safeguards.

The returned sample has \`selection_probability\` and
\`inverse_selection_probability\` for transparent sampling coverage
and potential future design-based estimators. Existing per-frame
precision/recall/IDF1 computations are NOT automatically reweighted,
so the returned inclusion weights must not be misrepresented as
already-implemented inverse-probability-corrected inference.

## Audit and limits

\`aqt_annotation_plan_audit(plan,frames)\` checks per-video support,
frame/time consistency, unique selected frames, temporal stratum
coverage and declared selection probabilities. It distinguishes
sampled frames from truly fully annotated frames.

Even a flawless sampling-plan software test does not validate the
correctness of human ground-truth boxes, species recognition or fish
IDs. Fish and video frames within one tank remain dependent, and
an independently randomized tank is the experimental unit for
tank-level interventions. Sampling across videos, tanks and species
needs a declared external study design.

This is a protocol for collecting evaluation truth. No real fish
annotations or performance estimates have been fabricated.
