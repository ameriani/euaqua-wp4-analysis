# Qualtrics preparation

Run scripts from the RStudio project root.

1. `source("scripts/01_import_qualtrics.R")` imports the Values CSV.
2. `source("scripts/02_prepare_qualtrics.R")` imports both exports, validates
   response matching, and uses the QSF to prepare a complete questionnaire codebook.

The second script requires `readxl` (verified with version 1.4.5), `jsonlite`, and
`xml2`. If absent, install them with
`install.packages(c("readxl", "jsonlite", "xml2"))`. The helper
`qualtrics_codebook.R` is sourced automatically; do not run it separately.

The CSV importer runs in a separate environment so existing imported objects are
not overwritten. The Excel reader retains all cells as text, without trimming.
Missing and duplicate ResponseId values and unequal response sets prevent matching.
ResponseId determines the matching order; PID is checked afterward. Blank PID,
duplicate nonblank PID and PID mismatches are reported as aggregate counts without
excluding responses. Empty strings in CSV and empty cells represented as NA in
Excel are equivalent only for comparison; neither source object is recoded.

`qualtrics_preparation$dictionary` contains research and consent variable
definitions and observed categorical code-label pairs. It preserves both exports'
question headings and flags differences, nonunique mappings, missing pairs, and
unexpected code formats. Age and free-text entry values are withheld. Administrative
metadata and participant identifiers are not included. Consent variables are marked
separately from research categories. Classifications are explicit and require review
if the variable set changes; they do not alter the data.

The observed dictionary still describes only observed options. The separate
`qualtrics_preparation$codebook` uses the unchanged QSF to list all 29 question
elements, marking the 27 active elements separately from the two unused elements.
It includes exact Italian HTML, readable text, all choices, matrix rows and scale
answers, display order, text-entry options, validation settings, display/skip logic,
block membership, and survey-flow nodes with inherited branch conditions. Raw rule
JSON and complete question payloads are retained so unparsed settings are not lost.
Question elements include instructional text, not only response questions.

Exported variables are linked through CSV ImportId metadata. Categorical response
codes are confirmed only through matched Values/Labels pairs and unique normalized
QSF option labels. Choice IDs and matrix answer IDs remain separate identifiers;
they are never assigned as exported codes. No RecodeValues entries are present.
Unobserved options retain missing exported codes and explicit unconfirmed status;
ambiguous matches and unmatched observed mappings are flagged. Complete option
labels are available, but complete numeric coding is not confirmed.

The `codebook$wording` comparison confirms that C4 and C5 differ between exports
only in literal line-break representation (CSV `\n\n`, Excel `\r\n\r\n`). After
format normalization, both agree with the QSF wording. Exact source text is retained;
normalization is used only for definition matching and readable display, never responses.

The QSF shows an in-page consent warning and an end-survey branch for selecting
"Non acconsento" on any of C1, C2, or C3. C4 and C5 are not in that branch.
The subsequent demographic, food-habit, and opinion blocks follow in order.
Age has numeric validation from 18 to 100. These are questionnaire definitions,
not analysis exclusions or evidence that every collected response meets those rules.

Only dictionaries, questionnaire definitions/rules, and aggregate checks are written to the ignored folder
`outputs/pilot-ita-30092026/qualtrics_preparation/`. Original files are never written
and their checksums are verified. Existing preparation outputs at those paths are
replaced when rerunning the script. No participant-level dataset is saved.

Review safely in RStudio with `View(qualtrics_preparation$codebook$questions)` and
`View(qualtrics_preparation$codebook$options)`. The `variables`, `flow`, `wording`, and
`mapping_issues` tables provide links, rule context, and review flags. Local files
are named `codebook_<table>.csv`; raw QSF metadata is not published to GitHub.
Do not print or open the full imported response objects for a shared demonstration.

## Complete descriptive analysis

Run from the RStudio project root:

```r
source("scripts/03_describe_qualtrics.R")
```

Preparation runs in a separate environment, preserving existing data/codebook objects.
Required packages are `readxl`, `jsonlite`, `xml2`, `ggplot2`, `systemfonts`, and `ragg`.
Reusable chart builders and PNG export are in `euaqua_plot_theme.R`.
All tables and charts describe this pilot sample only.

The script contains clearly marked sections for sample characteristics, purchasing
and dietary habits, label/sustainability perceptions, free-text availability, and
a separate consent audit. It covers 16 substantive categorical items, quantitative
age, four free-text fields, and five consent fields. Unused QSF questions,
instructional elements, respondent identifiers and administrative metadata are not
substantive descriptive outcomes.

