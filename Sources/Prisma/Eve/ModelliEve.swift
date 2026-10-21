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

    init(autore: Autore, testo: String, titolo: String? = nil, motore: String? = nil) {
        self.autore = autore
        self.testo = testo
        self.titolo = titolo
        self.motore = motore
        data = Appuntamento.alMinuto(Date())
    }

    private enum CodingKeys: String, CodingKey { case id, autore, testo, titolo, motore, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        autore = try c.decodeIfPresent(Autore.self, forKey: .autore) ?? .eve
        testo = try c.decodeIfPresent(String.self, forKey: .testo) ?? ""
        titolo = try c.decodeIfPresent(String.self, forKey: .titolo)
        motore = try c.decodeIfPresent(String.self, forKey: .motore)
        data = try c.decodeIfPresent(Date.self, forKey: .data) ?? Date()
    }
}

/// Gli spunti pronti sotto la conversazione.
enum SpuntoEve: String, CaseIterable, Identifiable {
    case incontro, riepilogo, prossimiPassi, protezione, scadenze

    var id: String { rawValue }

    var domanda: String {
        switch self {
        case .incontro: return "Prepara il prossimo incontro"
        case .riepilogo: return "Fammi un riepilogo del cliente"
        case .prossimiPassi: return "Elenca i prossimi passi"
        case .protezione: return "Dove è scoperta la protezione?"
        case .scadenze: return "Spiegami le scadenze in arrivo"
        }
    }

    var simbolo: String {
        switch self {
        case .incontro: return "◷"
        case .riepilogo: return "≡"
        case .prossimiPassi: return "✓"
        case .protezione: return "◈"
        case .scadenze: return "!"
        }
    }

    /// Riconosce uno spunto anche se scritto a mano.
    static func da(_ testo: String) -> SpuntoEve? {
        let t = testo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first { $0.domanda.lowercased() == t }
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
