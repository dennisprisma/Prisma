import Foundation

/// Un messaggio della conversazione con Eve (salvato nel dossier del cliente).
struct MessaggioEve: Identifiable, Codable, Equatable {
    enum Autore: String, Codable { case utente, eve }

    var id = "msg-\(UUID().uuidString.prefix(8).lowercased())"
    var autore: Autore
    var testo: String
    /// Titolo breve delle risposte di Eve.
    var titolo: String?
    /// Motore che ha prodotto la risposta ("Modello Apple", "Sintesi dai dati").
    var motore: String?
    var data = Date()
    /// Le azioni proposte da Eve (spunto «Cosa proporre al cliente?»), con quello che ne è stato fatto.
    var proposte: [PropostaEve]?

    init(autore: Autore, testo: String, titolo: String? = nil, motore: String? = nil, proposte: [PropostaEve]? = nil) {
        self.autore = autore
        self.testo = testo
        self.titolo = titolo
        self.motore = motore
        self.proposte = proposte
        data = Appuntamento.alMinuto(Date())
    }

    private enum CodingKeys: String, CodingKey { case id, autore, testo, titolo, motore, data, proposte }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        autore = try c.decodeIfPresent(Autore.self, forKey: .autore) ?? .eve
        testo = try c.decodeIfPresent(String.self, forKey: .testo) ?? ""
        titolo = try c.decodeIfPresent(String.self, forKey: .titolo)
        motore = try c.decodeIfPresent(String.self, forKey: .motore)
        data = try c.decodeIfPresent(Date.self, forKey: .data) ?? Date()
        proposte = try? c.decodeIfPresent([PropostaEve].self, forKey: .proposte)
    }
}

/// Un'azione che Eve propone per il cliente, ricavata dai motori di analisi: diventa un'attività
/// o una bozza di proposta in Posizioni, sempre da completare e confermare dal consulente.
struct PropostaEve: Codable, Equatable, Identifiable {
    /// Chiave stabile ("protezione-vita", "obiettivo-<id>"…).
    var id: String
    var titolo: String
    /// Il perché, con le cifre dei motori.
    var perche: String
    /// Area della posizione da proporre (nil se è solo un'attività).
    var area: AreaPosizione?
    var rischio: RischioCoperto?
    var capitale: Double?
    var versamentoMensile: Double?
    var importo: Double?
    /// Cosa ne ha fatto il consulente.
    var attivitaId: String?
    var posizioneId: String?
}

/// Gli spunti pronti sotto la conversazione. Quelli di analisi leggono gli stessi motori dei
/// prospetti e dei report: i numeri di Eve e quelli dei documenti coincidono.
enum SpuntoEve: String, CaseIterable, Identifiable {
    case riepilogo, checkUp, proposte, incontro, prossimiPassi, resoconto, resistenza, pensione, protezione, liquidita, obiettivi, cambiare, documenti, scadenze

    var id: String { rawValue }

    var domanda: String {
        switch self {
        case .riepilogo: return "Fammi un riepilogo del cliente"
        case .checkUp: return "Fai il check-up del cliente"
        case .proposte: return "Cosa proporre al cliente?"
        case .incontro: return "Prepara il prossimo incontro"
        case .prossimiPassi: return "Elenca i prossimi passi"
        case .resoconto: return "Come stanno andando le posizioni?"
        case .resistenza: return "Cosa succede se i mercati crollano?"
        case .pensione: return "Spiegami il piano pensione"
        case .protezione: return "Dove è scoperta la protezione?"
        case .liquidita: return "Cosa fare della liquidità?"
        case .obiettivi: return "A che punto sono gli obiettivi?"
        case .cambiare: return "Conviene restare o cambiare?"
        case .documenti: return "Cosa dicono i documenti?"
        case .scadenze: return "Spiegami le scadenze in arrivo"
        }
    }

    var simbolo: String {
        switch self {
        case .riepilogo: return "≡"
        case .checkUp: return "●"
        case .proposte: return "✚"
        case .incontro: return "◷"
        case .prossimiPassi: return "✓"
        case .resoconto: return "↗"
        case .resistenza: return "↘"
        case .pensione: return "☂"
        case .protezione: return "◈"
        case .liquidita: return "€"
        case .obiettivi: return "◎"
        case .cambiare: return "⇄"
        case .documenti: return "▤"
        case .scadenze: return "!"
        }
    }

    /// Riconosce uno spunto anche se scritto a mano.
    static func da(_ testo: String) -> SpuntoEve? {
        let t = testo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first { $0.domanda.lowercased() == t }
    }

