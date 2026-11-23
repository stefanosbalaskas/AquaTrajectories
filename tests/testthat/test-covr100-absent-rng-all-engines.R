# Four independently seeded research engines must not create a persistent
# global random state when the caller had no .Random.seed. All source data
# here are synthetic; no treatment causality or posterior calibration.
test_that("tank, functional, identity and optical scenario RNGs preserve absent caller state",{
 had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
 if(had) old <- get(".Random.seed",envir=.GlobalEnv)
 on.exit({
   if(had) assign(".Random.seed",old,envir=.GlobalEnv)
   else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
     rm(".Random.seed",envir=.GlobalEnv)
 },add=TRUE)
 if(had) rm(".Random.seed",envir=.GlobalEnv)
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))

 epoch <- expand.grid(tank_id=c("C1","C2","T1","T2"),
        epoch=c("baseline","response"),KEEP.OUT.ATTRS=FALSE)
 epoch$treatment <- ifelse(substr(epoch$tank_id,1,1)=="C",
                         "control","treatment")
 epoch$value <- ifelse(epoch$epoch=="baseline",1,2) +
                ifelse(epoch$treatment=="treatment",.2,0)
 tc <- aqt_tank_event_contrast(epoch,draws=100L,seed=12L)
 expect_true(is.finite(tc$estimate))
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))

 grid <- expand.grid(tank_id=c("C1","C2","T1","T2"),
                     time_relative_s=c(-1,0,1),
                     KEEP.OUT.ATTRS=FALSE)
 grid$session_id <- grid$tank_id
 grid$camera_id <- "C"
 grid$track_id <- "F"
 grid$event_id <- "E"
 grid$treatment <- ifelse(substr(grid$tank_id,1,1)=="C",
                         "control","treatment")
 grid$value <- grid$time_relative_s+
               ifelse(grid$treatment=="treatment",.2,0)
 grid$supported <- TRUE
 class(grid) <- c("aqt_functional_event_grid","data.frame")
 fc <- aqt_functional_tank_contrast(grid,draws=100L,seed=15L)
 expect_true(is.data.frame(fc$curve))
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))

 tr <- aqt_tracks(data.frame(session_id="S",camera_id="C",
       track_id=rep(c("F1","F2"),each=3),time_s=rep(0:2,2),
       x=c(0:2,3:5),y=c(0,0,0,2,2,2),observed=TRUE))
 e <- data.frame(session_id="S",camera_id="C",track_a="F1",
                 track_b="F2",at_s=1,probability_swap=.5)
 id <- aqt_identity_switch_scenarios(tr,e,draws=2L,seed=17L)
 expect_equal(nrow(id$decisions),2L)
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))

 a <- aqt_tracks(data.frame(session_id="S",camera_id="A",
       track_id="a",time_s=0:2,x=rep(0,3),y=0))
 b <- aqt_tracks(data.frame(session_id="S",camera_id="B",
       track_id="b",time_s=0:2,x=rep(-.4,3),y=0))
 cam <- function(x) aqt_flatport_camera(diag(3),diag(3),
       center=c(x,0,0),glass_front_point=c(0,0,1),
       glass_normal=c(0,0,1),glass_thickness=.1,
       n_first=1,n_glass=1,n_water=1,units="cm")
 pair <- data.frame(session_id="S",id_a="a",id_b="b",
       time_a_s=0:2,time_b_s=0:2,fish_id="F")
 scenarios <- aqt_joint_refractive_scenarios(a,b,pair,
          cam(0),cam(2),draws=10L,seed=19L)
 expect_equal(length(scenarios$tracks),10L)
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
 expect_false(scenarios$assumptions$probabilities_calibrated)
});
