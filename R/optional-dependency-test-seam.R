# Test seam for optional package-availability failure injection.
# A non-function binding is skipped during ordinary R function lookup,
# so production calls continue to use base::requireNamespace unchanged.
# testthat::local_mocked_bindings() temporarily substitutes this package-local
# binding and restores it automatically. It never changes loaded libraries,
# installed packages, science data, or the coverage gate.
requireNamespace <- NULL
