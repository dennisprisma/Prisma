import Foundation

/// Ipotesi per la destinazione della liquidità: rendimenti lordi indicativi per orizzonte.
/// Servono a confrontare ordini di grandezza, non sono rendimenti di prodotti precisi.
enum IpotesiLiquidita {
    /// Rendimento di un conto corrente o di un deposito libero.
    static let conto = 0.5
    static let riserva = 1.5
    static let breve = 2.5
    static let medio = 3.0
    static let lungo = 5.0
    /// Mesi entro cui un capitale "è in scadenza".
    static let finestraMesi = 12
    /// Anni del confronto tra lasciare fermo e destinare.
    static let anniConfronto = 5
}

/// Un capitale che scade nei prossimi mesi (o già scaduto).
struct CapitaleInScadenza: Identifiable {
    let posizione: Posizione
    var id: String { posizione.id }
    let data: Date
    let scaduto: Bool
    let fisco: EsitoFiscale
    var netto: Double { fisco.netto }
}

/// Un salvadanaio: una parte del capitale con il suo orizzonte e il suo strumento.
struct Salvadanaio: Identifiable {
    enum Tipo: String, CaseIterable { case riserva, breve, medio, lungo }
    let tipo: Tipo
    var id: String { tipo.rawValue }
    let importo: Double
    let titolo: String
    let orizzonte: String
    let strumenti: String
    let rendimento: Double
    let perche: String
    /// Obiettivi che questo salvadanaio serve.
    let obiettivi: [Obiettivo]
}

/// Capitale in scadenza e liquidità: quanto arriva, quanto tenere, come destinare il resto.
struct EsitoLiquidita {
    let scadenze: [CapitaleInScadenza]
    let liquidita: [Posizione]
    var liquiditaAttuale: Double { liquidita.reduce(0) { $0 + $1.valore } }
    var nettoInScadenza: Double { scadenze.reduce(0) { $0 + $1.netto } }
    var imposteScadenze: Double { scadenze.reduce(0) { $0 + $1.fisco.imposta + $1.fisco.bolloMaturato } }
    var totale: Double { liquiditaAttuale + nettoInScadenza }
    let riservaNecessaria: Double
    let mesiRiserva: Int
    let fabbisognoMensile: Double
    let salvadanai: [Salvadanaio]
    /// Proposte aperte che potrebbero accogliere il capitale.
    let proposte: [Posizione]
    /// Valore reale (euro di oggi) dopo gli anni del confronto: tutto fermo sul conto o destinato.
    let realeFermo: Double
    let realeDestinato: Double
    var perditaFermo: Double { totale - realeFermo }
    var vantaggioDestinare: Double { realeDestinato - realeFermo }
    /// Potere d'acquisto perso in un anno lasciando l'eccedenza ferma sul conto.
    let erosioneAnnua: Double
    let note: [String]

    var eccedenza: Double { max(0, totale - riservaNecessaria) }
}

