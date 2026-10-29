import Foundation

/// Da dove arriva il versamento iniziale di una proposta (dalla versione 22 dell'archivio).
enum FonteCapitale: String, Codable, CaseIterable, Identifiable {
    case liquidita, sostituzione, nuoviRisparmi, altro

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .liquidita: return "Liquidità del cliente"
        case .sostituzione: return "Riscatto della posizione sostituita"
        case .nuoviRisparmi: return "Nuovi risparmi dal reddito"
        case .altro: return "Altre somme (eredità, TFR, vendita)"
        }
    }
}

/// A che cosa risponde la proposta: un bisogno rilevato, un'area della mappa o un obiettivo.
enum CollegamentoBisogno: Hashable {
    /// Id di un `BisognoRilevato` (es. "previdenza-assente").
    case rilevato(String)
    case area(AreaBisogno)
    /// Id di un `Obiettivo`.
    case obiettivo(String)
}

/// Un documento consegnato al cliente prima della firma.
struct ConsegnaDocumento: Codable, Hashable {
    /// `VoceDocumento.id`.
    var voceId: String
    var consegnatoIl: Date
}

/// Il colore e la frase di un controllo nel momento in cui la scheda è stata segnata come firmata.
struct EsitoRegistrato: Codable, Hashable {
    /// `ControlloAdeguatezza.Tipo.rawValue` (stringa: un tipo sconosciuto di una versione futura si legge lo stesso).
    var controllo: String
    /// `Semaforo.rawValue`.
    var semaforo: String
    var esito: String
}

/// La scheda di adeguatezza di una proposta: le scelte del consulente e le consegne. I controlli non si
/// salvano: si ricalcolano ogni volta dai dati (tranne i colori registrati alla firma).
/// Una sola scheda per posizione; resta anche quando la proposta diventa in essere.
struct SchedaAdeguatezza: Identifiable, Codable, Hashable {
    var posizioneId: String
    var clienteId: String
    /// Bisogno a cui risponde: al massimo uno dei tre (vedi `collegamento`).
    var bisognoRilevatoId: String?
    var areaBisogno: AreaBisogno?
    var obiettivoId: String?
    /// La posizione in essere che la proposta sostituisce (nil = nuovo investimento).
    var posizioneSostituitaId: String?
    /// Da dove arriva il versamento iniziale (nil = regola predefinita del motore).
    var fonte: FonteCapitale?
    /// Perché la proposta è adatta al cliente, con le parole del consulente: entra nel PDF.
    var motivazione = ""
    var consegne: [ConsegnaDocumento] = []
    /// Voci dell'elenco segnate «non serve per questa proposta».
    var nonPertinenti: [String] = []
    var creataIl: Date
    var aggiornataIl: Date?
    /// Segnata come firmata dal cliente (nil = da firmare). Mentre è firmata la scheda non si modifica.
    var firmataIl: Date?
    var esitiAllaFirma: [EsitoRegistrato]?

    var id: String { posizioneId }

    init(posizioneId: String, clienteId: String, creataIl: Date) {
        self.posizioneId = posizioneId
        self.clienteId = clienteId
        self.creataIl = creataIl
    }

    /// Il bisogno a cui risponde la proposta: scriverlo azzera gli altri due campi.
    var collegamento: CollegamentoBisogno? {
        get {
            if let o = obiettivoId { return .obiettivo(o) }
            if let r = bisognoRilevatoId { return .rilevato(r) }
            return areaBisogno.map { .area($0) }
        }
        set {
            obiettivoId = nil
            bisognoRilevatoId = nil
            areaBisogno = nil
            switch newValue {
            case .obiettivo(let o)?: obiettivoId = o
            case .rilevato(let r)?: bisognoRilevatoId = r
            case .area(let a)?: areaBisogno = a
            case nil: break
            }
        }
    }

    /// Quando è stato consegnato il documento (nil = non consegnato).
    func consegnato(_ voceId: String) -> Date? { consegne.first { $0.voceId == voceId }?.consegnatoIl }

    var firmata: Bool { firmataIl != nil }

