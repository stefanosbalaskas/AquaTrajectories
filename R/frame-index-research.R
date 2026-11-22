# Frame-indexed scientific analysis for real source data without measured time.
# The acquisition frame is NOT substituted for a physical timestamp.

#' Frame-indexed aquatic movement and group-geometry analysis
#'
#' Provides descriptive pixel-space observations when no measured camera frame
#' timestamps exist. Only successive recorded frames within an individual
#' camera-local track yield displacement; gaps are never connected. Neither
#' velocity in px/s nor treatment effects are computed. Separate input
#' data_path values (e.g. published reference and actual model predictions)
#' are never treated as matched biological individual IDs.
#'
#' @param frames Data frame: data_path,session_id,camera_id,frame_id,
#'   width_px,height_px,time_s. Frames must be complete 0..N-1 in each scope;
#'   time_s must be entirely absent/blank/NA.
#' @param observations Data frame: data_path,session_id,camera_id,frame_id,
#'   track_id,x,y, bounding-box centre coordinates in pixels. Optional
#'   bbox_left,bbox_top,bbox_width,bbox_height,detection_confidence,
#'   annotation_status are preserved unchanged.
#' @param occupancy_bins Grid bins per image axis, 2..50.
#' @param max_fish_per_frame Pairwise geometry computational guard, 2..200.
#' @return List of original rows, frame coverage, adjacent-frame displacements,
#'   within-frame group geometry, normalized-image occupancy, scoped summaries
#'   and scientific warnings. Class aqt_frame_index_study.
#' @export
aqt_frame_index_analyze <- function(frames,observations,
                                    occupancy_bins=8L,
                                    max_fish_per_frame=200L) {
  if(!is.data.frame(frames) || !is.data.frame(observations) ||
     !nrow(frames) || !nrow(observations))
    stop("Nonempty frame and observation data frames required",call.=FALSE)
  frame_required <- c("data_path","session_id","camera_id","frame_id",
                      "width_px","height_px","time_s")
  obs_required <- c("data_path","session_id","camera_id","frame_id",
                    "track_id","x","y")
  if(!all(frame_required %in% names(frames)) ||
     !all(obs_required %in% names(observations)))
    stop("Missing required frame-index source columns",call.=FALSE)
  for(v in list(occupancy_bins,max_fish_per_frame))
    if(!is.numeric(v) || length(v)!=1L || !is.finite(v) ||
       v!=floor(v))stop("Grid and complexity controls must be integers",call.=FALSE)
  if(occupancy_bins<2L || occupancy_bins>50L ||
     max_fish_per_frame<2L || max_fish_per_frame>200L)
    stop("Grid or complexity control outside safe bounds",call.=FALSE)
  f <- as.data.frame(frames,stringsAsFactors=FALSE)
  o <- as.data.frame(observations,stringsAsFactors=FALSE)
  # Explicitly reject the tempting but false convenience of FPS-derived time.
  if(any(!is.na(f$time_s) & nzchar(trimws(as.character(f$time_s)))))
    stop("Use the time-aware AquaTrajectories pipeline for timed recordings; this method accepts unknown timestamps only",call.=FALSE)
  for(nm in c("data_path","session_id","camera_id")) {
    f[[nm]] <- as.character(f[[nm]])
    o[[nm]] <- as.character(o[[nm]])
    if(anyNA(f[[nm]]) || anyNA(o[[nm]]) ||
       any(!nzchar(f[[nm]])) || any(!nzchar(o[[nm]])))
      stop("Missing frame/observation scope",call.=FALSE)
  }
  o$track_id <- as.character(o$track_id)
  if(anyNA(o$track_id) || any(!nzchar(o$track_id)))
    stop("Track ID cannot be missing",call.=FALSE)
  for(nm in c("frame_id","width_px","height_px")) {
    if(!is.numeric(f[[nm]]) || anyNA(f[[nm]]) ||
       any(!is.finite(f[[nm]])) || any(f[[nm]]!=floor(f[[nm]])))
      stop("Frame numbers and dimensions must be integer-valued",call.=FALSE)
  }
  if(any(f$frame_id<0) || any(f$width_px<=0) || any(f$height_px<=0))
    stop("Invalid frame ID or image dimensions",call.=FALSE)
  if(!is.numeric(o$frame_id) || anyNA(o$frame_id) ||
     any(!is.finite(o$frame_id)) || any(o$frame_id<0) ||
     any(o$frame_id!=floor(o$frame_id)))
    stop("Invalid observation frame index",call.=FALSE)
  for(nm in c("x","y"))
    if(!is.numeric(o[[nm]]) || anyNA(o[[nm]]) ||
       any(!is.finite(o[[nm]])))
      stop("Observed coordinates must be finite numeric",call.=FALSE)
  key <- function(d,with_frame=TRUE,with_track=FALSE) {
    x <- list(d$data_path,d$session_id,d$camera_id)
    if(with_frame)x <- c(x,list(d$frame_id))
    if(with_track)x <- c(x,list(d$track_id))
    do.call(paste,c(x,sep="\r"))
  }
  fk <- key(f)
  if(anyDuplicated(fk))stop("Duplicate acquired frame scope",call.=FALSE)
  scope <- key(f,FALSE)
  for(idx in split(seq_len(nrow(f)),scope)) {
    ids <- sort(f$frame_id[idx])
    if(!identical(as.double(ids),as.double(seq.int(0L,length(idx)-1L))))
      stop("Frame manifest must contain every recorded local frame 0..N-1",call.=FALSE)
    if(length(unique(f$width_px[idx]))!=1L ||
       length(unique(f$height_px[idx]))!=1L)
      stop("Variable image geometry requires a different workflow",call.=FALSE)
  }
  ok <- match(key(o),fk)
  if(anyNA(ok))stop("Observation references missing original frame",call.=FALSE)
  if(anyDuplicated(key(o,TRUE,TRUE)))
    stop("Duplicate camera-local identity within a frame",call.=FALSE)
  if(any(o$x<0 | o$y<0 | o$x>f$width_px[ok] | o$y>f$height_px[ok]))
    stop("Observed centres outside source image",call.=FALSE)
  if("detection_confidence" %in% names(o)) {
    z <- suppressWarnings(as.numeric(o$detection_confidence))
    supplied <- !is.na(o$detection_confidence) &
      nzchar(as.character(o$detection_confidence))
    if(any(supplied & (!is.finite(z) | z<0 | z>1)))
      stop("Nonfinite or invalid model detection confidence",call.=FALSE)
  }
  o <- o[order(o$data_path,o$session_id,o$camera_id,
               o$track_id,o$frame_id),,drop=FALSE]
  rownames(o) <- NULL
  o$previous_frame_id <- NA_integer_
  o$step_dx_px <- NA_real_
  o$step_dy_px <- NA_real_
  o$step_distance_px <- NA_real_
  o$missing_intervening_observations <- FALSE
  track_scope <- key(o,FALSE,TRUE)
  for(idx in split(seq_len(nrow(o)),track_scope)) {
    if(length(idx)<2L)next
    frame_gap <- diff(o$frame_id[idx])
    if(any(frame_gap<=0))stop("Nonincreasing frame within scoped track",call.=FALSE)
    end <- idx[-1L]
    o$previous_frame_id[end] <- o$frame_id[idx[-length(idx)]]
    o$missing_intervening_observations[end] <- frame_gap>1
    adjacent <- frame_gap==1
    if(any(adjacent)) {
      j <- end[adjacent]
      previous <- idx[-length(idx)][adjacent]
      dx <- o$x[j]-o$x[previous]
      dy <- o$y[j]-o$y[previous]
      o$step_dx_px[j] <- dx
      o$step_dy_px[j] <- dy
      o$step_distance_px[j] <- sqrt(dx^2+dy^2)
    }
  }
  obs_count <- table(key(o))
  f$n_observed <- as.integer(obs_count[match(fk,names(obs_count))])
  f$n_observed[is.na(f$n_observed)] <- 0L
  f$observed_frame <- f$n_observed>0L
  f <- f[order(f$data_path,f$session_id,f$camera_id,f$frame_id),,
         drop=FALSE]
  rownames(f) <- NULL
  # Geometry is observed within one frame and one data origin only.
  geom <- lapply(split(seq_len(nrow(o)),key(o)),function(idx) {
    a <- o[idx,,drop=FALSE]
    n <- nrow(a)
    center <- c(mean(a$x),mean(a$y))
    rg <- sqrt(mean((a$x-center[1])^2+(a$y-center[2])^2))
    nn <- NA_real_
    if(n>=2L && n<=max_fish_per_frame) {
      m <- as.matrix(stats::dist(a[,c("x","y")]))
      diag(m) <- Inf
      nn <- mean(apply(m,1L,min))
    }
    data.frame(data_path=a$data_path[1],session_id=a$session_id[1],
      camera_id=a$camera_id[1],frame_id=a$frame_id[1],
      n_visible=n,centroid_x_px=center[1],centroid_y_px=center[2],
      radius_of_gyration_px=if(n>=2L)rg else NA_real_,
      mean_nearest_neighbor_px=nn,
      geometry_eligible=(n>=2L && n<=max_fish_per_frame))
  })
  g <- do.call(rbind,geom)
  rownames(g) <- NULL
  g <- g[order(g$data_path,g$session_id,g$frame_id),,drop=FALSE]
  # Image-normalized occupancy is an observation distribution, not a
  # missingness-corrected biologically valid habitat selection estimate.
  ix <- match(key(o),key(f))
  bins <- as.integer(occupancy_bins)
  a <- pmin(bins-1L,floor(o$x/f$width_px[ix]*bins))
  b <- pmin(bins-1L,floor(o$y/f$height_px[ix]*bins))
  occupancy <- stats::aggregate(rep(1L,nrow(o)),
    by=list(data_path=o$data_path,session_id=o$session_id,
            camera_id=o$camera_id,bin_x=a,bin_y=b),FUN=sum)
  names(occupancy)[ncol(occupancy)] <- "n_observations"
  summaries <- lapply(split(seq_len(nrow(f)),key(f,FALSE)),function(idx) {
    z <- f[idx,,drop=FALSE]
    oi <- which(o$data_path==z$data_path[1] &
                o$session_id==z$session_id[1] &
                o$camera_id==z$camera_id[1])
    d <- o[oi,,drop=FALSE]
    data.frame(data_path=z$data_path[1],session_id=z$session_id[1],
      camera_id=z$camera_id[1],n_recorded_frames=nrow(z),
      n_frames_with_observations=sum(z$observed_frame),
      n_frames_without_observations=sum(!z$observed_frame),
      n_observations=nrow(d),n_local_track_labels=length(unique(d$track_id)),
      n_adjacent_frame_steps=sum(is.finite(d$step_distance_px)),
      n_unbridged_within_track_gaps=sum(d$missing_intervening_observations),
      observed_path_sum_px=sum(d$step_distance_px,na.rm=TRUE),
      n_frames_with_pair_geometry=sum(g$data_path==z$data_path[1] &
        g$session_id==z$session_id[1] &g$camera_id==z$camera_id[1] &
        g$geometry_eligible))
  })
  s <- do.call(rbind,summaries)
  rownames(s) <- NULL
  result <- list(frames=f,observations=o,group_geometry=g,
    occupancy=occupancy,summary=s,
    diagnostics=c(
      "Time status: UNKNOWN. No measured timestamps supplied; no px/s, acceleration, or physical-time quantities.",
      "2D image-pixel coordinates; no camera calibration, no cm and no underwater 3D reconstruction.",
      "Original published fish identity labels not independently human re-adjudicated.",
      "Model-local identity labels are not interchangeable with reference identities.",
      "No experimental event, treatment, independent tank replication or causal/stress inference.",
      "Observed movement is lower-bound conditional path displacement only; gaps are not bridged.",
      "School geometry and occupancy are descriptive and affected by detection/identity incompleteness."),
    metadata=list(frame_index_origin=0L,position_units="px",
      step_units="px/adjacent_recorded_frame",
      elapsed_time_status="unknown",independent_identity_validated=FALSE,
      physical_calibration_validated=FALSE,statistical_treatment_inference=FALSE,
      occupancy_bins=bins,max_fish_per_frame=max_fish_per_frame))
  class(result) <- "aqt_frame_index_study"
  result
}

