# Mathematical simulation source must never be described as fish biology.
test_that("synthetic generator enforces bounds and restores the global RNG exactly",{
 for (x in list(0,NA_real_,2.5,c(1,2))) {
   expect_error(aqt_simulate_tracks(n_fish=x),"Invalid simulator configuration")
 }
 for (x in list(1,NA_real_,2.5,c(1,3))) {
   expect_error(aqt_simulate_tracks(n_frames=x),"Invalid simulator configuration")
 }
 for (x in list(0,-1,Inf,NA_real_)) {
   expect_error(aqt_simulate_tracks(fps=x),"Invalid simulator configuration")
 }
 for (x in list(1,4,NA_integer_,c(2,3))) {
   expect_error(aqt_simulate_tracks(dimension=x),"Invalid simulator configuration")
 }
 set.seed(41)
 old <- .Random.seed
 a <- aqt_simulate_tracks(n_fish=1,n_frames=2,dimension=3,seed=100)
 expect_identical(.Random.seed,old)
 b <- aqt_simulate_tracks(n_fish=1,n_frames=2,dimension=3,seed=100)
 expect_identical(as.data.frame(a),as.data.frame(b))
 expect_equal(nrow(a),2L)
 expect_equal(attr(a,"aqt_dimension"),3L)
 expect_equal(attr(a,"aqt_units"),"cm")
 expect_identical(unique(a$track_id),"fish1")
 had <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
 if(had) prior <- get(".Random.seed",envir=.GlobalEnv)
 on.exit({
   if(had)assign(".Random.seed",prior,envir=.GlobalEnv)
   else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
     rm(".Random.seed",envir=.GlobalEnv)
 },add=TRUE)
 if(had)rm(".Random.seed",envir=.GlobalEnv)
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
 zero_seed <- aqt_simulate_tracks(n_fish=2,n_frames=3,seed=7)
 expect_s3_class(zero_seed,"aqt_tracks")
 expect_false(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))
 expect_false(anyNA(zero_seed$time_s))
})
