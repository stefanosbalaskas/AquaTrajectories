# AquaTrajectories: independent detection benchmark
# Reference rectangles must come from external manual review, not the detector
# under evaluation. Score and IoU conventions are recorded in the outputs.

.aqt_required <- function(x, names, name) {
  if (!is.data.frame(x) || !all(names %in% names(x)))
    stop(name, " must be a data frame with: ", paste(names,collapse=", "),call.=FALSE)
}

.aqt_scope <- function(x) {
  paste(x$session_id,x$camera_id,x$frame_id,sep="\r")
}

#' Validate labelled detector bounding boxes
#'
#' Reference and prediction boxes use the same format. Every box is a
#' nondegenerate axis-aligned rectangle in the same pixel coordinate system.
#' Frame identifiers must be scoped by session and camera. A prediction
#' must have confidence in [0,1]; reference boxes need no confidence.
#'
#' @param data Data frame: session_id, camera_id, frame_id, class_id,
#'   xmin, ymin, xmax, ymax; for predictions also confidence.
#' @param role Whether these are independent reference boxes or predictions.
#' @return A validated data frame of boxes.
#' @export
aqt_detection_boxes <- function(data,role=c("truth","prediction")) {
  role <- match.arg(role)
  fields <- c("session_id","camera_id","frame_id","class_id",
              "xmin","ymin","xmax","ymax")
  .aqt_required(data,fields,"data")
  d <- as.data.frame(data,stringsAsFactors=FALSE)
  for (nm in fields[1:4]) {
    if (anyNA(d[[nm]]) || any(!nzchar(as.character(d[[nm]]))))
      stop(nm," must be nonmissing and nonempty",call.=FALSE)
    d[[nm]] <- as.character(d[[nm]])
  }
  for (nm in fields[5:8]) {
    if (!is.numeric(d[[nm]]) || any(!is.finite(d[[nm]])))
      stop(nm," must contain finite numbers",call.=FALSE)
  }
  if (any(d$xmin>=d$xmax) || any(d$ymin>=d$ymax))
    stop("Degenerate or inverted bounding box",call.=FALSE)
  if (role=="prediction") {
    if (!"confidence" %in% names(d) || !is.numeric(d$confidence) ||
        any(!is.finite(d$confidence)) ||
        any(d$confidence<0 | d$confidence>1))
      stop("Predictions require confidence values within [0,1]",call.=FALSE)
  } else if (!"confidence" %in% names(d)) d$confidence <- NA_real_
  d$box_index <- seq_len(nrow(d))
  d
}

#' Calculate pairwise intersection over union of axis-aligned rectangles
#' @param truth,pred Data frames with xmin/ymin/xmax/ymax.
#' @return Numeric n_truth-by-n_pred IoU matrix.
#' @export
aqt_box_iou <- function(truth,pred) {
  fields <- c("xmin","ymin","xmax","ymax")
  .aqt_required(truth,fields,"truth")
  .aqt_required(pred,fields,"pred")
  for (d in list(truth,pred)) {
    for (nm in fields) if (!is.numeric(d[[nm]]) || any(!is.finite(d[[nm]])))
      stop("Box coordinates must be finite numeric",call.=FALSE)
    if (any(d$xmin>=d$xmax) || any(d$ymin>=d$ymax))
      stop("Degenerate bounding box",call.=FALSE)
  }
  ans <- matrix(0,nrow(truth),nrow(pred))
  if (!length(ans)) return(ans)
  for (i in seq_len(nrow(truth))) for (j in seq_len(nrow(pred))) {
    w <- max(0,min(truth$xmax[i],pred$xmax[j])-max(truth$xmin[i],pred$xmin[j]))
    h <- max(0,min(truth$ymax[i],pred$ymax[j])-max(truth$ymin[i],pred$ymin[j]))
    intr <- w*h
    area1 <- (truth$xmax[i]-truth$xmin[i])*(truth$ymax[i]-truth$ymin[i])
    area2 <- (pred$xmax[j]-pred$xmin[j])*(pred$ymax[j]-pred$ymin[j])
    ans[i,j] <- intr/(area1+area2-intr)
  }
  ans
}

