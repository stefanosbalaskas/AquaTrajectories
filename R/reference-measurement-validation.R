# M08: evaluation of external model output against published annotations.
# This is an image-coordinate measurement audit, not biological validation.

.aqt_m08_key <- function(d, track=FALSE) {
  x <- cbind(as.character(d$session_id),as.character(d$camera_id),
             as.character(d$frame_id))
  if(track)x <- cbind(x,as.character(d$track_id))
  apply(x,1L,paste,collapse="\r")
}
.aqt_m08_dist <- function(x,y) sqrt(x*x+y*y)
.aqt_m08_iou <- function(a,b) {
  w <- pmax(0,pmin(a$bbox_left+a$bbox_width,
                   b$bbox_left+b$bbox_width)-pmax(a$bbox_left,b$bbox_left))
  h <- pmax(0,pmin(a$bbox_top+a$bbox_height,
                   b$bbox_top+b$bbox_height)-pmax(a$bbox_top,b$bbox_top))
  overlap <- w*h
  union <- a$bbox_width*a$bbox_height+b$bbox_width*b$bbox_height-overlap
  ifelse(union>0,overlap/union,0)
}
.aqt_m08_mean <- function(x) if(length(x) && any(is.finite(x)))
  base::mean(x[is.finite(x)]) else NA_real_
.aqt_m08_rg <- function(coords) {
  if(nrow(coords)<2L)return(NA_real_)
  centre <- colMeans(coords)
  sqrt(mean(rowSums((sweep(coords,2L,centre))^2)))
}
.aqt_m08_nn <- function(coords) {
  if(nrow(coords)<2L)return(NA_real_)
  z <- as.matrix(stats::dist(coords))
  diag(z) <- Inf
  mean(apply(z,1L,min))
}

