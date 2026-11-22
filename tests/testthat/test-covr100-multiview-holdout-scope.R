# Synthetic holdout gates: no hardware pulse verification or external XYZ
# survey authenticity is asserted. Fail before any 3D model scoring.
.cov100_protocol_markers <- function() {
  ids <- paste0("P",1:6)
  m <- expand.grid(camera_id=c("A","B","C"),marker_id=ids,
    KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
  m$session_id <- "S"
  m$time_s <- match(m$marker_id,ids)-1+
    ifelse(m$camera_id=="B",2,ifelse(m$camera_id=="C",4,0))
  m
}
.cov100_protocol_targets <- function(a="A",b="B",session="S") {
  n <- 9L
  data.frame(trial_id="T",tank_id="TANK",
     session_id=session,camera_a_id=a,camera_b_id=b,
     target_id=paste0("L",seq_len(n)),
     target_group=c(rep("FIT",6),rep("HOLDOUT",3)),
     partition=c(rep("fit",6),rep("holdout",3)),
     truth_x=seq_len(n)/10,truth_y=seq_len(n)/20,
     truth_z=rep(1:3,3),
     a_u_px=seq_len(n)/10,a_v_px=seq_len(n)/20,
     b_u_px=seq_len(n)/10,b_v_px=seq_len(n)/20)
}
test_that("heldout multiview protocol refuses missing source camera/session clock fits",{
  markers <- .cov100_protocol_markers()
  targets <- .cov100_protocol_targets(session="UNSYNCHRONIZED")
  expect_error(aqt_multiview_holdout_protocol(
     markers,targets,cameras=list(),reference_camera="A",
     train_markers=paste0("P",1:4),
     holdout_markers=paste0("P",5:6)),
     "Every target camera/session needs a heldout sync fit")
})
test_that("heldout multiview protocol refuses a reference camera absent from surveyed pair",{
  markers <- .cov100_protocol_markers()
  targets <- .cov100_protocol_targets(a="B",b="C")
  expect_error(aqt_multiview_holdout_protocol(
     markers,targets,cameras=list(),reference_camera="A",
     train_markers=paste0("P",1:4),
     holdout_markers=paste0("P",5:6)),
     "Surveyed target sessions need the declared reference camera")
})
