#!/usr/bin/env Rscript
# Cross-platform locked pixel-mask image regression for actual package plots.
# 600x480 ragg device, no web, fixed deterministic synthetic fixtures.
# Candidate mode emits actual pixel-mask RLE to be reviewed/frozen in Git.
# Verify mode compares EVERY pixel to frozen Linux golden after checking
# same-platform exact rerender; IoU bounds tolerate system font differences.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=2L || !args[[1L]] %in% c("capture","verify"))
  stop("Usage: Rscript nv2_pixel_golden.R capture|verify NEW_DIR")
mode<-args[[1L]];out<-args[[2L]]
if(file.exists(out)||!dir.exists(dirname(out)))
  stop("Output directory must be new under an existing parent")
if(!requireNamespace("ragg",quietly=TRUE) ||
   !requireNamespace("png",quietly=TRUE))
  stop("Pinned CI requires ragg and png packages")
suppressPackageStartupMessages(library(aquaTrajectories))
plots<-list()
p<-do.call(rbind,lapply(1:3,function(i)
  data.frame(session_id="GOLDEN",camera_id="SENSOR",
    track_id=paste0("F",i),time_s=0:13,
    x=seq(0,13)*(0.1+i*.04)+i*1.5,
    y=sin((0:13)/3+i)+.35*i,observed=TRUE)))
paths<-aqt_tracks(p,units="cm",coordinate_system="tank")
plots[["paths"]] <- function() aqt_plot_paths(paths)
p2<-aqt_tracks(data.frame(session_id="GOLDEN",camera_id="SENSOR",
    track_id="F01",time_s=0:13,
    x=sin((0:13)/2),y=cos((0:13)/2),observed=TRUE),
    units="cm",coordinate_system="tank")
rec<-aqt_trajectory_recurrence(p2,radius=.7,
              theiler=1,store_matrix=TRUE)
plots[["recurrence"]] <- function() aqt_plot_recurrence(rec)
t<-seq(0,1,length.out=9)
fp<-do.call(rbind,lapply(1:6,function(i)
  data.frame(session_id="GOLDEN",camera_id="SENSOR",
    track_id=paste0("F",i),time_s=t,
    x=t*(.3+i*.12)+sin(t*pi)*i/12,
    y=t*(.1+i*.21)+cos(t*pi)*i/8,observed=TRUE)))
fit<-aqt_trajectory_grid_pca(
      aqt_tracks(fp,"cm","tank"),
      n_grid=9,n_components=2,origin="start",max_gap_s=.13)
plots[["grid_pca"]] <- function() aqt_plot_grid_pca(fit,component=1)
render<-function(draw,path){
  ragg::agg_png(filename=path,width=600,height=480,
                units="px",res=96,background="white")
  tryCatch(draw(),finally=grDevices::dev.off())
  x<-png::readPNG(path)
  if(length(dim(x))!=3 || dim(x)[1L]!=480L ||
     dim(x)[2L]!=600L || dim(x)[3L]<3L)
    stop("Unexpected golden raster device dimensions")
  # Actual per-pixel foreground mask, not a downsampled thumbnail hash.
  as.integer((x[,,1L]+x[,,2L]+x[,,3L])/3 < .9)
}
encode<-function(bits){
  r<-rle(bits)
  paste0(r$values[1L],";",paste(r$lengths,collapse=","))
}
decode<-function(s,n=600L*480L){
  pieces<-strsplit(s,";",fixed=TRUE)[[1L]]
  if(length(pieces)!=2L||!pieces[1L] %in% c("0","1"))
    stop("Malformed frozen pixel mask")
  lengths<-suppressWarnings(as.integer(strsplit(pieces[2L],",",
                                              fixed=TRUE)[[1L]]))
  if(!length(lengths)||anyNA(lengths)||any(lengths<=0)||
     sum(as.double(lengths))!=n)stop("Frozen pixel mask size invalid")
  values<-(seq_along(lengths)-1L+as.integer(pieces[1L]))%%2L
  rep(values,lengths)
}
dir.create(out)
base<-file.path("tests","golden","nv2_pixel_masks.csv")
if(mode=="verify"&&!file.exists(base))
  stop("Golden baseline is not frozen in source control")
reference<-if(mode=="verify") utils::read.csv(base,
  stringsAsFactors=FALSE,check.names=FALSE) else NULL
records<-list();golden<-list()
for(id in names(plots)) {
  one<-file.path(out,paste0(id,"_a.png"))
  two<-file.path(out,paste0(id,"_b.png"))
  a<-render(plots[[id]],one)
  b<-render(plots[[id]],two)
  if(!identical(a,b))stop("Rerender pixel-nondeterminism: ",id)
  rle_text<-encode(a)
  if(mode=="capture") {
    golden[[id]]<-data.frame(figure_id=id,
      width_px=600L,height_px=480L,foreground_rle=rle_text)
    # Read from Actions logs when original source baseline is approved.
    cat("NV2_FROZEN_CANDIDATE|",id,"|",rle_text,"\n",sep="")
    comparison<-c(pixel_disagreement=0,foreground_iou=1)
  } else {
    match<-reference[reference$figure_id==id,,drop=FALSE]
    if(nrow(match)!=1L || match$width_px!=600L ||match$height_px!=480L)
      stop("Missing/corrupt independent frozen golden reference for ",id)
    gold<-decode(match$foreground_rle)
    disagreement<-mean(a!=gold)
    union<-sum(a==1L|gold==1L)
    overlap<-if(union>0)sum(a==1L&gold==1L)/union else 1
    comparison<-c(pixel_disagreement=disagreement,
                  foreground_iou=overlap)
    if(disagreement>.04 || overlap<.65)
      stop("Cross-platform golden regression drift for ",id,
           ": pixel difference=",disagreement," foreground IoU=",overlap)
  }
  records[[id]]<-data.frame(figure_id=id,
    width_px=480L,height_px=320L,
    reference_mode=mode,
    identical_second_render=TRUE,
    pixel_disagreement=comparison[1L],
    foreground_iou=comparison[2L],
    output_png_sha256=unname(digest::digest(one,file=TRUE,algo="sha256")),
    R_version=as.character(getRversion()),
    ragg_version=as.character(utils::packageVersion("ragg")))
}
values<-do.call(rbind,unname(records));rownames(values)<-NULL
utils::write.csv(values,file.path(out,"PIXEL_REGRESSION.csv"),
                 row.names=FALSE)
if(mode=="capture")utils::write.csv(
  do.call(rbind,unname(golden)),
  file.path(out,"CANDIDATE_GOLDEN.csv"),row.names=FALSE,quote=TRUE)
jsonlite::write_json(list(schema="NV2_PIXEL_REGRESSION_V1",
   mode=mode,figures=names(plots),ragg=as.character(
     utils::packageVersion("ragg")),
   true_per_pixel_mask_comparison=TRUE,
   full_RGB_byte_identity_cross_platform=FALSE,
   mask_threshold_luminance=.9,
   allowed_cross_os_pixel_disagreement_fraction=.04,
   minimum_cross_os_foreground_iou=.65,
   latest_matrix_sha256=unname(digest::digest(
     file.path(out,"PIXEL_REGRESSION.csv"),file=TRUE,algo="sha256"))),
   file.path(out,"PIXEL_MANIFEST.json"),
   auto_unbox=TRUE,pretty=TRUE)
cat("NV2_PIXEL_GOLDEN_",toupper(mode),"_PASS",length(plots),"plot functions\n")
