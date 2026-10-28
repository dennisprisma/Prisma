import Foundation
import CoreGraphics

/// «Cerca ovunque» (⌘K): una sola ricerca su app, clienti, posizioni, documenti (anche nel testo
/// delle pagine), appuntamenti, attività, obiettivi, incontri e prodotti. Tutto avviene sul Mac,
/// sui dati dell'archivio locale.
enum GruppoRicerca: String, CaseIterable, Identifiable {
    case app, clienti, posizioni, documenti, note, appuntamenti, attivita, obiettivi, incontri, prodotti
    /// Comandi rapidi del pannello (nuovo appuntamento, crea backup…): solo nella ricerca a parole.
    case azioni

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .app: return "App"
        case .clienti: return "Clienti"
        case .posizioni: return "Posizioni"
        case .documenti: return "Documenti"
        case .note: return "Note"
        case .appuntamenti: return "Appuntamenti"
        case .attivita: return "Attività"
        case .obiettivi: return "Obiettivi"
        case .incontri: return "Incontri"
        case .prodotti: return "Prodotti"
        case .azioni: return "Azioni"
        }
    }

    /// L'app che apre i risultati del gruppo (e ne presta l'icona).
    var app: AppPrisma {
        switch self {
        case .app: return .ricerca
        case .clienti: return .clienti
        case .posizioni: return .posizioni
        case .documenti: return .documenti
        case .note: return .note
        case .appuntamenti: return .agenda
        case .attivita: return .attivita
        case .obiettivi: return .obiettivi
        case .incontri: return .incontri
        case .prodotti: return .prodotti
        case .azioni: return .ricerca
        }
    }
}

/// Un comando rapido del pannello di ricerca: si trova scrivendo («appuntamento», «backup») e si esegue con Invio.
enum AzioneRicerca: String, CaseIterable, Hashable {
    case nuovoAppuntamento, nuovaAttivita, nuovaNota, creaBackup, modoCliente, spaziLavoro, appAperte, notifiche, scrivania

    var titolo: String {
        switch self {
        case .nuovoAppuntamento: return "Nuovo appuntamento"
        case .nuovaAttivita: return "Nuova attività"
        case .nuovaNota: return "Nuova nota"
        case .creaBackup: return "Crea backup"
        case .modoCliente: return "Modalità cliente"
        case .spaziLavoro: return "Spazi di lavoro"
        case .appAperte: return "Le tue app aperte"
        case .notifiche: return "Centro notifiche"
        case .scrivania: return "Mostra la scrivania"
        }
    }

    var dettaglio: String {
        switch self {
        case .nuovoAppuntamento: return "Fissa un incontro in agenda con il cliente attivo"
        case .nuovaAttivita: return "Segna una cosa da fare per il cliente attivo"
        case .nuovaNota: return "Una pagina nuova nel taccuino del cliente attivo"
        case .creaBackup: return "Copia di clienti, agenda, posizioni e documenti nella cartella dei backup"
        case .modoCliente: return "Mostra solo il cliente attivo, per girare lo schermo"
        case .spaziLavoro: return "Le app già disposte per il lavoro di oggi"
        case .appAperte: return "Le finestre aperte, con un clic per tornarci"
        case .notifiche: return "Scadenze, riesami e promemoria"
        case .scrivania: return "Riduce le finestre e torna alla scrivania"
        }
    }

    /// Simbolo SF dell'azione.
    var simbolo: String {
        switch self {
        case .nuovoAppuntamento: return "calendar.badge.plus"
        case .nuovaAttivita: return "checklist"
        case .nuovaNota: return "square.and.pencil"
        case .creaBackup: return "externaldrive.badge.timemachine"
        case .modoCliente: return "person.crop.rectangle"
        case .spaziLavoro: return "rectangle.split.2x1"
        case .appAperte: return "square.grid.2x2"
        case .notifiche: return "bell"
        case .scrivania: return "menubar.dock.rectangle"
        }
    }

    /// Altre parole con cui si cerca.
    var paroleChiave: String {
        switch self {
        case .nuovoAppuntamento: return "fissa incontro agenda appuntamento riunione telefonata crea"
        case .nuovaAttivita: return "crea attività promemoria cosa da fare compito"
        case .nuovaNota: return "crea nota appunto taccuino scrivi"
        case .creaBackup: return "salva copia sicurezza backup archivio"
        case .modoCliente: return "presenta schermo cliente riservato"
        case .spaziLavoro: return "spazi disposizione finestre lavoro"
        case .appAperte: return "finestre aperte app passa"
        case .notifiche: return "avvisi scadenze promemoria notifiche"
        case .scrivania: return "desktop scrivania chiudi riduci"
        }
    }

