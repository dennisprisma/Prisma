import Foundation

/// La prova di resistenza del patrimonio: cosa perdono le posizioni in essere in tre scenari avversi
/// (mercati in forte calo, inflazione alta per tre anni, immobili in calo) e se la perdita sui mercati
/// sta dentro quella che il cliente può sopportare secondo il suo profilo.
/// Sono stime prudenti e semplici, non previsioni: servono a parlarne con il cliente.
struct ProvaResistenza {
    enum Tipo: String, CaseIterable, Identifiable {
        case mercati, inflazione, immobili
        var id: String { rawValue }

        var titolo: String {
            switch self {
            case .mercati: return "Mercati in forte calo"
            case .inflazione: return "Inflazione alta"
            case .immobili: return "Immobili in calo"
            }
        }

        var ipotesi: String {
            switch self {
            case .mercati:
                return "Un anno come il 2008 o il 2022: ogni posizione perde secondo il suo indicatore di rischio (SRI); il capitale garantito tiene. Nelle multiramo con i dati separati rischia solo la parte in fondi: la gestione separata non segue i mercati ed è garantita solo con il consolidamento annuo."
            case .inflazione:
                return "Prezzi in salita del \(CifreDoc.condizione(MotoreResistenza.inflazioneAlta)) l'anno per \(MotoreResistenza.anniInflazione) anni: perde potere d'acquisto ciò che rende meno."
            case .immobili:
                return "Il valore degli immobili scende del \(CifreDoc.condizione(MotoreResistenza.caloImmobili)); i debiti restano uguali."
            }
        }
    }

    /// Quanto perde una posizione in uno scenario, e perché.
    struct Voce: Identifiable {
        let posizione: Posizione
        let perdita: Double
        let motivo: String
        var id: String { posizione.id }
        var quota: Double { posizione.valore > 0 ? perdita / posizione.valore : 0 }
    }

    struct Scenario: Identifiable {
        let tipo: Tipo
        /// Dalla posizione più colpita alla meno colpita; solo le posizioni che perdono qualcosa.
        let voci: [Voce]
        /// La base su cui leggere la perdita: il patrimonio finanziario (mercati, inflazione) o il netto (immobili).
        let base: Double
        var id: String { tipo.rawValue }
        var perdita: Double { voci.reduce(0) { $0 + $1.perdita } }
        var quota: Double { base > 0 ? perdita / base : 0 }
    }

    enum Giudizio {
        case dentro, alLimite, oltre

        var etichetta: String {
            switch self {
            case .dentro: return "Dentro il profilo"
            case .alLimite: return "Al limite del profilo"
            case .oltre: return "Oltre il profilo"
            }
        }
    }

    let scenari: [Scenario]
    /// Investimento, risparmio, previdenza e liquidità in essere.
    let patrimonioFinanziario: Double
    let patrimonioNetto: Double
    /// La perdita sui mercati che il profilo del cliente sopporta (quota del patrimonio finanziario).
    let sopportabile: Double?
    let propensione: ProfiloInvestitore.Propensione?
    /// Quota del patrimonio finanziario con il capitale garantito o senza rischio di mercato.
    let quotaProtetta: Double
    /// Le crisi vere del passato (2008, 2020, 2022) applicate alle posizioni di oggi, per classe di attivo.
    /// Non entrano nel giudizio, che resta quello dello scenario sui mercati.
    var crisi: [EsitoCrisi] = []

    /// La crisi del passato che farebbe perdere di più al patrimonio di oggi (nil se nessuna lo tocca).
    var crisiPeggiore: EsitoCrisi? {
        crisi.filter { !$0.voci.isEmpty }.max { $0.perdita < $1.perdita }
    }

    func scenario(_ t: Tipo) -> Scenario? { scenari.first { $0.tipo == t } }

    /// Il confronto tra la perdita sui mercati e quella sopportabile (nil senza profilo o senza investimenti).
    var giudizio: Giudizio? {
        guard let s = sopportabile, let m = scenario(.mercati), m.base > 0 else { return nil }
        // La soglia è in percentuale, la quota è una frazione
        let perdita = m.quota * 100
        if perdita <= s { return .dentro }
        return perdita <= s * MotoreResistenza.margineLimite ? .alLimite : .oltre
    }

    var vuota: Bool { scenari.allSatisfy { $0.voci.isEmpty } }
}

