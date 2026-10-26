import Foundation

/// Una nota del taccuino: appunti, dettagli e prossimi passi, sempre legati a un cliente.
struct Nota: Identifiable, Codable, Hashable {
    var id = "nota-\(UUID().uuidString.prefix(8).lowercased())"
    var clienteId: String
    var titolo: String
    var testo: String
    /// In evidenza: resta in cima all'elenco.
    var fissata = false
    var creataIl = Nota.adesso
    var aggiornataIl = Nota.adesso

    /// L'archivio salva le date al secondo: le note nascono già così, e si rileggono identiche.
    static var adesso: Date { Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down)) }

    /// Limite del titolo (come nel template).
    static let limiteTitolo = 180
    /// Caratteri di ogni nota passati a Eve nella scheda del cliente.
    static let limiteEve = 300

    var titoloMostrato: String {
        let t = titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Nota senza titolo" : t
    }

    /// Le prime parole del testo, su una riga.
    var anteprima: String {
        let compatto = testo.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !compatto.isEmpty else { return "Una pagina pronta per le tue idee." }
        guard compatto.count > Nota.limiteAnteprima else { return compatto }
        // Si taglia all'ultimo spazio, mai a metà parola
        let inizio = compatto.prefix(Nota.limiteAnteprima)
        let taglio = inizio.lastIndex(of: " ").map { String(inizio[..<$0]) } ?? String(inizio)
        return taglio.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:.")) + "…"
    }

    /// Caratteri dell'anteprima su una riga.
    static let limiteAnteprima = 95

    /// Il testo su una riga, fino a `n` caratteri (per Eve).
    func estratto(_ n: Int) -> String {
        String(testo.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(n))
    }

    var vuota: Bool {
        titolo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Le note fissate prima, poi dalla più recente.
    static func ordina(_ a: Nota, _ b: Nota) -> Bool {
        a.fissata != b.fissata ? a.fissata : a.aggiornataIl > b.aggiornataIl
    }
}
