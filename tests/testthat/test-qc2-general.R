# QC 2.0 — synthetic, explicitly controlled equivalence and lineage evidence.
# These tests do not establish detector, identity or animal welfare accuracy.

test_that("2D/3D source representations agree after declared unit and clock conversion", {
  d <- data.frame(session_id="S",camera_id="TOP",track_id="0007",
    time_s=c(0,1,2,3),x=c(0,1,3,4),y=c(0,0,0,0),
    z=c(1,1,1,1),observed=TRUE,
    frame_id=c(0L,1L,3L,4L),
    source_row=c("row-A","row-B","row-C","row-D"),
    stringsAsFactors=FALSE)
  before <- serialize(d,NULL,version=3L)
  native <- aqt_qc2_report(d,gap_limits_s=c(1.1,2.1),
    speed_limits=c(1.2,5),units="cm",coordinate_system="tank")
  expect_equal(native$dimension,3L)
  expect_equal(unique(native$summary$n_eligible_steps),2L)
  expect_equal(unique(native$summary$path_length),2)
  expect_true(all(native$lineage$reason[
    native$lineage$to_source_row=="row-C"]=="nonadjacent_source_frame"))
  expect_true(all(native$lineage$from_source_row[
    native$lineage$to_source_row=="row-C"]=="row-B"))
  expect_identical(before,serialize(d,NULL,version=3L))
  mm <- data.frame(session="S",camera="TOP",fish="0007",
    t_ms=c(0,1000,2000,3000),x_mm=c(0,10,30,40),
    y_mm=rep(0,4),z_mm=rep(10,4),observed=TRUE,
    frame_id=c(0,1,3,4),rowno=d$source_row)
  map <- c(session_id="session",camera_id="camera",track_id="fish",
           time_s="t_ms",x="x_mm",y="y_mm",z="z_mm",
           observed="observed",frame_id="frame_id",source_row="rowno")
  alias <- aqt_qc2_report(mm,gap_limits_s=c(1.1,2.1),
    speed_limits=c(1.2,5),units="mm",target_units="cm",
    coordinate_system="tank",column_map=map,time_scale=.001)
  expect_equal(alias$summary$path_length,native$summary$path_length)
  expect_equal(alias$summary$n_eligible_steps,native$summary$n_eligible_steps)
  expect_equal(alias$lineage$retained_step_distance,
               native$lineage$retained_step_distance)
  expect_identical(alias$canonical_source_sha256,
                   native$canonical_source_sha256)
  reversed <- d[nrow(d):1L,,drop=FALSE]
  shuffled <- aqt_qc2_report(reversed,gap_limits_s=c(1.1,2.1),
    speed_limits=c(1.2,5),units="cm",coordinate_system="tank")
  expect_identical(shuffled$canonical_source_sha256,
                   native$canonical_source_sha256)
  expect_equal(shuffled$summary$path_length,native$summary$path_length)
  from_tracks <- aqt_qc2_report(aqt_tracks(d,units="cm",
                               coordinate_system="tank"),
                               gap_limits_s=c(1.1,2.1),speed_limits=c(1.2,5))
  expect_equal(from_tracks$summary$path_length,
               native$summary$path_length)
  expect_equal(alias$analysis_units,"cm")
  expect_true(all(alias$lineage$coordinate_units=="cm"))
  expect_identical(alias$raw_source$source_row,d$source_row)
  path <- tempfile(fileext=".csv")
  on.exit(unlink(path),add=TRUE)
  utils::write.csv(mm,path,row.names=FALSE)
  from_csv <- aqt_qc2_report(path,gap_limits_s=c(1.1,2.1),
    speed_limits=c(1.2,5),units="mm",target_units="cm",
    coordinate_system="tank",column_map=map,time_scale=.001)
  expect_identical(unique(from_csv$tracks$track_id),"0007")
  expect_equal(from_csv$summary$path_length,native$summary$path_length)
  expect_identical(from_csv$canonical_source_sha256,
                   native$canonical_source_sha256)
  expect_true(nzchar(from_csv$source_file_sha256))
})

