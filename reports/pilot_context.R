# Public contextual metadata supplied by the user, separate from observed results.
# Sources checked on 2 October 2026. Rendering does not fetch changing online data.
euaqua_pilot_context <- list(
  demographic_url = "https://demo.istat.it/app/?i=POS&l=ita",
  education_url = "https://www.istat.it/comunicato-stampa/livelli-di-istruzione-e-ritorni-occupazionali-anno-2024/",
  education_pdf = "https://www.istat.it/wp-content/uploads/2025/12/Report-Livelli-di-istruzione-e-ritorni-occupazionali-Anno-2024.pdf",
  sex_benchmark = c(Woman = 51.36, Man = 48.64),
  sex_target = c(Woman = 5L, Man = 5L),
  age_benchmark = c("18-30" = 15.71, "31-55" = 38.13, "56+" = 46.16),
  age_target = c("18-30" = 3L, "31-55" = 4L, "56+" = 3L),
  education_benchmark = c(33.3, 44.4, 22.3), education_target = c(0L, 6L, 4L),
  demographic_status = "Supplied benchmarks pending verification",
  demographic_population = "Residents aged 18+, 1 January 2026; estimated data",
  education_status = paste("44.4% and 22.3% verified in the ISTAT release; 33.3% is 100% minus",
    "the published 66.7% with at least upper secondary education (PDF, page 2)."),
  education_population = "Residents aged 25-64 in private households, 2024",
  seafood_target = "Mix of frequent and occasional consumers; no numerical quota",
  statement = paste("ISTAT distributions provide contextual benchmarks; the group should not be",
    "described as demographically representative of the Italian adult population.")
)
