# Source-row scientific figure integrity is checked independently of a
# SHA digest, which alone is not a cryptographic author signature.
.cov100_v2_tracks <- function() {
 aqt_tracks(data.frame(session_id="S",camera_id="TOP",track_id="F",
   time_s=0:4,x=0:4,y=c(0,1,0,1,0),observed=TRUE),
   units="cm",coordinate_system="tank")
}
.cov100_v2_report <- function() {
 aqt_qc2_report(.cov100_v2_tracks(),gap_limits_s=1.1)
}
.cov100_v2_sign <- function(q) {
 q$scientific_evidence_sha256<-aquaTrajectories:::.aqt_viz2_sha(
    list(tracks=q$tracks,policies=q$policies,summary=q$summary,
         exclusions=q$exclusions,lineage=q$lineage))
 q
}
test_that("QC2 figure checks reject plausible but modified metadata", {
 q <- .cov100_v2_report()
 expect_error(aquaTrajectories:::.aqt_viz2_check_qc(list()),
              "Expected a QC 2.0 report")
 bad<-q;bad$schema<-"UNVERIFIED"
 expect_error(aquaTrajectories:::.aqt_viz2_check_qc(bad),
              "Expected a QC 2.0 report")
 bad<-q;bad$lineage$reason_detail[1]<-"edited"
 expect_error(aquaTrajectories:::.aqt_viz2_check_qc(bad),
              "modified after scientific audit")
 s<-aqt_viz2_spec(q,figure="paths")
 bad<-s;bad$points$x[1]<-999
 expect_error(aqt_viz2_draw(bad),"modified after")
 bad$integrity_sha256<-aquaTrajectories:::.aqt_viz2_spec_sha(bad)
 expect_error(aqt_viz2_draw(bad),"Figure points or QC decisions modified")
 bad<-s;bad$segments$speed[1]<-999
 bad$integrity_sha256<-aquaTrajectories:::.aqt_viz2_spec_sha(bad)
 expect_error(aqt_viz2_draw(bad),"Figure points or QC decisions modified")
 bad<-s;bad$qc_decisions$reason_detail[1]<-"changed"
 bad$integrity_sha256<-aquaTrajectories:::.aqt_viz2_spec_sha(bad)
 expect_error(aqt_viz2_draw(bad),"Figure points or QC decisions modified")
})
test_that("QC2 plot assertions cannot be evaded by rehashing an invalid movement ledger", {
 q <- .cov100_v2_report()
 invalid <- q
 invalid$lineage <- invalid$lineage[-1,,drop=FALSE]
 expect_error(aqt_viz2_spec(.cov100_v2_sign(invalid),figure="paths"),
              "QC ledger does not reconcile")
 invalid <- q
 invalid$lineage$step_eligible[1] <- TRUE
 expect_error(aqt_viz2_spec(.cov100_v2_sign(invalid),figure="paths"),
              "Eligible movement lacks matching observed source endpoints")
 invalid <- q
 idx<-which(invalid$lineage$step_eligible)[1L]
 invalid$lineage$from_source_row[idx]<-invalid$lineage$to_source_row[idx]
 expect_error(aqt_viz2_spec(.cov100_v2_sign(invalid),figure="paths"),
              "forward in time")
 invalid <- q
 idx<-which(invalid$lineage$step_eligible)[1L]
 invalid$lineage$retained_step_duration_s[idx] <- 0
 expect_error(aqt_viz2_spec(.cov100_v2_sign(invalid),figure="paths"),
              "invalid distance/time denominators")
})
test_that("QC2 figure scope refuses empty observations and overplotted independent fish",{
 tr<-.cov100_v2_tracks()
 d<-as.data.frame(tr);d$x<-NA_real_;d$y<-NA_real_;d$observed<-FALSE
 empty<-aqt_tracks(d,units="cm",coordinate_system="tank")
 expect_error(aqt_viz2_spec(empty,"paths",gap_limit_s=1.1),
              "No observed positions")
 many <- do.call(rbind,lapply(seq_len(31),function(i)data.frame(
   session_id="S",camera_id="TOP",track_id=sprintf("F%03d",i),
   time_s=0,x=i,y=0,observed=TRUE)))
 all<-aqt_tracks(many,units="cm",coordinate_system="tank")
 expect_error(aqt_viz2_spec(all,"qc_coverage",gap_limit_s=1.1),
              "at most 30 fish")
})
test_that("VIZ2 verifier rejects malformed manifests and external source mismatch",{
 spec<-aqt_viz2_spec(.cov100_v2_tracks(),"paths",gap_limit_s=1.1)
 root<-tempfile("cov100_viz2_")
 dir.create(root)
 on.exit(unlink(root,recursive=TRUE,force=TRUE),add=TRUE)
 out<-file.path(root,"figure")
 expect_invisible(aqt_viz2_export(spec,out,formats="pdf"))
 expect_true(aqt_viz2_verify(out))
 incorrect<-file.path(root,"different_source.csv")
 writeLines("original\ndata",incorrect)
 expect_error(aqt_viz2_verify(out,source_file=incorrect),
              "External original source file SHA-256 mismatch")
 manifest<-file.path(out,"VIZ2_MANIFEST.json")
 source<-jsonlite::fromJSON(manifest,simplifyVector=FALSE)
 corrupted<-source;corrupted$schema<-"NOT_THE_EXPECTED_SCHEMA"
 jsonlite::write_json(corrupted,manifest,pretty=TRUE,auto_unbox=TRUE)
 expect_error(aqt_viz2_verify(out),"Malformed VIZ2 manifest schema")
 jsonlite::write_json(source,manifest,pretty=TRUE,auto_unbox=TRUE)
 expect_true(aqt_viz2_verify(out))
 points<-file.path(out,"PLOTTED_SOURCE_POINTS.csv")
 d<-utils::read.csv(points,stringsAsFactors=FALSE)
 d$source_row[2]<-d$source_row[1]
 utils::write.csv(d,points,row.names=FALSE,na="")
 source$output_sha256[["PLOTTED_SOURCE_POINTS.csv"]]<-
    unname(digest::digest(points,file=TRUE,algo="sha256"))
 jsonlite::write_json(source,manifest,pretty=TRUE,auto_unbox=TRUE)
 expect_error(aqt_viz2_verify(out),"lineage is incomplete or inconsistent")
})
