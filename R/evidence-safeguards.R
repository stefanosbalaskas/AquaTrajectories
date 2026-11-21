# Evidence safeguards: descriptive sensitivity and claim eligibility.
# Observations, software identities and camera coordinates are not experimental units.
# Functions in this file never impute missing tracks or certify calibration.

.aqt_ev_require <- function(d, cols) {
  if (!is.data.frame(d) || !nrow(d) || !all(cols %in% names(d)))
    stop("A nonempty data frame containing: ", paste(cols,collapse=", "),
         " is required",call.=FALSE)
}
.aqt_ev_cols <- function(d, names) {
  .aqt_ev_require(d,names)
  invisible(TRUE)
}
.aqt_ev_clean <- function(d,group_col,phase_col,time_col,value_col,
                          track_col,eligible_col=NULL,policy_col=NULL) {
  cols <- c(group_col,phase_col,time_col,value_col,track_col,
            eligible_col,policy_col)
  .aqt_ev_cols(d,cols)
  o <- data.frame(
    group=as.character(d[[group_col]]),
    phase=as.character(d[[phase_col]]),
    time=as.numeric(d[[time_col]]),
    value=as.numeric(d[[value_col]]),
    track=as.character(d[[track_col]]),
    policy=if(is.null(policy_col)) "default" else as.character(d[[policy_col]]),
    eligible=if(is.null(eligible_col)) TRUE else d[[eligible_col]],
    stringsAsFactors=FALSE)
  if(!is.logical(o$eligible) || anyNA(o$eligible))
    stop("Eligibility must be a nonmissing logical column",call.=FALSE)
  good <- o$eligible & stats::complete.cases(o[,c("group","phase","time",
    "value","track","policy")]) & nzchar(o$group) & nzchar(o$phase) &
    nzchar(o$track) & nzchar(o$policy)
  o[good,,drop=FALSE]
}
.aqt_ev_split <- function(d, cols) {
  if(!nrow(d))return(list())
  split(seq_len(nrow(d)),interaction(d[,cols,drop=FALSE],
        drop=TRUE,lex.order=TRUE))
}
.aqt_ev_median <- function(x) if(length(x)) stats::median(x) else NA_real_

