import Foundation

/// Un riscatto totale chiesto all'inizio di un anno di contratto, in uno scenario.
struct AnnoRiscatto: Hashable {
    /// Anno di contratto all'inizio del quale si riscatta (2 = dal 13° mese).
    let anno: Int
    /// Valore di ciascuna parte (id → euro) alla fine dell'anno precedente.
    let parti: [String: Double]
    let valore: Double
    /// Crescita del valore del contratto nell'ultimo anno (%).
    let crescita: Double
    let penalePercento: Double
    let penale: Double
    let imposta: Double
    /// Bollo maturato dall'inizio, trattenuto al pagamento.
    let bollo: Double
    let netto: Double
    let premio: Double

    /// Primo mese dell'anno (13 per il 2° anno).
    var mese: Int { (anno - 1) * 12 + 1 }
    var anniTrascorsi: Int { anno - 1 }
    var guadagno: Double { netto - premio }
    /// Variazione sul premio versato (%).
    var variazione: Double { premio > 0 ? (netto / premio - 1) * 100 : 0 }
    /// Rendimento netto medio annuo (%).
    var rendimentoMedio: Double { MotoreValutazione.medioAnnuo(netto, premio, anni: anniTrascorsi) }
    /// Rendimento medio annuo al lordo delle imposte e del bollo, come nel KID (%).
    var rendimentoLordo: Double { MotoreValutazione.medioAnnuo(valore - penale, premio, anni: anniTrascorsi) }
}

/// Costi e trattenute di un anno di contratto.
struct CostiAnno: Hashable {
    let anno: Int
    let ingresso: Double
    /// Commissione di gestione dei Fondi Interni (già nel valore delle quote).
    let commissione: Double
    /// Costi dei fondi sottostanti, stima (già nel valore delle quote).
    let sottostanti: Double
    /// Trattenuto sul rendimento della Gestione separata.
    let trattenuto: Double
    let bollo: Double
    /// Valore medio del contratto nell'anno, per l'incidenza.
    let valoreMedio: Double

    var totale: Double { ingresso + commissione + sottostanti + trattenuto + bollo }
    var incidenza: Double { valoreMedio > 0 ? totale / valoreMedio * 100 : 0 }
    var gestione: Double { commissione + sottostanti + trattenuto }
}

struct EsitoScenarioValutazione: Hashable {
    let scenario: ScenarioValutazione
    let riscatti: [AnnoRiscatto]
    let costi: [CostiAnno]

    var tipo: TipoScenario { scenario.tipo }
    func riscatto(anno: Int) -> AnnoRiscatto? { riscatti.first { $0.anno == anno } }
}

/// Una voce della cascata "dove va il denaro".
struct VoceCascata: Hashable {
    enum Genere { case partenza, meno, piu, subtotale, arrivo }
    let etichetta: String
    let importo: Double
    let genere: Genere
}

struct EsitoValutazione: Hashable {
    let premio: Double
    let ingresso: Double
    let capitale: Double
    /// Capitale iniziale di ciascuna parte (id → euro).
    let partiIniziali: [String: Double]
    let scenari: [EsitoScenarioValutazione]

    func scenario(_ t: TipoScenario) -> EsitoScenarioValutazione? { scenari.first { $0.tipo == t } }
    /// Anni di riscatto simulati (2…).
    var anniRiscatto: [Int] { scenari.first?.riscatti.map(\.anno) ?? [] }
}

/// Il motore delle valutazioni di riscatto.
///
/// Anno per anno, ogni parte del contratto cresce del suo rendimento: la Gestione separata del
/// rendimento lordo meno il trattenuto, il Fondo Interno del rendimento netto dei suoi costi.
/// Per un riscatto all'inizio dell'anno: penale sul valore del contratto, imposta sostitutiva sul
/// guadagno (valore meno penale meno premi) con l'aliquota media delle parti, bollo maturato sulle
/// quote. È lo stesso schema del prospetto illustrativo di Denis (Orizzonte Valore, ottobre 2026).
enum MotoreValutazione {
    static func calcola(_ v: ValutazioneInvestimento, condizioni c: CondizioniContratto) -> EsitoValutazione {
        let ingresso = c.ingresso(v.premio)
        let capitale = v.premio - ingresso
        let sommaQuote = max(c.componenti.reduce(0) { $0 + $1.quota }, 0.000_1)
        let iniziali = Dictionary(uniqueKeysWithValues: c.componenti.map { ($0.id, capitale * $0.quota / sommaQuote) })
        let scenari = TipoScenario.allCases.map { t in
            scenario(v.scenario(t), condizioni: c, premio: v.premio, ingresso: ingresso, iniziali: iniziali, anni: max(1, v.anni))
        }
        return EsitoValutazione(premio: v.premio, ingresso: ingresso, capitale: capitale, partiIniziali: iniziali, scenari: scenari)
    }

