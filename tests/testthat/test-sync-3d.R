test_that("sync marker fit recovers known offset and affine clock", {
  m <- data.frame(camera_id=rep(c("REF","SIDE"),each=3),
      marker_id=rep(letters[1:3],2),
      time_s=c(10,20,30,9,19,29))
  s <- aqt_sync_fit(m,"REF")
  side <- s[s$camera_id=="SIDE",,drop=FALSE]
  expect_equal(side$intercept_s,1,tolerance=1e-9)
  expect_equal(side$slope,1,tolerance=1e-9)
  x <- aqt_tracks(data.frame(session_id="S1",camera_id="SIDE",
      track_id="F",time_s=c(9,19),x=c(0,1),y=c(0,1)))
  aligned <- aqt_sync_apply(x,s)
  expect_equal(aligned$time_s,c(10,20))
})

test_that("pinhole DLT recovers an exact known 3D point", {
  P1 <- cbind(diag(3),c(0,0,0))
  P2 <- cbind(diag(3),c(-1,0,0))
  xyz <- aqt_triangulate_pairs(matrix(c(.5,.25),nrow=1),
        matrix(c(.25,.25),nrow=1),P1,P2)
  expect_true(xyz$valid)
  expect_equal(unlist(xyz[1,c("x","y","z")],use.names=FALSE),
        c(2,1,4),tolerance=1e-8)
  expect_lt(xyz$reprojection_rmse,1e-8)
  expect_error(aqt_triangulate_pairs(matrix(1,2,2),matrix(1,3,2),P1,P2),
               "matched")
})