#' Compare descriptive trajectory estimates across weighting and QC specifications
#'
#' A source-column-aware, descriptive sensitivity analysis. Numeric-looking
#' recording and track labels are always identifiers, not list positions.
#' Pooled steps, fragment-equal medians and time-window-equal medians are
#' contrasted without treating steps or fragments as independent animals.
#'
#' @param data Data frame containing eligible or policy-tagged movement steps.
#' @param group_col,phase_col,time_col,value_col,track_col Source column names.
#' @param eligible_col Optional logical step eligibility column.
#' @param policy_col Optional QC policy identifier; policies remain separate.
#' @param window_widths Positive widths in declared source-time units.
#' @param reference_phase Explicit reference phase label.
#' @param min_steps Minimum eligible rows per recording/phase/policy.
#' @return List with estimates, contrasts, sign-stability flags, and provenance.
#' @export
aqt_compare_specifications <- function(data,group_col="recording",
    phase_col="phase",time_col="time_s",value_col="speed",
    track_col="track_id",eligible_col=NULL,policy_col=NULL,
    window_widths=c(1,3,6),reference_phase="Before",min_steps=3L) {
  if(!is.numeric(window_widths) || !length(window_widths) ||
     anyNA(window_widths) || any(!is.finite(window_widths)) ||
     any(window_widths<=0) || anyDuplicated(window_widths))
    stop("window_widths must contain distinct positive finite values",call.=FALSE)
  if(length(min_steps)!=1L || !is.finite(min_steps) || min_steps<1 ||
     min_steps!=floor(min_steps))
    stop("min_steps must be a positive integer",call.=FALSE)
  d <- .aqt_ev_clean(data,group_col,phase_col,time_col,value_col,
                     track_col,eligible_col,policy_col)
  if(!nrow(d))stop("No eligible finite movement steps",call.=FALSE)
  estimates <- list()
  for(ix in .aqt_ev_split(d,c("group","phase","policy"))) {
    z <- d[ix,,drop=FALSE]
    if(nrow(z)<min_steps)next
    key <- z[1,c("group","phase","policy"),drop=FALSE]
    tracks <- .aqt_ev_split(z,c("track"))
    fragment_medians <- vapply(tracks,function(j)
      stats::median(z$value[j]),numeric(1L))
    make <- function(method,width,estimate,n_units) {
      data.frame(group=key$group,phase=key$phase,policy=key$policy,
        method=method,window_width=width,estimate=estimate,
        n_steps=nrow(z),n_fragments=length(tracks),
        n_aggregation_units=as.integer(n_units),stringsAsFactors=FALSE)
    }
    estimates[[length(estimates)+1L]] <-
      make("pooled_steps",0,stats::median(z$value),nrow(z))
    estimates[[length(estimates)+1L]] <-
      make("fragment_equal",0,stats::median(fragment_medians),
           length(fragment_medians))
    for(w in window_widths) {
      bin <- floor(z$time/w)
      cell <- split(z$value,as.character(bin),drop=TRUE)
      vm <- vapply(cell,stats::median,numeric(1L))
      estimates[[length(estimates)+1L]] <-
        make("time_window_equal",w,stats::median(vm),length(vm))
    }
  }
  if(!length(estimates))stop("No group meets min_steps",call.=FALSE)
  est <- do.call(rbind,estimates);row.names(est)<-NULL
  ref <- est[est$phase==reference_phase,,drop=FALSE]
  if(!nrow(ref))stop("reference_phase not present among estimable groups",
                     call.=FALSE)
  other <- est[est$phase!=reference_phase,,drop=FALSE]
  by <- c("group","policy","method","window_width")
  contrasts <- merge(other,ref[,c(by,"estimate"),drop=FALSE],
    by=by,suffixes=c("","_reference"),sort=FALSE)
  if(nrow(contrasts)) {
    contrasts$reference_phase <- reference_phase
    contrasts$difference <- contrasts$estimate-contrasts$estimate_reference
    contrasts <- contrasts[,c("group","phase","policy","reference_phase",
      "method","window_width","difference","estimate",
      "estimate_reference","n_steps","n_fragments",
      "n_aggregation_units"),drop=FALSE]
  }
  flags <- list()
  if(nrow(contrasts)) {
    for(ix in .aqt_ev_split(contrasts,c("group","phase","policy"))) {
      z <- contrasts[ix,,drop=FALSE]
      signs <- unique(sign(z$difference[is.finite(z$difference)]))
      signs <- signs[signs!=0]
      flags[[length(flags)+1L]] <- data.frame(
        group=z$group[1],phase=z$phase[1],policy=z$policy[1],
        n_specifications=nrow(z),direction_reversal=length(signs)>1L,
        min_difference=min(z$difference),max_difference=max(z$difference),
        stringsAsFactors=FALSE)
    }
  }
  flag <- if(length(flags))do.call(rbind,flags) else data.frame()
  structure(list(estimates=est,contrasts=contrasts,stability=flag,
    units="source outcome units / declared source-time unit",
    statement="Descriptive comparisons only; not independent animal/tank effects.",
    data_sha256=unname(digest::digest(data,algo="sha256")),
    config=list(window_widths=window_widths,reference_phase=reference_phase,
      min_steps=min_steps,columns=c(group_col,phase_col,time_col,value_col,
                                   track_col,eligible_col,policy_col))),
    class="aqt_specification_audit")
}

