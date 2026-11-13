#' Plot swimming-heading rose diagrams with explicit angle conventions
#'
#' Uses supplied heading_rad values from aqt_kinematics() or another
#' documented 2D projected-heading source. Circular bins compare direction
#' distributions without claiming true 3D orientation. Optional preloaded
#' raster images can be shown beside each condition's polar rose.
#'
#' @param data A data.frame with condition and heading_rad columns.
#' @param bins Number of angular bins (integer between 4 and 72).
#' @param scale One of fraction (bin proportion) or count (weighted count).
#' @param clockwise Whether angles increase clockwise rather than CCW.
#' @param zero_offset_rad Rotation of the supplied angle-zero direction.
#' @param weight_col Optional nonnegative observation-weight column.
#' @param frame_rasters Optional named list of preloaded raster images, with
#'   names matching conditions. Supplied images are not generated or altered.
#' @param fill Fill colour for rose diagram sectors.
#' @return Invisibly a table of bin centers, counts, proportions and
#'   descriptive circular statistics.
#' @export
aqt_plot_heading_rose <- function(
    data,bins=16L,scale=c("fraction","count"),
    clockwise=FALSE,zero_offset_rad=0,weight_col=NULL,
    frame_rasters=NULL,fill="#B0C36B") {
  scale <- match.arg(scale)
  x <- .aqt_pub_data(data,c("condition","heading_rad"),
                     "Swimming-heading rose")
  labels <- .aqt_pub_scope(x,"condition")
  if (!is.numeric(bins) || length(bins)!=1L || is.na(bins) ||
      bins<4 || bins>72 || bins!=as.integer(bins))
    stop("bins must be an integer from 4 to 72",call.=FALSE)
  bins <- as.integer(bins)
  if(!is.logical(clockwise) || length(clockwise)!=1L ||
     is.na(clockwise))
    stop("clockwise must be TRUE or FALSE",call.=FALSE)
  .aqt_pub_number(zero_offset_rad,"zero_offset_rad")
  .aqt_pub_id(fill,"fill")
  if (!is.numeric(x$heading_rad) ||
      any(is.infinite(x$heading_rad)))
    stop("heading_rad must be numeric and may contain NA but not Inf",
         call.=FALSE)
  if (is.null(weight_col)) {
    weights <- rep(1,nrow(x))
  } else {
    .aqt_pub_id(weight_col,"weight_col")
    if (!weight_col %in% names(x))
      stop("Missing observation weight column",call.=FALSE)
    .aqt_pub_column_numeric(x,weight_col)
    weights <- x[[weight_col]]
    if(any(weights<0))stop("Weights cannot be negative",call.=FALSE)
  }
  dropped <- sum(is.na(x$heading_rad))
  good <- is.finite(x$heading_rad) & weights>0
  if (!any(good))
    stop("No finite headings with positive weight",call.=FALSE)
  labels <- labels[good]
  original <- x$heading_rad[good]
  weights <- weights[good]
  transformed <- ((if(clockwise) -original else original)+
                    zero_offset_rad)%%(2*pi)
  panel <- unique(labels)
  if(length(panel)>6L)
    stop("At most six conditions in one heading-rose figure",
         call.=FALSE)
  if(!is.null(frame_rasters)) {
    if(!is.list(frame_rasters) || is.null(names(frame_rasters)) ||
       anyDuplicated(names(frame_rasters)) ||
       !all(panel %in% names(frame_rasters)))
      stop("frame_rasters must be a named list covering every condition",
           call.=FALSE)
    if(length(panel)>4L)
      stop("Image + rose layout supports at most four conditions",
           call.=FALSE)
  }
  idx <- pmin(bins,1L+floor(transformed/(2*pi)*bins))
  all_counts <- lapply(panel,function(p) {
    at <- which(labels==p)
    counts <- tabulate(idx[at],nbins=bins)
    summed <- vapply(seq_len(bins),function(i)
                   sum(weights[at[idx[at]==i]]),numeric(1L))
    props <- summed/sum(summed)
    stats <- .aqt_pub_circular_summary(original[at],weights[at])
    data.frame(condition=p,bin=seq_len(bins),
      center_deg=((seq_len(bins)-.5)*360/bins)%%360,
      n_observations=counts,weighted_count=summed,
      proportion=props,
      mean_heading_rad=stats$mean_heading_rad,
      circular_resultant_length=stats$circular_resultant_length,
      stringsAsFactors=FALSE)
  })
  summary <- do.call(rbind,all_counts)
  rownames(summary) <- NULL
  plotted <- if(scale=="fraction")summary$proportion else
    summary$weighted_count
  rmax <- max(plotted)
  rmax <- if(rmax>0)rmax*1.06 else 1
  old <- graphics::par(no.readonly=TRUE)
  on.exit(graphics::par(old),add=TRUE)
  graphics::par(mfrow=if(is.null(frame_rasters))
    .aqt_pub_panels(length(panel)) else c(length(panel),2L),
    mar=c(1.7,1.3,2.8,1.3),oma=c(.3,.3,1.3,.2))
  for (p in panel) {
    if (!is.null(frame_rasters)) {
      raster <- tryCatch(grDevices::as.raster(frame_rasters[[p]]),
                         error=function(e)stop(
                           "Unusable frame raster for ",p,": ",
                           conditionMessage(e),call.=FALSE))
      graphics::plot(NA_real_,NA_real_,xlim=c(0,1),ylim=c(0,1),
          xlab="",ylab="",axes=FALSE,asp=1,type="n",
          main=paste0(p,": provided image"))
      graphics::rasterImage(raster,0,0,1,1,interpolate=FALSE)
      graphics::box(col="#9BA3AE")
    }
    d <- summary[summary$condition==p,,drop=FALSE]
    y <- if(scale=="fraction")d$proportion else d$weighted_count
    graphics::plot(NA_real_,NA_real_,type="n",asp=1,axes=FALSE,
      xlim=c(-1.17*rmax,1.17*rmax),
      ylim=c(-1.17*rmax,1.17*rmax),
      xlab="",ylab="",main=p)
    .aqt_pub_draw_circular_grid(rmax)
    for (j in seq_len(bins)) if(y[j]>0) {
      angle <- (seq(j-1,j,length.out=9L))*2*pi/bins
      graphics::polygon(c(0,y[j]*cos(angle),0),
                        c(0,y[j]*sin(angle),0),
                        col=grDevices::adjustcolor(fill,alpha.f=.8),
                        border="#6C7C3C",lwd=.5)
    }
    for (a in seq(0,315,by=45)) {
      rad <- a*pi/180
      graphics::text(1.12*rmax*cos(rad),1.12*rmax*sin(rad),
                     labels=paste0(a,"\u00b0"),cex=.6)
    }
    graphics::mtext(paste0("Max scale: ",
      format(round(if(scale=="fraction")rmax*100 else rmax,2),
             trim=TRUE),if(scale=="fraction") "%" else " observations"),
      side=1,line=.6,cex=.61)
  }
  graphics::mtext(paste0("Planar headings; ",
    if(clockwise) "clockwise" else "counter-clockwise",
    " from configured zero; identical radial scale"),
    side=3,outer=TRUE,line=.15,cex=.72)
  attr(summary,"excluded_missing_or_zero_weight") <-
    nrow(x)-length(original)
  attr(summary,"coordinate_convention_requires_external_confirmation") <- TRUE
  attr(summary,"3d_orientation_inferred") <- FALSE
  invisible(summary)
}
