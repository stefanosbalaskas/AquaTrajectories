# Coverage-closing tests exercise explicit evidence contracts and real
# unsupported/invalid input pathways. Every outcome is checked, not swallowed.
# Entirely synthetic inputs. No SmartFish files are used.

.cov100_ev_data <- function() {
  d <- data.frame(recording="R01",phase=rep(c("Before","After"),each=24),
    time_s=rep(0:23,2),speed=c(rep(2,24),rep(4,24)),
    track_id=rep(c("1","2","3"),length.out=48),
    x=rep(seq(1,12,length.out=24),2),
    y=rep(seq(2,25,length.out=24),2),
    bbox_area=rep(seq(10,33,length.out=24),2),
    confidence=rep(seq(.1,.9,length.out=24),2),
    eligible=TRUE, policy="strict",stringsAsFactors=FALSE)
  d$fragment <- paste0(d$track_id,"-",seq_len(nrow(d)))
  d
}

test_that("specification audit distinguishes missing, ineligible and unsupported inputs", {
  z <- .cov100_ev_data()
  expect_error(aqt_compare_specifications(data.frame(x=1)),"nonempty data frame")
  expect_error(aqt_compare_specifications(z,min_steps=0),"positive integers")
  expect_error(aqt_compare_specifications(z,min_steps_per_window=0),"positive integers")
  expect_error(aqt_compare_specifications(z,window_widths=c(1,1)),"distinct positive")
  expect_error(aqt_compare_specifications(z,reference_phase="Never"),"reference_phase")
  expect_error(aqt_compare_specifications(z,min_steps=999),"No group meets")
  z$eligible <- FALSE
  expect_error(aqt_compare_specifications(z,eligible_col="eligible"),"No eligible")
  z$eligible <- TRUE
  z$eligible[1] <- NA
  expect_error(aqt_compare_specifications(z,eligible_col="eligible"),"Eligibility")
  z$eligible[1] <- TRUE
  z$eligible <- as.integer(z$eligible)
  expect_error(aqt_compare_specifications(z,eligible_col="eligible"),"Eligibility")
  z$eligible <- TRUE
  expect_true(nrow(aqt_compare_specifications(z,min_steps_per_window=100,
                     window_widths=c(1,2))$estimates)>0)
  a <- aqt_compare_specifications(z,policy_col="policy",
       fragment_col="fragment",eligible_col="eligible",window_widths=1)
  expect_true(all(a$estimates$policy=="strict"))
  expect_true("fragment_equal" %in% a$estimates$method)
  expect_false(any(a$stability$direction_reversal))
  only_before <- z[z$phase=="Before",,drop=FALSE]
  no_contrast <- aqt_compare_specifications(only_before,window_widths=1)
  expect_equal(nrow(no_contrast$contrasts),0L)
  expect_equal(nrow(no_contrast$stability),0L)
  # One insufficient phase must be ignored, not silently treated as another replicate.
  z <- z[c(which(z$phase=="Before"),which(z$phase=="After")[1:2]),]
  partial <- aqt_compare_specifications(z,window_widths=1)
  expect_equal(unique(partial$estimates$phase),"Before")
})

test_that("measurement contracts reject undocumented physical interpretations", {
  axes <- data.frame(axis=c("x","y","z"),variable=c("u","v","depth"),
                     unit=c("px","px","source"),calibrated=FALSE,
                     stringsAsFactors=FALSE)
  bad <- axes
  bad$unit[3] <- "furlongs"
  expect_error(aqt_measurement_contract(bad),"supported unit")
  bad <- axes
  bad$calibrated <- c(TRUE,NA,FALSE)
  expect_error(aqt_measurement_contract(bad),"calibration flag")
  expect_error(aqt_measurement_contract(axes,common_frame_verified=NA),
               "explicit TRUE or FALSE")
  expect_error(aqt_measurement_contract(axes,common_frame_verified=1),
               "explicit TRUE or FALSE")
  expect_error(aqt_measurement_contract(axes,calibration_reference=NA_character_),
               "reference must be a string")
  expect_error(aqt_measurement_contract(axes,calibration_reference=4),
               "reference must be a string")
  contract <- aqt_measurement_contract(axes)
  expect_error(aqt_source_3axis_preview(data.frame(u=1,v=2,depth=3),NULL),
               "Explicit measurement contract")
  empty <- data.frame(u=c(NA_real_,NA_real_),v=c(1,2),depth=c(1,2))
  expect_error(aqt_source_3axis_preview(empty,contract),"No complete")
  expect_error(aqt_source_3axis_preview(data.frame(u=1,v=2,depth=3),
               contract,max_points=0),"max_points")
  physical <- axes
  physical$unit <- "cm"
  physical$calibrated <- TRUE
  physical <- aqt_measurement_contract(physical,
      common_frame_verified=TRUE,calibration_reference="surveyed-001")
  expect_true(physical$physical_3d_eligible)
  pdf <- tempfile(fileext=".pdf")
  grDevices::pdf(pdf)
  on.exit({grDevices::dev.off();unlink(pdf)},add=TRUE)
  constant <- data.frame(u=rep(3,8),v=rep(4,8),depth=rep(5,8))
  expect_length(aqt_source_3axis_preview(constant,physical,max_points=3),3L)
  expect_length(aqt_source_3axis_preview(data.frame(
    u=seq_len(12),v=seq_len(12)*2,depth=seq_len(12)*3),
    contract,max_points=5),5L)
})