#' Declare source-axis semantics without silently inferring physical coordinates
#'
#' @param axes Three-row data frame: axis (x/y/z), variable, unit, calibrated.
#' @param common_frame_verified Explicit verified common physical frame.
#' @param calibration_reference Independent calibration evidence identifier.
#' @return Contract whose physical_3d_eligible field is FALSE unless all
#'   three axes are calibrated, physical and share a verified frame.
#' @export
aqt_measurement_contract <- function(axes,common_frame_verified=FALSE,
                                     calibration_reference="") {
  .aqt_ev_cols(axes,c("axis","variable","unit","calibrated"))
  if(nrow(axes)!=3L || !setequal(as.character(axes$axis),c("x","y","z")) ||
     anyDuplicated(as.character(axes$axis)) ||
     anyDuplicated(as.character(axes$variable)))
    stop("axes must map unique x, y and z variables",call.=FALSE)
  axes <- axes[match(c("x","y","z"),as.character(axes$axis)),,drop=FALSE]
  axes$axis <- as.character(axes$axis)
  axes$variable <- as.character(axes$variable)
  axes$unit <- as.character(axes$unit)
  if(anyNA(axes) || any(!nzchar(axes$variable)) ||
     any(!axes$unit %in% c("px","mm","cm","m","source")) ||
     !is.logical(axes$calibrated) || anyNA(axes$calibrated))
    stop("Each axis needs a variable, supported unit and explicit calibration flag",
         call.=FALSE)
  if(!is.logical(common_frame_verified) ||
     length(common_frame_verified)!=1L || is.na(common_frame_verified))
    stop("common_frame_verified must be explicit TRUE or FALSE",call.=FALSE)
  if(!is.character(calibration_reference) ||
     length(calibration_reference)!=1L || is.na(calibration_reference))
    stop("calibration_reference must be a string",call.=FALSE)
  physical <- all(axes$unit %in% c("mm","cm","m")) &&
    all(axes$calibrated) && isTRUE(common_frame_verified) &&
    nzchar(calibration_reference)
  structure(list(axes=axes,physical_3d_eligible=physical,
     unit_homogeneity=length(unique(axes$unit))==1L,
     common_frame_verified=common_frame_verified,
     calibration_reference=calibration_reference,
     claim=if(physical) "Physical 3D eligible by researcher declaration; independently verify evidence" else
       "Three-variable display only; physical 3D velocity/distance prohibited",
     source_sha256=unname(digest::digest(axes,algo="sha256"))),
     class="aqt_measurement_contract")
}

#' Static three-axis observation plot, including explicitly mixed-unit axes
#'
#' This visualises three recorded variables; it does not calculate 3D speed.
#' @param data Source observations.
#' @param contract Output of aqt_measurement_contract().
#' @param max_points Maximum evenly indexed observations to display.
#' @return Selected row indices, invisibly.
#' @export
aqt_plot_source_3axis <- function(data,contract,max_points=4000L) {
  if(!inherits(contract,"aqt_measurement_contract"))
    stop("Explicit measurement contract required",call.=FALSE)
  nm <- contract$axes$variable
  .aqt_ev_cols(data,nm)
  v <- lapply(nm,function(k) as.numeric(data[[k]]))
  good <- which(stats::complete.cases(as.data.frame(v)))
  if(!length(good))stop("No complete three-axis observations",call.=FALSE)
  if(!is.numeric(max_points)||length(max_points)!=1L||
     !is.finite(max_points)||max_points<1)
    stop("max_points must be positive",call.=FALSE)
  if(length(good)>max_points)
    good <- good[unique(round(seq(1,length(good),length.out=max_points)))]
  xyz <- lapply(v,function(z) z[good])
  span <- lapply(xyz,function(z) {
    r <- range(z)
    if(diff(r)==0)r+c(-.5,.5) else r
  })
  pmat <- graphics::persp(x=span[[1]],y=span[[2]],
    z=matrix(0,2L,2L),theta=38,phi=24,expand=.7,
    xlab=paste0(contract$axes$axis[1]," (",contract$axes$unit[1],")"),
    ylab=paste0(contract$axes$axis[2]," (",contract$axes$unit[2],")"),
    zlab=paste0(contract$axes$axis[3]," (",contract$axes$unit[3],")"),
    ticktype="detailed")
  t <- grDevices::trans3d(xyz[[1]],xyz[[2]],xyz[[3]],pmat)
  graphics::points(t$x,t$y,pch=16,cex=.32,col=grDevices::adjustcolor(
    "#24639B",alpha.f=.55))
  graphics::mtext(if(contract$physical_3d_eligible)
    "Declared calibrated 3D positions" else
    "Mixed/source axes: visualization only, NOT metric 3D",side=3,line=.2,cex=.8)
  invisible(good)
}