    /// Le azioni che si completano in un modulo (il pannello lo apre sopra di sé).
    var conModulo: Bool { self == .nuovoAppuntamento || self == .nuovaAttivita }
}

/// Dove porta un risultato.
enum DestinazioneRicerca: Hashable {
    case app(AppPrisma)
    case cliente(String)
    case posizione(String)
    case documento(String)
    case nota(String)
    case appuntamento(String)
    case attivita(String)
    case obiettivo(String)
    case incontro(String)
    case prodotto(String)
}

/// Chiave unica di un risultato: le azioni portano tutte al pannello, si distinguono per l'azione.
struct ChiaveRisultato: Hashable {
    let destinazione: DestinazioneRicerca
    let azione: AzioneRicerca?
}

struct RisultatoRicerca: Identifiable, Hashable {
    let destinazione: DestinazioneRicerca
    let gruppo: GruppoRicerca
    let titolo: String
    let dettaglio: String
    /// La riga in cui compare la parola cercata, se non è nel titolo.
    var estratto: String?
    var canale: Canale?
    var punteggio = 0
    /// Per il gruppo Azioni: il comando da eseguire.
    var azione: AzioneRicerca?
    /// A parità di punteggio, l'ordine (più basso prima); 0 = in ordine alfabetico.
    var ordine = 0

    var id: ChiaveRisultato { ChiaveRisultato(destinazione: destinazione, azione: azione) }

    /// L'app di cui mostrare l'icona.
    var app: AppPrisma {
        if case .app(let a) = destinazione { return a }
        return gruppo.app
    }
}

struct SezioneRicerca: Identifiable {
    let gruppo: GruppoRicerca
    let risultati: [RisultatoRicerca]
    /// Quanti risultati ci sono in tutto (si mostrano i primi).
    let totale: Int

    var id: GruppoRicerca { gruppo }
    /// Il punteggio del primo risultato: il pannello mette prima i gruppi che rispondono meglio.
    var migliore: Int { risultati.first?.punteggio ?? 0 }
}

/// Tutto ciò che il pannello mostra per un testo: sezioni, filtri riconosciuti e totali per canale.
struct EsitoRicerca {
    var sezioni: [SezioneRicerca] = []
    var interpretata = RicercaInterpretata()
    /// Con i filtri: le posizioni trovate (o quelle in essere dei clienti trovati) per canale.
    var totali: [TotaleCanaleRicerca] = []
    var totaliDeiClienti = false

    static let vuoto = EsitoRicerca()
    var elenco: [RisultatoRicerca] { sezioni.flatMap(\.risultati) }
}

enum MotoreRicerca {
    /// Risultati mostrati per gruppo.
    static let perGruppo = 5
    /// Con i filtri si vede l'elenco intero (fino a questo numero per gruppo).
    static let perGruppoFiltri = 60
    /// Caratteri attorno alla parola trovata nel testo di un documento.
    static let contestoPrima = 40
    static let contestoDopo = 70

    private static let opzioni: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Le parole cercate: ognuna deve comparire (senza badare a maiuscole e accenti).
    static func parole(_ testo: String) -> [String] {
        testo.split(whereSeparator: { $0.isWhitespace }).map(String.init).filter { !$0.isEmpty }
    }

    static func contiene(_ testo: String, _ parola: String) -> Bool {
        testo.range(of: parola, options: opzioni, locale: Formati.italiano) != nil
    }

    /// Punteggio del titolo: inizia con la ricerca > ogni parola all'inizio di una parola > dentro il titolo.
    static func punteggio(titolo: String, ricerca: String, parole: [String]) -> Int {
        if titolo.range(of: ricerca, options: opzioni.union(.anchored), locale: Formati.italiano) != nil { return 300 }
        let iniziali = titolo.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if parole.allSatisfy({ p in iniziali.contains { $0.range(of: p, options: opzioni.union(.anchored), locale: Formati.italiano) != nil } }) { return 200 }
        if parole.allSatisfy({ contiene(titolo, $0) }) { return 150 }
        return 50
    }

