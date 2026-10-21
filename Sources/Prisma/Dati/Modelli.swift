import Foundation

/// Canale con cui il consulente lavora una posizione o una proposta.
enum Canale: String, Codable, CaseIterable, Identifiable {
    case alleanza
    case indipendente

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .alleanza: return "Alleanza Assicurazioni"
        case .indipendente: return "Dennis Vincenzoni · Consulenza finanziaria"
        }
    }

    var nomeBreve: String {
        switch self {
        case .alleanza: return "Alleanza"
        case .indipendente: return "Indipendente"
        }
    }
}

/// Tinta dell'avatar del cliente (come le classi .os-avatar del template).
enum TintaAvatar: String, Codable {
    case blu, rosa, verde, viola, oro
}

struct Cliente: Identifiable, Codable, Hashable {
    let id: String
    var nome: String
    var iniziali: String
    var tinta: TintaAvatar
    var tema: String
    var email: String
    var telefono: String
    var preferito: Bool
    var nota: String
    var creatoIl: Date
}

struct Appuntamento: Identifiable, Codable, Hashable {
    enum Stato: String, Codable { case pianificato, concluso }

    let id: String
    var clienteId: String
    var titolo: String
    var inizio: Date
    var durataMinuti: Int
    var luogo: String
    var note: String
    var stato: Stato
}

struct Attivita: Identifiable, Codable, Hashable {
    enum Priorita: String, Codable { case alta, normale, bassa }

    let id: String
    var clienteId: String
    var titolo: String
    var scadenza: Date
    var priorita: Priorita
    var completata: Bool
}
