import Foundation

/// Prove dell'esperienza per tipo di prodotto: classificazione, livelli, perdita stimata delle proposte,
/// incoerenze in MotoreCoerenza, suggerimenti, lettura tollerante, dati di prova (X1–X16).
/// Chiamate da `ProvaCalcoli.esegui()` prima del riepilogo: gli errori si sommano.
enum ProvaCalcoliEsperienza {
    static func esegui(_ verifica: VerificaCalcoli) {
        classificazione(verifica)
        livelli(verifica)
        perdite(verifica)
        coerenza(verifica)
        suggerimenti(verifica)
        lettura(verifica)
        datiDiProva(verifica)
    }

    // MARK: - Aiuti

    private static func pos(_ nome: String, _ area: AreaPosizione, _ valore: Double,
                            _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        AiutiProva.posizione(nome, area, valore, modifica)
    }

    /// Una proposta presentata, senza valore attuale: conta il versamento iniziale più un anno di premi.
    private static func proposta(_ nome: String, _ area: AreaPosizione, versamento: Double,
                                 _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        var p = Posizione(clienteId: "prova", canale: .indipendente, stato: .proposta, area: area, nome: nome)
        p.esito = .presentata
        p.controvalore = nil
        p.versamentoIniziale = versamento
        modifica(&p)
        return p
    }

    private static func cliente(_ griglia: EsperienzaProdotti?, propensione: ProfiloInvestitore.Propensione? = nil,
                                orizzonte: Int? = nil) -> Cliente {
        var c = Cliente(id: "prova", nome: "Cliente di prova", iniziali: "CP", tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: AiutiProva.data(2020, 1, 1))
        c.profilo.propensione = propensione
        c.profilo.orizzonteAnni = orizzonte
        c.profilo.esperienzaProdotti = griglia
        return c
    }

    private static func griglia(_ voci: VoceEsperienza..., capacita: CapacitaPerdite? = nil) -> EsperienzaProdotti {
        var e = EsperienzaProdotti()
        for v in voci { e.imposta(v) }
        e.capacitaPerdite = capacita
        return e
    }

    private static func voce(_ t: TipoProdotto, _ conosce: Bool?, _ haAvuto: Bool?, _ haCapito: Bool?) -> VoceEsperienza {
        VoceEsperienza(tipo: t, conosce: conosce, haAvuto: haAvuto, haCapito: haCapito)
    }

    /// Le proposte delle prove X3–X13.
    private static var fondoAzionario: Posizione {
        proposta("Fondo comune azionario", .investimento, versamento: 30_000) { $0.tipologia = "Fondo comune azionario" }
    }
    private static var obbligazionario: Posizione {
        proposta("Fondo comune obbligazionario", .investimento, versamento: 20_000) {
            $0.tipologia = "Fondo comune obbligazionario"; $0.quotaAzionaria = 0; $0.quotaTitoliStato = 100
        }
    }
    private static var multiramo: Posizione {
        proposta("Polizza multiramo", .investimento, versamento: 10_000) {
            $0.tipologia = "Polizza multiramo"; $0.quotaGestioneSeparata = 70; $0.quotaAzionaria = 30; $0.sri = 3
        }
    }
    private static var unitLinked: Posizione {
        proposta("Polizza unit linked", .investimento, versamento: 20_000) {
            $0.tipologia = "Polizza unit linked (Ramo III)"; $0.sri = 3; $0.periodoRaccomandato = 5; $0.emittente = "Compagnia B"
        }
    }
    private static var ramoI: Posizione {
        proposta("Rivalutabile a premi ricorrenti", .risparmio, versamento: 0) {
            $0.tipologia = "Polizza rivalutabile a premi ricorrenti (Ramo I)"; $0.premio = 100; $0.frequenza = .mensile
        }
    }

    // MARK: - X1 · Classificazione