    /// Un candidato: titolo, campi (etichetta, valore) in cui cercare e, per i documenti, le pagine.
    private struct Candidato {
        var risultato: RisultatoRicerca
        var campi: [(String, String)] = []
        var pagine: [String] = []
    }

    /// Valuta un candidato: nil se manca anche una sola parola.
    private static func valuta(_ c: Candidato, ricerca: String, parole: [String]) -> RisultatoRicerca? {
        let titolo = c.risultato.titolo
        var mancanti = parole.filter { !contiene(titolo, $0) }
        var r = c.risultato
        r.punteggio = punteggio(titolo: titolo, ricerca: ricerca, parole: parole)
        guard !mancanti.isEmpty else { return r }
        // Le parole che non sono nel titolo vanno cercate nei campi
        var estratto: String?
        for (etichetta, valore) in c.campi where !valore.isEmpty {
            let trovate = mancanti.filter { contiene(valore, $0) }
            guard !trovate.isEmpty else { continue }
            // Il valore già scritto nel dettaglio (il nome del cliente) non si ripete
            if estratto == nil, !contiene(r.dettaglio, valore) { estratto = "\(etichetta): \(riga(valore, attorno: trovate[0]))" }
            mancanti.removeAll { trovate.contains($0) }
            if mancanti.isEmpty { break }
        }
        // Poi nel testo delle pagine
        if !mancanti.isEmpty {
            for (i, pagina) in c.pagine.enumerated() {
                let trovate = mancanti.filter { contiene(pagina, $0) }
                guard !trovate.isEmpty else { continue }
                if estratto == nil { estratto = "pag. \(i + 1): \(riga(pagina, attorno: trovate[0]))" }
                mancanti.removeAll { trovate.contains($0) }
                if mancanti.isEmpty { break }
            }
        }
        guard mancanti.isEmpty else { return nil }
        r.estratto = estratto
        r.punteggio -= 20
        return r
    }

    /// Il pezzo di testo attorno alla parola, su una riga.
    static func riga(_ testo: String, attorno parola: String) -> String {
        let compatto = testo.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard let r = compatto.range(of: parola, options: opzioni, locale: Formati.italiano) else {
            return String(compatto.prefix(contestoPrima + contestoDopo))
        }
        let inizio = compatto.index(r.lowerBound, offsetBy: -contestoPrima, limitedBy: compatto.startIndex) ?? compatto.startIndex
        let fine = compatto.index(r.upperBound, offsetBy: contestoDopo, limitedBy: compatto.endIndex) ?? compatto.endIndex
        var pezzo = String(compatto[inizio..<fine])
        if inizio > compatto.startIndex { pezzo = "…" + pezzo }
        if fine < compatto.endIndex { pezzo += "…" }
        return pezzo
    }

    static func cerca(_ testo: String, in stato: StatoShell) -> [SezioneRicerca] {
        cercaCompleta(testo, in: stato).sezioni
    }

    /// La ricerca del pannello: le parole come sempre e, se ci sono, i filtri (`FiltriRicerca`) con i totali per canale.
    static func cercaCompleta(_ testo: String, in stato: StatoShell, oggi: Date = Date()) -> EsitoRicerca {
        let interpretata = FiltriRicerca.interpreta(testo)
        var esito = EsitoRicerca()
        esito.interpretata = interpretata
        if interpretata.conFiltri {
            cercaConFiltri(interpretata, in: stato, oggi: oggi, esito: &esito)
        } else {
            // Prima i gruppi che rispondono meglio (come Spotlight); a pari merito l'ordine di sempre
            esito.sezioni = cercaParole(interpretata.testoLibero, in: stato).enumerated()
                .sorted { a, b in a.element.migliore != b.element.migliore ? a.element.migliore > b.element.migliore : a.offset < b.offset }
                .map(\.element)
        }
        return esito
    }

    /// I nomi dei clienti per id.
    private static func nomiClienti(_ dati: DatiPrisma) -> [String: String] {
        var nomi: [String: String] = [:]
        for c in dati.clienti { nomi[c.id] = c.nome }
        return nomi
    }

