# Publication Visualization 2.0: exact original-row evidence and fail-closed
# export qualifications. These are deterministic *synthetic* fish tracks.

.viz2_fixture <- function() {
  d<-data.frame(session_id="S",camera_id="TOP",track_id="0007",
    frame_id=c(0L,1L,2L,4L,5L,6L),
    time_s=c(0,1,2,3,4,5),
    x=c(0,1,NA,3,4,5),y=c(0,0,NA,0,0,0),
    observed=c(TRUE,TRUE,FALSE,TRUE,TRUE,TRUE),
    source_row=paste0("source-",1:6),stringsAsFactors=FALSE)
  aqt_tracks(d,units="cm",coordinate_system="tank")
}

test_that("VIZ2 specification preserves source points and only eligible segments", {
  tr<-.viz2_fixture()
  pristine<-serialize(tr,NULL,version=3L)
  q<-aqt_qc2_report(tr,gap_limits_s=c(1.01,2.01))
  expect_error(aqt_viz2_spec(q,figure="paths"),"explicit policy_id")
  s<-aqt_viz2_spec(q,figure="paths",policy_id="QC001",
                    preset="journal_single",caption="Synthetic only")
  expect_s3_class(s,"aqt_viz2_spec")
  expect_equal(nrow(s$points),6L)
  expect_equal(nrow(s$qc_decisions),6L)
  expect_equal(nrow(s$segments),3L)
  expect_identical(s$segments$to_source_row,
                   c("source-2","source-5","source-6"))
  expect_false(any(s$segments$to_source_row=="source-4"))
  expect_equal(s$counts$n_observed_positions,5L)
  expect_equal(s$counts$n_not_estimable,3L)
  expect_identical(s$provenance$coordinate_units,"cm")
  expect_equal(s$segments$speed,rep(1,3))
  expect_identical(serialize(tr,NULL,version=3L),pristine)
  expect_identical(aqt_viz2_presets()$preset,
    c("journal_single","journal_double","manuscript","presentation"))
  expect_equal(aqt_viz2_gallery()$function_name,
    sort(grep("^aqt_plot_",getNamespaceExports("aquaTrajectories"),
              value=TRUE)))
  expect_equal(sum(aqt_viz2_gallery()$optional_backend),6L)
})

test_that("VIZ2 gap policy, frame skip, projection and multi-camera errors fail closed", {
  tr<-.viz2_fixture()
  spec<-aqt_viz2_spec(tr,figure="speed",gap_limit_s=1.01)
  expect_equal(nrow(spec$segments),3L)
  expect_true(all(spec$segments$dt_s==1))
  expect_error(aqt_viz2_spec(tr,figure="speed"),"finite positive")
  expect_error(aqt_viz2_spec(tr,figure="paths",
                             gap_limit_s=1,plane="xz"),
               "true 3D")
  expect_error(aqt_viz2_spec(tr,figure="unknown",gap_limit_s=1),"arg")
  q<-aqt_qc2_report(tr,gap_limits_s=1.01,step_limits=.5)
  expect_error(aqt_viz2_spec(q,figure="speed"),
               "No eligible speed observations")
  quiet<-aqt_viz2_spec(q,figure="paths")
  expect_equal(nrow(quiet$segments),0)
  expect_equal(sum(quiet$qc_decisions$step_status=="excluded_by_policy"),3L)
  g<-tr
  more<-as.data.frame(g)
  more$camera_id<-"SIDE"
  more$source_row<-paste0("SIDE-",more$source_row)
  both<-aqt_tracks(rbind(as.data.frame(g),more),
                   units="cm",coordinate_system="tank")
  expect_error(aqt_viz2_spec(both,figure="paths",gap_limit_s=1.01),
               "Specify camera_id")
  selected<-aqt_viz2_spec(both,figure="paths",gap_limit_s=1.01,
                          camera_id="TOP")
  expect_equal(nrow(selected$points),nrow(tr))
  qbad<-q
  qbad$lineage$step_eligible[2L]<-TRUE
  expect_error(aqt_viz2_spec(qbad),"modified after scientific audit")
  altered<-spec
  altered$segments$speed[1L]<-200
  expect_error(aqt_viz2_draw(altered),"modified after")
})

