import Foundation

/// I tipi di occasione. L'ordine conta: è quello del modulo delle impostazioni e dell'elenco.
/// I nuovi tipi vanno in fondo. Il valore grezzo si salva in `ImpostazioniOccasioni.tipiSpenti`.
enum TipoOccasione: String, Codable, CaseIterable, Identifiable, Hashable {
    // Contratti
    case fineBloccoRiscatto, senzaPenali, periodoRaccomandato, ricorrenzaGestione
    // Previdenza
    case anticipazioniPrevidenza, aliquotaPrevidenza, pensioneVicina
    // Famiglia
    case maggiorenne, fineCarico
    // Protezione
    case capitaleSottoDebito, limiteEtaTCM, limiteEtaLTC
    // Fisco (da MotoreFineAnno)
    case scadenzaFiscale

    var id: String { rawValue }

    var gruppo: GruppoOccasione {
        switch self {
        case .fineBloccoRiscatto, .senzaPenali, .periodoRaccomandato, .ricorrenzaGestione: return .contratti
        case .anticipazioniPrevidenza, .aliquotaPrevidenza, .pensioneVicina: return .previdenza
        case .maggiorenne, .fineCarico: return .famiglia
        case .capitaleSottoDebito, .limiteEtaTCM, .limiteEtaLTC: return .protezione
        case .scadenzaFiscale: return .fisco
        }
    }
}

/// I gruppi di tipi: un interruttore ciascuno in Impostazioni e il filtro della vista «Occasioni».
enum GruppoOccasione: String, CaseIterable, Identifiable, Hashable {
    case contratti, previdenza, famiglia, protezione, fisco

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .contratti: return "Contratti"
        case .previdenza: return "Previdenza"
        case .famiglia: return "Famiglia"
        case .protezione: return "Protezione"
        case .fisco: return "Fisco"
        }
    }

    var tipi: [TipoOccasione] { TipoOccasione.allCases.filter { $0.gruppo == self } }
}

/// Quanto conta un'occasione. Decide la priorità nel riesame e se l'occasione arriva nelle notifiche.
enum ImportanzaOccasione: Int, Comparable, Hashable {
    case alta, media, bassa

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Una data in cui cambia qualcosa per un cliente. Si calcola da `MotoreOccasioni` e non si salva.
struct Occasione: Identifiable, Hashable {
    let tipo: TipoOccasione
    /// Il giorno dell'occasione. L'ora è quella della data di partenza (decorrenza, nascita, 12:00 per il fisco).
    /// Agenda e prove ragionano sul giorno (`startOfDay`).
    let data: Date
    let clienteId: String
    /// La posizione da cui nasce (contratti, previdenza, caso morte, fisco dei piani). Nil per famiglia e persona.
    let posizioneId: String?
    /// Il familiare di cui si parla (maggiorenne, fine carico, limiti d'età e pensione del partner).
    let familiareId: String?
    /// Il canale della posizione. Per famiglia, persona e fisco misto è il canale comune del cliente, o nil:
    /// allora il colore è neutro e l'etichetta del canale non compare.
    let canale: Canale?
    /// Senza cifre in euro: va anche nei promemoria del Mac.
    let titolo: String
    /// Cosa cambia e cosa fare, con le cifre.
    let dettaglio: String
    /// Riferimento normativo o contrattuale (TestiOccasioni).
    let fonte: String
    /// La cifra chiave: mesi di blocco, anno senza penali, anni del KID, aliquota, età, debito residuo, IRPEF.
    let valore: Double?
    let importanza: ImportanzaOccasione
    /// Solo per `.scadenzaFiscale`: quale scadenza di Fine anno.
    var fiscale: ScadenzaFiscale.Tipo? = nil

    /// Stabile tra un calcolo e l'altro: "\(tipo)-\(soggetto)-aaaammgg". Il soggetto è la posizione, il
    /// familiare o il cliente; per il fisco è "\(fiscale)-\(clienteId)".
    let id: String
}

/// Le scelte del consulente sulle occasioni (Impostazioni › Occasioni). Dalla versione 22 dell'archivio.
/// Lettura tollerante: valori fuori elenco tornano al predefinito, i tipi sconosciuti si ignorano.
struct ImpostazioniOccasioni: Codable, Equatable, Hashable {
    /// Lo strato «Occasioni» nella settimana e nel mese dell'Agenda (la vista «Occasioni» c'è sempre).
    var inAgenda = true
    /// Quanti giorni prima arrivano notifica e promemoria.
    var anticipoGiorni = 30
    /// I tipi che il consulente non vuole vedere: spariscono da Agenda, notifiche, promemoria e riesame.
    var tipiSpenti: [TipoOccasione] = []
    /// L'età da cui una temporanea caso morte o una copertura LTC non si sottoscrivono più.
    var etaLimiteTCM = RegoleOccasioni.etaLimitePredefinita
    var etaLimiteLTC = RegoleOccasioni.etaLimitePredefinita

    /// Gli anticipi che si possono scegliere (giorni).
    static let anticipi = [7, 15, 30, 60, 90]
    /// Le età limite che si possono scegliere.
    static let etaLimiti = [60, 65, 70, 75, 80]

    init() {}

    func attivo(_ t: TipoOccasione) -> Bool { !tipiSpenti.contains(t) }

    /// Acceso se almeno un tipo del gruppo è acceso.
    func attivo(_ g: GruppoOccasione) -> Bool { g.tipi.contains { attivo($0) } }

    /// Accende o spegne tutti i tipi del gruppo, nell'ordine di `TipoOccasione.allCases`.
    mutating func imposta(_ g: GruppoOccasione, attivo: Bool) {
        var spenti = Set(tipiSpenti)
        if attivo { spenti.subtract(g.tipi) } else { spenti.formUnion(g.tipi) }
        tipiSpenti = TipoOccasione.allCases.filter { spenti.contains($0) }
    }

    private enum CodingKeys: String, CodingKey { case inAgenda, anticipoGiorni, tipiSpenti, etaLimiteTCM, etaLimiteLTC }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        inAgenda = (try? c.decodeIfPresent(Bool.self, forKey: .inAgenda)) ?? true
        let anticipo = (try? c.decodeIfPresent(Int.self, forKey: .anticipoGiorni)) ?? 30
        anticipoGiorni = Self.anticipi.contains(anticipo) ? anticipo : 30
        // Testi grezzi: un tipo che questa versione non conosce si ignora, non fa scartare le impostazioni
        let grezzi = (try? c.decodeIfPresent([String].self, forKey: .tipiSpenti)) ?? []
        tipiSpenti = grezzi.compactMap(TipoOccasione.init(rawValue:))
        let tcm = (try? c.decodeIfPresent(Int.self, forKey: .etaLimiteTCM)) ?? RegoleOccasioni.etaLimitePredefinita
        etaLimiteTCM = Self.etaLimiti.contains(tcm) ? tcm : RegoleOccasioni.etaLimitePredefinita
        let ltc = (try? c.decodeIfPresent(Int.self, forKey: .etaLimiteLTC)) ?? RegoleOccasioni.etaLimitePredefinita
        etaLimiteLTC = Self.etaLimiti.contains(ltc) ? ltc : RegoleOccasioni.etaLimitePredefinita
    }
}
