import SwiftUI

// Proprietario: G7 (guida). La «Guida di Prisma» per chi non sa nulla di finanza né di app: l'introduzione
// in 5 pagine, «Come si usa» di ogni app, le parole (Glossario.swift). Testi in Swift, non in Eve/: non sono
// istruzioni per il modello. Tutto locale, niente rete.

/// Che cosa mostra il pannello «Guida di Prisma».
enum PaginaGuida: Equatable {
    /// L'introduzione, alla pagina data (0…PaginaIntroduzione.pagine.count - 1).
    case introduzione(Int)
    /// Come si usa un'app (la stessa scheda del pulsante «Come si usa», più grande).
    case app(AppPrisma)
    /// Il glossario, aperto su una voce (nil: dall'inizio).
    case glossario(VoceGlossario.Chiave?)

    /// La scheda del pannello.
    var scheda: SchedaGuida {
        switch self {
        case .introduzione: return .comeFunziona
        case .app: return .app
        case .glossario: return .parole
        }
    }
}

/// Le tre schede del pannello della guida.
enum SchedaGuida: Hashable, CaseIterable {
    case comeFunziona, app, parole

    var nome: String {
        switch self {
        case .comeFunziona: return "Come funziona"
        case .app: return "Le app"
        case .parole: return "Le parole"
        }
    }
}

/// «A cosa serve / Come si usa in 3 passi / Le parole da sapere» di un'app.
struct AiutoApp {
    /// Una frase sola, senza gergo.
    let aCosaServe: String
    /// Una riga breve (al massimo 60 caratteri) per l'elenco della guida e, nel dock, per VoiceOver.
    let inBreve: String
    /// Esattamente tre passi, con i nomi dei pulsanti veri tra «» (senza glifi: ETICHETTE di GRUPPI.md).
    let passi: [String]
    /// Le parole del glossario che servono in questa app (da 0 a 5).
    let parole: [VoceGlossario.Chiave]
}

extension AppPrisma {
    /// La guida dell'app (testi in `GuidaTesti`).
    var aiuto: AiutoApp { GuidaTesti.aiuto(self) }
}

