# Workstream 02: non-destructive, scope-aware trajectory quality control.
# Raw input, screened/reviewed tracks, and derived measurements remain separate.
.aqt_qc_numeric <- function(x) suppressWarnings(as.numeric(x))
.aqt_qc_scope <- function(session,camera,frame=NULL,track=NULL) {
  pieces <- list(as.character(session),as.character(camera))
  if (!is.null(frame)) pieces <- c(pieces,list(as.character(frame)))
  if (!is.null(track)) pieces <- c(pieces,list(as.character(track)))
  do.call(paste,c(pieces,list(sep="\r")))
}
.aqt_qc_limit <- function(x,name,allow_null=FALSE) {
  if (is.null(x) && allow_null) return(invisible(TRUE))
  if (!is.numeric(x) || length(x)!=1L || is.na(x) ||
      !is.finite(x) || x<=0) stop(name," must be a finite positive scalar",call.=FALSE)
  invisible(TRUE)
}
.aqt_qc_frames <- function(frames) {
  req <- c("session_id","camera_id","frame_id","time_s","width_px","height_px")
  if (!is.data.frame(frames) || !all(req %in% names(frames)) ||
      !nrow(frames)) stop("Complete nonempty frame manifest required",call.=FALSE)
  f <- as.data.frame(frames[,req,drop=FALSE],stringsAsFactors=FALSE)
  for (nm in c("session_id","camera_id")) {
    f[[nm]] <- as.character(f[[nm]])
    if (anyNA(f[[nm]]) || any(!nzchar(f[[nm]]))) stop("Invalid frame scope",call.=FALSE)
  }
  for (nm in c("frame_id","time_s","width_px","height_px")) {
    if (!is.numeric(f[[nm]])) stop("Frame ",nm," must be numeric",call.=FALSE)
  }
  if (any(!is.finite(f$frame_id)) || any(f$frame_id<0) ||
      any(f$frame_id!=floor(f$frame_id)) ||
      any(!is.finite(f$width_px)) || any(!is.finite(f$height_px)) ||
      any(f$width_px<1 | f$height_px<1) ||
      any(f$width_px!=floor(f$width_px)) ||
      any(f$height_px!=floor(f$height_px)))
    stop("Invalid frame identifiers or dimensions",call.=FALSE)
  key <- .aqt_qc_scope(f$session_id,f$camera_id,f$frame_id)
  if (anyDuplicated(key)) stop("Duplicate frame in source manifest",call.=FALSE)
  for (ix in split(seq_len(nrow(f)),.aqt_qc_scope(f$session_id,f$camera_id))) {
    k <- ix[order(f$frame_id[ix])]
    tt <- f$time_s[k]
    if (!(all(is.na(tt)) ||
          (all(is.finite(tt)) && all(tt>=0) &&
           (length(tt)<2L || all(diff(tt)>0)))))
      stop("Frame clock must be complete strictly increasing seconds or entirely unknown",
           call.=FALSE)
  }
  f
}

