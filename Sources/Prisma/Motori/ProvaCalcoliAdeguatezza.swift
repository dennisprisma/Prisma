import Foundation

/// Prove della scheda di adeguatezza (giro 4, specifica 1, §9.1): i sette controlli, il complessivo, i
/// documenti per canale e tipo, la firma, la lettura tollerante, le schede da completare (AD1–AD59).
/// Chiamate da `ProvaCalcoli.esegui()` dopo quelle dei giri 2 e 3: gli errori si sommano.
/// Tutto relativo a `AiutiProva.oggi`; tolleranze 0,01 per le percentuali e 0,5 per gli euro.
enum ProvaCalcoliAdeguatezza {
    static func esegui(_ verifica: VerificaCalcoli) {
        rischio(verifica)
        orizzonte(verifica)
        esperienza(verifica)
        bisogno(verifica)
        liquidita(verifica)
        concentrazione(verifica)
        sostituzione(verifica)
        documentiEFirma(verifica)
        lettura(verifica)
        daCompletare(verifica)
    }

    // MARK: - Dati comuni

    private static let cal = Calendar(identifier: .gregorian)
    private static var oggi: Date { AiutiProva.oggi }

    private static func tra(anni: Int = 0, mesi: Int = 0, giorni: Int = 0) -> Date {
        cal.date(byAdding: DateComponents(year: anni, month: mesi, day: giorni), to: oggi) ?? oggi
    }

    /// Cliente di 50 anni, propensione moderata (SRI fino a 3), orizzonte 10 anni, 30.000 € netti l'anno;
    /// esperto di fondi, non conosce il Ramo I, capacità di perdita media; casa importante, salute bassa.
    private static func cliente(_ modifica: (inout Cliente) -> Void = { _ in }) -> Cliente {
        var c = Cliente(id: "prova", nome: "Cliente di prova", iniziali: "CP", tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: AiutiProva.data(2020, 1, 1))
        c.dataNascita = tra(anni: -50)
        c.profilo.propensione = .moderata
        c.profilo.orizzonteAnni = 10
        c.profilo.redditoNettoAnnuo = 30_000
        var e = EsperienzaProdotti()
        e.imposta(VoceEsperienza(tipo: .fondiETF, conosce: true, haAvuto: true, haCapito: true))
        e.imposta(VoceEsperienza(tipo: .ramoI, conosce: false))
        e.capacitaPerdite = .media
        c.profilo.esperienzaProdotti = e
        var b = ProfiloBisogni()
        b.imposta(ValutazioneBisogno(area: .casa, importanza: .alta))
        b.imposta(ValutazioneBisogno(area: .salute, importanza: .bassa))
        b.esiti = ["previdenza-assente": true, "liquidita-ferma": false]
        c.bisogni = b
        modifica(&c)
        return c
    }

    private static let rilevati = [
        BisognoRilevato(id: "previdenza-assente", area: .pensione, titolo: "Avviare la previdenza integrativa",
                        motivo: "Nessuna forma di previdenza complementare.", importanza: .alta),
        BisognoRilevato(id: "liquidita-ferma", area: .patrimonio, titolo: "Liquidità ferma",
                        motivo: "Molta liquidità sui conti.", importanza: .media),
    ]

    private static var conto: Posizione {
        AiutiProva.posizione("Conto", .liquidita, 30_000) { $0.id = "conto"; $0.emittente = "Banca" }
    }

    private static var fondo: Posizione {
        AiutiProva.posizione("Fondo comune azionario", .investimento, 20_000) {
            $0.id = "fondo"; $0.tipologia = "Fondo comune azionario"; $0.emittente = "SGR Alfa"; $0.sri = 4
        }
    }

    private static var polizza: Posizione {
        let decorrenza = tra(anni: -2, mesi: -1)
        return AiutiProva.posizione("Polizza rivalutabile", .risparmio, 30_000, canale: .alleanza) {
            $0.id = "polizza"; $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.emittente = "Alleanza Assicurazioni"
            $0.totaleVersato = 28_000; $0.decorrenza = decorrenza; $0.penali = [3, 2, 1]
            $0.minimoGarantito = 1; $0.consolidamento = true; $0.rendimentoAtteso = 3; $0.trattenuto = 1
        }
    }

    /// Riserva di emergenza: 2.000 € al mese per 6 mesi = 12.000 €.
    private static var riserva: IpotesiProtezione {
        var ip = IpotesiProtezione()
        ip.fabbisognoMensile = 2_000
        ip.mesiRiserva = 6
        return ip
    }

    /// L'obiettivo «Auto» fra 12 mesi, 10.000 €, niente da parte.
    private static func auto(collegate: [String] = []) -> Obiettivo {
        var o = Obiettivo(clienteId: "prova", titolo: "Auto", area: .casa, importo: 10_000, scadenza: tra(mesi: 12))
        o.id = "obiettivo-auto"
        o.posizioniCollegate = collegate
        return o
    }

    /// Una proposta presentata del cliente di prova.
    private static func proposta(_ nome: String, _ area: AreaPosizione, canale: Canale = .indipendente,
                                 _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        var p = Posizione(clienteId: "prova", canale: canale, stato: .proposta, area: area, nome: nome)
        p.id = "proposta"
        p.esito = .presentata
        modifica(&p)
        return p
    }