/// I testi «Come si usa» delle 16 app.
enum GuidaTesti {
    static func aiuto(_ app: AppPrisma) -> AiutoApp {
        switch app {
        case .clienti:
            return AiutoApp(
                aCosaServe: "Qui c'è la scheda di ogni cliente: chi è, la sua famiglia, il lavoro, entrate e spese, che cosa gli preme. È il punto di partenza di ogni analisi.",
                inBreve: "Le schede delle persone che segui",
                passi: ["Scegli il cliente nella rubrica a sinistra, oppure «Nuovo cliente» (o «Importa…» da Contatti ed Excel).",
                        "Completa la scheda: Prisma segna i dati che mancano e dice a che cosa servono.",
                        "Da qui vai alle sue Posizioni o prepara il prossimo incontro."],
                parole: [.dossier, .riesame, .profiloRischio, .antiriciclaggio])
        case .posizioni:
            return AiutoApp(
                aCosaServe: "Tutto quello che il cliente ha già (in essere) e quello che gli proponi (in proposta), diviso per canale: Alleanza o consulenza indipendente. È il cuore di Prisma.",
                inBreve: "Che cosa ha il cliente e che cosa gli proponi",
                passi: ["Scegli il cliente e guarda il riepilogo: quanto ha, dove, con quale canale.",
                        "«Posizione» per ciò che ha già, «Proposta» per ciò che consigli (o «Importa…» da Excel).",
                        "Apri una posizione: valore, costi, riscatto e proiezione nel tempo."],
                parole: [.inEssere, .canale, .riscatto, .penali, .sri])
        case .analisi360:
            return AiutoApp(
                aCosaServe: "Guarda insieme le quattro aree della vita finanziaria del cliente (pensione, protezione, investimenti, risparmio) e mostra dove è coperto e dove no, con le cifre.",
                inBreve: "Pensione, protezione, investimenti e risparmio insieme",
                passi: ["Scegli il cliente: le ipotesi partono dalle sue posizioni.",
                        "Correggi le ipotesi con lui (età della pensione, spese, reddito).",
                        "Leggi le scoperture e passa alle Simulazioni o al prospetto."],
                parole: [.tassoSostituzione, .montante, .deducibilita, .tcm, .riservaLiquidita])
        case .incontri:
            return AiutoApp(
                aCosaServe: "Il quaderno di ogni incontro: che cosa preparare, che cosa ti dice il cliente, che cosa decidete.",
                inBreve: "Prepara gli appuntamenti e annota le decisioni",
                passi: ["«Prepara il primo incontro»: Prisma propone i temi dal dossier.",
                        "Durante l'incontro scrivi appunti e decisioni.",
                        "«Ai prossimi passi»: nascono attività e appuntamenti da confermare."],
                parole: [.riesame, .coerenza])
        case .obiettivi:
            return AiutoApp(
                aCosaServe: "Dai un nome ai progetti del cliente (la casa, gli studi dei figli) e scopri quanto manca e quanto mettere da parte ogni mese.",
                inBreve: "I progetti del cliente, con importo e data",
                passi: ["«Nuovo obiettivo»: nome, importo, data.",
                        "Collega le posizioni che servono a quel progetto.",
                        "Guarda il versamento mensile che serve per arrivarci in tempo."],
                parole: [.interesseComposto, .inflazione])
        case .confronti:
            return AiutoApp(
                aCosaServe: "Metti a confronto le posizioni o gli scenari del cliente con le stesse regole, per vedere quale conviene e perché.",
                inBreve: "Due o tre ipotesi una accanto all'altra",
                passi: ["Scegli il cliente e le voci da confrontare.",
                        "Guarda la tabella: versato, costi, tasse, valore finale.",
                        "«Restare o cambiare…» per valutare una sostituzione, oppure «Prospetto in PDF»."],
                parole: [.riy, .rendimentoNetto, .penali])
        case .prodotti:
            return AiutoApp(
                aCosaServe: "L'archivio dei prodotti che proponi, Alleanza e non solo: condizioni, costi, rischio e la fonte da cui vengono.",
                inBreve: "Le schede dei prodotti, con costi e fonti",
                passi: ["Scegli una scheda o «Nuova scheda».",
                        "Controlla condizioni e costi, poi «Segna verificata oggi».",
                        "«Crea una proposta per…» il cliente attivo, oppure «Simula»."],
                parole: [.kid, .sri, .riy, .gestioneSeparata, .minimoGarantito])
        case .simulazioni:
            return AiutoApp(
                aCosaServe: "Calcola come cresce un capitale o un versamento nel tempo, con costi, tasse e inflazione.",
                inBreve: "«E se…?»: quanto diventa un capitale nel tempo",
                passi: ["«Nuova ipotesi», oppure parti da una posizione del cliente.",
                        "Cambia importi, anni e rendimento: il risultato si aggiorna subito.",
                        "«Salva scenario» e confrontane fino a tre."],
                parole: [.interesseComposto, .inflazione, .rendimentoNetto, .volatilita])
        case .agenda:
            return AiutoApp(
                aCosaServe: "Il calendario degli appuntamenti, con dentro anche le scadenze e le date importanti delle posizioni dei clienti.",
                inBreve: "Appuntamenti e scadenze delle posizioni",
                passi: ["«Oggi» per la giornata, le frecce per spostarti tra i giorni.",
                        "«Appuntamento» e scegli il cliente.",
                        "Le scadenze in giornata sono occasioni: «Analizza in Posizioni»."],
                parole: [.riesame])
        case .attivita:
            return AiutoApp(
                aCosaServe: "L'elenco delle cose da fare, collegate ai clienti: chiamate, documenti da chiedere, proposte da seguire.",
                inBreve: "Le cose da fare, una alla volta",
                passi: ["«Nuova attività» e collegala a un cliente.",
                        "Spunta il cerchio quando è fatta.",
                        "«Apri in Agenda» per darle una data."],
                parole: [])
        case .note:
            return AiutoApp(
                aCosaServe: "Il taccuino: appunti liberi, collegati a una persona se vuoi. Eve li legge per rispondere meglio.",
                inBreve: "Gli appunti, collegati ai clienti",
                passi: ["«Nuova nota».",
                        "Scrivi, e scegli il cliente se riguarda lui.",
                        "Ritrovala con la ricerca o dalla scheda del cliente."],
                parole: [])
        case .documenti:
            return AiutoApp(
                aCosaServe: "Qui finiscono i documenti dei clienti. Prisma li legge sul Mac, trova le cifre (con la pagina) e ti dice che cosa non torna con il dossier.",
                inBreve: "KID, polizze ed estratti conto letti sul Mac",
                passi: ["Trascina i file sulla finestra, o «Scegli i file…».",
                        "Controlla le cifre trovate e conferma.",
                        "Collega il documento a una posizione: Prisma mostra le differenze."],
                parole: [.kid, .sri, .riy])
        case .presentazioni:
            return AiutoApp(
                aCosaServe: "Prepara i documenti da stampare o salvare in PDF: il prospetto dettagliato per te e il report essenziale per il cliente. Sempre su carta bianca.",
                inBreve: "I PDF: prospetto per te, report per il cliente",
                passi: ["Scegli il cliente e il tipo di documento.",
                        "Controlla le pagine a schermo (sono identiche al PDF); «Modifica ipotesi e testi…» se serve.",
                        "«Salva PDF…», «Stampa…» o «Archivia nei Documenti»."],
                parole: [.prospettoReport, .riy, .sri])
        case .eve:
            return AiutoApp(
                aCosaServe: "Eve risponde alle tue domande sui clienti, le posizioni e i documenti. Le cifre le calcola Prisma, Eve le spiega. Funziona sul Mac, senza internet.",
                inBreve: "L'assistente: domande in chat o a voce",
                passi: ["Scegli il cliente di cui parlare.",
                        "Scrivi la domanda (o premi il microfono).",
                        "Usa gli spunti pronti: riepilogo, che cosa manca, prepara l'incontro."],
                parole: [])
        case .ricerca:
            return AiutoApp(
                aCosaServe: "Una ricerca unica in tutto Prisma: clienti, posizioni, documenti, appuntamenti e attività.",
                inBreve: "Trova clienti, posizioni, documenti (⌘K)",
                passi: ["⌘K, oppure «Cerca ovunque» sulla scrivania.",
                        "Scrivi una parte del nome o del prodotto.",
                        "Invio per aprire il risultato; i filtri restringono (per esempio «canale:alleanza»)."],
                parole: [])
        case .impostazioni:
            return AiutoApp(
                aCosaServe: "Il tuo profilo, i backup (manuali e ogni settimana), l'aspetto chiaro o scuro, la dimensione del testo e i dati di prova.",
                inBreve: "Profilo, backup, aspetto, dati di prova",
                passi: ["Archivio: scegli la cartella dei backup e fai il primo.",
                        "Esperienza: aspetto, dimensione del testo, guida.",
                        "Archivio: carica o togli i clienti di prova."],
                parole: [])
        }
    }
}

