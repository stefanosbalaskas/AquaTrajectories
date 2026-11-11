# AquaTrajectories: point-track validation against independent identities
# All match identifiers are scoped by (session,camera). No cross-camera
# re-identification, HOTA, or full CLEAR MOT conventions are claimed here.

#' Validate manually labelled or predicted point tracks for benchmarking
#'
#' Ground truth must be independently annotated and use stable identities
#' within each video. Frame IDs must be nonnegative integers on a common
#' reference clock; partial human annotations must be evaluated only on
#' their annotated frames.
#'
#' @param data Data frame with session_id, camera_id, frame_id, track_id,
#'   x and y; optionally class_id. Coordinates must use the same scale.
#' @return Canonical per-frame tracking observations.
#' @export
aqt_tracking_observations <- function(data) {
  f <- c("session_id","camera_id","frame_id","track_id","x","y")
  .aqt_required(data,f,"data")
  d <- as.data.frame(data,stringsAsFactors=FALSE)
  for (nm in c("session_id","camera_id","track_id")) {
    if (anyNA(d[[nm]]) || any(!nzchar(as.character(d[[nm]]))))
      stop("Invalid tracking identity scope",call.=FALSE)
    d[[nm]] <- as.character(d[[nm]])
  }
  if (!is.numeric(d$frame_id) || any(!is.finite(d$frame_id)) ||
      any(d$frame_id<0 | d$frame_id!=floor(d$frame_id)))
    stop("frame_id must be finite nonnegative integer-valued numeric",call.=FALSE)
  if (!is.numeric(d$x) || !is.numeric(d$y) ||
      any(!is.finite(d$x)) || any(!is.finite(d$y)))
    stop("Tracking coordinates must be finite numeric",call.=FALSE)
  if (!"class_id" %in% names(d)) d$class_id <- "fish"
  if (anyNA(d$class_id) || any(!nzchar(as.character(d$class_id))))
    stop("class_id must be nonempty",call.=FALSE)
  d$class_id <- as.character(d$class_id)
  d$frame_id <- as.numeric(d$frame_id)
  key <- paste(d$session_id,d$camera_id,d$frame_id,d$track_id,sep="\r")
  if (anyDuplicated(key))
    stop("Duplicate track ID within the same camera/session/frame",call.=FALSE)
  d
}

#' Maximum-weight identity assignment (internal Hungarian algorithm)
#' @keywords internal
.aqt_max_assignment <- function(weight) {
  nr <- nrow(weight); nc <- ncol(weight)
  if (!nr || !nc) return(rep(NA_integer_,nr))
  if (!is.numeric(weight) || any(!is.finite(weight)) || any(weight<0))
    stop("Expected nonnegative finite assignment weights",call.=FALSE)
  size <- max(nr,nc)
  W <- matrix(0,size,size)
  W[seq_len(nr),seq_len(nc)] <- weight
  C <- max(W)-W
  u <- numeric(size+1L); v <- numeric(size+1L)
  p <- integer(size+1L); way <- integer(size+1L)
  for (i in seq_len(size)) {
    p[1L] <- i
    j0 <- 1L
    used <- rep(FALSE,size+1L)
    minv <- rep(Inf,size+1L)
    repeat {
      used[j0] <- TRUE
      i0 <- p[j0]
      delta <- Inf
      j1 <- NA_integer_
      for (j in seq.int(2L,size+1L)) if (!used[j]) {
        cur <- C[i0,j-1L]-u[i0+1L]-v[j]
        if (cur<minv[j]) {
          minv[j] <- cur
          way[j] <- j0
        }
        if (minv[j]<delta) {
          delta <- minv[j]
          j1 <- j
        }
      }
      if (!is.finite(delta)) stop("Assignment failed",call.=FALSE)
      for (j in seq_len(size+1L)) {
        if (used[j]) {
          u[p[j]+1L] <- u[p[j]+1L]+delta
          v[j] <- v[j]-delta
        } else {
          minv[j] <- minv[j]-delta
        }
      }
      j0 <- j1
      if (p[j0]==0L) break
    }
    repeat {
      j1 <- way[j0]
      p[j0] <- p[j1]
      j0 <- j1
      if (j0==1L) break
    }
  }
  assignment <- rep(NA_integer_,nr)
  for (j in seq.int(2L,size+1L)) {
    row <- p[j]
    if (row>=1L && row<=nr && j-1L<=nc)
      assignment[row] <- j-1L
  }
  assignment
}