#' Audit observational versus independent experimental units
#'
#' @param data Observation data with recording and optional independent unit IDs.
#' @param recording_col Source recording identifier column.
#' @param animal_col Optional verified-animal identifier column.
#' @param tank_col Optional experimental tank identifier column.
#' @param treatment_col Optional treatment allocation column.
#' @param animal_ids_verified,tanks_independent_verified,randomization_verified
#'   Explicit scientific evidence declarations, never inferred from ID counts.
#' @param min_tanks_per_arm Minimum independently verified tanks per arm.
#' @return Conservative inference-readiness status without causal certification.
#' @export
aqt_inference_readiness <- function(data,recording_col="recording",
   animal_col=NULL,tank_col=NULL,treatment_col=NULL,
   animal_ids_verified=FALSE,tanks_independent_verified=FALSE,
   randomization_verified=FALSE,min_tanks_per_arm=2L) {
  .aqt_ev_cols(data,c(recording_col,animal_col,tank_col,treatment_col))
  for(flag in list(animal_ids_verified,tanks_independent_verified,
                   randomization_verified))
    if(!is.logical(flag)||length(flag)!=1L||is.na(flag))
      stop("Verification declarations must be explicit TRUE or FALSE",call.=FALSE)
  rec <- unique(as.character(data[[recording_col]]))
  n_animals <- if(!is.null(animal_col)) length(unique(
    as.character(data[[animal_col]]))) else NA_integer_
  arm <- data.frame()
  experimental <- FALSE
  if(!is.null(tank_col) && !is.null(treatment_col)) {
    x <- data.frame(tank=as.character(data[[tank_col]]),
                    arm=as.character(data[[treatment_col]]))
    x <- unique(x[stats::complete.cases(x),,drop=FALSE])
    if(anyDuplicated(x$tank))
      stop("One tank cannot be assigned to multiple treatments",call.=FALSE)
    arm <- as.data.frame(table(x$arm),stringsAsFactors=FALSE)
    names(arm) <- c("treatment","n_tanks")
    experimental <- tanks_independent_verified &&
      nrow(arm)>=2L && all(arm$n_tanks>=min_tanks_per_arm)
  }
  structure(list(n_observations=nrow(data),n_recordings=length(rec),
    n_recorded_animal_ids=n_animals,
    animal_level_eligible=animal_ids_verified && !is.null(animal_col),
    experimental_contrast_eligible=experimental,
    randomized_allocation_declared=randomization_verified,
    causal_effect_certified=FALSE,
    arm_counts=arm,
    supported_claim=if(experimental)
      "Independent-tank association estimable; causal identification not certified"
      else if(animal_ids_verified && !is.null(animal_col))
      "Animal-level descriptive/associational analysis only"
      else "Recording-level descriptive analysis only; no independent fish/tank inference",
    data_sha256=unname(digest::digest(data,algo="sha256"))),
    class="aqt_inference_readiness")
}

.aqt_ev_js <- function(p,q) {
  m <- (p+q)/2
  kl <- function(x,y) sum(x[x>0]*log(x[x>0]/y[x>0]))
  (kl(p,m)+kl(q,m))/2
}
.aqt_ev_entropy <- function(p) {
  if(length(p)<2L)return(NA_real_)
  -sum(p[p>0]*log(p[p>0]))/log(length(p))
}

