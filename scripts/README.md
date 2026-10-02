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

## First descriptive analysis

Run `source("scripts/03_describe_qualtrics.R")` from the RStudio project root.
It sources preparation in a separate environment and applies the shared theme
from `euaqua_plot_theme.R`. Required packages are `readxl`, `jsonlite`, `xml2`,
`ggplot2`, `systemfonts`, and `ragg`. If needed, install them with
`install.packages(c("readxl", "jsonlite", "xml2", "ggplot2", "systemfonts", "ragg"))`.

The analysis describes `D_fish_freq` for this pilot sample. It retains all five
QSF options, including zero counts, in questionnaire order. English display labels
are stored separately from the original Italian definitions. The translations
have no identified uncertainty. The ordering comes from QSF display positions,
not sorting by exported codes or arranging responses by frequency.

Valid responses have a nonblank value with an unambiguous export-confirmed mapping.
Only NA and empty strings are missing; whitespace is not trimmed. Unmapped
nonmissing values are reported separately. No participant rows are removed.
Percentages are `100 * option count / valid mapped responses`; the denominator is
shown in the summary and chart caption. If there are no valid responses, percentages
are undefined. Unobserved options are included with zero counts without assigning
unconfirmed numeric codes. In particular, an unconfirmed QSF choice ID is never
treated as an exported code. Unexpected text in unmapped values is withheld;
unknown numeric codes are reported only as aggregate code counts.

Counts are checked independently against the Excel Labels export. Internal checks
verify the total/valid/missing/unmapped partition and percentage sum. Existing
imported objects and original files are preserved. Only aggregate outputs and
definition tables are saved; no participant-level dataset is written.

Outputs are in `outputs/pilot-ita-30092026/descriptive/D_fish_freq/`, ignored by Git:

- `frequency_table.csv`: English response options, counts, and percentages.
- `response_summary.csv`: total, valid, missing, unmapped, and denominator counts.
- `option_definitions.csv`: questionnaire order, original Italian labels, English
  display labels, separately recorded QSF IDs and confirmed codes, and review status.
- `unmapped_values.csv`: aggregate unmatched codes, with nonnumeric values withheld.
- `font_report.csv`: font availability and actual regular/bold font resolution.
- `D_fish_freq_bar_chart.png`: blue bars, all options, and an explicit denominator.
- `analysis_notes.txt`: definitions and limits for interpreting this pilot sample.

The script exports PNG with ragg at 180 dpi and resolves fonts with systemfonts.
Inspect the rendered chart after rerunning; future font installations may change
the resolved family. Palette and font policy are documented in `AGENTS.md`.
Generated files at these paths are replaced on rerun.

In RStudio, use `View(euaqua_descriptive_analysis$frequency_table)` to review the
aggregate table. Run `print(euaqua_descriptive_analysis$chart)` to show the chart in
the **Plots** pane, or open the exported PNG from **Files**. The source data and
codebook keep their original wording and variable names.