    private static func classificazione(_ verifica: VerificaCalcoli) {
        let casi: [(area: AreaPosizione, tipologia: String, tipo: TipoProdotto, stimata: Bool)] = [
            (.risparmio, "Polizza rivalutabile a premio unico (Ramo I)", .ramoI, false),
            (.investimento, "Polizza unit linked (Ramo III)", .ramoIII, false),
            (.investimento, "Polizza multiramo (Ramo I e Ramo III)", .multiramo, false),
            (.risparmio, "Contratto di capitalizzazione", .ramoI, false),
            (.investimento, "ETF con piano di accumulo", .fondiETF, false),
            (.investimento, "Fondo comune azionario", .fondiETF, false),
            (.investimento, "BTP a tasso fisso", .titoli, false),
            (.investimento, "Azioni Enel", .titoli, false),
            (.investimento, "Gestione patrimoniale", .fondiETF, false),
            (.investimento, "Prodotto strutturato", .fondiETF, true),
            (.previdenza, "Piano individuale pensionistico (PIP)", .previdenza, false),
            (.protezione, "Temporanea caso morte a capitale costante", .protezione, false),
        ]
        for caso in casi {
            let p = pos("Posizione di prova", caso.area, 10_000) { $0.tipologia = caso.tipologia }
            let k = MotoreEsperienza.classifica(p)
            verifica.vero("X1 «\(caso.tipologia)»: \(caso.tipo.nome)\(caso.stimata ? " (stimato)" : "")",
                          k?.tipo == caso.tipo && k?.stimata == caso.stimata)
        }
        let polizzaVita = pos("Posizione di prova", .investimento, 10_000) { $0.tipologia = "Polizza vita"; $0.sri = 4 }
        let kVita = MotoreEsperienza.classifica(polizzaVita)
        verifica.vero("X1 «Polizza vita» con SRI 4: Ramo III stimato", kVita?.tipo == .ramoIII && kVita?.stimata == true)
        for area in [AreaPosizione.liquidita, .immobili, .debiti] {
            verifica.vero("X1 \(area.nome): nessun tipo", MotoreEsperienza.classifica(pos("Posizione di prova", area, 10_000)) == nil)
        }
        let deposito = pos("Posizione di prova", .investimento, 10_000) { $0.regimeFiscale = .deposito }
        verifica.vero("X1 Regime di deposito: nessun tipo", MotoreEsperienza.classifica(deposito) == nil)
        if let scheda = DatiDemo.prodotti().first(where: { $0.id == "prodotto-etf-globale" }) {
            let k = MotoreEsperienza.classifica(prodotto: scheda)
            verifica.vero("X1 Scheda «ETF azionario globale»: fondi ed ETF", k?.tipo == .fondiETF && k?.stimata == false)
            // Una proposta senza tipologia nata dalla scheda si classifica con la scheda
            var daScheda = scheda.proposta(per: "prova")
            daScheda.tipologia = ""
            verifica.vero("X1 Proposta senza tipologia: il tipo della scheda",
                          MotoreEsperienza.classifica(daScheda, prodotti: [scheda])?.tipo == .fondiETF)
        } else {
            verifica.vero("X1 Scheda «prodotto-etf-globale» nei dati di prova", false)
        }
        verifica.vero("X1 Ambiti: IBIP, MiFID, previdenza, protezione",
                      TipoProdotto.ramoI.ambito == .ibip && TipoProdotto.multiramo.ambito == .ibip && TipoProdotto.titoli.ambito == .mifid
                        && TipoProdotto.previdenza.ambito == .previdenza && TipoProdotto.protezione.ambito == .protezione)
    }

    // MARK: - X2 · Livello

    private static func livelli(_ verifica: VerificaCalcoli) {
        let casi: [(Bool?, Bool?, Bool?, LivelloEsperienza)] = [
            (nil, nil, nil, .daChiedere),
            (false, nil, nil, .nonConosce),
            (false, true, nil, .nonConosce),
            (true, nil, false, .daSpiegare),
            (nil, nil, false, .daSpiegare),
            (true, nil, nil, .conosce),
            (nil, true, nil, .conosce),
            (true, false, true, .conosce),
            (true, true, true, .esperto),
        ]
        func testo(_ b: Bool?) -> String { b.map { $0 ? "S" : "N" } ?? "—" }
        for (c, a, h, atteso) in casi {
            verifica.vero("X2 \(testo(c)) \(testo(a)) \(testo(h)): \(atteso.nome)",
                          MotoreEsperienza.livello(voce(.ramoI, c, a, h)) == atteso)
        }
        verifica.vero("X2 Griglia mai compilata: da chiedere", MotoreEsperienza.livello(nil, .ramoI) == .daChiedere)
    }

    // MARK: - X3 · Perdita stimata

