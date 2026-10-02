# Complete variable-level Qualtrics descriptives for this pilot sample.
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
  # ---- Purchasing and dietary habits: original fish-consumption result ----
  chart <- euaqua_frequency_plot(frequency_table, summary,
    "Fish and seafood consumption frequency",
    "How often do you consume fish or seafood products?", font_family)

  output_dir <- file.path("outputs", "pilot-ita-30092026", "descriptive", variable)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  tables <- list(frequency_table = frequency_table, response_summary = summary,
    option_definitions = option_definitions, unmapped_values = counted$unmapped, font_report = font_report)
  for (name in names(tables)) {
    write.csv(tables[[name]], file.path(output_dir, paste0(name, ".csv")),
      row.names = FALSE, na = "", fileEncoding = "UTF-8")
  }
  chart_path <- file.path(output_dir, "D_fish_freq_bar_chart.png")
  euaqua_export_plot(chart, chart_path)
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

  # ---- Sample characteristics: authorized marginal distributions and quantitative age ----
  # User-approved demographic tables only; no cross-tabulations or individual records.
  analyses <- list(D_fish_freq = list(frequency_table = frequency_table, summary = summary,
    option_definitions = option_definitions, unmapped_values = counted$unmapped,
    chart = chart, chart_path = chart_path))
  root <- file.path("outputs", "pilot-ita-30092026", "descriptive")
  demographic_tables_only <- c("C_gender", "C_education", "C_occupation")
  text_blank <- function(x) {
    visible <- gsub("(*UTF)(*UCP)[[:space:]\\p{Zs}\\x{200B}\\x{FEFF}]", "", enc2utf8(x), perl = TRUE)
    is.na(x) | !nzchar(visible)
  }
  write_table <- function(x, path) write.csv(x, path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  analysis_specs <- list(D_fish_freq = list(section = "purchasing_and_dietary_habits",
    type = "ordered categories", translation_status = "No uncertainty identified"))

  # Verify counts against both exports; preserve original demographic categories.
  # English labels are separate from Italian source definitions; option IDs are not codes.
  describe_category <- function(v, section, title, subtitle, italian, english, type = "categories",
                                translation_status = "No uncertainty identified") {
    definitions <- preparation$codebook$options
    definitions <- definitions[definitions$variable == v & definitions$active_in_flow &
      definitions$axis %in% c("Choices", "Answers"), , drop = FALSE]
    definitions <- definitions[order(definitions$display_position), , drop = FALSE]
    if (!setequal(definitions$option_label, italian) || length(italian) != length(english) ||
        anyDuplicated(definitions$display_position)) stop(paste("Review options/translation for", v))
    labels <- english[match(definitions$option_label, italian)]
    if (anyNA(labels) || anyDuplicated(labels)) stop(paste("Review English labels for", v))
    cts <- count_options(preparation$csv_data[[v]], definitions)
    confirmed <- definitions$mapping_status == "Confirmed by matched Values/Labels exports"
    excel <- vapply(definitions$option_label, function(label)
      sum(preparation$excel_data[[v]] == label, na.rm = TRUE), integer(1))
    if (any(excel[confirmed] != cts$counts[confirmed])) stop(paste("Values/Labels mismatch for", v))
    ft <- data.frame(Questionnaire_order = definitions$display_position, Response_option = labels,
      Count = cts$counts, Percent_of_valid_responses = cts$percentages)
    defs <- data.frame(Questionnaire_order = definitions$display_position,
      Original_option = definitions$option_label, English_display_label = labels,
      QSF_option_ID = definitions$qsf_option_id, Confirmed_exported_code = definitions$exported_code,
      Mapping_status = definitions$mapping_status, Translation_status = translation_status)
    dir <- file.path(root, section, v)
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    plot <- NULL; path <- NA_character_
    if (!v %in% demographic_tables_only) {
      plot <- euaqua_frequency_plot(ft, cts$summary, title,
        paste(strwrap(subtitle, width = 100), collapse = "\n"), font_family)
      path <- file.path(dir, paste0(v, "_bar_chart.png"))
      height <- if (v == "D_diet_type") 8.5 else if (nrow(ft) >= 6L) 7.5 else 6.5
      euaqua_export_plot(plot, path, height = height)
    }
    tables <- list(frequency_table = ft, response_summary = cts$summary,
      option_definitions = defs, unmapped_values = cts$unmapped)
    for (name in names(tables)) write_table(tables[[name]], file.path(dir, paste0(name, ".csv")))
    writeLines(c(paste(v, "— pilot sample only"),
      paste("Percentage denominator:", cts$summary$Percent_denominator, "valid mapped responses."),
      "NA and empty strings are missing. Explicit Never/non-reader/prefer-not-to-answer options are valid categories.",
      "Unmapped values remain separate. Unobserved options retain unconfirmed numeric codes.",
      "No ordinal means, numerical scores, collapsed categories, combined scales, or reader-only analyses.",
      paste("Translation review:", translation_status),
      if (v %in% demographic_tables_only) "User-authorized marginal demographic table; no chart or cross-tabulation." else
        "All questionnaire options included, including zeros, in questionnaire order."
    ), file.path(dir, "analysis_notes.txt"), useBytes = TRUE)
    analyses[[v]] <<- list(frequency_table = ft, summary = cts$summary, option_definitions = defs,
      unmapped_values = cts$unmapped, chart = plot, chart_path = path, title = title, question = subtitle)
    analysis_specs[[v]] <<- list(section = section, type = type, translation_status = translation_status)
  }
  describe_category("C_gender", "sample_characteristics", "Gender identity",
    "Which gender do you identify with?",
    c("Donna", "Uomo", "Preferisco non rispondere", "Altro:"),
    c("Woman", "Man", "Prefer not to answer", "Other"), "nominal")
  describe_category("C_education", "sample_characteristics", "Highest educational qualification",
    "What is the highest educational qualification you have completed?",
    c("Licenza media o inferiore", "Diploma di scuola superiore", "Laurea triennale",
      "Laurea magistrale o superiore (Master, PhD)"),
    c("Lower secondary school or below", "Upper secondary school diploma",
      "Bachelor's degree", "Master's degree or higher (including PhD)"), "ordered categories",
    "Review: descriptive translation of Italian qualifications; no international equivalence assumed")
  describe_category("C_occupation", "sample_characteristics", "Current employment status",
    "What is your current employment status?",
    c("Studente/studentessa", "Occupato/a dipendente", "Lavoratore/lavoratrice autonomo/a",
      "Disoccupato/a", "Pensionato/a", "Altro:"),
    c("Student", "Employee", "Self-employed", "Unemployed", "Retired", "Other"), "nominal")

  summarise_age <- function(values, lower = 18, upper = 100) {
    missing <- text_blank(values)
    numerical_copy <- suppressWarnings(as.numeric(values))
    valid <- !missing & is.finite(numerical_copy)
    invalid <- !missing & !is.finite(numerical_copy)
    # Include all finite numeric entries, even flagged out-of-range/noninteger values.
    # Nonblank nonnumeric/nonfinite values cannot enter a numerical summary; report them.
    available <- numerical_copy[valid]
    qs <- if (length(available)) as.numeric(stats::quantile(available, c(.25, .5, .75), type = 7)) else rep(NA_real_, 3)
    out <- data.frame(Total_responses = length(values), Valid_numeric_responses = sum(valid),
      Missing_responses = sum(missing), Invalid_nonmissing_responses = sum(invalid),
      First_quartile_years = qs[1L], Median_years = qs[2L], Third_quartile_years = qs[3L],
      Minimum_years = if (length(available)) min(available) else NA_real_,
      Maximum_years = if (length(available)) max(available) else NA_real_,
      Outside_QSF_range = sum(valid & (numerical_copy < lower | numerical_copy > upper), na.rm = TRUE),
      Noninteger_values = sum(valid & numerical_copy != trunc(numerical_copy), na.rm = TRUE),
      Quartile_method = "R quantile type 7: h = 1 + (n - 1) * p; linear interpolation",
      Numerical_summary_denominator = sum(valid))
    stopifnot(sum(valid) + sum(missing) + sum(invalid) == length(values))
    out
  }
  age_question <- preparation$codebook$questions
  age_rules <- jsonlite::fromJSON(age_question$validation_json[age_question$export_tag == "C_age"])$Settings$ValidNumber
  age_summary <- summarise_age(preparation$csv_data$C_age, as.numeric(age_rules$Min), as.numeric(age_rules$Max))
  age_dir <- file.path(root, "sample_characteristics", "C_age")
  dir.create(age_dir, recursive = TRUE, showWarnings = FALSE)
  write_table(age_summary, file.path(age_dir, "age_summary.csv"))
  writeLines(c("Quantitative age: median, quartiles, min-max and conversion flags. No individual points.",
    "Quartiles: R quantile type 7, linear interpolation with h = 1 + (n - 1) * p.",
    "Only a derived numeric copy is converted; original values remain unchanged.",
    "NA, empty and whitespace-only entries are missing. Non-finite/nonnumeric nonblank values are counted as invalid.",
    "All finite numeric entries remain in summaries, including those outside the QSF range or not whole years.",
    "Unexpected values require review; no automatic exclusions. No age-by-demographic combinations."
  ), file.path(age_dir, "analysis_notes.txt"))

  # User-approved recruitment comparison: 18-30, 31-55 and 56+, in completed years.
  # Only a derived copy is grouped. Finite noninteger or under-18 ages remain in
  # numerical summaries and are flagged as unassigned here, never silently rounded.
  age_copy <- suppressWarnings(as.numeric(preparation$csv_data$C_age))
  age_missing <- text_blank(preparation$csv_data$C_age)
  age_assignable <- !age_missing & is.finite(age_copy) & age_copy == trunc(age_copy) & age_copy >= 18
  age_band <- cut(age_copy[age_assignable], breaks = c(18, 31, 56, Inf),
    labels = c("18-30", "31-55", "56+"), right = FALSE)
  age_band_denominator <- sum(age_assignable)
  age_bands <- data.frame(Category = levels(age_band), Count = as.integer(table(age_band)),
    Percent = if (age_band_denominator > 0) 100 * as.integer(table(age_band)) / age_band_denominator else NA_real_,
    Denominator = age_band_denominator)
  age_band_summary <- data.frame(Total = length(age_copy), Valid_banded = age_band_denominator,
    Missing = sum(age_missing), Unassigned_nonmissing = sum(!age_missing & !age_assignable))
  stopifnot(sum(age_bands$Count) == age_band_denominator,
    sum(age_band_summary[-1]) == age_band_summary$Total)
  write_table(age_bands, file.path(age_dir, "age_band_distribution.csv"))
  write_table(age_band_summary, file.path(age_dir, "age_band_summary.csv"))

  # A comparison-only tertiary grouping; the four questionnaire categories stay intact.
  education <- analyses$C_education$frequency_table
  stopifnot(identical(education$Response_option, c("Lower secondary school or below",
    "Upper secondary school diploma", "Bachelor's degree", "Master's degree or higher (including PhD)")))
  education_comparison <- data.frame(Category = c("At most lower secondary", "Upper secondary diploma",
    "University degree (combined questionnaire options)"),
    Count = c(education$Count[1:2], sum(education$Count[3:4])),
    Denominator = analyses$C_education$summary$Percent_denominator)
  education_comparison$Percent <- if (education_comparison$Denominator[1] > 0)
    100 * education_comparison$Count / education_comparison$Denominator else NA_real_
  stopifnot(sum(education_comparison$Count) == analyses$C_education$summary$Valid_mapped_responses)
  write_table(education_comparison, file.path(root, "sample_characteristics/C_education/education_comparison.csv"))

  # ---- Purchasing and dietary habits: separate distributions, no combined attention scale ----
  # The fish-consumption analysis above retains its original table, plot and output path.
  describe_category("D_grocery_resp", "purchasing_and_dietary_habits", "Responsibility for grocery shopping",
    "Do you shop for food for yourself or your household?",
    c("No, se ne occupa principalmente un’altra persona", "Sì, occasionalmente",
      "Sì, insieme ad altre persone", "Sì, principalmente io", "Vivo da solo/a e me ne occupo interamente io"),
    c("No, another person mainly does it", "Yes, occasionally", "Yes, together with other people",
      "Yes, I mainly do it", "I live alone and do all the shopping"))
  describe_category("D_diet_type", "purchasing_and_dietary_habits", "Usual diet",
    "Which description best represents your usual diet?",
    c("Onnivora (consumo abituale di alimenti di origine animale e vegetale)",
      "Flexitariana (dieta prevalentemente vegetariana, con consumo occasionale di carne, pesce e/o derivati animali)",
      "Pescetariana (non consumo carne, ma consumo pesce e altri prodotti di origine animale)",
      "Vegetariana (non consumo carne o pesce, ma consumo altri prodotti di origine animale)",
      "Vegana (non consumo alimenti di origine animale)", "Altro:"),
    c("Omnivorous: regularly eat animal and plant foods",
      "Flexitarian: mainly vegetarian, occasionally eat meat, fish or animal products",
      "Pescatarian: no meat, but eat fish and other animal products",
      "Vegetarian: no meat or fish, but eat other animal products", "Vegan: no animal foods", "Other"), "nominal")
  for (i in 1:3) {
    aspect <- c("Health and nutritional quality", "Environmental sustainability", "Price")[i]
    describe_category(paste0("D_attention_matrix_", i), "purchasing_and_dietary_habits",
      paste("Shopping attention:", tolower(aspect)),
      paste("How much attention do you pay to", tolower(aspect), "when shopping for food?"),
      c("Per nulla", "Poco", "Abbastanza", "Molto", "Moltissimo"),
      c("Not at all", "A little", "Somewhat", "A lot", "A great deal"), "ordinal item")
  }

  # ---- Label and sustainability perceptions: separate items, non-readers retained ----
  nonreader <- "Non leggo le etichette"
  section <- "label_and_sustainability_perceptions"
  describe_category("E_label_trust", section, "Trust in food label information",
    "How much do you trust the information on food labels?",
    c("Per nulla", "Poco", "Né poco né molto", "Molto", "Moltissimo", nonreader),
    c("Not at all", "A little", "Neither little nor much", "A lot", "A great deal", "I do not read labels"),
    "ordinal item with non-reader category")
  describe_category("E_label_comp", section, "Ease of understanding food labels",
    "How easy is it for you to understand food label information?",
    c("Per nulla facile", "Poco facile", "Abbastanza facile", "Molto facile", "Estremamente facile", nonreader),
    c("Not at all easy", "Not very easy", "Fairly easy", "Very easy", "Extremely easy", "I do not read labels"),
    "ordinal item with non-reader category")
  describe_category("E_label_overload", section, "Difficulty finding useful label information",
    "When a label has a lot of information, how often is it difficult to find what helps your choice?",
    c("Mai", "Raramente", "A volte", "Spesso", "Sempre", nonreader),
    c("Never", "Rarely", "Sometimes", "Often", "Always", "I do not read labels"),
    "ordinal item with non-reader category")
  describe_category("E_new_label_eval", section, "Evaluation of new sustainability communication",
    "Considering existing sustainability information, how would you evaluate a new form of communication?",
    c("Creerebbe molta più confusione", "Creerebbe un po' più di confusione", "Non farebbe differenza",
      "Aiuterebbe un po’ a comprendere meglio il prodotto", "Aiuterebbe molto a comprendere meglio il prodotto", nonreader),
    c("Would create much more confusion", "Would create a little more confusion", "Would make no difference",
      "Would help a little to understand the product", "Would help a lot to understand the product", "I do not read labels"),
    "ordinal item with non-reader category")
  describe_category("E_label_format", section, "Preferred sustainability information format",
    "How would you prefer the different aspects of sustainability to be presented on a food label?",
    c("Come informazioni separate, ciascuna relativa a uno specifico aspetto",
      "Come un’unica indicazione sintetica della sostenibilità complessiva del prodotto",
      "Come un’indicazione sintetica accompagnata da informazioni sui singoli aspetti, direttamente sull’etichetta",
      "Come un’indicazione sintetica sull’etichetta, con informazioni sui singoli aspetti accessibili tramite QR code",
      "Non ho preferenze", nonreader),
    c("Separate information for each aspect", "One summary indication of overall product sustainability",
      "A summary indication with details on individual aspects on the label",
      "A summary indication on the label with details on individual aspects via QR code",
      "No preference", "I do not read labels"), "nominal with non-reader category")
  describe_category("E_fav_fish_type", section, "Preferred fish product type",
    "Which type of fish product do you prefer to buy?",
    c("Pesce pescato / selvatico", "Pesce da acquacoltura convenzionale", "Pesce da acquacoltura biologica", "Indifferente", "Altro"),
    c("Wild-caught fish", "Conventionally farmed fish", "Organically farmed fish", "No preference", "Other"), "nominal")
  describe_category("E_oa_awareness", section, "Awareness of organic aquaculture",
    "How familiar are you with the concept of organic aquaculture?",
    c("Non ne avevo mai sentito parlare", "Ne ho sentito parlare, ma non saprei spiegare di cosa si tratta",
      "Lo conosco in modo generale", "Lo conosco abbastanza bene", "Lo conosco molto bene"),
    c("I had never heard of it", "I have heard of it but could not explain it",
      "I have a general understanding", "I know it fairly well", "I know it very well"), "ordered categories")

  # ---- Free text: availability only; no quotations, thematic coding or conditional subsets ----
  summarise_text <- function(values) {
    missing <- text_blank(values)
    result <- data.frame(Total_responses = length(values), Nonblank_responses = sum(!missing),
      Blank_responses = sum(missing), Availability_denominator = length(values))
    stopifnot(result$Nonblank_responses + result$Blank_responses == result$Total_responses)
    result
  }
  text_sections <- c(C_gender_4_TEXT = "sample_characteristics", C_occupation_6_TEXT = "sample_characteristics",
    D_diet_type_6_TEXT = "purchasing_and_dietary_habits", E_fav_fish_type_5_TEXT = "label_and_sustainability_perceptions")
  free_text_availability <- do.call(rbind, lapply(names(text_sections), function(v) {
    result <- summarise_text(preparation$csv_data[[v]])
    dir <- file.path(root, text_sections[[v]], v)
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    write_table(result, file.path(dir, "text_availability.csv"))
    data.frame(Variable = v, Section = text_sections[[v]], result)
  }))
  write_table(free_text_availability, file.path(root, "free_text_availability.csv"))

  # ---- Consent: separate eligibility/permission audit; no automatic exclusions ----
  audit_consents <- function(values_data, options_data) {
    rows <- list(); required_granted <- list()
    for (v in paste0("C", 1:5)) {
      defs <- options_data[options_data$variable == v, ]
      confirmed <- defs$mapping_status == "Confirmed by matched Values/Labels exports"
      yes_codes <- defs$exported_code[confirmed & defs$option_label == "Acconsento"]
      no_codes <- defs$exported_code[confirmed & defs$option_label == "Non acconsento"]
      values <- values_data[[v]]
      missing <- is.na(values) | values == ""
      yes <- !missing & values %in% yes_codes
      no <- !missing & values %in% no_codes
      unmapped <- !missing & !(yes | no)
      rows[[v]] <- data.frame(Consent_variable = v,
        Role = if (v %in% c("C1", "C2", "C3")) "Required in QSF participation flow" else "Optional permission",
        Total_responses = length(values), Granted = sum(yes), Declined = sum(no),
        Missing = sum(missing), Unmapped = sum(unmapped),
        Review_required = any(no | missing | unmapped))
      if (v %in% c("C1", "C2", "C3")) required_granted[[v]] <- yes
      stopifnot(sum(yes) + sum(no) + sum(missing) + sum(unmapped) == length(values))
    }
    audit <- do.call(rbind, rows); rownames(audit) <- NULL
    all_required <- Reduce(function(x, y) x & y, required_granted)
    list(audit = audit, eligibility = data.frame(Total_responses = nrow(values_data),
      All_required_consents_confirmed = sum(all_required),
      Required_consent_review_needed = sum(!all_required), Participants_automatically_excluded = 0L))
  }
  # Check the reviewed QSF still contains the required C1-C3 termination branch.
  qids <- preparation$codebook$questions$question_id[
    match(c("C1", "C2", "C3"), preparation$codebook$questions$export_tag)]
  branches <- preparation$codebook$flow$inherited_branch_json[
    preparation$codebook$flow$type == "EndSurvey"]
  if (!any(vapply(branches, function(b) all(vapply(qids, function(id)
      grepl(id, b, fixed = TRUE), logical(1))), logical(1)))) stop("Consent flow changed; review required.")
  consent <- audit_consents(preparation$csv_data, preparation$codebook$options)
  # Faithful English display translations of the verified QSF questions. Retain
  # exact Italian text separately for traceability, without individual selections.
  consent_definitions <- data.frame(Consent_variable = paste0("C", 1:5),
    Original_question = preparation$codebook$questions$question_text[
      match(paste0("C", 1:5), preparation$codebook$questions$export_tag)],
    English_question = c("Do you consent to participate in the study?",
      "Do you consent to the processing of your personal data for this research, as described in section A of the privacy notice?",
      "Do you consent to the recording and use of your image and voice for the research purposes described in section A of the privacy notice?",
      paste("Do you consent to the analysis of your facial expressions using artificial intelligence tools, respecting the confidentiality measures described in sections A and A1 of the privacy notice?",
        "This analysis will help us better understand consumer perceptions. Consent is optional: you may participate even if you do not consent."),
      paste("Do you consent to the retention and further use of your data for future research, as described in section B of the privacy notice?",
        "Retaining the collected data will allow us to use them for new investigations, extending the scientific contribution of your participation.",
        "Consent is optional: you may participate even if you do not consent.")),
    Permission = c("Study participation", "Personal-data processing for this research",
      "Recording and research use of image and voice", "AI analysis of facial expressions",
      "Data retention and further use for future research"))
  consent_dir <- file.path(root, "consent_audit")
  dir.create(consent_dir, recursive = TRUE, showWarnings = FALSE)
  write_table(consent$audit, file.path(consent_dir, "consent_permission_audit.csv"))
  write_table(consent$eligibility, file.path(consent_dir, "required_consent_summary.csv"))
  write_table(consent_definitions, file.path(consent_dir, "consent_question_definitions.csv"))
  writeLines(c("C1-C3: required in the reviewed QSF participation branch. C4-C5: optional permissions.",
    "Consent is eligibility/permission information, not a substantive research outcome.",
    "Declined, missing and unmapped permissions are flagged; no participants are automatically excluded.",
    "Check permissions relevant to each further analysis. Granted export values are not a blanket authorization."
  ), file.path(consent_dir, "permission_review.txt"))

  # ---- Coverage, methods and review index ----
  response_overview <- do.call(rbind, lapply(names(analyses), function(v) {
    data.frame(Variable = v, Section = analysis_specs[[v]]$section, analyses[[v]]$summary,
      Disclosure_status = if (v %in% demographic_tables_only) "Authorized marginal demographic table" else "Aggregate distribution")
  }))
  rownames(response_overview) <- NULL
  plan <- do.call(rbind, lapply(names(analyses), function(v) {
    data.frame(Variable = v, Section = analysis_specs[[v]]$section, Variable_type = analysis_specs[[v]]$type,
      Summary_method = "Counts and valid-response percentages in questionnaire order",
      Translation_status = analysis_specs[[v]]$translation_status)
  }))
  plan <- rbind(plan, data.frame(Variable = c("C_age", names(text_sections), paste0("C", 1:5)),
    Section = c("sample_characteristics", unname(text_sections), rep("consent_audit", 5)),
    Variable_type = c("quantitative", rep("free text", 4), rep("consent", 5)),
    Summary_method = c("Median, quartiles (R type 7), min-max and conversion flags",
      rep("Whitespace-aware nonblank/blank counts only", 4), rep("Eligibility/permission audit only", 5)),
    Translation_status = "No individual responses translated"))
  rownames(plan) <- NULL
  stopifnot(setequal(plan$Variable, unique(preparation$dictionary$variable)),
    all(response_overview$Total_responses == nrow(preparation$csv_data)))
  write_table(response_overview, file.path(root, "categorical_response_overview.csv"))
  write_table(plan, file.path(root, "descriptive_plan.csv"))
  write_table(font_report, file.path(root, "font_report.csv"))
  writeLines(c("Approved methods: separate ordinal item counts/percentages; no means, scores, collapsing or combined scales.",
    "Non-reader options remain explicit valid responses. No analysis restricted to label readers.",
    "Percentages use each item's valid mapped responses. Never is a valid category.",
    "Age: median/quartiles (R type 7), min-max and flags; user-approved comparison bands 18-30, 31-55, 56+.",
    "Free text: whitespace-aware nonblank/blank counts only. No individual responses or thematic coding.",
    "Consent audit is separate; permissions must be reviewed before relevant further analysis.",
    "All participants retained. Source data, codebook definitions and existing imported objects unchanged.",
    "User-authorized marginal gender, education and occupation tables. No combinations or individual age points.",
    "Education grouping is comparison-only: bachelor's plus master's/higher. Original four categories are preserved.",
    "Translation review: education qualification labels are descriptive; international equivalence is not assumed.",
    "Colours are provisional EUAqua approximations. Font availability/fallback is recorded in font_report.csv.",
    "These results apply only to the pilot sample."
  ), file.path(root, "methodological_decisions.txt"))
  charts <- vapply(analyses, function(a) if (is.null(a$chart)) NA_character_ else a$chart_path, "")
  cat("Complete descriptive coverage:", nrow(plan), "variables, including consent and free-text audits.\n")
  cat("Substantive categorical items:", length(analyses), "| charts:", sum(!is.na(charts)), "\n")
  cat("Categorical missing:", sum(response_overview$Missing_responses),
    "| unmapped:", sum(response_overview$Unmapped_nonmissing_responses), "\n")
  cat("Age missing:", age_summary$Missing_responses, "| invalid:", age_summary$Invalid_nonmissing_responses,
    "| range flags:", age_summary$Outside_QSF_range, "| noninteger flags:", age_summary$Noninteger_values, "\n")
  cat("Consent issues requiring review:", sum(consent$audit$Review_required), "| automatically excluded: 0\n")
  cat("Marginal demographic tables authorized; no demographic charts or combinations. Pilot sample only.\n")

  list(analyses = analyses, response_overview = response_overview, age_summary = age_summary,
    age_bands = age_bands, age_band_summary = age_band_summary, education_comparison = education_comparison,
    consent_definitions = consent_definitions,
    free_text_availability = free_text_availability, consent_audit = consent$audit,
    eligibility_summary = consent$eligibility, descriptive_plan = plan, chart_paths = charts,
    summarise_age = summarise_age, summarise_text = summarise_text, audit_consents = audit_consents,
    frequency_table = frequency_table, summary = summary,
    option_definitions = option_definitions, unmapped_values = counted$unmapped,
    font_report = font_report, chart = chart, chart_path = chart_path,
    count_options = count_options, options = options)
})