    private static func scheda(_ modifica: (inout SchedaAdeguatezza) -> Void) -> SchedaAdeguatezza {
        var s = SchedaAdeguatezza(posizioneId: "proposta", clienteId: "prova", creataIl: oggi)
        modifica(&s)
        return s
    }

    private static func ingresso(_ p: Posizione, scheda: SchedaAdeguatezza? = nil, cliente c: Cliente? = nil,
                                 posizioni: [Posizione]? = nil, obiettivi: [Obiettivo]? = nil, bisogni: [BisognoRilevato]? = nil,
                                 protezione: IpotesiProtezione? = nil,
                                 voci: [VoceDocumento] = ImpostazioniConsegna.predefinite) -> IngressoAdeguatezza {
        IngressoAdeguatezza(proposta: p, cliente: c ?? cliente(), posizioni: (posizioni ?? [conto, fondo, polizza]) + [p],
                            prodotti: [], obiettivi: obiettivi ?? [auto()], bisogni: bisogni ?? rilevati,
                            protezione: protezione ?? riserva, ipotesiConfermate: true, scheda: scheda, voci: voci, oggi: oggi)
    }

    private static func esito(_ i: IngressoAdeguatezza) -> EsitoAdeguatezza { MotoreAdeguatezza.calcola(i) }

    // Le proposte delle prove

    private static func bilanciato(sri: Int? = 3, _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        proposta("Fondo bilanciato", .investimento) {
            $0.tipologia = "Fondo comune bilanciato"; $0.emittente = "SGR Alfa"; $0.sri = sri
            modifica(&$0)
        }
    }

    private static func ramoI(_ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        proposta("Piano rivalutabile", .risparmio, canale: .alleanza) {
            $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.emittente = "Alleanza Assicurazioni"
            modifica(&$0)
        }
    }

    private static func protezione(_ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        proposta("Temporanea caso morte", .protezione) {
            $0.tipologia = "Temporanea caso morte a capitale costante"; $0.emittente = "Compagnia"
            $0.rischio = .vita; $0.capitaleAssicurato = 100_000; $0.premio = 20; $0.frequenza = .mensile
            modifica(&$0)
        }
    }

    private static func pip(_ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        proposta("Piano pensionistico", .previdenza, canale: .alleanza) {
            $0.tipologia = "Piano individuale pensionistico (PIP)"; $0.emittente = "Alleanza Assicurazioni"
            modifica(&$0)
        }
    }

    private static func semaforo(_ e: EsitoAdeguatezza, _ t: ControlloAdeguatezza.Tipo) -> String {
        e.controllo(t)?.semaforo.rawValue ?? "assente"
    }

    // MARK: - AD1–AD6 · Rischio

    private static func rischio(_ verifica: VerificaCalcoli) {
        let e1 = esito(ingresso(bilanciato()))
        let r1 = e1.controllo(.rischio)
        verifica.vero("AD1 Rischio: SRI 3 con profilo moderato è coerente", r1?.semaforo == .verde)
        verifica("AD1 Rischio: valore 3", r1?.valore ?? -1, 3)
        verifica("AD1 Rischio: soglia 3", r1?.soglia ?? -1, 3)
        verifica.vero("AD1 Rischio: l'esito dice «SRI 3 su 7»", r1?.esito.contains("SRI 3 su 7") == true)

        let r2 = esito(ingresso(bilanciato(sri: 4))).controllo(.rischio)
        verifica.vero("AD2 Rischio: SRI 4 oltre il moderato è da rivedere", r2?.semaforo == .rosso)
        verifica("AD2 Rischio: valore 4", r2?.valore ?? -1, 4)

        let r3 = esito(ingresso(ramoI())).controllo(.rischio)
        verifica.vero("AD3 Rischio: SRI non indicato è da motivare e stimato", r3?.semaforo == .giallo && r3?.stimato == true)
        verifica("AD3 Rischio: SRI stimato 1 per il Ramo I", r3?.valore ?? -1, 1)
        verifica.vero("AD3 Rischio: l'esito dice «stimato»", r3?.esito.contains("stimato") == true)

        let senzaProfilo = cliente { $0.profilo.propensione = nil }
        let r4 = esito(ingresso(bilanciato(), cliente: senzaProfilo)).controllo(.rischio)
        verifica.vero("AD4 Rischio: senza propensione è da completare", r4?.semaforo == .grigio)

        let e5 = esito(ingresso(protezione()))
        verifica.vero("AD5 Rischio: non pertinente per una copertura",
                      e5.controllo(.rischio) == nil && e5.esclusi.contains { $0.tipo == .rischio })

        let multiramo = proposta("Polizza multiramo", .investimento) {
            $0.tipologia = "Polizza multiramo (Ramo I e Ramo III)"; $0.emittente = "Compagnia"
            $0.quotaGestioneSeparata = 40; $0.rendimentoGestione = 3; $0.rendimentoFondi = 5; $0.sri = 3; $0.sriFondi = 5
        }
        let r6 = esito(ingresso(multiramo)).controllo(.rischio)
        verifica.vero("AD6 Rischio: multiramo divisa con SRI della combinazione 3 è coerente", r6?.semaforo == .verde)
        verifica("AD6 Rischio: valore 3", r6?.valore ?? -1, 3)
        verifica.vero("AD6 Rischio: un dettaglio dice «fondi hanno SRI 5»",
                      r6?.dettagli.contains { $0.contains("fondi hanno SRI 5") } == true)
    }

