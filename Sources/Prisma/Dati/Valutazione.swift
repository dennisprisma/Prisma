import Foundation

// Condizioni di un contratto d'investimento (tipicamente una polizza multiramo) e valutazioni
// di riscatto per un cliente. I dati delle condizioni vengono dal KID, dal DIP aggiuntivo IBIP,
// dalle Condizioni di assicurazione e dai rendiconti: Prisma li calcola, non li inventa.

/// Una parte del contratto: Gestione separata o Fondo Interno.
struct ComponenteContratto: Identifiable, Codable, Hashable {
    enum Tipo: String, Codable, CaseIterable, Identifiable {
        case gestioneSeparata, fondoInterno

        var id: String { rawValue }

        var nome: String {
            switch self {
            case .gestioneSeparata: return "Gestione separata"
            case .fondoInterno: return "Fondo Interno"
            }
        }
    }

    var id = "comp-\(UUID().uuidString.prefix(6).lowercased())"
    var tipo: Tipo
    /// Nome commerciale ("Fondo Euro San Giorgio").
    var nome: String
    /// Quota del capitale investito (30 = 30%).
    var quota: Double
    /// Gestione separata: quanto la Compagnia trattiene dal rendimento lordo (% annuo).
    var trattenuto: Double = 0
    /// Fondo Interno: commissione di gestione, già nel valore delle quote (% annuo).
    var commissione: Double = 0
    /// Fondo Interno: costi dei fondi sottostanti, stima (% annuo), già nel valore delle quote.
    var costiSottostanti: Double = 0
    /// Il bollo annuo si applica al valore di questa parte (le quote del Fondo Interno).
    var bollo = false
    /// Quota investita in titoli di Stato (% della parte), tassata al 12,5%.
    var titoliStato: Double = 0
    /// Una frase per il cliente: che cosa fa questa parte.
    var descrizione = ""
    /// Caratteristiche per il prospetto (volatilità, composizione…).
    var caratteristiche = ""
    /// Storico: rendimenti lordi annui (Gestione separata) o valori della quota (Fondo Interno).
    var storico: [PuntoStorico] = []
    var notaStorico = ""
    /// Gestione separata: rendimento minimo garantito annuo (%); nil = non indicato (nessun pavimento, come prima).
    var minimoGarantito: Double?
    /// Gestione separata: true se il rendimento si consolida ogni anno, false se la garanzia vale solo
    /// a scadenza o in caso di decesso; nil = non indicato.
    var consolidamento: Bool?
    /// Gestione separata: quota del rendimento lordo retrocessa (0–100), alternativa al trattenuto fisso.
    var retrocessione: Double?
    // Dalla versione 20 dell'archivio (multiramo a due parti)
    /// Rendimento lordo annuo ipotizzato (%): della gestione (prima del trattenuto) o del fondo (prima dei costi).
    var rendimentoAtteso: Double?
    /// Fondo Interno: SRI, volatilità annua (%) e quota azionaria (0–100) della parte.
    var sri: Int?
    var volatilita: Double?
    var quotaAzionaria: Double?

    init(tipo: Tipo, nome: String, quota: Double) {
        self.tipo = tipo
        self.nome = nome
        self.quota = quota
    }

    /// Nome completo con le virgolette («Fondo Euro San Giorgio»).
    var nomeCompleto: String { "\(tipo.nome) «\(nome)»" }
}

/// Un dato storico: un anno o una data, con un valore (rendimento % o valore della quota).
struct PuntoStorico: Codable, Hashable {
    var etichetta: String
    /// nil se il dato non è disponibile.
    var valore: Double?
    var nota = ""
}

/// Uno scenario del KID: rendimento medio annuo, al lordo delle imposte.
struct ScenarioKID: Codable, Hashable {
    var nome: String
    /// Uscita dopo 1 anno (% medio annuo).
    var unAnno: Double?
    /// Uscita al periodo indicato in `CondizioniContratto.anniKID` (% medio annuo).
    var periodo: Double?
}

