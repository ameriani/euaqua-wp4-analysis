# Rebuild the existing analysis, then render only an allowlist of aggregate results.
# Run from the RStudio project root: source("reports/render_pilot_report.R")
render_euaqua_pilot_report <- function(report_date = as.Date(format(Sys.time(), tz = "Europe/Copenhagen"))) {
  required <- c("rmarkdown", "knitr", "htmltools", "xml2")
  absent <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent)) stop("Missing report dependencies: ", paste(absent, collapse = ", "))
  if (!rmarkdown::pandoc_available()) stop("Pandoc is required; use the RStudio installation.")
  root <- normalizePath(".", winslash = "/")
  stopifnot(file.exists(file.path(root, "scripts/03_describe_qualtrics.R")))
  analysis_env <- new.env(parent = globalenv())
  invisible(capture.output(source("scripts/03_describe_qualtrics.R", local = analysis_env)))
  analysis <- analysis_env$euaqua_descriptive_analysis
  style <- new.env(parent = baseenv())
  sys.source("scripts/euaqua_plot_theme.R", envir = style)
  out <- file.path(root, "outputs/pilot-ita-30092026/report")
  assets <- file.path(out, "assets")
  dir.create(assets, recursive = TRUE, showWarnings = FALSE)
  allowed <- names(analysis$chart_paths)[!is.na(analysis$chart_paths)]
  # No response-level data, consent results, or demographic distributions enter knitting.
  items <- lapply(allowed, function(v) {
    a <- analysis$analyses[[v]]
    disk <- read.csv(file.path(dirname(a$chart_path), "frequency_table.csv"), check.names = FALSE)
    stopifnot(isTRUE(all.equal(a$frequency_table, disk, check.attributes = FALSE)),
      sum(a$frequency_table$Count) == a$summary$Valid_mapped_responses,
      a$summary$Total_responses == sum(a$summary[c("Valid_mapped_responses", "Missing_responses", "Unmapped_nonmissing_responses")]))
    if (a$summary$Percent_denominator > 0) stopifnot(
      max(abs(a$frequency_table$Percent_of_valid_responses -
        100 * a$frequency_table$Count / a$summary$Percent_denominator)) < 1e-8)
    filename <- paste0(v, "_bar_chart.png")
    stopifnot(file.copy(a$chart_path, file.path(assets, filename), overwrite = TRUE))
    list(table = a$frequency_table, summary = a$summary,
      definitions = a$option_definitions, unmapped = a$unmapped_values,
      title = a$chart$labels$title, question = a$chart$labels$subtitle,
      asset = paste0("assets/", filename))
  })
  names(items) <- allowed
  age_disk <- read.csv("outputs/pilot-ita-30092026/descriptive/sample_characteristics/C_age/age_summary.csv")
  stopifnot(isTRUE(all.equal(analysis$age_summary, age_disk, check.attributes = FALSE)))
  report <- list(items = items, completeness = analysis$response_overview,
    age = analysis$age_summary, education = analysis$analyses$C_education$option_definitions,
    font = analysis$font_report,
    sample_size = unique(analysis$response_overview$Total_responses),
    pilot_date = as.Date("2026-09-30"), report_date = as.Date(report_date))
  stopifnot(length(report$sample_size) == 1L)
  # Dates are study metadata, not hard-coded analytical results. The pilot date was
  # checked against the saved executive Gantt: "Pilot scheduled for 30 September 2026".
  family <- report$font$Resolved_regular_family
  css <- sprintf('
html { background: %s; } body { font-family: "%s", sans-serif; color: %s; font-size: 15px; line-height: 1.45; margin: 0; }
.main-container { max-width: 1080px; margin: auto; padding: 36px 32px; }
h1,h2,h3,h4 { font-family: inherit; color: %s; line-height: 1.25; }
h1 { font-size: 36px; margin: 10px 0 18px; } h2 { margin-top: 36px; border-bottom: 3px solid %s; padding-bottom: 8px; }
h3 { margin-top: 24px; } .eyebrow { color: %s; letter-spacing: .12em; font-weight: bold; }
.title-card { border-top: 8px solid %s; border-bottom: 1px solid %s; padding: 24px 0 32px; }
.metadata { display: flex; flex-wrap: wrap; gap: 28px; } .metadata strong { display: block; color: %s; }
.review { border-left: 4px solid %s; padding: 12px 20px; background: #f7f9fa; }
table { width: 100%%; border-collapse: collapse; margin: 12px 0 18px; font-size: 13px; }
caption,figcaption { text-align: left; font-weight: bold; color: %s; margin: 7px 0; font-size: 12px; }
th { text-align: left; border-bottom: 2px solid %s; padding: 7px 8px; } td { padding: 6px 8px; border-bottom: 1px solid %s; vertical-align: top; }
td.numeric { text-align: right; font-variant-numeric: tabular-nums; } tbody tr:nth-child(even) { background: #f7f9fa; }
figure { margin: 16px 0 24px; } figure img { display: block; max-width: 100%%; height: auto; }
.denominator,.footnote { font-size: 13px; } .item { margin: 24px 0 32px; } a { color: %s; }
@page { size: A4; margin: 16mm; }
@media print { body { font-size: 10pt; line-height: 1.3; print-color-adjust: exact; -webkit-print-color-adjust: exact; }
.main-container { max-width: none; padding: 0; } h1 { font-size: 24pt; } h2 { font-size: 16pt; margin-top: 18pt; }
h3 { font-size: 12pt; } h1,h2,h3,caption,.denominator { break-after: avoid; }
table { font-size: 9.5pt; break-inside: avoid; } tr,figure,.title-card,.review { break-inside: avoid; }
thead { display: table-header-group; } figure { margin: 10pt 0 14pt; }
figure img { max-height: 135mm; width: auto; max-width: 100%%; }
caption,figcaption { font-size: 9pt; } .title-card { padding: 14pt 0 18pt; }
.metadata { gap: 18px; } .denominator,.footnote { font-size: 9pt; } }
', style$euaqua_neutrals[["background"]], family, style$euaqua_neutrals[["text"]],
    style$euaqua_palette[["blue"]], style$euaqua_palette[["green"]], style$euaqua_palette[["green"]],
    style$euaqua_palette[["blue"]], style$euaqua_neutrals[["grid"]], style$euaqua_palette[["blue"]],
    style$euaqua_palette[["light_blue"]], style$euaqua_palette[["blue"]], style$euaqua_palette[["light_blue"]],
    style$euaqua_neutrals[["grid"]], style$euaqua_palette[["blue"]])
  writeLines(css, file.path(assets, "euaqua-report.css"))
  render_env <- new.env(parent = baseenv())
  render_env$report <- report
  result <- rmarkdown::render("reports/pilot_report.Rmd", output_file = "EUAqua_pilot_report.html",
    output_dir = out, intermediates_dir = out, knit_root_dir = root, envir = render_env,
    output_options = list(css = "assets/euaqua-report.css"), quiet = TRUE)
  # Verify every numeric HTML table cell against the aggregate value supplied to it.
  doc <- xml2::read_html(result)
  references <- xml2::xml_attr(xml2::xml_find_all(doc, "//*[@src]"), "src")
  references <- c(references, xml2::xml_attr(xml2::xml_find_all(doc, "//link[@href]"), "href"))
  stopifnot(!any(grepl("^(https?:|/)", references)),
    all(file.exists(file.path(out, references))))
  nodes <- xml2::xml_find_all(doc, "//td[@data-expected]")
  stopifnot(length(nodes) > 0L,
    identical(trimws(xml2::xml_text(nodes)), xml2::xml_attr(nodes, "data-expected")))
  narrative <- xml2::xml_find_all(doc, "//span[@data-expected]")
  stopifnot(identical(trimws(xml2::xml_text(narrative)), xml2::xml_attr(narrative, "data-expected")),
    length(xml2::xml_find_all(doc, "//figure")) == length(items))
  prose <- gsub("[[:space:]]+", " ", xml2::xml_text(xml2::xml_find_all(doc, "//p")))
  singular <- prose[grepl("The most frequent category was", prose, fixed = TRUE)]
  stopifnot(!any(grepl("responses per category|% each", singular)))
  writeLines(c(paste("Verified numeric table cells:", length(nodes)),
    paste("Verified numeric narrative fields:", length(narrative)),
    paste("Verified existing charts:", length(items)),
    "Frequency tables and age summary agree with descriptive CSV outputs.",
    "Counts reconcile with denominators; percentages checked before rendering.",
    "No participant-level objects or consent results supplied to report template.",
    "All report resources are present and referenced by relative local paths.",
    "HTML typography and print pagination require browser preview; numeric verification does not verify layout."
  ), file.path(out, "verification.txt"))
  writeLines(capture.output(sessionInfo()), file.path(out, "session_info.txt"))
  message("Rendered and numerically verified: ", result)
  invisible(result)
}

euaqua_pilot_report_path <- render_euaqua_pilot_report()