test_that("VIZ2 all four formats and all-data SHA256 verification are transactional", {
  skip_if_not(capabilities("png") && capabilities("tiff") && capabilities("cairo"))
  tr<-.viz2_fixture()
  f<-tempfile(fileext=".csv")
  on.exit(unlink(f),add=TRUE)
  source_rows<-as.data.frame(tr)
  source_rows$z<-NULL # preserve 2D column types on CSV reimport
  utils::write.csv(source_rows,f,row.names=FALSE)
  q<-aqt_qc2_report(f,gap_limits_s=1.01,units="cm",
                    coordinate_system="tank")
  fig<-aqt_viz2_spec(q,figure="paths",source_file=f,
                      preset="manuscript",caption="Synthetic source fixture")
  out<-tempfile("aqt-viz2-",tmpdir=tempdir())
  on.exit(unlink(out,recursive=TRUE,force=TRUE),add=TRUE)
  aqt_viz2_export(fig,out,formats=c("svg","pdf","png","tiff"))
  files<-c("figure.svg","figure.pdf","figure.png","figure.tiff",
    "FIGURE_MANIFEST.json","VIZ2_MANIFEST.json",
    "PLOTTED_SOURCE_POINTS.csv","ELIGIBLE_SOURCE_SEGMENTS.csv",
    "ALL_QC_ROW_DECISIONS.csv","SELECTED_QC_POLICY.csv")
  expect_true(all(file.exists(file.path(out,files))))
  expect_true(all(file.info(file.path(out,files))$size>0))
  expect_true(aqt_viz2_verify(out))
  expect_true(aqt_viz2_verify(out,source_file=f))
  m<-jsonlite::fromJSON(file.path(out,"VIZ2_MANIFEST.json"),
                        simplifyVector=FALSE)
  expect_identical(m$data_provenance$source_file_sha256,
    unname(digest::digest(f,file=TRUE,algo="sha256")))
  expect_equal(m$counts$n_eligible_steps,3L)
  for(nm in names(m$output_sha256))expect_identical(
    m$output_sha256[[nm]],
    unname(digest::digest(file.path(out,nm),file=TRUE,algo="sha256")))
  expect_error(aqt_viz2_export(fig,out,formats="pdf"),"new path")
  modified<-fig
  modified$caption<-"invalid mutable change"
  reject<-tempfile("no-output-")
  expect_error(aqt_viz2_export(modified,reject,formats="pdf"),"modified")
  expect_false(file.exists(reject))
  file.create(file.path(out,"unrelated.txt"))
  writeLines("changed",file.path(out,"PLOTTED_SOURCE_POINTS.csv"))
  expect_error(aqt_viz2_verify(out),"SHA-256 mismatch")
})

test_that("VIZ2 source-file change is blocked and measured 3D is projection-only",{
  tr<-.viz2_fixture()
  file<-tempfile(fileext=".csv")
  on.exit(unlink(file),add=TRUE)
  source_rows<-as.data.frame(tr)
  source_rows$z<-NULL
  utils::write.csv(source_rows,file,row.names=FALSE)
  q<-aqt_qc2_report(file,gap_limits_s=1.1,units="cm",
                    coordinate_system="tank")
  s<-aqt_viz2_spec(q,"paths",source_file=file)
  writeLines("modified",file)
  expect_error(aqt_viz2_draw(s),"source file changed")
  d<-as.data.frame(tr)
  d$z<-ifelse(d$observed,2*d$x,NA_real_)
  tr3<-aqt_tracks(d,units="cm",coordinate_system="tank")
  spec<-aqt_viz2_spec(tr3,figure="paths",
                      gap_limit_s=1.01,plane="xz")
  expect_equal(spec$segments$x1,c(1,4,5))
  expect_equal(spec$segments$y1,c(2,8,10))
  expect_equal(spec$segments$full_step_distance,
    rep(sqrt(5),3),tolerance=1e-12)
  vel<-aqt_viz2_spec(tr3,figure="speed",gap_limit_s=1.01,plane="xz")
  expect_equal(vel$segments$speed,rep(sqrt(5),3),tolerance=1e-12)
})

test_that("VIZ2 actual graphics differ between eligible and policy-rejected paths",{
  skip_if_not_installed("png")
  skip_if_not(capabilities("png"))
  tr<-.viz2_fixture()
  loose<-aqt_viz2_spec(tr,"paths",gap_limit_s=1.01)
  strict<-aqt_viz2_spec(
     aqt_qc2_report(tr,gap_limits_s=1.01,step_limits=.5),"paths")
  file1<-tempfile(fileext=".png");file2<-tempfile(fileext=".png")
  on.exit(unlink(c(file1,file2)),add=TRUE)
  render<-function(spec,file) {
    grDevices::png(file,width=650,height=450,res=100)
    tryCatch(aqt_viz2_draw(spec),finally=grDevices::dev.off())
    png::readPNG(file)
  }
  a<-render(loose,file1)
  b<-render(strict,file2)
  expect_identical(dim(a),dim(b))
  expect_gt(mean(abs(a-b)),.00002)
  expect_equal(loose$counts$n_source_rows,strict$counts$n_source_rows)
  expect_equal(strict$counts$n_eligible_steps,0L)
})

test_that("VIZ2 exporting zero eligible segments is verifiable and source-linked",{
  skip_if_not(capabilities("png"))
  tr<-.viz2_fixture()
  spec<-aqt_viz2_spec(aqt_qc2_report(tr,1.1,step_limits=.5),
                      "qc_reasons")
  destination<-tempfile("zero-seg-viz2-")
  on.exit(unlink(destination,recursive=TRUE,force=TRUE),add=TRUE)
  aqt_viz2_export(spec,destination,formats="pdf")
  expect_true(aqt_viz2_verify(destination))
  z<-utils::read.csv(file.path(destination,"ELIGIBLE_SOURCE_SEGMENTS.csv"))
  expect_equal(nrow(z),0L)
  pts<-utils::read.csv(file.path(destination,"PLOTTED_SOURCE_POINTS.csv"))
  expect_equal(nrow(pts),6L)
})