    /// Valuta i candidati di un gruppo, li ordina e tiene i primi `limite`.
    private static func sezione(_ g: GruppoRicerca, _ elenco: [Candidato], ricerca: String, parole: [String],
                                limite: Int) -> SezioneRicerca? {
        let trovati = elenco.compactMap { c -> RisultatoRicerca? in
            guard !parole.isEmpty else { return c.risultato }
            return valuta(c, ricerca: ricerca, parole: parole)
        }
        .sorted { a, b in
            if a.punteggio != b.punteggio { return a.punteggio > b.punteggio }
            if a.ordine != b.ordine { return a.ordine < b.ordine }
            return a.titolo.localizedCaseInsensitiveCompare(b.titolo) == .orderedAscending
        }
        guard !trovati.isEmpty else { return nil }
        return SezioneRicerca(gruppo: g, risultati: Array(trovati.prefix(limite)), totale: trovati.count)
    }

    /// La ricerca a parole su tutto l'archivio (come è sempre stata), più le azioni rapide.
    private static func cercaParole(_ testo: String, in stato: StatoShell) -> [SezioneRicerca] {
        let ricerca = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        let parole = parole(ricerca)
        guard !parole.isEmpty else { return [] }
        let dati = stato.dati
        let nomi = nomiClienti(dati)
        func nome(_ id: String) -> String { nomi[id] ?? "Senza cliente" }

        var candidati: [GruppoRicerca: [Candidato]] = [:]
        candidati[.app] = AppPrisma.allCases.filter { $0 != .ricerca }.map {
            Candidato(risultato: RisultatoRicerca(destinazione: .app($0), gruppo: .app, titolo: $0.titolo, dettaglio: $0.sottotitolo))
        }
        candidati[.clienti] = dati.clienti.map { c in
            Candidato(risultato: RisultatoRicerca(destinazione: .cliente(c.id), gruppo: .clienti, titolo: c.nome, dettaglio: c.tema),
                      campi: [("Progetto", c.tema), ("Email", c.email), ("Telefono", c.telefono), ("Professione", c.professione),
                              ("Codice fiscale", c.codiceFiscale), ("Indirizzo", c.indirizzo), ("Nota", c.nota)])
        }
        candidati[.posizioni] = dati.posizioni.map { p in
            Candidato(risultato: RisultatoRicerca(destinazione: .posizione(p.id), gruppo: .posizioni, titolo: p.nome,
                                                  dettaglio: "\(nome(p.clienteId)) · \(p.stato.nome)", canale: p.canale),
                      campi: [("Cliente", nome(p.clienteId)), ("Tipologia", p.tipologia), ("Emittente", p.emittente),
                              ("Contratto", p.numeroContratto), ("Contraente", p.contraente), ("Assicurato", p.assicurato),
                              ("Beneficiari", p.beneficiari), ("Canale", p.canale.nomeBreve), ("Note", p.note)])
        }
        candidati[.documenti] = dati.documenti.map { d in
            Candidato(risultato: RisultatoRicerca(destinazione: .documento(d.id), gruppo: .documenti, titolo: d.titolo,
                                                  dettaglio: "\(nome(d.clienteId)) · \(d.tipo.nome)"),
                      campi: [("Cliente", nome(d.clienteId))] + d.campi.map { ($0.chiave.nome, $0.valore) },
                      pagine: stato.testoDocumento(d, memorizza: false))
        }
        candidati[.note] = dati.note.filter { !$0.vuota }.map { n in
            Candidato(risultato: RisultatoRicerca(destinazione: .nota(n.id), gruppo: .note, titolo: n.titoloMostrato,
                                                  dettaglio: "\(nome(n.clienteId)) · \(Formati.dataEstesa.string(from: n.aggiornataIl))"),
                      campi: [("Cliente", nome(n.clienteId)), ("Testo", n.testo)])
        }
        candidati[.appuntamenti] = dati.appuntamenti.map { a in
            Candidato(risultato: RisultatoRicerca(destinazione: .appuntamento(a.id), gruppo: .appuntamenti, titolo: a.titolo,
                                                  dettaglio: "\(nome(a.clienteId)) · \(Formati.dataOra.string(from: a.inizio))", canale: a.canale),
                      campi: [("Cliente", nome(a.clienteId)), ("Luogo", a.luogo), ("Note", a.note)])
        }
        candidati[.attivita] = dati.attivita.map { a in
            Candidato(risultato: RisultatoRicerca(destinazione: .attivita(a.id), gruppo: .attivita, titolo: a.titolo,
                                                  dettaglio: "\(nome(a.clienteId)) · \(a.completata ? "completata" : "entro il \(Formati.dataEstesa.string(from: a.scadenza))")"),
                      campi: [("Cliente", nome(a.clienteId)), ("Note", a.note)])
        }
        candidati[.obiettivi] = dati.obiettivi.map { o in
            Candidato(risultato: RisultatoRicerca(destinazione: .obiettivo(o.id), gruppo: .obiettivi, titolo: o.titolo,
                                                  dettaglio: "\(nome(o.clienteId)) · \(Formati.euro(o.importo)) entro il \(Formati.dataEstesa.string(from: o.scadenza))"),
                      campi: [("Cliente", nome(o.clienteId)), ("Note", o.note)])
        }
        candidati[.incontri] = dati.incontri.map { i in
            Candidato(risultato: RisultatoRicerca(destinazione: .incontro(i.id), gruppo: .incontri, titolo: i.titolo,
                                                  dettaglio: "\(nome(i.clienteId)) · \(Formati.dataEstesa.string(from: i.data))"),
                      campi: [("Cliente", nome(i.clienteId)), ("Preoccupazioni", i.preoccupazioni), ("Progetti", i.progetti),
                              ("Esperienza", i.esperienza), ("Appunti", i.appunti), ("Decisioni", i.decisioni),
                              ("Prossima attività", i.prossimaAttivita)])
        }
        candidati[.prodotti] = dati.prodotti.map { p in
            Candidato(risultato: RisultatoRicerca(destinazione: .prodotto(p.id), gruppo: .prodotti, titolo: p.nome,
                                                  dettaglio: [p.emittente, p.tipologia].filter { !$0.isEmpty }.joined(separator: " · "), canale: p.canale),
                      campi: [("Emittente", p.emittente), ("Tipologia", p.tipologia), ("Canale", p.canale.nomeBreve),
                              ("Garanzie", p.garanzie), ("Liquidabilità", p.liquidabilita), ("Fonte", p.fonte), ("Note", p.note)])
        }

        candidati[.azioni] = AzioneRicerca.allCases.filter { $0 != .modoCliente || !stato.inModoCliente }.map { a in
            Candidato(risultato: RisultatoRicerca(destinazione: .app(.ricerca), gruppo: .azioni, titolo: a.titolo,
                                                  dettaglio: a.dettaglio, azione: a),
                      campi: [("Azione", a.paroleChiave)])
        }

        return GruppoRicerca.allCases.compactMap { g in
            sezione(g, candidati[g] ?? [], ricerca: ricerca, parole: parole, limite: perGruppo)
        }
    }