/// Calcoli della liquidità: tutto dalle Posizioni (capitali in scadenza, conti), dagli Obiettivi
/// e dalle ipotesi dell'Analisi 360 (fabbisogno mensile e mesi di riserva).
enum MotoreLiquidita {
    static func calcola(_ posizioni: [Posizione], obiettivi: [Obiettivo], analisi: IpotesiProtezione, prodotti: [Prodotto] = [],
                        data: Date = Date()) -> EsitoLiquidita {
        let limite = Calendar.current.date(byAdding: .month, value: IpotesiLiquidita.finestraMesi, to: data) ?? data
        let scadenze = posizioni
            .filter { $0.stato == .inEssere && $0.area.proiettabile && $0.scadenza.map { $0 <= limite } == true }
            .sorted { ($0.scadenza ?? data) < ($1.scadenza ?? data) }
            .map { p in
                CapitaleInScadenza(posizione: p, data: p.scadenza ?? data, scaduto: (p.scadenza ?? data) < data,
                                   fisco: MotoreFiscale.calcola(p, prodotto: p.prodottoId.flatMap { id in prodotti.first { $0.id == id } }, data: p.scadenza ?? data))
            }
        let liquidita = posizioni.filter { $0.stato == .inEssere && $0.area == .liquidita }
        let totale = liquidita.reduce(0) { $0 + $1.valore } + scadenze.reduce(0) { $0 + $1.netto }
        let riserva = analisi.fabbisognoMensile * Double(analisi.mesiRiserva)
        var note: [String] = []

        // Gli obiettivi da finanziare, per orizzonte (quanto manca oggi a ciascuno)
        func mesiA(_ d: Date) -> Int { max(0, Calendar.current.dateComponents([.month], from: data, to: d).month ?? 0) }
        let conMancante = obiettivi.map { ($0, AvanzamentoObiettivo($0, posizioni: posizioni).mancante) }.filter { $0.1 > 0.5 }
        let breve = conMancante.filter { mesiA($0.0.scadenza) <= 24 }
        let medio = conMancante.filter { mesiA($0.0.scadenza) > 24 && mesiA($0.0.scadenza) <= 84 }

        var resta = totale
        func prendi(_ v: Double) -> Double { let x = min(max(0, v), resta); resta -= x; return x }
        let quotaRiserva = prendi(riserva)
        let quotaBreve = prendi(breve.reduce(0) { $0 + $1.1 })
        let quotaMedio = prendi(medio.reduce(0) { $0 + $1.1 })
        let quotaLungo = prendi(resta)
        if quotaRiserva < riserva - 0.5 { note.append("La liquidità non basta nemmeno per la riserva di emergenza: la priorità è costruirla.") }

        let salvadanai = [
            Salvadanaio(tipo: .riserva, importo: quotaRiserva, titolo: "Riserva di emergenza", orizzonte: "subito disponibile",
                        strumenti: "conto corrente e conto deposito libero", rendimento: IpotesiLiquidita.riserva,
                        perche: "\(analisi.mesiRiserva) mesi di spese (\(CifreDoc.euro(analisi.fabbisognoMensile)) al mese) per imprevisti senza toccare gli investimenti.", obiettivi: []),
            Salvadanaio(tipo: .breve, importo: quotaBreve, titolo: "Progetti vicini", orizzonte: "entro 2 anni",
                        strumenti: "conto deposito vincolato, titoli di Stato a breve, obbligazionario a scadenza", rendimento: IpotesiLiquidita.breve,
                        perche: breve.isEmpty ? "Nessun obiettivo nei prossimi due anni." : "Per gli obiettivi dei prossimi due anni: il capitale deve esserci alla data.",
                        obiettivi: breve.map { $0.0 }),
            Salvadanaio(tipo: .medio, importo: quotaMedio, titolo: "Progetti di medio periodo", orizzonte: "da 2 a 7 anni",
                        strumenti: "polizza rivalutabile, obbligazionario, bilanciato prudente", rendimento: IpotesiLiquidita.medio,
                        perche: medio.isEmpty ? "Nessun obiettivo tra due e sette anni." : "Per gli obiettivi tra due e sette anni: stabilità con un po' di rendimento.",
                        obiettivi: medio.map { $0.0 }),
            Salvadanaio(tipo: .lungo, importo: quotaLungo, titolo: "Crescita nel tempo", orizzonte: "oltre 7 anni",
                        strumenti: "bilanciato, azionario globale con piano di accumulo, previdenza", rendimento: IpotesiLiquidita.lungo,
                        perche: "Ciò che non serve per anni può lavorare di più e proteggersi dall'inflazione.", obiettivi: []),
        ]

        // Lasciare tutto fermo sul conto o destinare: valore reale dopo gli anni del confronto
        let anni = Double(IpotesiLiquidita.anniConfronto)
        let infl = 1 + IpotesiCalcolo.inflazione / 100
        let netto: (Double) -> Double = { r in r * (1 - RegoleFiscali.ordinaria / 100) }
        let fermo = totale * pow(1 + netto(IpotesiLiquidita.conto) / 100, anni) / pow(infl, anni)
        let destinato = salvadanai.reduce(0) { $0 + $1.importo * pow(1 + netto($1.rendimento) / 100, anni) } / pow(infl, anni)
        let eccedenza = max(0, totale - riserva)
        let erosione = eccedenza * (IpotesiCalcolo.inflazione - netto(IpotesiLiquidita.conto)) / 100

        let proposte = posizioni.filter { $0.stato == .proposta && $0.area.proiettabile && $0.esito != .rifiutata }
        note.append("Rendimenti indicativi lordi per orizzonte: riserva \(CifreDoc.condizione(IpotesiLiquidita.riserva)), breve \(CifreDoc.condizione(IpotesiLiquidita.breve)), medio \(CifreDoc.condizione(IpotesiLiquidita.medio)), lungo \(CifreDoc.condizione(IpotesiLiquidita.lungo)); conto \(CifreDoc.condizione(IpotesiLiquidita.conto)). Confronto al netto del 26% e dell'inflazione del \(CifreDoc.condizione(IpotesiCalcolo.inflazione)).")
        note.append("Capitali in scadenza al valore di oggi, netti di imposte e bollo maturato: la cifra definitiva la comunica la compagnia alla scadenza.")

        return EsitoLiquidita(scadenze: scadenze, liquidita: liquidita, riservaNecessaria: riserva, mesiRiserva: analisi.mesiRiserva,
                              fabbisognoMensile: analisi.fabbisognoMensile, salvadanai: salvadanai, proposte: proposte,
                              realeFermo: fermo, realeDestinato: destinato, erosioneAnnua: erosione, note: note)
    }
}