    private enum CodingKeys: String, CodingKey {
        case posizioneId, clienteId, bisognoRilevatoId, areaBisogno, obiettivoId, posizioneSostituitaId, fonte
        case motivazione, consegne, nonPertinenti, creataIl, aggiornataIl, firmataIl, esitiAllaFirma
    }

    /// Lettura tollerante: obbligatori solo `posizioneId` e `clienteId` (senza, la scheda si scarta con
    /// `ElencoTollerante`); ogni altro campo illeggibile prende il valore predefinito
    /// (`areaBisogno` e `fonte` sconosciute → nil, `creataIl` mancante → 1° gennaio 2001).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        posizioneId = try c.decode(String.self, forKey: .posizioneId)
        clienteId = try c.decode(String.self, forKey: .clienteId)
        bisognoRilevatoId = try? c.decodeIfPresent(String.self, forKey: .bisognoRilevatoId)
        areaBisogno = try? c.decodeIfPresent(AreaBisogno.self, forKey: .areaBisogno)
        obiettivoId = try? c.decodeIfPresent(String.self, forKey: .obiettivoId)
        posizioneSostituitaId = try? c.decodeIfPresent(String.self, forKey: .posizioneSostituitaId)
        fonte = try? c.decodeIfPresent(FonteCapitale.self, forKey: .fonte)
        motivazione = (try? c.decodeIfPresent(String.self, forKey: .motivazione)) ?? ""
        // Le consegne una per una: una consegna illeggibile si scarta, le altre restano
        consegne = (try? c.decodeIfPresent(ElencoTollerante<ConsegnaDocumento>.self, forKey: .consegne))?.elementi ?? []
        nonPertinenti = (try? c.decodeIfPresent([String].self, forKey: .nonPertinenti)) ?? []
        creataIl = (try? c.decodeIfPresent(Date.self, forKey: .creataIl)) ?? Date(timeIntervalSinceReferenceDate: 0)
        aggiornataIl = try? c.decodeIfPresent(Date.self, forKey: .aggiornataIl)
        firmataIl = try? c.decodeIfPresent(Date.self, forKey: .firmataIl)
        esitiAllaFirma = try? c.decodeIfPresent([EsitoRegistrato].self, forKey: .esitiAllaFirma)
    }
}

/// Per quali proposte vale un documento dell'elenco.
enum AmbitoConsegna: String, Codable, CaseIterable, Identifiable {
    /// Prodotti d'investimento assicurativi (Ramo I, Ramo III, multiramo) e strumenti finanziari.
    case investimento
    /// Solo prodotti d'investimento assicurativi (IBIP: Ramo I, Ramo III, multiramo).
    case investimentoAssicurativo
    /// Solo strumenti finanziari (fondi, ETF, azioni, obbligazioni).
    case strumentiFinanziari
    case protezione
    case previdenza

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .investimento: return "Investimenti (polizze e strumenti finanziari)"
        case .investimentoAssicurativo: return "Polizze d'investimento (Ramo I, III, multiramo)"
        case .strumentiFinanziari: return "Fondi, ETF e titoli"
        case .protezione: return "Protezione"
        case .previdenza: return "Previdenza complementare"
        }
    }

    /// true se il documento vale per una proposta di quel tipo (nil = tipo non classificato: false).
    func comprende(_ t: TipoProdotto?) -> Bool {
        guard let t else { return false }
        switch self {
        case .investimento: return [.ramoI, .ramoIII, .multiramo, .fondiETF, .titoli].contains(t)
        case .investimentoAssicurativo: return [.ramoI, .ramoIII, .multiramo].contains(t)
        case .strumentiFinanziari: return [.fondiETF, .titoli].contains(t)
        case .protezione: return t == .protezione
        case .previdenza: return t == .previdenza
        }
    }
}

/// Un documento da consegnare prima della firma, per un canale (Impostazioni › Proposte).
struct VoceDocumento: Identifiable, Codable, Hashable {
    var id: String
    var canale: Canale
    var titolo: String
    /// Riferimento normativo o nota breve, sotto il titolo e nel PDF.
    var dettaglio = ""
    /// nil = tutte le proposte del canale.
    var perTipo: AmbitoConsegna?
    /// true = solo quando la proposta sostituisce un contratto in essere.
    var soloSostituzione = false
    var attiva = true