    /// La ricerca per criterio: solo clienti e posizioni che rispettano i filtri, e tra questi quelli con tutte le parole.
    private static func cercaConFiltri(_ r: RicercaInterpretata, in stato: StatoShell, oggi: Date, esito: inout EsitoRicerca) {
        let dati = stato.dati
        let filtrati = FiltriRicerca.applica(r, dati: dati, oggi: oggi)
        esito.totali = filtrati.totali
        esito.totaliDeiClienti = filtrati.totaliDeiClienti
        let nomi = nomiClienti(dati)
        func nome(_ id: String) -> String { nomi[id] ?? "Senza cliente" }
        var prodotti: [String: Prodotto] = [:]
        for x in dati.prodotti { prodotti[x.id] = x }
        let ricerca = r.testoLibero
        let parole = r.parole
        let scadenze = r.filtri.contains { if case .scade = $0 { return true } else { return false } }

        // Posizioni: per scadenza se si filtra la scadenza, altrimenti dalla più grande
        let posizioni = filtrati.posizioni.sorted { a, b in
            if scadenze { return (a.scadenza ?? .distantFuture) < (b.scadenza ?? .distantFuture) }
            return a.valore > b.valore
        }
        let candidatiPosizioni = posizioni.enumerated().map { i, p -> Candidato in
            var risultato = RisultatoRicerca(destinazione: .posizione(p.id), gruppo: .posizioni, titolo: p.nome,
                                             dettaglio: "\(nome(p.clienteId)) · \(p.stato.nome)",
                                             estratto: FiltriRicerca.dettaglio(p, filtri: r.filtriPosizioni, prodotto: p.prodottoId.flatMap { prodotti[$0] }),
                                             canale: p.canale)
            risultato.ordine = i + 1
            return Candidato(risultato: risultato,
                             campi: [("Cliente", nome(p.clienteId)), ("Tipologia", p.tipologia), ("Emittente", p.emittente),
                                     ("Contratto", p.numeroContratto), ("Note", p.note)])
        }
        let filtriClienti = r.filtriClienti.map(\.descrizione).joined(separator: " · ")
        let candidatiClienti = filtrati.clienti.map { c in
            Candidato(risultato: RisultatoRicerca(destinazione: .cliente(c.id), gruppo: .clienti, titolo: c.nome, dettaglio: c.tema,
                                                  estratto: filtriClienti.isEmpty ? nil : filtriClienti),
                      campi: [("Progetto", c.tema), ("Professione", c.professione), ("Nota", c.nota)])
        }
        // Con le parole il nome trovato non si ripete come estratto: l'estratto dei filtri resta
        func conEstratto(_ s: SezioneRicerca?, _ originali: [Candidato]) -> SezioneRicerca? {
            guard let s else { return nil }
            var estratti: [ChiaveRisultato: String] = [:]
            for c in originali { if let e = c.risultato.estratto { estratti[c.risultato.id] = e } }
            let risultati = s.risultati.map { x -> RisultatoRicerca in
                var y = x
                if let e = estratti[x.id] { y.estratto = e }
                return y
            }
            return SezioneRicerca(gruppo: s.gruppo, risultati: risultati, totale: s.totale)
        }
        esito.sezioni = [
            conEstratto(sezione(.clienti, candidatiClienti, ricerca: ricerca, parole: parole, limite: perGruppoFiltri), candidatiClienti),
            conEstratto(sezione(.posizioni, candidatiPosizioni, ricerca: ricerca, parole: parole, limite: perGruppoFiltri), candidatiPosizioni),
        ].compactMap { $0 }
        // Con le parole i totali sono di ciò che resta (tutti i risultati, non solo quelli mostrati)
        guard !parole.isEmpty else { return }
        func ids(_ s: SezioneRicerca?) -> Set<String> {
            Set(s?.risultati.compactMap { x -> String? in
                switch x.destinazione {
                case .posizione(let id), .cliente(let id): return id
                default: return nil
                }
            } ?? [])
        }
        if !r.filtriPosizioni.isEmpty {
            let restano = ids(sezione(.posizioni, candidatiPosizioni, ricerca: ricerca, parole: parole, limite: Int.max))
            esito.totali = FiltriRicerca.totali(filtrati.posizioni.filter { restano.contains($0.id) })
            esito.totaliDeiClienti = false
        } else {
            let restano = ids(sezione(.clienti, candidatiClienti, ricerca: ricerca, parole: parole, limite: Int.max))
            esito.totali = FiltriRicerca.totali(dati.posizioni.filter { $0.stato == .inEssere && restano.contains($0.clienteId) })
            esito.totaliDeiClienti = true
        }
    }
}

