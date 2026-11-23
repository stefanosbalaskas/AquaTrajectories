# Test-only internal numerical failure channels. None of the
# injected matrices or algorithms is presented as empirical fish evidence.
test_that("DLT refuses zero-depth projective solutions",{
 P1 <- cbind(diag(3),c(0,0,0))
 P2 <- cbind(diag(3),c(-2,0,0))
 testthat::with_mocked_bindings({
   result <- aqt_triangulate_pairs(matrix(c(0,0),ncol=2),
         matrix(c(-.4,0),ncol=2),P1,P2)
   expect_false(result$valid[1L])
   expect_true(all(is.na(result[1L,c("x","y","z")])))
 },svd=function(a) list(d=c(1,1,1,0),v=diag(4)),
   .package="aquaTrajectories")
})

test_that("identity Hungarian solver reports corrupt internal assignment costs",{
 mock_max <- function(...) {
   args <- list(...)
   if(length(args)==1L && is.matrix(args[[1L]])) return(Inf)
   base::max(...)
 }
 testthat::with_mocked_bindings({
   expect_error(aquaTrajectories:::.aqt_max_assignment(
       matrix(c(2,1,1,2),ncol=2)),
       "Assignment failed")
 },max=mock_max,.package="aquaTrajectories")
})