    // MARK: - AD7–AD12 · Orizzonte

    private static func orizzonte(_ verifica: VerificaCalcoli) {
        let o7 = esito(ingresso(bilanciato { $0.periodoRaccomandato = 5 })).controllo(.orizzonte)
        verifica.vero("AD7 Orizzonte: 5 anni entro 10 è coerente", o7?.semaforo == .verde)
        verifica("AD7 Orizzonte: valore 5", o7?.valore ?? -1, 5)
        verifica("AD7 Orizzonte: soglia 10", o7?.soglia ?? -1, 10)

        let o8 = esito(ingresso(bilanciato { $0.periodoRaccomandato = 12 })).controllo(.orizzonte)
        verifica.vero("AD8 Orizzonte: 12 anni oltre 10 è da rivedere", o8?.semaforo == .rosso)

        let scadenza = tra(anni: 15)
        let o9 = esito(ingresso(bilanciato { $0.scadenza = scadenza })).controllo(.orizzonte)
        verifica.vero("AD9 Orizzonte: senza periodo, la durata del contratto è da motivare e stimata",
                      o9?.semaforo == .giallo && o9?.stimato == true)
        verifica("AD9 Orizzonte: durata 15 anni", o9?.valore ?? -1, 15)
        verifica.vero("AD9 Orizzonte: l'esito dice «oltre»", o9?.esito.contains("oltre") == true)

        let senzaOrizzonte = cliente { $0.profilo.orizzonteAnni = nil }
        let o10 = esito(ingresso(bilanciato { $0.periodoRaccomandato = 5 }, cliente: senzaOrizzonte)).controllo(.orizzonte)
        verifica.vero("AD10 Orizzonte: senza orizzonte del cliente è da completare", o10?.semaforo == .grigio)

        let nascita = tra(anni: -64)
        let anziano = cliente { $0.dataNascita = nascita; $0.profilo.lavoro = DatiLavoro(etaPensione: 67) }
        let o11 = esito(ingresso(pip(), cliente: anziano)).controllo(.orizzonte)
        verifica.vero("AD11 Previdenza: 3 anni alla pensione è da motivare", o11?.semaforo == .giallo)
        verifica("AD11 Previdenza: 3 anni di partecipazione", o11?.valore ?? -1, 3)
        verifica("AD11 Previdenza: soglia 5", o11?.soglia ?? -1, 5)

        let adesione = tra(anni: -10)
        let fondoPensione = AiutiProva.posizione("Fondo pensione", .previdenza, 15_000) {
            $0.id = "fondo-pensione"; $0.primaAdesione = adesione
        }
        let o12 = esito(ingresso(pip(), cliente: anziano, posizioni: [conto, fondo, polizza, fondoPensione])).controllo(.orizzonte)
        verifica.vero("AD12 Previdenza: con 10 anni già maturati è coerente", o12?.semaforo == .verde)
        verifica("AD12 Previdenza: 13 anni di partecipazione", o12?.valore ?? -1, 13)
    }

    // MARK: - AD13–AD16 · Esperienza

    private static func esperienza(_ verifica: VerificaCalcoli) {
        let c = cliente()
        let p13 = bilanciato()
        let x13 = esito(ingresso(p13)).controllo(.esperienza)
        let v = MotoreEsperienza.verifica(p13, esperienza: c.profilo.esperienzaProdotti, prodotti: [])
        verifica.vero("AD13 Esperienza: fondi, esperto, entro la capacità è coerente", x13?.semaforo == .verde)
        verifica.vero("AD13 Esperienza: l'esito è quello della specifica 2", v.map { TestiEsperienza.esitoScheda($0) } == x13?.esito)

        let x14 = esito(ingresso(ramoI())).controllo(.esperienza)
        verifica.vero("AD14 Esperienza: Ramo I che non conosce è da rivedere", x14?.semaforo == .rosso)

        let senzaGriglia = cliente { $0.profilo.esperienzaProdotti = nil }
        let x15 = esito(ingresso(bilanciato(), cliente: senzaGriglia)).controllo(.esperienza)
        verifica.vero("AD15 Esperienza: senza griglia è da completare", x15?.semaforo == .grigio)

        let limitata = cliente { $0.profilo.esperienzaProdotti?.capacitaPerdite = .limitata }
        let etf = proposta("ETF azionario globale", .investimento) {
            $0.tipologia = "ETF"; $0.emittente = "Emittente ETF"; $0.quotaAzionaria = 100; $0.sri = 5; $0.versamentoIniziale = 10_000
        }
        let x16 = esito(ingresso(etf, cliente: limitata)).controllo(.esperienza)
        verifica.vero("AD16 Esperienza: ETF azionario oltre la capacità limitata è da rivedere", x16?.semaforo == .rosso)
        verifica.vero("AD16 Esperienza: perdita stimata oltre il 10%", (x16?.valore ?? 0) > 10)
        verifica("AD16 Esperienza: soglia 10", x16?.soglia ?? -1, 10)
    }

