# Source-unit longitudinal design is meaningful only for complete,
# equally spaced within-fish curves and one session/event per tank.
test_that("strict functional longitudinal preparation rejects nonfinite grids before fitting",{
 g <- .cov100_func_grid()
 bad <- g
 bad$time_relative_s[1] <- Inf
 expect_error(aqt_functional_longitudinal_prepare(bad),
              "Functional model time grid must be finite")
})
test_that("two complete fish sessions may not masquerade as one independently treated tank",{
 g <- .cov100_func_grid()
 bad <- g
 bad$session_id[bad$tank_id=="C1" & bad$track_id=="F2"] <- "UNRELATED_SESSION"
 expect_error(aqt_functional_longitudinal_prepare(bad),
              "Each independently treated tank requires one session and event")
})
