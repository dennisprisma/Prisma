import Foundation

/// Una crisi vera del passato: di quanto sono cambiate, in euro, le principali classi di attivo.
/// Le variazioni sono indicative (arrotondate, da indici pubblici) e servono a dire al cliente
/// «se tornasse un anno così, il tuo patrimonio di oggi farebbe circa questo»: non sono previsioni.
struct CrisiStorica: Identifiable {
    enum Classe: String, CaseIterable, Identifiable {
        case azioni, governativi, societarie, liquidita, gestioneSeparata, immobili
        var id: String { rawValue }

        var nome: String {
            switch self {
            case .azioni: return "Azioni"
            case .governativi: return "Titoli di Stato"
            case .societarie: return "Obbligazioni societarie"
            case .liquidita: return "Liquidità"
            case .gestioneSeparata: return "Gestione separata"
            case .immobili: return "Immobili"
            }
        }
    }

    let anno: Int
    let titolo: String
    /// Il periodo misurato (anno solare o dal massimo al minimo).
    let periodo: String
    /// Variazione per classe di attivo, in % (negativa = calo). Le classi mancanti non cambiano.
    let variazioni: [Classe: Double]
    /// Inflazione italiana dell'anno (Istat, indice NIC), per il racconto.
    let inflazione: Double
    /// Quanto ci è voluto per recuperare, in parole (indicativo).
    let recupero: String
    var id: Int { anno }

    func variazione(_ c: Classe) -> Double { variazioni[c] ?? 0 }
}

/// Come è fatta una posizione, in quote del suo valore (0–1, la somma fa 1).
struct ComposizionePosizione: Equatable {
    var azioni = 0.0
    var governativi = 0.0
    var societarie = 0.0
    var liquidita = 0.0
    var gestioneSeparata = 0.0
    var immobili = 0.0
    /// true se la quota azionaria è stimata (dalla tipologia o dall'SRI) e non indicata nella posizione.
    var stimata = false

    func quota(_ c: CrisiStorica.Classe) -> Double {
        switch c {
        case .azioni: return azioni
        case .governativi: return governativi
        case .societarie: return societarie
        case .liquidita: return liquidita
        case .gestioneSeparata: return gestioneSeparata
        case .immobili: return immobili
        }
    }

    /// Variazione della posizione in una crisi, in % del suo valore (negativa = calo).
    func variazione(_ k: CrisiStorica) -> Double {
        CrisiStorica.Classe.allCases.reduce(0) { $0 + quota($1) * k.variazione($1) }
    }
}

/// Cosa farebbe una crisi del passato alle posizioni di oggi del cliente.
struct EsitoCrisi: Identifiable {
    struct Voce: Identifiable {
        let posizione: Posizione
        let composizione: ComposizionePosizione
        /// Euro persi (negativo = guadagno, per esempio i titoli di Stato nel 2008).
        let perdita: Double
        var id: String { posizione.id }
        var quota: Double { posizione.valore > 0 ? perdita / posizione.valore : 0 }
    }

    let crisi: CrisiStorica
    /// Le posizioni finanziarie che cambiano valore, dalla più colpita alla meno colpita.
    let voci: [Voce]
    /// Il patrimonio finanziario (investimento, risparmio, previdenza e liquidità in essere).
    let base: Double
    /// Calo degli immobili, a parte: pesa sul patrimonio netto, non su quello finanziario.
    let perditaImmobili: Double
    /// Il confronto con la perdita che il profilo sopporta (nil senza propensione).
    let giudizio: ProvaResistenza.Giudizio?
    var id: Int { crisi.anno }
    /// Euro persi sul patrimonio finanziario (negativo = guadagno).
    var perdita: Double { voci.reduce(0) { $0 + $1.perdita } }
    var quota: Double { base > 0 ? perdita / base : 0 }
}

