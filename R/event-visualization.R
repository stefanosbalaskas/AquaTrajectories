#' Visualize independent tank-level before/after changes
#'
#' Draws one line per tank within the two treatment groups. This plot
#' displays the actual unit of replication; it does not draw uncertainty
#' bands from frame-level pseudo-replicates.
#'
#' @param fit Result from aqt_tank_event_contrast().
#' @param ylab Label for the behavioural metric.
#' @return The per-tank summary, invisibly; opens a base-R plot.
#' @export
aqt_plot_tank_changes <- function(fit,ylab="Behavioural measurement") {
  if (!is.list(fit) || !is.data.frame(fit$per_tank) ||
      !all(c("tank_id","treatment","mean_baseline","mean_response") %in%
        names(fit$per_tank)) ||
      length(fit$treatment_levels)!=2L)
    stop("Expected an aqt_tank_event_contrast result",call.=FALSE)
  d <- fit$per_tank
  limits <- range(c(d$mean_baseline,d$mean_response),finite=TRUE)
  if (!all(is.finite(limits))) stop("No finite tank observations",call.=FALSE)
  previous <- graphics::par(mfrow=c(1,2))
  on.exit(graphics::par(previous),add=TRUE)
  for (g in fit$treatment_levels) {
    z <- d[d$treatment==g,,drop=FALSE]
    graphics::plot(1,mean(z$mean_baseline),type="n",
      xlim=c(.85,2.15),ylim=limits,
      xaxt="n",xlab="Event epoch",ylab=ylab,
      main=paste0(g, " (",nrow(z)," tanks)"))
    graphics::axis(1,at=c(1,2),labels=c("Baseline","Response"))
    colors <- grDevices::hcl.colors(max(nrow(z),1L),palette="Dark 3")
    for (i in seq_len(nrow(z))) {
      graphics::lines(c(1,2),
        c(z$mean_baseline[i],z$mean_response[i]),
        type="b",pch=16,col=colors[i])
    }
  }
  invisible(d)
}
