#' Dense-grid approximation to multivariate functional trajectory PCA
#'
#' Each scoped fish path is independently registered to 0..1 relative time,
#' linearly resampled to a common grid and decomposed by ordinary PCA on
#' concatenated X/Y(/Z) grid coordinates. This is an explicitly finite-grid
#' PCA approximation, NOT sparse FPCA, continuous functional mixed models,
#' temporal causality inference, or a qualified EyeTrajectories backend.
#' Starting-position centering optionally removes constant translation.
#' Irregular source sampling is accepted only when no gap exceeds max_gap_s.
#'
#' @param tracks Validated aqt_tracks with >=3 complete scoped fish paths.
#' @param n_grid Integer common relative-time grid size, 5..1000.
#' @param n_components Number of principal components, 1..min(n_fish-1,p).
#' @param origin start (subtract initial XYZ) or absolute coordinates.
#' @param max_gap_s Largest source interval allowed for interpolation.
#' @return aqt_grid_pca containing scores, mode curves, mean path,
#'   relative-time grid, and variance explained.
#' @export
aqt_trajectory_grid_pca <- function(
    tracks,n_grid=60L,n_components=2L,
    origin=c("start","absolute"),max_gap_s=Inf) {
  aqt_tracks_validate(tracks)
  origin <- match.arg(origin)
  if (!is.numeric(n_grid) || length(n_grid)!=1L ||
      !is.finite(n_grid) || n_grid!=floor(n_grid) ||
      n_grid<5L || n_grid>1000L)
    stop("n_grid must be an integer between 5 and 1000",call.=FALSE)
  if (!is.numeric(n_components) || length(n_components)!=1L ||
      !is.finite(n_components) || n_components!=floor(n_components) ||
      n_components<1L)
    stop("n_components must be a positive integer",call.=FALSE)
  if (!nrow(tracks)) stop("No trajectories supplied",call.=FALSE)
  scoped <- interaction(tracks$session_id,tracks$camera_id,
                        tracks$track_id,drop=TRUE)
  groups <- split(seq_len(nrow(tracks)),scoped)
  ng <- length(groups)
  axes <- c("x","y",if (identical(attr(tracks,"aqt_dimension"),3L)) "z")
  dimn <- length(axes)
  features <- as.double(ng)*n_grid*dimn
  if (ng<3L || ng>500L || features>250000)
    stop("Grid PCA requires 3..500 paths within 250,000 grid cells",
         call.=FALSE)
  if (n_components>min(ng-1L,n_grid*dimn))
    stop("n_components exceeds available independent PCA rank",call.=FALSE)
  grid <- seq(0,1,length.out=as.integer(n_grid))
  M <- matrix(NA_real_,ng,n_grid*dimn)
  scopes <- data.frame(session_id=character(),camera_id=character(),
                       track_id=character())
  for (i in seq_along(groups)) {
    d <- aqt_tracks(as.data.frame(tracks[groups[[i]],,drop=FALSE]),
                    units=attr(tracks,"aqt_units"),
                    coordinate_system=attr(tracks,"aqt_coordinate_system"))
    p <- .aqt_single_path(d,max_gap_s=max_gap_s)
    t <- p$data$time_s
    rel <- (t-t[1L])/(t[length(t)]-t[1L])
    fitted <- vapply(seq_len(dimn),function(j) {
      z <- p$position[,j]
      if (origin=="start") z <- z-z[1L]
      stats::approx(x=rel,y=z,xout=grid,ties="ordered",
                    rule=1)$y
    },numeric(n_grid))
    if (!is.matrix(fitted)) fitted <- matrix(fitted,ncol=dimn)
    if (any(!is.finite(fitted)))
      stop("A trajectory cannot be interpolated onto the full grid",
           call.=FALSE)
    M[i,] <- as.vector(fitted)
    scopes <- rbind(scopes,p$data[1L,c("session_id","camera_id","track_id")])
  }
  model <- stats::prcomp(M,center=TRUE,scale.=FALSE)
  total <- sum(model$sdev^2)
  if (!is.finite(total) || total<=0)
    stop("All gridded fish trajectories are identical; PCA undefined",
         call.=FALSE)
  k <- as.integer(n_components)
  modes <- array(NA_real_,dim=c(n_grid,dimn,k),
                 dimnames=list(NULL,axes,paste0("PC",seq_len(k))))
  for (j in seq_len(k))
    modes[,,j] <- matrix(model$rotation[,j],nrow=n_grid,ncol=dimn)
  scores <- scopes
  for (j in seq_len(k))
    scores[[paste0("PC",j)]] <- model$x[,j]
  mean_path <- matrix(model$center,nrow=n_grid,ncol=dimn,
                      dimnames=list(NULL,axes))
  structure(list(scores=scores,mean_path=mean_path,modes=modes,
    explained_variance=model$sdev[seq_len(k)]^2/total,
    mode_sd=model$sdev[seq_len(k)],
    time_relative=grid,origin=origin,units=attr(tracks,"aqt_units"),
    coordinate_system=attr(tracks,"aqt_coordinate_system"),
    dimension=dimn,n_paths=ng,n_grid=as.integer(n_grid),
    implementation="finite-grid multivariate PCA; not sparse FPCA"),
    class="aqt_grid_pca")
}

#' Plot the mean 2D/3D trajectory and one dense-grid PCA mode
#'
#' Shows mean +/- one empirical component SD in each coordinate versus
#' registered relative time. This is a descriptive mode visualization,
#' not an interval for fish behaviour or a reconstructed 3D shape.
#'
#' @param fit aqt_grid_pca.
#' @param component One component index.
#' @return PCA fit invisibly; creates a base R multi-panel figure.
#' @export
aqt_plot_grid_pca <- function(fit,component=1L) {
  if (!inherits(fit,"aqt_grid_pca") ||
      !is.matrix(fit$mean_path) ||
      !is.array(fit$modes) ||
      length(dim(fit$modes))!=3L)
    stop("Expected an aqt_grid_pca fit",call.=FALSE)
  kmax <- dim(fit$modes)[3L]
  if (!is.numeric(component) || length(component)!=1L ||
      !is.finite(component) || component<1L ||
      component>kmax || component!=floor(component))
    stop("Unknown PCA component",call.=FALSE)
  mode <- fit$modes[,,as.integer(component),drop=FALSE]
  dim(mode) <- dim(fit$mean_path)
  shifted <- mode*fit$mode_sd[component]
  previous <- graphics::par(mfrow=c(fit$dimension,1L))
  on.exit(graphics::par(previous),add=TRUE)
  for (j in seq_len(fit$dimension)) {
    mn <- fit$mean_path[,j]
    lo <- mn-shifted[,j]
    hi <- mn+shifted[,j]
    ylim <- range(c(lo,mn,hi),finite=TRUE)
    if (diff(ylim)==0) ylim <- ylim+c(-.5,.5)
    graphics::plot(fit$time_relative,mn,type="l",lwd=2,
      xlab="Relative trajectory time (0 to 1)",
      ylab=paste0(colnames(fit$mean_path)[j]," (",fit$units,")"),
      main=paste0("Grid PCA mode ",component," - ",
                  colnames(fit$mean_path)[j]),ylim=ylim)
    graphics::lines(fit$time_relative,lo,col="#1B7F8C",lty=2)
    graphics::lines(fit$time_relative,hi,col="#AA5533",lty=2)
  }
  invisible(fit)
}