#' Validate fish trajectory measurements against declared reference annotations
#'
#' Compare image-pixel coordinates, adjacent-frame displacement and matched
#' group geometry after external evaluation-only one-to-one IoU matching.
#' The source observations remain unchanged and original fish references
#' are NOT claimed as independently re-adjudicated biological identity truth.
#'
#' @param frames Original M07 acquisition-frame table with unknown time_s.
#' @param observations Original M07 separate reference and model observation rows.
#' @param matched Evaluator one-to-one bbox associations with 1-based
#' reference_source_row/model_source_row source-line indices.
#' @param iou_threshold Declared matching threshold in (0,1], default .5.
#' @return A list containing source-preserving matching, complete reference
#' adjacent-step ledger, matched-subset spatial geometry, a per-sequence
#' measurement summary and explicit blocked physical/biological claims.
#' @export
aqt_reference_measurement_validate <- function(frames,observations,
                                               matched,iou_threshold=.5) {
  if(!is.data.frame(frames)||!is.data.frame(observations)||
     !is.data.frame(matched)||!nrow(frames)||!nrow(observations))
    stop("Expected nonempty source frame and observation tables",call.=FALSE)
  if(!is.numeric(iou_threshold)||length(iou_threshold)!=1L||
     !is.finite(iou_threshold)||iou_threshold<=0||iou_threshold>1)
    stop("IoU threshold must lie in (0,1]",call.=FALSE)
  f <- frames
  o <- observations
  m <- matched
  obs_names <- c("data_path","session_id","camera_id","frame_id",
    "track_id","x","y","bbox_left","bbox_top","bbox_width","bbox_height")
  frame_names <- c("data_path","session_id","camera_id","frame_id",
                   "width_px","height_px","time_s")
  match_names <- c("session_id","camera_id","frame_id",
    "reference_track_id","model_track_id","reference_source_row",
    "model_source_row","reference_x_px","reference_y_px",
    "model_x_px","model_y_px","iou","position_error_px")
  if(!all(obs_names %in% names(o))||!all(frame_names %in% names(f))||
     !all(match_names %in% names(m)))
    stop("Incomplete original observation or match schema",call.=FALSE)
  if(!setequal(as.character(unique(o$data_path)),c("reference","model"))||
     any(!is.na(f$time_s) & nzchar(trimws(as.character(f$time_s)))))
    stop("Source separation and unknown time must be preserved",call.=FALSE)
  if(any(!is.finite(o$x))||any(!is.finite(o$y))||
     any(!is.finite(o$bbox_left))||any(!is.finite(o$bbox_top))||
     any(!is.finite(o$bbox_width))||any(!is.finite(o$bbox_height))||
     any(o$bbox_width<=0)||any(o$bbox_height<=0))
    stop("Invalid source observation geometry",call.=FALSE)
  index <- paste(o$data_path,.aqt_m08_key(o),sep="\r")
  frame_index <- paste(f$data_path,.aqt_m08_key(f),sep="\r")
  if(anyDuplicated(frame_index)||anyNA(match(index,frame_index))||
     anyDuplicated(paste(index,o$track_id,sep="\r")))
    stop("Missing or duplicate original acquisition/track scope",call.=FALSE)
  if(nrow(m)) {
    rr <- as.integer(m$reference_source_row)
    pp <- as.integer(m$model_source_row)
    if(anyNA(rr)||anyNA(pp)||any(rr<1L)||any(pp<1L)||
       any(rr>nrow(o))||any(pp>nrow(o))||anyDuplicated(rr)||
       anyDuplicated(pp))
      stop("Invalid or duplicated source observation matching",call.=FALSE)
    a <- o[rr,,drop=FALSE]
    b <- o[pp,,drop=FALSE]
    if(any(a$data_path!="reference")||any(b$data_path!="model")||
       any(.aqt_m08_key(a)!=.aqt_m08_key(b))||
       any(.aqt_m08_key(a)!=do.call(paste,
         c(m[c("session_id","camera_id","frame_id")],sep="\r")))||
       any(as.character(a$track_id)!=as.character(m$reference_track_id))||
       any(as.character(b$track_id)!=as.character(m$model_track_id)))
      stop("Evaluation associations violate reference/model camera scope",call.=FALSE)
    iou <- .aqt_m08_iou(a,b)
    pos <- .aqt_m08_dist(a$x-b$x,a$y-b$y)
    if(any(!is.finite(iou))||any(iou+1e-9<iou_threshold)||
       any(abs(iou-as.numeric(m$iou))>1e-8)||
       any(abs(pos-as.numeric(m$position_error_px))>1e-7)||
       any(abs(as.numeric(m$reference_x_px)-a$x)>1e-6)||
       any(abs(as.numeric(m$reference_y_px)-a$y)>1e-6)||
       any(abs(as.numeric(m$model_x_px)-b$x)>1e-6)||
       any(abs(as.numeric(m$model_y_px)-b$y)>1e-6))
      stop("Reported IoU, reference center or model position error differs from source boxes",call.=FALSE)
  } else {rr <- pp <- integer();iou <- pos <- numeric()}
  ref_idx <- which(o$data_path=="reference")
  model_idx <- which(o$data_path=="model")
  ref <- o[ref_idx,,drop=FALSE]
  # Preserve complete published-reference adjacent-frame denominator.
  group_key <- paste(ref$session_id,ref$camera_id,ref$track_id,sep="\r")
  steps <- list();k <- 0L
  matched_ref <- match(seq_len(nrow(o)),rr)
  for(ii in split(seq_along(ref_idx),group_key)) {
    rows <- ref_idx[ii][order(as.numeric(o$frame_id[ref_idx[ii]]))]
    if(length(rows)<2L)next
    for(j in seq.int(2L,length(rows))) {
      a <- rows[j-1L];b <- rows[j]
      if(o$frame_id[b]!=o$frame_id[a]+1L)next
      dx <- o$x[b]-o$x[a];dy <- o$y[b]-o$y[a]
      distance <- .aqt_m08_dist(dx,dy)
      m0 <- matched_ref[a];m1 <- matched_ref[b]
      status <- if(is.na(m0)||is.na(m1))"unmatched_endpoint" else
        if(as.character(m$model_track_id[m0]) !=
           as.character(m$model_track_id[m1]))"model_id_discontinuity" else
        "matched_same_id"
      md <- bias <- err <- vec <- NA_real_
      if(status=="matched_same_id") {
        ma <- pp[m0];mb <- pp[m1]
        mdx <- o$x[mb]-o$x[ma];mdy <- o$y[mb]-o$y[ma]
        md <- .aqt_m08_dist(mdx,mdy)
        bias <- md-distance
        err <- abs(bias)
        vec <- .aqt_m08_dist(mdx-dx,mdy-dy)
      }
      k <- k+1L
      steps[[k]] <- data.frame(session_id=o$session_id[a],
        camera_id=o$camera_id[a],reference_track_id=as.character(o$track_id[a]),
        frame_start=o$frame_id[a],frame_end=o$frame_id[b],status=status,
        reference_step_px=distance,model_step_px=md,signed_step_bias_px=bias,
        absolute_step_error_px=err,vector_error_px=vec,
        stringsAsFactors=FALSE)
    }
  }
  empty_step <- data.frame(session_id=character(),camera_id=character(),
    reference_track_id=character(),frame_start=numeric(),frame_end=numeric(),
    status=character(),reference_step_px=numeric(),model_step_px=numeric(),
    signed_step_bias_px=numeric(),absolute_step_error_px=numeric(),
    vector_error_px=numeric(),stringsAsFactors=FALSE)
  st <- if(k)do.call(rbind,steps) else empty_step
  rownames(st) <- NULL
  # Group geometry: reference *matched subset* versus corresponding model
  # subset, and separately the full publisher-reference versus selected fish.
  geometry <- list()
  fref <- f[f$data_path=="reference",,drop=FALSE]
  for(j in seq_len(nrow(fref))) {
    x <- fref[j,,drop=FALSE]
    candidate <- which(o$data_path=="reference" &
      as.character(o$session_id)==as.character(x$session_id) &
      as.character(o$camera_id)==as.character(x$camera_id) &
      o$frame_id==x$frame_id)
    matches <- which(as.character(m$session_id)==as.character(x$session_id) &
      as.character(m$camera_id)==as.character(x$camera_id) &
      as.numeric(m$frame_id)==as.numeric(x$frame_id))
    whole <- as.matrix(o[candidate,c("x","y"),drop=FALSE])
    matching_ref <- as.matrix(o[rr[matches],c("x","y"),drop=FALSE])
    matching_model <- as.matrix(o[pp[matches],c("x","y"),drop=FALSE])
    full_rg <- .aqt_m08_rg(whole)
    rg_ref <- .aqt_m08_rg(matching_ref)
    rg_mod <- .aqt_m08_rg(matching_model)
    nn_ref <- .aqt_m08_nn(matching_ref)
    nn_mod <- .aqt_m08_nn(matching_model)
    geometry[[j]] <- data.frame(session_id=as.character(x$session_id),
      camera_id=as.character(x$camera_id),frame_id=x$frame_id,
      n_reference=length(candidate),n_matched=length(matches),
      full_reference_rg_px=full_rg,matched_reference_rg_px=rg_ref,
      matched_model_rg_px=rg_mod,
      matched_rg_bias_px=rg_mod-rg_ref,
      subset_selection_rg_bias_px=rg_ref-full_rg,
      matched_reference_nn_px=nn_ref,matched_model_nn_px=nn_mod,
      matched_nn_bias_px=nn_mod-nn_ref)
  }
  gr <- do.call(rbind,geometry)
  rownames(gr) <- NULL
  sequences <- sort(unique(as.character(f$session_id)))
  summary <- lapply(sequences,function(seq) {
    n_ref <- sum(o$data_path=="reference" & o$session_id==seq)
    n_mod <- sum(o$data_path=="model" & o$session_id==seq)
    match_ids <- which(as.character(m$session_id)==seq)
    st_ids <- which(st$session_id==seq)
    eligible <- st_ids[st$status[st_ids]=="matched_same_id"]
    data.frame(sequence=seq,n_reference=n_ref,n_model=n_mod,
      n_matched=length(match_ids),
      matched_reference_fraction=length(match_ids)/n_ref,
      n_reference_adjacent_steps=length(st_ids),
      n_paired_same_id_steps=length(eligible),
      paired_step_fraction=if(length(st_ids))length(eligible)/length(st_ids) else NA_real_,
      n_two_endpoints_different_model_id=
        sum(st$status[st_ids]=="model_id_discontinuity"),
      n_reference_steps_missing_match_endpoint=
        sum(st$status[st_ids]=="unmatched_endpoint"),
      median_position_error_px=if(length(match_ids))
        stats::median(pos[match_ids]) else NA_real_,
      paired_step_MAE_px=.aqt_m08_mean(st$absolute_step_error_px[eligible]),
      frames_with_two_or_more_matched=sum(gr$session_id==seq & gr$n_matched>=2),
      matched_group_rg_MAE_px=.aqt_m08_mean(abs(gr$matched_rg_bias_px[gr$session_id==seq])),
      group_subset_selection_rg_MAE_px=.aqt_m08_mean(abs(gr$subset_selection_rg_bias_px[gr$session_id==seq])),
      stringsAsFactors=FALSE)
  })
  summary <- do.call(rbind,summary)
  rownames(summary) <- NULL
  out <- list(schema="AQT_M08_R_REFERENCE_MEASUREMENT_V1",
    source_frame_rows=nrow(f),source_observation_rows=nrow(o),
    source_rows_preserved=TRUE,source_data=observations,
    input_matched=matched,recomputed_position_error_px=pos,
    recomputed_iou=iou,adjacent_reference_steps=st,
    group_geometry=gr,summary=summary,
    primary_iou=iou_threshold,
    independent_biological_id_certified=FALSE,
    measured_time_certified=FALSE,physical_3D_certified=FALSE,
    causal_event_or_welfare_inference_certified=FALSE)
  class(out) <- "aqt_m08_reference_measurement"
  out
}

