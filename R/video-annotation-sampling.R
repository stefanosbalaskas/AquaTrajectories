# Wave 11E: independent frame-annotation sampling BEFORE examining
# model predictions. This does NOT label any fish or validate the model.

#' Prespecify a random time-stratified video annotation frame sample
#'
#' Samples only from independently acquired video PTS manifests, not YOLO
#' predictions, detections, tracker confidence or inferred fish presence.
#' Frames are split into equal-duration time strata WITHIN each camera
#' recording, and a balanced number of acquired frames is sampled per
#' stratum using an RNG state that is restored before returning. Required
#' strata without frames or enough acquired frames fail closed, rather
#' than silently reducing or shifting the annotation sample.
#'
#' A plan is NOT a list of already annotated frames. Its
#' annotation_status is "planned_not_annotated" until real manual
#' annotation is completed; the bundle scorer explicitly rejects it.
#' After actual independent full-frame annotation, the caller may set
#' annotation_status to "fully_annotated" for those reviewed frames.
#'
#' @param frames Verified aqt_frame_manifest including zero-fish frames.
#' @param per_video Number of acquired frames to sample independently
#'   for every camera-local recording; positive integer.
#' @param strata Number of equal-duration temporal strata per recording,
#'   <= per_video and >=2. Each must supply its allocated frames.
#' @param seed Explicit nonnegative integer RNG seed.
#' @return aqt_annotation_plan frame table with sample probabilities,
#'   inverse selection weights and an unannotated status marker.
#' @export
aqt_annotation_frame_plan <- function(
    frames,per_video=60L,strata=6L,seed=11L) {
  if (!inherits(frames,"aqt_frame_manifest"))
    stop("Expected aqt_frame_manifest with real acquired frame PTS",
         call.=FALSE)
  m <- aqt_frame_manifest(as.data.frame(frames))
  for (z in list(per_video,strata))
    if (!is.numeric(z) || length(z)!=1L ||
        !is.finite(z) || z!=floor(z) || z<1)
      stop("per_video and strata must be positive integers",call.=FALSE)
  if (per_video<2L || strata<2L || strata>per_video)
    stop("Require >=2 requested frames and >=2 temporal strata",
         call.=FALSE)
  if (!is.numeric(seed) || length(seed)!=1L ||
      !is.finite(seed) || seed!=floor(seed) ||
      seed<0 || seed>=.Machine$integer.max)
    stop("seed must be a nonnegative integer",call.=FALSE)
  per_video <- as.integer(per_video)
  strata <- as.integer(strata)
  groups <- split(seq_len(nrow(m)),
    paste(m$session_id,m$camera_id,sep="\r"))
  saved_seed <- exists(".Random.seed",envir=.GlobalEnv,
                       inherits=FALSE)
  if (saved_seed) previous_seed <- get(".Random.seed",envir=.GlobalEnv)
  on.exit({
    if (saved_seed) {
      assign(".Random.seed",previous_seed,envir=.GlobalEnv)
    } else if (exists(".Random.seed",envir=.GlobalEnv,
                      inherits=FALSE)) {
      rm(".Random.seed",envir=.GlobalEnv)
    }
  },add=TRUE)
  set.seed(as.integer(seed))
  out <- vector("list",length(groups))
  n <- 0L
  for (idx in groups) {
    video <- m[idx,,drop=FALSE]
    if (nrow(video)<per_video)
      stop("Video has fewer acquired frames than requested annotations",
           call.=FALSE)
    duration <- max(video$time_s)-min(video$time_s)
    if (!is.finite(duration) || duration<=0)
      stop("Video must have a strictly positive presentation time span",
           call.=FALSE)
    edges <- seq(min(video$time_s),max(video$time_s),
                 length.out=strata+1L)
    bins <- findInterval(video$time_s,edges,
                         rightmost.closed=TRUE,all.inside=TRUE)
    # The remainder is allocated to the earliest strata by a declared
    # deterministic rule; the exact unequal quotas are always recorded.
    quota <- rep.int(as.integer(per_video%/%strata),strata)
    remainder <- per_video %% strata
    if (remainder>0L) quota[seq_len(remainder)] <-
      quota[seq_len(remainder)]+1L
    available <- tabulate(bins,nbins=strata)
    if (any(available<quota))
      stop("Too few acquired frames in at least one time stratum; choose fewer strata or a smaller sample",
           call.=FALSE)
    selected <- vector("list",strata)
    for (j in seq_len(strata)) {
      candidates <- which(bins==j)
      take <- sort(candidates[sample.int(length(candidates),quota[j])])
      z <- video[take,,drop=FALSE]
      z$temporal_stratum <- j
      z$stratum_start_s <- edges[j]
      z$stratum_end_s <- edges[j+1L]
      z$n_stratum_available <- available[j]
      z$n_stratum_selected <- quota[j]
      z$selection_probability <- quota[j]/available[j]
      z$inverse_selection_probability <- available[j]/quota[j]
      z$annotation_status <- "planned_not_annotated"
      selected[[j]] <- z
    }
    n <- n+1L
    out[[n]] <- do.call(rbind,selected)
  }
  result <- do.call(rbind,out)
  result <- result[order(result$session_id,result$camera_id,
                         result$frame_id),,drop=FALSE]
  rownames(result) <- NULL
  class(result) <- c("aqt_annotation_plan","data.frame")
  attr(result,"aqt_sampling_seed") <- as.integer(seed)
  attr(result,"aqt_sampling_design") <-
    "equal-duration temporal strata, uniform acquired-frame sample without replacement"
  attr(result,"aqt_annotation_source_verified") <- FALSE
  attr(result,"aqt_annotations_completed") <- FALSE
  result
}

