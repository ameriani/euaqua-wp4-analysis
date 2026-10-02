# Shared EUAqua chart style. These are provisional visual approximations,
# not verified official brand colour codes. Keep palette changes in this file.
euaqua_palette <- c(
  blue = "#246DB5",
  green = "#83B829",
  light_blue = "#5598CF"
)
euaqua_neutrals <- c(text = "#263238", grid = "#E7ECEF", background = "#FFFFFF")

# Resolve installed fonts explicitly instead of relying on silent device fallback.
# Export with ragg so chart text uses the same systemfonts resolution.
euaqua_font_report <- function() {
  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    stop("Package systemfonts is required to verify chart fonts.")
  }
  families <- unique(systemfonts::system_fonts()$family)
  priority <- c("Montserrat", "Calibri", "Arial", "Helvetica")
  present <- priority[tolower(priority) %in% tolower(families)]
  requested <- if (length(present)) families[match(tolower(present[1L]), tolower(families))] else "sans"
  regular <- systemfonts::match_fonts(requested)
  bold <- systemfonts::match_fonts(requested, weight = "bold")
  actual <- systemfonts::font_info(path = regular$path, index = regular$index)$family[1L]
  actual_bold <- systemfonts::font_info(path = bold$path, index = bold$index)$family[1L]
  data.frame(
    Preferred_font = "Montserrat", Preferred_font_available = "montserrat" %in% tolower(families),
    First_fallback = "Calibri", First_fallback_available = "calibri" %in% tolower(families),
    Requested_family = requested, Resolved_regular_family = actual,
    Resolved_bold_family = actual_bold,
    Further_fallback = !tolower(actual) %in% c("montserrat", "calibri"),
    Renderer = "ragg PNG / systemfonts", stringsAsFactors = FALSE
  )
}

theme_euaqua <- function(base_size = 12, base_family = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Package ggplot2 is required.")
  if (is.null(base_family)) base_family <- euaqua_font_report()$Resolved_regular_family
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      text = ggplot2::element_text(family = base_family, colour = euaqua_neutrals[["text"]]),
      plot.background = ggplot2::element_rect(fill = euaqua_neutrals[["background"]], colour = NA),
      panel.background = ggplot2::element_rect(fill = euaqua_neutrals[["background"]], colour = NA),
      panel.grid.major.x = ggplot2::element_line(colour = euaqua_neutrals[["grid"]], linewidth = 0.35),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(colour = euaqua_neutrals[["text"]]),
      axis.title = ggplot2::element_text(colour = euaqua_neutrals[["text"]]),
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 4, margin = ggplot2::margin(b = 8)),
      plot.subtitle = ggplot2::element_text(size = base_size, margin = ggplot2::margin(b = 15)),
      plot.caption = ggplot2::element_text(size = base_size - 2, hjust = 0, margin = ggplot2::margin(t = 15)),
      plot.title.position = "plot", plot.caption.position = "plot",
      plot.margin = ggplot2::margin(20, 28, 18, 20),
      legend.background = ggplot2::element_rect(fill = euaqua_neutrals[["background"]], colour = NA)
    )
}
