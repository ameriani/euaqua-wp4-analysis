# First descriptive analysis: D_fish_freq in this pilot sample only.
# Run from the project root: source("scripts/03_describe_qualtrics.R")
# Preparation is isolated so existing data and codebook objects are preserved.
euaqua_descriptive_analysis <- local({
  packages <- c("readxl", "jsonlite", "xml2", "ggplot2", "systemfonts", "ragg")
  absent <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent)) stop(paste("Required packages missing:", paste(absent, collapse = ", ")))
  source("scripts/euaqua_plot_theme.R", local = TRUE)
  font_report <- euaqua_font_report()
  font_family <- font_report$Resolved_regular_family
  invisible(capture.output(source("scripts/02_prepare_qualtrics.R", local = TRUE)))
  preparation <- qualtrics_preparation
  variable <- "D_fish_freq"
  options <- preparation$codebook$options
  options <- options[options$variable == variable & options$active_in_flow & options$axis == "Choices", ]
  options <- options[order(options$display_position), , drop = FALSE]
  if (!nrow(options) || anyDuplicated(options$display_position)) {
    stop("Questionnaire options or their order require review.")
  }

  # Separate English display labels; original Italian definitions remain untouched.
  # These straightforward frequency translations have no identified uncertainty.
  translations <- data.frame(
    Original_option = c("Meno di 1 volta al mese", "1-2 volte al mese",
      "Circa una volta a settimana", "2 o più volte a settimana", "Mai"),
    English_display_label = c("Less than once a month", "1-2 times a month",
      "About once a week", "2 or more times a week", "Never"),
    Translation_status = "No uncertainty identified", stringsAsFactors = FALSE
  )
  translation_index <- match(options$option_label, translations$Original_option)
  if (anyNA(translation_index) || !setequal(options$option_label, translations$Original_option)) {
    stop("Questionnaire labels changed; English translations need review.")
  }
  translations <- translations[translation_index, , drop = FALSE]
  rownames(translations) <- NULL

  # Valid means a nonblank value with an unambiguous export-confirmed mapping.
  # Only NA and empty strings are missing. Whitespace is not silently trimmed.
  # Unmapped nonmissing values are reported separately, never assigned to options.
  count_options <- function(values, definitions) {
    confirmed <- definitions$mapping_status == "Confirmed by matched Values/Labels exports"
    if (anyNA(definitions$exported_code[confirmed]) ||
        anyDuplicated(definitions$exported_code[confirmed])) {
      stop("Confirmed code mappings are missing or ambiguous.")
    }
    missing <- is.na(values) | values == ""
    mapped <- match(values, definitions$exported_code[confirmed])
    valid <- !missing & !is.na(mapped)
    unmapped <- !missing & is.na(mapped)
    counts <- integer(nrow(definitions))
    counts[which(confirmed)] <- tabulate(mapped[valid], nbins = sum(confirmed))
    denominator <- sum(valid)
    percentages <- if (denominator > 0L) 100 * counts / denominator else rep(NA_real_, length(counts))
    # Numeric unknown codes may be reported as aggregate codes. Unexpected text
    # is withheld so a malformed categorical field cannot expose identifying text.
    raw_unknown <- values[unmapped]
    safe_unknown <- ifelse(grepl("^[0-9]+$", raw_unknown), raw_unknown, "[non-numeric value withheld]")
    unknown_codes <- sort(unique(safe_unknown))
    unknown_table <- data.frame(Unmapped_value = unknown_codes,
      Count = tabulate(match(safe_unknown, unknown_codes), nbins = length(unknown_codes)),
      stringsAsFactors = FALSE)
    summary <- data.frame(
      Total_responses = length(values), Valid_mapped_responses = denominator,
      Missing_responses = sum(missing), Unmapped_nonmissing_responses = sum(unmapped),
      Percent_denominator = denominator, stringsAsFactors = FALSE
    )
    stopifnot(sum(counts) == denominator,
      denominator + sum(missing) + sum(unmapped) == length(values),
      sum(unknown_table$Count) == sum(unmapped))
    if (denominator > 0L) stopifnot(abs(sum(percentages) - 100) < 1e-8)
    list(counts = counts, percentages = percentages, summary = summary, unmapped = unknown_table)
  }
  counted <- count_options(preparation$csv_data[[variable]], options)
  summary <- counted$summary
  # Independent check against Labels export counts; this does not rely on row order.
  excel_counts <- vapply(options$option_label, function(label)
    sum(preparation$excel_data[[variable]] == label, na.rm = TRUE), integer(1))
  if (!identical(unname(excel_counts), counted$counts)) {
    stop("Values and Labels frequency counts differ; review before plotting.")
  }

  frequency_table <- data.frame(
    Questionnaire_order = options$display_position,
    Response_option = translations$English_display_label,
    Count = counted$counts, Percent_of_valid_responses = counted$percentages,
    stringsAsFactors = FALSE
  )
  option_definitions <- data.frame(
    Questionnaire_order = options$display_position,
    Original_option = options$option_label,
    English_display_label = translations$English_display_label,
    QSF_option_ID = options$qsf_option_id, Confirmed_exported_code = options$exported_code,
    Mapping_status = options$mapping_status,
    Translation_status = translations$Translation_status, stringsAsFactors = FALSE
  )
  plot_data <- frequency_table
  plot_data$Annotation <- if (summary$Valid_mapped_responses > 0L)
    sprintf("%d (%.1f%%)", plot_data$Count, plot_data$Percent_of_valid_responses) else
      sprintf("%d (percentage undefined)", plot_data$Count)
  caption <- sprintf(
    paste0("Pilot sample only. Percentages use valid mapped responses (n = %d).\n",
           "Total = %d; valid = %d; missing = %d; unmapped = %d."),
    summary$Percent_denominator, summary$Total_responses, summary$Valid_mapped_responses,
    summary$Missing_responses, summary$Unmapped_nonmissing_responses
  )
  chart <- ggplot2::ggplot(plot_data, ggplot2::aes(x = Count, y = Response_option)) +
    ggplot2::geom_col(fill = euaqua_palette[["blue"]], width = 0.65, show.legend = FALSE) +
    ggplot2::geom_text(ggplot2::aes(label = Annotation), hjust = -0.12,
      family = font_family, colour = euaqua_neutrals[["text"]], size = 3.8, show.legend = FALSE) +
    ggplot2::scale_y_discrete(limits = rev(translations$English_display_label), drop = FALSE) +
    ggplot2::scale_x_continuous(
      breaks = seq.int(0L, max(1L, max(plot_data$Count))),
      limits = c(0, max(1, max(plot_data$Count)) * 1.4), expand = c(0, 0)
    ) +
    ggplot2::labs(title = "Fish and seafood consumption frequency",
      subtitle = "How often do you consume fish or seafood products?",
      x = "Responses (count)", y = NULL, caption = caption) +
    theme_euaqua(base_family = font_family) + ggplot2::theme(legend.position = "none")

  output_dir <- file.path("outputs", "pilot-ita-30092026", "descriptive", variable)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  tables <- list(frequency_table = frequency_table, response_summary = summary,
    option_definitions = option_definitions, unmapped_values = counted$unmapped, font_report = font_report)
  for (name in names(tables)) {
    write.csv(tables[[name]], file.path(output_dir, paste0(name, ".csv")),
      row.names = FALSE, na = "", fileEncoding = "UTF-8")
  }
  chart_path <- file.path(output_dir, "D_fish_freq_bar_chart.png")
  ggplot2::ggsave(chart_path, chart, device = ragg::agg_png, width = 11, height = 6.5,
    units = "in", dpi = 180, bg = euaqua_neutrals[["background"]])
  writeLines(c(
    "D_fish_freq: descriptive analysis of this pilot sample",
    "Question: How often do you consume fish or seafood products?",
    "All response options are included in questionnaire order (Never is last).",
    "Valid: nonblank values with an unambiguous export-confirmed option mapping.",
    "Missing: NA or empty string. Other unmapped values are reported separately.",
    sprintf("Percentages = count / valid mapped responses (%d) * 100.", summary$Percent_denominator),
    "Zero-count options do not imply that their exported numeric codes are confirmed.",
    "No participant rows were removed and no source values or labels were recoded.",
    "English frequency labels have no identified translation uncertainty; Italian definitions are retained separately.",
    "Colours are provisional EUAqua approximations, not verified official brand codes.",
    sprintf("Preferred font: Montserrat; first fallback: Calibri; resolved font: %s (bold: %s).",
      font_report$Resolved_regular_family, font_report$Resolved_bold_family),
    "PNG renderer: ragg/systemfonts. Visually inspect the exported chart after rerunning.",
    "These results describe this pilot sample and do not estimate population consumption patterns."
  ), file.path(output_dir, "analysis_notes.txt"), useBytes = TRUE)

  cat("D_fish_freq — pilot sample descriptive analysis\n")
  print(frequency_table, row.names = FALSE)
  print(summary, row.names = FALSE)
  cat("Unmapped nonmissing responses:", summary$Unmapped_nonmissing_responses, "\n")
  cat("Montserrat available:", font_report$Preferred_font_available,
    "| Calibri available:", font_report$First_fallback_available, "\n")
  cat("Resolved regular font:", font_report$Resolved_regular_family,
    "| bold:", font_report$Resolved_bold_family, "\n")
  cat("Count and percentage checks passed; original response objects preserved.\n")
  cat("Chart saved:", chart_path, "\n")
  list(frequency_table = frequency_table, summary = summary,
    option_definitions = option_definitions, unmapped_values = counted$unmapped,
    font_report = font_report, chart = chart, chart_path = chart_path,
    count_options = count_options, options = options)
})
