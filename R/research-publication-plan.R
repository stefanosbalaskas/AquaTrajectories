# Milestone 04 figure eligibility and source-bound presentation plan.

.aqt_publication_assert <- function(study) {
  if (!inherits(study,"aqt_scientific_analysis") ||
      !inherits(study$review,"aqt_qc_review") ||
      !is.data.frame(study$diagnostics) ||
      !identical(digest::digest(study$review$qc$raw,
                   algo="sha256",serialize=TRUE),study$audit$source_sha256))
    stop("Expected intact source-verified scientific analysis object",call.=FALSE)
  invisible(TRUE)
}
.aqt_publication_scope_index <- function(d,s,c) {
  which(as.character(d$session_id)==s & as.character(d$camera_id)==c)
}
.aqt_publication_valid <- function(x) is.data.frame(x) && nrow(x)>0L

.aqt_publication_entry <- function(id,kind,title,caption,ok,
                                   reason="",session="",camera="",used=0L) {
  data.frame(figure_id=id,kind=kind,title=title,caption=caption,
     session_id=session,camera_id=camera,eligible=isTRUE(ok),
     reason=if(isTRUE(ok)) "" else reason,n_used=as.integer(used),
     stringsAsFactors=FALSE)
}

#' Plan source-supported scientific publication figures
#'
#' Returns all candidate figures, including ones that must be withheld
#' because the selected scientific analysis did not support them. No
#' interpolation, estimation, or source-data modification takes place.
#' @param study Source-verified aqt_scientific_analysis.
#' @param max_scopes Maximum camera/session panels, 1..8.
#' @return Figure eligibility catalogue with evidence counts and captions.
#' @export
aqt_research_figure_plan <- function(study,max_scopes=3L) {
  .aqt_publication_assert(study)
  if (!is.numeric(max_scopes) || length(max_scopes)!=1L ||
      !is.finite(max_scopes) || max_scopes<1L || max_scopes>8L ||
      max_scopes!=floor(max_scopes))
    stop("max_scopes must be an integer from 1 to 8",call.=FALSE)
  plan <- list()
  add <- function(...) plan[[length(plan)+1L]] <<- .aqt_publication_entry(...)
  cov <- study$audit$camera_coverage
  okcov <- .aqt_publication_valid(cov) &&
    all(c("n_acquisition_frames","n_frames_with_reviewed_positions") %in%
      names(cov))
  add("F01_SOURCE_COVERAGE","coverage","Reviewed acquisition-frame coverage",
      "Fraction of source acquisition frames containing at least one reviewed eligible tracked fish. Not fish-level recall.",
      okcov,"Missing acquisition-frame or review coverage",used=if(okcov)
      sum(cov$n_acquisition_frames) else 0L)
  ledger <- study$review$row_audit
  add("F02_REVIEW_COUNTS","review_counts","Source row eligibility",
      "Numbers of eligible and excluded original observations; all original rows remain archived in the QC ledger.",
      nrow(ledger)>0L,"No source fish-observation rows",used=nrow(ledger))
  f <- study$review$qc$frames
  scopes <- unique(f[,c("session_id","camera_id"),drop=FALSE])
  scopes <- scopes[order(as.character(scopes$session_id),
                         as.character(scopes$camera_id)),,drop=FALSE]
  scopes <- head(scopes,max_scopes)
  for (i in seq_len(nrow(scopes))) {
    s <- as.character(scopes$session_id[i])
    c <- as.character(scopes$camera_id[i])
    prefix <- sprintf("S%02d",i)
    m <- study$movement
    p <- if(!is.null(study$review$tracks))
       study$review$tracks else NULL
    points <- if(!is.null(p)) {
      ix <- .aqt_publication_scope_index(p,s,c)
      sum(p$observed[ix] & is.finite(p$x[ix]) & is.finite(p$y[ix]))
    } else 0L
    mk <- if(!is.null(m)) m$kinematics else NULL
    steps <- if(!is.null(mk)) {
      ix <- .aqt_publication_scope_index(mk,s,c)
      sum(is.finite(mk$step_distance[ix]))
    } else 0L
    add(paste0(prefix,"_QUALIFIED_PATHS"),"paths",
        paste("Observed 2D trajectories:",s,c),
        "Only original reviewed fish positions are drawn; line segments must correspond to QC-valid source-frame-adjacent movement steps.",
        !is.null(m) && points>0L,
        "No source-qualified movement observations for this session/camera",
        session=s,camera=c,used=points)
    add(paste0(prefix,"_MEASURED_SPEED"),"speed",
        paste("Valid movement speed:",s,c),
        "Each plotted speed is a retained, gap-qualified displacement step; no excluded or missing frame is interpolated.",
        !is.null(m) && steps>0L,
        "No finite eligible displacement steps in this session/camera",
        session=s,camera=c,used=steps)
    geom <- if(!is.null(study$schooling))
      study$schooling$spatial_summary else NULL
    gi <- if(.aqt_publication_valid(geom))
       .aqt_publication_scope_index(geom,s,c) else integer()
    good <- length(gi)>0L && all(is.finite(geom$radius_gyration[gi]))
    add(paste0(prefix,"_SCHOOL_DISPERSION"),"school_dispersion",
        paste("Simultaneous fish-school dispersion:",s,c),
        "Observed school radius of gyration. Different fish counts or tracking coverage can change the geometry.",
        !is.null(study$schooling) && good,
        "No qualified simultaneous-fish school geometry",
        session=s,camera=c,used=length(gi))
    group <- if(!is.null(study$schooling))
      study$schooling$group_metrics else NULL
    gx <- if(.aqt_publication_valid(group))
      .aqt_publication_scope_index(group,s,c) else integer()
    n_pol <- if(length(gx))sum(is.finite(group$polarization[gx])) else 0L
    add(paste0(prefix,"_DIRECTIONAL_POLARIZATION"),"polarization",
        paste("School directional alignment:",s,c),
        "Directional polarization uses Milestone 02 gap-audited velocities; it is undefined when fewer than two qualified moving fish coincide.",
        !is.null(study$schooling) && n_pol>0L,
        "Insufficient simultaneous nonzero, QC-qualified fish velocity vectors",
        session=s,camera=c,used=n_pol)
  }
  ep <- if(!is.null(study$events)) study$events$epoch_summaries else NULL
  epn <- if(.aqt_publication_valid(ep))sum(is.finite(ep$value)) else 0L
  add("F20_EVENT_EPOCHS","event_epochs","Descriptive event-epoch outcomes",
      "Per-fish event outcomes; repeated fish frames are not independently treated experimental replicates.",
      epn>0L,"Missing event log or no supported event-epoch observations",used=epn)
  grid <- if(!is.null(study$functional))study$functional$grid else NULL
  n_support <- if(.aqt_publication_valid(grid))sum(grid$supported) else 0L
  add("F21_FUNCTIONAL_SUPPORT","functional_support","Event-relative data coverage",
      "Observed support fraction at each relative event time; source-missing measurements remain missing.",
      n_support>0L,"No source-supported functional observations",
      used=n_support)
  add("F22_FUNCTIONAL_CURVES","functional_curves","Supported functional trajectories",
      "Observed fish curves with unsupported positions preserved as gaps. Fish curves are not independent treatment units.",
      n_support>=2L,"Insufficient supported functional curve points",
      used=n_support)
  fit <- if(!is.null(study$statistical_models))
    study$statistical_models$tank_contrast else NULL
  nf <- if(is.list(fit) && .aqt_publication_valid(fit$per_tank))
       nrow(fit$per_tank) else 0L
  add("F30_INDEPENDENT_TANK_CHANGES","tank_changes",
      "Independently treated tanks before and after event",
      "One measured before/after line per independent tank. Descriptive, not causal proof.",
      nf>0L,"No fitted design-eligible independent-tank contrast",
      used=nf)
  sim <- if(!is.null(study$uncertainty))
    study$uncertainty$path_sensitivity else NULL
  ns <- if(.aqt_publication_valid(sim)) nrow(sim) else 0L
  add("F40_POSITION_SENSITIVITY","sensitivity",
      "Conditional position-error sensitivity",
      "Researcher-declared, fixed-identity simulated path quantiles. NOT empirical statistical confidence intervals.",
      ns>0L,"No configured positional sensitivity scenarios",used=ns)
  ans <- do.call(rbind,plan)
  rownames(ans) <- NULL
  ans
}
