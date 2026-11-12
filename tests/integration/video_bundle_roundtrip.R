# Run after python tests/python/generate_video_bundle_fixture.py PATH.
# Uses exact bytes from the same Python runner that can accept actual
# GoPro frames; the decoder/YOLO are mocked and are NOT real fish trials.
args <- commandArgs(trailingOnly=TRUE)
if (length(args)!=1L || !dir.exists(args[1L]))
  stop("Require an existing Python video-bundle fixture directory")
suppressPackageStartupMessages(library(aquaTrajectories))
folder <- args[1L]

tracked <- aqt_video_bundle_import(folder,"tracked")
stopifnot(inherits(tracked,"aqt_video_bundle"))
stopifnot(nrow(tracked$frames)==3L)
stopifnot(nrow(tracked$tracks)==2L)
stopifnot(identical(as.numeric(tracked$frames$frame_id),c(0,1,2)))
stopifnot(isTRUE(all.equal(tracked$frames$time_s,c(0,.055,.17),
                           tolerance=1e-10)))
stopifnot(identical(as.character(tracked$tracks$track_id),c("7","7")))
stopifnot(identical(as.character(tracked$tracks$class_id),c("0","0")))
stopifnot(tracked$output_sha256_verified)
stopifnot(!tracked$fish_identity_accuracy_certified)

annotated <- data.frame(session_id="S1",camera_id="TOP",
                        frame_id=0:2)
truth_boxes <- data.frame(
  session_id="S1",camera_id="TOP",frame_id=0:1,
  class_id="0",xmin=c(10,11),ymin=20,
  xmax=c(20,21),ymax=30)
truth_tracks <- data.frame(
  session_id="S1",camera_id="TOP",frame_id=0:1,
  track_id="verified_in_synthetic_fixture",x=c(15,16),y=25,
  class_id="0")
evaluation <- aqt_video_bundle_benchmark(
  tracked,truth_boxes,truth_tracks,annotated,
  max_position_error_px=.01)
all <- evaluation$detection[evaluation$detection$class_id=="ALL",]
stopifnot(nrow(all)==1L,all$TP==2,all$FP==0,all$FN==0)
stopifnot(all$F1==1)
stopifnot(evaluation$tracking$IDF1==1)
stopifnot(evaluation$annotated_frame_fraction==1)
stopifnot(!evaluation$independent_annotation_source_verified)

empty <- aqt_video_bundle_import(folder,"empty")
stopifnot(inherits(empty,"aqt_video_bundle"),
          nrow(empty$frames)==2L,
          nrow(empty$tracks)==0L,
          nrow(empty$classes)==0L,
          isTRUE(empty$output_sha256_verified),
          !empty$fish_identity_accuracy_certified)
cat("PASS Python runner -> MOT/PTS/SHA/class sidecar -> R tracking benchmark\n")
