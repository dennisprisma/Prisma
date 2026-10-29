import Foundation

/// Le voci del confronto «Nel documento / In Prisma» (dalla versione 23 dell'archivio). L'ordine dei casi
/// è quello delle righe della tabella.
enum VoceDossier: String, Codable, CaseIterable, Identifiable {
    case beneficiari, premio, capitaleAssicurato, scadenza
    case sri, periodoRaccomandato, costoIngresso, costoGestione, incidenzaCosti, rendimentoLordo

    var id: String { rawValue }

    /// Il dato del documento da cui viene (per il rendimento lordo: quello della pagina e della fonte «p. N»;
    /// il valore si calcola con `MotoreConfrontoDossier.rendimentoLordo`).
    var campo: CampoDocumento {
        switch self {
        case .beneficiari: return .beneficiari
        case .premio: return .premio
        case .capitaleAssicurato: return .capitaleAssicurato
        case .scadenza: return .scadenza
        case .sri: return .sri
        case .periodoRaccomandato: return .periodoDetenzione
        case .costoIngresso: return .costoIngresso
        case .costoGestione: return .costoAnnuo
        case .incidenzaCosti: return .incidenzaCosti
        case .rendimentoLordo: return .rendimentoModerato
        }
    }

    /// Voci di rischio e di costo: un loro aumento in un nuovo KID apre l'impatto sui clienti.
    var rischioOCosto: Bool { [.sri, .costoIngresso, .costoGestione, .incidenzaCosti].contains(self) }

    /// Le voci che ha anche una scheda prodotto (le altre sono solo dei contratti).
    var diProdotto: Bool { ![.beneficiari, .premio, .capitaleAssicurato, .scadenza].contains(self) }
}

/// Un valore di una voce, per il confronto e per lo storico. Struttura a campi facoltativi (non un enum con
/// valori associati): il JSON resta semplice e tollerante.
struct ValoreVoce: Codable, Hashable {
    /// Beneficiari.
    var testo: String?
    /// Importi (€), percentuali (%), SRI e anni (interi scritti come numero).
    var numero: Double?
    /// Scadenza (a mezzogiorno, secondi interi).
    var data: Date?
    /// Solo per il premio: `Frequenza.rawValue`; "unica" = premio unico (il versamento iniziale della posizione).
    var frequenza: String?

    init(testo: String? = nil, numero: Double? = nil, data: Date? = nil, frequenza: String? = nil) {
        self.testo = testo
        self.numero = numero
        self.data = data
        self.frequenza = frequenza
    }
}

/// Un dato del dossier cambiato dal confronto con un documento (o rimesso com'era): resta nello storico della
/// posizione o della scheda, anche se il documento poi si elimina (dalla versione 23 dell'archivio).
struct VariazioneDossier: Codable, Hashable, Identifiable {
    var id = "var-\(UUID().uuidString.prefix(8).lowercased())"
    /// `VoceDossier.rawValue` (stringa: una voce di una versione futura si legge lo stesso e si mostra com'è).
    var voce = ""
    /// Testi come li mostrava il confronto («200.000 €», «3 su 7», «—» se vuoto).
    var prima = ""
    var dopo = ""
    /// Il valore del campo prima e dopo (nil = vuoto): serve al ripristino.
    var valorePrima: ValoreVoce?
    var valoreDopo: ValoreVoce?
    /// Documento da cui viene (nil per un ripristino).
    var documentoId: String?
    /// Titolo e tipo del documento al momento dell'aggiornamento: restano anche se il documento si elimina.
    var titoloDocumento = ""
    var tipoDocumento = ""
    var il = Date(timeIntervalSinceReferenceDate: 0)
    /// Schede prodotto: la fonte che aveva la scheda prima di questo aggiornamento.
    var fontePrecedente: String?
    /// Ripristino: l'id della variazione annullata.
    var ripristinoDi: String?

    init(voce: String, prima: String, dopo: String, valorePrima: ValoreVoce?, valoreDopo: ValoreVoce?,
         documentoId: String?, titoloDocumento: String, tipoDocumento: String, il: Date,
         fontePrecedente: String? = nil, ripristinoDi: String? = nil) {
        self.voce = voce
        self.prima = prima
        self.dopo = dopo
        self.valorePrima = valorePrima
        self.valoreDopo = valoreDopo
        self.documentoId = documentoId
        self.titoloDocumento = titoloDocumento
        self.tipoDocumento = tipoDocumento
        self.il = il
        self.fontePrecedente = fontePrecedente
        self.ripristinoDi = ripristinoDi
    }

    private enum CodingKeys: String, CodingKey {
        case id, voce, prima, dopo, valorePrima, valoreDopo, documentoId, titoloDocumento, tipoDocumento, il, fontePrecedente, ripristinoDi
    }

    /// Lettura tollerante (come `Movimento`): una variazione malformata non fa scartare la posizione né l'archivio.
    init(from decoder: Decoder) throws {
        // Tutto ai valori predefiniti se non è nemmeno un oggetto
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        id = (try? c.decode(String.self, forKey: .id)) ?? id
        voce = (try? c.decode(String.self, forKey: .voce)) ?? ""
        prima = (try? c.decode(String.self, forKey: .prima)) ?? ""
        dopo = (try? c.decode(String.self, forKey: .dopo)) ?? ""
        valorePrima = try? c.decodeIfPresent(ValoreVoce.self, forKey: .valorePrima)
        valoreDopo = try? c.decodeIfPresent(ValoreVoce.self, forKey: .valoreDopo)
        documentoId = try? c.decodeIfPresent(String.self, forKey: .documentoId)
        titoloDocumento = (try? c.decode(String.self, forKey: .titoloDocumento)) ?? ""
        tipoDocumento = (try? c.decode(String.self, forKey: .tipoDocumento)) ?? ""
        il = (try? c.decode(Date.self, forKey: .il)) ?? Date(timeIntervalSinceReferenceDate: 0)
        fontePrecedente = try? c.decodeIfPresent(String.self, forKey: .fontePrecedente)
        ripristinoDi = try? c.decodeIfPresent(String.self, forKey: .ripristinoDi)
    }
}

/// Con che cosa si confronta un documento.
enum BersaglioConfronto: Hashable {
    case posizione(String)
    case prodotto(String)
}