    // MARK: - AD17–AD24 · Bisogno

    private static func bisogno(_ verifica: VerificaCalcoli) {
        let b17 = esito(ingresso(pip(), scheda: scheda { $0.collegamento = .rilevato("previdenza-assente") })).controllo(.bisogno)
        verifica.vero("AD17 Bisogno: bisogno confermato è coerente", b17?.semaforo == .verde)
        verifica.vero("AD17 Bisogno: l'esito dice «confermato»", b17?.esito.contains("confermato") == true)

        let b18 = esito(ingresso(pip(), scheda: scheda { $0.collegamento = .rilevato("liquidita-ferma") })).controllo(.bisogno)
        verifica.vero("AD18 Bisogno: bisogno scartato con il cliente è da rivedere", b18?.semaforo == .rosso)

        let b19 = esito(ingresso(ramoI(), scheda: scheda { $0.collegamento = .area(.casa) })).controllo(.bisogno)
        verifica.vero("AD19 Bisogno: area casa importante per il Ramo I è coerente", b19?.semaforo == .verde)

        let b20 = esito(ingresso(protezione(), scheda: scheda { $0.collegamento = .area(.salute) })).controllo(.bisogno)
        verifica.vero("AD20 Bisogno: area salute di importanza bassa è da motivare", b20?.semaforo == .giallo)

        let b21 = esito(ingresso(protezione(), scheda: scheda { $0.collegamento = .area(.pensione) })).controllo(.bisogno)
        verifica.vero("AD21 Bisogno: area pensione per una copertura è da motivare", b21?.semaforo == .giallo)
        verifica.vero("AD21 Bisogno: l'esito dice «non è tra le soluzioni tipiche»",
                      b21?.esito.contains("non è tra le soluzioni tipiche") == true)

        let p22 = ramoI()
        let e22 = esito(ingresso(p22, obiettivi: [auto(collegate: [p22.id])]))
        let b22 = e22.controllo(.bisogno)
        verifica.vero("AD22 Bisogno: obiettivo collegato in Obiettivi è coerente", b22?.semaforo == .verde)
        verifica.vero("AD22 Bisogno: non è un suggerimento", e22.collegamentoSuggerito == false)
        verifica.vero("AD22 Bisogno: l'esito nomina «Auto»", b22?.esito.contains("Auto") == true)

        let e23 = esito(ingresso(pip(), obiettivi: []))
        verifica.vero("AD23 Bisogno: suggerimento da confermare", semaforo(e23, .bisogno) == Semaforo.giallo.rawValue)
        verifica.vero("AD23 Bisogno: suggerisce il bisogno di previdenza",
                      e23.collegamento == .rilevato("previdenza-assente") && e23.collegamentoSuggerito)

        let unitLinked = proposta("Polizza unit linked", .investimento) {
            $0.tipologia = "Polizza unit linked (Ramo III)"; $0.emittente = "Compagnia"; $0.sri = 3
        }
        let senzaBisogni = cliente { $0.bisogni = ProfiloBisogni() }
        let e24 = esito(ingresso(unitLinked, cliente: senzaBisogni, obiettivi: [], bisogni: []))
        verifica.vero("AD24 Bisogno: senza bisogni né obiettivi è da completare",
                      semaforo(e24, .bisogno) == Semaforo.grigio.rawValue && e24.collegamento == nil)
    }

    // MARK: - AD25–AD34 · Liquidità