/// Le condizioni di un contratto, dalla documentazione ufficiale.
struct CondizioniContratto: Codable, Hashable {
    /// "Base, senza copertura complementare infortuni".
    var versione = ""
    var componenti: [ComponenteContratto] = []
    /// Costo d'ingresso sul premio (%), con un eventuale massimo in euro.
    var costoIngresso: Double = 0
    var costoIngressoMassimo: Double?
    /// Mesi dalla decorrenza in cui il riscatto non è consentito.
    var mesiBloccoRiscatto = 12
    /// Penali di riscatto sul valore del contratto, per annualità: [2° anno, 3° anno, …] in %.
    var penali: [Double] = []
    /// Imposta di bollo annua sul valore delle quote (%).
    var bollo: Double = 0.20
    var aliquota: Double = 26
    var aliquotaTitoliStato: Double = 12.5
    /// Periodo di detenzione raccomandato dal KID, in anni.
    var periodoRaccomandato: Int?
    /// Scenari del KID e data del KID.
    var scenariKID: [ScenarioKID] = []
    var anniKID = 5
    var esempioKID = ""
    var dataDocumenti: Date?
    var garantito: [String] = []
    var nonGarantito: [String] = []
    var riscattoParziale = ""
    var recesso = ""
    var fonti = ""

    /// Costo d'ingresso in euro su un premio.
    func ingresso(_ premio: Double) -> Double {
        let c = premio * costoIngresso / 100
        return costoIngressoMassimo.map { min(c, $0) } ?? c
    }

    /// Penale (%) per un riscatto chiesto all'inizio dell'anno `anno` (2 = dal 13° mese).
    func penale(anno: Int) -> Double {
        let i = anno - 2
        return i >= 0 && i < penali.count ? penali[i] : 0
    }

    /// Anno (dalla decorrenza) da cui non ci sono più penali.
    var annoSenzaPenali: Int { penali.count + 2 }

    /// Aliquota d'imposta di una parte, secondo la quota in titoli di Stato.
    func aliquotaParte(_ c: ComponenteContratto) -> Double {
        aliquota - c.titoliStato / 100 * (aliquota - aliquotaTitoliStato)
    }

    /// Composizione in parole: "30% Gestione separata «Fondo Euro San Giorgio» – 70% Fondo Interno «Allocazione Dinamica»".
    var composizione: String {
        componenti.map { "\(Formati.percentuale($0.quota)) \($0.nomeCompleto)" }.joined(separator: " – ")
    }

    var composizioneBreve: String {
        componenti.map { "\(Formati.percentuale($0.quota)) \($0.tipo.nome)" }.joined(separator: " – ")
    }
}

/// Favorevole, intermedio, sfavorevole: i tre andamenti di una valutazione.
enum TipoScenario: String, Codable, CaseIterable, Identifiable {
    case favorevole, intermedio, sfavorevole

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .favorevole: return "Favorevole"
        case .intermedio: return "Intermedio"
        case .sfavorevole: return "Sfavorevole"
        }
    }
}

/// Le ipotesi di uno scenario: il rendimento di ogni parte e il perché.
struct ScenarioValutazione: Codable, Hashable, Identifiable {
    var tipo: TipoScenario
    /// Rendimento per parte (id della parte → %): lordo per la Gestione separata,
    /// netto dei costi del fondo per il Fondo Interno.
    var rendimenti: [String: Double] = [:]
    /// Perché questa ipotesi (scritto dal consulente).
    var perche = ""
    /// Come va il fondo in questo scenario, in una frase per il cliente.
    var racconto = ""

    var id: TipoScenario { tipo }

    func rendimento(_ c: ComponenteContratto) -> Double { rendimenti[c.id] ?? 0 }
}

/// Una valutazione d'investimento per un cliente: un premio su un prodotto, tre scenari,
/// i testi del consulente. Da qui nascono il prospetto (A4 verticale) e il report (A4 orizzontale).
struct ValutazioneInvestimento: Identifiable, Codable, Hashable {
    var id = "val-\(UUID().uuidString.prefix(8).lowercased())"
    var clienteId: String
    /// Chi firma il contratto, come va scritto sul report ("Marco ed Elena Bianchi").
    var intestatari: String
    var prodottoId: String
    /// Proposta collegata in Posizioni, se c'è.
    var posizioneId: String?
    var premio: Double
    var data = Date()
    /// Anni di riscatto simulati dopo il primo (5 = riscatto all'inizio del 2°…6° anno).
    var anni = 5
    var scenari: [ScenarioValutazione] = TipoScenario.allCases.map { ScenarioValutazione(tipo: $0) }
    /// Perché il cliente investe e quando potrebbe servirgli il denaro ("potreste averne bisogno già tra uno o due anni").
    var esigenza = ""
    /// Perché lo scenario centrale usa quel rendimento.
    var notaScenarioCentrale = ""
    /// Il consiglio del consulente sul riscatto.
    var consiglio = ""
    var creataIl = Date()

    init(clienteId: String, intestatari: String, prodottoId: String, premio: Double) {
        self.clienteId = clienteId
        self.intestatari = intestatari
        self.prodottoId = prodottoId
        self.premio = premio
    }