    private static func perdite(_ verifica: VerificaCalcoli) {
        let azionario = MotoreEsperienza.perdita(fondoAzionario)
        verifica("X3 Fondo azionario: azioni 100% × −37%", azionario.percento, 37, tolleranza: 0.0001)
        verifica.vero("X3 Fondo azionario: la crisi del 2008", azionario.anno == 2008)
        verifica("X3 Fondo azionario: 11.100 € su 30.000", azionario.euro, 11_100, tolleranza: 0.01)

        let obbligazioni = MotoreEsperienza.perdita(obbligazionario)
        verifica("X3 Obbligazionario in titoli di Stato: −17%", obbligazioni.percento, 17, tolleranza: 0.0001)
        verifica.vero("X3 Obbligazionario: la crisi del 2022", obbligazioni.anno == 2022)

        let mr = MotoreEsperienza.perdita(multiramo)
        verifica("X3 Multiramo 70% GS, 30% azioni: 0,3 × 37", mr.percento, 11.1, tolleranza: 0.0001)
        verifica.vero("X3 Multiramo: la crisi del 2008", mr.anno == 2008)

        let ul = MotoreEsperienza.perdita(unitLinked)
        verifica("X3 Unit linked SRI 3: 0,35 × 33 + 0,325 × 4 + 0,325 × 7", ul.percento, 15.125, tolleranza: 0.0001)
        verifica.vero("X3 Unit linked: la crisi del 2020", ul.anno == 2020)

        let gs = MotoreEsperienza.perdita(ramoI)
        verifica("X3 Ramo I: nessuna perdita", gs.percento, 0, tolleranza: 0.0001)
        verifica.vero("X3 Ramo I: nessuna crisi", gs.anno == nil && gs.titoloCrisi == nil)
        verifica("X3 Ramo I: capitale di un anno di premi", gs.capitale, 1_200, tolleranza: 0.01)
    }

    // MARK: - X4–X13 · Incoerenze in MotoreCoerenza

