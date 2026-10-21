import Foundation

/// Un incontro con il cliente: preparazione, ascolto, appunti e decisioni, prossimi passi.
/// È il luogo dove il profilo dei bisogni si aggiorna: dalle risposte e dagli appunti
/// Prisma (o Eve) propone bisogni, eventi di vita e attività da confermare.
struct Incontro: Identifiable, Codable, Hashable {
    enum Stato: String, Codable { case preparazione, concluso }

    var id = "incontro-\(UUID().uuidString.prefix(8).lowercased())"
    var clienteId: String
    var titolo: String
    var data: Date
    /// Appuntamento dell'agenda a cui si riferisce.
    var appuntamentoId: String?
    var stato = Stato.preparazione
    /// Aree dell'Analisi 360 da affrontare.
    var temi: [AreaAnalisi] = AreaAnalisi.allCases
    // Le tre domande aperte
    var preoccupazioni = ""
    var progetti = ""
    var esperienza = ""
    var appunti = ""
    var decisioni = ""
    // Prossimi passi
    var prossimaAttivita = ""
    var scadenzaAttivita: Date?
    var prossimoIncontro: Date?
    /// Collegamenti creati alla chiusura.
    var attivitaCreataId: String?
    var appuntamentoCreatoId: String?
    var aggiornatoIl: Date?

    init(clienteId: String, titolo: String, data: Date, appuntamentoId: String? = nil) {
        self.clienteId = clienteId
        self.titolo = titolo
        self.data = data
        self.appuntamentoId = appuntamentoId
    }

    /// Tutto il testo scritto durante l'incontro (per l'estrazione).
    var testoAscolto: String {
        [preoccupazioni, progetti, esperienza, appunti, decisioni].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    var vuoto: Bool { testoAscolto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private enum CodingKeys: String, CodingKey {
        case id, clienteId, titolo, data, appuntamentoId, stato, temi, preoccupazioni, progetti, esperienza, appunti, decisioni
        case prossimaAttivita, scadenzaAttivita, prossimoIncontro, attivitaCreataId, appuntamentoCreatoId, aggiornatoIl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        clienteId = try c.decode(String.self, forKey: .clienteId)
        titolo = try c.decodeIfPresent(String.self, forKey: .titolo) ?? "Incontro"
        data = try c.decodeIfPresent(Date.self, forKey: .data) ?? Date()
        appuntamentoId = try c.decodeIfPresent(String.self, forKey: .appuntamentoId)
        stato = try c.decodeIfPresent(Stato.self, forKey: .stato) ?? .preparazione
        temi = (try? c.decodeIfPresent([AreaAnalisi].self, forKey: .temi)) ?? AreaAnalisi.allCases
        preoccupazioni = try c.decodeIfPresent(String.self, forKey: .preoccupazioni) ?? ""
        progetti = try c.decodeIfPresent(String.self, forKey: .progetti) ?? ""
        esperienza = try c.decodeIfPresent(String.self, forKey: .esperienza) ?? ""
        appunti = try c.decodeIfPresent(String.self, forKey: .appunti) ?? ""
        decisioni = try c.decodeIfPresent(String.self, forKey: .decisioni) ?? ""
        prossimaAttivita = try c.decodeIfPresent(String.self, forKey: .prossimaAttivita) ?? ""
        scadenzaAttivita = try c.decodeIfPresent(Date.self, forKey: .scadenzaAttivita)
        prossimoIncontro = try c.decodeIfPresent(Date.self, forKey: .prossimoIncontro)
        attivitaCreataId = try c.decodeIfPresent(String.self, forKey: .attivitaCreataId)
        appuntamentoCreatoId = try c.decodeIfPresent(String.self, forKey: .appuntamentoCreatoId)
        aggiornatoIl = try c.decodeIfPresent(Date.self, forKey: .aggiornatoIl)
    }
}

/// Le tre domande aperte dell'ascolto.
enum DomandaAscolto: String, CaseIterable, Identifiable {
    case preoccupazioni, progetti, esperienza

    var id: String { rawValue }

    var domanda: String {
        switch self {
        case .preoccupazioni: return "Cosa la preoccupa di più, oggi?"
        case .progetti: return "Cosa vorrebbe realizzare nei prossimi cinque anni?"
        case .esperienza: return "Come ha vissuto risparmi e investimenti finora?"
        }
    }

    var suggerimento: String {
        switch self {
        case .preoccupazioni: return "Famiglia, lavoro, salute, debiti… con le sue parole."
        case .progetti: return "Casa, figli, attività, viaggi, pensione: cosa e quando."
        case .esperienza: return "Perdite, delusioni, cosa l'ha fatto stare tranquillo."
        }
    }
}
