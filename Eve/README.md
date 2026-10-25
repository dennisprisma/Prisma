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

## Eve e i documenti del cliente
Da Documenti, «Chiedi a Eve» spiega un KID, una polizza o un estratto conto (`Sources/Prisma/Eve/DocumentiEve.swift`): i dati trovati con la pagina, il rischio e il periodo raccomandato letti con il profilo del cliente, i costi, cosa non torna con la posizione collegata, i dati ancora da confermare e quelli da verificare nelle condizioni. Lo spunto «Cosa dicono i documenti?» riassume tutti i documenti del cliente. Con il modello Apple la spiegazione diventa discorsiva, sulle stesse cifre.

## Le proposte di Eve
Lo spunto «Cosa proporre al cliente?» (`Sources/Prisma/Eve/ProposteEve.swift`) ricava dalle analisi le azioni da fare, in ordine di urgenza: copertura caso morte, tutela per invalidità, riserva di emergenza, piano previdenziale (con il risparmio IRPEF), piani di accumulo per gli obiettivi, capitale da far lavorare, capitali in scadenza. Salta ciò che ha già una proposta aperta. Ogni azione diventa, con un tocco, un'attività o una bozza di proposta in Posizioni con area e cifre: prodotto e canale li sceglie il consulente.

## Parlare con Eve
Eve ascolta e risponde a voce (`Sources/Prisma/Eve/VoceEve.swift`, `AscoltoEve.swift`, `Sources/Prisma/Shell/VoceShell.swift`).
- **Ascolto**: riconoscimento vocale di macOS in italiano, **solo sul dispositivo** (`requiresOnDeviceRecognition`). Se il Mac non sa riconoscere l'italiano senza internet, Eve non ascolta e spiega come attivare la dettatura: l'audio non esce mai dal Mac.
- **Voce**: sintesi vocale di macOS, la migliore voce femminile italiana installata (le «Premium» e «Avanzate» sono le più naturali), scelta e velocità nelle impostazioni. Non si imita la voce di una persona o di un personaggio reale: si sceglie tra le voci di sistema.
- **Conversazione**: pulsante del microfono o ⌥⌘E. La frase finisce da sola dopo una breve pausa e segue la stessa strada delle domande scritte. La risposta resta scritta; a voce Eve ne dice l'inizio (o tutta, se si sceglie). A conversazione continua, finita la risposta Eve torna ad ascoltare finché non le si dice «basta così».
- Permessi: microfono e riconoscimento vocale (testi in `Info.plist`).

## Eve fa le cose
Quando le chiedi qualcosa da fare, a voce o per scritto, Eve lo fa e te lo conferma («Va bene, te lo preparo»). I comandi li riconosce l'app con regole sulle parole (`Sources/Prisma/Eve/ComandiEve.swift`, giorni e orari in `DateItaliane.swift`), così funzionano con ogni motore e anche senza modello; li esegue `Sources/Prisma/Shell/ComandiShell.swift`.
- **Documenti**: «preparami il report della prova di resistenza di Marco», «fammi il prospetto dei costi», «il fascicolo per l'incontro con Laura» (con il prossimo appuntamento del cliente, i report adatti già scelti). «Prospetto» = per te, altrimenti il report per il cliente.
- **Appuntamenti**: «fissa un incontro con Giulia giovedì alle 15», «una telefonata con Laura domani alle tre e mezza». Se manca il giorno o l'ora Eve lo chiede e la frase dopo completa l'appuntamento; avvisa se a quell'ora c'è già un impegno.
- **Promemoria**: «ricordami di chiamare Laura venerdì» → un'attività del cliente.
- **Note**: «prendi nota che Marco vuole cambiare casa nel 2028» → una nota nel taccuino del cliente.
- **Agenda**: «cosa ho domani?».
- **Aprire**: «apri l'agenda», «vai alle posizioni», «passa a Sofia», «apri Marco Bianchi».
Quello che Eve crea si apre o si annulla dalla risposta. Le domande («quanto pesano i costi?») restano domande. In modalità cliente Eve non esce dal dossier del cliente davanti a te. Il solo cognome vale come cliente dopo «con», «per», «di»… («i conti correnti» non è Andrea Conti).

## Contenuto della cartella
- `Istruzioni/` — istruzioni di sistema e prompt per ogni compito (chat, estrazione, commento ai report).
- `Schemi/` — schemi dei dati da estrarre (es. polizza, KID, estratto conto, proposta).
- `Esempi/` — esempi per verticalizzare Eve, con documenti anonimizzati: mai dati veri di clienti.
- `Valutazione/` — casi di prova con il risultato atteso, per misurare la qualità dell'estrazione e confrontare i motori.

## Build
- Il framework FoundationModels si compila solo con l'SDK di macOS 26.
- Verificato il 21/10/2026: il runner `macos-15-intel` ha installati anche Xcode 26.0–26.3 (il predefinito è 16.4). Quando si arriva a Eve basta selezionare Xcode 26.3 nel workflow con `DEVELOPER_DIR`, senza cambiare runner. Riguarda solo il server di build, non il Mac dell'utente.
- Il codice che usa FoundationModels va protetto con `#if canImport(FoundationModels)` e `@available(macOS 26, *)`, così l'app resta compatibile con macOS 13.
