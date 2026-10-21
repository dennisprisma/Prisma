# Prisma — istruzioni per Claude Code

## Il progetto
Prisma è un'app macOS nativa (SwiftUI) per uso personale di un consulente finanziario che lavora sia per Alleanza Assicurazioni (colloca solo prodotti Alleanza) sia come indipendente (consulenza a 360°: investimenti, risparmio, previdenza, assicurazione).
Moduli:
- Clienti: anagrafica e analisi completa del cliente
- Agenda: gestione completa di impegni e appuntamenti
- Posizioni (il fulcro): analisi delle posizioni in essere e non in essere dei clienti, prospetti finanziari anche per proposte di prodotti Alleanza e non solo. Va sempre distinto il canale (Alleanza / indipendente)
- Eve: assistente AI che legge documenti, prospetti e dati, li capisce e fornisce spiegazioni, dati, report e risposte in chat
Tutto resta in locale sul Mac: niente server, niente cloud.

## Regole di sviluppo (vincolanti)
- Niente Xcode, niente .xcodeproj, niente asset catalog compilati con Xcode. Il progetto è solo Swift Package Manager (Package.swift).
- Non proporre mai di installare Xcode o i Command Line Tools sul Mac dell'utente.
- Il codice non si compila in questo ambiente (Linux). Compila GitHub Actions (.github/workflows/build.yml, runner macos-15-intel) a ogni push e pull request. Non usare macos-latest: le code dei runner Apple Silicon gratuiti vanno in timeout.
- Dopo ogni push controlla l'esito della build (gh run list, gh run view --log-failed) e correggi finché non è verde. Un lavoro con la build rossa non è finito.
- Lavora su un branch e apri una pull request; main deve restare sempre compilabile.
- Nessuna dipendenza esterna senza chiedere prima.
- Target minimo macOS 13. Il Mac dell'utente è un MacBook Pro M1 con 8 GB di RAM (macOS 27): codice leggero, attenzione alla memoria.
- Non puoi avviare né vedere l'app: per il controllo visivo chiedi all'utente uno screenshot.

## Grafica (priorità assoluta)
- La grafica la decide l'utente. Le fonti ufficiali sono:
  - Design/template.html → struttura, layout, colori, font, spaziature, componenti
  - Design/Icone/ → icone dell'interfaccia e icona dell'app
- Riproduci il template fedelmente in SwiftUI. Non inventare colori, font, misure o elementi grafici. Se qualcosa non è definito nel template, chiedi prima di decidere.
- Tutti i colori, font, misure, raggi e ombre vanno centralizzati in Sources/Prisma/DesignSystem/ e ricavati dal template: mai valori sparsi nel codice.
- Le icone vanno convertite nel formato adatto a SwiftUI senza Xcode (es. PDF/PNG caricati dalle risorse) mantenendo l'aspetto originale.

## Dati e privacy
- I dati dei clienti sono personali e patrimoniali: restano sul Mac, mai inviati a servizi esterni.
- Archivio locale in ~/Library/Application Support/Prisma.
- Backup: manuale (pulsante "Crea backup") + automatico settimanale, con rotazione (ultime 8 copie), cartella di destinazione scelta dall'utente (es. iCloud Drive o disco esterno) e funzione di ripristino. Il backup comprende clienti, agenda, posizioni, documenti e impostazioni di Eve.

## Eve (assistente AI)
- Motore intercambiabile tramite un protocollo Swift: primo motore il modello Apple integrato (framework FoundationModels, sul dispositivo), con verifica di disponibilità a runtime e messaggio chiaro se non disponibile. In futuro eventualmente un modello Qwen 3-4B in locale.
- Eve estrae dati strutturati e spiega; calcoli e impaginazione di report e prospetti li fa l'app con modelli grafici fissi coerenti col template.
- Prompt, istruzioni e configurazioni di Eve stanno nel repository, cartella Eve/.

## Lingua
Interfaccia, commenti e messaggi di commit in italiano.