    func scenario(_ t: TipoScenario) -> ScenarioValutazione {
        scenari.first { $0.tipo == t } ?? ScenarioValutazione(tipo: t)
    }

    /// Più intestatari: il report dà del voi.
    var plurale: Bool { intestatari.contains(" e ") || intestatari.contains(" ed ") }

    /// Ipotesi di partenza da rivedere: Gestione separata attorno alla media storica, Fondo Interno
    /// attorno allo scenario moderato del KID. Il consulente le corregge e scrive il perché.
    /// Se la parte indica il rendimento lordo ipotizzato si parte da quello: per la Gestione separata così
    /// com'è, per il Fondo Interno al netto di commissione e costi dei fondi sottostanti (al decimo).
    static func ipotesiDiPartenza(_ c: CondizioniContratto) -> [ScenarioValutazione] {
        let moderato = c.scenariKID.first { $0.nome.lowercased().hasPrefix("moder") }?.periodo ?? 4
        return TipoScenario.allCases.map { t in
            var s = ScenarioValutazione(tipo: t)
            for p in c.componenti {
                switch p.tipo {
                case .gestioneSeparata:
                    let valori = p.storico.compactMap(\.valore)
                    let media = valori.isEmpty ? 3 : valori.reduce(0, +) / Double(valori.count)
                    let base = p.rendimentoAtteso ?? (media * 10).rounded() / 10
                    s.rendimenti[p.id] = t == .favorevole ? base + 0.4 : t == .intermedio ? base + 0.1 : base - 0.4
                case .fondoInterno:
                    let base: Double
                    if let r = p.rendimentoAtteso {
                        let netto = ((1 + r / 100) * (1 - (p.commissione + p.costiSottostanti) / 100) - 1) * 100
                        base = (netto * 10).rounded() / 10
                    } else {
                        base = moderato.rounded()
                    }
                    s.rendimenti[p.id] = t == .favorevole ? base * 2 : t == .intermedio ? base : -3
                }
            }
            return s
        }
    }
}

// MARK: - Letture tolleranti: i campi mancanti prendono il valore predefinito

extension ComponenteContratto {
    private enum CodingKeys: String, CodingKey {
        case id, tipo, nome, quota, trattenuto, commissione, costiSottostanti, bollo, titoliStato
        case descrizione, caratteristiche, storico, notaStorico
        case minimoGarantito, consolidamento, retrocessione
        case rendimentoAtteso, sri, volatilita, quotaAzionaria
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(tipo: try c.decodeIfPresent(Tipo.self, forKey: .tipo) ?? .fondoInterno,
                  nome: try c.decodeIfPresent(String.self, forKey: .nome) ?? "",
                  quota: try c.decodeIfPresent(Double.self, forKey: .quota) ?? 0)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? id
        trattenuto = try c.decodeIfPresent(Double.self, forKey: .trattenuto) ?? 0
        commissione = try c.decodeIfPresent(Double.self, forKey: .commissione) ?? 0
        costiSottostanti = try c.decodeIfPresent(Double.self, forKey: .costiSottostanti) ?? 0
        bollo = try c.decodeIfPresent(Bool.self, forKey: .bollo) ?? false
        titoliStato = try c.decodeIfPresent(Double.self, forKey: .titoliStato) ?? 0
        descrizione = try c.decodeIfPresent(String.self, forKey: .descrizione) ?? ""
        caratteristiche = try c.decodeIfPresent(String.self, forKey: .caratteristiche) ?? ""
        storico = (try? c.decodeIfPresent([PuntoStorico].self, forKey: .storico)) ?? []
        notaStorico = try c.decodeIfPresent(String.self, forKey: .notaStorico) ?? ""
        minimoGarantito = try? c.decodeIfPresent(Double.self, forKey: .minimoGarantito)
        consolidamento = try? c.decodeIfPresent(Bool.self, forKey: .consolidamento)
        retrocessione = try? c.decodeIfPresent(Double.self, forKey: .retrocessione)
        rendimentoAtteso = try? c.decodeIfPresent(Double.self, forKey: .rendimentoAtteso)
        sri = try? c.decodeIfPresent(Int.self, forKey: .sri)
        volatilita = try? c.decodeIfPresent(Double.self, forKey: .volatilita)
        quotaAzionaria = try? c.decodeIfPresent(Double.self, forKey: .quotaAzionaria)
    }
}

