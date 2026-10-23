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

    var titoloMostrato: String {
        let t = titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Nota senza titolo" : t
    }

    /// Le prime parole del testo, su una riga.
    var anteprima: String {
        let compatto = testo.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return compatto.isEmpty ? "Una pagina pronta per le tue idee." : String(compatto.prefix(95))
    }

    var vuota: Bool {
        titolo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && testo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Le note fissate prima, poi dalla più recente.
    static func ordina(_ a: Nota, _ b: Nota) -> Bool {
        a.fissata != b.fissata ? a.fissata : a.aggiornataIl > b.aggiornataIl
    }
}
