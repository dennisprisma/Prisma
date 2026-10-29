import Foundation

/// Tipo di documento d'identità (identificazione antiriciclaggio).
enum TipoDocumentoIdentita: String, Codable, CaseIterable, Identifiable {
    case cartaIdentita, passaporto, patente, altro

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .cartaIdentita: return "Carta d'identità"
        case .passaporto: return "Passaporto"
        case .patente: return "Patente di guida"
        case .altro: return "Altro documento"
        }
    }
}

/// Profilo di rischio di riciclaggio assegnato al cliente: decide ogni quanto si rinnova l'adeguata verifica.
enum RischioRiciclaggio: String, Codable, CaseIterable, Identifiable {
    case basso, medio, alto

    var id: String { rawValue }

    /// «Basso», «Medio», «Alto».
    var nome: String { rawValue.capitalized }
}

/// Il questionario di adeguatezza (profilatura) di un canale.
struct QuestionarioAdeguatezza: Codable, Hashable {
    /// Data di compilazione e firma.
    var compilatoIl: Date?
    /// Validità di questo questionario in mesi; nil = quella del canale in Impostazioni.
    var validitaMesi: Int?
    /// Profilo che risulta dal questionario, come scritto sul modulo («Moderato»…). Testo libero.
    var esito: String?
}

/// Il documento d'identità usato per l'identificazione.
struct DocumentoIdentita: Codable, Hashable {
    var tipo: TipoDocumentoIdentita?
    var numero: String?
    var rilasciatoIl: Date?
    var scadenza: Date?

    init(tipo: TipoDocumentoIdentita? = nil, numero: String? = nil, rilasciatoIl: Date? = nil, scadenza: Date? = nil) {
        self.tipo = tipo
        self.numero = numero
        self.rilasciatoIl = rilasciatoIl
        self.scadenza = scadenza
    }

    private enum CodingKeys: String, CodingKey { case tipo, numero, rilasciatoIl, scadenza }

    /// Lettura tollerante (come `DatiLavoro`): un valore illeggibile, per esempio un tipo sconosciuto, diventa nil.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        tipo = try? c.decodeIfPresent(TipoDocumentoIdentita.self, forKey: .tipo)
        numero = try? c.decodeIfPresent(String.self, forKey: .numero)
        rilasciatoIl = try? c.decodeIfPresent(Date.self, forKey: .rilasciatoIl)
        scadenza = try? c.decodeIfPresent(Date.self, forKey: .scadenza)
    }
}

/// L'adeguata verifica antiriciclaggio fatta su un canale.
struct AdeguataVerifica: Codable, Hashable {
    var eseguitaIl: Date?
    var rischio: RischioRiciclaggio?

    init(eseguitaIl: Date? = nil, rischio: RischioRiciclaggio? = nil) {
        self.eseguitaIl = eseguitaIl
        self.rischio = rischio
    }

    private enum CodingKeys: String, CodingKey { case eseguitaIl, rischio }

    /// Lettura tollerante: un rischio di una versione futura («altissimo») diventa nil e la data resta.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        eseguitaIl = try? c.decodeIfPresent(Date.self, forKey: .eseguitaIl)
        rischio = try? c.decodeIfPresent(RischioRiciclaggio.self, forKey: .rischio)
    }
}

/// Le date di conformità del cliente (dalla versione 22 dell'archivio). Tutto facoltativo: nil = non registrato.
/// Niente dizionari con chiave `Canale` (JSONEncoder li scriverebbe come array alternati): un campo per canale.
struct ConformitaCliente: Codable, Hashable {
    var questionarioAlleanza: QuestionarioAdeguatezza?
    var questionarioIndipendente: QuestionarioAdeguatezza?
    var verificaAlleanza: AdeguataVerifica?
    var verificaIndipendente: AdeguataVerifica?
    var documento: DocumentoIdentita?
    /// Voci segnate dal consulente come «non richieste per questo cliente» (`VoceConformita.Tipo.rawValue`).
    /// I valori sconosciuti si ignorano.
    var nonRichieste: [String]?