#' Audit video-derived aquatic trajectories without editing source observations
#'
#' The original research bundle or caller-provided data are retained as raw.
#' Duplicate fish IDs, malformed positions, unmatched frames, invalid source
#' times, low confidence and excessive coordinate steps are flagged on BOTH
#' the row-level ledger and aggregate coverage tables. A gap flag refers to
#' a discontinuous step, not an automatically invalid point.
#'
#' Missing individual frames cannot be interpreted as detection false negatives
#' without an independently declared expected identity roster. Inferred ID
#' switches and biological stress/welfare are not measured by this function.
#'
#' @param input An imported aqt_research_bundle or raw observation data frame.
#' @param frames Complete frame manifest; omit for aqt_research_bundle input.
#' @param max_gap_s Maximum continuous observed movement interval, seconds.
#' @param max_speed Optional position-unit/second threshold; requires times.
#' @param max_jump_px Optional maximum image-space adjacent step in pixels.
#' @param min_detection_confidence Optional score threshold in [0,1].
#' @param expected_tracks Optional externally declared session_id,camera_id,track_id
#'  roster; used only for explicitly roster-based expected coverage.
#' @param truth Optional independent manually annotated point tracks.
#' @param evaluated_frames Explicit annotated frames, including empty frames.
#' @param max_reference_distance Distance tolerance for manual point tracking check.
#' @return An aqt_trajectory_qc object with raw, row_audit, coverage, optional
#'  manual_accuracy, provenance, and an immutable source-of-truth audit ledger.
#' @export
aqt_trajectory_qc <- function(input,frames=NULL,max_gap_s=.2,
                              max_speed=NULL,max_jump_px=NULL,
                              min_detection_confidence=NULL,
                              expected_tracks=NULL,truth=NULL,
                              evaluated_frames=NULL,
                              max_reference_distance=NULL) {
  .aqt_qc_limit(max_gap_s,"max_gap_s")
  .aqt_qc_limit(max_speed,"max_speed",allow_null=TRUE)
  .aqt_qc_limit(max_jump_px,"max_jump_px",allow_null=TRUE)
  if (!is.null(min_detection_confidence) &&
      (!is.numeric(min_detection_confidence) ||
       length(min_detection_confidence)!=1L ||
       !is.finite(min_detection_confidence) ||
       min_detection_confidence<0 || min_detection_confidence>1))
    stop("min_detection_confidence must be within [0,1]",call.=FALSE)
  is_bundle <- inherits(input,"aqt_research_bundle")
  if (is_bundle) {
    if (!is.null(frames)) stop("Bundle already contains authenticated frames",call.=FALSE)
    verified <- aqt_research_bundle_import(input$directory)
    raw <- as.data.frame(verified$observations)
    frames <- verified$frames
    time_provenance <- verified$metadata$time_status
    provenance <- list(source_type="research_bundle_v1",
      source_output_sha256=verified$metadata$output_sha256,
      recorded_tracking_kind=verified$metadata$tracking_kind,
      source_directory=verified$directory,
      independent_identity_certified=FALSE,
      independent_clock_certified=FALSE)
  } else {
    if (!is.data.frame(input)) stop("Expected a research bundle or raw data.frame",call.=FALSE)
    raw <- as.data.frame(input,stringsAsFactors=FALSE)
    time_provenance <- "user_supplied_not_independently_verified"
    provenance <- list(source_type="untrusted_raw_table",
       independent_identity_certified=FALSE,independent_clock_certified=FALSE)
  }
  f <- .aqt_qc_frames(frames)
  required <- c("session_id","camera_id","track_id","frame_id","time_s",
                "x","y","observed")
  if (!all(required %in% names(raw)))
    stop("Raw observations require: ",paste(required,collapse=","),call.=FALSE)
  if (inherits(input,"aqt_tracks") &&
      !identical(attr(input,"aqt_coordinate_system"),"image"))
    stop("This acquisition QC requires image-space coordinates; use the physical trajectory core directly for calibrated XYZ",call.=FALSE)
  if ("z" %in% names(raw) && any(!is.na(raw$z)))
    stop("This acquisition QC accepts source-image XY, not physical XYZ",call.=FALSE)
  if (!is.null(min_detection_confidence) &&
      !"detection_confidence" %in% names(raw))
    stop("A detector confidence cutoff requires source detection_confidence; identity probability is not interchangeable",call.=FALSE)
  n <- nrow(raw)
  raw_sha <- digest::digest(raw,algo="sha256",serialize=TRUE)
  id <- lapply(c("session_id","camera_id","track_id"),function(k)
    as.character(raw[[k]]))
  names(id) <- c("session_id","camera_id","track_id")
  frame <- .aqt_qc_numeric(raw$frame_id)
  time <- .aqt_qc_numeric(raw$time_s)
  x <- .aqt_qc_numeric(raw$x)
  y <- .aqt_qc_numeric(raw$y)
  observed <- raw$observed
  if (!is.logical(observed)) {
    observed <- as.character(observed)
    observed <- ifelse(observed %in% c("TRUE","T","1"),TRUE,
                       ifelse(observed %in% c("FALSE","F","0"),FALSE,NA))
  }
  conf <- if ("detection_confidence" %in% names(raw))
    .aqt_qc_numeric(raw$detection_confidence) else rep(NA_real_,n)
  keys <- .aqt_qc_scope(id$session_id,id$camera_id,frame)
  framekeys <- .aqt_qc_scope(f$session_id,f$camera_id,f$frame_id)
  frameix <- match(keys,framekeys)
  scope <- .aqt_qc_scope(id$session_id,id$camera_id)
  trackkey <- .aqt_qc_scope(id$session_id,id$camera_id,track=id$track_id)
  pairkey <- .aqt_qc_scope(id$session_id,id$camera_id,frame,track=id$track_id)
  dup <- duplicated(pairkey) | duplicated(pairkey,fromLast=TRUE)
  valid_id <- !is.na(id$session_id) & !is.na(id$camera_id) &
    !is.na(id$track_id) & nzchar(id$session_id) &
    nzchar(id$camera_id) & nzchar(id$track_id)
  valid_frame <- is.finite(frame) & frame>=0 & frame==floor(frame) &
    !is.na(frameix)
  has_xy <- is.finite(x) & is.finite(y)
  frame_has_time <- !is.na(frameix) & !is.na(f$time_s[pmax(1L,frameix)])
  expected_time <- rep(NA_real_,n)
  expected_time[!is.na(frameix)] <- f$time_s[frameix[!is.na(frameix)]]
  time_conflict <- !is.na(expected_time) &
    (!is.finite(time) | abs(time-expected_time)>1e-8)
  time_missing_declared <- is.na(expected_time)
  time_invented <- time_missing_declared & !is.na(time)
  time_unknown <- all(is.na(f$time_s))
  if (!time_unknown && any(vapply(split(seq_len(nrow(f)),
           .aqt_qc_scope(f$session_id,f$camera_id)),
           function(i) all(is.na(f$time_s[i])),logical(1L))) &&
      !is.null(max_speed))
    stop("max_speed requires known timestamps for every included scope",
         call.=FALSE)
  if (time_unknown && !is.null(max_speed))
    stop("max_speed requires real source timestamps",call.=FALSE)
  conflict_obs <- is.na(observed) |
    (!is.na(observed) & (observed != has_xy))
  width <- rep(NA_real_,n); height <- rep(NA_real_,n)
  width[!is.na(frameix)] <- f$width_px[frameix[!is.na(frameix)]]
  height[!is.na(frameix)] <- f$height_px[frameix[!is.na(frameix)]]
  out_of_bounds <- has_xy & (x<0 | y<0 | x>width | y>height)
  out_of_bounds[is.na(out_of_bounds)] <- FALSE
  nonfinite_position <- (!is.na(raw$x) & !is.finite(x)) |
    (!is.na(raw$y) & !is.finite(y))
  invalid_conf <- if ("detection_confidence" %in% names(raw))
    (!is.na(raw$detection_confidence) & !is.finite(conf)) |
    (!is.na(conf) & (conf<0 | conf>1)) else rep(FALSE,n)
  low_conf <- if (is.null(min_detection_confidence)) rep(FALSE,n) else
    !is.na(conf) & conf<min_detection_confidence
  step_delta <- rep(NA_real_,n); step_dt <- rep(NA_real_,n)
  large_gap <- rep(FALSE,n); jump <- rep(FALSE,n)
  excessive_speed <- rep(FALSE,n)
  valid_for_motion <- valid_id & valid_frame & !dup & has_xy &
    !conflict_obs & !out_of_bounds & !nonfinite_position & !time_conflict &
    !time_invented & !invalid_conf
  for (idx in split(seq_len(n),trackkey)) {
    if (length(idx)<2L) next
    idx <- idx[order(frame[idx],na.last=TRUE)]
    for (j in seq.int(2L,length(idx))) {
      a <- idx[j-1L]; b <- idx[j]
      if (!valid_for_motion[b]) next
      if (!valid_for_motion[a]) {
        large_gap[b] <- TRUE
        next
      }
      before <- frameix[a]; after <- frameix[b]
      # Two observations must refer to adjacent recorded acquisition frames.
      # A dropped fish observation is never silently jumped across.
      candidate <- f$session_id[before]==f$session_id[after] &&
        f$camera_id[before]==f$camera_id[after] &&
        frame[b]>frame[a]
      if (!candidate) next
      scopeframe <- which(f$session_id==id$session_id[b] &
                          f$camera_id==id$camera_id[b])
      chronological <- scopeframe[order(f$frame_id[scopeframe])]
      adjacent <- match(after,chronological)-match(before,chronological)==1L
      dt <- if (is.finite(expected_time[a]) && is.finite(expected_time[b]))
        expected_time[b]-expected_time[a] else NA_real_
      dist <- sqrt((x[b]-x[a])^2+(y[b]-y[a])^2)
      if (!adjacent || (is.finite(dt) && dt>max_gap_s)) {
        large_gap[b] <- TRUE
        next
      }
      step_delta[b] <- dist
      step_dt[b] <- dt
      jump[b] <- !is.null(max_jump_px) && dist>max_jump_px
      excessive_speed[b] <- !is.null(max_speed) && is.finite(dt) &&
        dt>0 && dist/dt>max_speed
    }
  }
  structural <- !valid_id | !valid_frame | dup | conflict_obs |
    nonfinite_position | out_of_bounds | time_conflict | time_invented |
    invalid_conf
  missing <- !has_xy | is.na(observed) | !observed
  flags <- data.frame(
    raw_row=seq_len(n),
    session_id=id$session_id,camera_id=id$camera_id,track_id=id$track_id,
    frame_id=frame,time_s=expected_time,
    flag_missing_position=missing,
    flag_duplicate_identity=dup,
    flag_invalid_scope=!valid_id,
    flag_unmapped_frame=!valid_frame,
    flag_invalid_observed=conflict_obs,
    flag_nonfinite_position=nonfinite_position,
    flag_out_of_bounds=out_of_bounds,
    flag_timestamp_conflict=time_conflict | time_invented,
    flag_invalid_confidence=invalid_conf,
    flag_low_confidence=low_conf,
    flag_gap_boundary=large_gap,
    flag_jump=jump,
    flag_excessive_speed=excessive_speed,
    structural_exclusion=structural,
    source_missing_time=time_missing_declared,
    automatically_eligible=valid_for_motion & !structural & !missing &
      !low_conf & !jump & !excessive_speed,
    step_distance=step_delta,step_dt_s=step_dt,
    stringsAsFactors=FALSE)
  flag_names <- grep("^flag_",names(flags),value=TRUE)
  flags$reasons <- vapply(seq_len(n),function(i) {
    z <- flag_names[vapply(flag_names,function(k) isTRUE(flags[[k]][i]),logical(1))]
    if(length(z)) paste(sub("^flag_","",z),collapse=";") else "none"
  },character(1))
  camera_rows <- list()
  fscope <- .aqt_qc_scope(f$session_id,f$camera_id)
  for (part in split(seq_len(nrow(f)),fscope)) {
    fpart <- f[part,,drop=FALSE]
    key <- .aqt_qc_scope(fpart$session_id,fpart$camera_id,fpart$frame_id)
    source_here <- keys %in% key & valid_id & valid_frame
    present <- keys[source_here & has_xy & !structural]
    eligible <- keys[source_here & flags$automatically_eligible]
    camera_rows[[length(camera_rows)+1L]] <- data.frame(
      session_id=fpart$session_id[1L],camera_id=fpart$camera_id[1L],
      n_acquisition_frames=nrow(fpart),n_frames_with_valid_positions=
        sum(key %in% present),n_frames_with_eligible_positions=
        sum(key %in% eligible),
      frame_detection_coverage=sum(key %in% present)/nrow(fpart),
      frame_eligible_coverage=sum(key %in% eligible)/nrow(fpart),
      n_raw_rows=sum(source_here),n_eligible_rows=
        sum(source_here & flags$automatically_eligible),
      n_excluded_rows=sum(source_here & !flags$automatically_eligible),
      expected_fish_count_known=FALSE,
      source_clock_available=all(is.finite(fpart$time_s)))
  }
  coverage <- do.call(rbind,camera_rows); rownames(coverage) <- NULL
  track_rows <- list()
  for (part in split(which(valid_id & valid_frame),trackkey[valid_id & valid_frame])) {
    start <- min(frame[part]); end <- max(frame[part])
    ix <- f$session_id==id$session_id[part[1L]] &
      f$camera_id==id$camera_id[part[1L]] &
      f$frame_id>=start & f$frame_id<=end
    denom <- sum(ix)
    eligible_track_frames <- length(unique(
      frame[part[flags$automatically_eligible[part]]]))
    track_rows[[length(track_rows)+1L]] <- data.frame(
      session_id=id$session_id[part[1L]],camera_id=id$camera_id[part[1L]],
      track_id=id$track_id[part[1L]],first_frame=start,last_frame=end,
      n_frames_in_observed_span=denom,
      n_frames_with_raw_track=length(unique(frame[part])),
      n_frames_with_eligible_track=eligible_track_frames,
      n_not_eligible_within_span=denom-eligible_track_frames,
      fraction_eligible_within_span=if(denom)
        eligible_track_frames/denom else NA_real_)
  }
  per_track <- if(length(track_rows)) do.call(rbind,track_rows) else
    data.frame(session_id=character(),camera_id=character(),track_id=character(),
               first_frame=numeric(),last_frame=numeric(),
               n_frames_in_observed_span=integer(),
               n_frames_with_raw_track=integer(),
               n_frames_with_eligible_track=integer(),
               n_not_eligible_within_span=integer(),
               fraction_eligible_within_span=numeric())
  rownames(per_track) <- NULL
  expected_coverage <- NULL
  if (!is.null(expected_tracks)) {
    req <- c("session_id","camera_id","track_id")
    if (!is.data.frame(expected_tracks) || !all(req %in% names(expected_tracks)))
      stop("expected_tracks must provide session_id,camera_id,track_id",call.=FALSE)
    er <- expected_tracks[,req,drop=FALSE]
    for (nm in req) er[[nm]] <- as.character(er[[nm]])
    if (anyNA(er) || any(!nzchar(as.matrix(er))) ||
        anyDuplicated(.aqt_qc_scope(er$session_id,er$camera_id,track=er$track_id)))
      stop("Invalid or duplicate expected fish roster",call.=FALSE)
    expected_coverage <- er
    expected_coverage$n_acquisition_frames <- integer(nrow(er))
    expected_coverage$n_frames_eligible <- integer(nrow(er))
    for (i in seq_len(nrow(er))) {
      k <- f$session_id==er$session_id[i] & f$camera_id==er$camera_id[i]
      if (!any(k)) stop("Expected fish roster references nonexistent camera",call.=FALSE)
      in_track <- id$session_id==er$session_id[i] &
        id$camera_id==er$camera_id[i] & id$track_id==er$track_id[i]
      expected_coverage$n_acquisition_frames[i] <- sum(k)
      expected_coverage$n_frames_eligible[i] <- length(unique(
        frame[in_track & flags$automatically_eligible]))
    }
    expected_coverage$eligible_fraction <-
      expected_coverage$n_frames_eligible/expected_coverage$n_acquisition_frames
    by_scope <- .aqt_qc_scope(expected_coverage$session_id,expected_coverage$camera_id)
    for (i in seq_len(nrow(coverage))) {
      coverage$expected_fish_count_known[i] <-
        any(by_scope==.aqt_qc_scope(coverage$session_id[i],coverage$camera_id[i]))
    }
  }
  manual <- NULL
  if (!is.null(truth) || !is.null(evaluated_frames) ||
      !is.null(max_reference_distance)) {
    if (is.null(truth) || is.null(evaluated_frames) ||
        is.null(max_reference_distance))
      stop("Manual accuracy check requires truth, evaluated_frames and max_reference_distance",call.=FALSE)
    .aqt_qc_limit(max_reference_distance,"max_reference_distance")
    ef <- aqt_evaluation_frames(evaluated_frames)
    if (!all(.aqt_qc_scope(ef$session_id,ef$camera_id,ef$frame_id) %in% framekeys))
      stop("Manual evaluation frames must occur in source frame manifest",call.=FALSE)
    if (!is.numeric(truth$frame_id) ||
        !all(.aqt_qc_scope(truth$session_id,truth$camera_id,truth$frame_id) %in%
             .aqt_qc_scope(ef$session_id,ef$camera_id,ef$frame_id)))
      stop("Truth observations outside annotated frame set",call.=FALSE)
    selected <- which(flags$automatically_eligible)
    pd <- data.frame(session_id=id$session_id[selected],
      camera_id=id$camera_id[selected],frame_id=frame[selected],
      track_id=id$track_id[selected],x=x[selected],y=y[selected],
      stringsAsFactors=FALSE)
    manual <- aqt_tracking_metrics(truth,pd,max_distance=max_reference_distance,
                                   evaluated_frames=ef)
  }
  structure(list(raw=raw,frames=f,row_audit=flags,camera_coverage=coverage,
       per_track_coverage=per_track,expected_coverage=expected_coverage,
       manual_accuracy=manual,automatic_eligible=flags$automatically_eligible,
       raw_sha256=raw_sha,provenance=provenance,time_provenance=time_provenance,
       thresholds=list(max_gap_s=max_gap_s,max_speed=max_speed,
        max_jump_px=max_jump_px,min_detection_confidence=min_detection_confidence),
       manual_annotation_provenance_independently_verified=FALSE,
       biological_identity_certified=FALSE,
       complete_detection_recall_certified=FALSE),
       class="aqt_trajectory_qc")
}

