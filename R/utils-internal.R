protegr2_badge_dependency <- function() {
  css_path <- system.file("www/pr2-badge.css", package = "protegR2")
  mtime    <- as.integer(file.info(css_path)$mtime)
  version  <- paste0(utils::packageVersion("protegR2"), ".", mtime)

  htmltools::htmlDependency(
    name       = "protegR2-badge",
    version    = version,
    src        = system.file("www", package = "protegR2"),
    script     = "pr2-badge.js",
    stylesheet = "pr2-badge.css"
  )
}