extension CondizioniContratto {
    private enum CodingKeys: String, CodingKey {
        case versione, componenti, costoIngresso, costoIngressoMassimo, mesiBloccoRiscatto, penali, bollo, aliquota
        case aliquotaTitoliStato, periodoRaccomandato, scenariKID, anniKID, esempioKID, dataDocumenti
        case garantito, nonGarantito, riscattoParziale, recesso, fonti
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        versione = try c.decodeIfPresent(String.self, forKey: .versione) ?? ""
        componenti = (try? c.decodeIfPresent([ComponenteContratto].self, forKey: .componenti)) ?? []
        costoIngresso = try c.decodeIfPresent(Double.self, forKey: .costoIngresso) ?? 0
        costoIngressoMassimo = try c.decodeIfPresent(Double.self, forKey: .costoIngressoMassimo)
        mesiBloccoRiscatto = try c.decodeIfPresent(Int.self, forKey: .mesiBloccoRiscatto) ?? 12
        penali = try c.decodeIfPresent([Double].self, forKey: .penali) ?? []
        bollo = try c.decodeIfPresent(Double.self, forKey: .bollo) ?? 0.20
        aliquota = try c.decodeIfPresent(Double.self, forKey: .aliquota) ?? 26
        aliquotaTitoliStato = try c.decodeIfPresent(Double.self, forKey: .aliquotaTitoliStato) ?? 12.5
        periodoRaccomandato = try c.decodeIfPresent(Int.self, forKey: .periodoRaccomandato)
        scenariKID = (try? c.decodeIfPresent([ScenarioKID].self, forKey: .scenariKID)) ?? []
        anniKID = try c.decodeIfPresent(Int.self, forKey: .anniKID) ?? 5
        esempioKID = try c.decodeIfPresent(String.self, forKey: .esempioKID) ?? ""
        dataDocumenti = try c.decodeIfPresent(Date.self, forKey: .dataDocumenti)
        garantito = try c.decodeIfPresent([String].self, forKey: .garantito) ?? []
        nonGarantito = try c.decodeIfPresent([String].self, forKey: .nonGarantito) ?? []
        riscattoParziale = try c.decodeIfPresent(String.self, forKey: .riscattoParziale) ?? ""
        recesso = try c.decodeIfPresent(String.self, forKey: .recesso) ?? ""
        fonti = try c.decodeIfPresent(String.self, forKey: .fonti) ?? ""
    }
}

extension ScenarioValutazione {
    private enum CodingKeys: String, CodingKey { case tipo, rendimenti, perche, racconto }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(tipo: try c.decodeIfPresent(TipoScenario.self, forKey: .tipo) ?? .intermedio)
        rendimenti = try c.decodeIfPresent([String: Double].self, forKey: .rendimenti) ?? [:]
        perche = try c.decodeIfPresent(String.self, forKey: .perche) ?? ""
        racconto = try c.decodeIfPresent(String.self, forKey: .racconto) ?? ""
    }
}

extension ValutazioneInvestimento {
    private enum CodingKeys: String, CodingKey {
        case id, clienteId, intestatari, prodottoId, posizioneId, premio, data, anni, scenari
        case esigenza, notaScenarioCentrale, consiglio, creataIl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(clienteId: try c.decode(String.self, forKey: .clienteId),
                  intestatari: try c.decodeIfPresent(String.self, forKey: .intestatari) ?? "",
                  prodottoId: try c.decodeIfPresent(String.self, forKey: .prodottoId) ?? "",
                  premio: try c.decodeIfPresent(Double.self, forKey: .premio) ?? 0)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? id
        posizioneId = try c.decodeIfPresent(String.self, forKey: .posizioneId)
        data = try c.decodeIfPresent(Date.self, forKey: .data) ?? Date()
        anni = try c.decodeIfPresent(Int.self, forKey: .anni) ?? 5
        if let s = try? c.decodeIfPresent([ScenarioValutazione].self, forKey: .scenari), !s.isEmpty { scenari = s }
        esigenza = try c.decodeIfPresent(String.self, forKey: .esigenza) ?? ""
        notaScenarioCentrale = try c.decodeIfPresent(String.self, forKey: .notaScenarioCentrale) ?? ""
        consiglio = try c.decodeIfPresent(String.self, forKey: .consiglio) ?? ""
        creataIl = try c.decodeIfPresent(Date.self, forKey: .creataIl) ?? Date()
    }
}

extension PuntoStorico {
    private enum CodingKeys: String, CodingKey { case etichetta, valore, nota }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(etichetta: try c.decodeIfPresent(String.self, forKey: .etichetta) ?? "",
                  valore: try c.decodeIfPresent(Double.self, forKey: .valore),
                  nota: try c.decodeIfPresent(String.self, forKey: .nota) ?? "")
    }
}
