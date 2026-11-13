#' Plot supplied feeding-behaviour phases against a measured index
#'
#' Four-panel descriptive scatterplot comparing feeding scenarios. The
#' function never infers feeding from speed, HMM state, or clustering alone:
#' both the numerical index and biological phase labels MUST be supplied.
#' Thus rendering the figure is not validation of a feeding index.
#'
#' @param data Nonempty data.frame with columns scenario,time_min,fbi,phase
#'   (or alternative names selected by column arguments).
#' @param scenario_col,time_col,index_col,phase_col Column names.
#' @param event_time_min Known intervention onset; default zero minutes.
#' @param index_limits Numeric axis limits; default c(0,1) for a
#'   normalized fraction. Set NULL to infer observed limits.
#' @param phase_colors Named vector of colour codes for the phase labels.
#' @return Invisibly, a data.frame with observations per supplied phase and
#'   scenario; attributes explicitly state the labels are not verified.
#' @export
aqt_plot_feeding_states <- function(
    data,scenario_col="scenario",time_col="time_min",
    index_col="fbi",phase_col="phase",event_time_min=0,
    index_limits=c(0,1),
    phase_colors=c(pre="#24292F",onset="#E53935",
                   later="#9CA3AF",post="#3055EE")) {
  cols <- c(scenario_col,time_col,index_col,phase_col)
  if (!all(vapply(cols,function(v)
      is.character(v) && length(v)==1L && !is.na(v) &&
        nzchar(v),logical(1L))) || anyDuplicated(cols))
    stop("Column names must be distinct nonempty character scalars",
         call.=FALSE)
  x <- .aqt_pub_data(data,cols,"Feeding-state plot")
  .aqt_pub_column_numeric(x,time_col)
  .aqt_pub_column_numeric(x,index_col)
  .aqt_pub_number(event_time_min,"event_time_min")
  groups <- .aqt_pub_scope(x,scenario_col)
  phases <- .aqt_pub_scope(x,phase_col)
  if (!is.character(phase_colors) || is.null(names(phase_colors)) ||
      anyDuplicated(names(phase_colors)) ||
      anyNA(phase_colors) || any(!nzchar(phase_colors)) ||
      !all(unique(phases) %in% names(phase_colors)))
    stop("phase_colors must name every supplied phase",call.=FALSE)
  panels <- unique(groups)
  if (length(panels)>4L)
    stop("At most four scenarios per publication figure",call.=FALSE)
  lim <- if (is.null(index_limits))
    range(x[[index_col]]) else index_limits
  if (!is.numeric(lim) || length(lim)!=2L || any(!is.finite(lim)) ||
      lim[2L]<=lim[1L])
    stop("index_limits must be increasing finite bounds",call.=FALSE)
  if (any(x[[index_col]]<lim[1L] | x[[index_col]]>lim[2L]))
    stop("Supplied index extends beyond index_limits; do not clip data",
         call.=FALSE)
  time_lim <- range(c(x[[time_col]],event_time_min))
  if (diff(time_lim)==0) time_lim <- time_lim+c(-.5,.5)
  previous <- graphics::par(no.readonly=TRUE)
  on.exit(graphics::par(previous),add=TRUE)
  graphics::par(mfrow=.aqt_pub_panels(length(panels)),
                mar=c(4,4,3,1),oma=c(.3,.5,1.5,.2))
  for (i in seq_along(panels)) {
    idx <- groups==panels[i]
    graphics::plot(x[[time_col]][idx],x[[index_col]][idx],
      type="n",ylim=lim,xlim=time_lim,las=1,main=panels[i],
      xlab="Time relative to intervention (min)",
      ylab="Supplied behaviour index")
    graphics::abline(v=event_time_min,col="#22A565",lty=2,lwd=1.5)
    graphics::points(x[[time_col]][idx],x[[index_col]][idx],
                     col=unname(phase_colors[phases[idx]]),
                     pch=16,cex=.4)
    if(i==1L)
      graphics::legend("topright",legend=names(phase_colors),
                       col=unname(phase_colors),pch=16,bty="n",
                       cex=.66,ncol=2L)
  }
  graphics::mtext("Externally supplied phase labels; descriptive, not validated feeding states",
                  side=3,outer=TRUE,line=.1,cex=.72)
  key <- paste(groups,phases,sep="\r")
  count <- table(key)
  first <- !duplicated(key)
  summary <- data.frame(scenario=groups[first],phase=phases[first],
                        n_samples=as.integer(count[key[first]]),
                        stringsAsFactors=FALSE)
  attr(summary,"phase_labels_externally_supplied") <- TRUE
  attr(summary,"feeding_index_independently_validated") <- FALSE
  invisible(summary)
}
