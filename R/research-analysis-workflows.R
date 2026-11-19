# Integrated scientific workflow using Milestone 02 source-preserving review.
# These methods orchestrate existing package numerical engines. No source
# timestamps, tank assignments, camera calibration or fish IDs are inferred.

.aqt_research_status <- function(state,reason="",n_used=NA_integer_) {
  data.frame(status=state,reason=reason,n_used=n_used,
             stringsAsFactors=FALSE)
}

.aqt_research_config <- function(config) {
  defaults <- list(
    max_gap_s=NULL,
    min_visible_fish=2L,
    max_pairs=1000000L,
    event_clock="unspecified",
    event_outcome="speed",
    event_windows=list(baseline=c(-5,0),response=c(0,5)),
    event_estimator="time_weighted",
    event_min_points=2L,
    functional_grid_s=seq(-5,5,by=.5),
    functional_max_gap_s=NULL,
    experimental_contrast=FALSE,
    treatment_levels=NULL,
    experimental_draws=199L,
    functional_contrast=FALSE,
    functional_model="none",
    min_fish_fraction=1,
    uncertainty=list(enabled=FALSE,sigma=NULL,rho=0,
                     systematic_sd=0,draws=30L,seed=31L)
  )
  if (!is.list(config) || (length(config) &&
      (is.null(names(config)) || anyNA(names(config)) ||
       any(!nzchar(names(config))) || anyDuplicated(names(config)))))
    stop("config must be a named list with unique keys",call.=FALSE)
  unknown <- setdiff(names(config),names(defaults))
  if (length(unknown))
    stop("Unknown research config setting: ",paste(unknown,collapse=", "),call.=FALSE)
  defaults[names(config)] <- config
  c <- defaults
  if (!is.null(c$max_gap_s)) .aqt_qc_limit(c$max_gap_s,"max_gap_s")
  if (!is.null(c$functional_max_gap_s))
    .aqt_qc_limit(c$functional_max_gap_s,"functional_max_gap_s")
  for (nm in c("min_visible_fish","max_pairs","event_min_points",
               "experimental_draws")) {
    x <- c[[nm]]
    if (!is.numeric(x) || length(x)!=1L || !is.finite(x) ||
        x!=floor(x) || x<1)
      stop(nm," must be a positive integer",call.=FALSE)
  }
  if (c$min_visible_fish<2)
    stop("min_visible_fish must be >=2",call.=FALSE)
  if (!c$event_clock %in% c("unspecified","same_recording",
                            "externally_synchronized"))
    stop("event_clock must be explicitly declared",call.=FALSE)
  if (!c$event_outcome %in% c("speed","step_distance"))
    stop("Event outcome must be an available source-derived numeric measure",
         call.=FALSE)
  if (!c$event_estimator %in% c("sample_mean","time_weighted"))
    stop("Invalid event estimator",call.=FALSE)
  if (!c$functional_model %in% c("none","nested_nlme"))
    stop("functional_model must be none or nested_nlme",call.=FALSE)
  if (!is.logical(c$experimental_contrast) ||
      length(c$experimental_contrast)!=1L || is.na(c$experimental_contrast) ||
      !is.logical(c$functional_contrast) ||
      length(c$functional_contrast)!=1L || is.na(c$functional_contrast))
    stop("Model requests must be TRUE/FALSE",call.=FALSE)
  if (!is.null(c$treatment_levels) &&
      (!is.character(c$treatment_levels) ||
       length(c$treatment_levels)!=2L ||
       anyNA(c$treatment_levels) ||
       any(!nzchar(trimws(c$treatment_levels))) ||
       anyDuplicated(c$treatment_levels)))
    stop("treatment_levels requires explicit ordered control and treatment labels",call.=FALSE)
  if (c$experimental_contrast && c$experimental_draws<100L)
    stop("experimental_draws must be >=100 for tank bootstrap",call.=FALSE)
  if (c$functional_contrast &&
      (c$experimental_draws<100L || c$experimental_draws>5000L))
    stop("functional contrast draws must be 100..5000",call.=FALSE)
  if (!is.numeric(c$functional_grid_s) ||
      length(c$functional_grid_s)<2L ||
      length(c$functional_grid_s)>500L ||
      any(!is.finite(c$functional_grid_s)) ||
      any(diff(c$functional_grid_s)<=0))
    stop("functional_grid_s must have 2..500 increasing finite seconds",call.=FALSE)
  if (!is.numeric(c$min_fish_fraction) ||
      length(c$min_fish_fraction)!=1L ||
      !is.finite(c$min_fish_fraction) ||
      c$min_fish_fraction<=0 || c$min_fish_fraction>1)
    stop("min_fish_fraction must lie in (0,1]",call.=FALSE)
  if (!is.list(c$uncertainty) ||
      (length(c$uncertainty) &&
       (is.null(names(c$uncertainty)) ||
        anyDuplicated(names(c$uncertainty)) ||
        any(!nzchar(names(c$uncertainty))))))
    stop("uncertainty must be a named list",call.=FALSE)
  base_u <- list(enabled=FALSE,sigma=NULL,rho=0,
                 systematic_sd=0,draws=30L,seed=31L)
  if (length(setdiff(names(c$uncertainty),names(base_u))))
    stop("Unknown uncertainty setting",call.=FALSE)
  base_u[names(c$uncertainty)] <- c$uncertainty
  if (!is.logical(base_u$enabled) || length(base_u$enabled)!=1L ||
      is.na(base_u$enabled))
    stop("uncertainty enabled must be TRUE/FALSE",call.=FALSE)
  if (base_u$enabled) {
    if (is.null(base_u$sigma))
      stop("Uncertainty requires researcher-declared sigma",call.=FALSE)
    if (!is.numeric(base_u$draws) || length(base_u$draws)!=1L ||
        !is.finite(base_u$draws) || base_u$draws<20L ||
        base_u$draws>1000L || base_u$draws!=floor(base_u$draws))
      stop("Uncertainty draws must be integer 20..1000",call.=FALSE)
  }
  c$uncertainty <- base_u
  c
}