#' Export numerical source-linked fish measurement validation
#'
#' This writes the already-computed source-preserving M08 measurement audit.
#' Reports are descriptive and explicitly withhold unmeasured physical/biological
#' conclusions; original frames and fish observations are not modified.
#' @param study Output of aqt_reference_measurement_validate.
#' @param directory New output directory; parent must exist.
#' @return New destination directory invisibly.
#' @export
aqt_reference_measurement_publish <- function(study,directory) {
  if(!inherits(study,"aqt_m08_reference_measurement")||
     !isTRUE(study$source_rows_preserved)||
     !is.data.frame(study$summary)||!nrow(study$summary))
    stop("Expected intact validated M08 study",call.=FALSE)
  if(!is.character(directory)||length(directory)!=1L||is.na(directory)||
     file.exists(directory)||!dir.exists(dirname(directory)))
    stop("Require new output location with existing parent",call.=FALSE)
  dir.create(directory)
  tables <- list("SEQUENCE_MEASUREMENT_SUMMARY.csv"=study$summary,
    "REFERENCE_ADJACENT_STEP_LEDGER.csv"=study$adjacent_reference_steps,
    "MATCHED_GROUP_GEOMETRY.csv"=study$group_geometry)
  for(n in names(tables)) utils::write.csv(tables[[n]],file.path(directory,n),
                                             row.names=FALSE,na="")
  # Preserve entire exact study and source references in one R object only.
  saveRDS(study,file.path(directory,"M08_SCIENTIFIC_ANALYSIS.rds"))
  report <- c("# M08 -- Conditional real fish measurement validation","",
    "Published-source reference boxes; not independent biological identification.",
    "Image coordinates only. No measured timestamps, physical 3D, feeding events, welfare or treatment effects.",
    paste0("Reference-model match threshold: IoU >= ",study$primary_iou),
    paste0("Original observations preserved: ",study$source_observation_rows),
    paste0("Matched observations: ",nrow(study$input_matched)),
    paste0("Eligible adjacent source-reference steps: ",
           nrow(study$adjacent_reference_steps)),
    paste0("Of those, same-model-ID matched steps: ",
           sum(study$adjacent_reference_steps$status=="matched_same_id")),
    "","## Scientific restrictions","",
    "Matched-pair error is selection-conditional, not overall fish tracking accuracy.",
    "Model detection/tracking failures remain visible in full denominators.",
    "Source fish identities are original publisher labels, not prediction-blind human review.")
  writeLines(report,file.path(directory,"REPORT.md"),useBytes=TRUE)
  files <- setdiff(list.files(directory,recursive=TRUE),"M08_R_OUTPUT_MANIFEST.json")
  out_hash <- stats::setNames(vapply(files,function(n)
    unname(digest::digest(file.path(directory,n),algo="sha256",file=TRUE)),
    character(1L)),files)
  jsonlite::write_json(list(schema="AQT_M08_R_REPORT_SHA256_V1",
      source_observation_rows=study$source_observation_rows,
      original_source_rows_preserved=TRUE,output_sha256=as.list(out_hash)),
      file.path(directory,"M08_R_OUTPUT_MANIFEST.json"),
      pretty=TRUE,auto_unbox=TRUE)
  invisible(directory)
}
