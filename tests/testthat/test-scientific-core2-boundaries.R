# Scientific Core 2.0 — boundary coverage of EXISTING kernels and exports.
# No animal/video ground truth. No source mutation.

test_that("R research configuration rejects unsupported or misleading analyses", {
  config <- getFromNamespace(".aqt_research_config","aquaTrajectories")
  original <- config(list())
  expect_identical(original$event_clock,"unspecified")
  expect_equal(original$min_visible_fish,2L)
  invalid <- list(
    list(bad_parameter=123),
    list(max_gap_s=-1),
    list(functional_max_gap_s=0),
    list(min_visible_fish=1L),
    list(max_pairs=0L),
    list(event_min_points=-1L),
    list(experimental_draws=0L),
    list(event_clock="inferred"),
    list(event_outcome="animal_stress"),
    list(event_estimator="invalid"),
    list(functional_model="unknown_model"),
    list(experimental_contrast=NA),
    list(functional_contrast="TRUE"),
    list(treatment_levels=c("control","control")),
    list(experimental_contrast=TRUE,experimental_draws=20L),
    list(functional_contrast=TRUE,experimental_draws=20L),
    list(functional_grid_s=c(0,0,1)),
    list(functional_grid_s=1),
    list(min_fish_fraction=0),
    list(min_fish_fraction=1.1),
    list(uncertainty=list(enabled=TRUE)),
    list(uncertainty=list(enabled=TRUE,sigma=.1,draws=10L)),
    list(uncertainty=list(unknown=TRUE)),
    list(uncertainty=list(enabled=NA))
  )
  for (entry in invalid) expect_error(config(entry))
  expect_identical(config(list(max_gap_s=.15))$max_gap_s,.15)
  expect_identical(config(list(uncertainty=list(enabled=TRUE,
    sigma=.2,draws=40L)))$uncertainty$draws,40L)
})

test_that("QC sensitivity rejects malformed clocks, positions and out-of-domain policies", {
  x <- data.frame(session_id="S",camera_id="C",track_id="A",
                  frame_id=c(0,1,2),time_s=c(0,.1,.2),
                  x=c(0,1,2),y=c(0,0,0),observed=TRUE)
  tr <- aqt_tracks(x)
  expect_error(aqt_qc_sensitivity(tr,gap_limits_s=.11,
                                  speed_limits=c(Inf,Inf)),"unique")
  expect_error(aqt_qc_sensitivity(tr,gap_limits_s=.11,
                                  step_limits=-1),"positive")
  expect_error(aqt_qc_sensitivity(tr,gap_limits_s=.11,
                                  speed_limits=0),"positive")
  expect_error(aqt_qc_sensitivity(tr,gap_limits_s=seq(.1,.8,length.out=8),
                                  speed_limits=seq(1,9,length.out=9)),
               "64 QC policies")
  bad <- x;bad$frame_id <- c(0,2,1)
  expect_error(aqt_qc_sensitivity(aqt_tracks(bad),gap_limits_s=.11),
               "strictly increase")
  bad <- x;bad$frame_id[2] <- NA_real_
  expect_error(aqt_qc_sensitivity(aqt_tracks(bad),gap_limits_s=.11),
               "finite nonnegative")
  bad <- x;bad$frame_id[2] <- .25
  expect_error(aqt_qc_sensitivity(aqt_tracks(bad),gap_limits_s=.11),
               "integer-valued")
})

test_that("figure exports guard input, widths, formats and source evidence", {
  good <- function() graphics::plot(1:6,1:6)
  dest <- tempfile("aqt-core2-boundary-")
  on.exit(unlink(dest,recursive=TRUE),add=TRUE)
  expect_error(aqt_figure_export(2,dest),"zero-argument")
  expect_error(aqt_figure_export(function(x) graphics::plot(x),dest),"zero-argument")
  expect_error(aqt_figure_export(good,dest,formats=c("png","png")),"unique")
  expect_error(aqt_figure_export(good,dest,formats="jpeg"),"unique")
  expect_error(aqt_figure_export(good,dest,width=1),"2..20")
  expect_error(aqt_figure_export(good,dest,height=30),"2..20")
  expect_error(aqt_figure_export(good,dest,dpi=40),"72..1200")
  expect_error(aqt_figure_export(good,dest,dpi=121.5),"72..1200")
  expect_error(aqt_figure_export(good,dest,caption=NA_character_),"character")
  expect_error(aqt_figure_export(good,dest,source_file="nonexistent.bin"),"existing file")
  expect_false(file.exists(dest))
})

test_that("all available raster/vector formats are real files and hash-audited", {
  formats <- c("pdf")
  if(capabilities("png"))formats <- c(formats,"png")
  if(capabilities("tiff"))formats <- c(formats,"tiff")
  if(capabilities("cairo"))formats <- c(formats,"svg")
  out <- tempfile("aqt-core2-four-formats-")
  on.exit(unlink(out,recursive=TRUE),add=TRUE)
  aqt_figure_export(function() graphics::plot(0:3,c(0,1,4,9)),out,
                    formats=formats,dpi=144L,caption="Known-answer graphic")
  m <- jsonlite::fromJSON(file.path(out,"FIGURE_MANIFEST.json"),
                          simplifyVector=FALSE)
  expect_setequal(unlist(m$formats),formats)
  for(fmt in formats) {
    file <- paste0("figure.",fmt)
    expect_gt(file.info(file.path(out,file))$size,100)
    expect_identical(m$output_sha256[[file]],
      unname(digest::digest(file.path(out,file),file=TRUE,algo="sha256")))
  }
})