.aqt_research_design <- function(design,tracks) {
  if (is.null(design)) return(NULL)
  names_required <- c("session_id","camera_id","tank_id","treatment")
  if (!is.data.frame(design) || !nrow(design) ||
      !all(names_required %in% names(design)))
    stop("Design requires session_id,camera_id,tank_id,treatment",call.=FALSE)
  d <- as.data.frame(design[,names_required,drop=FALSE])
  for (nm in names_required) {
    d[[nm]] <- as.character(d[[nm]])
    if (anyNA(d[[nm]]) || any(!nzchar(trimws(d[[nm]]))))
      stop("Design contains blank scope or assignment",call.=FALSE)
  }
  k <- .aqt_qc_scope(d$session_id,d$camera_id)
  if (anyDuplicated(k))
    stop("A recording must have exactly one design row",call.=FALSE)
  tracks_k <- unique(.aqt_qc_scope(tracks$session_id,tracks$camera_id))
  if (!setequal(k,tracks_k))
    stop("Design must cover exactly the review recording scopes",call.=FALSE)
  aqt_design_audit(d) # Reject treatment variations within a tank.
  d
}

.aqt_research_attach_design <- function(data,design) {
  if (is.null(design)) return(data)
  lookup <- .aqt_qc_scope(design$session_id,design$camera_id)
  k <- .aqt_qc_scope(data$session_id,data$camera_id)
  ix <- match(k,lookup)
  if (anyNA(ix)) stop("Design mapping lost an acquisition scope",call.=FALSE)
  data$tank_id <- design$tank_id[ix]
  data$treatment <- design$treatment[ix]
  data
}

.aqt_research_polarization <- function(group,kin) {
  # Native aqt_group_metrics gets centroid and nearest-neighbour geometry;
  # this recomputes ONLY velocity polarization from the gap-audited kinematics.
  group$polarization[] <- NA_real_
  if (!nrow(kin) || !nrow(group)) return(group)
  key <- .aqt_qc_scope(kin$session_id,kin$camera_id,kin$time_s)
  by_time <- split(seq_len(nrow(kin)),key)
  vnames <- c("vx","vy")
  if ("vz" %in% names(kin) && any(is.finite(kin$vz)))
    vnames <- c(vnames,"vz")
  pol <- vapply(by_time,function(idx) {
    v <- as.matrix(kin[idx,vnames,drop=FALSE])
    len <- sqrt(rowSums(v^2))
    valid <- stats::complete.cases(v) & is.finite(len) &
             len>0 & kin$observed[idx]
    if (sum(valid)<2L) return(NA_real_)
    u <- v[valid,,drop=FALSE]/len[valid]
    sqrt(sum(colMeans(u)^2))
  },numeric(1L))
  gkey <- .aqt_qc_scope(group$session_id,group$camera_id,group$time_s)
  group$polarization <- unname(pol[match(gkey,names(pol))])
  group
}

