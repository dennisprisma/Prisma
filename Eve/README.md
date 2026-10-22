# Eve — impostazione

Eve è l'assistente AI di Prisma: legge documenti, prospetti e dati dei clienti, li capisce e risponde in chat con spiegazioni, dati e commenti. Tutto avviene sul Mac: nessun dato esce dal computer.

## Storia
Una prima versione di Eve usava modelli Qwen verticalizzati sull'app. Funzionava, ma report e prospetti non venivano bene. Quel lavoro è andato perso: si riparte da zero, e da ora tutto ciò che riguarda Eve (istruzioni, schemi, esempi, test) vive in questa cartella, sotto controllo di versione.

## Principio guida: Eve estrae e spiega, l'app calcola e impagina
- I modelli piccoli capiscono ed estraggono bene, ma sono poco affidabili nei calcoli e nell'impaginare documenti lunghi.
- Eve quindi **non scrive il prospetto intero**: legge i documenti ed estrae i dati in forma strutturata (importi, scadenze, rendimenti, costi, coperture).
- I **numeri li calcola l'app** con i motori di calcolo di Prisma, senza errori.
- I **report li impagina l'app** con modelli grafici fissi, coerenti con il tema iOS 5. Eve aggiunge solo i testi di commento.
- Ogni dato estratto viene **confermato dall'utente** prima di essere salvato, con il riferimento alla pagina del documento da cui viene.

## Motori (intercambiabili)
Protocollo Swift unico, così il motore si cambia senza riscrivere l'app. Capacità richieste:
- disponibilità a runtime (con messaggio chiaro se il motore non è utilizzabile)
- chat con risposta progressiva
- estrazione strutturata secondo uno schema
- uso di strumenti dell'app (vedi sotto)

1. **Modello Apple integrato** (framework FoundationModels, sul dispositivo) — primo motore.
   - Zero spazio su disco, zero costi, memoria gestita dal sistema.
   - Generazione guidata: restituisce dati strutturati garantiti secondo lo schema.
   - Richiede macOS 26 o successivo e Apple Intelligence attiva: l'app resta compatibile con macOS 13 e su sistemi più vecchi Eve mostra un messaggio chiaro.
   - Finestra di contesto limitata (circa 4.000 token): i documenti lunghi vanno letti a pezzi (pagina o sezione), estraendo da ciascun pezzo e poi unendo i risultati nell'app.
2. **Qwen 3-4B in locale** — eventuale, solo per i compiti dove il modello Apple non basta.
   - Circa 2-3 GB di RAM: è la taglia massima sensata sul MacBook Pro M1 da 8 GB. Un 7-8B (circa 5 GB) metterebbe il Mac in affanno.
   - Richiede una libreria esterna per l'esecuzione: va chiesto prima di aggiungerla.

## Lettura dei documenti (strumenti nativi, nessuna dipendenza)
- PDF con testo: PDFKit.
- PDF scansionati e immagini: riconoscimento del testo di Vision, sul dispositivo.
- Documenti tipici: KID, set informativi e prospetti, polizze, estratti conto, proposte Alleanza e di altre compagnie.

## Strumenti che Eve può usare
Eve non calcola da sola: chiede all'app. Esempi:
- cercare un cliente e leggerne la scheda
- elencare le posizioni (in essere e non in essere) con il canale Alleanza / indipendente
- leggere scadenze e appuntamenti
- lanciare un calcolo dei motori di Prisma (proiezioni, gap previdenziale, gap di protezione, confronti) e commentarne il risultato

## Eve e i documenti di analisi
Gli spunti di Eve (check-up, resoconto, pensione, protezione, liquidità, obiettivi, restare o cambiare) usano gli stessi motori dei prospetti e dei report (`Sources/Prisma/Eve/AnalisiEve.swift`): le cifre in chat e sui documenti coincidono. Da Prospetti e report il pulsante «Chiedi a Eve» apre la spiegazione del documento aperto. Con il modello Apple le cifre arrivano come bozza (spunti) o come calcoli pertinenti (domande libere riconosciute dalle parole chiave); senza modello risponde la sintesi dai dati.

## Contenuto della cartella
- `Istruzioni/` — istruzioni di sistema e prompt per ogni compito (chat, estrazione, commento ai report).
- `Schemi/` — schemi dei dati da estrarre (es. polizza, KID, estratto conto, proposta).
- `Esempi/` — esempi per verticalizzare Eve, con documenti anonimizzati: mai dati veri di clienti.
- `Valutazione/` — casi di prova con il risultato atteso, per misurare la qualità dell'estrazione e confrontare i motori.

## Build
- Il framework FoundationModels si compila solo con l'SDK di macOS 26.
- Verificato il 21/10/2026: il runner `macos-15-intel` ha installati anche Xcode 26.0–26.3 (il predefinito è 16.4). Quando si arriva a Eve basta selezionare Xcode 26.3 nel workflow con `DEVELOPER_DIR`, senza cambiare runner. Riguarda solo il server di build, non il Mac dell'utente.
- Il codice che usa FoundationModels va protetto con `#if canImport(FoundationModels)` e `@available(macOS 26, *)`, così l'app resta compatibile con macOS 13.
