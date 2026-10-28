# Prisma — istruzioni per Claude Code

## Il progetto
Prisma è un'app macOS nativa (SwiftUI) per uso personale di un consulente finanziario che lavora sia per Alleanza Assicurazioni (colloca solo prodotti Alleanza) sia come indipendente (consulenza a 360°: investimenti, risparmio, previdenza, assicurazione).
Moduli:
- Clienti: anagrafica e analisi completa del cliente
- Agenda: gestione completa di impegni e appuntamenti
- Posizioni (il fulcro): analisi delle posizioni in essere e non in essere dei clienti, prospetti finanziari anche per proposte di prodotti Alleanza e non solo. Va sempre distinto il canale (Alleanza / indipendente)
- Eve: assistente AI che legge documenti, prospetti e dati, li capisce e fornisce spiegazioni, dati, report e risposte in chat
Tutto resta in locale sul Mac: niente server, niente cloud.

**Principio permanente:** Prisma è e resterà sempre prima di tutto un'app di **analisi**: analisi delle posizioni dei clienti (in essere e in proposta) e delle possibilità di investimento, risparmio, previdenza e assicurazione. L'intelligenza artificiale (Eve) e ogni altra funzione sono al servizio di questa analisi, mai il contrario. Nell'interfaccia il fulcro è l'app **Posizioni** (ex "Analisi" del primo template), subito dopo Clienti nel dock e sulla scrivania.

## Regole di sviluppo (vincolanti)
- Niente Xcode, niente .xcodeproj, niente asset catalog compilati con Xcode. Il progetto è solo Swift Package Manager (Package.swift).
- Non proporre mai di installare Xcode o i Command Line Tools sul Mac dell'utente.
- Il codice non si compila in questo ambiente (Linux). Compila GitHub Actions (.github/workflows/build.yml, runner macos-15-intel) a ogni push e pull request. Non usare macos-latest: le code dei runner Apple Silicon gratuiti vanno in timeout.
- Dopo ogni push controlla l'esito della build (gh run list, gh run view --log-failed) e correggi finché non è verde. Un lavoro con la build rossa non è finito.
- Lavora su un branch e apri una pull request; main deve restare sempre compilabile. L'utente ti autorizza a unire tu la pull request in main quando la build è verde (e solo allora).
- Nessuna dipendenza esterna senza chiedere prima.
- Target minimo macOS 13. Il Mac dell'utente è un MacBook Pro M1 con 8 GB di RAM (macOS 27): codice leggero, attenzione alla memoria.
- Non puoi avviare l'app, ma puoi vederne le schermate: a ogni push il workflow esegue `Prisma --istantanee` e pubblica le PNG sul branch `anteprime` (`git fetch origin anteprime`). Guardale prima di chiedere screenshot all'utente e aggiorna la pagina online delle anteprime (https://claude.ai/artifact/EauRU1ohEGjHj4zvTomDvb). Per ciò che le istantanee non mostrano (ombre, menu, interazioni) chiedi uno screenshot.
- Backup e ripristino sono verificati nel workflow con `Prisma --prova-backup`: se tocchi l'archivio o i backup, mantieni la prova aggiornata.

## Grafica (priorità assoluta)
- La grafica la decide l'utente. Le fonti ufficiali sono:
  - Design/tema-liquid-glass.html → tema **Liquid Glass**: struttura, layout, colori chiari e scuri, vetro, font, spaziature, componenti, icone delle app
  - Design/Logo/ → il logo di Prisma (triangolo diviso in tre spicchi, #0F2433; bianco sugli sfondi scuri)
  - Design/Icone/ → icone delle app in vetro (generate dal tema con `genera-icone.js`) e icona dell'app (AppIcon.png)
- Il tema Liquid Glass è l'identità grafica (dal 27 ottobre 2026 sostituisce il tema iOS 5 di Design/template.html, che resta solo come storico). Nuove schermate, funzioni ed elementi si possono aggiungere purché coerenti con questo stile.
- Aspetto chiaro, scuro o automatico (scelta in Impostazioni). I documenti PDF restano sempre su carta bianca, chiari, con colori opachi e fissi: niente vetro sui documenti.
- Struttura scelta: un'unica finestra Prisma con barra superiore, scrivania, dock e finestre interne in vetro.
- Sfondo della scrivania: acqua vista dall'alto con gocce al rallentatore (prototipo approvato: «pioggia leggera»), disegnata in Metal. Lo sfondo è **sempre attivo**: l'acqua si muove anche con le app aperte e con la scrivania coperta da finestre ingrandite. Si ferma solo quando la finestra di Prisma non si vede (nascosta, ridotta nel Dock o coperta da altre finestre del Mac), sotto la sala opaca della presentazione, con «Riduci movimento», con il Mac a riposo o se l'utente sceglie lo sfondo fermo; in risparmio energetico non si ferma ma rallenta il ritmo dei fotogrammi (20 invece di 30 al secondo). Il disegno resta fuori dal thread principale (CVDisplayLink e coda propria). Nelle istantanee si usa il fermo-immagine.
- Canale sempre riconoscibile: Alleanza = etichetta in vetro blu (#2563EB) con il logo Alleanza; indipendente = etichetta in vetro color cuoio (#B06E12) con la scritta "Denis Vicenzoni · Consulenza finanziaria" (nelle versioni compatte resta il colore del canale).
- L'icona Agenda mostra la data del giorno (mese e giorno disegnati dall'app sopra l'icona senza data).
- Dati di prova: i 5 clienti del template (più i 30 clienti fittizi caricabili da Impostazioni), per valutare i motori di calcolo.
- Tutti i colori, font, misure, raggi, ombre e superfici di vetro vanno centralizzati in Sources/Prisma/DesignSystem/ e ricavati dal tema: mai valori sparsi nel codice.
- Le icone vanno convertite nel formato adatto a SwiftUI senza Xcode (PNG caricati dalle risorse) mantenendo l'aspetto originale; il logo è disegnato in vettoriale (LogoPrisma).
- Le API di macOS 26 (vetro nativo) vanno protette con `#if compiler(>=6.2)` e `if #available(macOS 26.0, *)`, con un ripiego per macOS 13-25.

## Dati e privacy
- I dati dei clienti sono personali e patrimoniali: restano sul Mac, mai inviati a servizi esterni.
- Archivio locale in ~/Library/Application Support/Prisma.
- Backup: manuale (pulsante "Crea backup") + automatico settimanale, con rotazione (ultime 8 copie), cartella di destinazione scelta dall'utente (es. iCloud Drive o disco esterno) e funzione di ripristino. Il backup comprende clienti, agenda, posizioni, documenti e impostazioni di Eve.

## Eve (assistente AI)
- Unico motore di intelligenza artificiale: **Qwen** sul Mac (Ollama su 127.0.0.1, modello qwen3:4b), dietro il protocollo Swift `MotoreEve`. Niente modello Apple. Se Qwen non è pronto Eve lo dice e non risponde; i calcoli di Prisma preparano le cifre esatte che Qwen racconta.
- Eve estrae dati strutturati e spiega; calcoli e impaginazione di report e prospetti li fa l'app con modelli grafici fissi coerenti col tema.
- Prompt, istruzioni e configurazioni di Eve stanno nel repository, cartella Eve/.

## Lingua
Interfaccia, commenti e messaggi di commit in italiano.
