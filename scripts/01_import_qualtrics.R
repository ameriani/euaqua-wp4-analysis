# Eseguire dal progetto RStudio euaqua-wp4-analysis.
# Questo script legge il CSV senza modificarlo e non salva dati su disco.

csv_path <- file.path(
  "data", "raw", "pilot-ita-30092026", "01_Qualtrics",
  "Pilot_Qualtrics_Values_2026-10-01.csv"
)
if (!file.exists(csv_path)) {
  stop("CSV non trovato. Aprire il progetto .Rproj e verificare il percorso.")
}

# read.csv gestisce anche le etichette con virgole o ritorni a capo.
# La prima riga diventa i nomi delle colonne. Tutte le celle restano testo:
# nessuna conversione automatica di date, codici o valori mancanti.
qualtrics_export <- read.csv(
  csv_path,
  header = TRUE,
  colClasses = "character",
  check.names = FALSE,
  na.strings = NULL,
  fileEncoding = "UTF-8-BOM",
  comment.char = "",
  fill = FALSE,
  blank.lines.skip = FALSE
)

# Verificare la struttura prima di separare le due righe di metadati.
if (nrow(qualtrics_export) < 2L || ncol(qualtrics_export) == 0L) {
  stop("L'esportazione non contiene le due righe di metadati attese.")
}
has_import_id <- function(row) {
  all(grepl('"ImportId"', as.character(unlist(row)), fixed = TRUE))
}
if (has_import_id(qualtrics_export[1L, , drop = FALSE]) ||
    !has_import_id(qualtrics_export[2L, , drop = FALSE])) {
  stop("Intestazioni Qualtrics inattese: importazione interrotta per verifica.")
}
if (any(!nzchar(names(qualtrics_export))) || anyDuplicated(names(qualtrics_export))) {
  stop("Nomi di variabili vuoti o duplicati: verificare l'esportazione.")
}

# Conservare i metadati separatamente per la successiva verifica delle etichette.
qualtrics_dictionary <- data.frame(
  variable = names(qualtrics_export),
  label = as.character(unlist(qualtrics_export[1L, ], use.names = FALSE)),
  import_metadata = as.character(unlist(qualtrics_export[2L, ], use.names = FALSE)),
  stringsAsFactors = FALSE
)

# Le prime due righe sono metadati, non risposte. Nessuna risposta viene filtrata.
qualtrics_data <- qualtrics_export[-c(1L, 2L), , drop = FALSE]
rownames(qualtrics_data) <- NULL
rm(qualtrics_export)

# Stampare soltanto un riepilogo strutturale, senza valori dei partecipanti.
cat("Righe di metadati Qualtrics riconosciute: 2 (etichette e ImportId)\n")
cat("Risposte importate:", nrow(qualtrics_data), "\n")
cat("Variabili:", ncol(qualtrics_data), "\n")
cat("Colonna ResponseId presente:", "ResponseId" %in% names(qualtrics_data), "\n")
cat("Colonna PID presente:", "PID" %in% names(qualtrics_data), "\n")
