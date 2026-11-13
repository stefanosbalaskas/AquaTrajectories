#' Plot swimming-speed changes around a known experimental intervention
#'
#' Panel A plots mean speed across independent tank units after averaging
#' within each tank and time bin. Panel B plots paired before/after
#' tank averages; bars show descriptive across-tank SD, not a significance
#' test. The input speed must already be measured in the declared units.
#'
#' @param data Kinematic data.frame with tank_id,time_s,speed, or an
#'   aqt_tracks object with a known tank identifier column.
#' @param event_time_s Known intervention onset in time_s units.
#' @param baseline_s,response_s Two intervals relative to event_time_s,
#'   e.g. c(-30,0) and c(0,30). Intervals must not overlap.
#' @param speed_unit Explicit speed units (e.g. cm/s); for an aqt_tracks
#'   object can be inferred from its declared spatial units.
#' @param tank_col Name of independent experimental-unit identifier.
#' @param time_bin_s Time bin width in seconds.
#' @param max_gap_s Maximum allowed observed step when deriving speed from
#'   aqt_tracks. No interpolation across a lost observation.
#' @return Invisibly a list of time_bin, per_tank_epoch and summary tables.
#' @export
aqt_plot_speed_response <- function(
    data,event_time_s,baseline_s=c(-30,0),response_s=c(0,30),
    speed_unit=NULL,tank_col="tank_id",time_bin_s=1,max_gap_s=.2) {
  .aqt_pub_number(event_time_s,"event_time_s")
  .aqt_pub_number(time_bin_s,"time_bin_s",positive=TRUE)
  .aqt_pub_number(max_gap_s,"max_gap_s",positive=TRUE)
  for (period in list(baseline_s,response_s))
    if (!is.numeric(period) || length(period)!=2L ||
        any(!is.finite(period)) || period[1L]>=period[2L])
      stop("Baseline and response windows must be finite increasing pairs",
           call.=FALSE)
  if (baseline_s[2L]>response_s[1L])
    stop("Baseline and response intervals cannot overlap",call.=FALSE)
  .aqt_pub_id(tank_col,"tank_col")
  if (inherits(data,"aqt_tracks")) {
    inferred <- attr(data,"aqt_units")
    if (is.null(speed_unit)) {
      if (is.null(inferred) || !inferred %in% c("cm","m"))
        stop("Specify speed_unit for nonphysical source coordinates",
             call.=FALSE)
      speed_unit <- paste0(inferred,"/s")
    }
    d <- aqt_kinematics(data,max_gap_s=max_gap_s)
  } else {
    d <- data
    if (is.null(speed_unit))
      stop("Specify measured speed_unit for kinematics input",call.=FALSE)
  }
  .aqt_pub_id(speed_unit,"speed_unit")
  d <- .aqt_pub_data(d,c(tank_col,"time_s","speed"),
                     "Speed response")
  ids <- .aqt_pub_scope(d,tank_col)
  .aqt_pub_column_numeric(d,"time_s")
  if (!is.numeric(d$speed))
    stop("speed must be numeric",call.=FALSE)
  keep <- is.finite(d$speed) & d$speed>=0
  if (!any(keep))stop("No finite nonnegative speed observations",call.=FALSE)
  d <- d[keep,,drop=FALSE]
  ids <- ids[keep]
  rel <- d$time_s-event_time_s
  interval <- c(baseline_s[1L],response_s[2L])
  draw <- rel>=interval[1L] & rel<=interval[2L]
  if (!any(draw))
    stop("No speed measurements within experimental window",
         call.=FALSE)
  d <- d[draw,,drop=FALSE]
  ids <- ids[draw]
  rel <- rel[draw]
  time_bin <- floor(rel/time_bin_s)*time_bin_s
  key <- interaction(ids,time_bin,drop=TRUE,lex.order=TRUE)
  per_bin <- do.call(rbind,lapply(split(seq_len(nrow(d)),key),
    function(i) data.frame(tank_id=ids[i[1L]],relative_time_s=time_bin[i[1L]],
                          mean_speed=mean(d$speed[i]),n_steps=length(i),
                          stringsAsFactors=FALSE)))
  binned <- split(seq_len(nrow(per_bin)),per_bin$relative_time_s)
  time_summary <- do.call(rbind,lapply(binned,function(i)
    data.frame(relative_time_s=per_bin$relative_time_s[i[1L]],
      mean_speed=mean(per_bin$mean_speed[i]),
      n_tanks=length(i),
      sd_tanks=if(length(i)>=2L)stats::sd(per_bin$mean_speed[i])
               else NA_real_,stringsAsFactors=FALSE)))
  time_summary <- time_summary[order(time_summary$relative_time_s),
                               ,drop=FALSE]
  tanks <- unique(ids)
  paired <- do.call(rbind,lapply(tanks,function(id) {
    ii <- which(ids==id)
    br <- rel[ii]>=baseline_s[1L] & rel[ii]<baseline_s[2L]
    rr <- rel[ii]>=response_s[1L] & rel[ii]<response_s[2L]
    if (!any(br) || !any(rr))return(NULL)
    data.frame(tank_id=id,baseline=mean(d$speed[ii[br]]),
               response=mean(d$speed[ii[rr]]),stringsAsFactors=FALSE)
  }))
  if (is.null(paired) || !nrow(paired))
    stop("No independent tank has valid measurements in both periods",
         call.=FALSE)
  means <- c(mean(paired$baseline),mean(paired$response))
  sds <- if(nrow(paired)>1L)
    c(stats::sd(paired$baseline),stats::sd(paired$response)) else
      c(NA_real_,NA_real_)
  upper <- max(c(per_bin$mean_speed,paired$baseline,paired$response,
                 means+sds),na.rm=TRUE)
  upper <- max(upper*1.15,1e-5)
  old <- graphics::par(no.readonly=TRUE)
  on.exit(graphics::par(old),add=TRUE)
  graphics::par(mfrow=c(1,2),mar=c(4.4,4.3,3.2,1.3),
                oma=c(.3,.3,1.4,.3))
  graphics::plot(NA_real_,NA_real_,type="n",
    xlim=interval,ylim=c(0,upper),xlab="Time relative to intervention (s)",
    ylab=paste0("Speed (",speed_unit,")"),
    main="(A) Tank-level speed trajectories")
  graphics::rect(baseline_s[1L],0,baseline_s[2L],upper,
    col=grDevices::adjustcolor("#497AA3",alpha.f=.08),border=NA)
  graphics::rect(response_s[1L],0,response_s[2L],upper,
    col=grDevices::adjustcolor("#E89B5A",alpha.f=.09),border=NA)
  colors <- grDevices::hcl.colors(length(tanks),"Dark 3")
  for (j in seq_along(tanks)) {
    z <- per_bin[per_bin$tank_id==tanks[j],,drop=FALSE]
    z <- z[order(z$relative_time_s),,drop=FALSE]
    graphics::lines(z$relative_time_s,z$mean_speed,
      col=grDevices::adjustcolor(colors[j],alpha.f=.33),lwd=1)
  }
  graphics::lines(time_summary$relative_time_s,time_summary$mean_speed,
    col="#163F62",lwd=2.5)
  graphics::abline(v=0,lty=2,lwd=1.3,col="#C94235")
  graphics::plot(NA_real_,NA_real_,type="n",xlim=c(.6,2.4),
    ylim=c(0,upper),xaxt="n",xlab="Known event epochs",
    ylab=paste0("Tank mean speed (",speed_unit,")"),
    main=paste0("(B) Paired tanks (n=",nrow(paired),")"))
  graphics::axis(1,at=1:2,labels=c("Baseline","Response"))
  for (i in seq_len(nrow(paired)))
    graphics::lines(1:2,as.numeric(paired[i,c("baseline","response")]),
      col=grDevices::adjustcolor("#8E9AA5",alpha.f=.55),lwd=.9)
  graphics::points(1:2,means,pch=16,cex=1.3,
                   col=c("#476F96","#B26236"))
  if (all(is.finite(sds))) {
    graphics::segments(1:2,pmax(0,means-sds),1:2,means+sds,
      lwd=2,col=c("#476F96","#B26236"))
    graphics::segments((1:2)- .045,pmax(0,means-sds),
                       (1:2)+ .045,pmax(0,means-sds),
                       lwd=2,col="#4B5563")
    graphics::segments((1:2)- .045,means+sds,(1:2)+ .045,means+sds,
                       lwd=2,col="#4B5563")
  }
  graphics::mtext("Tank units are replication; descriptive means and SD, no p-values",
    side=3,outer=TRUE,cex=.7,line=.2)
  summary <- data.frame(epoch=c("baseline","response"),
      mean_speed=means,sd_tanks=sds,n_tanks=nrow(paired),
      speed_unit=speed_unit)
  result <- list(time_bins=time_summary,per_tank_time_bins=per_bin,
                 per_tank_epoch=paired,summary=summary)
  attr(result,"independent_tank_replication_verified") <- FALSE
  attr(result,"significance_test_performed") <- FALSE
  invisible(result)
}
