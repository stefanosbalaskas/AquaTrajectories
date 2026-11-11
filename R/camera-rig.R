# AquaTrajectories: calibrated, pinhole camera rig for known-correspondence
# stereo fish tracks. This deliberately does not solve underwater refraction
# or automatic cross-camera identity association.

#' Construct a calibrated pinhole camera rig
#'
#' Projection matrices must use one common metric world-coordinate system.
#' Declaring an optical interface does not correct refraction: 3D pinhole
#' reconstruction explicitly refuses such rigs.
#'
#' @param projections Named list of at least two finite 3-by-4 pinhole P matrices.
#' @param units World-position units, cm or m.
#' @param optical_path One of air_only or refractive_interface.
#' @return A validated aqt_rig object.
#' @export
aqt_rig_new <- function(projections,units="cm",
                        optical_path=c("air_only","refractive_interface")) {
  optical_path <- match.arg(optical_path)
  if (!is.list(projections) || length(projections)<2L ||
      is.null(names(projections)) ||
      anyNA(names(projections)) || any(!nzchar(names(projections))) ||
      anyDuplicated(names(projections)))
    stop("projections must be a named list of two or more cameras",call.=FALSE)
  if (length(units)!=1L || !units %in% c("cm","m"))
    stop("World units must be cm or m",call.=FALSE)
  for (nm in names(projections)) {
    P <- projections[[nm]]
    if (!is.matrix(P) || !is.numeric(P) ||
        !identical(dim(P),c(3L,4L)) || any(!is.finite(P)))
      stop("Each projection matrix must be finite numeric 3x4",call.=FALSE)
    if (qr(P[,1:3,drop=FALSE])$rank<3L)
      stop("Camera projection must have an invertible 3x3 left block",call.=FALSE)
  }
  structure(list(projections=projections,units=units,
    optical_path=optical_path,calibration_qualified=FALSE),class="aqt_rig")
}

#' Verify calibrated camera rig structure
#' @param rig aqt_rig to check.
#' @return TRUE invisibly, or an error.
#' @export
aqt_rig_validate <- function(rig) {
  if (!inherits(rig,"aqt_rig") || !is.list(rig) ||
      !identical(rig$calibration_qualified,FALSE))
    stop("Expected an unqualified aqt_rig object",call.=FALSE)
  aqt_rig_new(rig$projections,rig$units,rig$optical_path)
  invisible(TRUE)
}

#' Calculate camera-centre separation under a pinhole model
#'
#' @param rig Calibrated camera rig.
#' @param camera_a,camera_b Camera labels in rig.
#' @return Distance between camera centres in rig world-coordinate units.
#' @export
aqt_rig_baseline <- function(rig,camera_a,camera_b) {
  aqt_rig_validate(rig)
  if (!all(c(camera_a,camera_b) %in% names(rig$projections)) ||
      identical(camera_a,camera_b))
    stop("Distinct rig camera IDs required",call.=FALSE)
  centre <- function(P) as.vector(-solve(P[,1:3,drop=FALSE],P[,4]))
  a <- centre(rig$projections[[camera_a]])
  b <- centre(rig$projections[[camera_b]])
  sqrt(sum((a-b)^2))
}

#' Project known world XYZ positions into one camera's image plane
#'
#' This performs projective pinhole geometry, not aquatic refraction.
#' @param rig Camera rig.
#' @param points Numeric n-by-3 XYZ matrix in rig units.
#' @param camera_id Camera in rig.
#' @return Data frame of projected x, y and valid flags.
#' @export
aqt_rig_project <- function(rig,points,camera_id) {
  aqt_rig_validate(rig)
  if (length(camera_id)!=1L || !camera_id %in% names(rig$projections))
    stop("Unknown camera_id",call.=FALSE)
  p <- as.matrix(points)
  if (!is.numeric(p) || ncol(p)!=3L)
    stop("points must be a numeric n-by-3 matrix",call.=FALSE)
  if (any(!is.finite(p)))
    stop("XYZ points must be finite",call.=FALSE)
  P <- rig$projections[[camera_id]]
  world <- cbind(p,1)
  proj <- t(P %*% t(world))
  valid <- is.finite(proj[,3]) & abs(proj[,3])>1e-12
  x <- rep(NA_real_,nrow(p));y <- x
  x[valid] <- proj[valid,1]/proj[valid,3]
  y[valid] <- proj[valid,2]/proj[valid,3]
  data.frame(x=x,y=y,valid=valid)
}