#' Apply documented review decisions without changing the original trajectories
#'
#' Decisions have raw_row,decision ("exclude" or "accept"),reason. An explicit
#' acceptance can overturn only a quality-warning (low score, jump, speed);
#' structural invalidities, missing coordinates or ambiguous duplicate IDs
#' can never be silently accepted. Rows rejected by quality rules are retained
#' in the screened track object with observed=FALSE to prevent gap bridging.
#'
#' @param qc Output of aqt_trajectory_qc.
#' @param decisions Optional manual review table; row ids identify source rows.
#' @return aqt_qc_review with original qc, review ledger and screened tracks.
#' @export
aqt_qc_review <- function(qc,decisions=NULL) {
  if (!inherits(qc,"aqt_trajectory_qc"))
    stop("Expected aqt_trajectory_qc object",call.=FALSE)
  n <- nrow(qc$raw)
  audit <- qc$row_audit
  eligible <- audit$automatically_eligible
  manual <- rep("none",n); manual_reason <- rep("",n)
  if (!is.null(decisions)) {
    needed <- c("raw_row","decision","reason")
    if (!is.data.frame(decisions) || !all(needed %in% names(decisions)))
      stop("Review decisions require raw_row,decision,reason",call.=FALSE)
    rr <- decisions$raw_row
    if (!is.numeric(rr) || anyNA(rr) || any(rr<1 | rr>n | rr!=floor(rr)) ||
        anyDuplicated(rr))
      stop("Manual decisions require unique valid raw_row numbers",call.=FALSE)
    action <- as.character(decisions$decision)
    reason <- as.character(decisions$reason)
    if (anyNA(action) || any(!action %in% c("exclude","accept")) ||
        anyNA(reason) || any(!nzchar(trimws(reason))))
      stop("Every manual decision requires accepted action and explicit reason",
           call.=FALSE)
    for (j in seq_along(rr)) {
      i <- as.integer(rr[j])
      if (action[j]=="accept") {
        if (audit$structural_exclusion[i] || audit$flag_missing_position[i])
          stop("Manual review cannot accept missing, duplicate or structurally invalid observations",
               call.=FALSE)
        eligible[i] <- TRUE
      } else eligible[i] <- FALSE
      manual[i] <- action[j]; manual_reason[i] <- reason[j]
    }
  }
  audit$manual_decision <- manual
  audit$manual_reason <- manual_reason
  audit$review_eligible <- eligible
  audit$review_status <- ifelse(audit$structural_exclusion,"structurally_invalid",
    ifelse(!eligible,"excluded","eligible"))
  if (all(is.na(qc$frames$time_s))) {
    screened <- NULL
    analysis_blocked <- "No source clock; time-dependent trajectories cannot be constructed"
  } else if (any(vapply(split(seq_len(nrow(qc$frames)),
               .aqt_qc_scope(qc$frames$session_id,qc$frames$camera_id)),
               function(z) all(is.na(qc$frames$time_s[z])),logical(1L)))) {
    screened <- NULL
    analysis_blocked <- "Mixed clock availability; scope-specific analysis required"
  } else {
    ok <- which(!audit$structural_exclusion &
                !audit$flag_timestamp_conflict)
    data <- qc$raw[ok,,drop=FALSE]
    for (nm in c("frame_id","time_s","x","y"))
      data[[nm]] <- .aqt_qc_numeric(data[[nm]])
    data$session_id <- as.character(data$session_id)
    data$camera_id <- as.character(data$camera_id)
    data$track_id <- as.character(data$track_id)
    data$observed <- as.logical(eligible[ok])
    data$raw_row <- ok
    # For explicitly missing coordinates, aqt_tracks preserves NA and false.
    screened <- aqt_tracks(data,units="px",coordinate_system="image")
    attr(screened,"aqt_qc_raw_sha256") <- qc$raw_sha256
    attr(screened,"aqt_qc_policy") <- qc$thresholds
    analysis_blocked <- NULL
  }
  structure(list(qc=qc,row_audit=audit,tracks=screened,
      analysis_blocked=analysis_blocked,
      n_original=n,n_review_eligible=sum(eligible),
      n_review_excluded=sum(!eligible),
      n_manual_decisions=sum(manual!="none"),
      independent_human_review_certified=FALSE,
      original_source_sha256=qc$raw_sha256),
    class="aqt_qc_review")
}

