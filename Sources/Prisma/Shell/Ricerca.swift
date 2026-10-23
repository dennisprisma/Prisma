import Foundation

/// «Cerca ovunque» (⌘K): una sola ricerca su app, clienti, posizioni, documenti (anche nel testo
/// delle pagine), appuntamenti, attività, obiettivi, incontri e prodotti. Tutto avviene sul Mac,
/// sui dati dell'archivio locale.
enum GruppoRicerca: String, CaseIterable, Identifiable {
    case app, clienti, posizioni, documenti, appuntamenti, attivita, obiettivi, incontri, prodotti

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .app: return "App"
        case .clienti: return "Clienti"
        case .posizioni: return "Posizioni"
        case .documenti: return "Documenti"
        case .appuntamenti: return "Appuntamenti"
        case .attivita: return "Attività"
        case .obiettivi: return "Obiettivi"
        case .incontri: return "Incontri"
        case .prodotti: return "Prodotti"
        }
    }

    /// L'app che apre i risultati del gruppo (e ne presta l'icona).
    var app: AppPrisma {
        switch self {
        case .app: return .ricerca
        case .clienti: return .clienti
        case .posizioni: return .posizioni
        case .documenti: return .documenti
        case .appuntamenti: return .agenda
        case .attivita: return .attivita
        case .obiettivi: return .obiettivi
        case .incontri: return .incontri
        case .prodotti: return .prodotti
        }
    }
}

/// Dove porta un risultato.
enum DestinazioneRicerca: Hashable {
    case app(AppPrisma)
    case cliente(String)
    case posizione(String)
    case documento(String)
    case appuntamento(String)
    case attivita(String)
    case obiettivo(String)
    case incontro(String)
    case prodotto(String)
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

    var id: DestinazioneRicerca { destinazione }

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
}

enum MotoreRicerca {
    /// Risultati mostrati per gruppo.
    static let perGruppo = 5
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
        let ricerca = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        let parole = parole(ricerca)
        guard !parole.isEmpty else { return [] }
        let dati = stato.dati
        var nomi: [String: String] = [:]
        for c in dati.clienti { nomi[c.id] = c.nome }
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
                      pagine: stato.testoDocumento(d))
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

        return GruppoRicerca.allCases.compactMap { g in
            let trovati = (candidati[g] ?? []).compactMap { valuta($0, ricerca: ricerca, parole: parole) }
                .sorted { $0.punteggio != $1.punteggio ? $0.punteggio > $1.punteggio
                    : $0.titolo.localizedCaseInsensitiveCompare($1.titolo) == .orderedAscending }
            guard !trovati.isEmpty else { return nil }
            return SezioneRicerca(gruppo: g, risultati: Array(trovati.prefix(perGruppo)), totale: trovati.count)
        }
    }
}

extension StatoShell {
    /// ⌘K: apre la Ricerca e mette il cursore nel campo.
    func cercaOvunque() {
        apri(.ricerca)
        richiestaFuocoRicerca += 1
    }

    /// Apre il risultato nella sua app, già selezionato.
    func vai(a destinazione: DestinazioneRicerca) {
        switch destinazione {
        case .app(let app):
            apri(app)
        case .cliente(let id):
            apriCliente(id)
        case .posizione(let id):
            if let p = dati.posizioni.first(where: { $0.id == id }) { apriPosizione(p) }
        case .documento(let id):
            guard let d = documento(id) else { return }
            clienteAttivoId = d.clienteId
            documentoSelezionato = d.id
            apri(.documenti)
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
