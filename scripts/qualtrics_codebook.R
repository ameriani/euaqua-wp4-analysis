# Build questionnaire definitions without exposing participant values.
build_qualtrics_codebook <- function(qsf_path, csv_metadata, excel_metadata, observed) {
  for (package in c("jsonlite", "xml2")) {
    if (!requireNamespace(package, quietly = TRUE)) {
      stop(paste("Required package missing:", package))
    }
  }
  qsf <- jsonlite::fromJSON(qsf_path, simplifyVector = FALSE)
  json <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
  value <- function(x) if (is.null(x) || !length(x)) "" else as.character(x)
  # Comparison/display only. Exact source HTML is retained in separate columns.
  plain <- function(x) {
    x <- value(x)
    if (!nzchar(x)) return("")
    x <- gsub("\\r\\n", " ", x, fixed = TRUE)
    x <- gsub("\\n", " ", x, fixed = TRUE)
    x <- gsub("</p>|<br\\s*/?>", " ", x, ignore.case = TRUE)
    text <- xml2::xml_text(xml2::read_html(paste0("<html><body>", x, "</body></html>")))
    trimws(gsub("[[:space:]\u00a0]+", " ", text, perl = TRUE))
  }
  elements <- qsf$SurveyElements
  questions <- lapply(Filter(function(e) identical(e$Element, "SQ"), elements), `[[`, "Payload")
  blocks <- Filter(function(e) identical(e$Element, "BL"), elements)[[1]]$Payload
  flow <- Filter(function(e) identical(e$Element, "FL"), elements)[[1]]$Payload
  if (anyDuplicated(vapply(questions, function(p) p$QuestionID, ""))) {
    stop("Duplicate QSF question IDs.")
  }
  all_keys <- function(x) if (is.list(x)) c(names(x), unlist(lapply(x, all_keys))) else character()
  recode_entries <- sum(all_keys(questions) == "RecodeValues")
  if (recode_entries > 0L) stop("Explicit recodes found; review mapping method.")
  descriptions <- function(x) {
    if (!is.list(x)) return(character())
    here <- if (!is.null(x[["Description"]])) plain(x[["Description"]]) else character()
    c(here, unlist(lapply(x[setdiff(names(x), "Description")], descriptions)))
  }

  flow_rows <- list()
  walk <- function(nodes, path = "Root", inherited = "") {
    for (i in seq_along(nodes)) {
      n <- nodes[[i]]
      current <- paste0(path, "/", i)
      condition <- if (!is.null(n$BranchLogic)) json(n$BranchLogic) else ""
      context <- paste(c(inherited, condition)[nzchar(c(inherited, condition))], collapse = " AND ")
      flow_rows[[length(flow_rows) + 1L]] <<- data.frame(
        path = current, type = value(n$Type), flow_id = value(n$FlowID),
        block_id = value(n$ID), inherited_branch_json = context,
        branch_text = paste(descriptions(n$BranchLogic), collapse = " | "),
        node_json = json(n[setdiff(names(n), "Flow")]), stringsAsFactors = FALSE
      )
      if (!is.null(n[["Flow"]])) walk(n[["Flow"]], current, context)
    }
  }
  walk(flow$Flow)
  flow_table <- do.call(rbind, flow_rows)
  question_rows <- list(); option_rows <- list(); links <- list()
  for (p in questions) {
    id <- p$QuestionID; tag <- p$DataExportTag
    membership <- Filter(function(b) any(vapply(b$BlockElements, function(e)
      identical(e$QuestionID, id), logical(1))), blocks)
    b <- if (length(membership)) membership[[1L]] else list()
    active <- !identical(b$Type, "Trash") && value(b$ID) %in% flow_table$block_id
    import_ids <- vapply(csv_metadata$import_metadata, function(x)
      value(jsonlite::fromJSON(x)$ImportId), "")
    # Link export columns via their explicit ImportId, never via response codes.
    linked <- csv_metadata$variable[import_ids == id | startsWith(import_ids, paste0(id, "_"))]
    question_rows[[length(question_rows) + 1L]] <- data.frame(
      question_id = id, export_tag = tag, question_type = p$QuestionType,
      selector = value(p$Selector), subselector = value(p$SubSelector),
      question_html_exact = value(p$QuestionText), question_text = plain(p$QuestionText),
      block_id = value(b$ID), block_name = value(b$Description), active_in_flow = active,
      block_element_position = if (length(b$BlockElements)) which(vapply(
        b$BlockElements, function(e) identical(e$QuestionID, id), logical(1)))[1L] else NA_integer_,
      block_flow_path = paste(flow_table$path[flow_table$block_id == value(b$ID)], collapse = "; "),
      exported_variables = paste(linked, collapse = "; "),
      validation_json = json(p$Validation), display_logic_json = json(p$DisplayLogic),
      in_page_display_logic_json = json(p$InPageDisplayLogic),
      display_logic_text = paste(c(descriptions(p$DisplayLogic),
                                   descriptions(p$InPageDisplayLogic)), collapse = " | "),
      skip_logic_json = json(p$SkipLogic), configuration_json = json(p$Configuration),
      choices_order_json = json(p$ChoiceOrder), answers_order_json = json(p$AnswerOrder),
      payload_json_exact = json(p), stringsAsFactors = FALSE
    )
    for (variable in linked) {
      imported <- import_ids[match(variable, csv_metadata$variable)]
      suffix <- substring(imported, nchar(id) + 2L)
      item <- if (identical(p$QuestionType, "Matrix")) plain(p$Choices[[suffix]]$Display) else ""
      links[[length(links) + 1L]] <- data.frame(
        variable = variable, question_id = id, question_html_exact = value(p$QuestionText),
        question_text = plain(p$QuestionText), matrix_item_text = item,
        text_entry = endsWith(imported, "_TEXT"), import_id = imported,
        stringsAsFactors = FALSE
      )
    }
    for (axis in c("Choices", "Answers")) {
      options <- p[[axis]]
      if (is.null(options) || !length(options)) next
      order_ids <- as.character(unlist(p[[if (axis == "Choices") "ChoiceOrder" else "AnswerOrder"]]))
      option_ids <- unique(c(order_ids, names(options)))
      for (option_id in option_ids) {
        option <- options[[option_id]]
        if (is.null(option)) stop("QSF option order references an absent option.")
        label <- plain(option$Display)
        is_response <- p$QuestionType == "MC" || (p$QuestionType == "Matrix" && axis == "Answers")
        variables <- if (is_response) linked[!endsWith(linked, "_TEXT")] else ""
        if (!length(variables)) variables <- ""
        for (variable in variables) {
          candidates <- observed[observed$variable == variable & !is.na(observed$observed_label), ]
          hit <- vapply(candidates$observed_label, plain, "") == label
          unique_qsf_label <- sum(vapply(options, function(o) plain(o$Display), "") == label) == 1L
          codes <- unique(candidates$observed_code[hit])
          ambiguous_code <- any(vapply(codes, function(code)
            length(unique(candidates$observed_label[candidates$observed_code == code])) > 1L, logical(1)))
          status <- if (!is_response) "Matrix item; not a response code" else
            if (!nzchar(variable)) "No export column; numeric mapping unconfirmed" else
              if (!length(codes)) "Unobserved option; numeric mapping unconfirmed" else
                if (!unique_qsf_label || length(codes) != 1L || ambiguous_code)
                  "Ambiguous mapping; not confirmed" else "Confirmed by matched Values/Labels exports"
          option_rows[[length(option_rows) + 1L]] <- data.frame(
            question_id = id, export_tag = tag, active_in_flow = active, variable = variable,
            axis = axis, qsf_option_id = option_id, display_position = match(option_id, order_ids),
            option_html_exact = value(option$Display), option_label = label,
            text_entry = identical(value(option$TextEntry), "true"),
            exported_code = if (status == "Confirmed by matched Values/Labels exports") codes else NA_character_,
            mapping_status = status, option_rules_json = json(option),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  question_table <- do.call(rbind, question_rows)
  options_table <- do.call(rbind, option_rows)
  variable_table <- do.call(rbind, links)
  if (!setequal(variable_table$variable, unique(observed$variable))) {
    stop("QSF links do not cover the observed research dictionary exactly.")
  }
  wording <- do.call(rbind, lapply(c("C4", "C5"), function(tag) {
    p <- questions[[which(vapply(questions, function(p) p$DataExportTag == tag, logical(1)))]]
    csv <- csv_metadata$label[match(tag, csv_metadata$variable)]
    excel <- excel_metadata$label[match(tag, excel_metadata$variable)]
    data.frame(variable = tag, csv_heading_exact = csv, excel_heading_exact = excel,
      qsf_question_html_exact = p$QuestionText, qsf_question_text = plain(p$QuestionText),
      exports_equal_after_format_normalization = identical(plain(csv), plain(excel)),
      csv_matches_qsf_after_format_normalization = identical(plain(csv), plain(p$QuestionText)),
      excel_matches_qsf_after_format_normalization = identical(plain(excel), plain(p$QuestionText)),
      stringsAsFactors = FALSE)
  }))
  # Retain unmatched observed labels as explicit review issues, never drop silently.
  issues <- observed[!is.na(observed$observed_code), c("variable", "observed_code", "observed_label")]
  covered <- vapply(seq_len(nrow(issues)), function(i) any(
    options_table$variable == issues$variable[i] &
      !is.na(options_table$exported_code) & options_table$exported_code == issues$observed_code[i] &
      options_table$option_label == plain(issues$observed_label[i])), logical(1))
  issues <- issues[!covered, , drop = FALSE]
  list(questions = question_table, options = options_table, variables = variable_table,
       flow = flow_table, wording = wording, mapping_issues = issues,
       recode_entries = recode_entries, qsf = qsf)
}
