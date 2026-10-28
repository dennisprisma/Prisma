import Foundation

/// Un punto in cui le posizioni del cliente non sono coerenti con il suo profilo: troppo rischio per la
/// propensione dichiarata, una proposta oltre il profilo o l'orizzonte, troppo patrimonio su un emittente
/// o su un canale.
struct Incoerenza: Identifiable {
    enum Tipo: Int, CaseIterable {
        case rischioMedio, azioni, crisi, proposta, orizzonte, emittente, canale

        var nome: String {
            switch self {
            case .rischioMedio: return "Rischio medio"
            case .azioni: return "Quota azionaria"
            case .crisi: return "Crisi del passato"
            case .proposta: return "Proposta"
            case .orizzonte: return "Orizzonte"
            case .emittente: return "Emittente"
            case .canale: return "Canale"
            }
        }

        /// Concentrazione (emittente o canale) invece che rischio rispetto al profilo.
        var concentrazione: Bool { self == .emittente || self == .canale }
    }

    let tipo: Tipo
    let titolo: String
    let dettaglio: String
    /// La posizione interessata, per i controlli su una sola posizione (proposte).
    let posizione: Posizione?
    /// Il valore misurato e la soglia, nella stessa unità (SRI su 7, oppure %, oppure anni).
    let valore: Double
    let soglia: Double
    /// true se l'incoerenza nasce con le proposte aperte (prima di presentarle).
    let dopoLeProposte: Bool
    var id: String { "\(tipo.rawValue)·\(posizione?.id ?? "-")·\(dopoLeProposte ? "proposte" : "oggi")·\(titolo)" }
}

/// Le misure di rischio e di concentrazione di un insieme di posizioni.
struct MisureCoerenza {
    struct Emittente: Identifiable {
        let nome: String
        let valore: Double
        /// Quota del patrimonio finanziario (0–1).
        let quota: Double
        let posizioni: Int
        /// Il canale, se tutte le posizioni dell'emittente sono dello stesso.
        let canale: Canale?
        var id: String { nome }
    }

    /// Investimento, risparmio, previdenza e liquidità.
    let patrimonioFinanziario: Double
    /// Il patrimonio finanziario senza la liquidità.
    let investimenti: Double
    /// SRI medio ponderato sul valore (liquidità e gestioni separate senza SRI contano 1).
    let sriMedio: Double?
    /// Quota del patrimonio finanziario in azioni (0–1), indicata o stimata.
    let quotaAzionaria: Double?
    let crisi: [EsitoCrisi]
    /// Dal più grande; liquidità esclusa (i conti hanno altre tutele), la quota è sul patrimonio finanziario.
    let emittenti: [Emittente]
    /// Quanto è investito in ogni canale (liquidità esclusa), in quota del patrimonio finanziario (0–1).
    let perCanale: [Canale: Double]

    var crisiPeggiore: EsitoCrisi? {
        crisi.filter { !$0.voci.isEmpty }.max { $0.perdita < $1.perdita }
    }
}

/// La coerenza delle posizioni di un cliente con il suo profilo, oggi e con le proposte aperte.
struct EsitoCoerenza {
    let propensione: ProfiloInvestitore.Propensione?
    let oggi: MisureCoerenza
    /// Le stesse misure contando anche le proposte aperte (nil se non ce ne sono).
    let conProposte: MisureCoerenza?
    /// Prima i controlli sul rischio, poi le proposte, poi la concentrazione.
    let incoerenze: [Incoerenza]

    var coerente: Bool { incoerenze.isEmpty }
    var rischio: [Incoerenza] { incoerenze.filter { !$0.tipo.concentrazione } }
    var concentrazione: [Incoerenza] { incoerenze.filter { $0.tipo.concentrazione } }
}

/// Coerenza con il profilo del cliente. Calcoli leggeri (nessuna simulazione), adatti anche al
/// pannello delle attenzioni di tutto il portafoglio. Le posizioni passate sono quelle del cliente.
enum MotoreCoerenza {
    /// SRI medio massimo per propensione (fasce usate di solito nell'adeguatezza: prudente fino a 2,
    /// moderata fino a 3, dinamica fino a 5, aggressiva senza limite).
    static func sriMassimo(_ p: ProfiloInvestitore.Propensione) -> Int {
        switch p {
        case .prudente: return 2
        case .moderata: return 3
        case .dinamica: return 5
        case .aggressiva: return 7
        }
    }

    /// Quota azionaria massima per propensione, in % del patrimonio finanziario (le fasce dei portafogli
    /// modello: prudente 20%, moderata 50%, dinamica 80%, aggressiva 100%).
    static func azioniMassime(_ p: ProfiloInvestitore.Propensione) -> Double {
        switch p {
        case .prudente: return 20
        case .moderata: return 50
        case .dinamica: return 80
        case .aggressiva: return 100
        }
    }

