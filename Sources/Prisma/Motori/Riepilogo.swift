import Foundation

/// Quadro delle posizioni di un cliente (o di tutti), con i totali per canale e per area.
struct RiepilogoPosizioni {
    /// Somma delle posizioni in essere che non sono debiti.
    let attivita: Double
    let debiti: Double
    var patrimonioNetto: Double { attivita - debiti }
    /// Premi e versamenti periodici di un anno, delle posizioni in essere.
    let premiAnnui: Double
    let contrattiConPremi: Int
    /// Capitale assicurato delle coperture in essere, totale e per rischio.
    let capitaleAssicurato: Double
    let perRischio: [RischioCoperto: Double]
    let coperture: Int
    /// Proposte non ancora chiuse (bozza o presentata).
    let proposteAperte: Int
    /// Versamento iniziale più un anno di premi delle proposte aperte.
    let valoreProposte: Double
    /// Valore in essere per area e per canale (debiti esclusi dal per canale).
    let perArea: [AreaPosizione: Double]
    let perCanale: [Canale: Double]
    /// Posizioni in essere che scadono nei prossimi 90 giorni o sono già scadute.
    let inScadenza: [Posizione]

    static let giorniScadenza = 90

    init(_ posizioni: [Posizione]) {
        let inEssere = posizioni.filter { $0.stato == .inEssere }
        attivita = inEssere.filter { !$0.area.passivo }.reduce(0) { $0 + $1.valore }
        debiti = inEssere.filter { $0.area.passivo }.reduce(0) { $0 + $1.valore }
        // Le rate dei debiti non sono premi né versamenti.
        let conPremi = inEssere.filter { $0.premioAnnuo > 0 && !$0.area.passivo }
        premiAnnui = conPremi.reduce(0) { $0 + $1.premioAnnuo }
        contrattiConPremi = conPremi.count
        let protezione = inEssere.filter { $0.area == .protezione }
        capitaleAssicurato = protezione.reduce(0) { $0 + ($1.capitaleAssicurato ?? 0) }
        coperture = protezione.count
        var rischi: [RischioCoperto: Double] = [:]
        for p in protezione {
            rischi[p.rischio ?? .altro, default: 0] += p.capitaleAssicurato ?? 0
        }
        perRischio = rischi
        let aperte = posizioni.filter { $0.stato == .proposta && $0.esito != .accettata && $0.esito != .rifiutata }
        proposteAperte = aperte.count
        valoreProposte = aperte.reduce(0) { $0 + $1.versamentoIniziale + $1.premioAnnuo }
        var aree: [AreaPosizione: Double] = [:]
        var canali: [Canale: Double] = [:]
        for p in inEssere {
            aree[p.area, default: 0] += p.valore
            if !p.area.passivo { canali[p.canale, default: 0] += p.valore }
        }
        perArea = aree
        perCanale = canali
        inScadenza = inEssere
            .filter { $0.scaduta || $0.scadeEntro(Self.giorniScadenza) }
            .sorted { ($0.scadenza ?? .distantFuture) < ($1.scadenza ?? .distantFuture) }
    }

    /// Quota (0–1) di un canale sulle attività in essere.
    func quota(_ canale: Canale) -> Double {
        let totale = perCanale.values.reduce(0, +)
        return totale > 0 ? (perCanale[canale] ?? 0) / totale : 0
    }
}