enum MotoreResistenza {
    /// Calo in uno scenario severo di mercato, per indicatore di rischio SRI (1–7). Stime prudenti
    /// coerenti con le classi di volatilità dei KID: un anno di forte crisi, non il caso peggiore assoluto.
    static let caloPerSRI: [Int: Double] = [1: 0, 2: 3, 3: 10, 4: 20, 5: 30, 6: 40, 7: 55]
    /// L'SRI quando il contratto non lo dice: secondo l'area.
    static func sriProbabile(_ a: AreaPosizione) -> Int {
        switch a {
        case .liquidita: return 1
        case .risparmio: return 2
        case .previdenza: return 3
        default: return 4
        }
    }
    /// La perdita sui mercati che ogni profilo sopporta, in % del patrimonio finanziario.
    static func sopportabile(_ p: ProfiloInvestitore.Propensione) -> Double {
        switch p {
        case .prudente: return 5
        case .moderata: return 10
        case .dinamica: return 20
        case .aggressiva: return 30
        }
    }
    /// Fino a un quarto oltre la soglia è «al limite».
    static let margineLimite = 1.25
    static let inflazioneAlta = 5.0
    static let anniInflazione = 3
    static let caloImmobili = 15.0

    static func calcola(_ posizioni: [Posizione], profilo: ProfiloInvestitore?) -> ProvaResistenza {
        let inEssere = posizioni.filter { $0.stato == .inEssere && $0.valore > 0 }
        let finanziarie = inEssere.filter { $0.area.proiettabile || $0.area == .liquidita }
        let finanziario = finanziarie.reduce(0) { $0 + $1.valore }
        let riepilogo = RiepilogoPosizioni(posizioni)

        let mercati = finanziarie.compactMap(voceMercati).sorted { $0.perdita > $1.perdita }
        let inflazione = finanziarie.compactMap(voceInflazione).sorted { $0.perdita > $1.perdita }
        let immobili = inEssere.filter { $0.area == .immobili }.map {
            ProvaResistenza.Voce(posizione: $0, perdita: $0.valore * caloImmobili / 100, motivo: "Calo del \(CifreDoc.condizione(caloImmobili)) del valore")
        }.sorted { $0.perdita > $1.perdita }

        let protetta = finanziarie.reduce(0) { $0 + $1.valore * (1 - quotaARischio($1)) }
        return ProvaResistenza(
            scenari: [
                .init(tipo: .mercati, voci: mercati, base: finanziario),
                .init(tipo: .inflazione, voci: inflazione, base: finanziario),
                .init(tipo: .immobili, voci: immobili, base: max(riepilogo.patrimonioNetto, 0)),
            ],
            patrimonioFinanziario: finanziario,
            patrimonioNetto: riepilogo.patrimonioNetto,
            sopportabile: profilo?.propensione.map(sopportabile),
            propensione: profilo?.propensione,
            quotaProtetta: finanziario > 0 ? protetta / finanziario : 0,
            crisi: MotoreResistenza.crisi(posizioni, profilo: profilo))
    }

    /// La parte del valore esposta ai mercati: niente per conti e gestioni separate,
    /// la parte fuori dalla gestione separata per le multiramo.
    static func quotaARischio(_ p: Posizione) -> Double {
        if p.area == .liquidita || p.gestioneSeparata { return 0 }
        // Previdenza in gestione separata (PIP di Ramo I): il valore non scende
        if p.area == .previdenza, (p.tipologia + " " + p.garanzie).lowercased().contains("gestione separata") { return 0 }
        // Multiramo senza la quota indicata: metà in gestione separata, come dice il metodo
        // (per il bollo invece resta tutta soggetta, stima prudente in `Posizione.quotaBollo`)
        if p.multiramo { return 1 - min(max(p.quotaGestioneSeparata ?? quotaGestioneSeparataPredefinita, 0), 100) / 100 }
        return 1
    }

    private static func voceMercati(_ p: Posizione) -> ProvaResistenza.Voce? {
        if p.multiramoDivisa { return voceMercatiDueParti(p) }
        let esposta = quotaARischio(p)
        guard esposta > 0 else { return nil }
        let sri = min(max(p.sri ?? sriProbabile(p.area), 1), 7)
        let calo = caloPerSRI[sri] ?? 0
        guard calo > 0 else { return nil }
        var motivo = p.sri == nil ? "SRI non indicato, stimato \(sri) su 7 dall'area" : "SRI \(sri) su 7: calo del \(CifreDoc.condizione(calo))"
        if esposta < 1 {
            let stimata = p.multiramo && p.quotaGestioneSeparata == nil ? " (stimato)" : ""
            motivo += "; \(CifreDoc.percento((1 - esposta) * 100, decimali: 0)) in gestione separata\(stimata), garantita"
        }
        return .init(posizione: p, perdita: p.valore * esposta * calo / 100, motivo: motivo)
    }