    private static func liquidita(_ verifica: VerificaCalcoli) {
        // Riserva 12.000, obiettivo vicino 10.000: servono 22.000; il conto ne ha 30.000
        let l25 = esito(ingresso(bilanciato { $0.versamentoIniziale = 5_000 })).controllo(.liquidita)
        verifica.vero("AD25 Liquidità: restano 25.000 € su 22.000 necessari, coerente", l25?.semaforo == .verde)
        verifica("AD25 Liquidità: restano 25.000 €", l25?.valore ?? -1, 25_000, tolleranza: 0.5)
        verifica("AD25 Liquidità: necessari 22.000 €", l25?.soglia ?? -1, 22_000, tolleranza: 0.5)

        let l26 = esito(ingresso(bilanciato { $0.versamentoIniziale = 10_000 })).controllo(.liquidita)
        verifica.vero("AD26 Liquidità: riserva sì, obiettivi no, da motivare", l26?.semaforo == .giallo)
        verifica("AD26 Liquidità: restano 20.000 €", l26?.valore ?? -1, 20_000, tolleranza: 0.5)

        let l27 = esito(ingresso(bilanciato { $0.versamentoIniziale = 25_000 })).controllo(.liquidita)
        verifica.vero("AD27 Liquidità: 5.000 € sotto metà della riserva, da rivedere", l27?.semaforo == .rosso)

        let l28 = esito(ingresso(bilanciato { $0.versamentoIniziale = 35_000 })).controllo(.liquidita)
        verifica.vero("AD28 Liquidità: la liquidità non basta, da rivedere",
                      l28?.semaforo == .rosso && l28?.esito.contains("non basta") == true)

        let l29 = esito(ingresso(bilanciato { $0.versamentoIniziale = 10_000; $0.mesiBloccoRiscatto = 12 })).controllo(.liquidita)
        verifica.vero("AD29 Liquidità: versamento bloccato e liquidità che non basta, da rivedere", l29?.semaforo == .rosso)

        let conSostituita = scheda { $0.posizioneSostituitaId = "polizza" }
        let l30 = esito(ingresso(bilanciato { $0.versamentoIniziale = 25_000 }, scheda: conSostituita)).controllo(.liquidita)
        verifica.vero("AD30 Liquidità: il capitale arriva dalla sostituita, coerente", l30?.semaforo == .verde)
        verifica("AD30 Liquidità: restano 30.000 €", l30?.valore ?? -1, 30_000, tolleranza: 0.5)

        let l31 = esito(ingresso(ramoI { $0.premio = 600; $0.frequenza = .mensile })).controllo(.liquidita)
        verifica.vero("AD31 Liquidità: versamenti al 24% del reddito netto, da motivare", l31?.semaforo == .giallo)
        let l31b = esito(ingresso(ramoI { $0.premio = 1_000; $0.frequenza = .mensile })).controllo(.liquidita)
        verifica.vero("AD31 Liquidità: versamenti al 40% del reddito netto, da rivedere", l31b?.semaforo == .rosso)

        var senzaFabbisogno = riserva
        senzaFabbisogno.fabbisognoMensile = 0
        let l32 = esito(ingresso(protezione(), protezione: senzaFabbisogno)).controllo(.liquidita)
        verifica.vero("AD32 Liquidità: senza fabbisogno mensile è da completare", l32?.semaforo == .grigio)

        let l33 = esito(ingresso(pip { $0.premio = 500; $0.frequenza = .mensile })).controllo(.liquidita)
        verifica.vero("AD33 Liquidità: 700 € oltre il limite deducibile di 5.300 €",
                      l33?.dettagli.contains { $0.contains("700 €") && $0.contains("5.300 €") } == true)

        let l34 = esito(ingresso(bilanciato { $0.versamentoIniziale = 5_000 }, posizioni: [fondo, polizza])).controllo(.liquidita)
        verifica.vero("AD34 Liquidità: senza conti è da completare", l34?.semaforo == .grigio)
    }

    // MARK: - AD35–AD39 · Concentrazione

    private static func concentrazione(_ verifica: VerificaCalcoli) {
        let c35 = esito(ingresso(bilanciato { $0.versamentoIniziale = 30_000 })).controllo(.concentrazione)
        verifica.vero("AD35 Concentrazione: SGR Alfa al 62,5% dopo la firma, da motivare", c35?.semaforo == .giallo)
        verifica("AD35 Concentrazione: 50.000 su 80.000", c35?.valore ?? -1, 62.5)
        verifica.vero("AD35 Concentrazione: un dettaglio dice «Prima 25%»", c35?.dettagli.contains { $0.contains("Prima 25%") } == true)

        let nuoviRisparmi = scheda { $0.fonte = .nuoviRisparmi }
        let c36 = esito(ingresso(bilanciato { $0.versamentoIniziale = 30_000 }, scheda: nuoviRisparmi)).controllo(.concentrazione)
        verifica.vero("AD36 Concentrazione: con nuovi risparmi al 45,45%, coerente", c36?.semaforo == .verde)
        verifica("AD36 Concentrazione: 50.000 su 110.000", c36?.valore ?? -1, 50_000.0 / 110_000 * 100)

        let grande = ramoI { $0.versamentoIniziale = 150_000 }
        let c37 = esito(ingresso(grande, scheda: nuoviRisparmi)).controllo(.concentrazione)
        verifica.vero("AD37 Concentrazione: Alleanza al 78% con 40 punti in più, da rivedere", c37?.semaforo == .rosso)
        verifica("AD37 Concentrazione: 180.000 su 230.000", c37?.valore ?? -1, 180_000.0 / 230_000 * 100)

        let contoPiccolo = AiutiProva.posizione("Conto", .liquidita, 10_000) { $0.id = "conto" }
        let polizzaGrande = AiutiProva.posizione("Polizza rivalutabile", .risparmio, 90_000, canale: .alleanza) {
            $0.id = "polizza"; $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.emittente = "Alleanza Assicurazioni"
        }
        let piano = proposta("Piano Alleanza", .risparmio, canale: .alleanza) {
            $0.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"; $0.premio = 100; $0.frequenza = .mensile
        }
        let c38 = esito(ingresso(piano, posizioni: [contoPiccolo, polizzaGrande])).controllo(.concentrazione)
        verifica.vero("AD38 Concentrazione: già al 90%, la proposta aggiunge poco: da motivare", c38?.semaforo == .giallo)
        verifica("AD38 Concentrazione: 91.200 su 101.200", c38?.valore ?? -1, 91_200.0 / 101_200 * 100)
        verifica.vero("AD38 Concentrazione: un dettaglio sul canale Alleanza",
                      c38?.dettagli.contains { $0.contains("canale Alleanza") } == true)

        let e39 = esito(ingresso(protezione()))
        verifica.vero("AD39 Concentrazione: non pertinente per una copertura",
                      e39.controllo(.concentrazione) == nil && e39.esclusi.contains { $0.tipo == .concentrazione })
    }

