#' Plot tank-level spatial occupancy trajectories and uncertainty bands
#'
#' The supplied area_fraction is averaged within tank and time bins BEFORE
#' calculating across-tank variation. This prevents fish frames from being
#' treated as independent biological replicates. Bands are descriptive
#' between-tank SD or SE, not confidence intervals or significance tests.
#'
#' @param data Long table with scenario,tank_id,time_s,area_fraction.
#' @param time_bin_s Bin width in seconds; zero or negative not allowed.
#' @param band One of sd, se, or none; only shown where at least two
#'   distinct tank units contribute to a time bin.
#' @param periods Optional start_s/end_s/label table of known experimental
#'   periods, displayed as shaded regions; not inferred from behaviour.
#' @return Invisibly a tank-equal-weight summary by scenario and time bin,
#'   with n_tanks and descriptive SD/SE.
#' @export
aqt_plot_occupancy_timeseries <- function(
    data,time_bin_s=60,band=c("sd","se","none"),periods=NULL) {
  band <- match.arg(band)
  .aqt_pub_number(time_bin_s,"time_bin_s",positive=TRUE)
  x <- .aqt_pub_data(data,c("scenario","tank_id","time_s",
                            "area_fraction"),"Occupancy time series")
  scenarios <- .aqt_pub_scope(x,"scenario")
  tanks <- .aqt_pub_scope(x,"tank_id")
  .aqt_pub_column_numeric(x,"time_s")
  .aqt_pub_column_numeric(x,"area_fraction")
  if (any(x$area_fraction<0 | x$area_fraction>1))
    stop("area_fraction must be a measured proportion between 0 and 1",
         call.=FALSE)
  # Each tank must belong to one treatment/scenario to avoid
  # pseudoreplication or accidentally combining repeated exposures.
  if (any(vapply(split(scenarios,tanks),function(z)
         length(unique(z))!=1L,logical(1L))))
    stop("A tank_id appears in multiple scenarios; supply distinct",
         " independently analysed tank/session identifiers",call.=FALSE)
  if (!is.null(periods)) {
    periods <- .aqt_pub_data(periods,c("start_s","end_s","label"),
                              "Periods")
    .aqt_pub_column_numeric(periods,"start_s")
    .aqt_pub_column_numeric(periods,"end_s")
    .aqt_pub_scope(periods,"label")
    if (any(periods$end_s<=periods$start_s))
      stop("Every experimental period must have end_s > start_s",
           call.=FALSE)
  }
  origin <- min(x$time_s)
  time_bin <- origin+
    floor((x$time_s-origin)/time_bin_s)*time_bin_s
  key <- interaction(scenarios,tanks,time_bin,drop=TRUE,lex.order=TRUE)
  per_tank <- do.call(rbind,lapply(split(seq_len(nrow(x)),key),
    function(rows) data.frame(
      scenario=scenarios[rows[1L]],tank_id=tanks[rows[1L]],
      time_s=time_bin[rows[1L]],
      area_fraction=mean(x$area_fraction[rows]),
      n_frames=length(rows),stringsAsFactors=FALSE)))
  group <- interaction(per_tank$scenario,per_tank$time_s,
                       drop=TRUE,lex.order=TRUE)
  summary <- do.call(rbind,lapply(split(seq_len(nrow(per_tank)),group),
    function(rows) {
      v <- per_tank$area_fraction[rows]
      n <- length(v)
      data.frame(scenario=per_tank$scenario[rows[1L]],
        time_s=per_tank$time_s[rows[1L]],
        mean_fraction=mean(v),
        sd_tanks=if (n>1L) stats::sd(v) else NA_real_,
        se_tanks=if (n>1L) stats::sd(v)/sqrt(n) else NA_real_,
        n_tanks=n,
        n_frames=sum(per_tank$n_frames[rows]),
        stringsAsFactors=FALSE)
    }))
  rownames(summary) <- NULL
  panels <- unique(scenarios)
  if (length(panels)>6L)
    stop("At most six scenarios in a single publication figure",
         call.=FALSE)
  time_range <- range(c(x$time_s,if(!is.null(periods))
    c(periods$start_s,periods$end_s)))
  if (diff(time_range)==0) time_range <- time_range+c(-.5,.5)
  old <- graphics::par(no.readonly=TRUE)
  on.exit(graphics::par(old),add=TRUE)
  graphics::par(mfrow=.aqt_pub_panels(length(panels)),
                mar=c(4,4,3,1),oma=c(.6,.7,1.3,.3))
  for (label in panels) {
    d <- summary[summary$scenario==label,,drop=FALSE]
    d <- d[order(d$time_s),,drop=FALSE]
    graphics::plot(NA_real_,NA_real_,type="n",
      xlim=time_range,ylim=c(0,100),
      xlab="Time (s)",ylab="Tank area (%)",
      main=paste0(label," | ",length(unique(
        per_tank$tank_id[per_tank$scenario==label]))," tanks"))
    if (!is.null(periods))
      for (j in seq_len(nrow(periods))) {
        graphics::rect(periods$start_s[j],0,periods$end_s[j],100,
                       col=grDevices::adjustcolor("#64748B",alpha.f=.10),
                       border=NA)
        graphics::text(mean(c(periods$start_s[j],periods$end_s[j])),
                       96,periods$label[j],cex=.6)
      }
    spread <- if(band=="none") rep(NA_real_,nrow(d)) else
      if(band=="sd") d$sd_tanks else d$se_tanks
    valid <- which(is.finite(spread))
    if (length(valid)>=2L) {
      runs <- split(valid,cumsum(c(1L,as.integer(diff(valid)!=1L))))
      for (indices in runs) if(length(indices)>=2L) {
        graphics::polygon(
          c(d$time_s[indices],rev(d$time_s[indices])),
          c(100*pmax(0,d$mean_fraction[indices]-spread[indices]),
            rev(100*pmin(1,d$mean_fraction[indices]+spread[indices]))),
          col=grDevices::adjustcolor("#2C8F69",alpha.f=.24),
          border=NA)
      }
    }
    graphics::lines(d$time_s,100*d$mean_fraction,
                    col="#166447",lwd=2.1)
    graphics::points(d$time_s,100*d$mean_fraction,
                     col="#166447",pch=16,cex=.35)
  }
  graphics::mtext(paste0("Equal tank weights; ",
    if(band=="none") "no uncertainty band" else paste0(
      "shaded tank-level ",toupper(band),
      " (only where n tanks >= 2)")),
    outer=TRUE,side=3,cex=.73,line=.1)
  attr(summary,"bands_are_confidence_intervals") <- FALSE
  attr(summary,"independent_tank_units_assumed_not_verified") <- TRUE
  attr(summary,"time_bin_s") <- time_bin_s
  invisible(summary)
}