# Match as many pairs as possible, using the highest-IoU edges first.
# This optimizes cardinality, not necessarily total overlap. The latter is
# not needed for thresholded TP/FP/FN evaluation.
.aqt_cardinality_match <- function(weight,threshold) {
  nr <- nrow(weight); nc <- ncol(weight)
  left <- rep(NA_integer_,nr)
  if (!nr || !nc) return(left)
  right <- rep(NA_integer_,nc)
  traverse <- function(i) {
    eligible <- which(is.finite(weight[i,]) & weight[i,]>=threshold)
    eligible <- eligible[order(-weight[i,eligible],eligible)]
    for (j in eligible) {
      if (seen[j]) next
      seen[j] <<- TRUE
      if (is.na(right[j]) || traverse(right[j])) {
        right[j] <<- i
        return(TRUE)
      }
    }
    FALSE
  }
  for (i in seq_len(nr)) {
    seen <- rep(FALSE,nc)
    traverse(i)
  }
  chosen <- which(!is.na(right))
  if (length(chosen)) left[right[chosen]] <- chosen
  left
}

#' Match fish detections to independent ground-truth boxes
#'
#' Matching maximizes valid pair cardinality independently for each
#' session, camera, frame, and class at an IoU threshold. Each reference
#' and predicted box can match at most once. The matching is deterministic.
#'
#' @param truth Reference boxes.
#' @param pred Predicted boxes with confidence.
#' @param iou_threshold Overlap threshold, inclusive.
#' @param confidence_threshold Predictions below this value are omitted.
#' @return Long table with TP, FP, FN statuses, source row indices and IoU.
#' @export
aqt_detection_match <- function(truth,pred,iou_threshold=.5,confidence_threshold=0) {
  if (length(iou_threshold)!=1L || !is.finite(iou_threshold) ||
      iou_threshold<=0 || iou_threshold>1)
    stop("iou_threshold must be in (0,1]",call.=FALSE)
  if (length(confidence_threshold)!=1L || !is.finite(confidence_threshold) ||
      confidence_threshold<0 || confidence_threshold>1)
    stop("confidence_threshold must be in [0,1]",call.=FALSE)
  g <- aqt_detection_boxes(truth,"truth")
  p <- aqt_detection_boxes(pred,"prediction")
  p <- p[p$confidence>=confidence_threshold,,drop=FALSE]
  columns <- data.frame(session_id=character(),camera_id=character(),
    frame_id=character(),class_id=character(),status=character(),
    truth_row=integer(),pred_row=integer(),iou=double(),
    confidence=double(),stringsAsFactors=FALSE)
  if (!nrow(g) && !nrow(p)) return(columns)
  gkey <- paste(.aqt_scope(g),g$class_id,sep="\r")
  pkey <- paste(.aqt_scope(p),p$class_id,sep="\r")
  keys <- unique(c(gkey,pkey))
  answer <- vector("list",length(keys))
  for (k in seq_along(keys)) {
    gi <- which(gkey==keys[k]); pj <- which(pkey==keys[k])
    gm <- g[gi,,drop=FALSE]; pm <- p[pj,,drop=FALSE]
    M <- aqt_box_iou(gm,pm)
    assignment <- .aqt_cardinality_match(M,iou_threshold)
    matched <- which(!is.na(assignment))
    matched_pred <- if (length(matched)) assignment[matched] else integer()
    status <- c(rep("TP",length(matched)),
                rep("FN",nrow(gm)-length(matched)),
                rep("FP",nrow(pm)-length(matched_pred)))
    tr <- c(gm$box_index[matched],
            gm$box_index[setdiff(seq_len(nrow(gm)),matched)],
            rep(NA_integer_,nrow(pm)-length(matched_pred)))
    pr <- c(pm$box_index[matched_pred],
            rep(NA_integer_,nrow(gm)-length(matched)),
            pm$box_index[setdiff(seq_len(nrow(pm)),matched_pred)])
    iou <- if (length(matched)) M[cbind(matched,matched_pred)] else numeric()
    val <- c(iou,rep(NA_real_,length(status)-length(iou)))
    conf <- c(pm$confidence[matched_pred],rep(NA_real_,nrow(gm)-length(matched)),
              pm$confidence[setdiff(seq_len(nrow(pm)),matched_pred)])
    ref <- if (nrow(gm)) gm[1L,] else pm[1L,]
    answer[[k]] <- data.frame(session_id=rep(ref$session_id,length(status)),
      camera_id=rep(ref$camera_id,length(status)),
      frame_id=rep(ref$frame_id,length(status)),
      class_id=rep(ref$class_id,length(status)),
      status=status,truth_row=tr,pred_row=pr,iou=val,confidence=conf)
  }
  do.call(rbind,answer)
}