test_that("readiness separates validated IDs, tank replication and causal claims", {
  z <- .cov100_ev_data()
  z$animal_id <- paste0("A",z$track_id)
  animal <- aqt_inference_readiness(z,animal_col="animal_id",
       animal_ids_verified=TRUE)
  expect_true(animal$animal_level_eligible)
  expect_false(animal$experimental_contrast_eligible)
  expect_match(animal$supported_claim,"Animal-level")
  t <- data.frame(recording=seq_len(4),tank=LETTERS[1:4],
                  treatment=c("C","C","T","T"))
  expect_error(aqt_inference_readiness(rbind(t,
         data.frame(recording=5,tank="A",treatment="T")),
         tank_col="tank",treatment_col="treatment"),
         "One tank cannot")
  ready <- aqt_inference_readiness(t,tank_col="tank",
       treatment_col="treatment",tanks_independent_verified=TRUE,
       randomization_verified=TRUE)
  expect_true(ready$experimental_contrast_eligible)
  expect_true(ready$randomized_allocation_declared)
  expect_false(ready$causal_effect_certified)
  expect_match(ready$supported_claim,"Independent-tank")
})

test_that("spatial support reports no-data and single-phase boundaries", {
  z <- .cov100_ev_data()
  expect_error(aqt_spatial_support(z,grid=c(1,8)),"integer grid")
  expect_error(aqt_spatial_support(z,window_width=0),"Positive window_width")
  expect_error(aqt_spatial_support(z,min_windows=0),"thresholds")
  bad <- z
  bad$x <- NA_real_
  expect_error(aqt_spatial_support(bad),"No finite positions")
  constant <- z
  constant$x <- 5
  constant$y <- 8
  supported <- aqt_spatial_support(constant,grid=c(2,2),window_width=1,
                        min_points_per_window=1,min_windows=1)
  expect_true(all(supported$summary$supported))
  expect_true(all(supported$summary$normalized_entropy==0))
  partial <- aqt_spatial_support(z,grid=c(2,2),window_width=1,
                        min_points_per_window=99,min_windows=1)
  expect_true(all(!partial$summary$supported))
  expect_true(all(is.na(partial$summary$normalized_entropy)))
  only <- aqt_spatial_support(z[z$phase=="Before",,drop=FALSE],
                       grid=c(2,2),window_width=1,
                       min_points_per_window=1,min_windows=1)
  expect_equal(nrow(only$comparisons),0L)
  expect_equal(nrow(supported$comparisons),1L)
  expect_equal(supported$comparisons$js_divergence,0,tolerance=1e-12)
  expect_true(is.na(aquaTrajectories:::.aqt_ev_entropy(1)))
  expect_equal(aquaTrajectories:::.aqt_ev_median(numeric()),NA_real_)
  expect_equal(aquaTrajectories:::.aqt_ev_median(c(1,2,3)),2)
})

test_that("image-geometry diagnostics identify missing and common-support strata", {
  z <- .cov100_ev_data()
  z$speed <- seq_len(nrow(z)) %% 9 + 1
  expect_error(aqt_geometry_bias_audit(z,n_strata=1),"stratum")
  expect_error(aqt_geometry_bias_audit(z,min_per_stratum=0),"stratum")
  bad <- z
  bad$bbox_area <- 0
  expect_error(aqt_geometry_bias_audit(bad),"No valid")
  no_ref <- aqt_geometry_bias_audit(z,reference_phase="Unknown",
          n_strata=3,min_per_stratum=1)
  expect_equal(nrow(no_ref$overlap),0L)
  constant_area <- z
  constant_area$bbox_area <- 3
  result <- aqt_geometry_bias_audit(constant_area,n_strata=3,
               min_per_stratum=1)
  expect_equal(nrow(result$overlap),0L)
  g <- aqt_geometry_bias_audit(z,n_strata=3,min_per_stratum=1,
          x_col="x",y_col="y",confidence_col="confidence")
  expect_true(nrow(g$overlap)>0)
  expect_true(all(g$overlap$coverage_ok))
  expect_true(is.finite(g$correlations$rho_confidence[1]))
  expect_true(all(c("reference_coverage","comparison_coverage") %in%
                  names(g$overlap)))
})

test_that("placebo cuts do not generate significance from insufficient support", {
  z <- .cov100_ev_data()
  expect_error(aqt_placebo_boundaries(z,window_width=0),"Invalid window")
  expect_error(aqt_placebo_boundaries(z,min_windows_per_side=1),"Invalid window")
  none <- aqt_placebo_boundaries(z,window_width=100,min_windows_per_side=3)
  expect_equal(nrow(none$cuts),0L)
  all_missing <- z
  all_missing$speed <- NA_real_
  no_complete <- aqt_placebo_boundaries(all_missing,window_width=1)
  expect_equal(nrow(no_complete$cuts),0L)
  p <- aqt_placebo_boundaries(z,window_width=1,min_windows_per_side=2)
  expect_true(nrow(p$cuts)>0)
  expect_false(any(grepl("p_value",names(p$cuts),fixed=TRUE)))
})