#' Compare spatial occupancy with explicit equal-window coverage checks
#'
#' @param data Data frame of positions, time and recording/phase identifiers.
#' @param group_col,phase_col,time_col,x_col,y_col Source column names.
#' @param window_width Positive source-time window width.
#' @param grid Integer pair giving common x/y grid dimensions per recording.
#' @param min_points_per_window,min_windows Minimum required support.
#' @return Spatial summary and Jensen-Shannon comparisons, marked unsupported
#'   wherever the minimum support is not met. No fish-level inference.
#' @export
aqt_spatial_support <- function(data,group_col="recording",phase_col="phase",
    time_col="time_s",x_col="x",y_col="y",window_width=3,grid=c(8L,8L),
    min_points_per_window=10L,min_windows=3L) {
  .aqt_ev_cols(data,c(group_col,phase_col,time_col,x_col,y_col))
  if(!is.numeric(grid)||length(grid)!=2L||any(grid<2)||
     any(grid!=floor(grid))||any(!is.finite(grid))||
     !is.numeric(window_width)||length(window_width)!=1L||
     !is.finite(window_width)||window_width<=0)
    stop("Positive window_width and integer grid dimensions >=2 required",
         call.=FALSE)
  if(any(c(min_points_per_window,min_windows)<1) ||
     any(!is.finite(c(min_points_per_window,min_windows))))
    stop("Minimum support thresholds must be positive",call.=FALSE)
  d <- data.frame(group=as.character(data[[group_col]]),
    phase=as.character(data[[phase_col]]),time=as.numeric(data[[time_col]]),
    x=as.numeric(data[[x_col]]),y=as.numeric(data[[y_col]]))
  d <- d[stats::complete.cases(d),,drop=FALSE]
  if(!nrow(d))stop("No finite positions",call.=FALSE)
  summary <- list();prob <- list()
  ncell <- prod(grid)
  for(g in unique(d$group)) {
    gd <- d[d$group==g,,drop=FALSE]
    xr <- range(gd$x);yr <- range(gd$y)
    if(diff(xr)==0)xr <- xr+c(-.5,.5)
    if(diff(yr)==0)yr <- yr+c(-.5,.5)
    ix <- pmin(grid[1],pmax(1L,floor((gd$x-xr[1])/
                         diff(xr)*grid[1])+1L))
    iy <- pmin(grid[2],pmax(1L,floor((gd$y-yr[1])/
                         diff(yr)*grid[2])+1L))
    gd$cell <- as.integer((iy-1L)*grid[1]+ix)
    gd$bin <- floor(gd$time/window_width)
    for(ph in unique(gd$phase)) {
      z <- gd[gd$phase==ph,,drop=FALSE]
      wins <- split(z$cell,as.character(z$bin),drop=TRUE)
      valid <- Filter(function(v) length(v)>=min_points_per_window,wins)
      nwin <- length(valid)
      supported <- nwin>=min_windows
      p <- if(nwin) {
        mats <- vapply(valid,function(v)
          tabulate(v,nbins=ncell)/length(v),numeric(ncell))
        rowMeans(matrix(mats,nrow=ncell))
      } else rep(NA_real_,ncell)
      key <- paste(g,ph,sep="\r")
      prob[[key]] <- if(supported) p else rep(NA_real_,ncell)
      summary[[length(summary)+1L]] <- data.frame(group=g,phase=ph,
        n_positions=nrow(z),n_windows=length(wins),
        n_supported_windows=nwin,
        min_window_positions=if(length(wins)) min(lengths(wins)) else 0L,
        supported=supported,
        normalized_entropy=if(supported) .aqt_ev_entropy(p) else NA_real_,
        grid_x=grid[1],grid_y=grid[2],
        stringsAsFactors=FALSE)
    }
  }
  sums <- do.call(rbind,summary);row.names(sums)<-NULL
  pairs <- list()
  for(g in unique(sums$group)) {
    ph <- sums$phase[sums$group==g]
    if(length(ph)<2)next
    for(pair in utils::combn(ph,2,simplify=FALSE)) {
      p <- prob[[paste(g,pair[1],sep="\r")]]
      q <- prob[[paste(g,pair[2],sep="\r")]]
      pairs[[length(pairs)+1L]] <- data.frame(group=g,
        phase_a=pair[1],phase_b=pair[2],
        supported=all(is.finite(c(p,q))),
        js_divergence=if(all(is.finite(c(p,q)))) .aqt_ev_js(p,q) else NA_real_)
    }
  }
  structure(list(summary=sums,comparisons=if(length(pairs))
    do.call(rbind,pairs) else data.frame(),probabilities=prob,
    thresholds=list(window_width=window_width,grid=grid,
      min_points_per_window=min_points_per_window,min_windows=min_windows),
    claim="Spatial distribution of detected positions; not animal occupancy"),
    class="aqt_spatial_support")
}

