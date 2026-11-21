# Synthetic, known-truth evidence safeguards; no claim of fish validation.

.evidence_fixture <- function() {
  b <- data.frame(recording=11025,phase="Before",
    time_s=rep(c(.1,1.1,2.1),each=3),speed=5,
    track_id=rep(c("01","02","03"),3),stringsAsFactors=FALSE)
  d <- data.frame(recording=11025,phase="During",
    time_s=c(rep(.1,3),rep(1.1,3),rep(2.1,100)),
    speed=c(rep(2,6),rep(10,100)),
    track_id=as.character(seq_len(106)),stringsAsFactors=FALSE)
  z <- rbind(b,d)
  z$x <- seq_len(nrow(z)) %% 11
  z$y <- (seq_len(nrow(z))*3) %% 17
  z$bbox_area <- seq_len(nrow(z)) %% 80 + 1
  z
}

test_that("known synthetic sign reversal is not concealed", {
  z <- .evidence_fixture()
  old <- serialize(z,NULL)
  a <- aqt_compare_specifications(z,window_widths=c(1,2),
    reference_phase="Before")
  expect_identical(serialize(z,NULL),old)
  expect_true(a$stability$direction_reversal[1])
  p <- subset(a$contrasts,method=="pooled_steps" & phase=="During")
  w <- subset(a$contrasts,method=="time_window_equal" &
                window_width==1 & phase=="During")
  expect_equal(p$difference,5)
  expect_equal(w$difference,-3)
  expect_equal(a$estimates$group[1],"11025")
  expect_true(all(a$estimates$n_steps>0))
  expect_true("track_id_equal" %in% a$estimates$method)
  z$fragment_id <- paste(z$track_id,seq_len(nrow(z)),sep="-")
  f <- aqt_compare_specifications(z,fragment_col="fragment_id",window_widths=1)
  expect_true("fragment_equal" %in% f$estimates$method)
  expect_error(aqt_compare_specifications(z,window_widths=c(0,3)),
               "window_widths")
})

test_that("source axis metadata forbids false metric 3D interpretation", {
  axes <- data.frame(axis=c("x","y","z"),
    variable=c("x","y","depth"),
    unit=c("px","px","cm"),
    calibrated=c(FALSE,FALSE,FALSE))
  mixed <- aqt_measurement_contract(axes)
  expect_false(mixed$physical_3d_eligible)
  expect_match(mixed$claim,"prohibited")
  physical <- axes
  physical$unit <- c("cm","mm","m")
  physical$calibrated <- TRUE
  expect_false(aqt_measurement_contract(physical)$physical_3d_eligible)
  good <- aqt_measurement_contract(physical,
            common_frame_verified=TRUE,calibration_reference="survey-001")
  expect_true(good$physical_3d_eligible)
  expect_error(aqt_measurement_contract(axes[1:2,,drop=FALSE]),"unique x")
  f <- tempfile(fileext=".pdf")
  grDevices::pdf(f)
  tryCatch({
    expect_length(aqt_source_3axis_preview(
      data.frame(x=seq_len(20),y=seq_len(20)*2,depth=seq_len(20)*3),
      mixed),20)
  },finally=grDevices::dev.off())
  unlink(f)
})

test_that("independent biological units require explicit verified design", {
  z <- .evidence_fixture()
  loose <- aqt_inference_readiness(z)
  expect_false(loose$animal_level_eligible)
  expect_false(loose$experimental_contrast_eligible)
  expect_false(loose$causal_effect_certified)
  expect_match(loose$supported_claim,"Recording-level")
  t <- data.frame(recording=1:4,tank=c("A","B","C","D"),
    treatment=c("Control","Control","Fed","Fed"))
  verified <- aqt_inference_readiness(t,tank_col="tank",
    treatment_col="treatment",tanks_independent_verified=TRUE)
  expect_true(verified$experimental_contrast_eligible)
  expect_false(verified$causal_effect_certified)
  expect_error(aqt_inference_readiness(
    rbind(t,t[1,,drop=FALSE])[,c("recording","tank","treatment")],
    tank_col="tank",treatment_col="treatment",
    animal_ids_verified=NA),"TRUE or FALSE")
  t$treatment[1] <- "Fed"
  expect_error(aqt_inference_readiness(t,tank_col="tank",
    treatment_col="treatment"),NA)
})