    /// Oltre il 50% del patrimonio finanziario presso un solo emittente è concentrazione eccessiva...
    static let sogliaEmittente = 50.0
    /// ...ma solo da 10.000 € in su: sotto, diversificare costa più di quanto protegga.
    static let minimoConcentrazione = 10_000.0
    /// Oltre l'80% del patrimonio finanziario investito nel canale Alleanza, che colloca i prodotti di una sola
    /// compagnia (la liquidità conta nella base, non nel canale).
    /// Il canale indipendente sceglie tra molti emittenti: lì conta la concentrazione per emittente.
    static let sogliaCanale = 80.0

    /// L'SRI per la media: quello indicato; senza, 1 per liquidità e capitale garantito, altrimenti
    /// quello probabile dell'area. Multiramo a due parti: l'SRI della combinazione scelta (quello del KID o,
    /// se manca, stimato dalla volatilità combinata), mai la media degli SRI delle opzioni né quello dei soli
    /// fondi, che sovrastimerebbe il rischio del contratto.
    static func sriStimato(_ p: Posizione) -> Int {
        if p.multiramoDivisa { return p.sriComposto }
        if let s = p.sri { return min(max(s, 1), 7) }
        if p.area == .liquidita || MotoreResistenza.quotaARischio(p) == 0 { return 1 }
        return MotoreResistenza.sriProbabile(p.area)
    }

    /// L'emittente di una posizione; senza nome, quelle del canale Alleanza sono di Alleanza Assicurazioni.
    static func nomeEmittente(_ p: Posizione) -> String {
        let e = p.emittente.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.isEmpty && p.canale == .alleanza { return Canale.alleanza.nome }
        return e
    }

    /// La chiave per riconoscere lo stesso emittente scritto in modi diversi («ALLEANZA», «Alleanza
    /// Assicurazioni S.p.A.»): minuscole, senza accenti, punteggiatura e forma giuridica.
    static func chiaveEmittente(_ nome: String) -> String {
        let base = nome.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT")).lowercased()
        let parole = base.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let scarta: Set<String> = ["spa", "s", "p", "a", "srl", "assicurazioni", "assicurazione"]
        let utili = parole.filter { !scarta.contains($0) }
        return (utili.isEmpty ? parole : utili).joined(separator: " ")
    }

    /// Una proposta contata come se fosse in essere: versamento iniziale più un anno di premi.
    static func comeInEssere(_ p: Posizione) -> Posizione {
        var q = p
        q.stato = .inEssere
        q.controvalore = p.versamentoIniziale + p.premioAnnuo
        return q
    }

    /// Proposte ancora aperte (né accettate né rifiutate).
    static func proposteAperte(_ posizioni: [Posizione]) -> [Posizione] {
        posizioni.filter { $0.stato == .proposta && $0.esito != .accettata && $0.esito != .rifiutata }
    }

    static func misure(_ posizioni: [Posizione], profilo: ProfiloInvestitore?) -> MisureCoerenza {
        let finanziarie = posizioni.filter { $0.stato == .inEssere && $0.valore > 0 && ($0.area.proiettabile || $0.area == .liquidita) }
        let totale = finanziarie.reduce(0) { $0 + $1.valore }
        var sommaSRI = 0.0
        var sommaAzioni = 0.0
        for p in finanziarie {
            sommaSRI += p.valore * Double(sriStimato(p))
            sommaAzioni += p.valore * (MotoreResistenza.composizione(p)?.azioni ?? 0)
        }
        let sri: Double? = totale > 0 ? sommaSRI / totale : nil
        let azioni: Double? = totale > 0 ? sommaAzioni / totale : nil
        let investite = finanziarie.filter { $0.area != .liquidita }
        let investimenti = investite.reduce(0) { $0 + $1.valore }

        var gruppi: [String: [Posizione]] = [:]
        for p in investite {
            let nome = nomeEmittente(p)
            guard !nome.isEmpty else { continue }
            gruppi[chiaveEmittente(nome), default: []].append(p)
        }
        let emittenti = gruppi.values.map { elenco -> MisureCoerenza.Emittente in
            let valore = elenco.reduce(0) { $0 + $1.valore }
            // Il nome com'è scritto nella posizione più grande
            let principale = elenco.max { $0.valore < $1.valore }
            let insieme = Set(elenco.map(\.canale))
            return MisureCoerenza.Emittente(nome: principale.map(nomeEmittente) ?? "", valore: valore,
                                            quota: totale > 0 ? valore / totale : 0, posizioni: elenco.count,
                                            canale: insieme.count == 1 ? insieme.first : nil)
        }
        .sorted { $0.valore != $1.valore ? $0.valore > $1.valore : $0.nome < $1.nome }

        var canali: [Canale: Double] = [:]
        if totale > 0 {
            for p in investite { canali[p.canale, default: 0] += p.valore / totale }
        }
        return MisureCoerenza(patrimonioFinanziario: totale, investimenti: investimenti, sriMedio: sri, quotaAzionaria: azioni,
                              crisi: MotoreResistenza.crisi(finanziarie, profilo: profilo), emittenti: emittenti, perCanale: canali)
    }