    /// L'argomento di una domanda libera, dalle parole chiave (per la sintesi dai dati, che non capisce
    /// le frasi): "quanto paga di tasse se riscatta il fondo pensione?" → pensione.
    static func argomento(_ testo: String) -> SpuntoEve? {
        // Ogni chiave è l'inizio di una parola ("pension" sì in «pensione», no in «sospensione»);
        // con \b in fondo vale solo la parola intera («passi» sì, «passività» no).
        let parole: [(SpuntoEve, [String])] = [
            (.resistenza, ["croll", #"crisi\b"#, "stress", "resisten", "ribass", #"perder[eà]\b"#]),
            (.riepilogo, [#"patrimonio netto\b"#]),
            (.proposte, [#"proporre\b"#, "proposte da fare", "cosa gli propongo", "cosa le propongo", "opportunità"]),
            (.pensione, ["pension", "previdenz", "anticipazion", #"tfr\b"#, "deducib"]),
            (.cambiare, [#"cambiare\b"#, "sostitu", #"restare\b"#, #"switch\b"#, "conviene"]),
            (.documenti, [#"document[oi]\b"#, #"kid\b"#, "estratto conto", "set informativo"]),
            (.liquidita, ["liquidit", "conto corrente", "in scadenza", "salvadana"]),
            (.obiettivi, ["obiettiv", "traguard"]),
            (.protezione, ["protezion", "copertur", #"tcm\b"#, "caso morte", "invalidit"]),
            (.resoconto, ["rendiment", "andament", "guadagn", #"tasse\b"#, #"impost[ae]\b"#, #"costi\b"#, #"netto\b"#, "resoconto"]),
            (.checkUp, ["check", "semaforo"]),
            (.scadenze, ["scadenz", #"scad[eo]\b"#]),
            (.incontro, [#"incontr[oi]\b"#, "appuntament"]),
            (.prossimiPassi, [#"passi\b"#, "cosa fare", "da fare"]),
            (.riepilogo, ["riepilog", "quadro", "situazione", "patrimonio"])
        ]
        let r = NSRange(testo.startIndex..., in: testo)
        return parole.first { voce in
            voce.1.contains { chiave in
                (try? NSRegularExpression(pattern: #"\b"# + chiave, options: [.caseInsensitive]))?.firstMatch(in: testo, range: r) != nil
            }
        }?.0
    }
}

/// Tutto ciò che Eve sa del cliente in questo momento: lo prepara l'app, con i suoi motori di calcolo.
struct FonteEve {
    let oggi: Date
    let nomeUtente: String
    let cliente: Cliente
    let posizioni: [Posizione]
    let appuntamenti: [Appuntamento]
    let attivita: [Attivita]
    let analisi: Analisi360
    let analisiSalvata: Bool
    let simulazioni: [Simulazione]
    var incontri: [Incontro] = []
    var obiettivi: [Obiettivo] = []
    /// Catalogo dei prodotti: penali, condizioni e costi per i calcoli fiscali e di sostituzione.
    var prodotti: [Prodotto] = []
    /// Documenti del cliente con i dati estratti (KID, polizze, estratti conto).
    var documenti: [Documento] = []
    /// Note del taccuino, le fissate prima e poi dalla più recente.
    var note: [Nota] = []
    /// Le due posizioni del confronto scelto in Prospetti e report (altrimenti la coppia predefinita)
    /// e gli anni della simulazione.
    var confronto: (attuale: String, alternativa: String)?
    var anniConfronto: Int?
}

extension SceltaProspetto {
    /// Lo spunto di Eve che spiega questo documento (nil se Eve non ne ha uno).
    var spuntoEve: SpuntoEve? {
        switch self {
        case .resoconto: return .resoconto
        case .sostituzione: return .cambiare
        case .previdenza: return .pensione
        case .protezione: return .protezione
        case .obiettivo: return .obiettivi
        case .liquidita: return .liquidita
        case .checkUp: return .checkUp
        case .resistenza: return .resistenza
        case .riesame: return .incontro
        case .posizione, .confronto, .valutazione, .portafoglio: return nil
        }
    }
}

struct RichiestaEve {
    let domanda: String
    let spunto: SpuntoEve?
    let fonte: FonteEve
    /// Ultimi messaggi della conversazione (per le domande di seguito).
    let storia: [MessaggioEve]
}

struct RispostaEve {
    var titolo: String?
    let testo: String
    var proposte: [PropostaEve]? = nil
}

enum DisponibilitaEve: Equatable {
    case pronto
    case nonDisponibile(String)

    var pronto: Bool { self == .pronto }

    var motivo: String? {
        if case .nonDisponibile(let m) = self { return m }
        return nil
    }
}

/// Un motore di Eve. Se ne possono aggiungere altri (per esempio un modello Qwen in locale)
/// senza toccare l'app: basta rispettare questo protocollo.
protocol MotoreEve {
    /// Nome mostrato nell'app e accanto alle risposte.
    var nome: String { get }
    /// Riga che spiega all'utente cosa fa il motore e dove lavora.
    var descrizione: String { get }
    var disponibilita: DisponibilitaEve { get }
    func rispondi(_ richiesta: RichiestaEve) async throws -> RispostaEve
}

struct ErroreEve: LocalizedError {
    let messaggio: String
    var errorDescription: String? { messaggio }
}