/// Una pagina dell'introduzione «Come funziona Prisma». Il testo accetta il grassetto e il corsivo di Markdown.
struct PaginaIntroduzione {
    let titolo: String
    let testo: String
    let punti: [String]
    /// Le icone delle app di cui parla (vuoto: il logo di Prisma).
    let app: [AppPrisma]
    /// Sotto i punti, le due etichette dei canali.
    var conCanali = false
    /// Sopra i punti, il percorso tipico Cliente → Posizioni → Analisi → Prospetto.
    var conPercorso = false

    /// Le 5 pagine dell'introduzione (fuori dalla vista: la prova dei calcoli le conta).
    static let pagine: [PaginaIntroduzione] = [
        PaginaIntroduzione(
            titolo: "Benvenuto in Prisma",
            testo: "Prisma è lo studio di lavoro di un consulente finanziario. Raccoglie le persone che segui, quello che hanno (polizze, investimenti, piani per la pensione) e ti aiuta a capire che cosa manca e che cosa conviene.",
            punti: ["I calcoli li fa Prisma: tu scegli e spieghi.",
                    "Tutto resta su questo Mac: niente internet, niente cloud.",
                    "Ci sono due canali, sempre distinti: Alleanza (blu) e consulenza indipendente (cuoio)."],
            app: [], conCanali: true),
        PaginaIntroduzione(
            titolo: "Si parte dalle persone",
            testo: "In **Clienti** c'è la scheda di ogni persona: famiglia, lavoro, entrate, spese, che cosa le preme. Più la scheda è completa, più le analisi sono precise.",
            punti: ["«Nuovo cliente», oppure «Importa…» dall'app Contatti o da Excel.",
                    "Prisma ti dice quali dati mancano e a che cosa servono.",
                    "In Agenda, Attività e Incontri segui gli appuntamenti con lui."],
            app: [.clienti, .agenda, .incontri]),
        PaginaIntroduzione(
            titolo: "Che cosa ha, che cosa gli proponi",
            testo: "In **Posizioni**, il cuore di Prisma, c'è tutto quello che il cliente ha già (*in essere*) e quello che gli stai proponendo (*in proposta*). Ogni posizione dice da quale canale viene.",
            punti: ["«Posizione» per ciò che ha già, «Proposta» per ciò che consigli.",
                    "Puoi leggerle dai documenti (KID, polizze, estratti conto) in Documenti.",
                    "Ogni parola tecnica ha la sua «i»: un clic e te la spiega."],
            app: [.posizioni, .documenti, .prodotti]),
        PaginaIntroduzione(
            titolo: "Capire che cosa manca",
            testo: "**Analisi 360** guarda insieme pensione, protezione della famiglia, investimenti e risparmio, e mostra dove il cliente è scoperto. **Simulazioni** e **Confronti** rispondono a «e se…?» con le cifre.",
            punti: ["Le ipotesi partono dai dati veri del cliente: puoi correggerle insieme a lui.",
                    "In Obiettivi dai un nome e una data ai suoi progetti (casa, studi dei figli).",
                    "I numeri sono sempre calcolati da Prisma, con il metodo scritto sotto."],
            app: [.analisi360, .simulazioni, .confronti, .obiettivi]),
        PaginaIntroduzione(
            titolo: "Spiegarlo in modo chiaro",
            testo: "Da **Prospetti e report** esce il documento in PDF: il *prospetto* dettagliato per te, il *report* essenziale da lasciare al cliente. **Eve** risponde alle tue domande e spiega i documenti, con le cifre di Prisma.",
            punti: ["«Come si usa», in alto in ogni finestra: a cosa serve l'app e come si usa, in 3 passi.",
                    "Menu Aiuto › Guida di Prisma (⌘?) per rivedere tutto, quando vuoi."],
            app: [.presentazioni, .eve], conPercorso: true),
    ]
}