    static func calcola(cliente c: Cliente, posizioni: [Posizione], prodotti: [Prodotto] = []) -> EsitoCoerenza {
        let inEssere = posizioni.filter { $0.stato == .inEssere }
        let proposte = proposteAperte(posizioni)
        let profilo = c.profilo
        let oggi = misure(inEssere, profilo: profilo)
        let conProposte: MisureCoerenza? = proposte.isEmpty ? nil : misure(inEssere + proposte.map(comeInEssere), profilo: profilo)

        var elenco: [Incoerenza] = []
        if let pr = profilo.propensione {
            elenco += rischio(oggi, propensione: pr, dopoLeProposte: false)
            if let cp = conProposte {
                // Con le proposte: solo ciò che nasce da loro
                let giaSegnalati = Set(elenco.map(\.tipo.rawValue))
                let nuove = rischio(cp, propensione: pr, dopoLeProposte: true).filter { !giaSegnalati.contains($0.tipo.rawValue) }
                elenco += nuove
            }
            let massimo = sriMassimo(pr)
            for p in proposte {
                // Multiramo a due parti: conta la combinazione; fondi oltre il profilo con la combinazione
                // dentro non sono un'incoerenza (lo dice il dettaglio della posizione)
                let sriProposta: Int? = p.multiramoDivisa ? p.sriComposto : p.sri
                guard let s = sriProposta, s > massimo else { continue }
                elenco.append(Incoerenza(tipo: .proposta, titolo: "Proposta oltre il profilo",
                                         dettaglio: "\(p.nome): SRI \(s) su 7, oltre il \(massimo) di un profilo \(pr.nome.lowercased()).",
                                         posizione: p, valore: Double(s), soglia: Double(massimo), dopoLeProposte: true))
            }
        }
        if let anni = profilo.orizzonteAnni, anni > 0 {
            for p in proposte {
                let scheda = p.prodottoId.flatMap { id in prodotti.first { $0.id == id } }
                guard let periodo = p.periodoRaccomandato ?? scheda?.periodoConsigliato, periodo > anni else { continue }
                elenco.append(Incoerenza(tipo: .orizzonte, titolo: "Orizzonte più lungo del profilo",
                                         dettaglio: "\(p.nome): periodo raccomandato di \(periodo) anni, il cliente ha indicato \(anni) \(anni == 1 ? "anno" : "anni").",
                                         posizione: p, valore: Double(periodo), soglia: Double(anni), dopoLeProposte: true))
            }
        }
        let concentrazioni = concentrazione(oggi, dopoLeProposte: false)
        elenco += concentrazioni
        if let cp = conProposte {
            let giaSegnalati = Set(concentrazioni.map(\.tipo.rawValue))
            let nuove = concentrazione(cp, dopoLeProposte: true).filter { !giaSegnalati.contains($0.tipo.rawValue) }
            elenco += nuove
        }
        return EsitoCoerenza(propensione: profilo.propensione, oggi: oggi, conProposte: conProposte, incoerenze: elenco)
    }

