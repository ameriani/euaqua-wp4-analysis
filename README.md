# euaqua-wp4-analysis
EUAqua WP4-4.2 research analysis

## Dati e risultati locali

GitHub contiene codice e documentazione del progetto. I dati dei partecipanti
e i risultati individuali devono restare fuori dalla cronologia Git.

- `data/raw/`: esportazioni originali Qualtrics, da conservare senza modificarle.
- `data/processed/`: dati puliti e dataset per l'analisi.
- `results/individual/`: tabelle, grafici e report riferiti ai singoli partecipanti.
- `outputs/`: altri risultati dell'analisi, esclusi da Git per impostazione iniziale.
- `exports/`: esportazioni locali, escluse da Git.

Queste cartelle e i principali formati di dati sono esclusi tramite `.gitignore`.
Salvare i file dei partecipanti soltanto nelle cartelle escluse: un PDF, un'immagine
o un file di testo salvato altrove potrebbe essere incluso in Git.
Non inserire risposte, nomi, email o identificativi dei partecipanti nel codice,
nei documenti condivisi o nei messaggi di commit. Non forzare l'aggiunta dei file
ignorati con `git add -f`.

Prima di ogni commit, controllare l'elenco dei file e le modifiche in GitHub Desktop.
Eventuali risultati aggregati da condividere richiedono prima una verifica del
contenuto e una scelta esplicita della cartella da pubblicare.

`.gitignore` non rimuove file già registrati nella cronologia Git e non protegge
da altre forme di condivisione o sincronizzazione della cartella locale.
