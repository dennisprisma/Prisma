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
    /// false se il riscatto cade nei mesi di blocco del contratto (`CondizioniContratto.mesiBloccoRiscatto`):
    /// le cifre restano come ipotesi, ma il riscatto non si può chiedere.
    var possibile = true
    /// Valore che il contratto avrebbe senza alcun costo (né ingresso, né gestione, né trattenuto, né penale),
    /// per l'incidenza dei costi come nel KID; 0 se non calcolato.
    var valoreSenzaCosti: Double = 0

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
    /// Rendimento medio annuo senza costi (%), al lordo delle imposte.
    var rendimentoSenzaCosti: Double { MotoreValutazione.medioAnnuo(valoreSenzaCosti, premio, anni: anniTrascorsi) }
    /// Incidenza annua dei costi come nel KID (RIY, punti percentuali l'anno): rendimento senza costi meno
    /// rendimento lordo con i costi e la penale; nil se il valore senza costi non è calcolato.
    var incidenzaCosti: Double? { valoreSenzaCosti > 0 ? rendimentoSenzaCosti - rendimentoLordo : nil }
    /// Il riscatto restituisce almeno il premio versato (si può chiedere e il netto è almeno il premio).
    var recuperaPremio: Bool { possibile && netto >= premio - 0.005 }
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
    /// Il primo riscatto possibile (fuori dai mesi di blocco).
    var primoPossibile: AnnoRiscatto? { riscatti.first { $0.possibile } }
    /// Il primo riscatto possibile che restituisce almeno il premio versato, se c'è negli anni simulati.
    var primoRecuperoPremio: AnnoRiscatto? { riscatti.first { $0.recuperaPremio } }
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
        // Lo stesso contratto senza costi (premio intero, nessun trattenuto né commissione): per l'incidenza come nel KID
        let sommaQuote = max(c.componenti.reduce(0) { $0 + $1.quota }, 0.000_1)
        var liberi = Dictionary(uniqueKeysWithValues: c.componenti.map { ($0.id, premio * $0.quota / sommaQuote) })
        var bollo = 0.0
        var riscatti: [AnnoRiscatto] = []
        var costi: [CostiAnno] = []
        for k in 1...anni {
            let prima = valori
            var commissione = 0.0, sottostanti = 0.0, trattenuto = 0.0, bolloAnno = 0.0
            for p in c.componenti {
                let inizio = prima[p.id] ?? 0
                let r: Double
                let lordo: Double
                switch p.tipo {
                case .gestioneSeparata:
                    // Lordo meno trattenuto (o retrocessione); con il consolidamento mai sotto il minimo garantito
                    lordo = s.rendimento(p)
                    r = MotoreGestioneSeparata.accreditato(p, lordo: lordo)
                    let punti = p.retrocessione == nil && r == lordo - p.trattenuto ? p.trattenuto : max(0, lordo - r)
                    trattenuto += inizio * punti / 100
                case .fondoInterno:
                    r = s.rendimento(p)
                    // Il rendimento del Fondo Interno è già netto delle commissioni: senza costi sarebbe più alto
                    let costiFondo = min(max(p.commissione + p.costiSottostanti, 0), 99) / 100
                    lordo = ((1 + r / 100) / (1 - costiFondo) - 1) * 100
                }
                let fine = inizio * (1 + r / 100)
                valori[p.id] = fine
                // Senza costi la gestione separata rende il lordo (con il consolidamento, almeno il minimo garantito)
                let lordoLibero = p.tipo == .gestioneSeparata && p.consolidamento == true ? max(lordo, max(0, p.minimoGarantito ?? 0)) : lordo
                liberi[p.id] = (liberi[p.id] ?? 0) * (1 + lordoLibero / 100)
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
                                         netto: netto, premio: premio,
                                         // Nei mesi di blocco il riscatto non si può chiedere
                                         possibile: (anno - 1) * 12 >= c.mesiBloccoRiscatto,
                                         valoreSenzaCosti: liberi.values.reduce(0, +)))
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
