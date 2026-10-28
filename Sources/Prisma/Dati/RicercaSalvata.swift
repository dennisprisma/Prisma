import Foundation

/// Una ricerca del pannello ⌘K salvata con un nome («Scadenze 2027 Alleanza» = `scade:2027 canale:alleanza`).
/// Sta nelle impostazioni dell'archivio, così va nel backup. Lettura tollerante: ogni campo ha un ripiego.
struct RicercaSalvata: Codable, Equatable, Identifiable {
    var id = "ricerca-\(UUID().uuidString.prefix(8).lowercased())"
    var nome: String
    /// Il testo del campo, filtri compresi.
    var testo: String
    var creataIl = Date()

    init(nome: String, testo: String) {
        self.nome = nome
        self.testo = testo
    }

    private enum CodingKeys: String, CodingKey {
        case id, nome, testo, creataIl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        testo = try c.decodeIfPresent(String.self, forKey: .testo) ?? ""
        nome = try c.decodeIfPresent(String.self, forKey: .nome) ?? testo
        if let id = try c.decodeIfPresent(String.self, forKey: .id) { self.id = id }
        if let data = try c.decodeIfPresent(Date.self, forKey: .creataIl) { creataIl = data }
    }
}
