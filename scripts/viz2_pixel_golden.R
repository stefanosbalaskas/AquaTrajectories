#!/usr/bin/env Rscript
# Publication Viz2 full-resolution pixel-mask regression of its four new
# QC-aware figure kinds. Native text and font rasterization vary across OS.
# Source-backed locked Linux golden is required in verify mode; no capture
# is misreported as cross-platform comparison.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=2L||!args[[1L]]%in%c("capture","verify")||
   file.exists(args[[2L]])||!dir.exists(dirname(args[[2L]])))
  stop("Use Rscript viz2_pixel_golden.R capture|verify NEW_DIRECTORY")
mode<-args[[1L]];out<-args[[2L]]
if(!requireNamespace("ragg",quietly=TRUE)||
   !requireNamespace("png",quietly=TRUE))
  stop("Install ragg and png to execute actual pixel comparison")
suppressPackageStartupMessages(library(aquaTrajectories))
tt<-0:15
d<-do.call(rbind,lapply(1:3,function(i) {
  # Distinct per-fish velocities keep three actual data series legible.
  yy<-i+cos(tt/2+i*.35)*(.30+.03*i)
  xx<-i*.7+tt*(.12+.05*i)+sin(tt/3+i*.22)*.20
  if(i==3)xx[13L]<-xx[13L]+6
  observed<-!(i==2L & tt==5L)
  data.frame(session_id="PUBLISH",camera_id="TOP",
    track_id=paste0("F",i),
    frame_id=tt+as.integer(tt>=7L),
    time_s=tt,
    x=ifelse(observed,xx,NA_real_),
    y=ifelse(observed,yy,NA_real_),
    observed=observed,
    source_row=paste0(i,"-",sprintf("%03d",tt)),
    stringsAsFactors=FALSE)
}))
tr<-aqt_tracks(d,units="cm",coordinate_system="tank")
qc<-aqt_qc2_report(tr,gap_limits_s=1.01,speed_limits=2)
kinds<-c("paths","speed","qc_coverage","qc_reasons")
specs<-lapply(kinds,function(kind)
 aqt_viz2_spec(qc,figure=kind,policy_id="QC001",
  preset="journal_double",caption="Deterministic synthetic figure"))
names(specs)<-kinds
if(any(vapply(specs,function(s)s$counts$n_eligible_steps==0,
             logical(1L))))
  stop("Pixel fixture must retain nonzero valid observed movement")
encode<-function(bits){
 r<-rle(bits)
 paste0(r$values[1L],";",paste(r$lengths,collapse=","))
}
decode<-function(s,n=600L*480L){
 parts<-strsplit(s,";",fixed=TRUE)[[1L]]
 if(length(parts)!=2L||!parts[1L]%in%c("0","1"))
   stop("Malformed frozen pixel mask")
 lengths<-suppressWarnings(as.integer(strsplit(parts[2L],",",
                                              fixed=TRUE)[[1L]]))
 if(!length(lengths)||anyNA(lengths)||any(lengths<=0)||
    sum(as.double(lengths))!=n)stop("Golden pixel count differs")
 rep((seq_along(lengths)-1L+as.integer(parts[1L]))%%2L,lengths)
}
render<-function(s,path){
 ragg::agg_png(path,width=600,height=480,units="px",res=96,
               background="white")
 tryCatch(aqt_viz2_draw(s),finally=grDevices::dev.off())
 image<-png::readPNG(path)
 if(!is.array(image)||length(dim(image))!=3L||
    dim(image)[1L]!=480L||dim(image)[2L]!=600L||
    dim(image)[3L]<3L)
   stop("Wrong PNG raster geometry")
 as.integer((image[,,1L]+image[,,2L]+image[,,3L])/3<.9)
}
golden_path<-"tests/golden/viz2_pixel_masks.csv"
golden_sha256<-"3c09d9bec4513d13c536435b12b6002a96f6113f8b34de99e5b1f275b5ad01da"
if(mode=="verify"&&!file.exists(golden_path))
  stop("Unreviewed/missing immutable pixel baseline")