    init(id: String, canale: Canale, titolo: String, dettaglio: String = "", perTipo: AmbitoConsegna? = nil,
         soloSostituzione: Bool = false, attiva: Bool = true) {
        self.id = id
        self.canale = canale
        self.titolo = titolo
        self.dettaglio = dettaglio
        self.perTipo = perTipo
        self.soloSostituzione = soloSostituzione
        self.attiva = attiva
    }

    private enum CodingKeys: String, CodingKey {
        case id, canale, titolo, dettaglio, perTipo, soloSostituzione, attiva
    }

    /// Lettura: `id`, `canale`, `titolo` obbligatori; `perTipo` sconosciuto → errore (la voce si scarta,
    /// le altre restano); il resto con i predefiniti.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        canale = try c.decode(Canale.self, forKey: .canale)
        titolo = try c.decode(String.self, forKey: .titolo)
        dettaglio = (try? c.decodeIfPresent(String.self, forKey: .dettaglio)) ?? ""
        perTipo = try c.decodeIfPresent(AmbitoConsegna.self, forKey: .perTipo)
        soloSostituzione = (try? c.decodeIfPresent(Bool.self, forKey: .soloSostituzione)) ?? false
        attiva = (try? c.decodeIfPresent(Bool.self, forKey: .attiva)) ?? true
    }
}

/// L'elenco dei documenti da consegnare, nelle impostazioni (dalla versione 22 dell'archivio).
struct ImpostazioniConsegna: Codable, Equatable {
    var voci: [VoceDocumento] = ImpostazioniConsegna.predefinite

    init() {}

    private enum CodingKeys: String, CodingKey { case voci }

