import Foundation

/// Le tre analisi del dossier Posizioni di un cliente: prova di resistenza, peso dei costi, passaggio generazionale.
struct AnalisiDossier {
    let patrimonio: PatrimonioNelTempo
    let prova: ProvaResistenza
    let costi: AnalisiCosti
    let successione: Successione?
}

extension StatoShell {
    /// Le analisi del dossier, ricalcolate solo quando cambiano i dati, il giorno o la modalità cliente
    /// (DerivatiDati): la vista si ridisegna spesso e le alternative dei costi passano dal motore della sostituzione.
    /// Una per cliente, così due viste su clienti diversi non si rubano il posto.
    func analisiDossier(_ id: String) -> AnalisiDossier {
        let d = derivatiValidi()
        if let v = d.dossier[id] { return v }
        let mie = posizioniCliente(id)
        let c = cliente(id)
        let obiettivi = obiettiviCliente(id)
        let valore = AnalisiDossier(patrimonio: MotorePatrimonio.calcola(mie, obiettivi: obiettivi),
                                    prova: MotoreResistenza.calcola(mie, profilo: c?.profilo),
                                    costi: MotoreCosti.calcola(mie, prodotti: dati.prodotti, cliente: id),
                                    successione: c.map { MotoreSuccessione.calcola(cliente: $0, posizioni: mie) })
        d.dossier[id] = valore
        // L'ultima calcolata resta anche qui (la prova di Eve controlla che la cache ci sia)
        cacheDossier = (versioneDati, valore)
        return valore
    }
}