    private static func coerenza(_ verifica: VerificaCalcoli) {
        let conto80 = pos("Conto", .liquidita, 80_000)
        let ul = unitLinked

        // X4. Non conosce le unit linked: resta solo l'esperienza (rischio, crisi, emittente e orizzonte dentro)
        let x4 = MotoreCoerenza.calcola(cliente: cliente(griglia(voce(.ramoIII, false, nil, nil)), propensione: .moderata, orizzonte: 20),
                                        posizioni: [conto80, ul])
        verifica.vero("X4 Proposta di un tipo che non conosce: solo l'esperienza", x4.incoerenze.map(\.tipo) == [.esperienza])
        let e4 = x4.incoerenze.first
        verifica.vero("X4 Titolo", e4?.titolo == "Proposta di un tipo che non conosce")
        verifica("X4 Valore 0", e4?.valore ?? -1, 0)
        verifica("X4 Soglia 2", e4?.soglia ?? -1, 2)
        verifica.vero("X4 Con le proposte, sulla proposta", e4?.dopoLeProposte == true && e4?.posizione?.id == ul.id)
        verifica.vero("X4 Il dettaglio nomina le unit linked", e4?.dettaglio.contains("le unit linked (Ramo III)") == true)

        // X5. La conosce ma non l'ha capita
        let x5 = MotoreCoerenza.calcola(cliente: cliente(griglia(voce(.ramoIII, true, nil, false)), propensione: .moderata, orizzonte: 20),
                                        posizioni: [conto80, ul])
        verifica.vero("X5 Da spiegare: solo l'esperienza", x5.incoerenze.map(\.tipo) == [.esperienza])
        verifica.vero("X5 Titolo", x5.incoerenze.first?.titolo == "Proposta di un prodotto da spiegare meglio")
        verifica("X5 Valore 1", x5.incoerenze.first?.valore ?? -1, 1)

        // X6. Ne ha esperienza
        let x6 = MotoreCoerenza.calcola(cliente: cliente(griglia(voce(.ramoIII, true, true, true)), propensione: .moderata, orizzonte: 20),
                                        posizioni: [conto80, ul])
        verifica.vero("X6 Esperto: nessuna incoerenza", x6.incoerenze.isEmpty)

        // X7. Griglia compilata senza il tipo proposto: da chiedere, nessuna incoerenza
        let x7 = MotoreCoerenza.calcola(cliente: cliente(griglia(voce(.ramoI, true, true, true)), propensione: .moderata, orizzonte: 20),
                                        posizioni: [conto80, ul])
        verifica.vero("X7 Da chiedere: nessuna incoerenza", x7.incoerenze.isEmpty)
        verifica.vero("X7 Da chiedere: la proposta", x7.esperienza?.daChiedere.map(\.id) == [ul.id])
        verifica.vero("X7 Griglia compilata", x7.esperienza?.compilata == true)

        // X8. Griglia mai compilata
        let x8 = MotoreCoerenza.calcola(cliente: cliente(nil, propensione: .moderata, orizzonte: 20), posizioni: [conto80, ul])
        verifica.vero("X8 Senza griglia: nessuna incoerenza", x8.incoerenze.isEmpty)
        verifica.vero("X8 Senza griglia: non compilata", x8.esperienza?.compilata == false)
        verifica("X8 Senza griglia: la proposta si verifica lo stesso", Double(x8.esperienza?.verifiche.count ?? -1), 1)

        // X9. Proposta rifiutata: non si controlla
        var rifiutata = ul
        rifiutata.esito = .rifiutata
        let x9 = MotoreCoerenza.calcola(cliente: cliente(griglia(voce(.ramoIII, false, nil, nil)), propensione: .moderata, orizzonte: 20),
                                        posizioni: [conto80, rifiutata])
        verifica.vero("X9 Rifiutata: nessuna verifica né incoerenza",
                      x9.esperienza?.verifiche.isEmpty == true && x9.incoerenze.isEmpty)

        // X10. Perdite: fondo azionario da 30.000 € (−37% nel 2008) con un conto da 70.000 €
        let conto70 = pos("Conto", .liquidita, 70_000)
        var azionario = fondoAzionario
        azionario.sri = 6
        azionario.emittente = "SGR Uno"
        func conCapacita(_ capacita: CapacitaPerdite) -> EsitoCoerenza {
            MotoreCoerenza.calcola(cliente: cliente(griglia(voce(.fondiETF, true, true, true), capacita: capacita)),
                                   posizioni: [conto70, azionario])
        }
        let limitata = conCapacita(.limitata)
        verifica.vero("X10 Capacità fino al 10%: perdite", limitata.incoerenze.map(\.tipo) == [.perdite])
        verifica("X10 Perdita 37%", limitata.incoerenze.first?.valore ?? -1, 37, tolleranza: 0.0001)
        verifica("X10 Soglia 10%", limitata.incoerenze.first?.soglia ?? -1, 10)
        verifica.vero("X10 Il dettaglio dice la crisi del 2008", limitata.incoerenze.first?.dettaglio.contains("2008") == true)
        verifica.vero("X10 Titolo", limitata.incoerenze.first?.titolo == "Perdita possibile oltre la capacità del cliente")
        let media = conCapacita(.media)
        verifica.vero("X10 Capacità fino al 25%: perdite", media.incoerenze.map(\.tipo) == [.perdite])
        verifica("X10 Soglia 25%", media.incoerenze.first?.soglia ?? -1, 25)
        verifica.vero("X10 Capacità oltre il 25%: nessun limite", conCapacita(.elevata).incoerenze.isEmpty)

        // X11. Obbligazionario (−17% nel 2022)
        func obbligazioni(_ capacita: CapacitaPerdite) -> EsitoCoerenza {
            MotoreCoerenza.calcola(cliente: cliente(griglia(voce(.fondiETF, true, true, true), capacita: capacita)),
                                   posizioni: [conto80, obbligazionario])
        }
        let o10 = obbligazioni(.limitata)
        verifica.vero("X11 Obbligazionario, fino al 10%: perdite", o10.incoerenze.map(\.tipo) == [.perdite])
        verifica("X11 Obbligazionario: 17%", o10.incoerenze.first?.valore ?? -1, 17, tolleranza: 0.0001)
        verifica.vero("X11 Obbligazionario, fino al 25%: nulla", obbligazioni(.media).incoerenze.isEmpty)

        // X12. Capacità nessuna, ogni tipo «esperto»
        let conto50 = pos("Conto", .liquidita, 50_000)
        func nessuna(_ p: Posizione, _ t: TipoProdotto) -> EsitoCoerenza {
            MotoreCoerenza.calcola(cliente: cliente(griglia(voce(t, true, true, true), capacita: .nessuna)), posizioni: [conto50, p])
        }
        var consolidata = ramoI
        consolidata.consolidamento = true
        verifica.vero("X12 Ramo I consolidato: nessuna perdita", nessuna(consolidata, .ramoI).incoerenze.isEmpty)
        var aScadenza = ramoI
        aScadenza.consolidamento = false
        let x12 = nessuna(aScadenza, .ramoI)
        verifica.vero("X12 Ramo I senza consolidamento: perdite", x12.incoerenze.map(\.tipo) == [.perdite])
        verifica.vero("X12 Titolo «Capitale garantito solo a scadenza»", x12.incoerenze.first?.titolo == "Capitale garantito solo a scadenza")
        verifica("X12 Valore 0", x12.incoerenze.first?.valore ?? -1, 0)
        let mr = nessuna(multiramo, .multiramo)
        verifica.vero("X12 Multiramo: una sola incoerenza di perdita", mr.incoerenze.map(\.tipo) == [.perdite])
        verifica("X12 Multiramo: 11,1%", mr.incoerenze.first?.valore ?? -1, 11.1, tolleranza: 0.0001)
        verifica("X12 Multiramo: soglia 0", mr.incoerenze.first?.soglia ?? -1, 0)
        let pip = proposta("Piano individuale pensionistico", .previdenza, versamento: 0) {
            $0.tipologia = "Piano individuale pensionistico (PIP)"; $0.premio = 200; $0.frequenza = .mensile
        }
        verifica.vero("X12 Previdenza: nessun controllo di perdita", nessuna(pip, .previdenza).incoerenze.isEmpty)

        // X13. Ordine con i controlli di prima (il caso di K10): proposta, orizzonte, esperienza, perdite
        let fondo = proposta("Fondo azionario Europa", .investimento, versamento: 20_000) {
            $0.tipologia = "Fondo comune"; $0.sri = 5; $0.periodoRaccomandato = 5
        }
        let x13 = MotoreCoerenza.calcola(cliente: cliente(griglia(voce(.fondiETF, false, nil, nil), capacita: .limitata),
                                                          propensione: .moderata, orizzonte: 3),
                                         posizioni: [conto50, fondo])
        verifica.vero("X13 Ordine: proposta, orizzonte, esperienza, perdite",
                      x13.incoerenze.map(\.tipo) == [.proposta, .orizzonte, .esperienza, .perdite])
        verifica("X13 Perdita 37%", x13.incoerenze.first { $0.tipo == .perdite }?.valore ?? -1, 37, tolleranza: 0.0001)
        verifica.vero("X13 Pillole del dettaglio", Incoerenza.Tipo.esperienza.pillola == "Esperienza"
                        && Incoerenza.Tipo.perdite.pillola == "Perdita possibile" && Incoerenza.Tipo.orizzonte.pillola == "Orizzonte più lungo"
                        && Incoerenza.Tipo.proposta.pillola == "Oltre il profilo")
        verifica.vero("X13 Metodo della coerenza: sempre tre righe", MotoreCoerenza.metodo.count == 3)

        // Scheda di adeguatezza: la frase della verifica
        if let v = MotoreEsperienza.verifica(ul, esperienza: griglia(voce(.ramoIII, false, nil, nil)), prodotti: []) {
            verifica.vero("X13 Scheda: la frase del dettaglio", TestiEsperienza.esitoScheda(v) == v.incoerenze.first?.dettaglio)
        } else {
            verifica.vero("X13 Scheda: la proposta si verifica", false)
        }
        if let v = MotoreEsperienza.verifica(ul, esperienza: nil, prodotti: []) {
            verifica.vero("X13 Scheda: esperienza non rilevata", TestiEsperienza.esitoScheda(v) == "Esperienza con questo tipo di prodotto non rilevata.")
        }
        verifica("X13 Righe della scheda: sempre 7", Double(MotoreEsperienza.righe(nil).count), 7)
    }

