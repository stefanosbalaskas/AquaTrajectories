# AquaTrajectories Wave 2: deterministic synthetic validation demonstration
# Educational only. Real fish research requires independently annotated videos.

library(aquaTrajectories)

# Two observed fish, sampled in the SAME camera and frame.
gt_boxes <- data.frame(
  session_id="S01",camera_id="TOP",frame_id="0",
  class_id="seabass",xmin=c(0,20),ymin=c(0,0),
  xmax=c(10,30),ymax=c(10,10)
)
pred_boxes <- rbind(
  transform(gt_boxes[1,,drop=FALSE],confidence=.95),
  data.frame(session_id="S01",camera_id="TOP",frame_id="0",
             class_id="seabass",xmin=40,ymin=0,xmax=50,ymax=10,
             confidence=.8)
)

# One correct detection, one false detection, and one missed fish.
print(aqt_detection_metrics(gt_boxes,pred_boxes,
                            iou_threshold=.5,confidence_threshold=.25))
print(aqt_detection_map(gt_boxes,pred_boxes,iou_thresholds=c(.5,.75)))

# Framewise truth: two stable physical fish over three frames.
reference <- data.frame(session_id="S01",camera_id="TOP",
   frame_id=rep(0:2,2),track_id=rep(c("A","B"),each=3),
   x=c(0,1,2,10,11,12),y=0)

# Detection and positions are perfect; fish A's predicted ID changes.
prediction <- reference
prediction$track_id <- c("1","1","3","2","2","2")

print(aqt_tracking_metrics(reference,prediction,max_distance=.1))

# One identity switch reduces IDF1 even though every fish was detected.
# ID labels in a different camera/session cannot be compared directly.
