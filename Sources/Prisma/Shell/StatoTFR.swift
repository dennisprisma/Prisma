import Foundation

// Lo stato del confronto «TFR in azienda o nel fondo» (giro 6, specifica 11 §5): le ipotesi per cliente stanno
// nell'archivio (`DatiPrisma.confrontiTFR`), il documento si costruisce dalle ipotesi del cliente attivo.
// La console scrive le ipotesi solo dopo una pausa (bozza locale in `SchedaTFR`): qui nessuna cache.

extension StatoShell {
    /// Le ipotesi del TFR del cliente: quelle salvate o quelle ricavate dai suoi dati.
    func ipotesiTFR(_ cliente: String) -> IpotesiTFR {
        if let salvate = dati.confrontiTFR[cliente] { return salvate }
        return IpotesiTFR.dalCliente(self.cliente(cliente), posizioni: posizioniCliente(cliente))
    }

    /// Salva le ipotesi del cliente; uguali a quelle già salvate non scrivono l'archivio.
    func salvaIpotesiTFR(_ cliente: String, _ i: IpotesiTFR) {
        guard !cliente.isEmpty, dati.confrontiTFR[cliente] != i else { return }
        dati.confrontiTFR[cliente] = i
    }

    /// Toglie le ipotesi salvate: si riparte dai dati del cliente.
    func ripartiTFR(_ cliente: String) {
        guard dati.confrontiTFR[cliente] != nil else { return }
        dati.confrontiTFR[cliente] = nil
    }

    /// Prospetto (A4 verticale) o report (A4 orizzontale) del confronto del TFR del cliente attivo.
    /// nil se la retribuzione non è positiva (non c'è niente da confrontare).
    func documentoTFR(report: Bool) -> DocumentoStampabile? {
        let id = clienteAttivoId
        guard let e = MotoreTFR.calcola(ipotesiTFR(id)) else { return nil }
        return DocumentoStampabile(TestiTFR(e, cliente: cliente(id)), report: report)
    }

    /// La posizione previdenza in essere del cliente che riceve già il TFR (`tfrConferito > 0`), se c'è.
    func fondoConTFR(_ cliente: String) -> Posizione? {
        posizioniCliente(cliente).first { $0.stato == .inEssere && $0.regime == .previdenza && ($0.tfrConferito ?? 0) > 0 }
    }
}