baseline<-if(mode=="verify") {
  if(!identical(unname(digest::digest(golden_path,file=TRUE,algo="sha256")),
                golden_sha256))
    stop("Frozen golden image CSV source digest mismatched")
  utils::read.csv(golden_path,stringsAsFactors=FALSE)
} else NULL
dir.create(out)
records<-list(); candidates<-list()
for(kind in kinds) {
 file_a<-file.path(out,paste0(kind,"_A.png"))
 file_b<-file.path(out,paste0(kind,"_B.png"))
 a<-render(specs[[kind]],file_a)
 b<-render(specs[[kind]],file_b)
 if(!identical(a,b))
   stop("Same-platform native pixel nondeterminism: ",kind)
 if(mode=="capture") {
   candidates[[kind]]<-data.frame(figure_id=kind,
     width_px=600L,height_px=480L,foreground_rle=encode(a))
   difference<-0;similarity<-1
   cat("VIZ2_FROZEN_CANDIDATE|",kind,"|",encode(a),"\n",sep="")
 } else {
   entry<-baseline[baseline$figure_id==kind,,drop=FALSE]
   if(nrow(entry)!=1L||entry$width_px!=600L||entry$height_px!=480L)
     stop("No exact frozen 600x480 source reference: ",kind)
   target<-decode(entry$foreground_rle)
   difference<-mean(a!=target)
   area<-sum(a==1L|target==1L)
   similarity<-if(area)sum(a==1L&target==1L)/area else 1
   if(difference>.045||similarity<.58)
     stop("Visual golden regression failed for ",kind,
          "; changed pixels=",difference,"; foreground IoU=",similarity)
 }
 records[[kind]]<-data.frame(figure_id=kind,
   n_pixels=600L*480L,same_os_second_render_identical=TRUE,
   absolute_pixel_disagreement_fraction=difference,
   foreground_intersection_over_union=similarity,
   output_sha256=unname(digest::digest(file_a,file=TRUE,algo="sha256")),
   exact_source_scientific_sha256=qc$scientific_evidence_sha256,
   qc_policy_id="QC001",
   synthetic_fixture=TRUE,stringsAsFactors=FALSE)
 cat("VIZ2_PIXEL_COMPARISON",kind,
     "different",format(difference,digits=8),
     "IoU",format(similarity,digits=8),"\n")
}
metrics<-do.call(rbind,unname(records))
utils::write.csv(metrics,file.path(out,"PIXEL_VIZ2_MATRIX.csv"),row.names=FALSE)
if(mode=="capture")
 utils::write.csv(do.call(rbind,unname(candidates)),
   file.path(out,"CANDIDATE_VIZ2_GOLDEN.csv"),row.names=FALSE,quote=TRUE)
jsonlite::write_json(list(schema="AQT_VIZ2_NATIVE_PIXEL_GOLDEN_V1",
  mode=mode,n_native_figures=length(kinds),
  source_sha256=qc$canonical_source_sha256,
  scientific_qc_sha256=qc$scientific_evidence_sha256,
  rows=nrow(tr),pixels_per_plot=600L*480L,
  max_changed_pixel_fraction=.045,
  min_foreground_iou=.58,
  same_os_bitwise_foreground_determinism=TRUE,
  full_color_RGBA_byte_equality_across_OS=FALSE,
  test_matrix_sha256=unname(digest::digest(
    file.path(out,"PIXEL_VIZ2_MATRIX.csv"),file=TRUE,algo="sha256"))),
  file.path(out,"PIXEL_VIZ2_MANIFEST.json"),
  auto_unbox=TRUE,pretty=TRUE)
cat("VIZ2_PIXEL_GOLDEN_",toupper(mode),"_PASS",length(kinds),"native figures\n")
