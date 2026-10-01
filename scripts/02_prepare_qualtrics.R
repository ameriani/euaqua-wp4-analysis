# Run from the project root: source("scripts/02_prepare_qualtrics.R")
# Dependency: readxl. No response exclusions, recoding, or original-file writes.
# Only the preparation object is assigned in the calling environment.
qualtrics_preparation <- local({
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop('Package readxl is required. Run install.packages("readxl") first.')
  }
  excel_path <- file.path(
    "data", "raw", "pilot-ita-30092026", "01_Qualtrics",
    "Pilot_Qualtrics_Labels_2026-10-01.xlsx"
  )
  if (!file.exists(excel_path)) stop("Labels export not found.")

  # Source the existing importer in a separate environment. This leaves existing
  # qualtrics_data and qualtrics_dictionary objects in RStudio untouched.
  import_env <- new.env()
  invisible(capture.output(source("scripts/01_import_qualtrics.R", local = import_env)))
  csv_data <- import_env$qualtrics_data
  csv_metadata <- import_env$qualtrics_dictionary
  source_paths <- c(import_env$csv_path, excel_path)
  original_hashes <- tools::md5sum(source_paths)

  sheets <- readxl::excel_sheets(excel_path)
  if (length(sheets) != 1L) stop("Expected one worksheet; review the workbook.")
  excel_export <- as.data.frame(readxl::read_excel(
    excel_path, sheet = sheets[1L], col_types = "text",
    trim_ws = FALSE, .name_repair = "minimal"
  ), stringsAsFactors = FALSE)
  if (nrow(excel_export) < 1L ||
      any(!nzchar(names(excel_export))) || anyDuplicated(names(excel_export))) {
    stop("Unexpected Excel headers; review the workbook.")
  }
  if (!setequal(names(csv_data), names(excel_export))) {
    stop("CSV and Excel variable sets differ; no dictionary was generated.")
  }
  # Identify metadata by matching its ResponseId question heading, not row count.
  # This Labels export has a question-text row and no ImportId row.
  response_heading <- csv_metadata$label[csv_metadata$variable == "ResponseId"]
  if (length(response_heading) != 1L ||
      !identical(excel_export$ResponseId[1L], response_heading)) {
    stop("Excel question-text row not recognized.")
  }
  excel_metadata <- data.frame(
    variable = names(excel_export),
    label = as.character(unlist(excel_export[1L, ], use.names = FALSE)),
    stringsAsFactors = FALSE
  )
  metadata_rows <- 1L
  if (nrow(excel_export) >= 2L && all(grepl(
      '"ImportId"', as.character(unlist(excel_export[2L, ])), fixed = TRUE))) {
    metadata_rows <- 2L
  }
  excel_data <- excel_export[-seq_len(metadata_rows), , drop = FALSE]
  rownames(excel_data) <- NULL

  # Blank comparison only: readxl uses NA for empty cells; read.csv keeps "".
  # This helper does not modify either imported data object.
  blank <- function(x) is.na(x) | x == ""
  equal_cells <- function(x, y) {
    (blank(x) & blank(y)) | (!blank(x) & !blank(y) & x == y)
  }
  match_exports <- function(values, labels) {
    for (key in c("ResponseId", "PID")) {
      if (!key %in% names(values) || !key %in% names(labels)) {
        stop("A required ResponseId or PID column is absent.")
      }
    }
    checks <- data.frame(
      check = c("CSV responses", "Excel responses", "CSV blank ResponseId",
                "Excel blank ResponseId", "CSV duplicate ResponseId",
                "Excel duplicate ResponseId", "CSV-only ResponseId",
                "Excel-only ResponseId"),
      value = c(nrow(values), nrow(labels), sum(blank(values$ResponseId)),
                sum(blank(labels$ResponseId)), sum(duplicated(values$ResponseId)),
                sum(duplicated(labels$ResponseId)),
                sum(!values$ResponseId %in% labels$ResponseId),
                sum(!labels$ResponseId %in% values$ResponseId))
    )
    if (any(checks$value[3:8] != 0L)) {
      print(checks, row.names = FALSE)
      stop("ResponseId matching is not one-to-one; review before continuing.")
    }
    index <- match(values$ResponseId, labels$ResponseId)
    matched_pid <- labels$PID[index]
    checks <- rbind(checks, data.frame(
      check = c("CSV blank PID", "Excel blank PID", "PID mismatches after matching",
                "CSV duplicate nonblank PID", "Excel duplicate nonblank PID"),
      value = c(sum(blank(values$PID)), sum(blank(labels$PID)),
                sum(!equal_cells(values$PID, matched_pid)),
                sum(duplicated(values$PID[!blank(values$PID)])),
                sum(duplicated(labels$PID[!blank(labels$PID)])))
    ))
    list(index = index, checks = checks)
  }
  matching <- match_exports(csv_data, excel_data)
  # This separate copy is aligned for comparisons; original Excel order is kept.
  excel_matched <- excel_data[matching$index, names(csv_data), drop = FALSE]

  # Explicit scope: consent variables and research questions in this export.
  # No administrative metadata, PID, or ResponseId enters the dictionary.
  categorical <- c(
    "C1", "C2", "C3", "C4", "C5", "C_gender", "C_education", "C_occupation",
    "D_grocery_resp", "D_fish_freq", "D_diet_type", "D_attention_matrix_1",
    "D_attention_matrix_2", "D_attention_matrix_3", "E_label_trust",
    "E_label_comp", "E_label_overload", "E_new_label_eval", "E_label_format",
    "E_fav_fish_type", "E_oa_awareness"
  )
  numeric_variable <- "C_age"
  text_variables <- c("C_gender_4_TEXT", "C_occupation_6_TEXT",
                      "D_diet_type_6_TEXT", "E_fav_fish_type_5_TEXT")
  research_variables <- names(csv_data)[grepl("^[CDE]_", names(csv_data)) |
                                       grepl("^C[1-5]$", names(csv_data))]
  if (!setequal(research_variables, c(categorical, numeric_variable, text_variables))) {
    stop("Research-variable scope changed; review classification before continuing.")
  }

  dictionary_parts <- lapply(research_variables, function(variable) {
    question_csv <- csv_metadata$label[match(variable, csv_metadata$variable)]
    question_excel <- excel_metadata$label[match(variable, excel_metadata$variable)]
    flags <- character()
    if (!isTRUE(equal_cells(question_csv, question_excel))) {
      flags <- c(flags, "Question headings differ between exports; review both")
    }
    kind <- if (variable %in% text_variables) "free text" else
      if (variable == numeric_variable) "numeric entry" else
        if (variable %in% paste0("C", 1:5)) "consent category" else "research category"
    pairs <- data.frame(observed_code = NA_character_, observed_label = NA_character_)
    if (variable %in% categorical) {
      codes <- csv_data[[variable]]
      labels <- excel_matched[[variable]]
      if (any(xor(blank(codes), blank(labels)))) {
        flags <- c(flags, "Blank/nonblank mismatch between exports")
      }
      # Only publish mappings if every nonblank code has a numeric category form.
      # Unrecognized values are withheld rather than exposed as possible free text.
      if (any(!grepl("^[0-9]+$", codes[!blank(codes)]))) {
        flags <- c(flags, "Unexpected categorical code format; mappings withheld")
      } else {
        usable <- !blank(codes) & !blank(labels)
        if (any(usable)) {
          pairs <- unique(data.frame(observed_code = codes[usable],
                                     observed_label = labels[usable]))
          pairs <- pairs[order(as.numeric(pairs$observed_code), pairs$observed_label), ]
          if (anyDuplicated(pairs$observed_code)) {
            flags <- c(flags, "One observed code maps to multiple labels")
          }
          if (anyDuplicated(pairs$observed_label)) {
            flags <- c(flags, "One observed label maps to multiple codes")
          }
        } else {
          flags <- c(flags, "No paired nonblank options observed")
        }
      }
    } else {
      flags <- c(flags, "Observed individual values intentionally withheld")
      if (any(!equal_cells(csv_data[[variable]], excel_matched[[variable]]))) {
        flags <- c(flags, "Entry values differ between exports; review locally")
      }
    }
    data.frame(
      variable = variable, kind = kind, question_csv = question_csv,
      question_excel = question_excel, pairs,
      scope = if (variable %in% categorical)
        "Observed options only; complete questionnaire scale not available in exports"
        else "Entry field; individual values not included",
      flags = if (length(flags)) paste(flags, collapse = "; ") else "None detected",
      stringsAsFactors = FALSE, row.names = NULL
    )
  })
  dictionary <- do.call(rbind, dictionary_parts)
  rownames(dictionary) <- NULL
  checks <- rbind(matching$checks, data.frame(
    check = c("Variables in each export", "Excel metadata rows",
              "Dictionary variables", "Variables with differing question headings"),
    value = c(ncol(csv_data), metadata_rows, length(research_variables),
              sum(!equal_cells(csv_metadata$label,
                excel_metadata$label[match(csv_metadata$variable, excel_metadata$variable)])))
  ))

  # Save only variable definitions and aggregate checks to ignored local outputs.
  output_dir <- file.path("outputs", "pilot-ita-30092026", "qualtrics_preparation")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(dictionary, file.path(output_dir, "observed_dictionary.csv"),
            row.names = FALSE, na = "", fileEncoding = "UTF-8")
  write.csv(checks, file.path(output_dir, "aggregate_checks.csv"),
            row.names = FALSE, fileEncoding = "UTF-8")
  if (!identical(original_hashes, tools::md5sum(source_paths))) {
    stop("Original-file integrity check failed.")
  }
  cat("Qualtrics preparation checks (no individual values):\n")
  print(checks, row.names = FALSE)
  cat("Original files unchanged. No responses excluded or recoded.\n")
  cat("Dictionary saved locally:", file.path(output_dir, "observed_dictionary.csv"), "\n")
  cat("Complete response scales require the questionnaire/codebook; not inferred.\n")
  list(csv_data = csv_data, csv_metadata = csv_metadata,
       excel_export = excel_export, excel_data = excel_data,
       excel_metadata = excel_metadata, checks = checks, dictionary = dictionary,
       match_exports = match_exports, readxl_version = as.character(packageVersion("readxl")))
})