#' Calculate audited movement only from reviewed, eligible observations
#'
#' Rejected rows remain traceable; accepted movement steps require adjacent,
#' observed points and the recorded maximum time gap. The output is descriptive
#' and cannot certify true fish identity or physical speed without calibration.
#'
#' @param review An aqt_qc_review from explicit aqt_qc_review().
#' @param max_gap_s Maximum interval used for valid movement steps.
#' @return aqt_qc_derived with kinematics, per-track path summary and counts.
#' @export
aqt_qc_derive <- function(review,max_gap_s=NULL) {
  if (!inherits(review,"aqt_qc_review"))
    stop("Expected an aqt_qc_review object",call.=FALSE)
  if (is.null(review$tracks))
    stop("Cannot derive time-based movement without source timestamps",call.=FALSE)
  if (is.null(max_gap_s)) max_gap_s <- review$qc$thresholds$max_gap_s
  .aqt_qc_limit(max_gap_s,"max_gap_s")
  kin <- aqt_kinematics(review$tracks,max_gap_s=max_gap_s)
  paths <- aqt_path_summary(review$tracks,max_gap_s=max_gap_s)
  # Never connect two observations across a source frame that was missing
  # from this scoped track (even if nominal dt appears small).
  if (nrow(kin)) {
    ledger <- review$row_audit
    raw_idx <- kin$raw_row
    stopifnot(all(raw_idx %in% ledger$raw_row))
    for (part in split(seq_len(nrow(kin)),
           .aqt_qc_scope(kin$session_id,kin$camera_id,track=kin$track_id))) {
      if (length(part)<2L) next
      order_part <- part[order(kin$time_s[part])]
      for (j in seq.int(2L,length(order_part))) {
        a <- order_part[j-1L]; b <- order_part[j]
        if (!is.finite(kin$dt_s[b]) || is.na(kin$step_distance[b])) next
        f <- review$qc$frames
        sid <- kin$session_id[b]; cam <- kin$camera_id[b]
        positions <- f$frame_id[f$session_id==sid & f$camera_id==cam]
        positions <- sort(positions)
        earlier <- ledger$frame_id[raw_idx[a]]
        later <- ledger$frame_id[raw_idx[b]]
        if (match(later,positions)-match(earlier,positions)!=1L) {
          kin[b,c("step_distance","vx","vy","vz","speed",
                  "heading_rad","acceleration","turn_rate_rad_s")] <- NA_real_
        }
      }
    }
    # Recalculate path summaries FROM actually retained continuous steps.
    keys <- .aqt_qc_scope(kin$session_id,kin$camera_id,track=kin$track_id)
    if (nrow(paths)) for (i in seq_len(nrow(paths))) {
      idx <- which(keys==.aqt_qc_scope(paths$session_id[i],
                        paths$camera_id[i],track=paths$track_id[i]))
      ok <- idx[is.finite(kin$step_distance[idx])]
      paths$path_length[i] <- sum(kin$step_distance[ok])
      paths$valid_steps[i] <- length(ok)
      paths$valid_duration_s[i] <- sum(kin$dt_s[ok])
      paths$mean_speed[i] <- if(length(ok) && paths$valid_duration_s[i]>0)
        paths$path_length[i]/paths$valid_duration_s[i] else NA_real_
    }
  }
  summary <- data.frame(n_source_rows=review$n_original,
    n_structurally_invalid=sum(review$row_audit$structural_exclusion),
    n_review_eligible=review$n_review_eligible,
    n_review_excluded=review$n_review_excluded,
    n_missing_positions=sum(review$row_audit$flag_missing_position),
    n_duplicate_identity_rows=sum(review$row_audit$flag_duplicate_identity),
    n_gap_boundaries=sum(review$row_audit$flag_gap_boundary),
    n_jump_warnings=sum(review$row_audit$flag_jump),
    n_speed_warnings=sum(review$row_audit$flag_excessive_speed),
    n_usable_movements=sum(is.finite(kin$step_distance)),
    n_original_source_frames=nrow(review$qc$frames),
    original_source_sha256=review$original_source_sha256,
    stringsAsFactors=FALSE)
  structure(list(kinematics=kin,path_summary=paths,summary=summary,
    review=review,provenance=review$qc$provenance,
    physical_calibration_certified=FALSE,
    fish_identity_accuracy_certified=FALSE),class="aqt_qc_derived")
}