extension StatoShell {
    /// Il pannello della guida aperto (nil = chiuso). Vive in `sistema`, come gli altri pannelli: aprirlo non
    /// ridisegna le app.
    var guida: PaginaGuida? {
        get { sistema.guida }
        set { sistema.guida = newValue }
    }

    /// Apre la guida sulla pagina data e chiude gli altri pannelli. Con la schermata di benvenuto davanti
    /// prima si entra, poi la guida compare a sblocco finito (due transazioni separate, mai insieme).
    /// Durante la presentazione non si apre.
    func apriGuida(_ pagina: PaginaGuida = .introduzione(0)) {
        guard presentazione == nil else { return }
        if bloccato {
            sblocca()
            // Nelle istantanee e nelle prove lo sblocco è di colpo: si prosegue subito
            if persistente {
                Movimenti.dopo(Tema.Moto.Sblocco.durataEntrata) { [weak self] in
                    guard let self, !self.bloccato else { return }
                    self.apriGuida(pagina)
                }
                return
            }
        }
        // Senza animazione nello stato: il contenitore di ShellView anima l'entrata (come «Le tue app aperte»)
        withTransaction(Transaction(animation: nil)) {
            if pannelloNotifiche { pannelloNotifiche = false }
            if pannelloSpazi { pannelloSpazi = false }
            if pannelloAppAperte { pannelloAppAperte = false }
            chiudiRicerca()
            if sistema.guida != pagina { sistema.guida = pagina }
        }
    }

    /// Chiude la guida. Se era l'introduzione, la segna come vista (non riparte da sola).
    func chiudiGuida() {
        guard let g = sistema.guida else { return }
        if case .introduzione = g, !dati.impostazioni.introduzioneVista, !solaLettura {
            dati.impostazioni.introduzioneVista = true
        }
        withTransaction(Transaction(animation: nil)) { sistema.guida = nil }
    }

    /// Dopo lo sblocco: al primo avvio parte l'introduzione (mai in modalità cliente, in sola lettura,
    /// nelle istantanee e nelle prove).
    func dopoSblocco() {
        guard persistente, !solaLettura, modoCliente == nil, presentazione == nil,
              !dati.impostazioni.introduzioneVista, sistema.guida == nil, !bloccato else { return }
        apriGuida(.introduzione(0))
    }
}
