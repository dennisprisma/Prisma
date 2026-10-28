import Foundation

/// Le analisi più pesanti di Obiettivi, Analisi 360 e del prospetto dell'obiettivo, calcolate una volta e
/// ricordate: la vista si ridisegna spesso, gli scenari con le probabilità e il fisco delle polizze no. Si
/// ricalcolano solo quando cambiano l'obiettivo, le posizioni, il cliente o il giorno. Si usano solo dalle
/// schermate e dai documenti (mai dai calcoli che legge Eve).
enum CacheMotoriAnalisi {
    /// Scenari con le probabilità già calcolati, per chiave dell'obiettivo e delle sue posizioni.
    nonisolated(unsafe) private static var memoriaScenari: [Int: EsitoMonteCarlo] = [:]
    /// Quanti esiti tenere al massimo (un cliente ha pochi obiettivi; poi si ricomincia).
    private static let massimoScenari = 12
    nonisolated(unsafe) private static var memoriaFisco: (chiave: Int, valore: FiscoPolizzeCliente)?

    /// La probabilità di raggiungere l'obiettivo con le posizioni collegate (scenari con le probabilità).
    /// `posizioni`: quelle del cliente; contano solo le collegate in essere. `data`: il giorno da cui parte
    /// la stima (quello del documento, nei prospetti).
    static func scenari(_ o: Obiettivo, posizioni: [Posizione], data: Date = Date()) -> EsitoMonteCarlo {
        let collegate = posizioni.filter { o.posizioniCollegate.contains($0.id) }
        var h = Hasher()
        h.combine(o)
        h.combine(collegate)
        h.combine(Calendar.current.startOfDay(for: data))
        let chiave = h.finalize()
        if let esito = memoriaScenari[chiave] { return esito }
        let esito = MotoreMonteCarlo.obiettivo(o, posizioni: collegate, data: data)
        if memoriaScenari.count >= massimoScenari { memoriaScenari.removeAll() }
        memoriaScenari[chiave] = esito
        return esito
    }

    /// Il fisco delle polizze del cliente: detrazioni per persona, capitali al decesso, bollo, deducibilità.
    static func fisco(cliente: Cliente, posizioni: [Posizione]) -> FiscoPolizzeCliente {
        var h = Hasher()
        h.combine(cliente)
        h.combine(posizioni)
        h.combine(Calendar.current.startOfDay(for: Date()))
        let chiave = h.finalize()
        if let f = memoriaFisco, f.chiave == chiave { return f.valore }
        let valore = FiscoPolizze.riepilogo(cliente: cliente, posizioni: posizioni)
        memoriaFisco = (chiave, valore)
        return valore
    }
}