extension StatoShell {
    /// Il pannello di ricerca (come Spotlight) è aperto. Vive in `sistema`: aprirlo non ridisegna la shell.
    var pannelloRicerca: Bool {
        get { sistema.pannelloRicerca }
        set { sistema.pannelloRicerca = newValue }
    }

    /// ⌘K: apre il pannello di ricerca in alto, sopra tutto, e mette il cursore nel campo. Non è più una finestra:
    /// il caso `.ricerca` resta tra le app (dock, archivi di prima) ma da qui in avanti porta al pannello.
    func cercaOvunque() {
        guard appConsentita(.ricerca) else {
            mostraAvviso("In modalità cliente la Ricerca non si apre: mostra i dati di altri clienti.")
            return
        }
        guard !bloccato, presentazione == nil else { return }
        // Un pannello alla volta, come in macOS
        if pannelloNotifiche { pannelloNotifiche = false }
        if pannelloSpazi { pannelloSpazi = false }
        if pannelloAppAperte { pannelloAppAperte = false }
        if !pannelloRicerca { pannelloRicerca = true }
        richiestaFuocoRicerca += 1
    }

    /// ⌘K e il pulsante «Cerca» della barra: apre o chiude il pannello.
    func alternaRicerca() {
        if pannelloRicerca { chiudiRicerca() } else { cercaOvunque() }
    }

    func chiudiRicerca() {
        if pannelloRicerca { pannelloRicerca = false }
    }

