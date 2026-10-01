# Qualtrics preparation

Run scripts from the RStudio project root.

1. `source("scripts/01_import_qualtrics.R")` imports the Values CSV.
2. `source("scripts/02_prepare_qualtrics.R")` imports both exports, validates
   response matching, and prepares a local dictionary for review.

The second script requires `readxl` (verified with version 1.4.5). If absent,
install it with `install.packages("readxl")`. No other external package is needed.

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

The exports establish only observed options, not the complete questionnaire response
scales. Unselected options and their codes must be verified against the questionnaire
or a codebook before assigning factor levels or interpreting missing categories.
Mappings flagged as ambiguous require review before use.

Only a dictionary and aggregate checks are written to the ignored folder
`outputs/pilot-ita-30092026/qualtrics_preparation/`. Original files are never written
and their checksums are verified. Existing preparation outputs at those paths are
replaced when rerunning the script. No participant-level dataset is saved.

Review safely in RStudio with `View(qualtrics_preparation$dictionary)`.
Do not print or open the full imported response objects for a shared demonstration.
