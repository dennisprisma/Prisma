import Foundation

/// L'incidenza dei costi come nel KID di ogni posizione del dossier Posizioni (la coerenza con il profilo
/// sta in DerivatiDati, per versione dei dati). Si ricalcola solo quando cambiano le posizioni, il catalogo
/// o il giorno: la vista si ridisegna spesso. Si usa solo dalle schermate (mai dai calcoli che legge Eve).
enum CacheMotoriPosizioni {
    nonisolated(unsafe) private static var ultimeIncidenze: (chiave: Int, valore: [String: IncidenzaCostiKID])?

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