    /// Lettura tollerante: chiave assente → `predefinite`; elenco presente (anche vuoto) → quello, con le
    /// voci illeggibili scartate una per una (`ElencoTollerante`).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let elenco = try? c.decodeIfPresent(ElencoTollerante<VoceDocumento>.self, forKey: .voci)
        voci = elenco?.elementi ?? ImpostazioniConsegna.predefinite
    }

    /// Le voci di un canale, nell'ordine dell'elenco (anche quelle spente).
    func voci(_ c: Canale) -> [VoceDocumento] { voci.filter { $0.canale == c } }

    /// L'elenco di Prisma: 15 voci Alleanza e 8 indipendenti (riferimenti da verificare sul testo vigente).
    static let predefinite: [VoceDocumento] = [
        // Alleanza
        VoceDocumento(id: "all-allegato3", canale: .alleanza,
                      titolo: "Allegato 3 · Informativa sul distributore",
                      dettaglio: "Regolamento IVASS n. 40/2018"),
        VoceDocumento(id: "all-allegato4ter", canale: .alleanza,
                      titolo: "Allegato 4-ter · Regole di comportamento del distributore",
                      dettaglio: "Regolamento IVASS n. 40/2018"),
        VoceDocumento(id: "all-allegato4bis", canale: .alleanza,
                      titolo: "Allegato 4-bis · Informazioni sulla distribuzione del prodotto d'investimento assicurativo",
                      dettaglio: "Regolamento IVASS n. 40/2018", perTipo: .investimentoAssicurativo),
        VoceDocumento(id: "all-allegato4", canale: .alleanza,
                      titolo: "Allegato 4 · Informazioni sulla distribuzione del prodotto assicurativo non IBIP",
                      dettaglio: "Regolamento IVASS n. 40/2018", perTipo: .protezione),
        VoceDocumento(id: "all-kid", canale: .alleanza,
                      titolo: "KID · Documento contenente le informazioni chiave",
                      dettaglio: "Reg. UE 1286/2014 (PRIIPs)", perTipo: .investimentoAssicurativo),
        VoceDocumento(id: "all-dip-ibip", canale: .alleanza,
                      titolo: "DIP aggiuntivo IBIP",
                      dettaglio: "Regolamento IVASS n. 41/2018", perTipo: .investimentoAssicurativo),
        VoceDocumento(id: "all-dip-protezione", canale: .alleanza,
                      titolo: "DIP Vita o DIP Danni e DIP aggiuntivo",
                      dettaglio: "Regolamento IVASS n. 41/2018", perTipo: .protezione),
        VoceDocumento(id: "all-condizioni", canale: .alleanza,
                      titolo: "Condizioni di assicurazione o regolamento del piano",
                      dettaglio: "Set informativo della compagnia"),
        VoceDocumento(id: "all-adeguatezza", canale: .alleanza,
                      titolo: "Questionario di adeguatezza della compagnia, firmato",
                      dettaglio: "Codice delle assicurazioni private, art. 121-septies", perTipo: .investimentoAssicurativo),
        VoceDocumento(id: "all-esigenze", canale: .alleanza,
                      titolo: "Questionario sulle richieste ed esigenze",
                      dettaglio: "IDD (Dir. UE 2016/97), art. 20, par. 1; Codice delle assicurazioni private, art. 119-ter (per ogni contratto, anche IBIP e PIP)"),
        VoceDocumento(id: "all-pip-chiave", canale: .alleanza,
                      titolo: "Nota informativa · «Le informazioni chiave per l'aderente»",
                      dettaglio: "Schema di Nota informativa COVIP", perTipo: .previdenza),
        VoceDocumento(id: "all-pip-pensione", canale: .alleanza,
                      titolo: "Documento «La mia pensione complementare»",
                      dettaglio: "Schema di Nota informativa COVIP", perTipo: .previdenza),
        VoceDocumento(id: "all-pip-autovalutazione", canale: .alleanza,
                      titolo: "Questionario di autovalutazione",
                      dettaglio: "COVIP, modulo di adesione", perTipo: .previdenza),
        VoceDocumento(id: "all-antiriciclaggio", canale: .alleanza,
                      titolo: "Adeguata verifica antiriciclaggio",
                      dettaglio: "D.Lgs. 231/2007, artt. 17 e 18; Regolamento IVASS n. 44/2019 (rami vita: se la compagnia la chiede anche per TCM e PIP, si cambia «Per» in Impostazioni)",
                      perTipo: .investimentoAssicurativo),
        VoceDocumento(id: "all-confronto", canale: .alleanza,
                      titolo: "Confronto tra il contratto sostituito e il nuovo (costi, penali, garanzie)",
                      dettaglio: "Da conservare con la proposta", soloSostituzione: true),
        // Indipendente
        VoceDocumento(id: "ind-informativa", canale: .indipendente,
                      titolo: "Informativa sul servizio di consulenza: natura indipendente, compensi, conflitti d'interesse",
                      dettaglio: "MiFID II (Dir. 2014/65/UE), art. 24"),
        VoceDocumento(id: "ind-contratto", canale: .indipendente,
                      titolo: "Contratto di consulenza firmato"),
        VoceDocumento(id: "ind-profilo", canale: .indipendente,
                      titolo: "Questionario di profilatura aggiornato",
                      dettaglio: "Reg. delegato UE 2017/565, art. 54"),
        VoceDocumento(id: "ind-costi", canale: .indipendente,
                      titolo: "Illustrazione dei costi e degli oneri ex ante",
                      dettaglio: "MiFID II, art. 24, par. 4; Reg. delegato UE 2017/565, art. 50"),
        VoceDocumento(id: "ind-kid", canale: .indipendente,
                      titolo: "KID del prodotto",
                      dettaglio: "Reg. UE 1286/2014 (PRIIPs); azioni e obbligazioni semplici non hanno KID: segnalo «non pertinente»",
                      perTipo: .investimento),
        VoceDocumento(id: "ind-adeguatezza", canale: .indipendente,
                      titolo: "Dichiarazione di adeguatezza della raccomandazione",
                      dettaglio: "Reg. delegato UE 2017/565, art. 54, par. 12"),
        VoceDocumento(id: "ind-previdenza", canale: .indipendente,
                      titolo: "Nota informativa e «La mia pensione complementare» della forma proposta",
                      dettaglio: "Schema di Nota informativa COVIP", perTipo: .previdenza),
        VoceDocumento(id: "ind-confronto", canale: .indipendente,
                      titolo: "Analisi dei costi e dei benefici del cambio",
                      dettaglio: "Reg. delegato UE 2017/565, art. 54, par. 11", soloSostituzione: true)
    ]
}
