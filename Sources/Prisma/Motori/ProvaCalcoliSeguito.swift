import Foundation

/// Prove del seguito delle proposte (giro 3, specifica 5, §7.1): proposte ferme, chiusura dell'appuntamento,
/// dati dell'accettazione, esiti, statistiche e archivio. Chiamate da `ProvaCalcoli.esegui()` dopo
/// `ProvaCalcoliMultiramo`: gli errori si sommano. Date fisse: oggi è il 28 ottobre 2026 (mercoledì, ore 12) e
/// i conti dei giorni attraversano il cambio dell'ora del 25 ottobre.
enum ProvaCalcoliSeguito {
    static func esegui(_ verifica: VerificaCalcoli) {
        sospese(verifica)
        chiusura(verifica)
        accettazione(verifica)
        esiti(verifica)
        archivio(verifica)
    }

    // MARK: - Aiuti

    private static let adesso = AiutiProva.data(2026, 10, 28)

    private static func d(_ anno: Int, _ mese: Int, _ giorno: Int) -> Date { AiutiProva.data(anno, mese, giorno) }

    /// Una data con l'ora (calendario gregoriano, come `AiutiProva.data`).
    private static func alle(_ anno: Int, _ mese: Int, _ giorno: Int, _ ora: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: anno, month: mese, day: giorno, hour: ora)) ?? Date()
    }

    private static func uguali(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return abs(a.timeIntervalSince(b)) < 1
    }

    private static let cliente = Cliente(id: "c1", nome: "Giulia Prova", iniziali: "GP", tinta: .blu, tema: "", email: "",
                                         telefono: "", preferito: false, nota: "", creatoIl: AiutiProva.data(2020, 1, 1))

    /// Una proposta di previdenza del cliente di prova (PIP, Alleanza), presentata di partenza.
    private static func proposta(_ id: String = "p1", esito: EsitoProposta? = .presentata,
                                 _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        var p = Posizione(id: id, clienteId: "c1", canale: .alleanza, stato: .proposta, area: .previdenza,
                          nome: "Piano previdenziale integrativo")
        p.tipologia = "PIP"
        p.esito = esito
        p.creataIl = AiutiProva.data(2026, 10, 20)
        modifica(&p)
        return p
    }

    private static func presentataIl(_ data: Date) -> SeguitoProposta {
        var s = SeguitoProposta()
        s.presentataIl = data
        return s
    }

    private static func appuntamento(_ id: String, _ inizio: Date, stato: Appuntamento.Stato = .pianificato,
                                     tipo: TipoAppuntamento = .proposta, posizione: String? = nil) -> Appuntamento {
        Appuntamento(id: id, clienteId: "c1", titolo: "Prova", inizio: inizio, durataMinuti: 45, luogo: "", note: "",
                     stato: stato, tipo: tipo, posizioneId: posizione)
    }

    private static func attivita(_ id: String, completata: Bool) -> Attivita {
        Attivita(id: id, clienteId: "c1", titolo: "Riprendere la proposta", scadenza: d(2026, 10, 20), priorita: .normale,
                 completata: completata)
    }

    private static func ferme(_ posizioni: [Posizione], appuntamenti: [Appuntamento] = [], attivita: [Attivita] = [],
                              soglia: Int = 21) -> [PropostaInSospeso] {
        MotoreSeguitoProposte.inSospeso(posizioni: posizioni, clienti: [cliente], appuntamenti: appuntamenti,
                                        attivita: attivita, adesso: adesso, soglia: soglia)
    }

    // MARK: - S1–S15: proposte ferme

    private static func sospese(_ verifica: VerificaCalcoli) {
        let p2 = proposta { $0.seguito = presentataIl(d(2026, 10, 6)) }

        // S1. Presentata il 7/10: 21 giorni, non bastano
        verifica.vero("S1 Seguito: presentata da 21 giorni non è ferma", ferme([proposta { $0.seguito = presentataIl(d(2026, 10, 7)) }]).isEmpty)

        // S2. Presentata il 6/10: 22 giorni di calendario (attraversa il 25/10)
        let f2 = ferme([p2])
        verifica("S2 Seguito: presentata il 6/10 è ferma da 22 giorni", Double(f2.first?.giorni ?? -1), 22)
        verifica.vero("S2 Seguito: contata dalla presentazione", f2.first?.fonte == .presentazione && f2.first?.motivo == .senzaRisposta)

        // S3–S6. Appuntamenti futuri del cliente
        let futuro = alle(2026, 10, 30, 10)
        verifica.vero("S3 Seguito: appuntamento futuro non collegato la toglie",
                      ferme([p2], appuntamenti: [appuntamento("a3", futuro)]).isEmpty)
        verifica("S4 Seguito: appuntamento futuro per un'altra posizione non vale",
                 Double(ferme([p2], appuntamenti: [appuntamento("a4", futuro, posizione: "p9")]).count), 1)
        verifica.vero("S5 Seguito: appuntamento futuro sulla stessa proposta la toglie",
                      ferme([p2], appuntamenti: [appuntamento("a5", futuro, posizione: "p1")]).isEmpty)
        verifica("S6 Seguito: appuntamento futuro già concluso non vale",
                 Double(ferme([p2], appuntamenti: [appuntamento("a6", futuro, stato: .concluso)]).count), 1)

        // S7. Telefonata passata collegata il 20/10: si conta da lì (8 giorni)
        let telefonata = appuntamento("a7", d(2026, 10, 20), stato: .concluso, tipo: .telefonata, posizione: "p1")
        verifica.vero("S7 Seguito: ultimo contatto collegato del 20/10, non ferma", ferme([p2], appuntamenti: [telefonata]).isEmpty)
        let rif = MotoreSeguitoProposte.riferimento(p2, passatiCollegati: [telefonata])
        verifica.vero("S7 Seguito: riferimento all'ultimo contatto", uguali(rif.data, d(2026, 10, 20)) && rif.fonte == .ultimoContatto)
        verifica("S7 Seguito: 8 giorni dall'ultimo contatto", Double(MotoreSeguitoProposte.giorni(da: rif.data, a: adesso)), 8)

        // S8. Senza seguito: dall'inserimento
        let f8 = ferme([proposta { $0.creataIl = d(2026, 9, 1) }])
        verifica("S8 Seguito: inserita il 1/9, ferma da 57 giorni", Double(f8.first?.giorni ?? -1), 57)
        verifica.vero("S8 Seguito: contata dall'inserimento", f8.first?.fonte == .creazione)

        // S9. Bozze, accettate, rifiutate e posizioni in essere non entrano mai
        let vecchia = d(2026, 1, 1)
        let mai = [proposta("b", esito: .bozza) { $0.creataIl = vecchia },
                   proposta("c", esito: .accettata) { $0.creataIl = vecchia },
                   proposta("r", esito: .rifiutata) { $0.creataIl = vecchia },
                   proposta("e") { $0.creataIl = vecchia; $0.stato = .inEssere }]
        verifica.vero("S9 Seguito: bozze, accettate, rifiutate e in essere mai ferme", ferme(mai).isEmpty)

        // S10. Soglia di 30 giorni
        verifica.vero("S10 Seguito: con 30 giorni la presentata da 22 non è ferma", ferme([p2], soglia: 30).isEmpty)

        // S11–S13. Rimandate
        func rimandata(_ ripresa: Date, attivita id: String? = nil) -> Posizione {
            proposta(esito: .rimandata) {
                var s = SeguitoProposta()
                s.riprendereIl = ripresa
                s.attivitaId = id
                $0.seguito = s
                $0.creataIl = vecchia
            }
        }
        verifica.vero("S11 Seguito: rimandata al 15/11 non è ancora da riprendere", ferme([rimandata(d(2026, 11, 15))]).isEmpty)
        let r12 = rimandata(d(2026, 10, 20), attivita: "t1")
        verifica.vero("S12 Seguito: la ricorda l'attività aperta", ferme([r12], attivita: [attivita("t1", completata: false)]).isEmpty)
        let f13 = ferme([r12], attivita: [attivita("t1", completata: true)])
        verifica("S13 Seguito: attività completata, da riprendere da 8 giorni", Double(f13.first?.giorni ?? -1), 8)
        verifica.vero("S13 Seguito: motivo e fonte della ripresa", f13.first?.motivo == .daRiprendere && f13.first?.fonte == .ripresa)

        // S14. Urgente oltre il doppio della soglia
        let p57 = proposta("p57") { $0.seguito = presentataIl(d(2026, 9, 1)) }
        verifica.vero("S14 Seguito: 57 giorni con soglia 21 è urgente", ferme([p57]).first?.urgente == true)
        verifica.vero("S14 Seguito: 22 giorni non è urgente", f2.first?.urgente == false)

        // S15. Dalla più ferma
        let ordine = ferme([rimandata(d(2026, 10, 20), attivita: "t1"), p2, p57], attivita: [attivita("t1", completata: true)])
        verifica.vero("S15 Seguito: ordine 57, 22, 8", ordine.map(\.giorni) == [57, 22, 8])
    }

    // MARK: - S16–S27: chiusura dell'appuntamento e modifiche a mano

    private static func chiusura(_ verifica: VerificaCalcoli) {
        let presentata = proposta()
        let concluso = appuntamento("a1", alle(2026, 10, 27, 15), stato: .concluso, posizione: "p1")

        // S16–S18. Quando chiedere l'esito
        verifica.vero("S16 Seguito: proposta conclusa e collegata chiede l'esito",
                      MotoreSeguitoProposte.richiedeEsito(concluso, posizione: presentata))
        var revisione = concluso
        revisione.tipo = .revisione
        var pianificato = concluso
        pianificato.stato = .pianificato
        let inEssere = proposta { $0.stato = .inEssere }
        let rifiutata = proposta(esito: .rifiutata)
        let giaChiesto = proposta { s in
            var x = SeguitoProposta()
            x.appuntamentoEsitoId = "a1"
            s.seguito = x
        }
        let falsi = [MotoreSeguitoProposte.richiedeEsito(revisione, posizione: presentata),
                     MotoreSeguitoProposte.richiedeEsito(pianificato, posizione: presentata),
                     MotoreSeguitoProposte.richiedeEsito(concluso, posizione: inEssere),
                     MotoreSeguitoProposte.richiedeEsito(concluso, posizione: rifiutata),
                     MotoreSeguitoProposte.richiedeEsito(concluso, posizione: giaChiesto)]
        verifica("S17 Seguito: revisione, pianificato, in essere, rifiutata, già chiesto: nessuna richiesta",
                 Double(falsi.filter { $0 }.count), 0)
        verifica.vero("S18 Seguito: una rimandata chiede l'esito",
                      MotoreSeguitoProposte.richiedeEsito(concluso, posizione: proposta(esito: .rimandata)))

        // S19–S22. Dopo la conclusione
        var bozza = proposta(esito: .bozza)
        MotoreSeguitoProposte.dopoConclusione(concluso, posizione: &bozza)
        verifica.vero("S19 Seguito: la bozza diventa presentata",
                      bozza.esito == .presentata && uguali(bozza.seguito?.presentataIl, alle(2026, 10, 27, 15)))
        MotoreSeguitoProposte.dopoConclusione(appuntamento("a20", d(2026, 11, 3), stato: .concluso, posizione: "p1"), posizione: &bozza)
        verifica.vero("S20 Seguito: un appuntamento dopo sposta la presentazione", uguali(bozza.seguito?.presentataIl, d(2026, 11, 3)))
        MotoreSeguitoProposte.dopoConclusione(appuntamento("a20b", d(2026, 10, 1), stato: .concluso, posizione: "p1"), posizione: &bozza)
        verifica.vero("S20 Seguito: uno prima non la sposta indietro", uguali(bozza.seguito?.presentataIl, d(2026, 11, 3)))
        var rimandata = proposta(esito: .rimandata) { p in
            var s = SeguitoProposta()
            s.riprendereIl = d(2026, 10, 20)
            p.seguito = s
        }
        MotoreSeguitoProposte.dopoConclusione(concluso, posizione: &rimandata)
        verifica.vero("S21 Seguito: la rimandata ripresentata", rimandata.esito == .presentata && rimandata.seguito?.riprendereIl == nil)
        var invariata = proposta(esito: .bozza)
        let prima = invariata
        MotoreSeguitoProposte.dopoConclusione(appuntamento("a22", d(2026, 10, 27), stato: .concluso, tipo: .telefonata, posizione: "p1"),
                                              posizione: &invariata)
        verifica.vero("S22 Seguito: una telefonata non cambia la proposta", invariata == prima)

        // S23–S27. Modifiche a mano (registraCambio)
        let ora = adesso
        var s23 = proposta(esito: .presentata)
        MotoreSeguitoProposte.registraCambio(da: proposta(esito: .bozza), a: &s23, adesso: ora)
        verifica.vero("S23 Seguito: da bozza a presentata segna la presentazione", uguali(s23.seguito?.presentataIl, ora))
        let x = d(2026, 9, 15)
        let conData = proposta { $0.seguito = presentataIl(x) }
        var s24 = conData
        MotoreSeguitoProposte.registraCambio(da: conData, a: &s24, adesso: ora)
        verifica.vero("S24 Seguito: resta presentata, la data non cambia", uguali(s24.seguito?.presentataIl, x))
        var s25 = conData
        s25.esito = .rifiutata
        MotoreSeguitoProposte.registraCambio(da: conData, a: &s25, adesso: ora)
        verifica.vero("S25 Seguito: rifiutata a mano segna la data dell'esito", uguali(s25.seguito?.esitoIl, ora))
        var s26 = proposta(esito: .presentata)
        MotoreSeguitoProposte.registraCambio(da: nil, a: &s26, adesso: ora)
        verifica.vero("S26 Seguito: una proposta nuova già presentata", uguali(s26.seguito?.presentataIl, ora))
        var s27 = proposta(esito: .bozza)
        MotoreSeguitoProposte.registraCambio(da: proposta(esito: .bozza), a: &s27, adesso: ora)
        verifica.vero("S27 Seguito: da bozza a bozza nessun seguito", s27.seguito == nil)
    }

    // MARK: - S28–S45: dati dell'accettazione

    private static func accettazione(_ verifica: VerificaCalcoli) {
        func proposti(_ p: Posizione, appuntamento: Appuntamento? = nil, altre: [Posizione] = []) -> DatiAccettazione {
            MotoreSeguitoProposte.datiProposti(p, appuntamento: appuntamento, altre: altre, adesso: adesso)
        }
        // S28–S31. Versato e primo valore
        let pip = proposta { $0.premio = 200; $0.frequenza = .mensile; $0.costoIngresso = 2 }
        verifica("S28 Seguito: PIP, versato il primo premio mensile", proposti(pip).versato ?? -1, 200)
        verifica("S28 Seguito: PIP, primo valore senza il 2% d'ingresso", proposti(pip).primoValore ?? -1, 196)
        let unico = proposta { $0.area = .investimento; $0.versamentoIniziale = 50_000; $0.costoIngresso = 1.5 }
        verifica("S29 Seguito: premio unico 50.000, versato", proposti(unico).versato ?? -1, 50_000)
        verifica("S29 Seguito: premio unico, primo valore senza l'1,5%", proposti(unico).primoValore ?? -1, 49_250)
        let senzaCosti = proposta { $0.area = .investimento; $0.versamentoIniziale = 10_000 }
        verifica("S30 Seguito: senza costo d'ingresso il primo valore è il versato", proposti(senzaCosti).primoValore ?? -1, 10_000)
        let tcm = proposta { $0.area = .protezione; $0.rischio = .vita; $0.premio = 14; $0.frequenza = .mensile }
        verifica("S31 Seguito: TCM, versato il premio mensile", proposti(tcm).versato ?? -1, 14)
        verifica.vero("S31 Seguito: TCM senza primo valore", proposti(tcm).primoValore == nil)

        // S32–S34. Decorrenza proposta
        verifica.vero("S32 Seguito: decorrenza della proposta tra un anno fa e un mese avanti",
                      uguali(proposti(proposta { $0.decorrenza = d(2026, 11, 1) }).decorrenza, d(2026, 11, 1)))
        verifica.vero("S33 Seguito: decorrenza troppo vecchia, il giorno dell'appuntamento a mezzogiorno",
                      uguali(proposti(proposta { $0.decorrenza = d(2024, 1, 1) },
                                      appuntamento: appuntamento("a33", alle(2026, 10, 27, 15))).decorrenza, d(2026, 10, 27)))
        verifica.vero("S34 Seguito: senza niente, oggi a mezzogiorno", uguali(proposti(proposta()).decorrenza, d(2026, 10, 28)))

        // S35–S37. Scadenza spostata: la durata resta
        let s35 = proposta { $0.creataIl = d(2026, 1, 15); $0.scadenza = d(2036, 1, 15) }
        verifica.vero("S35 Seguito: dieci anni dall'inserimento, dal 1/3/2026 al 1/3/2036",
                      uguali(MotoreSeguitoProposte.scadenzaSpostata(s35, decorrenza: d(2026, 3, 1)), d(2036, 3, 1)))
        let s36 = proposta { $0.decorrenza = d(2026, 2, 1); $0.scadenza = d(2046, 2, 1) }
        verifica.vero("S36 Seguito: vent'anni dalla decorrenza, dal 1/3/2026 al 1/3/2046",
                      uguali(MotoreSeguitoProposte.scadenzaSpostata(s36, decorrenza: d(2026, 3, 1)), d(2046, 3, 1)))
        verifica.vero("S37 Seguito: senza scadenza nessuna scadenza",
                      MotoreSeguitoProposte.scadenzaSpostata(proposta(), decorrenza: d(2026, 3, 1)) == nil)

        // S38–S39. Prima adesione: anche gli anni maturati in un'altra forma
        let altra = proposta("fondo") { $0.stato = .inEssere; $0.esito = nil; $0.primaAdesione = d(2008, 3, 1) }
        verifica.vero("S38 Seguito: prima adesione dall'altra previdenza in essere",
                      uguali(proposti(pip, altre: [altra, pip]).primaAdesione, d(2008, 3, 1)))
        let senzaAltre = proposti(pip)
        verifica.vero("S39 Seguito: senza altre forme, la decorrenza", uguali(senzaAltre.primaAdesione, senzaAltre.decorrenza))

        // S40–S45. Controlli
        func dati(_ decorrenza: Date, primo: Double? = 196, versato: Double? = 200, scadenza: Date? = nil) -> DatiAccettazione {
            DatiAccettazione(decorrenza: decorrenza, primoValore: primo, versato: versato, scadenza: scadenza)
        }
        func avvisi(_ x: DatiAccettazione) -> [AvvisoEsito] { MotoreSeguitoProposte.verifica(x, posizione: pip, adesso: adesso) }
        verifica("S40 Seguito: decorrenza tra 31 giorni, nessun blocco", Double(avvisi(dati(d(2026, 11, 28))).filter(\.bloccante).count), 0)
        verifica("S41 Seguito: decorrenza tra 32 giorni, un blocco", Double(avvisi(dati(d(2026, 11, 29))).filter(\.bloccante).count), 1)
        verifica.vero("S42 Seguito: scadenza uguale alla decorrenza blocca",
                      avvisi(dati(d(2026, 11, 1), scadenza: d(2026, 11, 1))).contains { $0.bloccante && $0.testo == TestiSeguito.avvisoScadenza })
        verifica.vero("S43 Seguito: primo valore negativo blocca",
                      avvisi(dati(d(2026, 11, 1), primo: -1)).contains { $0.bloccante && $0.testo == TestiSeguito.avvisoNegativi })
        let vecchia = avvisi(dati(d(2025, 6, 1)))
        verifica.vero("S44 Seguito: decorrenza di più di un anno fa, un avviso che non blocca",
                      vecchia.count == 1 && vecchia.first?.bloccante == false && vecchia.first?.testo == TestiSeguito.avvisoDecorrenzaVecchia)
        let scarto = avvisi(dati(d(2026, 11, 1), primo: 150))
        verifica.vero("S45 Seguito: primo valore lontano dal versato, avviso che non blocca",
                      scarto.count == 1 && scarto.first?.bloccante == false && scarto.first?.testo == TestiSeguito.avvisoScarto)
        verifica("S45 Seguito: primo valore 196 su 200, nessun avviso", Double(avvisi(dati(d(2026, 11, 1))).count), 0)
    }

    // MARK: - S46–S53: esiti, recesso, statistiche

    private static func esiti(_ verifica: VerificaCalcoli) {
        // S46. Accettata: i valori veri
        var pip = proposta { $0.premio = 200; $0.frequenza = .mensile }
        let accettata = DatiAccettazione(decorrenza: d(2026, 11, 1), primoValore: 196, versato: 200, scadenza: d(2056, 11, 1),
                                         primaAdesione: d(2026, 11, 1))
        let t46 = MotoreSeguitoProposte.applica(.accettata(accettata), a: &pip, appuntamentoId: "a1", adesso: adesso)
        verifica.vero("S46 Seguito: accettata in essere", pip.stato == .inEssere && pip.esito == .accettata && t46 == nil)
        verifica("S46 Seguito: controvalore al primo valore", pip.controvalore ?? -1, 196)
        verifica("S46 Seguito: versato", pip.totaleVersato ?? -1, 200)
        verifica.vero("S46 Seguito: data del valore e prima adesione",
                      uguali(pip.dataValore, d(2026, 11, 1)) && uguali(pip.primaAdesione, d(2026, 11, 1)) && uguali(pip.decorrenza, d(2026, 11, 1)))
        verifica.vero("S46 Seguito: data dell'esito e appuntamento", uguali(pip.seguito?.esitoIl, adesso) && pip.seguito?.appuntamentoEsitoId == "a1")
        verifica.vero("S46 Seguito: nessuno storico inventato", pip.rilevazioni == nil)

        // S47. TCM: il controvalore resta
        var tcm = proposta { $0.area = .protezione; $0.rischio = .vita; $0.controvalore = 0; $0.premio = 14; $0.frequenza = .mensile }
        _ = MotoreSeguitoProposte.applica(.accettata(DatiAccettazione(decorrenza: d(2026, 11, 1), primoValore: nil, versato: 14)),
                                          a: &tcm, appuntamentoId: nil, adesso: adesso)
        verifica("S47 Seguito: TCM, controvalore invariato", tcm.controvalore ?? -1, 0)
        verifica("S47 Seguito: TCM, primo premio versato", tcm.totaleVersato ?? -1, 14)

        // S48. Rifiutata
        var rif = proposta()
        _ = MotoreSeguitoProposte.applica(.rifiutata(motivo: .costo, nota: "caro"), a: &rif, appuntamentoId: nil, adesso: adesso)
        verifica.vero("S48 Seguito: rifiutata resta proposta con motivo e nota",
                      rif.stato == .proposta && rif.esito == .rifiutata && rif.seguito?.motivo == .costo && rif.seguito?.nota == "caro")

        // S49. Rimandata: l'attività della ripresa
        var rim = proposta()
        let t49 = MotoreSeguitoProposte.applica(.rimandata(al: d(2027, 1, 28), motivo: .tempi, nota: ""), a: &rim,
                                                appuntamentoId: nil, adesso: adesso)
        verifica.vero("S49 Seguito: attività «Riprendere la proposta»",
                      t49?.titolo == "Riprendere la proposta «Piano previdenziale integrativo»" && t49?.clienteId == "c1"
                          && t49?.scadenza == Calendar.current.startOfDay(for: d(2027, 1, 28)))
        verifica.vero("S49 Seguito: rimandata con la ripresa a mezzogiorno",
                      rim.esito == .rimandata && rim.seguito?.attivitaId == t49?.id && t49 != nil
                          && uguali(rim.seguito?.riprendereIl, d(2027, 1, 28)) && rim.seguito?.motivo == .tempi)

        // S50. Ci deve pensare
        var attesa = proposta(esito: .bozza)
        _ = MotoreSeguitoProposte.applica(.inAttesa, a: &attesa, appuntamentoId: "a2", adesso: adesso)
        let a2 = appuntamento("a2", d(2026, 10, 27), stato: .concluso, posizione: "p1")
        verifica.vero("S50 Seguito: in attesa resta presentata e non si richiede",
                      attesa.esito == .presentata && uguali(attesa.seguito?.presentataIl, adesso)
                          && !MotoreSeguitoProposte.richiedeEsito(a2, posizione: attesa))

        // S51–S52. Recesso: polizze vita e PIP sì, fondi e danni no
        let polizza = AiutiProva.posizione("Polizza", .investimento, 10_000) { $0.regimeFiscale = .polizza }
        verifica.vero("S51 Seguito: recesso dalla polizza fino al 27/11",
                      uguali(MotoreSeguitoProposte.fineRecesso(polizza, firma: adesso), d(2026, 11, 27)))
        let etf = AiutiProva.posizione("ETF", .investimento, 10_000) { $0.tipologia = "ETF azionario" }
        let infortuni = AiutiProva.posizione("Infortuni", .protezione, 0) { $0.rischio = .infortuni }
        let tcmVita = AiutiProva.posizione("TCM", .protezione, 0) { $0.rischio = .vita }
        verifica.vero("S52 Seguito: niente recesso per ETF e infortuni",
                      MotoreSeguitoProposte.fineRecesso(etf, firma: adesso) == nil && MotoreSeguitoProposte.fineRecesso(infortuni, firma: adesso) == nil)
        verifica.vero("S52 Seguito: recesso dalla TCM fino al 27/11", uguali(MotoreSeguitoProposte.fineRecesso(tcmVita, firma: adesso), d(2026, 11, 27)))

        // S53. Statistiche
        func conMotivo(_ id: String, _ esito: EsitoProposta, _ m: MotivoEsito) -> Posizione {
            proposta(id, esito: esito) { p in
                var s = SeguitoProposta()
                s.motivo = m
                p.seguito = s
            }
        }
        func decisa(_ id: String, _ esito: EsitoProposta, _ da: Date, _ a: Date) -> Posizione {
            proposta(id, esito: esito) { p in
                var s = SeguitoProposta()
                s.presentataIl = da
                s.esitoIl = a
                p.seguito = s
                if esito == .accettata { p.stato = .inEssere }
            }
        }
        let st = MotoreSeguitoProposte.statistiche([conMotivo("r1", .rifiutata, .costo), conMotivo("r2", .rifiutata, .costo),
                                                    conMotivo("r3", .rifiutata, .tempi), conMotivo("m1", .rimandata, .liquidita),
                                                    decisa("a", .accettata, d(2026, 10, 1), d(2026, 10, 21)),
                                                    decisa("r4", .rifiutata, d(2026, 9, 1), d(2026, 10, 1))])
        let motiviRifiuto: [MotivoEsito] = st.motiviRifiuto.map { $0.motivo }
        let volteRifiuto: [Int] = st.motiviRifiuto.map { $0.volte }
        let motiviRinvio: [MotivoEsito] = st.motiviRinvio.map { $0.motivo }
        let volteRinvio: [Int] = st.motiviRinvio.map { $0.volte }
        verifica.vero("S53 Seguito: rifiutate per costo (2) e tempi (1)", motiviRifiuto == [.costo, .tempi] && volteRifiuto == [2, 1])
        verifica.vero("S53 Seguito: rimandate per liquidità (1)", motiviRinvio == [.liquidita] && volteRinvio == [1])
        verifica("S53 Seguito: 25 giorni in media per decidere", st.giorniMediDecisione ?? -1, 25)
        verifica("S53 Seguito: due proposte decise con le date", Double(st.decise), 2)

        // S54–S55. La rimandata conta tra le aperte; il tasso non cambia
        let base = [AiutiProva.posizione("In essere", .investimento, 10_000) { $0.esito = .accettata },
                    proposta("r5", esito: .rifiutata)]
        let conRimandata = base + [proposta("m2", esito: .rimandata)]
        let pBase = MotorePortafoglio.calcola(base, clienti: [cliente], oggi: adesso)
        let pRim = MotorePortafoglio.calcola(conRimandata, clienti: [cliente], oggi: adesso)
        verifica("S54 Seguito: una rimandata nel Portafoglio", Double(pRim.esiti[.rimandata] ?? 0), 1)
        verifica("S54 Seguito: tasso di accettazione invariato", pRim.tassoAccettazione ?? -1, pBase.tassoAccettazione ?? -2)
        verifica("S55 Seguito: la rimandata è una proposta aperta",
                 Double(RiepilogoPosizioni(conRimandata).proposteAperte - RiepilogoPosizioni(base).proposteAperte), 1)
    }

    // MARK: - S56–S59: archivio

    private static func archivio(_ verifica: VerificaCalcoli) {
        let p = proposta()
        let grezzo = (try? Archivio.codificatore.encode(p)).flatMap { try? JSONSerialization.jsonObject(with: $0) }
        var oggetto: [String: Any] = (grezzo as? [String: Any]) ?? [:]
        func leggi() -> Posizione? {
            (try? JSONSerialization.data(withJSONObject: oggetto)).flatMap { try? Archivio.decodificatore.decode(Posizione.self, from: $0) }
        }
        let senza = leggi()
        verifica.vero("S56 Seguito: posizione senza seguito letta", senza != nil && senza?.seguito == nil)
        oggetto["seguito"] = ["motivo": "boh", "nota": "x"]
        let malformato = leggi()
        verifica.vero("S57 Seguito: motivo sconosciuto ignorato, nota conservata",
                      malformato != nil && malformato?.seguito?.motivo == nil && malformato?.seguito?.nota == "x")
        oggetto["seguito"] = 5
        let numero = leggi()
        verifica.vero("S58 Seguito: seguito illeggibile non scarta la posizione",
                      numero?.nome == p.nome && (numero?.seguito == nil || numero?.seguito?.vuoto == true))

        // S59. Giorni del seguito nelle impostazioni
        let impostazioni = (try? Archivio.codificatore.encode(Impostazioni())).flatMap { try? JSONSerialization.jsonObject(with: $0) }
        var imp: [String: Any] = (impostazioni as? [String: Any]) ?? [:]
        func giorni() -> Int {
            ((try? JSONSerialization.data(withJSONObject: imp)).flatMap { try? Archivio.decodificatore.decode(Impostazioni.self, from: $0) })?
                .giorniSeguitoProposte ?? -1
        }
        imp["giorniSeguitoProposte"] = 17
        verifica("S59 Seguito: 17 giorni non è una scelta, torna a 21", Double(giorni()), 21)
        imp.removeValue(forKey: "giorniSeguitoProposte")
        verifica("S59 Seguito: senza la chiave, 21", Double(giorni()), 21)
        imp["giorniSeguitoProposte"] = 30
        verifica("S59 Seguito: 30 giorni conservati", Double(giorni()), 30)
    }
}