    /// Multiramo a due parti: perde solo la parte in fondi, secondo l'SRI dei fondi (indicato o stimato dalla
    /// loro volatilità). L'SRI della combinazione non si applica più alla sola parte esposta: niente doppio
    /// sconto. La gestione separata non segue i mercati; è garantita solo con il consolidamento annuo
    /// (non indicato = annuo, come per il Ramo I).
    private static func voceMercatiDueParti(_ p: Posizione) -> ProvaResistenza.Voce? {
        let fondi = p.parteFondi
        guard fondi > 0 else { return nil }
        let sri = p.sriParteFondi
        let calo = caloPerSRI[sri] ?? 0
        guard calo > 0 else { return nil }
        let sriStimato = p.sriFondi == nil ? " (stimato)" : ""
        var motivo = "Fondi: SRI \(sri) su 7\(sriStimato), calo del \(CifreDoc.condizione(calo)) sul \(CifreDoc.percento(fondi * 100, decimali: 0)) in fondi"
        if p.parteGestione > 0 {
            let stimata = p.quotaGestioneStimata ? " (stimato)" : ""
            let garanzia = p.consolidamento == false ? "che non segue i mercati, senza garanzia prima della scadenza" : "garantita"
            motivo += "; \(CifreDoc.percento(p.parteGestione * 100, decimali: 0)) in gestione separata\(stimata), \(garanzia)"
        }
        return .init(posizione: p, perdita: p.valore * fondi * calo / 100, motivo: motivo)
    }

    /// Il potere d'acquisto perso in tre anni d'inflazione alta, per ciò che rende meno dell'inflazione
    /// (al netto dei costi; i conti senza rendimento indicato rendono zero).
    private static func voceInflazione(_ p: Posizione) -> ProvaResistenza.Voce? {
        // Senza rendimento indicato: zero per i conti, l'ipotesi predefinita per il resto.
        // Multiramo a due parti: accreditato della gestione separata e netto dei fondi, pesati sulle quote.
        let netto = p.multiramoDivisa ? p.rendimentoNettoComposto
            : (p.rendimentoAtteso ?? (p.area == .liquidita ? 0 : IpotesiCalcolo.rendimentoPredefinito)) - (p.costoComplessivo ?? 0)
        guard netto < inflazioneAlta else { return nil }
        let anni = Double(anniInflazione)
        let reale = pow((1 + netto / 100) / (1 + inflazioneAlta / 100), anni)
        let perdita = p.valore * (1 - reale)
        guard perdita > 0.5 else { return nil }
        return .init(posizione: p, perdita: perdita,
                     motivo: "Rende \(CifreDoc.percento(netto)) netto, sotto il \(CifreDoc.condizione(inflazioneAlta)) dei prezzi")
    }

    /// Due righe per Eve e per le schede: la perdita di ogni scenario e il confronto con il profilo.
    static func sintesi(_ r: ProvaResistenza) -> [String] {
        var righe: [String] = []
        for s in r.scenari where !s.voci.isEmpty {
            let colpita = s.voci.first.map { " (la più colpita: \($0.posizione.nome), \(Formati.euro($0.perdita)))" } ?? ""
            let base = s.tipo == .immobili ? "del patrimonio netto" : "del patrimonio finanziario"
            righe.append("\(s.tipo.titolo): \(Formati.euro(s.perdita)), il \(CifreDoc.percento(s.quota * 100)) \(base)\(colpita).")
        }
        if let g = r.giudizio, let s = r.sopportabile, let p = r.propensione, let m = r.scenario(.mercati) {
            righe.append("\(g.etichetta): con una propensione \(p.nome.lowercased()) si sopporta una perdita fino al \(CifreDoc.condizione(s)); sui mercati la stima è il \(CifreDoc.percento(m.quota * 100)).")
        }
        if r.patrimonioFinanziario > 0 {
            righe.append("Capitale garantito o senza rischio di mercato: il \(CifreDoc.percento(r.quotaProtetta * 100, decimali: 0)) del patrimonio finanziario.")
        }
        // In fondo e su una riga: le crisi vere del passato sul patrimonio di oggi
        let crisi = r.crisi.filter { !$0.voci.isEmpty }
        if !crisi.isEmpty, r.patrimonioFinanziario > 0 {
            let elenco = crisi.map { k -> String in
                let euro = k.perdita >= 0 ? Formati.meno + Formati.euro(k.perdita) : "+" + Formati.euro(-k.perdita)
                return "\(k.crisi.anno) \(euro) (\(CifreDoc.percento(-k.quota * 100)))"
            }
            righe.append("Se tornassero le crisi del passato (stime indicative): " + elenco.joined(separator: ", ") + ".")
        }
        return righe
    }
}