.aqt_research_notes <- function(stage,reason,used=NA_integer_) {
  x <- .aqt_research_status(stage,reason,used)
  x
}

.aqt_research_model_try <- function(fn) {
  tryCatch(list(ok=TRUE,value=fn(),error=NULL),
           error=function(e) list(ok=FALSE,value=NULL,
                                  error=conditionMessage(e)))
}

.aqt_research_ensemble <- function(review,derived,config) {
  u <- config$uncertainty
  x <- derived$kinematics
  if (!nrow(x) || !any(is.finite(x$step_distance)))
    stop("No eligible movement intervals support conditional sensitivity",call.=FALSE)
  if (nrow(review$tracks)*as.double(u$draws)*2>2e6)
    stop("Conditional sensitivity would exceed package scenario memory guard",
         call.=FALSE)
  ensemble <- aqt_trajectory_ensemble(review$tracks,sigma=u$sigma,
      rho=u$rho,systematic_sd=u$systematic_sd,
      draws=u$draws,seed=u$seed,max_gap_s=config$max_gap_s)
  if (!identical(.aqt_qc_scope(x$session_id,x$camera_id,x$time_s,
                              track=x$track_id),
                 .aqt_qc_scope(review$tracks$session_id,
                              review$tracks$camera_id,review$tracks$time_s,
                              track=review$tracks$track_id)))
    stop("Uncertainty source and gap-eligible ledger ordering differ",
         call.=FALSE)
  eligible_steps <- is.finite(x$step_distance)
  unit_key <- .aqt_qc_scope(x$session_id,x$camera_id,track=x$track_id)
  units <- split(seq_len(nrow(x)),unit_key)
  result <- vector("list",length(units)*u$draws)
  k <- 0L
  for (i in seq_len(u$draws)) {
    scenario <- aqt_ensemble_tracks(ensemble,i)
    m <- aqt_kinematics(scenario,max_gap_s=config$max_gap_s)
    for (idx in units) {
      valid <- eligible_steps[idx] & is.finite(m$step_distance[idx])
      k <- k+1L
      result[[k]] <- data.frame(
        session_id=as.character(x$session_id[idx[1L]]),
        camera_id=as.character(x$camera_id[idx[1L]]),
        track_id=as.character(x$track_id[idx[1L]]),
        draw=i,
        path_length=sum(m$step_distance[idx][valid]),
        n_retained_steps=sum(valid),stringsAsFactors=FALSE)
    }
  }
  simulations <- do.call(rbind,result)
  summary <- do.call(rbind,lapply(split(seq_len(nrow(simulations)),
      .aqt_qc_scope(simulations$session_id,simulations$camera_id,
                    track=simulations$track_id)),function(idx) {
    z <- simulations[idx,,drop=FALSE]
    q <- stats::quantile(z$path_length,c(.025,.5,.975),names=FALSE)
    data.frame(session_id=z$session_id[1L],camera_id=z$camera_id[1L],
        track_id=z$track_id[1L],scenario_q025=q[1L],
        scenario_median=q[2L],scenario_q975=q[3L],
        fixed_identity=TRUE,interval_is_confidence_interval=FALSE)
  }))
  rownames(summary) <- NULL
  list(path_sensitivity=summary,assumptions=ensemble$assumptions,
       n_scenarios=as.integer(u$draws),
       interval_type="conditional position-error scenario quantiles, NOT CI",
       fixed_identity=TRUE,physical_error_calibrated=FALSE)
}

