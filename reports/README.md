# Pilot report

Open the existing RStudio project and run:

```r
source("reports/render_pilot_report.R")
```

The report uses R Markdown, the simplest report engine available in this environment.
Additional report dependencies are `rmarkdown`, `knitr`, `htmltools`, `xml2`, and
Pandoc (available through RStudio); analysis dependencies remain documented in the
existing scripts. Nothing is installed or downloaded by the renderer.

The renderer executes `scripts/03_describe_qualtrics.R` in an isolated environment,
then supplies only permitted aggregates to `pilot_report.Rmd`. It verifies the
frequency tables and age summary against the existing CSV exports. It does not
implement another response-processing pipeline. The original analysis scripts and
fish-consumption chart are unchanged. Consent results and individual records never
enter the report template; demographic distributions remain withheld.

Open `outputs/pilot-ita-30092026/report/EUAqua_pilot_report.html` in a browser.
Keep the entire report folder together when moving the HTML: charts and CSS are
local assets. The folder also contains numerical verification and session details.
Use the browser's print preview to review its A4 print layout. Generated HTML,
assets, numerical outputs and any print PDFs must remain under ignored `outputs/`.

The report date defaults to the date of rendering in Europe/Copenhagen. To rebuild
with an explicit date after sourcing, use `render_euaqua_pilot_report(report_date =
as.Date("YYYY-MM-DD"))` with the intended report date.

Pilot-date provenance: the saved project executive Gantt,
`EUAQUA_WP4_Executive_Gantt_2026-2027.numbers`, states “Pilot scheduled for 30
September 2026”. This was verified against the local saved workbook, consistently
with the pilot archive name. It documents the scheduled session date, rather than
questionnaire completion dates. Correct the metadata if the actual session differed.

All numerical findings are generated dynamically. Dates and questionnaire wording
are study metadata, not analytical findings. Palette and font selection come from
`scripts/euaqua_plot_theme.R`; colours are provisional approximations. Education
translations and the demographic disclosure rule remain flagged for review. No
appropriate official logo asset was found in this workspace.

Verification status: the HTML has rendered successfully and its numerical fields
have passed automated checks. All existing chart images have been inspected.
The in-app browser blocked the local-file preview, so full HTML typography,
browser font resolution and print pagination remain pending a manual browser
review. Treat this as a draft until those checks are completed.