#' Diagnose camera-geometry association and common-support exclusions
#'
#' @param data Source step table.
#' @param group_col,phase_col,speed_col,area_col Column names.
#' @param reference_phase Phase defining the reference comparison.
#' @param n_strata Number of pooled bounding-box-area quantile strata.
#' @param min_per_stratum Minimum observations per phase in an overlap stratum.
#' @return Descriptive Spearman correlations and overlap coverage diagnostics.
#' @export
aqt_geometry_bias_audit <- function(data,group_col="recording",
    phase_col="phase",speed_col="speed",area_col="bbox_area",
    reference_phase="Before",n_strata=5L,min_per_stratum=10L) {
  .aqt_ev_cols(data,c(group_col,phase_col,speed_col,area_col))
  if(length(n_strata)!=1L || n_strata<2 || n_strata!=floor(n_strata) ||
     length(min_per_stratum)!=1L || min_per_stratum<1)
    stop("Invalid stratum settings",call.=FALSE)
  d <- data.frame(group=as.character(data[[group_col]]),
    phase=as.character(data[[phase_col]]),
    speed=as.numeric(data[[speed_col]]),
    area=as.numeric(data[[area_col]]))
  d <- d[stats::complete.cases(d) & d$area>0,,drop=FALSE]
  if(!nrow(d))stop("No valid speed/bounding-box observations",call.=FALSE)
  corrs <- lapply(.aqt_ev_split(d,c("group","phase")),function(ix) {
    z <- d[ix,,drop=FALSE]
    data.frame(group=z$group[1],phase=z$phase[1],n=nrow(z),
      spearman_rho=if(nrow(z)>2 && length(unique(z$area))>1 &&
              length(unique(z$speed))>1)
        suppressWarnings(stats::cor(z$speed,z$area,method="spearman"))
      else NA_real_)
  })
  overlap <- list()
  for(g in unique(d$group)) {
    z <- d[d$group==g,,drop=FALSE]
    cuts <- unique(as.numeric(stats::quantile(z$area,
                              probs=seq(0,1,length.out=n_strata+1L))))
    if(length(cuts)<3)next
    z$stratum <- cut(z$area,breaks=cuts,include.lowest=TRUE,labels=FALSE)
    a <- z[z$phase==reference_phase,,drop=FALSE]
    if(!nrow(a))next
    for(ph in setdiff(unique(z$phase),reference_phase)) {
      b <- z[z$phase==ph,,drop=FALSE]
      ca <- tabulate(a$stratum,nbins=length(cuts)-1L)
      cb <- tabulate(b$stratum,nbins=length(cuts)-1L)
      valid <- which(ca>=min_per_stratum & cb>=min_per_stratum)
      overlap[[length(overlap)+1L]] <- data.frame(group=g,phase=ph,
        reference_phase=reference_phase,n_strata=length(cuts)-1L,
        n_common_strata=length(valid),reference_coverage=
          if(nrow(a))sum(ca[valid])/nrow(a) else NA_real_,
        comparison_coverage=if(nrow(b))sum(cb[valid])/nrow(b) else NA_real_,
        coverage_ok=length(valid)>0L &&
          sum(ca[valid])/nrow(a)>=.8 && sum(cb[valid])/nrow(b)>=.8)
    }
  }
  structure(list(correlations=do.call(rbind,corrs),
    overlap=if(length(overlap))do.call(rbind,overlap) else data.frame(),
    claim="Descriptive association and overlap only; not causal adjustment"),
    class="aqt_geometry_bias_audit")
}