    init() {}

    func questionario(_ c: Canale) -> QuestionarioAdeguatezza? {
        c == .alleanza ? questionarioAlleanza : questionarioIndipendente
    }

    mutating func impostaQuestionario(_ q: QuestionarioAdeguatezza?, canale c: Canale) {
        if c == .alleanza { questionarioAlleanza = q } else { questionarioIndipendente = q }
    }

    func verifica(_ c: Canale) -> AdeguataVerifica? {
        c == .alleanza ? verificaAlleanza : verificaIndipendente
    }

    mutating func impostaVerifica(_ v: AdeguataVerifica?, canale c: Canale) {
        if c == .alleanza { verificaAlleanza = v } else { verificaIndipendente = v }
    }

    /// Vero se il consulente ha segnato la voce come non richiesta.
    func nonRichiesta(_ tipo: String) -> Bool { nonRichieste?.contains(tipo) ?? false }
}

/// Validità e periodicità delle scadenze di conformità (Impostazioni → Esperienza → «Scadenze di conformità»).
/// Valori predefiniti: buona prassi di Prisma, non obblighi di legge (vedi `TestiConformita.fonte`).
struct RegoleConformita: Codable, Equatable {
    var mesiQuestionarioAlleanza = 36
    var mesiQuestionarioIndipendente = 36
    var mesiVerificaBasso = 36
    var mesiVerificaMedio = 24
    var mesiVerificaAlto = 12
    /// L'adeguata verifica si tiene anche sul canale indipendente.
    var verificaIndipendente = true
    /// Ogni quanti mesi si riconferma il consenso commerciale; 0 = non scade.
    var mesiCommerciale = 24
    /// Data dell'ultima versione dell'informativa privacy: chi l'ha firmata prima la riceve di nuovo.
    var informativaAggiornataIl: Date?

    init() {}

    func mesiQuestionario(_ c: Canale) -> Int {
        c == .alleanza ? mesiQuestionarioAlleanza : mesiQuestionarioIndipendente
    }

    func mesiVerifica(_ r: RischioRiciclaggio) -> Int {
        switch r {
        case .basso: return mesiVerificaBasso
        case .medio: return mesiVerificaMedio
        case .alto: return mesiVerificaAlto
        }
    }

    private enum CodingKeys: String, CodingKey {
        case mesiQuestionarioAlleanza, mesiQuestionarioIndipendente, mesiVerificaBasso, mesiVerificaMedio, mesiVerificaAlto
        case verificaIndipendente, mesiCommerciale, informativaAggiornataIl
    }

    /// Lettura tollerante: gli archivi di prima e i valori illeggibili tornano ai predefiniti.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = RegoleConformita()
        mesiQuestionarioAlleanza = (try? c.decodeIfPresent(Int.self, forKey: .mesiQuestionarioAlleanza)) ?? base.mesiQuestionarioAlleanza
        mesiQuestionarioIndipendente = (try? c.decodeIfPresent(Int.self, forKey: .mesiQuestionarioIndipendente)) ?? base.mesiQuestionarioIndipendente
        mesiVerificaBasso = (try? c.decodeIfPresent(Int.self, forKey: .mesiVerificaBasso)) ?? base.mesiVerificaBasso
        mesiVerificaMedio = (try? c.decodeIfPresent(Int.self, forKey: .mesiVerificaMedio)) ?? base.mesiVerificaMedio
        mesiVerificaAlto = (try? c.decodeIfPresent(Int.self, forKey: .mesiVerificaAlto)) ?? base.mesiVerificaAlto
        verificaIndipendente = (try? c.decodeIfPresent(Bool.self, forKey: .verificaIndipendente)) ?? base.verificaIndipendente
        mesiCommerciale = (try? c.decodeIfPresent(Int.self, forKey: .mesiCommerciale)) ?? base.mesiCommerciale
        informativaAggiornataIl = try? c.decodeIfPresent(Date.self, forKey: .informativaAggiornataIl)
    }
}