extension MotoreResistenza {
    /// Le tre crisi vere applicate al patrimonio di oggi. Valori indicativi in euro, arrotondati,
    /// scelti dove possibile dal lato prudente (per un investitore italiano):
    /// - 2008, crisi finanziaria (anno solare): azioni mondiali in euro (MSCI World EUR, netto) circa −37%;
    ///   titoli di Stato +4% (l'indice dell'area euro fece circa +9%, i BTP meno per l'allargamento dello
    ///   spread: si usa il dato più basso); obbligazioni societarie investment grade in euro circa −4%;
    ///   immobili −5% indicativo (in Italia le case non crollarono nel 2008 ma persero circa il 15–20%
    ///   tra il 2008 e il 2015, fonti Banca d'Italia e Istat). Inflazione 2008: 3,3%. Le azioni mondiali in
    ///   euro tornarono ai valori di inizio 2008 in circa 4 anni.
    /// - 2020, pandemia (dal massimo del 19 febbraio al minimo del 23 marzo): azioni mondiali in euro
    ///   circa −33%; titoli di Stato −4% (BTP con lo spread vicino ai 300 punti; l'area euro circa −3%);
    ///   obbligazioni societarie in euro circa −7%; immobili invariati. Inflazione 2020: −0,2%.
    ///   Recupero in meno di un anno.
    /// - 2022, inflazione e tassi (anno solare): azioni mondiali in euro −12,8% (MSCI World EUR, netto),
    ///   arrotondato a −13%; titoli di Stato in euro circa −17/−18% (−17%); obbligazioni societarie in euro
    ///   circa −14%; immobili invariati in valore nominale. Inflazione 2022: 8,1%.
    /// Liquidità e gestioni separate (Ramo I, valore di carico con capitale garantito) restano a zero
    /// anche dove hanno guadagnato qualcosa: prudenza.
    static let crisiDelPassato: [CrisiStorica] = [
        CrisiStorica(anno: 2008, titolo: "Crisi finanziaria", periodo: "anno 2008",
                     variazioni: [.azioni: -37, .governativi: 4, .societarie: -4, .immobili: -5],
                     inflazione: 3.3,
                     recupero: "Le azioni mondiali in euro sono tornate ai valori di inizio 2008 in circa 4 anni."),
        CrisiStorica(anno: 2020, titolo: "Pandemia", periodo: "dal 19 febbraio al 23 marzo 2020",
                     variazioni: [.azioni: -33, .governativi: -4, .societarie: -7],
                     inflazione: -0.2,
                     recupero: "Le azioni mondiali hanno recuperato il calo in meno di un anno."),
        CrisiStorica(anno: 2022, titolo: "Inflazione e tassi", periodo: "anno 2022",
                     variazioni: [.azioni: -13, .governativi: -17, .societarie: -14],
                     inflazione: 8.1,
                     recupero: "Le azioni hanno recuperato in circa un anno; le obbligazioni molto più lentamente."),
    ]

    /// Multiramo senza la quota in gestione separata indicata: metà e metà (come dice il metodo).
    static let quotaGestioneSeparataPredefinita = 50.0
    /// Parte obbligazionaria senza la quota in titoli di Stato indicata: metà governativi, metà societarie.
    static let quotaGovernativiPredefinita = 0.5
    /// Quota azionaria della parte esposta ai mercati quando non è indicata né si capisce dalla tipologia,
    /// secondo l'SRI: stime indicative (un ETF azionario mondiale ha di solito SRI 4).
    static let azioniPerSRI: [Int: Double] = [1: 0, 2: 0.1, 3: 0.35, 4: 0.7, 5: 1, 6: 1, 7: 1]

    /// Quota azionaria stimata della parte esposta ai mercati (0–1), dalla tipologia o dall'SRI.
    static func quotaAzionariaStimata(_ p: Posizione) -> Double {
        let t = p.tipologia.lowercased()
        if t.contains("bilanciat") { return 0.5 }
        if t.contains("azionari") { return 1 }
        if t.contains("obbligazionari") || t.contains("monetari") { return 0 }
        if t.contains("flessibil") { return 0.4 }
        let sri = min(max(p.sri ?? sriProbabile(p.area), 1), 7)
        return azioniPerSRI[sri] ?? 0.7
    }

