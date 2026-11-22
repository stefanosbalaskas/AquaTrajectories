# Test seam for optional package-availability failure injection.
# A non-function binding is skipped during ordinary R function lookup,
# so production calls continue to use base::requireNamespace unchanged.
# testthat::local_mocked_bindings() temporarily substitutes this package-local
# binding and restores it automatically. It never changes loaded libraries,
# installed packages, science data, or the coverage gate.
requireNamespace <- NULL

# These non-function bindings likewise leave ordinary production lookup
# unchanged. Tests can locally simulate directory creation, copying and
# atomic rename failures without altering OS permissions or global base APIs.
dir.create <- NULL
file.rename <- NULL
file.copy <- NULL

# Missing output-files can be modelled deterministically within only our
# package namespace, rather than deleting source files or overriding base.
file.exists <- NULL

# Additional test-only namespace seams for SVG header reads, public
# namespace inventory and failed file-metadata reads; base R remains normal.
readLines <- NULL
getNamespaceExports <- NULL
file.info <- NULL