### Approved methods

- Categorical and ordinal items: all options in questionnaire order, including
  zeros. Count only values with export-confirmed mappings. Report total, valid,
  missing and unmapped values separately. Percentages are
  `100 * category count / valid mapped responses`.
  NA and empty strings are missing. Other values are not silently trimmed.
- Explicit options such as Never and I do not read labels stay valid categories.
  Non-readers remain inside each item's denominator. No reader-only analyses.
- Health/environment/price attention and trust/comprehension/overload are separate
  items. No ordinal means, scores, category collapsing or combined indices.
- Age: valid finite numeric count, missing count, invalid nonblank count, median,
  first/third quartiles and min-max. R `quantile(type = 7)`
  uses linear interpolation with `h = 1 + (n - 1) * p`.
  Conversion creates a numerical copy; originals stay unchanged. Whitespace-only
  ages are missing. Nonnumeric/nonfinite entries cannot enter the numerical summary
  and are counted separately. Out-of-range and noninteger finite values are flagged
  and retained in summaries. The bounds come from QSF validation. No age bands.
- Free text: only nonblank/blank counts among all retained responses. Unicode
  whitespace and invisible zero-width/BOM characters count as blankness when no
  other content is present. No individual text, quotations or thematic coding.
- Consent: C1-C3 form the reviewed participation-consent branch; C4-C5 are optional
  permissions. Granted/declined/missing/unmapped counts are a separate audit.
  Flags require review before relevant further analyses; no automatic exclusions.

### Privacy and translations

Gender, education and occupation distributions are checked internally, but all
subgroup counts/percentages are withheld in saved tables, and no demographic charts
are exported. Completeness counts and questionnaire definitions remain available.
No cross-tabulations, demographic combinations or individual age points are shown.
A disclosure rule is still needed before demographic subgroup results are released.

English display labels are separate from the original Italian questionnaire and
codebook definitions. Option definitions link both languages, keeping QSF IDs
separate from exported codes. Education translations are flagged for review:
they describe Italian qualifications and do not establish international equivalence.

### Outputs and review

Generated files are ignored by Git under
`outputs/pilot-ita-30092026/descriptive/`.
Subfolders are:

- `sample_characteristics/<variable>/`: protected categorical tables, age
  numerical summary, and availability tables for demographic text fields.
- `purchasing_and_dietary_habits/<variable>/`: grocery responsibility, diet,
  separate attention items, and diet text availability.
- `label_and_sustainability_perceptions/<variable>/`: label/perception items,
  fish preference, awareness, and fish preference text availability.
- `consent_audit/`: permission audit, required-consent summary, and review notes.
- The existing fish-consumption folder `D_fish_freq/` and its original filenames
  are preserved for backward compatibility.

Each categorical folder has `frequency_table.csv`, `response_summary.csv`,
`option_definitions.csv`, `unmapped_values.csv`, and `analysis_notes.txt`.
Eligible charts are named `<variable>_bar_chart.png`.
Age has `age_summary.csv`; free-text fields have `text_availability.csv`.
Root files `descriptive_plan.csv`, `categorical_response_overview.csv`,
`free_text_availability.csv`, `font_report.csv`, and `methodological_decisions.txt`
provide a review index and document the denominator/disclosure decisions.
Generated files are replaced on rerun; no participant-level datasets are written.

Review safely in RStudio:

```r
View(euaqua_descriptive_analysis$response_overview)
View(euaqua_descriptive_analysis$age_summary)
View(euaqua_descriptive_analysis$free_text_availability)
View(euaqua_descriptive_analysis$consent_audit)
View(euaqua_descriptive_analysis$analyses$E_label_trust$frequency_table)
print(euaqua_descriptive_analysis$analyses$E_label_trust$chart)
```

The original fish result remains available as
`euaqua_descriptive_analysis$frequency_table` and
`euaqua_descriptive_analysis$chart`.
Open exported PNGs from the RStudio Files pane to inspect actual rendering.

Counts are checked against Excel Labels and percentages against their stated
denominator. Source objects and files are preserved. Each export uses ragg at
180 dpi, with systemfonts resolving regular/bold font families. Report the further
fallback if Montserrat and Calibri are absent. Visually inspect exported charts
after rerunning, particularly when fonts or labels change. The shared colours
remain provisional approximations, as documented in AGENTS.md.
