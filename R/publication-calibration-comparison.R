#' Compare three-dimensional reconstruction errors on held-out targets
#'
#' Two-column publication panel per method: nonnegative Euclidean XYZ
#' position-error histogram and an axonometric map of surveyed target
#' locations coloured by their error. It does not substitute for a signed
#' inter-target distance-error distribution, and a plotted residual is not
#' independent calibration certification.
#'
#' @param data Data.frame containing method,target_id,partition and six
#'   truth/prediction XYZ coordinates in explicitly stated units.
#' @param units Either cm or m; must match supplied physical coordinates.
#' @param require_holdout Require explicit partition==holdout (default TRUE).
#'   Rows marked fit are never scored; overlapping target IDs between
#'   fit and holdout in the same method cause an error.
#' @return Invisibly a per-method error summary. Source measurements and
#'   external survey accuracy are not automatically certified.
#' @export
aqt_plot_calibration_comparison <- function(
    data,units=c("cm","m"),require_holdout=TRUE) {
  units <- match.arg(units)
  required <- c("method","target_id",
      "truth_x","truth_y","truth_z","estimate_x","estimate_y","estimate_z")
  if (!is.logical(require_holdout) || length(require_holdout)!=1L ||
      is.na(require_holdout))
    stop("require_holdout must be TRUE or FALSE",call.=FALSE)
  if (require_holdout) required <- c(required,"partition")
  x <- .aqt_pub_data(data,required,"Calibration comparison")
  methods <- .aqt_pub_scope(x,"method")
  ids <- .aqt_pub_scope(x,"target_id")
  if (require_holdout) {
    parts <- .aqt_pub_scope(x,"partition")
    if (!all(parts %in% c("fit","holdout")))
      stop("partition must be either fit or holdout",call.=FALSE)
    scope <- paste(methods,ids,sep="\r")
    if (length(intersect(scope[parts=="fit"],
                         scope[parts=="holdout"]))>0L)
      stop("Target IDs leak from calibration fit into holdout",
           call.=FALSE)
    x <- x[parts=="holdout",,drop=FALSE]
    if (!nrow(x)) stop("No independently held-out target rows",call.=FALSE)
  }
  xyzcols <- c("truth_x","truth_y","truth_z",
               "estimate_x","estimate_y","estimate_z")
  .aqt_pub_physical_xyz(x,xyzcols)
  methods <- .aqt_pub_scope(x,"method")
  ids <- .aqt_pub_scope(x,"target_id")
  if (anyDuplicated(paste(methods,ids,sep="\r")))
    stop("Only one record per method and target_id is supported",
         call.=FALSE)
  m <- unique(methods)
  if (length(m)>4L)
    stop("Select at most four calibration methods per figure",call.=FALSE)
  truth <- as.matrix(x[,c("truth_x","truth_y","truth_z"),drop=FALSE])
  estimate <- as.matrix(x[,c("estimate_x","estimate_y","estimate_z"),
                          drop=FALSE])
  difference <- estimate-truth
  residual <- sqrt(rowSums(difference^2))
  max_error <- max(residual)
  bounds <- apply(rbind(truth,estimate),2L,range)
  for (j in seq_len(3L)) {
    if (bounds[2L,j]==bounds[1L,j])
      bounds[,j] <- bounds[,j]+c(-.5,.5)
  }
  xy_truth <- .aqt_pub_project_xyz(truth,bounds)
  xy_est <- .aqt_pub_project_xyz(estimate,bounds)
  xy_range <- apply(rbind(xy_truth,xy_est),2L,range)
  pad <- pmax(.06,apply(xy_range,2L,diff)*.12)
  palette <- grDevices::hcl.colors(128L,"YlOrRd")
  rank <- pmax(1L,pmin(128L,
    as.integer(ceiling(residual/pmax(max_error,1e-10)*128L))))
  old <- graphics::par(no.readonly=TRUE)
  on.exit(graphics::par(old),add=TRUE)
  graphics::par(mfrow=c(length(m),2L),mar=c(3.7,3.9,2.9,.9),
                oma=c(.5,.5,1.6,.3))
  summaries <- vector("list",length(m))
  for(i in seq_along(m)) {
    take <- which(methods==m[i])
    values <- residual[take]
    graphics::hist(values,breaks="Sturges",freq=FALSE,
      col="#5B9CC9",border="white",
      xlab=paste0("3D position error (",units,")"),
      ylab="Density",
      main=paste0("(",LETTERS[i],") ",m[i]," | Euclidean error"))
    graphics::abline(v=mean(values),col="#B42318",lwd=2)
    graphics::plot(NA_real_,NA_real_,type="n",asp=1,axes=FALSE,
      xlim=xy_range[,1L]+c(-pad[1L],pad[1L]),
      ylim=xy_range[,2L]+c(-pad[2L],pad[2L]),
      xlab="",ylab="",
      main=paste0(m[i],": XYZ error-coloured targets"))
    graphics::segments(xy_truth[take,1L],xy_truth[take,2L],
      xy_est[take,1L],xy_est[take,2L],
      col=palette[rank[take]],lwd=.85)
    graphics::points(xy_truth[take,1L],xy_truth[take,2L],
      pch=16,cex=.68,col=palette[rank[take]])
    graphics::legend("bottomleft",
      legend=c(paste0("0 ",units),
               paste0(format(round(max_error,3),trim=TRUE)," ",units),
               "Colour = absolute XYZ error"),
      fill=c(palette[1L],palette[128L],NA),
      border=NA,bty="n",cex=.65)
    summaries[[i]] <- data.frame(method=m[i],n_targets=length(take),
      mean_error=mean(values),
      rmse_3d=sqrt(mean(values^2)),
      max_error=max(values),
      mean_error_x=mean(difference[take,1L]),
      mean_error_y=mean(difference[take,2L]),
      mean_error_z=mean(difference[take,3L]),
      stringsAsFactors=FALSE)
  }
  graphics::mtext(paste0("Held-out XYZ errors (",units,
        "); axonometric projection, not independent survey certification"),
        side=3,outer=TRUE,line=.2,cex=.72)
  result <- do.call(rbind,summaries)
  rownames(result) <- NULL
  attr(result,"units") <- units
  attr(result,"fit_targets_excluded") <- require_holdout
  attr(result,"independent_physical_survey_verified") <- FALSE
  invisible(result)
}