    /// La composizione per classe di attivo di una posizione (nil per protezione e debiti).
    /// Gestione separata e conti non scendono; la parte esposta ai mercati si divide in azioni
    /// (`quotaAzionaria` della posizione, altrimenti stimata) e obbligazioni (titoli di Stato secondo
    /// `quotaTitoliStato`, altrimenti metà e metà); i fondi monetari valgono come liquidità.
    static func composizione(_ p: Posizione) -> ComposizionePosizione? {
        var c = ComposizionePosizione()
        switch p.area {
        case .protezione, .debiti:
            return nil
        case .immobili:
            c.immobili = 1
            return c
        case .liquidita:
            c.liquidita = 1
            return c
        case .investimento, .risparmio, .previdenza:
            break
        }
        let esposta = quotaARischio(p)
        c.gestioneSeparata = 1 - esposta
        guard esposta > 0 else { return c }
        let azioni: Double
        if let q = p.quotaAzionaria {
            // La quota azionaria è sul valore di tutta la posizione: non può superare la parte esposta
            azioni = min(max(q, 0) / 100, esposta)
        } else {
            azioni = quotaAzionariaStimata(p) * esposta
            c.stimata = true
        }
        c.azioni = azioni
        let obbligazioni = max(0, esposta - azioni)
        if p.tipologia.lowercased().contains("monetari") {
            c.liquidita = obbligazioni
            return c
        }
        let governativi = p.quotaTitoliStato.map { min(max($0, 0) / 100, obbligazioni) } ?? obbligazioni * quotaGovernativiPredefinita
        c.governativi = governativi
        c.societarie = obbligazioni - governativi
        return c
    }

    /// Il giudizio sul profilo per una perdita (frazione del patrimonio finanziario), con le stesse
    /// soglie della prova sui mercati.
    static func giudica(quota: Double, sopportabile: Double?) -> ProvaResistenza.Giudizio? {
        guard let s = sopportabile else { return nil }
        let perdita = quota * 100
        if perdita <= s { return .dentro }
        return perdita <= s * margineLimite ? .alLimite : .oltre
    }

    /// Le crisi del passato applicate alle posizioni in essere di oggi.
    static func crisi(_ posizioni: [Posizione], profilo: ProfiloInvestitore?) -> [EsitoCrisi] {
        let inEssere = posizioni.filter { $0.stato == .inEssere && $0.valore > 0 }
        let finanziarie = inEssere.filter { $0.area.proiettabile || $0.area == .liquidita }
        let base = finanziarie.reduce(0) { $0 + $1.valore }
        let immobili = inEssere.filter { $0.area == .immobili }.reduce(0) { $0 + $1.valore }
        var composte: [(posizione: Posizione, composizione: ComposizionePosizione)] = []
        for p in finanziarie {
            if let c = composizione(p) { composte.append((posizione: p, composizione: c)) }
        }
        let soglia = profilo?.propensione.map(sopportabile)
        return crisiDelPassato.map { k -> EsitoCrisi in
            var voci: [EsitoCrisi.Voce] = []
            for x in composte {
                let perdita = -(x.posizione.valore * x.composizione.variazione(k) / 100)
                if abs(perdita) >= 0.5 {
                    voci.append(EsitoCrisi.Voce(posizione: x.posizione, composizione: x.composizione, perdita: perdita))
                }
            }
            voci.sort { $0.perdita > $1.perdita }
            let totale = voci.reduce(0) { $0 + $1.perdita }
            return EsitoCrisi(crisi: k, voci: voci, base: base,
                              perditaImmobili: -(immobili * k.variazione(.immobili) / 100),
                              giudizio: base > 0 ? giudica(quota: totale / base, sopportabile: soglia) : nil)
        }
    }

    /// Il metodo delle crisi del passato, per il prospetto e le schermate.
    static var metodoCrisi: [String] {
        let righe: [String] = crisiDelPassato.map { k -> String in
            let classi = CrisiStorica.Classe.allCases.map { "\($0.nome.lowercased()) \(CifreDoc.percento(k.variazione($0), decimali: 0))" }
            return "\(k.titolo) (\(k.periodo)): \(classi.joined(separator: ", ")); inflazione \(CifreDoc.percento(k.inflazione))."
        }
        return righe + [
            "Le variazioni sono indicative e arrotondate (azioni mondiali in euro, titoli di Stato e obbligazioni societarie in euro); liquidità e gestioni separate restano a zero, il capitale è garantito. Si applicano alla composizione di ogni posizione: quota azionaria indicata o stimata dalla tipologia e dall'SRI, titoli di Stato secondo la quota indicata (altrimenti metà della parte obbligazionaria), multiramo con il 50% in gestione separata se non indicato. Non sono previsioni.",
        ]
    }
}
