# Independent surveyed target tables: structural checks cannot
# authenticate real physical measurements or cross-tank independence.
.cov100_targets <- function() {
 n<-9L
 data.frame(trial_id="T1",tank_id="TANK",session_id="S",
  camera_a_id="TOP",camera_b_id="SIDE",
  target_id=paste0("P",seq_len(n)),
  target_group=c(rep("CALIB",6),rep("HOLDOUT",3)),
  partition=c(rep("fit",6),rep("holdout",3)),
  truth_x=seq(0,.8,length.out=n),truth_y=sin(seq_len(n)),
  truth_z=rep(c(1,2,3),3),
  a_u_px=seq_len(n)*.1,a_v_px=seq_len(n)*.2,
  b_u_px=seq_len(n)*.3,b_v_px=seq_len(n)*.4)
}
test_that("underwater calibration target registry enforces separate physical groups", {
 d<-.cov100_targets()
 expect_error(aqt_target_trial_table(list()),"Expected nonempty measured XYZ")
 expect_error(aqt_target_trial_table(d[FALSE,,drop=FALSE]),
              "Expected nonempty measured XYZ")
 bad<-d;bad$trial_id[1]<-""
 expect_error(aqt_target_trial_table(bad),"Physical target identifiers")
 bad<-d;bad$target_id[1]<-NA_character_
 expect_error(aqt_target_trial_table(bad),"Physical target identifiers")
 bad<-d;bad$truth_y<-as.character(bad$truth_y)
 expect_error(aqt_target_trial_table(bad),"finite numeric")
 bad<-d;bad$a_v_px[1]<-Inf
 expect_error(aqt_target_trial_table(bad),"finite numeric")
 bad<-d;bad$partition[1]<-"unknown"
 expect_error(aqt_target_trial_table(bad),"partition must be fit or holdout")
 bad<-d;bad$camera_a_id[1]<-"SIDE"
 expect_error(aqt_target_trial_table(bad),"Two distinct physical cameras")
 bad<-d;bad$camera_a_id[1]<-"OTHER"
 expect_error(aqt_target_trial_table(bad),"fixed camera pair")
 bad<-d;bad$target_id[2]<-bad$target_id[1]
 expect_error(aqt_target_trial_table(bad),"Duplicate physical target ID")
 bad<-d;bad$truth_x[2]<-bad$truth_x[1]
 bad$truth_y[2]<-bad$truth_y[1]
 bad$truth_z[2]<-bad$truth_z[1]
 expect_error(aqt_target_trial_table(bad),"Repeated surveyed XYZ")
 bad<-d;bad$partition[6]<-"holdout"
 expect_error(aqt_target_trial_table(bad),"requires >=6 fit and >=3")
 bad<-d;bad$target_group[7]<-"CALIB"
 expect_error(aqt_target_trial_table(bad),"assemblies must be disjoint")
 bad<-d;bad$truth_z[7:9]<-1
 expect_error(aqt_target_trial_table(bad),"depth variation")
 valid<-aqt_target_trial_table(d,units="cm")
 expect_s3_class(valid,"aqt_target_trials")
 expect_identical(attr(valid,"aqt_pixel_contract"),
                  "externally_undistorted_image_pixels")
 expect_false(attr(valid,"aqt_external_xyz_survey_verified"))
 expect_false(attr(valid,"aqt_calibration_certified"))
 expect_error(aqt_target_holdout_benchmark(list(),list()),"Expected aqt_target_trials")
 expect_error(aqt_target_holdout_benchmark(valid,list()),"Provide named refractive")
 expect_error(aqt_target_holdout_benchmark(valid,list(A=1,B=2)),"Provide named refractive")
})