test_that("spatial coverage limits and unequal sampling are explicit", {
  z <- data.frame(recording="A",phase=rep(c("Before","After"),each=90),
    time_s=rep(rep(0:8,each=10),2),
    x=rep(1:10,18),y=rep(11:20,18))
  ok <- aqt_spatial_support(z,window_width=1,grid=c(4,4),
    min_points_per_window=10,min_windows=5)
  expect_true(all(ok$summary$supported))
  expect_true(all(is.finite(ok$summary$normalized_entropy)))
  expect_true(all(is.finite(ok$comparisons$js_divergence)))
  z <- z[-which(z$phase=="After" & z$time_s>1),,drop=FALSE]
  poor <- aqt_spatial_support(z,window_width=1,grid=c(4,4),
    min_points_per_window=10,min_windows=5)
  expect_false(poor$summary$supported[poor$summary$phase=="After"])
  expect_true(is.na(poor$comparisons$js_divergence))
})

test_that("geometry diagnostics do not mistake overlap for causal adjustment", {
  z <- .evidence_fixture()
  g <- aqt_geometry_bias_audit(z,n_strata=3,min_per_stratum=1,
    x_col="x",y_col="y")
  expect_true(nrow(g$correlations)>=2)
  expect_true(all(c("rho_image_x","rho_image_y","rho_confidence") %in%
    names(g$correlations)))
  expect_true(all(c("reference_coverage","comparison_coverage",
                    "coverage_ok") %in% names(g$overlap)))
  expect_match(g$claim,"not causal")
})

test_that("placebo cuts are explicitly noninferential and not p-values", {
  z <- data.frame(recording="A",phase=rep("Before",12),
                  time_s=0:11,speed=c(1:6,8:13))
  p <- aqt_placebo_boundaries(z,window_width=1,min_windows_per_side=3)
  expect_equal(nrow(p$cuts),7)
  expect_false(any(grepl("^p(_|value)",names(p$cuts))))
  expect_match(p$warning,"not p-values")
})

test_that("report export seals hashes and refuses overwrite", {
  z <- .evidence_fixture()
  spec <- aqt_compare_specifications(z,window_widths=1)
  ready <- aqt_inference_readiness(z)
  axes <- data.frame(axis=c("x","y","z"),
    variable=c("x","y","bbox_area"),
    unit=c("px","px","source"),calibrated=FALSE)
  report <- aqt_evidence_report(spec,ready,
    measurement=aqt_measurement_contract(axes),
    spatial=aqt_spatial_support(z,min_points_per_window=1,
                              min_windows=1,window_width=1),
    geometry=aqt_geometry_bias_audit(z,min_per_stratum=1,n_strata=3))
  expect_true(any(report$status$status=="sensitive"))
  expect_true(any(grepl("experimental contrasts are not supported",
                        report$statements)))
  parent <- tempfile("aqt_evidence_")
  dir.create(parent);on.exit(unlink(parent,recursive=TRUE),add=TRUE)
  target <- file.path(parent,"report")
  old <- serialize(report,NULL)
  aqt_evidence_export(report,target)
  expect_identical(serialize(report,NULL),old)
  expect_true(file.exists(file.path(target,"sha256_manifest.csv")))
  ledger <- utils::read.csv(file.path(target,"sha256_manifest.csv"))
  expect_true(nrow(ledger)>=5L)
  hashes <- vapply(seq_len(nrow(ledger)),function(i)
    unname(digest::digest(file=file.path(target,ledger$file[i]),
                           algo="sha256")),character(1L))
  expect_identical(hashes,ledger$sha256)
  expect_error(aqt_evidence_export(report,target),"new output directory")
})