    // MARK: - AD40–AD45 · Sostituzione

    private static func sostituzione(_ verifica: VerificaCalcoli) {
        func fondoB(ingresso costoIngresso: Double?, rendimento: Double = 5, costo: Double = 1.2) -> Posizione {
            proposta("Fondo bilanciato", .investimento) {
                $0.tipologia = "Fondo comune bilanciato"; $0.emittente = "SGR Alfa"; $0.sri = 3
                $0.costoIngresso = costoIngresso; $0.rendimentoAtteso = rendimento; $0.costoAnnuo = costo
            }
        }
        let sostituisce = scheda { $0.posizioneSostituitaId = "polizza" }

        let e40 = esito(ingresso(fondoB(ingresso: 2), scheda: sostituisce))
        verifica("AD40 Sostituzione: costi dell'uscita 600 + 580,72", e40.uscita?.costi ?? -1, 1_180.72, tolleranza: 0.5)
        verifica("AD40 Sostituzione: 3,94% del valore", e40.uscita?.percentuale ?? -1, 1_180.72 / 30_000 * 100)
        verifica("AD40 Sostituzione: imposte anticipate 364 €", e40.uscita?.imposteAnticipate ?? -1, 364, tolleranza: 0.5)
        verifica.vero("AD40 Sostituzione: oltre il 3% è da rivedere", semaforo(e40, .sostituzione) == Semaforo.rosso.rawValue)
        verifica("AD40 Sostituzione: tre garanzie perse", Double(e40.uscita?.garanziePerse.count ?? -1), 3)

        let e41 = esito(ingresso(fondoB(ingresso: nil), scheda: sostituisce))
        let s41 = e41.controllo(.sostituzione)
        verifica("AD41 Sostituzione: costi 600 €", e41.uscita?.costi ?? -1, 600, tolleranza: 0.5)
        verifica("AD41 Sostituzione: 2% del valore", e41.uscita?.percentuale ?? -1, 2)
        verifica.vero("AD41 Sostituzione: da motivare", s41?.semaforo == .giallo)
        verifica.vero("AD41 Sostituzione: il cambio recupera nel periodo", e41.uscita?.pareggio != nil)
        verifica.vero("AD41 Sostituzione: un dettaglio sul cambio di canale",
                      s41?.dettagli.contains { $0.contains("Cambio di canale") } == true)

        let s42 = esito(ingresso(fondoB(ingresso: nil, rendimento: 1, costo: 2.5), scheda: sostituisce)).controllo(.sostituzione)
        verifica.vero("AD42 Sostituzione: il cambio non recupera, da rivedere",
                      s42?.semaforo == .rosso && s42?.esito.contains("non recupera") == true)

        let e43 = esito(ingresso(ramoI()))
        verifica.vero("AD43 Sostituzione: senza sostituita non c'è il controllo", e43.controllo(.sostituzione) == nil)
        verifica.vero("AD43 Sostituzione: Prisma suggerisce la polizza", e43.sostituitaSuggerita == "polizza")

        let decorrenza = tra(anni: -5)
        let fondoPensione = AiutiProva.posizione("Fondo pensione", .previdenza, 20_000) {
            $0.id = "fondo-pensione"; $0.decorrenza = decorrenza; $0.totaleVersato = 18_000
        }
        let daPrevidenza = scheda { $0.posizioneSostituitaId = "fondo-pensione" }
        let s44 = esito(ingresso(fondoB(ingresso: nil), scheda: daPrevidenza,
                                 posizioni: [conto, fondo, polizza, fondoPensione])).controllo(.sostituzione)
        verifica.vero("AD44 Sostituzione: riscatto della previdenza, da rivedere",
                      s44?.semaforo == .rosso && s44?.esito.contains("23%") == true)

        let perse = MotoreAdeguatezza.garanziePerse(polizza, fondoB(ingresso: nil), trasferimento: false, data: oggi)
        verifica.vero("AD45 Garanzie perse: capitale garantito, minimo dell'1%, consolidamento",
                      perse == ["il capitale garantito della gestione separata", "il rendimento minimo garantito dell'1% l'anno",
                                "il consolidamento annuo dei rendimenti"])
    }

    // MARK: - AD46–AD53 · Complessivo, documenti, firma