    /// Rischio medio, azioni e crisi del passato rispetto alla propensione.
    static func rischio(_ m: MisureCoerenza, propensione pr: ProfiloInvestitore.Propensione, dopoLeProposte: Bool) -> [Incoerenza] {
        var elenco: [Incoerenza] = []
        let prefisso = dopoLeProposte ? "Con le proposte: " : ""
        let profilo = "un profilo \(pr.nome.lowercased())"
        let massimo = sriMassimo(pr)
        if let s = m.sriMedio, s > Double(massimo) {
            elenco.append(Incoerenza(tipo: .rischioMedio, titolo: prefisso + "Rischio medio oltre il profilo",
                                     dettaglio: "SRI medio ponderato \(numero(s)) su 7, oltre il \(massimo) di \(profilo).",
                                     posizione: nil, valore: s, soglia: Double(massimo), dopoLeProposte: dopoLeProposte))
        }
        let limite = azioniMassime(pr)
        if let a = m.quotaAzionaria, a * 100 > limite {
            elenco.append(Incoerenza(tipo: .azioni, titolo: prefisso + "Troppe azioni per il profilo",
                                     dettaglio: "Il \(CifreDoc.percento(a * 100, decimali: 0)) del patrimonio finanziario in azioni, oltre il \(CifreDoc.percento(limite, decimali: 0)) di \(profilo).",
                                     posizione: nil, valore: a * 100, soglia: limite, dopoLeProposte: dopoLeProposte))
        }
        if let k = m.crisiPeggiore, k.giudizio == .oltre {
            let sopportabile = MotoreResistenza.sopportabile(pr)
            elenco.append(Incoerenza(tipo: .crisi, titolo: prefisso + "Nelle crisi vere, oltre il profilo",
                                     dettaglio: "Una crisi come quella del \(k.crisi.anno) (\(k.crisi.titolo.lowercased())) toglierebbe circa \(CifreDoc.euro(k.perdita)), il \(CifreDoc.percento(k.quota * 100)) del patrimonio finanziario: \(profilo) ne sopporta il \(CifreDoc.condizione(sopportabile)).",
                                     posizione: nil, valore: k.quota * 100, soglia: sopportabile, dopoLeProposte: dopoLeProposte))
        }
        return elenco
    }

    /// Troppo su un emittente, o quasi tutto nel canale Alleanza (solo se l'emittente non lo dice già).
    static func concentrazione(_ m: MisureCoerenza, dopoLeProposte: Bool) -> [Incoerenza] {
        var elenco: [Incoerenza] = []
        let prefisso = dopoLeProposte ? "Con le proposte: " : ""
        if let e = m.emittenti.first, e.quota * 100 > sogliaEmittente, e.valore >= minimoConcentrazione {
            let posizioni = e.posizioni == 1 ? "una posizione" : "\(e.posizioni) posizioni"
            elenco.append(Incoerenza(tipo: .emittente, titolo: prefisso + "Concentrazione su un emittente",
                                     dettaglio: "Il \(CifreDoc.percento(e.quota * 100, decimali: 0)) del patrimonio finanziario presso \(e.nome) (\(posizioni), \(CifreDoc.euro(e.valore))): oltre il \(CifreDoc.percento(sogliaEmittente, decimali: 0)) è utile valutare se diversificare.",
                                     posizione: nil, valore: e.quota * 100, soglia: sogliaEmittente, dopoLeProposte: dopoLeProposte))
        }
        let alleanza = (m.perCanale[.alleanza] ?? 0) * 100
        if elenco.isEmpty, alleanza > sogliaCanale, m.investimenti >= minimoConcentrazione {
            elenco.append(Incoerenza(tipo: .canale, titolo: prefisso + "Quasi tutto in un solo canale",
                                     dettaglio: "Il \(CifreDoc.percento(alleanza, decimali: 0)) del patrimonio finanziario è investito nel canale Alleanza, che colloca i prodotti di una sola compagnia.",
                                     posizione: nil, valore: alleanza, soglia: sogliaCanale, dopoLeProposte: dopoLeProposte))
        }
        return elenco
    }

    private static let formatoNumero: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    /// Un numero con un decimale, all'italiana: «3,4».
    static func numero(_ v: Double) -> String {
        formatoNumero.string(from: NSNumber(value: v)) ?? String(format: "%.1f", v)
    }

    /// Il metodo, per il prospetto e le schermate.
    static var metodo: [String] {
        [
            "Rischio rispetto al profilo: SRI medio ponderato sul valore (liquidità e capitale garantito senza SRI contano 1; per le multiramo con i dati separati l'SRI della combinazione, dal KID o stimato) entro prudente 2, moderata 3, dinamica 5; azioni entro prudente 20%, moderata 50%, dinamica 80% del patrimonio finanziario; nelle crisi vere del 2008, 2020 e 2022 la perdita peggiore non oltre un quarto sopra quella sopportabile (prudente 5%, moderata 10%, dinamica 20%, aggressiva 30%).",
            "Proposte: si segnalano quelle con un SRI oltre il profilo o un periodo raccomandato più lungo dell'orizzonte del cliente, e ciò che cambierebbe con le proposte aperte (contate per il versamento iniziale più un anno di premi).",
            "Concentrazione: oltre il \(CifreDoc.percento(sogliaEmittente, decimali: 0)) del patrimonio finanziario presso un solo emittente (da \(CifreDoc.euro(minimoConcentrazione)) in su; i conti esclusi), oppure oltre l'\(CifreDoc.percento(sogliaCanale, decimali: 0)) investito nel canale Alleanza, che colloca i prodotti di una sola compagnia.",
        ]
    }
}