    // MARK: - X14 · Suggerimenti

    private static func suggerimenti(_ verifica: VerificaCalcoli) {
        let etf = pos("ETF", .investimento, 10_000) { $0.tipologia = "ETF con piano di accumulo" }
        let s = MotoreEsperienza.suggerimenti(griglia(voce(.fondiETF, true, nil, true)), posizioni: [etf])
        verifica.vero("X14 ETF in essere, «ha avuto» vuoto: suggerito", s.map(\.tipo) == [.fondiETF] && s.first?.posizioni.count == 1)
        verifica.vero("X14 «Ha avuto» già sì: nessun suggerimento",
                      MotoreEsperienza.suggerimenti(griglia(voce(.fondiETF, true, true, true)), posizioni: [etf]).isEmpty)
        var inProposta = etf
        inProposta.stato = .proposta
        verifica.vero("X14 Solo in proposta: nessun suggerimento",
                      MotoreEsperienza.suggerimenti(griglia(voce(.fondiETF, true, nil, true)), posizioni: [inProposta]).isEmpty)
    }

    // MARK: - X15 · Lettura tollerante

    private static func lettura(_ verifica: VerificaCalcoli) {
        func leggi(_ json: String) -> EsperienzaProdotti? {
            try? Archivio.decodificatore.decode(EsperienzaProdotti.self, from: Data(json.utf8))
        }
        let futuro = leggi(#"{"voci":[{"tipo":"criptovalute","conosce":true},{"tipo":"ramoI","conosce":true,"haAvuto":false}],"capacitaPerdite":"enorme"}"#)
        verifica.vero("X15 Tipo sconosciuto scartato, le altre voci restano",
                      futuro?.voci.count == 1 && futuro?.voci.first?.tipo == .ramoI && futuro?.voci.first?.haAvuto == false)
        verifica.vero("X15 Capacità sconosciuta: nil", futuro != nil && futuro?.capacitaPerdite == nil)
        let malformata = leggi(#"{"voci":[{"tipo":"ramoI","conosce":"forse"},{"tipo":"previdenza","conosce":false}]}"#)
        verifica.vero("X15 Valore non booleano: voce scartata", malformata?.voci.map(\.tipo) == [.previdenza])
        let doppia = leggi(#"{"voci":[{"tipo":"ramoI","conosce":true},{"tipo":"ramoI","conosce":false}]}"#)
        verifica.vero("X15 Stesso tipo due volte: vale l'ultima", doppia?.voci.count == 1 && doppia?.voci.first?.conosce == false)

        // Il cliente di Giulia senza la chiave (archivio 20) e con un valore strano
        guard let giulia = DatiDemo.clienti().first(where: { $0.id == "giulia" }),
              let grezzo = (try? Archivio.codificatore.encode(giulia)).flatMap({ try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any],
              var profilo = grezzo["profilo"] as? [String: Any] else {
            verifica.vero("X15 Cliente di Giulia codificato", false)
            return
        }
        verifica.vero("X15 Il profilo di Giulia ha la griglia", profilo["esperienzaProdotti"] != nil)
        var oggetto = grezzo
        profilo["esperienzaProdotti"] = nil
        oggetto["profilo"] = profilo
        let senza = (try? JSONSerialization.data(withJSONObject: oggetto)).flatMap { try? Archivio.decodificatore.decode(Cliente.self, from: $0) }
        verifica.vero("X15 Archivio 20: griglia nil, profilo intatto",
                      senza != nil && senza?.profilo.esperienzaProdotti == nil && senza?.profilo.propensione == .moderata)
        profilo["esperienzaProdotti"] = 42
        oggetto["profilo"] = profilo
        let strano = (try? JSONSerialization.data(withJSONObject: oggetto)).flatMap { try? Archivio.decodificatore.decode(Cliente.self, from: $0) }
        verifica.vero("X15 Griglia illeggibile: il cliente si legge", strano != nil)
        verifica.vero("X15 Griglia illeggibile: non compilata", strano?.profilo.esperienzaProdotti?.compilata != true)
        verifica("X15 Griglia illeggibile: il resto del profilo resta", strano?.profilo.redditoLordoAnnuo ?? -1, 32_000)

        // Andata e ritorno con 7 voci e la capacità
        var piena = EsperienzaProdotti()
        for t in TipoProdotto.allCases {
            piena.imposta(voce(t, true, t == .previdenza ? false : true, t == .ramoIII ? nil : true))
        }
        piena.capacitaPerdite = .media
        piena.aggiornataIl = AiutiProva.data(2026, 10, 1)
        let tornata = (try? Archivio.codificatore.encode(piena)).flatMap { try? Archivio.decodificatore.decode(EsperienzaProdotti.self, from: $0) }
        verifica.vero("X15 Andata e ritorno: identica", piena.voci.count == 7 && tornata == piena)
    }

    // MARK: - X16 · Dati di prova

    private static func datiDiProva(_ verifica: VerificaCalcoli) {
        let demo = DatiPrisma.demo()
        func cliente(_ id: String) -> Cliente? { demo.clienti.first { $0.id == id } }
        func sue(_ id: String) -> [Posizione] { demo.posizioni.filter { $0.clienteId == id } }
        func esito(_ id: String) -> EsitoCoerenza? {
            cliente(id).map { MotoreCoerenza.calcola(cliente: $0, posizioni: sue(id), prodotti: demo.prodotti) }
        }
        func di(_ e: EsitoCoerenza?, _ tipo: Incoerenza.Tipo) -> [Incoerenza] { e?.incoerenze.filter { $0.tipo == tipo } ?? [] }

        let giulia = esito("giulia")
        let espGiulia = di(giulia, .esperienza)
        verifica.vero("X16 Giulia: il PIP di un tipo che non conosce",
                      giulia != nil && espGiulia.count == 1 && espGiulia.first?.posizione?.id == "pos-giulia-piano-previdenziale-integrativo"
                        && espGiulia.first?.titolo == "Proposta di un tipo che non conosce")
        verifica.vero("X16 Giulia: nessuna perdita oltre la capacità", di(giulia, .perdite).isEmpty)

        let andrea = esito("andrea")
        let espAndrea = di(andrea, .esperienza)
        verifica.vero("X16 Andrea: il Ramo I che non conosce",
                      andrea != nil && espAndrea.count == 1 && espAndrea.first?.posizione?.id == "pos-andrea-piano-di-risparmio-rivalutabile")
        verifica.vero("X16 Andrea: nessuna perdita (gestione separata consolidata)", di(andrea, .perdite).isEmpty)
        verifica.vero("X16 Andrea: la temporanea caso morte è a posto",
                      andrea?.incoerenze.contains { $0.posizione?.id == "pos-andrea-temporanea-caso-morte" } == false)

        let sofia = esito("sofia")
        verifica.vero("X16 Sofia: nessuna incoerenza di esperienza o perdita",
                      sofia != nil && di(sofia, .esperienza).isEmpty && di(sofia, .perdite).isEmpty)
        if let p = demo.posizioni.first(where: { $0.id == "pos-sofia-obbligazionario-a-scadenza-2030" }) {
            verifica("X16 Sofia: obbligazionario a scadenza −15,5% nel 2022", MotoreEsperienza.perdita(p).percento, 15.5, tolleranza: 0.0001)
        } else {
            verifica.vero("X16 Sofia: la proposta obbligazionaria nei dati di prova", false)
        }

        let marco = esito("marco")
        verifica.vero("X16 Marco: senza griglia, nessuna esperienza", marco != nil && di(marco, .esperienza).isEmpty
                        && marco?.esperienza?.compilata == false)

        let grigliaDi = { (id: String) -> EsperienzaProdotti? in cliente(id)?.profilo.esperienzaProdotti }
        verifica.vero("X16 Esperienza suggerita: Giulia media", MotoreEsperienza.esperienzaSuggerita(grigliaDi("giulia")) == .media)
        verifica.vero("X16 Esperienza suggerita: Sofia elevata", MotoreEsperienza.esperienzaSuggerita(grigliaDi("sofia")) == .elevata)
        verifica.vero("X16 Esperienza suggerita: Andrea nessuna (2 tipi)", MotoreEsperienza.esperienzaSuggerita(grigliaDi("andrea")) == nil)
        verifica.vero("X16 Sintesi di Giulia", MotoreEsperienza.sintesi(grigliaDi("giulia")) == "7 tipi su 7 · 2 che non conosce · 1 da spiegare")
        let suggeriti = MotoreEsperienza.suggerimenti(grigliaDi("giulia"), posizioni: sue("giulia"), prodotti: demo.prodotti)
        verifica.vero("X16 Giulia: segnare «ha avuto» per i fondi (2 posizioni)",
                      suggeriti.map(\.tipo) == [.fondiETF] && suggeriti.first?.posizioni.count == 2)
        let segnalati = MotoreEsperienza.daSegnalare(clienti: demo.clienti, posizioni: demo.posizioni, prodotti: demo.prodotti)
        verifica.vero("X16 Notifica: Andrea e Giulia", segnalati.map { $0.cliente.id } == ["andrea", "giulia"])
        let attenzioni = MotoreAttenzioni.calcola(clienti: demo.clienti, posizioni: demo.posizioni)
        verifica.vero("X16 Le attenzioni non vedono le proposte", !attenzioni.contains { $0.titolo.hasPrefix("Proposta di") })
    }
}
