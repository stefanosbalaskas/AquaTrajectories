#' Convert incomplete aquatic trajectories to sparse functional observations
#'
#' Prepares one coordinate at a time as ragged Ly/Lt lists for a separately
#' qualified functional-data backend. Only manually marked OBSERVED, finite
#' positions are retained. No linear interpolation or false 3D assumption.
#' Every camera/session/track scope forms one curve; researchers must decide
#' if these scopes are biologically independent and representative.
#'
#' @param tracks Canonical 2D/3D aqt_tracks with possible missing samples.
#' @param coordinate x, y, or z (z requires 3D).
#' @param time_axis "relative" rescales each complete recording time range
#'   to 0..1; "absolute" keeps the original session-clock seconds.
#' @param min_points At least 3 observed points per scoped fish.
#' @return aqt_sparse_fpca_input with Ly, Lt, scope, missingness audit,
#'   coordinate units and time axis metadata.
#' @export
aqt_sparse_fpca_input <- function(tracks,coordinate="x",
                                  time_axis=c("relative","absolute"),
                                  min_points=3L) {
  aqt_tracks_validate(tracks)
  time_axis <- match.arg(time_axis)
  axes <- c("x","y",if (identical(attr(tracks,"aqt_dimension"),3L)) "z")
  if (!is.character(coordinate) || length(coordinate)!=1L ||
      !coordinate %in% axes)
    stop("Coordinate must be an available observed x/y/z axis",call.=FALSE)
  if (!is.numeric(min_points) || length(min_points)!=1L ||
      !is.finite(min_points) || min_points<3L ||
      min_points!=floor(min_points))
    stop("min_points must be an integer >=3",call.=FALSE)
  if (!nrow(tracks)) stop("No fish trajectories supplied",call.=FALSE)
  d <- as.data.frame(tracks)
  keys <- interaction(d$session_id,d$camera_id,d$track_id,drop=TRUE)
  groups <- split(seq_len(nrow(d)),keys)
  if (length(groups)<5L)
    stop("Sparse FPCA preparation requires >=5 scoped curves",call.=FALSE)
  Ly <- vector("list",length(groups))
  Lt <- vector("list",length(groups))
  scopes <- vector("list",length(groups))
  names(Ly) <- names(Lt) <- names(groups)
  for (i in seq_along(groups)) {
    z <- d[groups[[i]],,drop=FALSE]
    z <- z[order(z$time_s),,drop=FALSE]
    ok <- z$observed & is.finite(z[[coordinate]])
    keep <- z[ok,,drop=FALSE]
    if (nrow(keep)<min_points)
      stop("Insufficient observed samples for scoped curve: ",
           names(groups)[i],call.=FALSE)
    times <- keep$time_s
    if (any(diff(times)<=0))
      stop("Observed curve times must be unique and increasing",
           call.=FALSE)
    if (time_axis=="relative") {
      span <- max(z$time_s)-min(z$time_s)
      if (span<=0) stop("Each scope needs a nonzero total time range",call.=FALSE)
      times <- (times-min(z$time_s))/span
    }
    Ly[[i]] <- as.numeric(keep[[coordinate]])
    Lt[[i]] <- as.numeric(times)
    scopes[[i]] <- data.frame(session_id=z$session_id[1L],
      camera_id=z$camera_id[1L],track_id=z$track_id[1L],
      n_total=nrow(z),n_observed=length(times),
      observed_fraction=length(times)/nrow(z),
      first_time_s=min(z$time_s),last_time_s=max(z$time_s),
      min_design_time=min(times),max_design_time=max(times),
      stringsAsFactors=FALSE)
  }
  scope <- do.call(rbind,unname(scopes))
  rownames(scope) <- NULL
  structure(list(Ly=Ly,Lt=Lt,scope=scope,
    axis=coordinate,time_axis=time_axis,
    units=attr(tracks,"aqt_units"),
    dimension=attr(tracks,"aqt_dimension"),
    missingness_explicit=TRUE,
    dataType="Sparse"),
    class="aqt_sparse_fpca_input")
}

#' Audit sparse functional observation coverage in common time bins
#'
#' Low coverage or many snippet-like curves can make the mean and
#' covariance surface poorly identified. This audit does not certify
#' PACE smoothing bandwidth, eigenfunctions or uncertainty coverage.
#'
#' @param input Output of aqt_sparse_fpca_input().
#' @param bins Integer 5..100 equal-width support bins.
#' @return Per-bin counts of distinct fish curves with data.
#' @export
aqt_sparse_fpca_design_audit <- function(input,bins=10L) {
  if (!inherits(input,"aqt_sparse_fpca_input") ||
      !is.list(input$Lt) || !length(input$Lt))
    stop("Expected an aqt_sparse_fpca_input",call.=FALSE)
  if (!is.numeric(bins) || length(bins)!=1L || !is.finite(bins) ||
      bins<5L || bins>100L || bins!=floor(bins))
    stop("bins must be an integer between 5 and 100",call.=FALSE)
  all_times <- unlist(input$Lt,use.names=FALSE)
  lo <- min(all_times);hi <- max(all_times)
  if (hi<=lo) stop("Common design time range is zero",call.=FALSE)
  edges <- seq(lo,hi,length.out=bins+1L)
  n <- length(input$Lt)
  present <- matrix(FALSE,nrow=n,ncol=as.integer(bins))
  for (i in seq_len(n)) {
    b <- findInterval(input$Lt[[i]],edges,
                      rightmost.closed=TRUE,all.inside=TRUE)
    present[i,unique(b)] <- TRUE
  }
  data.frame(bin=seq_len(bins),left=edges[-length(edges)],
    right=edges[-1L],n_curves=colSums(present),
    curve_fraction=colMeans(present),
    n_total_curves=n,
    low_coverage=colMeans(present)<.2)
}

#' Fit an independently maintained sparse FPCA backend to fish coordinates
#'
#' Uses fdapace::FPCA when fdapace is installed. The backend is not
#' EyeTrajectories and this adapter does not claim native R parity for
#' unverified EyeTrajectories methods. Report the fdapace version and
#' verify temporal design coverage before interpreting eigenfunctions.
#'
#' @param input aqt_sparse_fpca_input.
#' @param optns Additional fdapace options; dataType="Sparse" and
#'   plot=FALSE are enforced.
#' @return aqt_sparse_fpca_fit containing original backend result and metadata.
#' @export
aqt_sparse_fpca_fit <- function(input,optns=list()) {
  if (!inherits(input,"aqt_sparse_fpca_input"))
    stop("Expected aqt_sparse_fpca_input",call.=FALSE)
  if (!is.list(optns) ||
      (length(optns) && (is.null(names(optns)) ||
        any(!nzchar(names(optns))))))
    stop("optns must be a named options list",call.=FALSE)
  if (!requireNamespace("fdapace",quietly=TRUE))
    stop("Install optional fdapace to fit sparse functional PCA",
         call.=FALSE)
  if (any(names(optns) %in% c("dataType","plot")))
    stop("dataType and plot are fixed by the aquatic adapter",
         call.=FALSE)
  options <- c(list(dataType="Sparse",plot=FALSE),optns)
  fit <- fdapace::FPCA(input$Ly,input$Lt,optns=options)
  structure(list(fit=fit,input_scope=input$scope,
    input_audit=aqt_sparse_fpca_design_audit(input),
    coordinate=input$axis,units=input$units,time_axis=input$time_axis,
    backend="fdapace",backend_version=as.character(
      utils::packageVersion("fdapace")),
    eyetrajectories_parity_claim=FALSE),
    class="aqt_sparse_fpca_fit")
}
