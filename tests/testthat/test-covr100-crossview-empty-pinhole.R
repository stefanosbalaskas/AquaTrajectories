# A zero-qualified candidate set still retains its original pinhole
# reprojection error units. It never authenticates biological identities.
test_that("zero valid pinhole crossview candidates retain pixel error units", {
  raw <- data.frame(
    candidate_id="P1",session_id="S",id_a="A",id_b="B",
    time_a_s=0,time_b_s=0,time_skew_s=0,
    reprojection_rmse_px=.05,valid=FALSE,
    stringsAsFactors=FALSE)
  result <- aqt_crossview_auto_associate(raw,min_support=1L)
  expect_identical(result$geometry_error_unit,"px")
  expect_equal(nrow(result$correspondences),0L)
  expect_equal(nrow(result$links),0L)
  expect_identical(result$n_original_candidates,1L)
  expect_identical(result$n_valid_candidates,0L)
  expect_false(result$independent_biological_identity_certified)
})