    private static func scenario(_ s: ScenarioValutazione, condizioni c: CondizioniContratto, premio: Double, ingresso: Double,
                                 iniziali: [String: Double], anni: Int) -> EsitoScenarioValutazione {
        var valori = iniziali
        var bollo = 0.0
        var riscatti: [AnnoRiscatto] = []
        var costi: [CostiAnno] = []
        for k in 1...anni {
            let prima = valori
            var commissione = 0.0, sottostanti = 0.0, trattenuto = 0.0, bolloAnno = 0.0
            for p in c.componenti {
                let inizio = prima[p.id] ?? 0
                let r: Double
                switch p.tipo {
                case .gestioneSeparata:
                    r = s.rendimento(p) - p.trattenuto
                    trattenuto += inizio * p.trattenuto / 100
                case .fondoInterno:
                    r = s.rendimento(p)
                }
                let fine = inizio * (1 + r / 100)
                valori[p.id] = fine
                if p.tipo == .fondoInterno {
                    let medio = (inizio + fine) / 2
                    commissione += medio * p.commissione / 100
                    sottostanti += medio * p.costiSottostanti / 100
                }
                if p.bollo { bolloAnno += fine * c.bollo / 100 }
            }
            bollo += bolloAnno
            let valorePrima = prima.values.reduce(0, +)
            let valore = valori.values.reduce(0, +)
            let anno = k + 1
            let penalePercento = c.penale(anno: anno)
            let penale = valore * penalePercento / 100
            // Aliquota media pesata sul valore di ciascuna parte
            let aliquota = valore > 0 ? c.componenti.reduce(0) { $0 + c.aliquotaParte($1) * (valori[$1.id] ?? 0) } / valore : c.aliquota
            let imposta = max(0, valore - penale - premio) * aliquota / 100
            let netto = valore - penale - imposta - bollo
            riscatti.append(AnnoRiscatto(anno: anno, parti: valori, valore: valore,
                                         crescita: valorePrima > 0 ? (valore / valorePrima - 1) * 100 : 0,
                                         penalePercento: penalePercento, penale: penale, imposta: imposta, bollo: bollo,
                                         netto: netto, premio: premio))
            costi.append(CostiAnno(anno: k, ingresso: k == 1 ? ingresso : 0, commissione: commissione, sottostanti: sottostanti,
                                   trattenuto: trattenuto, bollo: bolloAnno,
                                   valoreMedio: (valorePrima + valore) / 2))
        }
        return EsitoScenarioValutazione(scenario: s, riscatti: riscatti, costi: costi)
    }

    /// Rendimento medio annuo composto (%) da un importo iniziale a uno finale.
    static func medioAnnuo(_ finale: Double, _ iniziale: Double, anni: Int) -> Double {
        guard iniziale > 0, finale > 0, anni > 0 else { return 0 }
        return (pow(finale / iniziale, 1 / Double(anni)) - 1) * 100
    }

    /// Dove va il denaro con il primo riscatto possibile: premio, costi, rendimento, penale, imposte, netto.
    static func cascata(_ e: EsitoValutazione, _ s: EsitoScenarioValutazione) -> [VoceCascata] {
        guard let r = s.riscatti.first, let costi = s.costi.first else { return [] }
        let mercati = r.valore + costi.gestione - e.capitale
        return [
            VoceCascata(etichetta: "Premio versato", importo: e.premio, genere: .partenza),
            VoceCascata(etichetta: "Costo di ingresso", importo: -e.ingresso, genere: .meno),
            VoceCascata(etichetta: "Rendimento dei mercati", importo: mercati, genere: mercati >= 0 ? .piu : .meno),
            VoceCascata(etichetta: "Costi di gestione", importo: -costi.gestione, genere: .meno),
            VoceCascata(etichetta: "Valore del contratto", importo: r.valore, genere: .subtotale),
            VoceCascata(etichetta: "Penale \(Formati.percentuale(r.penalePercento))", importo: -r.penale, genere: .meno),
            VoceCascata(etichetta: "Imposta sostitutiva", importo: -r.imposta, genere: .meno),
            VoceCascata(etichetta: "Imposta di bollo", importo: -r.bollo, genere: .meno),
            VoceCascata(etichetta: "Netto incassato", importo: r.netto, genere: .arrivo),
        ]
    }

    /// Aliquota media d'imposta delle parti, pesata sulle quote iniziali (per i testi: "circa il 25%").
    static func aliquotaMedia(_ c: CondizioniContratto) -> Double {
        let somma = c.componenti.reduce(0) { $0 + $1.quota }
        guard somma > 0 else { return c.aliquota }
        return c.componenti.reduce(0) { $0 + c.aliquotaParte($1) * $1.quota } / somma
    }
}