#' Detection precision, recall, F1 and one-to-one match counts
#'
#' Precision is undefined (NA) when no predictions exist, except that
#' unobserved classes are omitted. Recall is undefined without references.
#' F1 is 0 when one of the defined precision/recall values is zero;
#' otherwise undefined if either input is undefined.
#'
#' @param truth,pred Reference and predicted boxes.
#' @param iou_threshold Match threshold.
#' @param confidence_threshold Prediction confidence cutoff.
#' @return Per-class rows plus a micro-pooled ALL row.
#' @export
aqt_detection_metrics <- function(truth,pred,iou_threshold=.5,confidence_threshold=.25) {
  m <- aqt_detection_match(truth,pred,iou_threshold,confidence_threshold)
  if (!nrow(m)) return(data.frame())
  classes <- unique(m$class_id)
  stat <- function(z,label) {
    tp <- sum(z$status=="TP"); fp <- sum(z$status=="FP"); fn <- sum(z$status=="FN")
    prec <- if (tp+fp) tp/(tp+fp) else NA_real_
    recall <- if (tp+fn) tp/(tp+fn) else NA_real_
    f1 <- if (is.na(prec) || is.na(recall)) NA_real_
          else if (prec+recall==0) 0 else 2*prec*recall/(prec+recall)
    data.frame(class_id=label,TP=tp,FP=fp,FN=fn,
               precision=prec,recall=recall,F1=f1)
  }
  out <- lapply(classes,function(cl) stat(m[m$class_id==cl,,drop=FALSE],cl))
  do.call(rbind,c(out,list(stat(m,"ALL"))))
}

#' Detection average precision using confidence-ranked 101-point interpolation
#'
#' These are explicit IoU-based, per-class AP calculations, NOT identical to
#' full COCO evaluation (no crowd/ignore, area ranges or maxDets conventions).
#' Rankings are computed across all frames per species. AP is 0 if references
#' exist but there are no predictions, NA when no reference exists.
#'
#' @param truth Independent labelled fish bounding boxes.
#' @param pred Predicted boxes with confidence scores.
#' @param iou_thresholds Overlap thresholds in (0,1].
#' @return Per class and IoU threshold AP, n_truth and n_predictions.
#' @export
aqt_detection_ap <- function(truth,pred,iou_thresholds=seq(.5,.95,by=.05)) {
  g <- aqt_detection_boxes(truth,"truth")
  p <- aqt_detection_boxes(pred,"prediction")
  if (!is.numeric(iou_thresholds) || !length(iou_thresholds) ||
      any(!is.finite(iou_thresholds)) || any(iou_thresholds<=0 | iou_thresholds>1))
    stop("Invalid IoU threshold vector",call.=FALSE)
  cl <- unique(c(g$class_id,p$class_id))
  if (!length(cl)) return(data.frame())
  out <- vector("list",length(cl)*length(iou_thresholds))
  q <- 0L
  for (species in cl) for (thr in iou_thresholds) {
    gt <- g[g$class_id==species,,drop=FALSE]
    pd <- p[p$class_id==species,,drop=FALSE]
    pd <- pd[order(-pd$confidence,pd$box_index),,drop=FALSE]
    ng <- nrow(gt); np <- nrow(pd)
    if (!ng) {
      ap <- NA_real_
    } else if (!np) {
      ap <- 0
    } else {
      gt_used <- rep(FALSE,ng)
      tp <- integer(np)
      scope_g <- .aqt_scope(gt)
      scope_p <- .aqt_scope(pd)
      for (j in seq_len(np)) {
        candidates <- which(scope_g==scope_p[j] & !gt_used)
        if (!length(candidates)) next
        overlap <- aqt_box_iou(gt[candidates,,drop=FALSE],
                               pd[j,,drop=FALSE])[,1L]
        best <- which.max(overlap)
        if (overlap[best]>=thr) {
          tp[j] <- 1L
          gt_used[candidates[best]] <- TRUE
        }
      }
      cumulative_tp <- cumsum(tp)
      recall <- cumulative_tp/ng
      precision <- cumulative_tp/seq_len(np)
      # 101-point maximum-precision envelope, inclusive of recall=1.
      ap <- mean(vapply(seq(0,1,length.out=101L),function(r) {
        applicable <- which(recall>=r)
        if (!length(applicable)) 0 else max(precision[applicable])
      },numeric(1L)))
    }
    q <- q+1L
    out[[q]] <- data.frame(class_id=species,iou_threshold=thr,
      n_truth=ng,n_predictions=np,AP=ap)
  }
  do.call(rbind,out)
}