#' Match separately observed fish positions to reference tracks
#'
#' Per-frame maximum-cardinality matching uses Euclidean distance in
#' coordinate units. It is class-aware by default and returns only actual
#' one-to-one matched pairs. This is not a cross-view matching method.
#'
#' @param truth,pred Independent truth and predicted point-track tables.
#' @param max_distance Positive maximum positional error for association.
#' @param class_aware Restrict matches to identical species labels.
#' @param evaluated_frames Optional manifest of all manually annotated frames.
#' @return One row per matched pair, with original row IDs and distance.
#' @export
aqt_tracking_match <- function(truth,pred,max_distance,class_aware=TRUE,
                               evaluated_frames=NULL) {
  if (!is.numeric(max_distance) || length(max_distance)!=1L ||
      !is.finite(max_distance) || max_distance<=0)
    stop("max_distance must be positive and finite",call.=FALSE)
  if (!is.logical(class_aware) || length(class_aware)!=1L || is.na(class_aware))
    stop("class_aware must be a logical scalar",call.=FALSE)
  gt <- .aqt_filter_evaluation_frames(aqt_tracking_observations(truth),
                                       evaluated_frames,reference=TRUE)
  pd <- .aqt_filter_evaluation_frames(aqt_tracking_observations(pred),
                                       evaluated_frames)
  empty <- data.frame(session_id=character(),camera_id=character(),
    frame_id=double(),truth_row=integer(),pred_row=integer(),
    truth_id=character(),pred_id=character(),truth_class=character(),
    pred_class=character(),distance=double())
  if (!nrow(gt) || !nrow(pd)) return(empty)
  key_gt <- paste(gt$session_id,gt$camera_id,gt$frame_id,sep="\r")
  key_pd <- paste(pd$session_id,pd$camera_id,pd$frame_id,sep="\r")
  results <- list(); q <- 0L
  for (key in intersect(unique(key_gt),unique(key_pd))) {
    gi <- which(key_gt==key); pj <- which(key_pd==key)
    a <- gt[gi,,drop=FALSE]; b <- pd[pj,,drop=FALSE]
    dx <- outer(a$x,b$x,"-"); dy <- outer(a$y,b$y,"-")
    distance <- sqrt(dx^2+dy^2)
    quality <- max_distance-distance
    if (class_aware) quality[outer(a$class_id,b$class_id,"!=")] <- -Inf
    map <- .aqt_cardinality_match(quality,0)
    pairs <- which(!is.na(map))
    if (!length(pairs)) next
    q <- q+1L
    results[[q]] <- data.frame(session_id=a$session_id[pairs],
      camera_id=a$camera_id[pairs],frame_id=a$frame_id[pairs],
      truth_row=gi[pairs],pred_row=pj[map[pairs]],
      truth_id=a$track_id[pairs],pred_id=b$track_id[map[pairs]],
      truth_class=a$class_id[pairs],pred_class=b$class_id[map[pairs]],
      distance=distance[cbind(pairs,map[pairs])])
  }
  if (!length(results)) return(empty)
  do.call(rbind,unname(results))
}