#' Run a unified, QC-linked aquatic scientific research analysis
#'
#' Uses the source-preserving Milestone 02 review as the ONLY eligible
#' measurement source. No timestamps, fish identities, tank assignments or
#' physical calibration are fabricated. Profiles whose evidentiary conditions
#' are not satisfied are marked skipped/blocked with explicit diagnostics.
#' Event clock equivalence must be researcher-declared. Population-level
#' inference is limited by independently treated tanks, not frame counts.
#'
#' @param review Completed aqt_qc_review from aqt_trajectory_qc.
#' @param profiles Any subset of movement, schooling, events, functional,
#'   experimental, uncertainty.
#' @param events Optional independent event log (session_id,event_id,start_s,end_s).
#' @param design Optional unique session/camera/tank/treatment mapping.
#' @param config Named analysis settings; see docs/SCIENTIFIC_WORKFLOWS_V1.md.
#' @return aqt_scientific_analysis with measurements, diagnostics and original
#'   QC lineage. Model failures and unsupported profiles retain exact reasons.
#' @export
aqt_research_analyze <- function(review,
    profiles=c("movement","schooling"),
    events=NULL,design=NULL,config=list()) {
  if (!inherits(review,"aqt_qc_review") ||
      !inherits(review$qc,"aqt_trajectory_qc") ||
      !identical(digest::digest(review$qc$raw,algo="sha256",serialize=TRUE),
                 review$original_source_sha256))
    stop("A valid source-preserving Milestone 02 review is required",call.=FALSE)
  options <- c("movement","schooling","events","functional",
               "experimental","uncertainty")
  if (!is.character(profiles) || !length(profiles) ||
      anyNA(profiles) || anyDuplicated(profiles) ||
      any(!profiles %in% options))
    stop("profiles must be a unique nonempty subset of the six workflow names",
         call.=FALSE)
  cfg <- .aqt_research_config(config)
  if (is.null(cfg$max_gap_s)) cfg$max_gap_s <- review$qc$thresholds$max_gap_s
  .aqt_qc_limit(cfg$max_gap_s,"max_gap_s")
  if (is.null(cfg$functional_max_gap_s))
    cfg$functional_max_gap_s <- cfg$max_gap_s
  clock <- !is.null(review$tracks)
  validated_events <- if (is.null(events)) NULL else aqt_event_table(events)
  if (!is.null(validated_events) && !nrow(validated_events))
    validated_events <- NULL
  d <- if (clock) .aqt_research_design(design,review$tracks) else NULL
  if (!clock && !is.null(design))
    stop("Design analysis requires time-qualified reviewed trajectories",call.=FALSE)
  used_review <- review
  derived <- if (clock) aqt_qc_derive(used_review,max_gap_s=cfg$max_gap_s) else NULL
  measures <- if (clock) derived$kinematics else NULL
  if (clock && !is.null(d))
    measures <- .aqt_research_attach_design(measures,d)
  report <- stats::setNames(lapply(options,function(z)
    .aqt_research_status("not_requested","Profile not requested")),options)
  for (z in profiles)
    report[[z]] <- .aqt_research_status("skipped","No eligible observations")
  movement <- schooling <- event_out <- functional <- stats_out <- uncert <- NULL
  if (!clock) {
    for (z in profiles)
      report[[z]] <- .aqt_research_status("blocked",
          "Original source-frame timing unavailable; no invented FPS time")
  } else {
    if ("movement" %in% profiles) {
      movement <- list(kinematics=measures,
        path_summaries=derived$path_summary,
        qc=derived$native_track_qc,
        counts=derived$summary)
      report[["movement"]] <- .aqt_research_status("complete",
        "Frame-adjacent reviewed displacement only",
        sum(is.finite(measures$step_distance)))
    }
    if ("schooling" %in% profiles) {
      found <- .aqt_research_model_try(function() {
        geom <- aqt_group_metrics(review$tracks,max_gap_s=cfg$max_gap_s)
        geom <- geom[geom$n_visible>=cfg$min_visible_fish,,drop=FALSE]
        if (!nrow(geom)) return(NULL)
        geom <- .aqt_research_polarization(geom,derived$kinematics)
        spatial <- aqt_group_spatial_summary(review$tracks,
                   min_fish=cfg$min_visible_fish)
        pair <- aqt_group_pairwise_distances(review$tracks,
                  max_pairs=cfg$max_pairs)
        list(group_metrics=geom,spatial_summary=spatial,
             pairwise_distances=pair,
             simultaneous_frames=nrow(geom),
             velocity_source="gap-audited Milestone 02 kinematics")
      })
      if (found$ok && !is.null(found$value)) {
        schooling <- found$value
        report[["schooling"]] <- .aqt_research_status("complete",
          "Simultaneously observed eligible camera-local fish only",
          nrow(schooling$group_metrics))
      } else report[["schooling"]] <- .aqt_research_status(
        if (found$ok) "skipped" else "failed",
        if (found$ok) "Fewer than required fish observed simultaneously"
        else found$error)
    }
    needs_event <- any(profiles %in% c("events","functional","experimental"))
    clock_ok <- cfg$event_clock %in%
      c("same_recording","externally_synchronized")
    event_ready <- !is.null(validated_events) && clock_ok
    for (z in intersect(profiles,c("events","functional","experimental"))) {
      if (!event_ready) report[[z]] <- .aqt_research_status("blocked",
        if (is.null(validated_events))
          "Independently logged event times were not supplied"
        else "Event clock relation unspecified; declare same_recording or externally_synchronized")
    }
    if (event_ready) {
      if ("events" %in% profiles || "experimental" %in% profiles) {
        e <- .aqt_research_model_try(function() {
          unit_cols <- c("camera_id","track_id")
          if (!is.null(d)) unit_cols <- c(unit_cols,"tank_id","treatment")
          aqt_event_epoch_summary(measures,validated_events,
            outcome=cfg$event_outcome,
            windows=cfg$event_windows,
            unit_cols=unit_cols,estimator=cfg$event_estimator,
            min_points=cfg$event_min_points,max_gap_s=cfg$max_gap_s)
        })
        if (e$ok && nrow(e$value)>0L) {
          event_out <- list(epoch_summaries=e$value,
                aligned_measurements=aqt_align_events(
                   measures,validated_events,
                   window_s=range(unlist(cfg$event_windows))),
                event_log=validated_events,
                clock_relation_declared=cfg$event_clock,
                independently_verified_sync=FALSE)
          if ("events" %in% profiles)
            report[["events"]] <- .aqt_research_status("complete",
              "Descriptive observed events, not causal treatment effects",
              sum(is.finite(e$value$value)))
        } else if ("events" %in% profiles) report[["events"]] <-
          .aqt_research_status(if(e$ok) "skipped" else "failed",
             if(e$ok) "No event-aligned observations" else e$error)
      }
      if ("functional" %in% profiles) {
        fg <- .aqt_research_model_try(function() {
          grid <- aqt_functional_event_grid(measures,validated_events,
            outcome=cfg$event_outcome,grid_s=cfg$functional_grid_s,
            max_gap_s=cfg$functional_max_gap_s)
          list(grid=grid,coverage=aqt_functional_coverage(grid))
        })
        if(fg$ok) {
          functional <- fg$value
          report[["functional"]] <- .aqt_research_status("complete",
            "Gap-limited supported grid, missing values never imputed",
            sum(fg$value$grid$supported))
        } else report[["functional"]] <- .aqt_research_status("failed",fg$error)
      }
      if ("experimental" %in% profiles) {
        if (is.null(d)) {
          report[["experimental"]] <- .aqt_research_status("blocked",
            "A unique tank/treatment assignment map is required")
        } else {
          design_audit <- aqt_design_audit(d)
          stats_out <- list(design_audit=design_audit,
                            tank_contrast=NULL,
                            hierarchical_model=NULL,
                            functional_contrast=NULL,
                            functional_model=NULL,
                            estimator_status="not_requested")
          sufficient <- nrow(design_audit)==2L &&
            all(design_audit$n_tanks>=2L)
          declared_levels <- cfg$treatment_levels
          ordered_levels_ok <- !is.null(declared_levels) &&
            setequal(design_audit$treatment,declared_levels)
          if (!sufficient) {
            report[["experimental"]] <- .aqt_research_status("blocked",
                "Two treatment groups with >=2 independent tanks each are required; fish/frames are not experimental replicates")
          } else if (is.null(event_out)) {
            report[["experimental"]] <- .aqt_research_status("blocked",
                "Experimental estimation requires observed baseline and response epochs")
          } else if (cfg$experimental_contrast && !ordered_levels_ok) {
            report[["experimental"]] <- .aqt_research_status("blocked",
                "Specify explicit ordered treatment_levels matching the two observed independent-tank groups")
          } else if (!cfg$experimental_contrast) {
            report[["experimental"]] <- .aqt_research_status("skipped",
              "Study design audited; treatment inference requires experimental_contrast=TRUE")
          } else {
            contrast <- .aqt_research_model_try(function()
              aqt_tank_event_contrast(event_out$epoch_summaries,
                treatment_levels=cfg$treatment_levels,
                draws=cfg$experimental_draws))
            if (contrast$ok) {
              stats_out$tank_contrast <- contrast$value
              stats_out$estimator_status <- "tank_bootstrap_completed"
              report[["experimental"]] <- .aqt_research_status("complete",
                "Between-tank association; not causal identification",
                sum(design_audit$n_tanks))
            } else report[["experimental"]] <-
              .aqt_research_status("failed",contrast$error)
          }
          if (sufficient && ordered_levels_ok && !is.null(functional) && cfg$functional_contrast) {
            fc <- .aqt_research_model_try(function()
              aqt_functional_tank_contrast(functional$grid,
                treatment_levels=cfg$treatment_levels,
                min_fish_fraction=cfg$min_fish_fraction,
                draws=cfg$experimental_draws))
            if(fc$ok) stats_out$functional_contrast <- fc$value
            else stats_out$functional_contrast_error <- fc$error
          }
          if (sufficient && ordered_levels_ok && !is.null(functional) &&
              cfg$functional_model=="nested_nlme") {
            fm <- .aqt_research_model_try(function()
              aqt_functional_longitudinal_fit(
                aqt_functional_longitudinal_prepare(functional$grid,
                  treatment_levels=sort(unique(d$treatment)))))
            if (fm$ok) stats_out$functional_model <- fm$value
            else stats_out$functional_model_error <- fm$error
          }
        }
      }
    }
    if ("uncertainty" %in% profiles) {
      if (!cfg$uncertainty$enabled)
        report[["uncertainty"]] <- .aqt_research_status("skipped",
          "Conditional scenario disabled; declare a measurement-error sigma")
      else {
        u <- .aqt_research_model_try(function()
            .aqt_research_ensemble(review,derived,cfg))
        if (u$ok) {
          uncert <- u$value
          report[["uncertainty"]] <- .aqt_research_status("complete",
            "Researcher-declared fixed-ID spatial sensitivity, not confidence intervals",
            u$value$n_scenarios)
        } else report[["uncertainty"]] <- .aqt_research_status("failed",u$error)
      }
    }
  }
  diagnostics <- do.call(rbind,lapply(names(report),function(profile) {
    cbind(profile=profile,report[[profile]],stringsAsFactors=FALSE)
  }))
  rownames(diagnostics) <- NULL
  source_counts <- review$row_audit
  scope <- if (clock) unique(.aqt_qc_scope(
    review$tracks$session_id,review$tracks$camera_id)) else character()
  audit <- list(
    camera_coverage=review$camera_coverage,
    per_track_coverage=review$per_track_coverage,
    expected_coverage=review$expected_coverage,
    eligibility=source_counts,
    source_rows=review$n_original,
    accepted_positions=review$n_review_eligible,
    excluded_rows=review$n_review_excluded,
    observed_movement_steps=if(clock) sum(is.finite(derived$kinematics$step_distance)) else 0L,
    n_source_frames=nrow(review$qc$frames),
    n_scopes=length(scope),
    source_sha256=review$original_source_sha256,
    original_rows_unchanged=TRUE)
  structure(list(
      movement=movement,schooling=schooling,events=event_out,
      functional=functional,statistical_models=stats_out,
      uncertainty=uncert,audit=audit,diagnostics=diagnostics,
      provenance=list(source=review$qc$provenance,
         raw_sha256=review$original_source_sha256,
         clock_provenance=review$qc$time_provenance,
         coordinate_units=if(clock) attr(review$tracks,"aqt_units") else "px",
         coordinate_system=if(clock) attr(review$tracks,"aqt_coordinate_system") else "image",
         event_clock_relation_declared=cfg$event_clock,
         event_clock_independently_certified=FALSE,
         fish_identity_certified=FALSE,physical_calibration_certified=FALSE,
         package_version=as.character(utils::packageVersion("aquaTrajectories")),
         profile_schema="aqt-research-analysis-1.0.0"),
      config=cfg,selected_profiles=profiles,
      review=review
    ),class="aqt_scientific_analysis")
}