.aqt_join_key <- function(s,id,t) {
  paste(as.character(s),as.character(id),
        sprintf("%.17g",as.numeric(t)),sep="\r")
}

#' Reconstruct explicitly matched two-view fish trajectories into 3D
#'
#' This is a strict known-correspondence stereo primitive. The external
#' correspondences table must supply correctly matched fish identities and
#' original timestamps in two already synchronized camera clocks.
#' A track ID in one camera is NOT assumed to match the same ID in another.
#' Water/glass/air refraction and fisheye effects must be corrected with
#' separately validated calibration models; this function will reject
#' a rig declaring a refractive optical interface.
#'
#' @param view_a,view_b 2D image-pixel aqt_tracks, each from one camera.
#' @param correspondences Data frame session_id, id_a, id_b,
#'   time_a_s, time_b_s, fish_id. Each row describes one known matching pair.
#' @param rig aqt_rig containing both cameras' P matrices.
#' @param max_skew_s Maximum permitted absolute synchronized time difference.
#' @return A physical-unit 3D aqt_tracks object with reprojection and
#'   time-skew diagnostics and source track labels.
#' @export
aqt_reconstruct_3d <- function(view_a,view_b,correspondences,rig,
                               max_skew_s=.02) {
  aqt_tracks_validate(view_a)
  aqt_tracks_validate(view_b)
  aqt_rig_validate(rig)
  if (!identical(attr(view_a,"aqt_dimension"),2L) ||
      !identical(attr(view_b,"aqt_dimension"),2L) ||
      !identical(attr(view_a,"aqt_coordinate_system"),"image") ||
      !identical(attr(view_b,"aqt_coordinate_system"),"image") ||
      !identical(attr(view_a,"aqt_units"),"px") ||
      !identical(attr(view_b,"aqt_units"),"px"))
    stop("Requires two 2D pixel-space image trajectory objects",call.=FALSE)
  if (!identical(rig$optical_path,"air_only"))
    stop("Refraction-aware reconstruction is not implemented; no pinhole shortcut",call.=FALSE)
  if (length(max_skew_s)!=1L || !is.numeric(max_skew_s) ||
      !is.finite(max_skew_s) || max_skew_s<0)
    stop("max_skew_s must be a finite nonnegative threshold",call.=FALSE)
  a <- as.data.frame(view_a);b <- as.data.frame(view_b)
  camera_a <- unique(a$camera_id);camera_b <- unique(b$camera_id)
  if (length(camera_a)!=1L || length(camera_b)!=1L ||
      camera_a==camera_b ||
      !all(c(camera_a,camera_b) %in% names(rig$projections)))
    stop("Each view must contain one distinct camera present in rig",call.=FALSE)
  if (aqt_rig_baseline(rig,camera_a,camera_b)<=1e-10)
    stop("Degenerate camera baseline",call.=FALSE)
  req <- c("session_id","id_a","id_b","time_a_s","time_b_s","fish_id")
  if (!is.data.frame(correspondences) ||
      !all(req %in% names(correspondences)) ||
      !nrow(correspondences))
    stop("Expected nonempty explicit cross-view correspondences",call.=FALSE)
  cdata <- as.data.frame(correspondences)
  for (nm in c("session_id","id_a","id_b","fish_id")) {
    if (anyNA(cdata[[nm]]) || any(!nzchar(as.character(cdata[[nm]]))))
      stop("Correspondence identities must be explicit",call.=FALSE)
    cdata[[nm]] <- as.character(cdata[[nm]])
  }
  for (nm in c("time_a_s","time_b_s")) {
    if (!is.numeric(cdata[[nm]]) || any(!is.finite(cdata[[nm]])))
      stop("Correspondence times must be finite",call.=FALSE)
  }
  skew <- abs(cdata$time_a_s-cdata$time_b_s)
  if (any(skew>max_skew_s))
    stop("Camera observations exceed permitted synchronization skew",call.=FALSE)
  ia <- match(.aqt_join_key(cdata$session_id,cdata$id_a,cdata$time_a_s),
              .aqt_join_key(a$session_id,a$track_id,a$time_s))
  ib <- match(.aqt_join_key(cdata$session_id,cdata$id_b,cdata$time_b_s),
              .aqt_join_key(b$session_id,b$track_id,b$time_s))
  if (anyNA(ia) || anyNA(ib))
    stop("Some externally matched observations are absent from their camera tracks",call.=FALSE)
  if (anyDuplicated(ia) || anyDuplicated(ib))
    stop("One camera observation assigned to multiple fish correspondences",call.=FALSE)
  xy1 <- as.matrix(a[ia,c("x","y"),drop=FALSE])
  xy2 <- as.matrix(b[ib,c("x","y"),drop=FALSE])
  good <- a$observed[ia] & b$observed[ib] &
    stats::complete.cases(xy1) & stats::complete.cases(xy2)
  xy1[!good,] <- NA_real_
  xy2[!good,] <- NA_real_
  tri <- aqt_triangulate_pairs(xy1,xy2,
            rig$projections[[camera_a]],rig$projections[[camera_b]])
  if (!any(tri$valid)) stop("No valid 3D reconstructed positions",call.=FALSE)
  out <- data.frame(session_id=cdata$session_id,camera_id="FUSED3D",
    track_id=cdata$fish_id,
    time_s=(cdata$time_a_s+cdata$time_b_s)/2,
    x=tri$x,y=tri$y,z=tri$z,observed=tri$valid & good,
    source_camera_a=camera_a,source_camera_b=camera_b,
    source_id_a=cdata$id_a,source_id_b=cdata$id_b,
    time_a_s=cdata$time_a_s,time_b_s=cdata$time_b_s,
    time_skew_s=skew,reprojection_rmse_px=tri$reprojection_rmse)
  invalid <- !out$observed
  out$x[invalid] <- NA_real_
  out$y[invalid] <- NA_real_
  out$z[invalid] <- NA_real_
  result <- aqt_tracks(out,units=rig$units,coordinate_system="tank")
  attr(result,"aqt_rig") <- rig
  result
}