#' Tracking identity F1 and within-camera association diagnostics
#'
#' IDF1 is computed from globally optimal one-to-one identity assignment
#' over framewise position matches (per session/camera). Adjacent ID switches
#' count only directly consecutive annotated frames with successful matches;
#' they are NOT a substitute for official CLEAR MOT or HOTA. For HOTA and
#' published benchmark parity use an external, independently validated
#' TrackEval run with compatible annotations.
#'
#' @param truth,pred Independent per-frame point-track tables.
#' @param max_distance Maximum spatial association error in coordinate units.
#' @param class_aware Match within class/species.
#' @param evaluated_frames Optional manifest of all manually annotated frames.
#' @return One row per session/camera with precision, recall, IDF1,
#'   positional RMSE, adjacent identity switches, and transparent counts.
#' @export
aqt_tracking_metrics <- function(truth,pred,max_distance,class_aware=TRUE,
                                 evaluated_frames=NULL) {
  gt <- .aqt_filter_evaluation_frames(aqt_tracking_observations(truth),
                                       evaluated_frames,reference=TRUE)
  pd <- .aqt_filter_evaluation_frames(aqt_tracking_observations(pred),
                                       evaluated_frames)
  matched <- aqt_tracking_match(gt,pd,max_distance,class_aware)
  key_gt <- paste(gt$session_id,gt$camera_id,sep="\r")
  key_pd <- paste(pd$session_id,pd$camera_id,sep="\r")
  keys <- unique(c(key_gt,key_pd))
  if (!length(keys)) return(data.frame())
  answer <- vector("list",length(keys))
  for (k in seq_along(keys)) {
    ti <- which(key_gt==keys[k]); pi <- which(key_pd==keys[k])
    tg <- gt[ti,,drop=FALSE]; pp <- pd[pi,,drop=FALSE]
    m <- matched[matched$truth_row %in% ti,,drop=FALSE]
    ntruth <- nrow(tg); npred <- nrow(pp); nm <- nrow(m)
    pr <- if (npred) nm/npred else NA_real_
    re <- if (ntruth) nm/ntruth else NA_real_
    make_key <- function(class,id) if (class_aware) paste(class,id,sep="\r") else id
    gt_ids <- unique(make_key(tg$class_id,tg$track_id))
    pd_ids <- unique(make_key(pp$class_id,pp$track_id))
    if (length(gt_ids) && length(pd_ids)) {
      W <- matrix(0,length(gt_ids),length(pd_ids))
      if (nm) {
        row_idx <- match(make_key(m$truth_class,m$truth_id),gt_ids)
        col_idx <- match(make_key(m$pred_class,m$pred_id),pd_ids)
        for (j in seq_len(nm)) W[row_idx[j],col_idx[j]] <- W[row_idx[j],col_idx[j]]+1
      }
      assigned <- .aqt_max_assignment(W)
      valid_assign <- which(!is.na(assigned))
      idtp <- if (length(valid_assign)) sum(W[cbind(valid_assign,assigned[valid_assign])]) else 0
    } else idtp <- 0
    idfp <- npred-idtp; idfn <- ntruth-idtp
    idf1 <- if (2*idtp+idfp+idfn>0) 2*idtp/(2*idtp+idfp+idfn) else NA_real_
    ncomparable <- 0L; idswitch <- 0L
    if (nm) {
      m$identity_key <- make_key(m$truth_class,m$truth_id)
      m$pred_key <- make_key(m$pred_class,m$pred_id)
      for (group in split(seq_len(nm),m$identity_key)) {
        z <- m[group,,drop=FALSE]
        z <- z[order(z$frame_id),,drop=FALSE]
        if (nrow(z)<2L) next
        adjacent <- diff(z$frame_id)==1
        ncomparable <- ncomparable+sum(adjacent)
        idswitch <- idswitch+sum(adjacent & z$pred_key[-1L]!=z$pred_key[-nrow(z)])
      }
    }
    source <- if (ntruth) tg[1L,] else pp[1L,]
    answer[[k]] <- data.frame(session_id=source$session_id,
      camera_id=source$camera_id,n_truth=ntruth,n_pred=npred,
      n_matches=nm,false_positives=npred-nm,false_negatives=ntruth-nm,
      tracking_precision=pr,tracking_recall=re,IDTP=idtp,IDFP=idfp,
      IDFN=idfn,IDF1=idf1,adjacent_id_switches=idswitch,
      comparable_adjacent_pairs=ncomparable,
      position_rmse=if (nm) sqrt(mean(m$distance^2)) else NA_real_)
  }
  do.call(rbind,answer)
}