    private static func documentiEFirma(_ verifica: VerificaCalcoli) {
        verifica.vero("AD46 Complessivo: verde, giallo, grigio → grigio", MotoreAdeguatezza.complessivo([.verde, .giallo, .grigio]) == .grigio)
        verifica.vero("AD46 Complessivo: verde, giallo → giallo", MotoreAdeguatezza.complessivo([.verde, .giallo]) == .giallo)
        verifica.vero("AD46 Complessivo: rosso, grigio → rosso", MotoreAdeguatezza.complessivo([.rosso, .grigio]) == .rosso)
        verifica.vero("AD46 Complessivo: nessun controllo → grigio", MotoreAdeguatezza.complessivo([]) == .grigio)

        let voci = ImpostazioniConsegna.predefinite
        // Senza elenco valgono le voci predefinite (niente variabili locali nel valore predefinito del parametro)
        func ids(_ p: Posizione, _ tipo: TipoProdotto?, sostituzione: Bool = false, voci elenco: [VoceDocumento]? = nil) -> [String] {
            MotoreAdeguatezza.documenti(p, voci: elenco ?? voci, tipo: tipo, sostituzione: sostituzione).map(\.id)
        }
        verifica.vero("AD47 Documenti Alleanza, Ramo I",
                      ids(ramoI(), .ramoI) == ["all-allegato3", "all-allegato4ter", "all-allegato4bis", "all-kid", "all-dip-ibip",
                                               "all-condizioni", "all-adeguatezza", "all-esigenze", "all-antiriciclaggio"])
        let protezioneAlleanza = protezione { $0.canale = .alleanza }
        verifica.vero("AD48 Documenti Alleanza, protezione",
                      ids(protezioneAlleanza, .protezione) == ["all-allegato3", "all-allegato4ter", "all-allegato4", "all-dip-protezione",
                                                               "all-condizioni", "all-esigenze"])
        verifica.vero("AD49 Documenti Alleanza, PIP",
                      ids(pip(), .previdenza) == ["all-allegato3", "all-allegato4ter", "all-condizioni", "all-esigenze",
                                                  "all-pip-chiave", "all-pip-pensione", "all-pip-autovalutazione"])
        let conSostituzione = ids(bilanciato(), .fondiETF, sostituzione: true)
        let senzaSostituzione = ids(bilanciato(), .fondiETF)
        verifica.vero("AD50 Documenti indipendente, fondo: 7 con la sostituzione (confronto in fondo), 6 senza",
                      conSostituzione.count == 7 && conSostituzione.last == "ind-confronto" && senzaSostituzione.count == 6)
        verifica.vero("AD51 Documenti indipendente, protezione",
                      ids(protezione(), .protezione) == ["ind-informativa", "ind-contratto", "ind-profilo", "ind-costi", "ind-adeguatezza"])
        let senzaAntiriciclaggio = voci.map { v -> VoceDocumento in
            var x = v
            if x.id == "all-antiriciclaggio" { x.attiva = false }
            return x
        }
        verifica("AD52 Documenti: con l'antiriciclaggio spento il Ramo I Alleanza ne ha 8",
                 Double(ids(ramoI(), .ramoI, voci: senzaAntiriciclaggio).count), 8)

        // AD53: tutto verde e i documenti che decidono se la scheda è pronta
        let beta = proposta("Fondo bilanciato Beta", .investimento) {
            $0.tipologia = "Fondo comune bilanciato"; $0.emittente = "SGR Beta"; $0.sri = 3
            $0.periodoRaccomandato = 5; $0.versamentoIniziale = 5_000
        }
        let documenti = ["ind-informativa", "ind-contratto", "ind-profilo", "ind-costi", "ind-kid", "ind-adeguatezza"]
        var s53 = scheda { $0.collegamento = .area(.casa); $0.fonte = .liquidita }
        s53.consegne = documenti.prefix(5).map { ConsegnaDocumento(voceId: $0, consegnatoIl: oggi) }
        let e53 = esito(ingresso(beta, scheda: s53))
        let tipi: [ControlloAdeguatezza.Tipo] = [.rischio, .orizzonte, .esperienza, .bisogno, .liquidita, .concentrazione]
        verifica.vero("AD53 Tutto coerente: sei controlli verdi",
                      e53.controlli.map(\.tipo) == tipi && e53.controlli.allSatisfy { $0.semaforo == .verde })
        verifica.vero("AD53 Tutto coerente: complessivo verde", e53.complessivo == .verde)
        verifica.vero("AD53 Cinque documenti su sei: non pronta per la firma", e53.pronta == false)
        s53.nonPertinenti = [documenti[5]]
        verifica.vero("AD53 La sesta non pertinente: pronta per la firma", esito(ingresso(beta, scheda: s53)).pronta == true)
    }

    // MARK: - AD54–AD58 · Lettura tollerante