#' Construct within-recording placebo boundaries, without pseudo-p-values
#'
#' @param data Source movement table.
#' @param group_col,phase_col,time_col,value_col Column names.
#' @param window_width Positive source-time bin width.
#' @param min_windows_per_side Minimum valid windows on each side of a cut.
#' @return Eligible within-file cut contrasts, not an independent null sample.
#' @export
aqt_placebo_boundaries <- function(data,group_col="recording",
    phase_col="phase",time_col="time_s",value_col="speed",
    window_width=3,min_windows_per_side=3L) {
  .aqt_ev_cols(data,c(group_col,phase_col,time_col,value_col))
  if(!is.numeric(window_width)||length(window_width)!=1L||
     !is.finite(window_width)||window_width<=0 ||
     min_windows_per_side<2)
    stop("Invalid window or minimum-side specification",call.=FALSE)
  d <- data.frame(group=as.character(data[[group_col]]),
    phase=as.character(data[[phase_col]]),
    time=as.numeric(data[[time_col]]),
    value=as.numeric(data[[value_col]]))
  d <- d[stats::complete.cases(d),,drop=FALSE]
  out <- list()
  for(ix in .aqt_ev_split(d,c("group","phase"))) {
    z <- d[ix,,drop=FALSE]
    bins <- split(z$value,as.character(floor(z$time/window_width)))
    tt <- as.numeric(names(bins))
    vals <- vapply(bins,stats::median,numeric(1L))
    vals <- vals[order(tt)]
    n <- length(vals)
    if(n<2L*min_windows_per_side)next
    for(k in seq.int(min_windows_per_side,n-min_windows_per_side)) {
      out[[length(out)+1L]] <- data.frame(
        group=z$group[1],phase=z$phase[1],cut_after_window=k,
        n_left=k,n_right=n-k,
        difference=stats::median(vals[(k+1L):n])-
                   stats::median(vals[seq_len(k)]))
    }
  }
  structure(list(cuts=if(length(out))do.call(rbind,out) else data.frame(),
    warning="Placebo cuts are dependent within-file diagnostics; their fractions are not p-values.",
    window_width=window_width),class="aqt_placebo_boundaries")
}

#' Assemble a claim-limited, machine-readable scientific evidence summary
#'
#' @param specification Output of aqt_compare_specifications().
#' @param readiness Output of aqt_inference_readiness().
#' @param measurement Optional measurement contract.
#' @param spatial Optional spatial-support audit.
#' @param geometry Optional camera-geometry audit.
#' @param placebo Optional within-file placebo audit.
#' @return Structured evidence report and dynamically derived statements.
#' @export
aqt_evidence_report <- function(specification,readiness,measurement=NULL,
                                spatial=NULL,geometry=NULL,placebo=NULL) {
  if(!inherits(specification,"aqt_specification_audit") ||
     !inherits(readiness,"aqt_inference_readiness"))
    stop("Specification and inference-readiness audits are required",call.=FALSE)
  types <- list(measurement="aqt_measurement_contract",
    spatial="aqt_spatial_support",geometry="aqt_geometry_bias_audit",
    placebo="aqt_placebo_boundaries")
  supplied <- list(measurement=measurement,spatial=spatial,
                   geometry=geometry,placebo=placebo)
  for(nm in names(supplied))if(!is.null(supplied[[nm]]) &&
     !inherits(supplied[[nm]],types[[nm]]))
    stop("Invalid evidence object: ",nm,call.=FALSE)
  reversal <- nrow(specification$stability)>0 &&
    any(specification$stability$direction_reversal)
  unsupported <- !is.null(spatial) && any(!spatial$summary$supported)
  limited_overlap <- !is.null(geometry) && nrow(geometry$overlap)>0 &&
    any(!geometry$overlap$coverage_ok)
  statements <- c(
    if(reversal)
      "At least one descriptive phase contrast changes direction across admissible aggregation specifications."
    else "No direction reversal was detected across the supplied specifications; this is not proof of causal robustness.",
    if(readiness$experimental_contrast_eligible)
      "Independent-tank association is eligible by explicit design declaration; causal identification remains unverified."
    else "Independent-tank experimental contrasts are not supported by the supplied design evidence.",
    if(!is.null(measurement) && !measurement$physical_3d_eligible)
      "Three-axis source displays must not be interpreted as physical 3D motion.",
    if(unsupported)
      "Some spatial comparisons lack the declared minimum time-window support.",
    if(limited_overlap)
      "Some geometry-stratified comparisons lack adequate common support.",
    if(!is.null(placebo))
      "Within-recording placebo cuts are descriptive falsification diagnostics, not hypothesis-test p-values.")
  status <- data.frame(check=c("direction_stability","experimental_replication",
    "physical_3d","spatial_support","geometry_overlap","placebo_boundary"),
    status=c(if(reversal)"sensitive" else "no_reversal_detected",
      if(readiness$experimental_contrast_eligible)"eligible_association" else "blocked",
      if(is.null(measurement))"not_assessed" else if(measurement$physical_3d_eligible)
        "declared_eligible" else "blocked",
      if(is.null(spatial))"not_assessed" else if(unsupported)"limited" else "supported",
      if(is.null(geometry))"not_assessed" else if(limited_overlap)"limited" else "supported",
      if(is.null(placebo))"not_assessed" else "descriptive_only"),
    stringsAsFactors=FALSE)
  structure(list(status=status,statements=statements,
    specification=specification,readiness=readiness,
    measurement=measurement,spatial=spatial,geometry=geometry,
    placebo=placebo,schema="AQT_EVIDENCE_GUARDS_V1"),
    class="aqt_evidence_report")
}

