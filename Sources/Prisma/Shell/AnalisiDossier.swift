import Foundation

/// Le tre analisi del dossier Posizioni di un cliente: prova di resistenza, peso dei costi, passaggio generazionale.
struct AnalisiDossier {
    let patrimonio: PatrimonioNelTempo
    let prova: ProvaResistenza
    let costi: AnalisiCosti
    let successione: Successione?
}

extension StatoShell {
    /// Le analisi del dossier, ricalcolate solo quando cambiano le posizioni del cliente, il cliente o il catalogo:
    /// la vista si ridisegna a ogni spostamento di finestra e le alternative dei costi passano dal motore della sostituzione.
    func analisiDossier(_ id: String) -> AnalisiDossier {
        let mie = posizioniCliente(id)
        let c = cliente(id)
        var h = Hasher()
        h.combine(id)
        h.combine(mie)
        h.combine(c)
        h.combine(dati.prodotti)
        let obiettivi = obiettiviCliente(id)
        h.combine(obiettivi.map(\.id))
        h.combine(obiettivi.map(\.scadenza))
        h.combine(Calendar.current.startOfDay(for: Date()))
        let chiave = h.finalize()
        if let cache = cacheDossier, cache.chiave == chiave { return cache.valore }
        let valore = AnalisiDossier(patrimonio: MotorePatrimonio.calcola(mie, obiettivi: obiettivi),
                                    prova: MotoreResistenza.calcola(mie, profilo: c?.profilo),
                                    costi: MotoreCosti.calcola(mie, prodotti: dati.prodotti, cliente: id),
                                    successione: c.map { MotoreSuccessione.calcola(cliente: $0, posizioni: mie) })
        cacheDossier = (chiave, valore)
        return valore
    }
}
