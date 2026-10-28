import Foundation

/// Le analisi nuove del dossier Posizioni che non stanno in `AnalisiDossier`: la coerenza con il profilo
/// del cliente e l'incidenza dei costi come nel KID di ogni posizione. Si ricalcolano solo quando cambiano
/// il cliente, le sue posizioni, il catalogo o il giorno: la vista si ridisegna a ogni spostamento di finestra.
/// Si usano solo dalle schermate (mai dai calcoli che legge Eve).
enum CacheMotoriPosizioni {
    nonisolated(unsafe) private static var ultimaCoerenza: (chiave: Int, valore: EsitoCoerenza)?
    nonisolated(unsafe) private static var ultimeIncidenze: (chiave: Int, valore: [String: IncidenzaCostiKID])?

    /// La coerenza con il profilo delle posizioni del cliente (in essere e proposte aperte).
    static func coerenza(cliente: Cliente, posizioni: [Posizione], prodotti: [Prodotto]) -> EsitoCoerenza {
        var h = Hasher()
        h.combine(cliente)
        h.combine(posizioni)
        h.combine(prodotti)
        h.combine(Calendar.current.startOfDay(for: Date()))
        let chiave = h.finalize()
        if let c = ultimaCoerenza, c.chiave == chiave { return c.valore }
        let valore = MotoreCoerenza.calcola(cliente: cliente, posizioni: posizioni, prodotti: prodotti)
        ultimaCoerenza = (chiave, valore)
        return valore
    }

    /// L'incidenza annua dei costi come nel KID (RIY) per ogni posizione che la ha, per id della posizione.
    static func incidenze(_ posizioni: [Posizione], prodotti: [Prodotto]) -> [String: IncidenzaCostiKID] {
        var h = Hasher()
        h.combine(posizioni)
        h.combine(prodotti)
        h.combine(Calendar.current.startOfDay(for: Date()))
        let chiave = h.finalize()
        if let c = ultimeIncidenze, c.chiave == chiave { return c.valore }
        var valore: [String: IncidenzaCostiKID] = [:]
        for p in posizioni {
            let scheda: Prodotto? = p.prodottoId.flatMap { id in prodotti.first { $0.id == id } }
            if let k = MotoreCosti.incidenzaKID(p, prodotto: scheda) { valore[p.id] = k }
        }
        ultimeIncidenze = (chiave, valore)
        return valore
    }
}
