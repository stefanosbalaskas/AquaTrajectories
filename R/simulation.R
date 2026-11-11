#' Simulate deterministic mathematical fish paths
#'
#' The random walks are testing fixtures and are NOT biologically calibrated.
#' @param n_fish Positive integer number of animals.
#' @param n_frames Number of frames.
#' @param fps Positive sampling rate.
#' @param dimension Either 2 or 3.
#' @param seed Random seed.
#' @return Synthetic aqt_tracks in tank/cm units.
#' @export
aqt_simulate_tracks <- function(n_fish=5L,n_frames=200L,fps=30,
                                dimension=2L,seed=7L) {
  if (length(n_fish)!=1L || is.na(n_fish) || n_fish<1 ||
      n_fish!=as.integer(n_fish) ||
      length(n_frames)!=1L || is.na(n_frames) || n_frames<2 ||
      n_frames!=as.integer(n_frames) ||
      length(fps)!=1L || !is.finite(fps) || fps<=0 ||
      length(dimension)!=1L || !dimension %in% c(2L,3L))
    stop("Invalid simulator configuration",call.=FALSE)
  had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if (had) old <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (had) assign(".Random.seed",old,envir=.GlobalEnv)
    else if (exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
      rm(".Random.seed",envir=.GlobalEnv)
  },add=TRUE)
  set.seed(seed)
  res <- lapply(seq_len(n_fish),function(i) {
    steps <- matrix(stats::rnorm(n_frames*dimension,sd=0.3),ncol=dimension)
    coords <- apply(steps,2L,cumsum)
    if (!is.matrix(coords)) coords <- matrix(coords,ncol=dimension)
    data.frame(session_id="S01",camera_id="SIM",track_id=paste0("fish",i),
      time_s=(seq_len(n_frames)-1)/fps,x=coords[,1L],y=coords[,2L],
      z=if (dimension==3L) coords[,3L] else NA_real_)
  })
  aqt_tracks(do.call(rbind,res),units="cm",coordinate_system="tank")
}
