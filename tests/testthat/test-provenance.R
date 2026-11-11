test_that("provenance detects changed and removed source files", {
  path <- tempfile(fileext=".csv")
  writeLines("fish,1",path)
  manifest <- aqt_provenance_new(path,metadata=list(detector="manual-reference"))
  ok <- aqt_provenance_verify(manifest)
  expect_equal(ok$status,"match")
  writeLines("fish,2",path)
  changed <- aqt_provenance_verify(manifest)
  expect_equal(changed$status,"changed")
  unlink(path)
  missing <- aqt_provenance_verify(manifest)
  expect_equal(missing$status,"missing")
})

test_that("human-reviewed corrections preserve origin and identity scopes", {
  raw <- data.frame(session_id="S1",camera_id="top",track_id=c("A","A","B","B"),
    time_s=c(0,1,0,1),x=c(0,1,10,11),y=0)
  tr <- aqt_tracks(raw)
  edits <- data.frame(session_id="S1",camera_id="top",
    source_track_id=c("A","B"),target_track_id=c("B","A"),
    start_s=c(1,1),end_s=c(1,1),
    reviewer="observer1",reason="reviewed crossing")
  fixed <- aqt_apply_identity_corrections(tr,edits)
  expect_equal(sum(fixed$identity_corrected),2)
  at_one <- fixed[fixed$time_s==1,,drop=FALSE]
  expect_equal(sort(at_one$track_id),c("A","B"))
  expect_equal(sort(at_one$original_track_id),c("A","B"))
  expect_true(aqt_tracks_validate(fixed))
  expect_error(aqt_apply_identity_corrections(tr,edits[1L,,drop=FALSE]),
               "Duplicate")
})