#' Export a complete, auditable scientific-analysis result without recomputation
#'
#' Creates a new directory of input lineage, stage-level CSV outputs,
#' serialized scientific objects and SHA-256 artifact manifest. Does not
#' overwrite existing outputs; RDS retains scientific model objects.
#'
#' @param study Aqt_scientific_analysis returned by aqt_research_analyze.
#' @param directory New output directory; parent must already exist.
#' @return Output path invisibly.
#' @export
aqt_research_export <- function(study,directory) {
  if (!inherits(study,"aqt_scientific_analysis") ||
      !inherits(study$review,"aqt_qc_review") ||
      !identical(digest::digest(study$review$qc$raw,
                     algo="sha256",serialize=TRUE),study$audit$source_sha256))
    stop("Unverifiable scientific analysis object/source lineage",call.=FALSE)
  if (!is.character(directory) || length(directory)!=1L ||
      is.na(directory) || file.exists(directory) || dir.exists(directory) ||
      !dir.exists(dirname(directory)))
    stop("A new destination with existing parent is required",call.=FALSE)
  staging <- tempfile(".aqt-research-analysis-",tmpdir=dirname(directory))
  dir.create(staging)
  on.exit(if(dir.exists(staging))
    unlink(staging,recursive=TRUE,force=TRUE),add=TRUE)
  folders <- c("movement","schooling","events","functional",
               "statistical_models","uncertainty","audit","reproducibility")
  for (folder in folders) dir.create(file.path(staging,folder))
  written <- character()
  emit <- function(name,obj) {
    file <- file.path(staging,name)
    if (!is.data.frame(obj)) stop("Export tables must be data.frames",call.=FALSE)
    utils::write.csv(obj,file,row.names=FALSE,na="")
    written <<- c(written,name)
  }
  emit("audit/measurement_eligibility.csv",study$audit$eligibility)
  emit("audit/camera_coverage.csv",study$audit$camera_coverage)
  emit("audit/track_coverage.csv",study$audit$per_track_coverage)
  emit("audit/profile_decisions.csv",study$diagnostics)
  if (!is.null(study$audit$expected_coverage))
    emit("audit/declared_roster_coverage.csv",study$audit$expected_coverage)
  if (!is.null(study$movement)) {
    emit("movement/kinematics.csv",study$movement$kinematics)
    emit("movement/path_summaries.csv",study$movement$path_summaries)
    emit("movement/counts.csv",study$movement$counts)
  }
  if (!is.null(study$schooling)) {
    emit("schooling/group_metrics.csv",study$schooling$group_metrics)
    emit("schooling/group_spatial.csv",study$schooling$spatial_summary)
    emit("schooling/pairwise_distances.csv",study$schooling$pairwise_distances)
  }
  if (!is.null(study$events)) {
    emit("events/epoch_summaries.csv",study$events$epoch_summaries)
    emit("events/aligned_measurements.csv",study$events$aligned_measurements)
    emit("events/source_event_log.csv",study$events$event_log)
  }
  if (!is.null(study$functional)) {
    emit("functional/event_grid.csv",study$functional$grid)
    emit("functional/observed_support.csv",study$functional$coverage)
  }
  if (!is.null(study$statistical_models)) {
    emit("statistical_models/experimental_design_audit.csv",
         study$statistical_models$design_audit)
  }
  if (!is.null(study$uncertainty))
    emit("uncertainty/conditional_path_sensitivity.csv",
         study$uncertainty$path_sensitivity)
  saveRDS(study,file.path(staging,"reproducibility/analysis.rds"),
          version=3L,compress="xz")
  written <- c(written,"reproducibility/analysis.rds")
  manifest <- list(
    schema_version="1.0.0",
    output_type="aqt_scientific_analysis",
    original_raw_sha256=study$audit$source_sha256,
    n_source_rows=study$audit$source_rows,
    n_review_eligible=study$audit$accepted_positions,
    n_review_excluded=study$audit$excluded_rows,
    n_valid_movement_steps=study$audit$observed_movement_steps,
    selected_profiles=study$selected_profiles,
    profile_status=split(study$diagnostics[,c("status","reason","n_used")],
                         study$diagnostics$profile),
    provenance=study$provenance,
    config=study$config,
    output_sha256=as.list(stats::setNames(vapply(written,function(name)
       unname(digest::digest(file.path(staging,name),
                             algo="sha256",file=TRUE)),character(1L)),
       written)))
  jsonlite::write_json(manifest,file.path(staging,
       "reproducibility/ANALYSIS_MANIFEST.json"),
       auto_unbox=TRUE,pretty=TRUE,null="null",na="null",digits=17)
  if (!file.rename(staging,directory))
    stop("Unable to publish complete scientific analysis output",call.=FALSE)
  invisible(directory)
}
