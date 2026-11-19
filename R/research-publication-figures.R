# Source-bound scientific figure drawing. These are visualizations ONLY;
# never recompute the original scientific estimators or override QC flags.

.aqt_publication_axis <- function(x) {
  x <- x[is.finite(x)]
  if(!length(x))stop("No finite plotting values",call.=FALSE)
  r <- range(x)
  span <- diff(r)
  if(span<1e-12)span <- max(abs(r),1)*.25
  r+c(-.04,.04)*span
}
.aqt_publication_units <- function(study) {
  unit <- study$provenance$coordinate_units
  if(is.null(unit)||!nzchar(unit))unit <- "source units"
  list(position=unit,speed=paste0(unit,"/s"))
}

.aqt_publication_draw <- function(study,figure) {
  kind <- as.character(figure$kind)
  s <- as.character(figure$session_id)
  camera <- as.character(figure$camera_id)
  unit <- .aqt_publication_units(study)
  if(kind=="coverage") {
    d <- study$audit$camera_coverage
    frac <- d$n_frames_with_reviewed_positions/d$n_acquisition_frames
    graphics::barplot(frac,ylim=c(0,1),col="#286B80",border=NA,
       names.arg=paste(d$session_id,d$camera_id,sep="/"),las=2,
       ylab="Proportion of actual acquisition frames",
       main="Camera frames with eligible tracked fish")
    graphics::mtext("Not fish-level detection recall",side=3,line=.25,cex=.73)
    return(invisible(NULL))
  }
  if(kind=="review_counts") {
    d <- study$review$row_audit
    v <- c(eligible=sum(d$review_eligible),
           excluded=nrow(d)-sum(d$review_eligible))
    graphics::barplot(v,col=c("#286B80","#B06E58"),border=NA,
       ylab="Original tracker-observation rows",main="Recorded quality review")
    graphics::mtext("All original rows retained in source audit",
       side=3,line=.25,cex=.74)
    return(invisible(NULL))
  }
  if(kind=="paths") {
    k <- study$movement$kinematics
    q <- k[.aqt_publication_scope_index(k,s,camera),,drop=FALSE]
    v <- q$observed & is.finite(q$x) & is.finite(q$y)
    ylim <- .aqt_publication_axis(q$y[v])
    if(identical(study$provenance$coordinate_system,"image"))
      ylim <- rev(ylim)
    graphics::plot(NA_real_,NA_real_,xlim=.aqt_publication_axis(q$x[v]),
       ylim=ylim,asp=1,xlab=paste0("X (",unit$position,")"),
       ylab=paste0("Y (",unit$position,")"),
       main=paste("Reviewed fish trajectories:",s,camera))
    groups <- split(seq_len(nrow(q)),q$track_id)
    colors <- grDevices::hcl.colors(length(groups),"Dark 3")
    for(i in seq_along(groups)) {
      z <- q[groups[[i]],,drop=FALSE]
      good <- z$observed & is.finite(z$x) & is.finite(z$y)
      graphics::points(z$x[good],z$y[good],pch=16,
          col=grDevices::adjustcolor(colors[i],alpha.f=.65),cex=.42)
      if(nrow(z)>=2L)
        for(j in seq.int(2L,nrow(z)))
          if(good[j] && good[j-1L] &&
              is.finite(z$step_distance[j]))
            graphics::segments(z$x[j-1L],z$y[j-1L],
                z$x[j],z$y[j],lwd=1.2,col=colors[i])
    }
    graphics::mtext("Only original, QC-eligible adjacent movement segments connected",
       side=3,line=.15,cex=.68)
    return(invisible(NULL))
  }
  if(kind=="speed") {
    k <- study$movement$kinematics
    z <- k[.aqt_publication_scope_index(k,s,camera),,drop=FALSE]
    z <- z[is.finite(z$speed),,drop=FALSE]
    graphics::plot(NA_real_,NA_real_,type="n",
       xlim=.aqt_publication_axis(z$time_s),
       ylim=c(0,max(z$speed)*1.1+1e-6),
       xlab="Acquisition time (s)",
       ylab=paste0("Speed (",unit$speed,")"),
       main=paste("Gap-qualified swimming speeds:",s,camera))
    ids <- unique(as.character(z$track_id))
    col <- grDevices::hcl.colors(length(ids),"Dark 3")
    for(i in seq_along(ids)) {
      d <- z[z$track_id==ids[i],,drop=FALSE]
      graphics::points(d$time_s,d$speed,pch=16,cex=.52,col=col[i])
    }
    graphics::mtext("Descriptive valid steps; no interpolation over missing frames",
      side=3,line=.2,cex=.72)
    return(invisible(NULL))
  }
  if(kind=="school_dispersion") {
    d <- study$schooling$spatial_summary
    aqt_plot_school_dynamics(d,s,camera,metric="radius_gyration")
    return(invisible(NULL))
  }
  if(kind=="polarization") {
    d <- study$schooling$group_metrics
    d <- d[.aqt_publication_scope_index(d,s,camera),,drop=FALSE]
    d <- d[is.finite(d$polarization),,drop=FALSE]
    graphics::plot(d$time_s,d$polarization,pch=16,cex=.55,
       col="#286B80",ylim=c(0,1),
       xlab="Acquisition time (s)",
       ylab="Directional polarization (unitless)",
       main=paste("Qualified school alignment:",s,camera))
    graphics::mtext("From eligible nonzero measured velocity vectors only",
      side=3,line=.2,cex=.72)
    return(invisible(NULL))
  }
  if(kind=="event_epochs") {
    d <- study$events$epoch_summaries
    d <- d[is.finite(d$value),,drop=FALSE]
    ep <- unique(as.character(d$epoch))
    v <- split(d$value,factor(as.character(d$epoch),levels=ep))
    graphics::stripchart(v,vertical=TRUE,method="stack",
        pch=16,cex=.62,col="#286B80",
        xlab="Declared event epoch",
        ylab=study$config$event_outcome,
        main="Recorded event-epoch fish outcomes")
    graphics::mtext("Fish rows are not independent treated tanks",
       side=3,line=.2,cex=.72)
    return(invisible(NULL))
  }
  if(kind=="functional_support") {
    d <- study$functional$coverage
    graphics::plot(d$time_relative_s,d$fraction_supported,
       type="b",pch=16,col="#286B80",ylim=c(0,1),
       xlab="Seconds relative to event",
       ylab="Fraction of fish curves with source support",
       main="Functional observation coverage")
    graphics::abline(v=0,lty=2,col="#B06E58")
    return(invisible(NULL))
  }
  if(kind=="functional_curves") {
    d <- study$functional$grid
    valid <- d$supported & is.finite(d$value)
    graphics::plot(NA_real_,NA_real_,type="n",
       xlim=.aqt_publication_axis(d$time_relative_s),
       ylim=.aqt_publication_axis(d$value[valid]),
       xlab="Seconds relative to event",
       ylab=study$config$event_outcome,
       main="Observed functional fish trajectories")
    key <- .aqt_qc_scope(d$session_id,d$camera_id,
                          track=d$track_id)
    groups <- split(seq_len(nrow(d)),key)
    cols <- grDevices::hcl.colors(length(groups),"Dark 3")
    for(i in seq_along(groups)) {
      z <- d[groups[[i]],,drop=FALSE]
      z <- z[order(z$time_relative_s),,drop=FALSE]
      v <- z$value
      v[!z$supported] <- NA_real_
      # NA values break graphics::lines; unsupported source data stay missing.
      graphics::lines(z$time_relative_s,v,col=cols[i],lwd=1)
      ok <- is.finite(v)
      graphics::points(z$time_relative_s[ok],v[ok],
        col=cols[i],pch=16,cex=.33)
    }
    graphics::abline(v=0,lty=2,col="#B06E58")
    graphics::mtext("Unsupported samples remain missing and visually disconnected",
        side=3,line=.15,cex=.70)
    return(invisible(NULL))
  }
  if(kind=="tank_changes") {
    aqt_plot_tank_changes(study$statistical_models$tank_contrast,
        ylab=paste0(study$config$event_outcome," (",unit$speed,")"))
    return(invisible(NULL))
  }
  if(kind=="sensitivity") {
    d <- study$uncertainty$path_sensitivity
    d <- d[order(d$session_id,d$camera_id,d$track_id),,drop=FALSE]
    if(nrow(d)>35L) d <- head(d,35L)
    labels <- paste(d$session_id,d$camera_id,d$track_id,sep="/")
    graphics::plot(NA_real_,NA_real_,type="n",
        xlim=.aqt_publication_axis(c(d$scenario_q025,d$scenario_q975)),
        ylim=c(.5,nrow(d)+.5),yaxt="n",
        xlab=paste0("Path length (",unit$position,")"),
        ylab="",main="Conditional fixed-identity sensitivity")
    graphics::axis(2,at=seq_len(nrow(d)),labels=labels,
        las=2,cex.axis=.55)
    for(i in seq_len(nrow(d))) {
      graphics::segments(d$scenario_q025[i],i,
        d$scenario_q975[i],i,col="#286B80",lwd=2)
      graphics::points(d$scenario_median[i],i,
        col="#B06E58",pch=16,cex=.8)
    }
    graphics::mtext("Hypothetical scenario quantiles - NOT confidence intervals",
         side=3,line=.15,cex=.69)
    return(invisible(NULL))
  }
  stop("Unknown figure kind: ",kind,call.=FALSE)
}

.aqt_publication_render <- function(study,row,file,format,width,height,dpi) {
  old <- grDevices::dev.cur()
  tryCatch({
    if(format=="pdf") grDevices::pdf(file,width=width,height=height,
       onefile=FALSE,useDingbats=FALSE,bg="white")
    else grDevices::png(file,width=width,height=height,
       res=dpi,units="in",bg="white")
    graphics::par(mar=c(4.6,4.7,3.8,1.6),
                  cex.main=.94,cex.lab=.91,cex.axis=.83)
    .aqt_publication_draw(study,row)
    grDevices::dev.off()
    if(!file.exists(file) || is.na(file.info(file)$size) ||
       file.info(file)$size<400)
      stop("The graphics device did not emit a usable file")
    list(ok=TRUE,reason="")
  },error=function(e) {
    if(grDevices::dev.cur()!=old)
      try(grDevices::dev.off(),silent=TRUE)
    if(file.exists(file)) unlink(file)
    list(ok=FALSE,reason=conditionMessage(e))
  })
}