#' Export a complete, immutable, provenance-linked trajectory QC audit
#'
#' Writes raw observations, frame manifest, row-level flags, reviewed tracks,
#' available annotation accuracy, derived measurements, and a manifest of
#' SHA-256 output hashes. Refuses existing output paths. No source video or
#' tracker weights are copied to the report.
#'
#' @param review An aqt_qc_review.
#' @param derived Optional aqt_qc_derived built from this review.
#' @param directory New output directory (parent must exist).
#' @return Export directory invisibly.
#' @export
aqt_qc_report <- function(review,derived=NULL,directory) {
  if (!inherits(review,"aqt_qc_review"))
    stop("Expected aqt_qc_review object",call.=FALSE)
  if (!is.null(derived) &&
      (!inherits(derived,"aqt_qc_derived") ||
       !identical(derived$review$original_source_sha256,
                  review$original_source_sha256)))
    stop("Derived measurements must originate from this review",call.=FALSE)
  if (!is.character(directory) || length(directory)!=1L ||
      is.na(directory) || file.exists(directory) || dir.exists(directory) ||
      !dir.exists(dirname(directory)))
    stop("Report destination must be new with an existing parent",call.=FALSE)
  folder <- tempfile(".aqt-qc-report-",tmpdir=dirname(directory))
  dir.create(folder)
  on.exit(if(dir.exists(folder)) unlink(folder,recursive=TRUE,force=TRUE),add=TRUE)
  files <- list(
    "RAW_OBSERVATIONS.csv"=review$qc$raw,
    "SOURCE_FRAME_MANIFEST.csv"=review$qc$frames,
    "ROW_QUALITY_AUDIT.csv"=review$row_audit,
    "CAMERA_COVERAGE.csv"=review$qc$camera_coverage,
    "TRACK_COVERAGE.csv"=review$qc$per_track_coverage)
  if(!is.null(review$qc$expected_coverage))
    files[["EXPECTED_TRACK_COVERAGE.csv"]] <- review$qc$expected_coverage
  if(!is.null(review$qc$manual_accuracy))
    files[["ANNOTATED_ACCURACY.csv"]] <- review$qc$manual_accuracy
  if(!is.null(review$tracks))
    files[["REVIEWED_TRACKS.csv"]] <- as.data.frame(review$tracks)
  if(!is.null(derived)){
    files[["DERIVED_KINEMATICS.csv"]] <- derived$kinematics
    files[["DERIVED_PATH_SUMMARY.csv"]] <- derived$path_summary
    files[["DERIVED_COUNTS.csv"]] <- derived$summary
  }
  for(name in names(files))
    utils::write.csv(files[[name]],file.path(folder,name),
                     row.names=FALSE,na="")
  hashes <- vapply(names(files),function(name)
    digest::digest(file.path(folder,name),algo="sha256",file=TRUE),
    character(1))
  meta <- list(schema_version="1.0.0",type="aqt_trajectory_qc_report",
      original_source_sha256=review$original_source_sha256,
      n_raw_rows=review$n_original,
      n_eligible=review$n_review_eligible,
      n_excluded=review$n_review_excluded,
      n_manual_decisions=review$n_manual_decisions,
      clock_status=review$qc$time_provenance,
      independent_human_review_certified=FALSE,
      biological_identity_accuracy_certified=FALSE,
      coordinate_units="px",
      thresholds=review$qc$thresholds,
      source_provenance=review$qc$provenance,
      output_sha256=as.list(hashes))
  jsonlite::write_json(meta,file.path(folder,"QC_REPORT_MANIFEST.json"),
                       auto_unbox=TRUE,pretty=TRUE,null="null")
  if (!file.rename(folder,directory))
    stop("Could not publish complete QC report directory",call.=FALSE)
  invisible(directory)
}