#' Publish a frame-indexed observation-quality and movement report
#'
#' Does not infer physical time, match reference/model fish identities, or
#' conceal frames with no observations. Produces independent source-specific
#' scientific plots, HTML with embedded SVG, vector PDFs, CSVs and an RDS.
#'
#' @param study Output of aqt_frame_index_analyze().
#' @param directory New directory; parent must exist.
#' @return Directory invisibly.
#' @export
aqt_frame_index_publish <- function(study,directory) {
  if(!inherits(study,"aqt_frame_index_study") ||
     !is.list(study$summary) && !is.data.frame(study$summary))
    stop("Expected aqt_frame_index_study",call.=FALSE)
  if(!is.character(directory) || length(directory)!=1L || is.na(directory) ||
     file.exists(directory) || !dir.exists(dirname(directory)))
    stop("Output directory must be new and parent must already exist",call.=FALSE)
  directory <- normalizePath(directory,mustWork=FALSE)
  dir.create(directory)
  complete <- FALSE
  on.exit(if(!complete && dir.exists(directory))
      unlink(directory,recursive=TRUE,force=TRUE),add=TRUE)
  dir.create(file.path(directory,"figures"))
  dir.create(file.path(directory,"tables"))
  tables <- list(
    "M07_PER_SEQUENCE_SUMMARY.csv"=study$summary,
    "M07_FRAME_COVERAGE.csv"=study$frames,
    "M07_OBSERVATION_STEP_QC.csv"=study$observations,
    "M07_GROUP_GEOMETRY.csv"=study$group_geometry,
    "M07_OBSERVED_OCCUPANCY.csv"=study$occupancy)
  for(nm in names(tables))
    utils::write.csv(tables[[nm]],file.path(directory,"tables",nm),
                     row.names=FALSE,na="")
  saveRDS(study,file.path(directory,"M07_FRAME_INDEX_ANALYSIS.rds"),
          version=3)
  paths <- unique(as.character(study$frames$data_path))
  seqs <- sort(unique(as.character(study$frames$session_id)))
  palette <- c(reference="#126c83",model="#cc6a30")
  color <- function(p) if(p %in% names(palette))palette[[p]] else "#515f72"
  empty_panel <- function(title,message) {
    graphics::plot.new(); graphics::title(main=title)
    graphics::text(.5,.5,message,cex=.9)
  }
  plot_one <- function(seq,family) {
    for(p in paths) {
      f <- study$frames[study$frames$session_id==seq &
                         study$frames$data_path==p,,drop=FALSE]
      o <- study$observations[study$observations$session_id==seq &
                             study$observations$data_path==p,,drop=FALSE]
      g <- study$group_geometry[study$group_geometry$session_id==seq &
                                study$group_geometry$data_path==p,,drop=FALSE]
      ttl <- paste(seq,p)
      if(family=="paths") {
        if(!nrow(o)) {empty_panel(ttl,"No observed tracks");next}
        w <- f$width_px[1];h <- f$height_px[1]
        graphics::plot(0,0,type="n",xlim=c(0,w),ylim=c(h,0),asp=1,
          main=ttl,xlab="Image X (px)",ylab="Image Y (px)")
        # Original points are always displayed, but connect ONLY contiguous
        # acquisition frames for the same scoped identity.
        good <- is.finite(o$step_distance_px) & !is.na(o$previous_frame_id)
        eligible <- which(good)
        if(length(eligible)) {
          trackkey <- paste(o$track_id,sep="")
          loc <- paste(trackkey,o$frame_id,sep="\r")
          prev <- paste(trackkey[eligible],o$previous_frame_id[eligible],sep="\r")
          j <- match(prev,loc)
          if(anyNA(j))stop("Adjacent-frame source segment cannot be reconstructed",call.=FALSE)
          graphics::segments(o$x[j],o$y[j],o$x[eligible],o$y[eligible],
                             col=grDevices::adjustcolor(color(p),alpha.f=.45))
        }
        graphics::points(o$x,o$y,pch=16,cex=.32,
                         col=grDevices::adjustcolor(color(p),alpha.f=.48))
      } else if(family=="coverage") {
        graphics::plot(f$frame_id,f$n_observed,type="h",col=color(p),
          main=ttl,xlab="Local recorded frame (not seconds)",
          ylab="Observed scoped fish IDs",lwd=1.2)
      } else if(family=="group") {
        if(!nrow(g) || !any(is.finite(g$radius_of_gyration_px))) {
          empty_panel(ttl,"No qualified multi-fish group geometry");next
        }
        graphics::plot(g$frame_id,g$radius_of_gyration_px,type="l",
          col=color(p),lwd=1.2,main=ttl,
          xlab="Local recorded frame (not seconds)",
          ylab="Radius of gyration (px)")
      } else if(family=="occupancy") {
        t <- study$occupancy[study$occupancy$data_path==p &
                            study$occupancy$session_id==seq,,drop=FALSE]
        n <- study$metadata$occupancy_bins
        zz <- matrix(0,nrow=n,ncol=n)
        if(nrow(t))
          for(i in seq_len(nrow(t)))
            zz[t$bin_x[i]+1L,t$bin_y[i]+1L] <-
              zz[t$bin_x[i]+1L,t$bin_y[i]+1L]+t$n_observations[i]
        graphics::image(seq(0,1,length.out=n),seq(0,1,length.out=n),
                        zz,main=ttl,xlab="Normalized image X",
                        ylab="Normalized image Y",col=grDevices::hcl.colors(30,"YlOrRd"))
      } else stop("Unknown plot family")
    }
    graphics::mtext(paste0("Separate track-ID namespaces; source timestamps unknown; descriptive image space only"),
                    side=1,outer=TRUE,line=1.0,cex=.62)
  }
  figure_catalog <- list()
  for(seq in seqs) for(family in c("paths","coverage","group","occupancy")) {
    name <- paste0(seq,"_",family)
    render <- function(fmt) {
      dest <- file.path(directory,"figures",paste0(name,".",fmt))
      if(fmt=="svg") {
        # Base Cairo SVG is not reliably available on headless macOS runners.
        # svglite is suggested, never imported unconditionally; the fallback
        # remains available when a working system Cairo device is present.
        if(requireNamespace("svglite",quietly=TRUE))
          svglite::svglite(file=dest,width=11,height=5.4,
                           pointsize=10,bg="white")
        else grDevices::svg(dest,width=11,height=5.4,pointsize=10)
      }
      else if(fmt=="pdf") grDevices::pdf(dest,width=11,height=5.4,
                                            useDingbats=FALSE)
      else grDevices::png(dest,width=2200,height=1080,res=200)
      tryCatch({
        graphics::par(mfrow=c(1,length(paths)),oma=c(2.4,0,0,0))
        plot_one(seq,family)
      },finally=grDevices::dev.off())
      if(!file.exists(dest) || is.na(file.info(dest)$size) ||
         file.info(dest)$size<100)
        stop("Incomplete scientific figure: ",dest,call.=FALSE)
      if(fmt=="svg") {
        svg_text <- paste(readLines(dest,warn=FALSE,encoding="UTF-8"),
                          collapse="\n")
        if(!grepl("<svg",svg_text,fixed=TRUE) ||
           !grepl("</svg>",svg_text,fixed=TRUE))
          stop("Malformed SVG scientific figure: ",dest,call.=FALSE)
      }
      dest
    }
    for(fmt in c("svg","pdf","png"))render(fmt)
    figure_catalog[[length(figure_catalog)+1L]] <-
      data.frame(figure=name,sequence=seq,family=family,
        svg=paste0("figures/",name,".svg"),
        pdf=paste0("figures/",name,".pdf"),
        png=paste0("figures/",name,".png"),
        status="complete",stringsAsFactors=FALSE)
  }
  catalogue <- do.call(rbind,figure_catalog)
  utils::write.csv(catalogue,file.path(directory,"FIGURE_CATALOG.csv"),
                   row.names=FALSE)
  markdown_table <- function(z) {
    zz <- z
    for(j in names(zz)){
      if(is.numeric(zz[[j]]))zz[[j]] <- format(signif(zz[[j]],6L),trim=TRUE)
      zz[[j]] <- gsub("[\r\n|]"," ",as.character(zz[[j]]))
    }
    paste(c(paste0("| ",paste(names(zz),collapse=" | ")," |"),
      paste0("| ",paste(rep("---",ncol(zz)),collapse=" | ")," |"),
      apply(zz,1,function(r)paste0("| ",paste(r,collapse=" | ")," |"))),
      collapse="\n")
  }
  notes <- study$diagnostics
  md <- c("# AquaTrajectories - real BrackishMOT dual-path research demonstration","",
    "**Descriptive frame-indexed analysis. Not animal identity accuracy certification or an experiment.**","",
    "## Research inputs","",
    "Path A uses publisher fish annotations (not independently readjudicated). Path B uses genuine frozen fish-model and ByteTrack outputs. Same five source recordings; different track-ID namespaces.","",
    "There are **no measured frame timestamps**; all displacement is **pixels per adjacent recorded frame**, not px/s or cm/s. The nominal sequence FPS is not substituted for exposure times.","",
    "## Full-denominator observed results","",
    markdown_table(study$summary),"",
    "## Scientific limitations and blocked conclusions","",
    paste0("- ",notes),"",
    "## Figures","",
    "Each publication figure provides a source-reference and model-track panel; absent observations remain absent. Occupancy is not corrected for detector missed fish.","",
    unlist(lapply(seq_len(nrow(catalogue)),function(i){
      z <- catalogue[i,];paste0("- [",z$figure,"](",z$pdf,") - [SVG](",z$svg,")")
    })),"",
    "## Evidence contracts","",
    "Upstream source and model input hashes are validated by the Python handoff. Derived table SHA-256 values are recorded in M07_SCIENCE_MANIFEST.json. Neither this report nor its figures are independent manual verification of biological fish ID.","")
  writeLines(md,file.path(directory,"REPORT.md"),useBytes=TRUE)
  # Standalone HTML embeds SVG inline; no external image, JS or network calls.
  html_escape <- function(v) {
    v <- gsub("&","&amp;",as.character(v),fixed=TRUE)
    v <- gsub("<","&lt;",v,fixed=TRUE)
    v <- gsub(">","&gt;",v,fixed=TRUE)
    gsub('"',"&quot;",v,fixed=TRUE)
  }
  to_html_table <- function(z)paste0("<table><thead><tr>",
    paste0("<th>",html_escape(names(z)),"</th>",collapse=""),
    "</tr></thead><tbody>",
    paste(apply(z,1,function(r)paste0("<tr>",
      paste0("<td>",html_escape(r),"</td>",collapse=""),"</tr>")),
      collapse=""),"</tbody></table>")
  figs <- vapply(seq_len(nrow(catalogue)),function(i){
    p <- file.path(directory,catalogue$svg[i])
    svg_text <- paste(readLines(p,warn=FALSE,encoding="UTF-8"),collapse="\n")
    # Remove only XML declaration/DOCTYPE; embed actual vector art in document.
    svg_text <- sub("^<\\?xml[^>]*>\\s*","",svg_text,perl=TRUE)
    svg_text <- sub("^<!DOCTYPE[^>]*>\\s*","",svg_text,perl=TRUE)
    paste0("<section><h3>",html_escape(catalogue$figure[i]),"</h3>",
      svg_text,"</section>")
  },character(1))
  html <- c('<!doctype html><html lang="en"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    '<title>AquaTrajectories - real fish frame-index analysis</title>',
    '<style>body{max-width:1100px;margin:3rem auto;padding:0 1rem;font:16px/1.6 system-ui,sans-serif;color:#24323c}h1,h2,h3{line-height:1.2}table{border-collapse:collapse;width:100%;font-size:13px}th,td{padding:7px;border-bottom:1px solid #ccd7db;text-align:left}section{padding:1rem 0;border-bottom:1px solid #dde5e8}svg{max-width:100%;height:auto}.warning{border-left:3px solid #a64;padding-left:1rem}small{color:#53666f}</style></head><body>',
    '<h1>AquaTrajectories - real fish dual-path analysis</h1>',
    '<p class="warning"><b>Frame-indexed observational demonstration only.</b> Published identities are not independently readjudicated; model identities are not biologically certified. No measured timestamps, calibration, feeding events, treatment inference or welfare claims.</p>',
    '<h2>Source denominators and conditional observed movement</h2>',
    to_html_table(study$summary),'<h2>Scientific limitations</h2><ul>',
    paste0('<li>',html_escape(notes),'</li>'),'</ul>',
    '<h2>Source-backed figures (embedded SVG)</h2>',figs,
    '<footer><small>Generated from original source-labelled and model-generated observations; no model trained or run by this renderer.</small></footer></body></html>')
  writeLines(html,file.path(directory,"REPORT.html"),useBytes=TRUE)
  files <- list.files(directory,recursive=TRUE,full.names=FALSE)
  files <- files[file.info(file.path(directory,files))$isdir==FALSE]
  hashes <- stats::setNames(vapply(files,function(n)
    unname(digest::digest(file.path(directory,n),file=TRUE,algo="sha256")),
    character(1)),files)
  info <- list(schema="AQT_M07_FRAME_INDEX_SCIENCE_PUBLICATION_V1",
    all_source_observations_preserved=TRUE,
    no_measured_clock=TRUE,
    reported_physical_speed=FALSE,
    independent_biological_identity_verified=FALSE,
    n_input_observations=nrow(study$observations),
    n_source_frame_path_rows=nrow(study$frames),
    n_figures_complete=nrow(catalogue),
    n_figures_failed=0L,
    output_sha256=as.list(hashes))
  jsonlite::write_json(info,file.path(directory,"M07_SCIENCE_MANIFEST.json"),
                       pretty=TRUE,auto_unbox=TRUE)
  complete <- TRUE
  invisible(directory)
}