#' Summarize quality of reconstructed stereo fish positions
#' @param reconstructed aqt_tracks returned by aqt_reconstruct_3d.
#' @return Per-session counts, missing proportions, reprojection error
#'   and synchronized time-skew diagnostics. A low reprojection error
#'   is not proof of absolute XYZ accuracy.
#' @export
aqt_reconstruction_quality <- function(reconstructed) {
  aqt_tracks_validate(reconstructed)
  needed <- c("session_id","observed","time_skew_s","reprojection_rmse_px")
  if (!all(needed %in% names(reconstructed)))
    stop("Expected reconstructed 3D tracks with stereo QC fields",call.=FALSE)
  groups <- split(seq_len(nrow(reconstructed)),reconstructed$session_id)
  out <- lapply(groups,function(idx) {
    d <- reconstructed[idx,,drop=FALSE]
    valid <- d$observed & !is.na(d$reprojection_rmse_px)
    data.frame(session_id=d$session_id[1L],
      n_pairs=nrow(d),n_reconstructed=sum(valid),
      missing_fraction=mean(!valid),
      median_reprojection_px=if (any(valid))
        stats::median(d$reprojection_rmse_px[valid]) else NA_real_,
      max_reprojection_px=if (any(valid))
        max(d$reprojection_rmse_px[valid]) else NA_real_,
      max_time_skew_s=max(d$time_skew_s))
  })
  do.call(rbind,unname(out))
}