    /// Apre un'app dall'interfaccia (dock, menu Vai, comandi di Eve): la Ricerca è il pannello, le altre una finestra.
    func apriApp(_ app: AppPrisma, da origine: CGPoint? = nil) {
        if app == .ricerca {
            cercaOvunque()
        } else {
            apri(app, da: origine)
        }
    }

    /// Esegue un'azione rapida del pannello (quelle con un modulo le apre il pannello stesso).
    func eseguiAzione(_ azione: AzioneRicerca) {
        switch azione {
        case .nuovoAppuntamento:
            filtroClienteAgenda = nil
            apri(.agenda)
        case .nuovaAttivita:
            apri(.attivita)
        case .nuovaNota:
            if nuovaNota(clienteId: clienti.contains { $0.id == clienteAttivoId } ? clienteAttivoId : nil) != nil { apri(.note) }
        case .creaBackup:
            creaBackup()
        case .modoCliente:
            alternaModoCliente()
        case .spaziLavoro:
            if !inModoCliente { pannelloSpazi = true }
        case .appAperte:
            pannelloAppAperte = true
        case .notifiche:
            if !pannelloNotifiche { alternaNotifiche() }
        case .scrivania:
            mostraScrivania()
        }
    }

    /// Le ricerche salvate (nelle impostazioni dell'archivio: vanno nel backup).
    var ricercheSalvate: [RicercaSalvata] { dati.impostazioni.ricercheSalvate }

    /// Salva il testo della ricerca con un nome; lo stesso testo si aggiorna invece di ripetersi.
    func salvaRicerca(_ testo: String, nome: String) {
        let t = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !solaLettura else { return }
        let n = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = RicercaSalvata(nome: n.isEmpty ? t : n, testo: t)
        if let i = dati.impostazioni.ricercheSalvate.firstIndex(where: { $0.testo == t }) {
            dati.impostazioni.ricercheSalvate[i].nome = r.nome
        } else {
            dati.impostazioni.ricercheSalvate.insert(r, at: 0)
        }
        mostraAvviso("Ricerca salvata: «\(r.nome)».")
    }

    func eliminaRicerca(_ id: String) {
        guard !solaLettura else { return }
        dati.impostazioni.ricercheSalvate.removeAll { $0.id == id }
    }

    /// Apre il risultato nella sua app, già selezionato.
    func vai(a destinazione: DestinazioneRicerca) {
        switch destinazione {
        case .app(let app):
            apriApp(app)
        case .cliente(let id):
            apriCliente(id)
        case .posizione(let id):
            if let p = dati.posizioni.first(where: { $0.id == id }) { apriPosizione(p) }
        case .documento(let id):
            guard let d = documento(id) else { return }
            clienteAttivoId = d.clienteId
            documentoSelezionato = d.id
            apri(.documenti)
        case .nota(let id):
            guard let n = nota(id) else { return }
            ricercaNote = ""
            if filtroClienteNote != nil { filtroClienteNote = n.clienteId }
            scegliNota(n.id)
            apri(.note)
        case .appuntamento(let id):
            guard let a = appuntamenti.first(where: { $0.id == id }) else { return }
            filtroClienteAgenda = nil
            giornoAgenda = Calendar.current.startOfDay(for: a.inizio)
            appuntamentoSelezionato = a.id
            apri(.agenda)
        case .attivita(let id):
            guard let a = attivita.first(where: { $0.id == id }) else { return }
            filtroClienteAttivita = nil
            filtroPrioritaAttivita = nil
            if a.completata && filtroStatoAttivita == .aperte || !a.completata && filtroStatoAttivita == .completate {
                filtroStatoAttivita = .tutte
            }
            attivitaSelezionata = a.id
            apri(.attivita)
        case .obiettivo(let id):
            guard let o = dati.obiettivi.first(where: { $0.id == id }) else { return }
            clienteAttivoId = o.clienteId
            obiettivoSelezionato = o.id
            apri(.obiettivi)
        case .incontro(let id):
            guard let i = dati.incontri.first(where: { $0.id == id }) else { return }
            clienteAttivoId = i.clienteId
            incontroAperto = i.id
            apri(.incontri)
        case .prodotto(let id):
            filtroCanaleProdotti = nil
            filtroAreaProdotti = nil
            prodottoSelezionato = id
            apri(.prodotti)
        }
    }
}