#' Export a sealed evidence report with tables, figure and SHA-256 ledger
#'
#' @param report Output of aqt_evidence_report().
#' @param directory Fresh output directory; overwrite is prohibited.
#' @return New directory, invisibly. No source input is modified.
#' @export
aqt_evidence_export <- function(report,directory) {
  if(!inherits(report,"aqt_evidence_report"))
    stop("Expected an aqt_evidence_report",call.=FALSE)
  if(!is.character(directory)||length(directory)!=1L||
     is.na(directory)||!nzchar(directory)||dir.exists(directory)||
     file.exists(directory) || !dir.exists(dirname(directory)))
    stop("Select a new output directory under an existing parent",call.=FALSE)
  before <- unname(digest::digest(report,algo="sha256"))
  dir.create(directory,recursive=FALSE)
  save <- function(name,d) {
    if(is.data.frame(d)&&ncol(d))
      utils::write.csv(d,file.path(directory,paste0(name,".csv")),
                       row.names=FALSE,na="")
  }
  save("evidence_status",report$status)
  save("specification_estimates",report$specification$estimates)
  save("specification_contrasts",report$specification$contrasts)
  save("direction_stability",report$specification$stability)
  save("experimental_units",report$readiness$arm_counts)
  if(!is.null(report$spatial)) {
    save("spatial_support",report$spatial$summary)
    save("spatial_comparisons",report$spatial$comparisons)
  }
  if(!is.null(report$geometry)) {
    save("geometry_correlations",report$geometry$correlations)
    save("geometry_overlap",report$geometry$overlap)
  }
  if(!is.null(report$placebo))
    save("within_recording_placebos",report$placebo$cuts)
  out <- c("# Trajectory evidence assessment","",
    "Descriptive, source-linked diagnostic reporting. Not fish-level or causal validation.",
    "",paste0("- ",report$statements),"",
    paste0("Input specification SHA-256: ",report$specification$data_sha256),
    paste0("Input readiness SHA-256: ",report$readiness$data_sha256))
  writeLines(out,file.path(directory,"evidence_readme.md"),useBytes=TRUE)
  if(nrow(report$specification$contrasts)) {
    grDevices::png(file.path(directory,"specification_contrasts.png"),
                   width=1300,height=800,res=150)
    tryCatch({
      z <- report$specification$contrasts
      zz <- z[order(z$group,z$phase,z$policy,z$method,z$window_width),]
      lim <- range(c(0,zz$difference),finite=TRUE)
      graphics::plot(seq_len(nrow(zz)),zz$difference,
        pch=16,cex=.7,ylim=lim,xlab="Specification index",
        ylab="Difference from declared reference (source units)",
        main="Estimator and weighting sensitivity")
      graphics::abline(h=0,lty=2)
    },finally=grDevices::dev.off())
  }
  if(!identical(before,unname(digest::digest(report,algo="sha256"))))
    stop("Evidence report changed during export",call.=FALSE)
  paths <- list.files(directory,full.names=TRUE,recursive=TRUE)
  if(any(basename(paths)=="sha256_manifest.csv"))
    stop("Manifest collision",call.=FALSE)
  ledger <- data.frame(file=basename(paths),
    sha256=vapply(paths,function(p)unname(digest::digest(
      file=p,algo="sha256")),character(1L)),
    stringsAsFactors=FALSE)
  utils::write.csv(ledger,file.path(directory,"sha256_manifest.csv"),
                   row.names=FALSE)
  invisible(directory)
}
