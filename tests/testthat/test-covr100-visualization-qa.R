# Synthetic publication visualization contract tests. These test rendering,
# observed-data provenance and explicit 2D/3D interpretation, not journal compliance.

.cov100_viz_tracks <- function() {
  aqt_tracks(data.frame(session_id="S1",camera_id="C1",track_id="01",
    time_s=c(0,.5,1,1.5,2),x=c(1,2,3,NA,5),y=c(2,3,5,NA,8),
    observed=c(TRUE,TRUE,TRUE,FALSE,TRUE),
    source_row=paste0("point-",1:5)),
    units="cm",coordinate_system="tank")
}

test_that("publication presets and explicitly scoped evidence are necessary", {
  x <- .cov100_viz_tracks()
  expect_error(aqt_viz2_spec(NULL),"validated tracks")
  expect_error(aqt_viz2_spec(x,"paths",gap_limit_s=.6,preset="publisher_approved"),
               "Unknown publication preset")
  expect_error(aqt_viz2_spec(x,"paths",gap_limit_s=.6,caption=NA_character_),
               "caption must")
  expect_error(aqt_viz2_spec(x,"paths",gap_limit_s=.6,caption=c("a","b")),
               "caption must")
  expect_error(aqt_viz2_spec(x,"paths",gap_limit_s=.6,policy_id="wrong"),
               "policy_id not present")
  expect_error(aqt_viz2_spec(x,"paths",gap_limit_s=.6,
               session_id="",camera_id="C1"),"nonempty strings")
  expect_error(aqt_viz2_spec(x,"paths",gap_limit_s=.6,session_id="S2"),
               "Specify camera_id")
  expect_error(aqt_viz2_spec(x,"paths",gap_limit_s=.6,
               session_id="S2",camera_id="C1"),"Selected session/camera")
  expect_error(aqt_viz2_spec(x,"paths",gap_limit_s=.6,source_file="missing_source.csv"),
               "requires a QC 2.0 report")
  q <- aqt_qc2_report(x,gap_limits_s=.6)
  expect_error(aqt_viz2_spec(q,"paths",gap_limit_s=.6),"already owns its gap")
  s <- aqt_viz2_spec(q,"paths",caption="synthetic",plane="xy")
  expect_equal(s$counts$n_source_rows,nrow(x))
  expect_gt(nrow(s$segments),0)
  expect_equal(s$caption,"synthetic")
  altered <- s
  altered$points$x[1] <- -999
  # Structural hash check rejects a post-audit mutation before plotting.
  expect_error(aqt_viz2_draw(altered),"modified")
  multi <- as.data.frame(x)
  multi$session_id <- "S2"
  multi$source_row <- paste0("S2-",multi$source_row)
  both <- aqt_tracks(rbind(as.data.frame(x),multi),
     units="cm",coordinate_system="tank")
  expect_error(aqt_viz2_spec(both,"paths",gap_limit_s=.6),
               "Specify session_id")
  scoped <- aqt_viz2_spec(both,"paths",gap_limit_s=.6,
                           session_id="S2")
  expect_equal(scoped$session_id,"S2")
  expect_equal(nrow(scoped$points),nrow(x))
})

test_that("all four publication plot families execute real draw paths", {
  x <- .cov100_viz_tracks()
  specs <- lapply(c("paths","speed","qc_coverage","qc_reasons"),
    function(f) aqt_viz2_spec(x,figure=f,gap_limit_s=.6))
  names(specs) <- c("paths","speed","qc_coverage","qc_reasons")
  plot <- tempfile(fileext=".pdf")
  grDevices::pdf(plot,width=9,height=6)
  on.exit({grDevices::dev.off();unlink(plot)},add=TRUE)
  for (nm in names(specs)) {
    expect_invisible(aqt_viz2_draw(specs[[nm]]))
  }
  expect_true(any(specs$qc_coverage$qc_decisions$step_status=="eligible"))
  expect_true(all(is.finite(specs$speed$segments$speed)))
  expect_true(length(aquaTrajectories:::.aqt_viz2_range(rep(4,5)))==2L)
  expect_error(aquaTrajectories:::.aqt_viz2_range(c(NA,Inf)),"No finite values")
})

test_that("image-coordinate plots invert pixel Y and do not claim physical XYZ", {
  d <- as.data.frame(.cov100_viz_tracks())
  d$z <- NULL
  tr <- aqt_tracks(d,units="px",coordinate_system="image")
  s <- aqt_viz2_spec(tr,"paths",gap_limit_s=.6)
  file <- tempfile(fileext=".pdf")
  grDevices::pdf(file,width=9,height=6)
  on.exit({grDevices::dev.off();unlink(file)},add=TRUE)
  expect_invisible(aqt_viz2_draw(s))
  expect_error(aqt_viz2_spec(tr,"paths",gap_limit_s=.6,plane="xz"),
               "true 3D")
  three <- as.data.frame(.cov100_viz_tracks())
  three$z <- ifelse(three$observed,three$x*2,NA_real_)
  tr3 <- aqt_tracks(three,units="cm",coordinate_system="tank")
  yzs <- aqt_viz2_spec(tr3,"paths",gap_limit_s=.6,plane="yz")
  expect_identical(yzs$plane,"yz")
  expect_true(any(is.finite(yzs$segments$full_step_distance)))
})

test_that("figure exports fail closed for invalid paths and missing manifests", {
  x <- .cov100_viz_tracks()
  spec <- aqt_viz2_spec(x,"qc_reasons",gap_limit_s=.6)
  existing <- tempfile("viz100_existing_")
  dir.create(existing)
  on.exit(unlink(existing,recursive=TRUE,force=TRUE),add=TRUE)
  expect_error(aqt_viz2_export(spec,existing,formats="pdf"),"new path")
  expect_error(aqt_viz2_export(spec,file.path(existing,"missing_parent","fig"),
             formats="pdf"),"new path")
  expect_error(aqt_viz2_verify(tempfile()),"existing visualization export")
  expect_error(aqt_viz2_verify(existing),"VIZ2 manifest missing")
  file <- tempfile(fileext=".csv")
  on.exit(unlink(file),add=TRUE)
  source <- as.data.frame(x); source$z <- NULL
  utils::write.csv(source,file,row.names=FALSE)
  report <- aqt_qc2_report(file,gap_limits_s=.6,units="cm",
           coordinate_system="tank")
  expect_error(aqt_viz2_spec(report,"paths",source_file=tempfile()),
               "source_file must be an existing data file")
  modified_source <- tempfile(fileext=".csv")
  on.exit(unlink(modified_source),add=TRUE)
  utils::write.csv(data.frame(x=1),modified_source,row.names=FALSE)
  expect_error(aqt_viz2_spec(report,"paths",source_file=modified_source),
               "does not match QC 2.0 input file hash")
})