test_that("evidence report statuses come from the supplied evidence only", {
  z <- .cov100_ev_data()
  z$speed <- 3
  specification <- aqt_compare_specifications(z,window_widths=1)
  t <- data.frame(recording=seq_len(4),tank=LETTERS[1:4],
                  treatment=c("C","C","T","T"))
  ready <- aqt_inference_readiness(t,tank_col="tank",
         treatment_col="treatment",tanks_independent_verified=TRUE)
  expect_error(aqt_evidence_report(NULL,ready),"required")
  expect_error(aqt_evidence_report(specification,ready,measurement=list()),
               "Invalid evidence object")
  bare <- aqt_evidence_report(specification,ready)
  expect_equal(bare$status$status[bare$status$check=="physical_3d"],"not_assessed")
  expect_equal(bare$status$status[bare$status$check=="spatial_support"],"not_assessed")
  axes <- data.frame(axis=c("x","y","z"),variable=c("x","y","z"),
                     unit="cm",calibrated=TRUE)
  physical <- aqt_measurement_contract(axes,TRUE,"surveyed-001")
  sp <- aqt_spatial_support(z,window_width=1,grid=c(2,2),
             min_points_per_window=1,min_windows=1)
  geometry <- aqt_geometry_bias_audit(z,n_strata=3,min_per_stratum=1,
             confidence_col="confidence")
  placebo <- aqt_placebo_boundaries(z,window_width=1,min_windows_per_side=2)
  completed <- aqt_evidence_report(specification,ready,physical,sp,
                                     geometry,placebo)
  by_check <- setNames(completed$status$status,completed$status$check)
  expect_identical(by_check[["direction_stability"]],"no_reversal_detected")
  expect_identical(by_check[["experimental_replication"]],"eligible_association")
  expect_identical(by_check[["physical_3d"]],"declared_eligible")
  expect_identical(by_check[["spatial_support"]],"supported")
  expect_identical(by_check[["geometry_overlap"]],"supported")
  expect_identical(by_check[["placebo_boundary"]],"descriptive_only")
  expect_true(any(grepl("causal identification remains unverified",
                         completed$statements,fixed=TRUE)))
  sparse <- aqt_spatial_support(z,window_width=1,grid=c(2,2),
             min_points_per_window=100,min_windows=1)
  limited <- aqt_evidence_report(specification,ready,spatial=sparse)
  expect_identical(limited$status$status[
    limited$status$check=="spatial_support"],"limited")
  poor_geom <- aqt_geometry_bias_audit(z,n_strata=3,min_per_stratum=100)
  limited_geom <- aqt_evidence_report(specification,ready,geometry=poor_geom)
  expect_identical(limited_geom$status$status[
    limited_geom$status$check=="geometry_overlap"],"limited")
})

test_that("evidence export handles optional placebo and absent comparisons", {
  z <- .cov100_ev_data()
  z <- z[z$phase=="Before",,drop=FALSE]
  specification <- aqt_compare_specifications(z,window_widths=1)
  ready <- aqt_inference_readiness(z)
  placebo <- aqt_placebo_boundaries(z,window_width=1,min_windows_per_side=2)
  report <- aqt_evidence_report(specification,ready,placebo=placebo)
  expect_error(aqt_evidence_export(list(),tempfile()),"Expected an")
  parent <- tempfile("coverage100_export_")
  dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  dest <- file.path(parent,"report")
  result <- aqt_evidence_export(report,dest)
  expect_identical(result,dest)
  expect_true(file.exists(file.path(dest,"within_recording_placebos.csv")))
  expect_false(file.exists(file.path(dest,"specification_contrasts.png")))
  expect_true(file.exists(file.path(dest,"sha256_manifest.csv")))
})

test_that("evidence export refuses a concurrently inserted reserved checksum manifest",{
  d <- .cov100_ev_data()
  d <- d[d$phase=="Before",,drop=FALSE]
  s <- aqt_compare_specifications(d,window_widths=1)
  ready <- aqt_inference_readiness(d)
  report <- aqt_evidence_report(s,ready)
  parent <- tempfile("cov100_manifest_race_");base::dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE,force=TRUE),add=TRUE)
  dest <- file.path(parent,"evidence")
  old <- digest::digest(report,algo="sha256")
  testthat::with_mocked_bindings({
    expect_error(aqt_evidence_export(report,dest),"Manifest collision")
  },dir.create=function(path,...) {
    created <- base::dir.create(path,...)
    if(created)
       writeLines("external collision",file.path(path,"sha256_manifest.csv"))
    created
  },.package="aquaTrajectories")
  expect_identical(digest::digest(report,algo="sha256"),old)
})
