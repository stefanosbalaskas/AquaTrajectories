# Fail closed when a public function lacks a categorized reference entry.
stopifnot(file.exists("NAMESPACE"), file.exists("_pkgdown.yml"))
if (!requireNamespace("yaml", quietly = TRUE)) stop("Install package 'yaml'")
ns <- readLines("NAMESPACE", warn = FALSE)
api <- sub("^export\\(([^)]*)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))
cfg <- yaml::read_yaml("_pkgdown.yml")
"%||%" <- function(x, y) if (is.null(x)) y else x
grouped <- unlist(lapply(cfg$reference, function(x) x$contents %||% character()), use.names = FALSE)
if (length(api) != 155L) stop("Expected 155 exported functions; actual: ", length(api))
if (anyDuplicated(grouped)) stop("Duplicate function assignments: ", paste(unique(grouped[duplicated(grouped)]), collapse=", "))
if (!setequal(api, grouped)) {
  stop("Missing functions: ", paste(setdiff(api, grouped), collapse=", "),
       "; extra entries: ", paste(setdiff(grouped, api), collapse=", "))
}
missing_rd <- api[!file.exists(file.path("man", paste0(api, ".Rd")))]
if (length(missing_rd)) stop("Missing Rd files: ", paste(missing_rd,collapse=", "))
article_names <- unlist(lapply(cfg$articles, function(x) x$contents), use.names = FALSE)
article_files <- file.path("vignettes", "articles", paste0(article_names, ".Rmd"))
if (anyDuplicated(article_names) || any(!file.exists(article_files))) stop("Articles missing or duplicated")
atlas <- paste(readLines("vignettes/articles/function-atlas.Rmd",warn=FALSE),collapse="\n")
missing_atlas <- api[!vapply(api, function(f) grepl(paste0("../reference/", f, ".html"),atlas,fixed=TRUE),logical(1))]
if(length(missing_atlas)) stop("Function atlas missing links: ",paste(missing_atlas,collapse=", "))
message("PKGDOWN_REFERENCE_AUDIT_PASS: ", length(api), " exports; ",
        sum(vapply(cfg$reference, function(x) !is.null(x$contents), logical(1))),
        " distinct groups; ", length(article_names), " articles")

required_images <- c("hero-science","workflow","multiview","uncertainty",
  "tank-design","behaviour","aci","validation")
image_paths <- file.path("pkgdown","assets",paste0(required_images,".svg"))
if (any(!file.exists(image_paths))) stop("Missing website SVG visuals")
if (!file.exists("pkgdown/index.md") || !file.exists("pkgdown/extra.css")) stop("Missing homepage or theme")
message("PKGDOWN_ASSET_AUDIT_PASS: 8 SVGs, homepage, theme, and articles present")