    private static func lettura(_ verifica: VerificaCalcoli) {
        let secondo = Date(timeIntervalSinceReferenceDate: oggi.timeIntervalSinceReferenceDate.rounded(.down))
        var piena = SchedaAdeguatezza(posizioneId: "p", clienteId: "c", creataIl: secondo)
        piena.areaBisogno = .pensione
        piena.posizioneSostituitaId = "s"
        piena.fonte = .altro
        piena.motivazione = "Perché sì"
        piena.consegne = [ConsegnaDocumento(voceId: "all-allegato3", consegnatoIl: secondo)]
        piena.nonPertinenti = ["all-kid"]
        piena.aggiornataIl = secondo
        piena.firmataIl = secondo
        piena.esitiAllaFirma = [EsitoRegistrato(controllo: "rischio", semaforo: "verde", esito: "SRI 2 su 7")]
        let riletta = (try? Archivio.codificatore.encode(piena)).flatMap { try? Archivio.decodificatore.decode(SchedaAdeguatezza.self, from: $0) }
        verifica.vero("AD54 Scheda completa: codificata e riletta uguale", riletta == piena)

        func leggi<V: Decodable>(_ tipo: V.Type, _ json: String) -> V? {
            try? Archivio.decodificatore.decode(V.self, from: Data(json.utf8))
        }
        let minima = leggi(SchedaAdeguatezza.self, #"{"posizioneId":"p","clienteId":"c"}"#)
        verifica.vero("AD55 Scheda con i soli id: si legge con i predefiniti",
                      minima != nil && minima?.consegne.isEmpty == true && minima?.firmataIl == nil
                          && minima?.creataIl == Date(timeIntervalSinceReferenceDate: 0))
        let strana = leggi(SchedaAdeguatezza.self, #"{"posizioneId":"p","clienteId":"c","fonte":"lotteria","areaBisogno":"luna"}"#)
        verifica.vero("AD56 Fonte e area sconosciute: si legge con nil",
                      strana != nil && strana?.fonte == nil && strana?.areaBisogno == nil)

        let buona = #"{"id":"v","canale":"alleanza","titolo":"Documento"}"#
        let cattiva = #"{"id":"x","canale":"alleanza","titolo":"X","perTipo":"ramoX"}"#
        let unaSola = leggi(ImpostazioniConsegna.self, "{\"voci\":[\(buona),\(cattiva)]}")
        verifica("AD57 Elenco con una voce illeggibile: resta quella buona", Double(unaSola?.voci.count ?? -1), 1)
        verifica("AD57 Elenco senza chiave: le 23 voci di Prisma", Double(leggi(ImpostazioniConsegna.self, "{}")?.voci.count ?? -1), 23)
        verifica("AD57 Elenco vuoto: resta vuoto", Double(leggi(ImpostazioniConsegna.self, #"{"voci":[]}"#)?.voci.count ?? -1), 0)

        // Archivio con una scheda buona e una senza `posizioneId`
        var oggetto: [String: Any] = ["clienti": [Any](), "clienteAttivoId": ""]
        if let dati = try? Archivio.codificatore.encode(piena),
           let buonaScheda = (try? JSONSerialization.jsonObject(with: dati)) as? [String: Any] {
            var senzaId = buonaScheda
            senzaId["posizioneId"] = nil
            oggetto["schedeAdeguatezza"] = [buonaScheda, senzaId]
        }
        let archivio = (try? JSONSerialization.data(withJSONObject: oggetto)).flatMap { try? Archivio.decodifica($0) }
        verifica("AD58 Archivio: una scheda letta su due", Double(archivio?.schedeAdeguatezza.count ?? -1), 1)
        let vecchio = leggi(DatiPrisma.self, #"{"clienti":[],"impostazioni":{}}"#)
        verifica.vero("AD58 Archivio senza schede: elenco vuoto", vecchio?.schedeAdeguatezza.isEmpty == true)
        verifica.vero("AD58 Archivio senza elenco dei documenti: quello di Prisma", vecchio?.impostazioni.consegna == ImpostazioniConsegna())
    }

    // MARK: - AD59 · Schede da completare

    private static func daCompletare(_ verifica: VerificaCalcoli) {
        let voci = ImpostazioniConsegna.predefinite.map { v -> VoceDocumento in
            var x = v
            if x.id == "all-antiriciclaggio" { x.attiva = false }
            return x
        }
        // Una proposta accettata (in essere) con la scheda non firmata
        var accettata = ramoI()
        accettata.id = "accettata"
        accettata.stato = .inEssere
        accettata.esito = .accettata
        var sAccettata = SchedaAdeguatezza(posizioneId: "accettata", clienteId: "prova", creataIl: tra(giorni: -10))
        sAccettata.aggiornataIl = tra(giorni: -9)
        // Una proposta presentata con 2 documenti consegnati su 8
        var presentata = ramoI()
        presentata.id = "presentata"
        var sPresentata = SchedaAdeguatezza(posizioneId: "presentata", clienteId: "prova", creataIl: tra(giorni: -3))
        sPresentata.consegne = [ConsegnaDocumento(voceId: "all-allegato3", consegnatoIl: tra(giorni: -3)),
                                ConsegnaDocumento(voceId: "all-kid", consegnatoIl: tra(giorni: -3))]
        // Una firmata e una di una posizione che non c'è più
        var firmata = ramoI()
        firmata.id = "firmata"
        var sFirmata = SchedaAdeguatezza(posizioneId: "firmata", clienteId: "prova", creataIl: tra(giorni: -20))
        sFirmata.firmataIl = tra(giorni: -19)
        let sSparita = SchedaAdeguatezza(posizioneId: "sparita", clienteId: "prova", creataIl: tra(giorni: -30))

        let elenco = MotoreAdeguatezza.daCompletare(schede: [sPresentata, sFirmata, sSparita, sAccettata],
                                                    posizioni: [accettata, presentata, firmata], voci: voci, prodotti: [])
        verifica("AD59 Schede da completare: due", Double(elenco.count), 2)
        verifica.vero("AD59 Prima la più vecchia: la firma della proposta accettata",
                      elenco.first?.posizione.id == "accettata" && elenco.first?.motivo == .firma)
        verifica.vero("AD59 Poi i 6 documenti da consegnare della proposta presentata",
                      elenco.last?.posizione.id == "presentata" && elenco.last?.motivo == .documenti(mancano: 6))
    }
}
