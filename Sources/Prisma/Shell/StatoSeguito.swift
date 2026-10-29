import Foundation

// MARK: - Seguito delle proposte nello stato (giro 3, specifica 5)
// Chiusura dell'esito dopo un appuntamento di proposta o di firma, proposte ferme in cache per ora.
// Le proprietà `richiestaEsito` (StatoShell) e `seguito` (DerivatiDati) le scrive l'integratore.

/// Il modulo dell'esito da mostrare (sheet), con l'app che lo presenta.
struct RichiestaEsito: Identifiable, Equatable {
    let posizioneId: String
    let appuntamentoId: String?
    /// .posizioni (dettaglio e Portafoglio) o .incontri (dopo «Archivia l'incontro»).
    let origine: AppPrisma
    let passo: PassoEsito

    var id: String { posizioneId + "·" + (appuntamentoId ?? "") }
}

extension StatoShell {
    /// La proposta di cui chiedere l'esito per questo appuntamento (nil se non serve).
    func propostaDaChiudere(_ a: Appuntamento) -> Posizione? {
        guard a.stato == .concluso, MotoreSeguitoProposte.tipiConEsito.contains(a.tipo), let pid = a.posizioneId,
              let p = dati.posizioni.first(where: { $0.id == pid }) else { return nil }
        return MotoreSeguitoProposte.richiedeEsito(a, posizione: p) ? p : nil
    }

    /// Appuntamento appena concluso: proposta presentata, attività di ripresa completata, richiesta per Incontri.
    func segnaConclusione(_ appuntamentoId: String, origine: AppPrisma? = nil) {
        guard let a = dati.appuntamenti.first(where: { $0.id == appuntamentoId }), a.stato == .concluso,
              MotoreSeguitoProposte.tipiConEsito.contains(a.tipo), let pid = a.posizioneId,
              let i = dati.posizioni.firstIndex(where: { $0.id == pid }) else { return }
        var p = dati.posizioni[i]
        let ripresa = p.seguito?.attivitaId
        MotoreSeguitoProposte.dopoConclusione(a, posizione: &p)
        if p != dati.posizioni[i] { dati.posizioni[i] = p }
        // L'appuntamento chiude la ripresa: l'attività «Riprendere la proposta…» è fatta
        if let t = ripresa { completaRipresa(t) }
        if origine == .incontri, propostaDaChiudere(a) != nil {
            richiestaEsito = RichiestaEsito(posizioneId: pid, appuntamentoId: a.id, origine: .incontri,
                                            passo: MotoreSeguitoProposte.passoIniziale(a))
        }
    }

    /// Apre il modulo dell'esito nell'app indicata.
    func apriEsito(_ p: Posizione, passo: PassoEsito, origine: AppPrisma, appuntamentoId: String? = nil) {
        richiestaEsito = RichiestaEsito(posizioneId: p.id, appuntamentoId: appuntamentoId, origine: origine, passo: passo)
    }

    /// I dati proposti per passare in essere la proposta (decorrenza, primo valore, versato, scadenza, prima adesione).
    func datiAccettazione(_ p: Posizione, appuntamento: Appuntamento?) -> DatiAccettazione {
        MotoreSeguitoProposte.datiProposti(p, appuntamento: appuntamento, altre: posizioniCliente(p.clienteId), adesso: Date())
    }

    /// Applica l'esito, aggiunge l'attività del rinvio, chiude l'attività di ripresa aperta e mostra l'avviso.
    func chiudiProposta(_ posizioneId: String, _ esito: EsitoScelto, appuntamentoId: String?) {
        guard !solaLettura else {
            mostraAvviso(TestiSeguito.solaLettura)
            return
        }
        guard let i = dati.posizioni.firstIndex(where: { $0.id == posizioneId }) else {
            richiestaEsito = nil
            return
        }
        var p = dati.posizioni[i]
        let ripresa = p.seguito?.attivitaId
        // Scritta direttamente: `salvaPosizione` rifarebbe `registraCambio`
        let nuova = MotoreSeguitoProposte.applica(esito, a: &p, appuntamentoId: appuntamentoId, adesso: Posizione.oggiArrotondato)
        dati.posizioni[i] = p
        if let t = nuova { dati.attivita.append(t) }
        // La ripresa di prima non serve più: accettata, rifiutata o rimandata a un'altra data (c'è l'attività nuova)
        switch esito {
        case .accettata, .rifiutata, .rimandata:
            if let t = ripresa, t != nuova?.id { completaRipresa(t) }
        case .inAttesa:
            break
        }
        richiestaEsito = nil
        mostraAvviso(TestiSeguito.avviso(esito, posizione: p, giorni: dati.impostazioni.giorniSeguitoProposte))
    }

    /// Le proposte ferme, in cache per ora (DerivatiDati): widget, Portafoglio, Prospetto.
    /// In modalità cliente solo quelle del cliente davanti a te.
    var proposteInSospeso: [PropostaInSospeso] {
        let d = derivatiValidi()
        let ora = DerivatiDati.ora()
        if let c = d.seguito, c.ora == ora { return c.valore }
        let v = MotoreSeguitoProposte.inSospeso(posizioni: posizioni, clienti: clienti, appuntamenti: appuntamenti,
                                                attivita: attivita, adesso: Date(),
                                                soglia: dati.impostazioni.giorniSeguitoProposte)
        d.seguito = (ora, v)
        return v
    }

    /// Una telefonata di seguito: tipo «Presentazione di una proposta», collegata alla posizione, il prossimo giorno
    /// lavorativo (come `bozzaRicontatto`). Concluderla chiede di nuovo l'esito. Si completa nel modulo dell'agenda.
    func bozzaSeguito(_ s: PropostaInSospeso, oggi: Date = Date()) -> Appuntamento {
        let cal = Calendar.current
        var giorno = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: oggi)) ?? oggi
        while cal.isDateInWeekend(giorno) { giorno = cal.date(byAdding: .day, value: 1, to: giorno) ?? giorno }
        var a = Appuntamento.nuovo(clienteId: s.cliente.id, giorno: giorno)
        a.titolo = TestiSeguito.titoloSeguito(s.posizione)
        a.tipo = .proposta
        a.luogo = TestiSeguito.luogoSeguito
        a.durataMinuti = 20
        a.canale = s.posizione.canale
        a.posizioneId = s.posizione.id
        a.note = TestiSeguito.noteSeguito(s)
        return a
    }

    /// Segna completata l'attività di ripresa, se è ancora aperta.
    private func completaRipresa(_ id: String) {
        guard let j = dati.attivita.firstIndex(where: { $0.id == id && !$0.completata }) else { return }
        dati.attivita[j].completata = true
    }
}
