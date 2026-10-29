import Foundation

/// Perché una proposta è stata rifiutata o rimandata: serve all'analisi del Portafoglio (dalla versione 21 dell'archivio).
enum MotivoEsito: String, Codable, CaseIterable, Identifiable {
    case costo, prodotto, rischio, altraSoluzione, liquidita, tempi, famiglia, documenti, altro

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .costo: return "Costi o premio troppo alti"
        case .prodotto: return "Il prodotto non lo convince"
        case .rischio: return "Troppo rischio per lui"
        case .altraSoluzione: return "Ha già un'altra soluzione"
        case .liquidita: return "Non ha la liquidità adesso"
        case .tempi: return "Non è il momento"
        case .famiglia: return "Ne deve parlare in famiglia"
        case .documenti: return "Mancano documenti o dati"
        case .altro: return "Altro"
        }
    }

    /// Le voci proposte per un rifiuto e per un rinvio (nel menu, in quest'ordine).
    static let perRifiuto: [MotivoEsito] = [.costo, .prodotto, .rischio, .altraSoluzione, .liquidita, .altro]
    static let perRinvio: [MotivoEsito] = [.tempi, .liquidita, .famiglia, .documenti, .altro]
}

/// Il seguito di una proposta (dalla versione 21 dell'archivio). Tutto facoltativo: senza, valgono le regole
/// di ripiego del motore del seguito.
struct SeguitoProposta: Codable, Hashable {
    /// L'ultima volta che è stata presentata (appuntamento di proposta concluso o esito «presentata» scelto a mano).
    var presentataIl: Date?
    /// Quando è stato segnato l'esito (accettata, rifiutata, rimandata).
    var esitoIl: Date?
    var motivo: MotivoEsito?
    /// Il motivo a parole o una nota sull'esito.
    var nota = ""
    /// Rimandata: quando riprenderla.
    var riprendereIl: Date?
    /// Rimandata: l'attività «Riprendere la proposta…» creata con il rinvio.
    var attivitaId: String?
    /// L'appuntamento in cui è stato chiesto l'esito: il riquadro non lo richiede per lo stesso appuntamento.
    var appuntamentoEsitoId: String?

    init() {}

    /// Vuoto: si salva `nil` al posto di un oggetto vuoto.
    var vuoto: Bool {
        presentataIl == nil && esitoIl == nil && motivo == nil && nota.isEmpty && riprendereIl == nil
            && attivitaId == nil && appuntamentoEsitoId == nil
    }

    private enum CodingKeys: String, CodingKey {
        case presentataIl, esitoIl, motivo, nota, riprendereIl, attivitaId, appuntamentoEsitoId
    }

    /// Lettura tollerante, come `Movimento`: un dato malformato (un motivo sconosciuto, un tipo sbagliato)
    /// diventa nil e non fa scartare la posizione né l'archivio.
    init(from decoder: Decoder) throws {
        self.init()
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        presentataIl = try? c.decodeIfPresent(Date.self, forKey: .presentataIl)
        esitoIl = try? c.decodeIfPresent(Date.self, forKey: .esitoIl)
        motivo = try? c.decodeIfPresent(MotivoEsito.self, forKey: .motivo)
        nota = (try? c.decodeIfPresent(String.self, forKey: .nota)) ?? ""
        riprendereIl = try? c.decodeIfPresent(Date.self, forKey: .riprendereIl)
        attivitaId = try? c.decodeIfPresent(String.self, forKey: .attivitaId)
        appuntamentoEsitoId = try? c.decodeIfPresent(String.self, forKey: .appuntamentoEsitoId)
    }
}

extension Impostazioni {
    /// I giorni che si possono scegliere per il seguito delle proposte.
    static let sceltaGiorniSeguito = [14, 21, 30, 45, 60]
    static let giorniSeguitoPredefiniti = 21
}