test_that("QC 2.0 separates unobserved, first, rejected and eligible steps", {
  d <- data.frame(track_id="A",time_s=0:5,x=c(0,1,NA,3,4,5),
    y=c(0,0,NA,0,0,0),observed=c(TRUE,TRUE,FALSE,TRUE,TRUE,TRUE),
    source_row=paste0("r",1:6))
  q <- aqt_qc2_report(d,gap_limits_s=1.1,speed_limits=Inf,
    step_limits=2,units="px",coordinate_system="image")
  expect_equal(nrow(q$lineage),6L)
  expect_equal(q$summary$n_source_rows,6L)
  expect_equal(q$summary$n_observed_positions,5L)
  expect_equal(q$summary$n_eligible_steps,3L)
  expect_equal(q$summary$path_length,3)
  expect_true(all(q$lineage$step_status %in%
                  c("eligible","not_estimable","excluded_by_policy")))
  expect_true(all(is.na(q$lineage$from_source_row[
    is.na(q$lineage$from_input_row)])))
  # A gap is not bridged over the unobserved third row.
  expect_false(q$lineage$step_eligible[q$lineage$to_source_row=="r4"])
  expect_identical(q$lineage$reason_detail[q$lineage$to_source_row=="r1"],
                   "first_record_in_track")
  expect_identical(q$lineage$reason_detail[q$lineage$to_source_row=="r3"],
                   "unobserved_current_position")
  expect_identical(q$lineage$reason_detail[q$lineage$to_source_row=="r4"],
                   "unobserved_previous_position")
  expect_equal(unique(q$lineage$coordinate_units),"px")
  expect_equal(q$summary$n_excluded_steps,0L)
})

test_that("QC2 catches ambiguous units, altered source IDs and flags", {
  d <- data.frame(track_id=c("A","A"),time_s=c(0,1),
    x=c(0,1),y=c(0,1),observed=TRUE,source_row=c("a","b"))
  expect_error(aqt_qc2_report(d,1),"source units")
  expect_error(aqt_qc2_report(d,1,units="px",coordinate_system="tank"),
               "Pixel and physical")
  expect_error(aqt_qc2_report(d,1,units="cm",target_units="px",
                              coordinate_system="tank"),"Pixel and physical")
  expect_error(aqt_qc2_report(d,1,units="cm",coordinate_system="tank",
                              time_scale=0),"time_scale")
  duplicate <- d; duplicate$source_row[2] <- "a"
  expect_error(aqt_qc2_report(duplicate,1,units="cm",
                              coordinate_system="tank"),"source_row")
  changed <- d;changed$observed[2] <- FALSE
  expect_error(aqt_qc2_report(changed,1,units="cm",
                              coordinate_system="tank"),"observed")
  expect_error(aqt_qc2_report(d,1,units="cm",coordinate_system="tank",
            column_map=c(track_id="track_id",x="x",y="y")),
            "required mapped fields")
})

test_that("QC 2.0 exported evidence is complete, new-only and checksum-auditable", {
  raw <- data.frame(track_id="A",time_s=0:2,x=0:2,y=0:2,
    source_row=c("alpha","beta","gamma"))
  report <- aqt_qc2_report(raw,gap_limits_s=c(1.1,2.1),
    speed_limits=c(Inf,1.1),units="cm",coordinate_system="tank")
  dest <- tempfile("aqt-qc2-export-")
  on.exit(unlink(dest,recursive=TRUE,force=TRUE),add=TRUE)
  aqt_qc2_export(report,dest)
  want <- c("SOURCE_ROWS.csv","CANONICAL_TRACKS.csv","QC_POLICIES.csv",
    "QC_SUMMARY.csv","QC_EXCLUSIONS.csv","QC_ROW_LINEAGE.csv",
    "README.txt","QC2_MANIFEST.json")
  expect_true(all(file.exists(file.path(dest,want))))
  expect_error(aqt_qc2_export(report,dest),"new path")
  manifest <- jsonlite::fromJSON(file.path(dest,"QC2_MANIFEST.json"),
                                 simplifyVector=FALSE)
  expect_identical(manifest$canonical_source_sha256,
                   report$canonical_source_sha256)
  expect_identical(manifest$raw_table_sha256,report$raw_table_sha256)
  for (name in names(manifest$output_sha256))
    expect_identical(manifest$output_sha256[[name]],
      unname(digest::digest(file.path(dest,name),file=TRUE,algo="sha256")))
  linked <- utils::read.csv(file.path(dest,"QC_ROW_LINEAGE.csv"))
  expect_identical(as.character(linked$to_source_row[1:3]),raw$source_row)
  altered <- report
  altered$raw_source$x[1] <- -99
  expect_error(aqt_qc2_export(altered,tempfile("tamper-qc2-")),
               "modified after audit")
  altered_lineage <- report
  altered_lineage$lineage$retained_step_distance[2L] <- -99
  expect_error(aqt_qc2_export(altered_lineage,tempfile("tamper-ledger-")),
               "QC scientific evidence")
})