#' Audit prespecified video-frame annotation sample support and coverage
#'
#' This checks the recorded sampling design against an acquired-frame
#' manifest, not truth of fish labels or human reviewer independence.
#' \`n_frames_selected\` must never be confused with fish-level or
#' independently treated tank-level replication.
#'
#' @param plan aqt_annotation_plan from aqt_annotation_frame_plan().
#' @param frames Original aqt_frame_manifest from the same video recordings.
#' @return aqt_annotation_plan_audit list with per-video and per-temporal
#'   stratum acquired/sample counts and inclusion probabilities.
#' @export
aqt_annotation_plan_audit <- function(plan,frames) {
  if (!inherits(plan,"aqt_annotation_plan") ||
      !all(c("session_id","camera_id","frame_id","time_s",
             "temporal_stratum","selection_probability",
             "inverse_selection_probability",
             "n_stratum_available","n_stratum_selected",
             "annotation_status") %in% names(plan)))
    stop("Expected aqt_annotation_plan",call.=FALSE)
  if (!inherits(frames,"aqt_frame_manifest"))
    stop("Expected original aqt_frame_manifest",call.=FALSE)
  m <- aqt_frame_manifest(as.data.frame(frames))
  p <- as.data.frame(plan)
  key <- function(d) paste(d$session_id,d$camera_id,d$frame_id,sep="\r")
  if (anyDuplicated(key(p)))
    stop("Duplicate sampled annotation frame",call.=FALSE)
  ref <- match(key(p),key(m))
  if (anyNA(ref) ||
      any(!is.finite(p$time_s)) ||
      any(abs(p$time_s-m$time_s[ref])>1e-8))
    stop("Annotation plan frames or timestamps do not match acquired video",
         call.=FALSE)
  if (anyNA(p$annotation_status) ||
      any(!p$annotation_status %in%
          c("planned_not_annotated","fully_annotated")))
    stop("Annotation status must be planned_not_annotated or fully_annotated",
         call.=FALSE)
  groups <- split(seq_len(nrow(p)),
    paste(p$session_id,p$camera_id,sep="\r"))
  per_video <- list();per_bin <- list();n <- 0L;q <- 0L
  for (idx in groups) {
    z <- p[idx,,drop=FALSE]
    available <- m[m$session_id==z$session_id[1L] &
                   m$camera_id==z$camera_id[1L],,drop=FALSE]
    bins <- sort(unique(z$temporal_stratum))
    if (anyNA(bins) || any(bins!=seq_along(bins)))
      stop("Temporal annotation strata must be complete consecutive integers",
           call.=FALSE)
    if (!all(c("stratum_start_s","stratum_end_s") %in% names(z)))
      stop("Missing temporal stratum endpoints",call.=FALSE)
    for (j in bins) {
      w <- z[z$temporal_stratum==j,,drop=FALSE]
      if (any(!is.finite(w$selection_probability)) ||
          any(!is.finite(w$inverse_selection_probability)) ||
          any(w$selection_probability<=0 | w$selection_probability>1) ||
          any(w$inverse_selection_probability<1))
        stop("Invalid frame sampling probabilities",call.=FALSE)
      if (length(unique(w$stratum_start_s))!=1L ||
          length(unique(w$stratum_end_s))!=1L ||
          w$stratum_start_s[1L]>=w$stratum_end_s[1L])
        stop("Invalid temporal stratum bounds",call.=FALSE)
      lo <- w$stratum_start_s[1L]; hi <- w$stratum_end_s[1L]
      n_available <- sum(available$time_s>=lo &
        if (j==max(bins)) available$time_s<=hi
        else available$time_s<hi)
      n_selected <- nrow(w)
      if (n_available!=w$n_stratum_available[1L] ||
          n_selected!=w$n_stratum_selected[1L] ||
          any(w$n_stratum_available!=n_available) ||
          any(w$n_stratum_selected!=n_selected) ||
          any(abs(w$selection_probability-
                  n_selected/n_available)>1e-10) ||
          any(abs(w$inverse_selection_probability-
                  n_available/n_selected)>1e-10))
        stop("Annotation sample counts or inclusion weights contradict acquired video",
             call.=FALSE)
      q <- q+1L
      per_bin[[q]] <- data.frame(
        session_id=z$session_id[1L],camera_id=z$camera_id[1L],
        temporal_stratum=j,
        n_acquired=n_available,n_selected=n_selected,
        coverage_fraction=n_selected/n_available,
        start_s=lo,end_s=hi)
    }
    n <- n+1L
    per_video[[n]] <- data.frame(
      session_id=z$session_id[1L],camera_id=z$camera_id[1L],
      n_acquired=nrow(available),n_planned=nrow(z),
      n_fully_annotated=sum(z$annotation_status=="fully_annotated"),
      planning_fraction=nrow(z)/nrow(available),
      complete_annotation_fraction=
        sum(z$annotation_status=="fully_annotated")/nrow(z))
  }
  structure(list(per_video=do.call(rbind,per_video),
    per_stratum=do.call(rbind,per_bin),
    sampling_is_prediction_independent_by_software_design=TRUE,
    independent_human_annotations_verified=FALSE,
    animal_welfare_or_model_accuracy_certified=FALSE,
    statistical_unit="recording and independently allocated tank, not sampled frames"),
    class="aqt_annotation_plan_audit")
}
