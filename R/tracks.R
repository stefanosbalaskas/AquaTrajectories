#' Construct a validated aquatic-animal trajectory table
#' @param data Data frame with session_id, camera_id, track_id, time_s, x, y;
#'   optional z and observed.
#' @param units Coordinate units: px, cm, or m.
#' @param coordinate_system image or tank.
#' @return An aqt_tracks object. IDs only apply within session and camera.
#' @export
aqt_tracks <- function(data, units = "px", coordinate_system = "image") {
  if (!is.data.frame(data)) stop("data must be a data.frame", call. = FALSE)
  required <- c("session_id", "camera_id", "track_id", "time_s", "x", "y")
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("Missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (length(units) != 1L || !units %in% c("px", "cm", "m"))
    stop("Unsupported units", call. = FALSE)
  if (length(coordinate_system) != 1L || !coordinate_system %in% c("image", "tank"))
    stop("Unsupported coordinate system", call. = FALSE)
  d <- as.data.frame(data)
  for (nm in c("session_id","camera_id","track_id")) {
    if (anyNA(d[[nm]]) || any(!nzchar(as.character(d[[nm]]))))
      stop(nm, " must contain nonempty identifiers", call. = FALSE)
    d[[nm]] <- as.character(d[[nm]])
  }
  for (nm in c("time_s","x","y"))
    if (!is.numeric(d[[nm]])) stop(nm, " must be numeric", call. = FALSE)
  if (!"z" %in% names(d)) d$z <- rep(NA_real_,nrow(d))
  if (!is.numeric(d$z)) stop("z must be numeric", call. = FALSE)
  if (any(!is.finite(d$time_s))) stop("time_s must be finite", call. = FALSE)
  if (any(is.infinite(d$x)) || any(is.infinite(d$y)) || any(is.infinite(d$z)))
    stop("Coordinates cannot be infinite", call. = FALSE)
  if (any(xor(is.na(d$x), is.na(d$y))))
    stop("x and y must both be present or both missing", call. = FALSE)
  dimn <- if (any(!is.na(d$z))) 3L else 2L
  if (dimn == 3L && coordinate_system == "image")
    stop("3D trajectories require tank coordinates", call. = FALSE)
  if (!"observed" %in% names(d)) d$observed <- !is.na(d$x) & !is.na(d$y)
  if (!is.logical(d$observed) || anyNA(d$observed))
    stop("observed must be nonmissing logical", call. = FALSE)
  d <- d[order(d$session_id,d$camera_id,d$track_id,d$time_s),,drop=FALSE]
  rownames(d) <- NULL
  key <- paste(d$session_id,d$camera_id,d$track_id,format(d$time_s,digits=17),sep="|")
  if (anyDuplicated(key)) stop("Duplicate time within scoped track",call.=FALSE)
  class(d) <- c("aqt_tracks","data.frame")
  attr(d,"aqt_units") <- units
  attr(d,"aqt_coordinate_system") <- coordinate_system
  attr(d,"aqt_dimension") <- dimn
  d
}

#' Validate trajectory structure
#' @param x An aqt_tracks object.
#' @return TRUE invisibly or an error.
#' @export
aqt_tracks_validate <- function(x) {
  if (!inherits(x,"aqt_tracks")) stop("Expected aqt_tracks",call.=FALSE)
  aqt_tracks(as.data.frame(x),attr(x,"aqt_units"),attr(x,"aqt_coordinate_system"))
  invisible(TRUE)
}

#' @export
print.aqt_tracks <- function(x, ...) {
  cat("<aqt_tracks>",nrow(x),"rows;",attr(x,"aqt_dimension"),
      "dimensions;",attr(x,"aqt_units"),"\n")
  invisible(x)
}

#' Import a canonical long-format CSV
#' @param path CSV file path.
#' @param units Coordinate units.
#' @param coordinate_system image or tank.
#' @export
aqt_import_csv <- function(path, units="px", coordinate_system="image") {
  # Reading only column names first avoids numeric type guessing on fish IDs.
  column_names <- names(utils::read.csv(path,nrows=0L,
                                         stringsAsFactors=FALSE))
  classes <- stats::setNames(rep(NA_character_,length(column_names)),
                             column_names)
  ids <- intersect(c("session_id","camera_id","track_id"),column_names)
  classes[ids] <- "character"
  d <- utils::read.csv(path,stringsAsFactors=FALSE,colClasses=classes)
  # All-blank numeric columns are inferred by read.csv as logical NA.
  # Only repair that narrow, lossless case; leave malformed values to the
  # existing aqt_tracks() schema validator.
  for (nm in intersect(c("x","y","z"),names(d))) {
    if (is.logical(d[[nm]]) && all(is.na(d[[nm]])))
      d[[nm]] <- rep(NA_real_,nrow(d))
  }
  aqt_tracks(d,units,coordinate_system)
}

#' Import explicitly exported YOLO/Ultralytics long-format tracks
#' @param path CSV path with track_id or fish_id, x_px and y_px.
#' @param session_id Session identifier.
#' @param camera_id Camera identifier.
#' @param fps FPS if time_s is absent and frame is present.
#' @param frame_origin Index representing zero seconds.
#' @export
aqt_import_yolo <- function(path,session_id,camera_id,fps=NULL,frame_origin=0) {
  d <- utils::read.csv(path,stringsAsFactors=FALSE)
  id <- if ("track_id" %in% names(d)) "track_id" else if ("fish_id" %in% names(d)) "fish_id" else ""
  if (!nzchar(id) || !all(c("x_px","y_px") %in% names(d)))
    stop("Expected track_id/fish_id, x_px and y_px",call.=FALSE)
  if (!"time_s" %in% names(d)) {
    if (is.null(fps) || length(fps)!=1L || !is.finite(fps) || fps<=0 || !"frame" %in% names(d))
      stop("Supply time_s or frame and a positive fps",call.=FALSE)
    d$time_s <- (d$frame-frame_origin)/fps
  }
  d$session_id <- session_id; d$camera_id <- camera_id
  d$track_id <- d[[id]]; d$x <- d$x_px; d$y <- d$y_px
  aqt_tracks(d)
}

#' Import long-form idtracker.ai tracks after explicit reshaping
#' @param path CSV path containing track_id, time_s, x, y.
#' @param session_id Session identifier.
#' @param camera_id Camera identifier.
#' @export
aqt_import_idtracker <- function(path,session_id,camera_id) {
  d <- utils::read.csv(path,stringsAsFactors=FALSE)
  if (!all(c("track_id","time_s","x","y") %in% names(d)))
    stop("Requires long-format track_id,time_s,x,y; reshape wide exports first",call.=FALSE)
  d$session_id<-session_id; d$camera_id<-camera_id
  aqt_tracks(d)
}

#' Export canonical trajectories
#' @param tracks An aqt_tracks object.
#' @param path Output CSV path.
#' @return Path invisibly.
#' @export
aqt_export_csv <- function(tracks,path) {
  aqt_tracks_validate(tracks)
  utils::write.csv(as.data.frame(tracks),path,row.names=FALSE,na="")
  invisible(path)
}
