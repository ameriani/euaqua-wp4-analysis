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

# Reusable count chart with all options in questionnaire order, including zeros.
# Labels can be wrapped for long options; underlying English labels stay intact.
euaqua_frequency_plot <- function(frequency_table, summary, title, subtitle,
                                 font_family = NULL, wrap_width = 48L) {
  if (is.null(font_family)) font_family <- euaqua_font_report()$Resolved_regular_family
  plot_data <- frequency_table
  plot_data$Annotation <- if (summary$Valid_mapped_responses > 0L)
    sprintf("%d (%.1f%%)", plot_data$Count, plot_data$Percent_of_valid_responses) else
      sprintf("%d (n/a)", plot_data$Count)
  wrap <- function(x) vapply(x, function(label) paste(strwrap(label, width = wrap_width), collapse = "\n"), "")
  caption <- sprintf(
    paste0("Pilot sample only. Percentages use valid mapped responses (n = %d).\n",
           "Total = %d; valid = %d; missing = %d; unmapped = %d."),
    summary$Percent_denominator, summary$Total_responses, summary$Valid_mapped_responses,
    summary$Missing_responses, summary$Unmapped_nonmissing_responses
  )
  ggplot2::ggplot(plot_data, ggplot2::aes(x = Count, y = Response_option)) +
    ggplot2::geom_col(fill = euaqua_palette[["blue"]], width = 0.65, show.legend = FALSE) +
    ggplot2::geom_text(ggplot2::aes(label = Annotation), hjust = -0.12,
      family = font_family, colour = euaqua_neutrals[["text"]], size = 3.8, show.legend = FALSE) +
    ggplot2::scale_y_discrete(limits = rev(plot_data$Response_option), labels = wrap, drop = FALSE) +
    ggplot2::scale_x_continuous(
      breaks = seq.int(0L, max(1L, max(plot_data$Count))),
      limits = c(0, max(1, max(plot_data$Count)) * 1.4), expand = c(0, 0)
    ) +
    ggplot2::labs(title = title, subtitle = subtitle,
      x = "Responses (count)", y = NULL, caption = caption) +
    theme_euaqua(base_family = font_family) + ggplot2::theme(legend.position = "none")
}

euaqua_export_plot <- function(chart, path, width = 11, height = 6.5) {
  if (!requireNamespace("ragg", quietly = TRUE)) stop("Package ragg is required for PNG export.")
  ggplot2::ggsave(path, chart, device = ragg::agg_png, width = width, height = height,
    units = "in", dpi = 180, bg = euaqua_neutrals[["background"]])
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
