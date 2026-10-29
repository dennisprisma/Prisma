import Foundation

/// Prove del confronto «Nel documento / In Prisma» (giro 5, specifica 9, §7.1): confronto con posizioni e schede,
/// aggiornamento con lo storico e il ripristino, «Lascia come in Prisma», premio e frequenze, rendimento lordo dal KID,
/// aumenti e impatto di un nuovo KID sui clienti, collegamento, archivio e stato. Chiamate da `ProvaCalcoli.esegui()`
/// dopo `ProvaCalcoliDocumenti`: gli errori si sommano. Date fisse con `AiutiProva.data`.
enum ProvaCalcoliConfrontoDossier {
    static func esegui(_ verifica: VerificaCalcoli) {
        polizza(verifica)
        premio(verifica)
        beneficiari(verifica)
        kid(verifica)
        collegamento(verifica)
        documentiDiProva(verifica)
        casiLimite(verifica)
        archivio(verifica)
        lordo(verifica)
        #if os(macOS)
        stato(verifica)
        #elseif os(iOS)
        // DD25-DD26 provano lo stato della Shell del Mac (StatoShell con le sue finestre): su iPhone e iPad si
        // provano i motori, lo stato mobile avrà le sue prove
        #endif
    }

    // MARK: - Dati di prova comuni

    private typealias Motore = MotoreConfrontoDossier

    private static let il = AiutiProva.data(2026, 10, 29)

    private static func campo(_ c: CampoDocumento, _ v: String, estratto: String = "", confermato: Bool = true) -> CampoEstratto {
        CampoEstratto(chiave: c, valore: v, pagina: 1, estratto: estratto, confermato: confermato)
    }

    private static func confermati(_ campi: [CampoEstratto]) -> [CampoEstratto] {
        campi.map { c in
            var x = c
            x.confermato = true
            return x
        }
    }

    private static func documento(_ campi: [CampoEstratto], tipo: Documento.Tipo = .polizza, cliente: String = "prova",
                                  titolo: String = "Documento di prova") -> Documento {
        var d = Documento(clienteId: cliente, titolo: titolo, tipo: tipo)
        d.id = "doc-dd-\(tipo.rawValue)"
        d.importatoIl = AiutiProva.data(2026, 10, 20)
        d.campi = campi
        return d
    }

    /// P1: la copertura di Marco come nei dati di prova, ma con date fisse.
    private static func p1() -> Posizione {
        var p = Posizione(clienteId: "prova", canale: .alleanza, stato: .inEssere, area: .protezione, nome: "Infortuni famiglia")
        p.id = "pos-dd-infortuni"
        p.numeroContratto = "AL-2025-551203"
        p.premio = 380
        p.frequenza = .annuale
        p.capitaleAssicurato = 200_000
        p.scadenza = AiutiProva.data(2026, 12, 13)
        p.creataIl = AiutiProva.data(2026, 1, 10)
        return p
    }

    /// D1: la polizza di prova di Marco (testo di DatiDemo), tutti i dati confermati.
    private static func d1() -> Documento {
        var d = Documento(clienteId: "prova", titolo: "Polizza Infortuni famiglia", tipo: .polizza)
        d.id = "doc-dd-polizza"
        d.importatoIl = AiutiProva.data(2026, 10, 20)
        d.campi = confermati(EstrattoreDocumento.conRegole(DatiDemo.testoDocumento("doc-marco-polizza") ?? []))
        return d
    }

    /// Pr1: la scheda di un fondo, KID 2025.
    private static func pr1() -> Prodotto {
        var p = Prodotto(nome: "Fondo Prova Bilanciato", canale: .indipendente, area: .investimento)
        p.id = "prodotto-dd-prova"
        p.emittente = "Prova SGR"
        p.sri = 3
        p.costoIngresso = 1
        p.costoAnnuo = 0.8
        p.incidenzaCostiKID = 1.1
        p.periodoRaccomandato = 5
        p.rendimentoAtteso = 4
        p.fonte = "KID 2025"
        return p
    }

    /// K1: il nuovo KID, con i dati come li dà l'estrattore, confermati (pagina 1).
    private static func k1(ingresso: String = "1,00", emittente: Bool = true) -> Documento {
        var campi = [campo(.nomeProdotto, "Fondo Prova Bilanciato, classe A")]
        if emittente { campi.append(campo(.emittente, "Prova SGR S.p.A.")) }
        campi += [campo(.sri, "4"), campo(.periodoDetenzione, "7"), campo(.costoIngresso, ingresso), campo(.costoAnnuo, "0,95"),
                  campo(.incidenzaCosti, "1,35"), campo(.rendimentoModerato, "3,2")]
        var d = documento(campi, tipo: .kid, cliente: "dd-anna", titolo: "KID Fondo Prova Bilanciato 2026")
        d.id = "doc-dd-kid-fondo"
        return d
    }

    private static func cliente(_ id: String, _ nome: String, _ propensione: ProfiloInvestitore.Propensione?) -> Cliente {
        var c = Cliente(id: id, nome: nome, iniziali: Cliente.iniziali(di: nome), tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: AiutiProva.data(2020, 1, 1))
        c.profilo.propensione = propensione
        return c
    }

    /// I1: i clienti dell'impatto.
    private static let clientiI1 = [
        cliente("dd-anna", "Anna Prova", .moderata),
        cliente("dd-bruno", "Bruno Prova", .dinamica),
        cliente("dd-carla", "Carla Prova", nil),
    ]

    private static func posizione(_ id: String, _ cliente: String, _ stato: StatoPosizione, nome: String = "Fondo Prova Bilanciato",
                                  canale: Canale = .indipendente, _ configura: (inout Posizione) -> Void) -> Posizione {
        var p = Posizione(clienteId: cliente, canale: canale, stato: stato, area: .investimento, nome: nome)
        p.id = id
        p.creataIl = AiutiProva.data(2026, 1, 10)
        configura(&p)
        return p
    }

    /// I1: le posizioni dell'impatto (a1, a2 di Anna; b1, b2 di Bruno; c1, c2 di Carla).
    private static func posizioniI1() -> [Posizione] {
        let scheda = "prodotto-dd-prova"
        return [
            posizione("a1", "dd-anna", .inEssere) { $0.prodottoId = scheda; $0.controvalore = 40_000 },
            posizione("a2", "dd-anna", .proposta) {
                $0.esito = .presentata; $0.prodottoId = scheda; $0.versamentoIniziale = 10_000; $0.premio = 200
                $0.frequenza = .mensile; $0.sri = 3; $0.costoAnnuo = 0.8; $0.incidenzaCostiKID = 1.1; $0.periodoRaccomandato = 5
            },
            posizione("b1", "dd-bruno", .inEssere, nome: "fondo prova bilanciato") { $0.controvalore = 25_000 },
            posizione("b2", "dd-bruno", .inEssere, canale: .alleanza) { $0.controvalore = 99_000 },
            posizione("c1", "dd-carla", .chiusa) { $0.prodottoId = scheda; $0.controvalore = 50_000 },
            posizione("c2", "dd-carla", .proposta) { $0.esito = .rifiutata; $0.prodottoId = scheda; $0.versamentoIniziale = 30_000 },
        ]
    }

    private static func stessoGiorno(_ a: Date?, _ b: Date) -> Bool {
        guard let a else { return false }
        return Calendar(identifier: .gregorian).isDate(a, inSameDayAs: b)
    }

    // MARK: - DD1–DD5: la polizza contro la posizione

    private static func polizza(_ verifica: VerificaCalcoli) {
        let d = d1()

        // DD1. Confronto
        let c = Motore.confronta(d, con: p1())
        verifica.vero("DD1 Confronto: righe beneficiari, premio, capitale, scadenza",
                      c.righe.map(\.voce) == [.beneficiari, .premio, .capitaleAssicurato, .scadenza])
        verifica.vero("DD1 Confronto: esiti nuovo, uguale, diverso, diverso", c.righe.map(\.esito) == [.nuovo, .uguale, .diverso, .diverso])
        verifica("DD1 Confronto: capitale −50.000", c.riga(.capitaleAssicurato)?.differenza ?? 0, -50_000)
        verifica.vero("DD1 Confronto: il capitale che scende peggiora", c.riga(.capitaleAssicurato)?.peggiora == true)
        verifica.vero("DD1 Confronto: scadenza senza differenza, non peggiora",
                      c.riga(.scadenza) != nil && c.riga(.scadenza)?.differenza == nil && c.riga(.scadenza)?.peggiora == false)
        verifica("DD1 Confronto: 6 voci che il documento non riporta", Double(c.mancanti.count), 6)
        verifica("DD1 Confronto: 3 differenze", Double(c.differenze), 3)
        verifica.vero("DD1 Confronto: preselezionati capitale e scadenza", c.preselezione == [.capitaleAssicurato, .scadenza])
        verifica.vero("DD1 Confronto: nota dei beneficiari", c.riga(.beneficiari)?.nota == TestiConfrontoDossier.notaBeneficiari)

        // DD2. Aggiornamento del capitale e della scadenza
        var p = p1()
        let nuove = Motore.applica([.capitaleAssicurato, .scadenza], da: c, documento: d, a: &p, il: il)
        verifica("DD2 Aggiorna: capitale 150.000", p.capitaleAssicurato ?? 0, 150_000)
        verifica.vero("DD2 Aggiorna: scadenza al 1/12/2026", stessoGiorno(p.scadenza, AiutiProva.data(2026, 12, 1)))
        verifica("DD2 Aggiorna: 2 variazioni restituite", Double(nuove.count), 2)
        verifica("DD2 Aggiorna: 2 variazioni nello storico", Double(p.variazioni?.count ?? 0), 2)
        let prima = p.variazioni?.first
        verifica.vero("DD2 Aggiorna: la prima variazione è il capitale", prima?.voce == "capitaleAssicurato")
        verifica("DD2 Aggiorna: valore di prima 200.000", prima?.valorePrima?.numero ?? 0, 200_000)
        verifica("DD2 Aggiorna: valore dopo 150.000", prima?.valoreDopo?.numero ?? 0, 150_000)
        verifica.vero("DD2 Aggiorna: documento, titolo e tipo della variazione",
                      prima?.documentoId == d.id && prima?.titoloDocumento == d.titolo && prima?.tipoDocumento == "polizza")
        verifica("DD2 Aggiorna: il premio non cambia", p.premio, 380)
        verifica("DD2 Aggiorna: resta solo la differenza dei beneficiari", Double(Motore.confronta(d, con: p).differenze), 1)

        // DD3. Ripristino del capitale
        if let v = prima {
            verifica.vero("DD3 Ripristino: la variazione del capitale si può annullare", Motore.ripristinabile(v, in: p))
            let r = Motore.ripristina(v, in: &p, il: il)
            verifica.vero("DD3 Ripristino: registrato", r != nil)
            verifica("DD3 Ripristino: capitale di nuovo 200.000", p.capitaleAssicurato ?? 0, 200_000)
            verifica("DD3 Ripristino: 3 variazioni", Double(p.variazioni?.count ?? 0), 3)
            verifica.vero("DD3 Ripristino: l'ultima annulla la prima", p.variazioni?.last?.ripristinoDi == v.id)
            verifica.vero("DD3 Ripristino: la prima non si annulla più", !Motore.ripristinabile(v, in: p))
            if let ultima = p.variazioni?.last {
                verifica.vero("DD3 Ripristino: il ripristino non si annulla", !Motore.ripristinabile(ultima, in: p))
            }
        } else {
            verifica.vero("DD3 Ripristino: variazione presente", false)
        }

        // DD4. «Lascia come in Prisma» vale per la coppia di valori
        var tenuto = d1()
        var q = p1()
        let chiave = Motore.confronta(tenuto, con: q).riga(.scadenza)?.chiave ?? ""
        verifica.vero("DD4 Tenute: chiave «scadenza|2026-12-01|2026-12-13» (\(chiave))", chiave == "scadenza|2026-12-01|2026-12-13")
        tenuto.vociTenute = [chiave]
        let ct = Motore.confronta(tenuto, con: q)
        verifica.vero("DD4 Tenute: scadenza lasciata in Prisma", ct.riga(.scadenza)?.esito == .tenuto)
        verifica("DD4 Tenute: 2 differenze", Double(ct.differenze), 2)
        verifica.vero("DD4 Tenute: preselezionato solo il capitale", ct.preselezione == [.capitaleAssicurato])
        verifica.vero("DD4 Tenute: non allineato", !ct.allineato)
        q.scadenza = AiutiProva.data(2026, 12, 14)
        let cs = Motore.confronta(tenuto, con: q)
        verifica.vero("DD4 Tenute: con la scadenza di Prisma cambiata la riga torna diversa", cs.riga(.scadenza)?.esito == .diverso)
        verifica("DD4 Tenute: di nuovo 3 differenze", Double(cs.differenze), 3)

        // DD5. Capitale non confermato
        var nonConfermato = d1()
        if let i = nonConfermato.campi.firstIndex(where: { $0.chiave == .capitaleAssicurato }) { nonConfermato.campi[i].confermato = false }
        let cn = Motore.confronta(nonConfermato, con: p1())
        verifica.vero("DD5 Da confermare: riga del capitale", cn.riga(.capitaleAssicurato)?.esito == .daConfermare)
        verifica.vero("DD5 Da confermare: non preselezionata", cn.riga(.capitaleAssicurato)?.preselezionata == false)
        verifica("DD5 Da confermare: 2 differenze", Double(cn.differenze), 2)
        var pn = p1()
        let nessuna = Motore.applica([.capitaleAssicurato], da: cn, documento: nonConfermato, a: &pn, il: il)
        verifica.vero("DD5 Da confermare: nessuna variazione", nessuna.isEmpty)
        verifica("DD5 Da confermare: il capitale resta 200.000", pn.capitaleAssicurato ?? 0, 200_000)
    }

    // MARK: - DD6–DD9b: premio e frequenze

    private static func premio(_ verifica: VerificaCalcoli) {
        // DD6. Frequenza dalla riga del documento
        let casi: [(String, Frequenza?)] = [
            ("Premio annuo: 380,00", .annuale), ("Premio mensile: 22,00", .mensile), ("Premio trimestrale lordo: 95,00", .trimestrale),
            ("Premio semestrale 190", .semestrale), ("Premio unico di perfezionamento: 50.000,00", .unica), ("Premio: 380,00", nil),
        ]
        for (testo, attesa) in casi {
            verifica.vero("DD6 Frequenza del premio: «\(testo)»", Motore.frequenzaPremio(testo) == attesa)
        }

        // DD7. Rate diverse, stessa cifra all'anno
        var q = p1()
        q.premio = 22
        q.frequenza = .mensile
        let dr = documento([campo(.premio, "264,00", estratto: "Premio annuo lordo: 264,00")])
        let c = Motore.confronta(dr, con: q)
        let r = c.riga(.premio)
        verifica.vero("DD7 Rate diverse: diverso", r?.esito == .diverso)
        verifica("DD7 Rate diverse: differenza annua 0", r?.differenza ?? 99, 0)
        verifica.vero("DD7 Rate diverse: non peggiora", r?.peggiora == false)
        verifica.vero("DD7 Rate diverse: nota", r?.nota == TestiConfrontoDossier.notaRateDiverse)
        verifica.vero("DD7 Rate diverse: preselezionata", r?.preselezionata == true)
        let nuove = Motore.applica([.premio], da: c, documento: dr, a: &q, il: il)
        verifica("DD7 Rate diverse: premio 264", q.premio, 264)
        verifica.vero("DD7 Rate diverse: frequenza annuale", q.frequenza == .annuale)
        verifica("DD7 Rate diverse: premio di prima 22", nuove.first?.valorePrima?.numero ?? 0, 22)
        verifica.vero("DD7 Rate diverse: frequenze di prima e dopo",
                      nuove.first?.valorePrima?.frequenza == "mensile" && nuove.first?.valoreDopo?.frequenza == "annuale")

        // DD8. Frequenza non scritta: quella di Prisma
        let d8 = documento([campo(.premio, "380,00", estratto: "Premio: 380,00")])
        verifica.vero("DD8 Frequenza dedotta: uguale", Motore.confronta(d8, con: p1()).riga(.premio)?.esito == .uguale)

        // DD8b. Stessa regola con una posizione mensile
        var q8 = p1()
        q8.premio = 30
        q8.frequenza = .mensile
        let r8 = Motore.confronta(documento([campo(.premio, "380", estratto: "Premio: 380")]), con: q8).riga(.premio)
        verifica.vero("DD8b Frequenza dedotta: diverso", r8?.esito == .diverso)
        verifica("DD8b Frequenza dedotta: (380 − 30) × 12", r8?.differenza ?? 0, 4_200)
        verifica.vero("DD8b Frequenza dedotta: nota", r8?.nota == TestiConfrontoDossier.notaFrequenzaDedotta(.mensile))

        // DD9. Premio unico
        var u = p1()
        u.versamentoIniziale = 50_000
        u.premio = 0
        u.frequenza = .unica
        let d9 = documento([campo(.premio, "50.000,00", estratto: "Premio unico: 50.000,00")])
        verifica.vero("DD9 Premio unico: uguale", Motore.confronta(d9, con: u).riga(.premio)?.esito == .uguale)

        // DD9b. Premio unico diverso
        let d9b = documento([campo(.premio, "55.000,00", estratto: "Premio unico: 55.000,00")])
        let c9 = Motore.confronta(d9b, con: u)
        verifica.vero("DD9b Premio unico: diverso", c9.riga(.premio)?.esito == .diverso)
        verifica("DD9b Premio unico: differenza 5.000", c9.riga(.premio)?.differenza ?? 0, 5_000)
        _ = Motore.applica([.premio], da: c9, documento: d9b, a: &u, il: il)
        verifica("DD9b Premio unico: versamento iniziale 55.000", u.versamentoIniziale, 55_000)
        verifica("DD9b Premio unico: premio periodico 0", u.premio, 0)
        verifica.vero("DD9b Premio unico: frequenza unica", u.frequenza == .unica)
    }

    // MARK: - DD10–DD10b: beneficiari

    private static func beneficiari(_ verifica: VerificaCalcoli) {
        var q = p1()
        q.beneficiari = "Luca Ferri"
        let uguale = Motore.confronta(documento([campo(.beneficiari, "luca  ferri.")]), con: q).riga(.beneficiari)
        verifica.vero("DD10 Beneficiari: maiuscole, spazi e punteggiatura non contano", uguale?.esito == .uguale)

        q.beneficiari = "Elena Bianchi"
        let diverso = Motore.confronta(documento([campo(.beneficiari, "Luca Ferri")]), con: q).riga(.beneficiari)
        verifica.vero("DD10b Beneficiari: diversi", diverso?.esito == .diverso)
        verifica.vero("DD10b Beneficiari: mai preselezionati", diverso?.preselezionata == false)
    }

    // MARK: - DD11–DD16: il nuovo KID contro la scheda

    private static func kid(_ verifica: VerificaCalcoli) {
        let k = k1()
        let c = Motore.confronta(k, con: pr1())

        // DD11. Confronto con la scheda
        verifica.vero("DD11 KID: righe delle voci di prodotto",
                      c.righe.map(\.voce) == [.sri, .periodoRaccomandato, .costoIngresso, .costoGestione, .incidenzaCosti, .rendimentoLordo])
        verifica.vero("DD11 KID: esiti", c.righe.map(\.esito) == [.diverso, .diverso, .uguale, .diverso, .diverso, .diverso])
        let differenze: [(VoceDossier, Double)] = [(.sri, 1), (.periodoRaccomandato, 2), (.costoIngresso, 0), (.costoGestione, 0.15),
                                                   (.incidenzaCosti, 0.25), (.rendimentoLordo, 0.3395)]
        for (voce, attesa) in differenze {
            verifica("DD11 KID: differenza \(voce.rawValue)", c.riga(voce)?.differenza ?? -99, attesa, tolleranza: 0.000_1)
        }
        verifica.vero("DD11 KID: peggiorano rischio, costi correnti e incidenza",
                      c.righe.map(\.peggiora) == [true, false, false, true, true, false])
        verifica("DD11 KID: 5 differenze", Double(c.differenze), 5)
        verifica.vero("DD11 KID: preselezione senza il rendimento lordo",
                      c.preselezione == [.sri, .periodoRaccomandato, .costoGestione, .incidenzaCosti])
        verifica.vero("DD11 KID: nessuna voce mancante", c.mancanti.isEmpty)
        verifica.vero("DD11 KID: nota del rendimento lordo stimato", c.riga(.rendimentoLordo)?.nota == TestiConfrontoDossier.notaLordo(.stima))

        // DD12. Aumenti
        let aumenti = Motore.aumenti(c)
        verifica.vero("DD12 Aumenti: rischio 3→4, costi correnti 0,8→0,95, incidenza 1,1→1,35",
                      aumenti == [AumentoKID(voce: .sri, prima: 3, dopo: 4), AumentoKID(voce: .costoGestione, prima: 0.8, dopo: 0.95),
                                  AumentoKID(voce: .incidenzaCosti, prima: 1.1, dopo: 1.35)])

        // DD13. Impatto sui clienti
        let e = Motore.impatto(aumenti, prodotto: pr1(), posizioni: posizioniI1(), clienti: clientiI1)
        verifica.vero("DD13 Impatto: Anna e Bruno", e.clienti.map(\.clienteId) == ["dd-anna", "dd-bruno"])
        let anna = e.clienti.first { $0.clienteId == "dd-anna" }
        let bruno = e.clienti.first { $0.clienteId == "dd-bruno" }
        verifica("DD13 Impatto: Anna 131 € l'anno (100 + 31)", anna?.costoAnnuoInPiu ?? 0, 131)
        verifica.vero("DD13 Impatto: Anna oltre il profilo (max 3)", anna?.oltreProfilo == true && anna?.sriMassimo == 3)
        verifica.vero("DD13 Impatto: Anna, prima la proposta", anna?.posizioni.map(\.id) == ["a2", "a1"])
        verifica("DD13 Impatto: Bruno 62,50 € l'anno", bruno?.costoAnnuoInPiu ?? 0, 62.5)
        verifica.vero("DD13 Impatto: Bruno dentro il profilo (max 5)", bruno?.oltreProfilo == false && bruno?.sriMassimo == 5)
        verifica.vero("DD13 Impatto: Bruno collegato per nome", bruno?.posizioni.first?.perNome == true)
        verifica("DD13 Impatto: 3 posizioni", Double(e.posizioni), 3)
        verifica("DD13 Impatto: 193,50 € l'anno in tutto", e.costoAnnuoInPiu, 193.5)
        verifica("DD13 Impatto: nessun ingresso in più", e.ingressoInPiu, 0)

        // DD14. Con il costo d'ingresso più alto
        let c14 = Motore.confronta(k1(ingresso: "2,00"), con: pr1())
        let a14 = Motore.aumenti(c14)
        verifica("DD14 Ingresso: 4 aumenti", Double(a14.count), 4)
        verifica.vero("DD14 Ingresso: il secondo è l'ingresso 1→2",
                      a14.count > 1 && a14[1] == AumentoKID(voce: .costoIngresso, prima: 1, dopo: 2))
        let e14 = Motore.impatto(a14, prodotto: pr1(), posizioni: posizioniI1(), clienti: clientiI1)
        verifica("DD14 Ingresso: 124 € dalla proposta di Anna (12.400 × 1%)", e14.ingressoInPiu, 124)
        let a1 = e14.clienti.first { $0.clienteId == "dd-anna" }?.posizioni.first { $0.id == "a1" }
        verifica.vero("DD14 Ingresso: niente sulla posizione in essere senza premi", a1 != nil && a1?.ingressoInPiu == 0)

        // DD15. Aggiornamento della scheda
        var pr = pr1()
        let nuove = Motore.applica(c.preselezione, da: c, documento: k, a: &pr, il: il)
        verifica.vero("DD15 Scheda: SRI 4 e periodo 7", pr.sri == 4 && pr.periodoRaccomandato == 7)
        verifica("DD15 Scheda: costi correnti 0,95", pr.costoAnnuo ?? 0, 0.95)
        verifica("DD15 Scheda: incidenza 1,35", pr.incidenzaCostiKID ?? 0, 1.35)
        verifica.vero("DD15 Scheda: rendimento e ingresso invariati", pr.rendimentoAtteso == 4 && pr.costoIngresso == 1)
        verifica.vero("DD15 Scheda: verificata il giorno dell'aggiornamento", pr.verificatoIl == Calendar.current.startOfDay(for: il))
        verifica.vero("DD15 Scheda: fonte dal KID", pr.fonte.hasPrefix("KID Fondo Prova Bilanciato 2026 (KID, importato il "))
        verifica("DD15 Scheda: 4 variazioni", Double(pr.variazioni?.count ?? 0), 4)
        verifica.vero("DD15 Scheda: la fonte di prima resta nello storico",
                      nuove.count == 4 && (pr.variazioni ?? []).allSatisfy { $0.fontePrecedente == "KID 2025" })
        let ultimo = Motore.aumenti(ultimo: pr.variazioni ?? [])
        verifica("DD15 Scheda: 3 aumenti nell'ultimo aggiornamento", Double(ultimo?.aumenti.count ?? 0), 3)
        verifica.vero("DD15 Scheda: aumenti dal KID", ultimo?.documentoId == k.id)

        // DD16. Anche le proposte aperte del prodotto
        var elenco = posizioniI1()
        let cambiate = Motore.applicaAProposte(c.preselezione, documento: k, prodottoId: pr1().id, posizioni: &elenco, il: il)
        verifica("DD16 Proposte: una proposta aggiornata", Double(cambiate), 1)
        let a2 = elenco.first { $0.id == "a2" }
        verifica.vero("DD16 Proposte: a2 con SRI 4 e periodo 7", a2?.sri == 4 && a2?.periodoRaccomandato == 7)
        verifica("DD16 Proposte: a2 costi correnti 0,95", a2?.costoAnnuo ?? 0, 0.95)
        verifica("DD16 Proposte: a2 incidenza 1,35", a2?.incidenzaCostiKID ?? 0, 1.35)
        verifica("DD16 Proposte: a2 con 4 variazioni", Double(a2?.variazioni?.count ?? 0), 4)
        verifica.vero("DD16 Proposte: la posizione in essere e la proposta rifiutata non cambiano",
                      elenco.first { $0.id == "a1" }?.variazioni == nil && elenco.first { $0.id == "c2" }?.variazioni == nil)
    }

    // MARK: - DD17–DD18b: collegamento

    private static func collegamento(_ verifica: VerificaCalcoli) {
        let d = d1()
        var altra = p1()
        altra.id = "pos-dd-altra"
        altra.numeroContratto = "AL-2024-000001"
        var chiusa = p1()
        chiusa.id = "pos-dd-chiusa"
        chiusa.stato = .chiusa
        var altroCliente = p1()
        altroCliente.id = "pos-dd-altro-cliente"
        altroCliente.clienteId = "altro"

        // DD17. Dal numero di contratto
        let trovata = Motore.posizioneProbabile(d, tra: [altra, chiusa, altroCliente, p1()])
        verifica.vero("DD17 Collegamento: la posizione dal numero di polizza",
                      trovata?.0.id == "pos-dd-infortuni" && trovata?.1 == .numeroContratto)

        // DD17b. Senza numero, due posizioni con lo stesso nome: nessuna
        var senzaNumero = d1()
        senzaNumero.campi.removeAll { $0.chiave == .numeroContratto }
        var q1 = p1()
        q1.numeroContratto = ""
        var q2 = altra
        q2.numeroContratto = ""
        verifica.vero("DD17b Collegamento: mai a caso tra due uguali", Motore.posizioneProbabile(senzaNumero, tra: [q1, q2, chiusa]) == nil)

        // DD17c. Candidate: la protezione sì, immobili, debiti e liquidità no
        let casa = AiutiProva.posizione("Casa", .immobili, 200_000)
        let mutuo = AiutiProva.posizione("Mutuo", .debiti, 90_000)
        let conto = AiutiProva.posizione("Conto", .liquidita, 10_000)
        let candidate = Motore.candidatePosizioni(d, tra: [p1(), casa, mutuo, conto])
        verifica.vero("DD17c Collegamento: tra le candidate la protezione, non immobili, debiti e liquidità",
                      candidate.map(\.id) == ["pos-dd-infortuni"])

        // DD17d. La polizza di prova di Marco tra le posizioni di prova: dal nome
        if var marco = DatiDemo.documenti().first(where: { $0.id == "doc-marco-polizza" }) {
            marco.posizioneId = nil
            let p = Motore.posizioneProbabile(marco, tra: DatiDemo.posizioni())
            verifica.vero("DD17d Collegamento: la polizza di Marco va su «Infortuni famiglia» dal nome",
                          p?.0.id == "pos-marco-infortuni-famiglia" && p?.1 == .nome)
        } else {
            verifica.vero("DD17d Collegamento: polizza di prova presente", false)
        }

        // DD18. La scheda dal nome e dall'emittente
        var fondoProva = Prodotto(nome: "Fondo Prova", canale: .indipendente, area: .investimento)
        fondoProva.id = "prodotto-dd-fondo"
        fondoProva.emittente = "Prova SGR"
        var altraSGR = Prodotto(nome: "Fondo Prova Bilanciato", canale: .indipendente, area: .investimento)
        altraSGR.id = "prodotto-dd-altra-sgr"
        altraSGR.emittente = "Altra SGR"
        let schede = [pr1(), fondoProva, altraSGR]
        let scheda = Motore.prodottoProbabile(k1(), tra: schede)
        verifica.vero("DD18 Collegamento: la scheda dal nome e dalla compagnia",
                      scheda?.0.id == "prodotto-dd-prova" && scheda?.1 == .nomeEdEmittente)

        // DD18b. Senza emittente due schede con il nome più lungo: nessuna
        verifica.vero("DD18b Collegamento: senza emittente nessuna scheda", Motore.prodottoProbabile(k1(emittente: false), tra: schede) == nil)
    }

    // MARK: - DD19–DD20c: i documenti di prova delle scene

    private static func documentiDiProva(_ verifica: VerificaCalcoli) {
        // DD19. Lettura del nuovo KID dell'ETF
        let campi = EstrattoreDocumento.conRegole(DatiConfrontoDemo.pagineKIDETF)
        func v(_ c: CampoDocumento) -> String? { campi.first { $0.chiave == c }?.valore }
        verifica.vero("DD19 KID ETF: SRI 5", v(.sri) == "5")
        verifica.vero("DD19 KID ETF: periodo 5", v(.periodoDetenzione) == "5")
        verifica.vero("DD19 KID ETF: ingresso 0,00", v(.costoIngresso) == "0,00")
        verifica.vero("DD19 KID ETF: costi correnti 0,25", v(.costoAnnuo) == "0,25")
        verifica.vero("DD19 KID ETF: incidenza 0,25", v(.incidenzaCosti) == "0,25")
        verifica.vero("DD19 KID ETF: scenario moderato 6,1", v(.rendimentoModerato) == "6,1")

        // DD19b. Contro la scheda dell'ETF
        let kidETF = DatiConfrontoDemo.kidETF()
        guard let etf = DatiDemo.prodotti().first(where: { $0.id == "prodotto-etf-globale" }) else {
            verifica.vero("DD19b KID ETF: scheda di prova presente", false)
            return
        }
        let c = Motore.confronta(kidETF, con: etf)
        verifica.vero("DD19b KID ETF: esiti", c.righe.map(\.esito) == [.diverso, .uguale, .nuovo, .diverso, .diverso, .diverso])
        verifica.vero("DD19b KID ETF: peggiorano rischio e costi", c.righe.map(\.peggiora) == [true, false, false, true, true, false])
        verifica("DD19b KID ETF: SRI +1", c.riga(.sri)?.differenza ?? 0, 1)
        verifica("DD19b KID ETF: costi correnti +0,05", c.riga(.costoGestione)?.differenza ?? 0, 0.05, tolleranza: 0.000_1)
        verifica("DD19b KID ETF: incidenza +0,05", c.riga(.incidenzaCosti)?.differenza ?? 0, 0.05, tolleranza: 0.000_1)
        verifica("DD19b KID ETF: lordo 6,3659% contro 5%", c.riga(.rendimentoLordo)?.differenza ?? 0, 1.3659, tolleranza: 0.000_1)
        verifica("DD19b KID ETF: 5 differenze", Double(c.differenze), 5)
        verifica.vero("DD19b KID ETF: preselezione", c.preselezione == [.sri, .costoIngresso, .costoGestione, .incidenzaCosti])

        // DD19c. Impatto sui clienti di prova
        let e = Motore.impatto(Motore.aumenti(c), prodotto: etf, posizioni: DatiDemo.posizioni(), clienti: DatiDemo.clienti())
        verifica.vero("DD19c Impatto ETF: Giulia e Laura", e.clienti.map(\.clienteId) == ["giulia", "laura"])
        let giulia = e.clienti.first { $0.clienteId == "giulia" }
        let laura = e.clienti.first { $0.clienteId == "laura" }
        verifica("DD19c Impatto ETF: Giulia 18,20 € l'anno", giulia?.costoAnnuoInPiu ?? 0, 18.2)
        verifica.vero("DD19c Impatto ETF: Giulia oltre il profilo (5 > 3)", giulia?.oltreProfilo == true)
        verifica("DD19c Impatto ETF: Laura 13,50 € l'anno", laura?.costoAnnuoInPiu ?? 0, 13.5)
        verifica.vero("DD19c Impatto ETF: Laura dentro il profilo (5 ≤ 5)", laura?.oltreProfilo == false)
        verifica.vero("DD19c Impatto ETF: entrambe per nome",
                      giulia?.posizioni.first?.perNome == true && laura?.posizioni.first?.perNome == true)
        verifica("DD19c Impatto ETF: 31,70 € in tutto", e.costoAnnuoInPiu, 31.7)

        // DD20. Lettura dell'appendice
        let scadenza = AiutiProva.data(2037, 3, 15)
        let campiApp = EstrattoreDocumento.conRegole(DatiConfrontoDemo.pagineAppendice(scadenza: scadenza))
        func a(_ c: CampoDocumento) -> CampoEstratto? { campiApp.first { $0.chiave == c } }
        verifica.vero("DD20 Appendice: numero di polizza", a(.numeroContratto)?.valore == "AL-2022-104851")
        verifica.vero("DD20 Appendice: beneficiari", a(.beneficiari)?.valore == "Luca Ferri")
        verifica.vero("DD20 Appendice: premio mensile 180,00",
                      a(.premio)?.valore == "180,00" && (a(.premio)?.estratto.lowercased().contains("mensile") ?? false))
        verifica.vero("DD20 Appendice: scadenza", a(.scadenza)?.valore == "15/03/2037")

        // DD20b. È un'appendice
        let appendice = DatiConfrontoDemo.appendice(scadenza: scadenza)
        verifica.vero("DD20b Appendice: riconosciuta dal titolo", appendice.appendice)

        // DD20c. Contro il piano di risparmio
        var piano = Posizione(clienteId: "giulia", canale: .alleanza, stato: .inEssere, area: .risparmio, nome: "Piano di risparmio rivalutabile")
        piano.premio = 150
        piano.frequenza = .mensile
        piano.beneficiari = "Eredi legittimi"
        piano.scadenza = scadenza
        let cp = Motore.confronta(appendice, con: piano)
        verifica.vero("DD20c Appendice: premio diverso", cp.riga(.premio)?.esito == .diverso)
        verifica("DD20c Appendice: +360 € l'anno", cp.riga(.premio)?.differenza ?? 0, 360)
        verifica.vero("DD20c Appendice: il premio non peggiora", cp.riga(.premio)?.peggiora == false)
        verifica.vero("DD20c Appendice: beneficiari diversi, non scelti",
                      cp.riga(.beneficiari)?.esito == .diverso && cp.riga(.beneficiari)?.preselezionata == false)
        verifica.vero("DD20c Appendice: scadenza uguale", cp.riga(.scadenza)?.esito == .uguale)
    }

    // MARK: - DD21–DD23: casi limite

    private static func casiLimite(_ verifica: VerificaCalcoli) {
        // DD21. Anni del periodo
        verifica.vero("DD21 Anni: «15 anni» → 15", Motore.anni("15 anni") == 15)
        verifica.vero("DD21 Anni: «0» → nessuno", Motore.anni("0") == nil)
        verifica.vero("DD21 Anni: «61» → nessuno", Motore.anni("61") == nil)
        let zero = documento([campo(.periodoDetenzione, "0")], tipo: .kid)
        verifica.vero("DD21 Anni: un periodo «0» non si legge",
                      Motore.confronta(zero, con: pr1()).riga(.periodoRaccomandato)?.esito == .illeggibile)

        // DD22. Tolleranza sui costi
        let c22 = Motore.confronta(documento([campo(.costoAnnuo, "0,804")], tipo: .kid), con: pr1())
        verifica.vero("DD22 Tolleranza: 0,80 e 0,804 sono uguali", c22.riga(.costoGestione)?.esito == .uguale)
        verifica.vero("DD22 Tolleranza: nessun aumento", Motore.aumenti(c22).isEmpty)

        // DD23. Multiramo a due parti
        if let multiramo = DatiDemo.posizioni().first(where: { $0.id == "pos-marco-polizza-multiramo" }) {
            let r = Motore.confronta(documento([campo(.costoAnnuo, "2,90")], tipo: .kid, cliente: "marco"), con: multiramo)
                .riga(.costoGestione)
            verifica.vero("DD23 Multiramo: costi correnti diversi", r?.esito == .diverso)
            verifica.vero("DD23 Multiramo: non preselezionati", r?.preselezionata == false)
            verifica.vero("DD23 Multiramo: nota", r?.nota == TestiConfrontoDossier.notaMultiramo)
        } else {
            verifica.vero("DD23 Multiramo: posizione di prova presente", false)
        }
    }

    // MARK: - DD24: archivio

    private static func archivio(_ verifica: VerificaCalcoli) {
        let codifica = JSONEncoder()
        let lettura = JSONDecoder()
        func dati(_ testo: String) -> Data { Data(testo.utf8) }

        // Una variazione malformata non lancia
        let malformata = try? lettura.decode(VariazioneDossier.self, from: dati(#"{"voce":3,"il":"x"}"#))
        verifica.vero("DD24 Archivio: variazione malformata letta senza errori", malformata != nil && malformata?.voce == "")

        let variazione = VariazioneDossier(voce: "sri", prima: "3 su 7", dopo: "4 su 7", valorePrima: ValoreVoce(numero: 3),
                                           valoreDopo: ValoreVoce(numero: 4), documentoId: "doc-dd", titoloDocumento: "KID",
                                           tipoDocumento: "kid", il: il, fontePrecedente: "KID 2025")

        // Posizione con lo storico, e senza il campo
        var p = p1()
        p.variazioni = [variazione]
        let pLetta = (try? codifica.encode(p)).flatMap { try? lettura.decode(Posizione.self, from: $0) }
        verifica.vero("DD24 Archivio: posizione con le variazioni uguale", pLetta == p)
        let senza = (try? codifica.encode(p1())).flatMap { try? lettura.decode(Posizione.self, from: $0) }
        verifica.vero("DD24 Archivio: posizione senza variazioni → nil", senza != nil && senza?.variazioni == nil)

        // Scheda con lo storico (le CodingKeys)
        var pr = pr1()
        pr.variazioni = [variazione]
        let prLetta = (try? codifica.encode(pr)).flatMap { try? lettura.decode(Prodotto.self, from: $0) }
        verifica.vero("DD24 Archivio: scheda con le variazioni uguale", prLetta == pr && prLetta?.variazioni?.first?.fontePrecedente == "KID 2025")

        // Documento con le voci tenute, e senza
        var d = d1()
        d.vociTenute = ["scadenza|2026-12-01|2026-12-13"]
        let dLetto = (try? codifica.encode(d)).flatMap { try? lettura.decode(Documento.self, from: $0) }
        verifica.vero("DD24 Archivio: documento con le voci tenute uguale", dLetto == d)
        let dSenza = try? lettura.decode(Documento.self, from: dati(#"{"id":"d","clienteId":"a","titolo":"Polizza","tipo":"polizza"}"#))
        verifica.vero("DD24 Archivio: documento senza voci tenute → nil", dSenza != nil && dSenza?.vociTenute == nil)
        let futuro = try? lettura.decode(Documento.self, from: dati(#"{"id":"d","clienteId":"a","titolo":"Appendice","tipo":"appendiceFutura"}"#))
        verifica.vero("DD24 Archivio: un tipo sconosciuto diventa «Altro» senza perdere il documento", futuro?.tipo == .altro)
    }

    // MARK: - DD27–DD28: rendimento lordo

    private static func lordo(_ verifica: VerificaCalcoli) {
        // DD27. Il lordo che rifà lo scenario moderato
        verifica("DD27 Lordo: KID di Giulia 4,0847%", Motore.lordoImplicito(moderato: 3.2, ingresso: 0, annuo: 0.85, anni: 15) ?? 0,
                 4.0847, tolleranza: 0.000_1)
        let multiramo = Motore.lordoImplicito(moderato: 2.6, ingresso: 1, annuo: 2.05, anni: 8)
        verifica("DD27 Lordo: KID multiramo 4,8790%", multiramo ?? 0, 4.8790, tolleranza: 0.000_1)
        verifica.vero("DD27 Lordo: senza anni nessuna stima", Motore.lordoImplicito(moderato: 3, ingresso: 0, annuo: 1, anni: 0) == nil)
        verifica.vero("DD27 Lordo: ingresso del 100% nessuna stima", Motore.lordoImplicito(moderato: 3, ingresso: 100, annuo: 1, anni: 5) == nil)
        let proiezione = MotoreProiezione.calcola(ParametriProiezione(capitaleIniziale: 10_000, versamento: 0, frequenza: .unica, anni: 8,
                                                                      rendimento: multiramo ?? 0, costoIngresso: 1, costoAnnuo: 2.05,
                                                                      aliquotaFiscale: 0, inflazione: 0))
        verifica("DD27 Lordo: la proiezione di Prisma rifà lo scenario (10.000 × 1,026^8)",
                 proiezione.punti.first { $0.anno == 8 }?.valore ?? 0, 12_279.45, tolleranza: 1)

        // DD28. Rendimento lordo di un documento
        if let giulia = DatiDemo.documenti().first(where: { $0.id == "doc-giulia-kid" }) {
            let stima = Motore.rendimentoLordo(giulia, soloConfermati: false)
            verifica("DD28 Lordo: KID di Giulia, dati letti", stima?.valore ?? 0, 4.0847, tolleranza: 0.000_1)
            verifica.vero("DD28 Lordo: KID di Giulia, stima", stima?.fonte == .stima)
            verifica.vero("DD28 Lordo: KID di Giulia senza dati confermati, nessun lordo",
                          Motore.rendimentoLordo(giulia, soloConfermati: true) == nil)
            var senzaPeriodo = giulia
            senzaPeriodo.campi = confermati(giulia.campi.filter { $0.chiave != .periodoDetenzione })
            verifica.vero("DD28 Lordo: senza periodo nessun lordo", Motore.rendimentoLordo(senzaPeriodo, soloConfermati: true) == nil)
        } else {
            verifica.vero("DD28 Lordo: KID di prova presente", false)
        }
        let kid2023 = documento(confermati(EstrattoreDocumento.conRegole(pagineKID2023)), tipo: .kid)
        let dalKID = Motore.rendimentoLordo(kid2023, soloConfermati: true)
        verifica("DD28 Lordo: KID 2023, prima dei costi 4,6%", dalKID?.valore ?? 0, 4.6, tolleranza: 0.000_1)
        verifica.vero("DD28 Lordo: KID 2023, dal KID", dalKID?.fonte == .kid)
    }

    /// Il testo del KID 2023 della prova 17b di `ProvaCalcoli` (rendimento «prima dei costi»).
    private static let pagineKID2023 = [
        """
        Documento contenente le informazioni chiave
        Nome del prodotto: Esempio Multiramo Futuro – Classe B
        Nome dell'ideatore del PRIIP: Esempio Vita S.p.A. – Gruppo Esempio
        Tipo: Contratto di assicurazione sulla vita multiramo
        """,
        """
        Indicatore di rischio
        Abbiamo classificato questo prodotto al livello 4 su 7, che corrisponde alla classe di rischio media.
        Periodo di detenzione raccomandato:
        8 anni
        Scenario moderato   Possibile rimborso al netto dei costi   9.870 EUR   12.410 EUR
        Rendimento medio per ciascun anno   -1,3%   2,7%
        """,
        """
        Andamento dei costi nel tempo
        Costi totali   410 EUR   1.540 EUR
        Incidenza annuale dei costi (*)   4,1%   1,9% ogni anno
        (*) Dimostra come i costi riducono il rendimento ogni anno: se si esce al termine del periodo il rendimento è del 4,6% prima dei costi.
        Composizione dei costi
        Costi di ingresso   2,5% dell'importo pagato al momento della sottoscrizione
        Costi di uscita   Non addebitiamo una commissione di uscita per questo prodotto
        Commissioni di gestione e altri costi amministrativi o di esercizio   1,60% del valore dell'investimento all'anno
        """,
    ]

    // MARK: - DD25–DD26: lo stato (StatoConfrontoDossier)

    #if os(macOS)
    private static func stato(_ verifica: VerificaCalcoli) {
        let etfId = "prodotto-etf-globale"

        // DD25. Il nuovo KID dell'ETF aggiorna la scheda; impatto e attività
        do {
            let s = StatoShell(persistente: false)
            let kid = DatiConfrontoDemo.kidETF()
            s.dati.documenti.append(kid)
            if let c = s.confronto(kid, .prodotto(etfId)) {
                s.aggiornaDalDocumento(kid.id, bersaglio: .prodotto(etfId), voci: c.preselezione, ancheProposte: true)
            } else {
                verifica.vero("DD25 Stato: confronto con la scheda dell'ETF", false)
            }
            let p = s.prodotto(etfId)
            verifica.vero("DD25 Stato: SRI 5", p?.sri == 5)
            verifica("DD25 Stato: ingresso 0", p?.costoIngresso ?? -1, 0)
            verifica("DD25 Stato: costi correnti 0,25", p?.costoAnnuo ?? 0, 0.25)
            verifica("DD25 Stato: incidenza 0,25", p?.incidenzaCostiKID ?? 0, 0.25)
            verifica.vero("DD25 Stato: periodo e rendimento invariati", p?.periodoRaccomandato == 5 && p?.rendimentoAtteso == 5)
            verifica("DD25 Stato: 4 variazioni", Double(p?.variazioni?.count ?? 0), 4)
            if let p, let impatto = s.impattoProdotto(p) {
                verifica("DD25 Stato: avviso con 2 clienti", Double(impatto.esito.clienti.count), 2)
                let prima = s.dati.attivita.count
                s.creaAttivitaImpatto(impatto.esito, prodotto: p, il: impatto.il)
                verifica("DD25 Stato: 2 attività create", Double(s.dati.attivita.count - prima), 2)
                let dopo = s.dati.attivita.count
                s.creaAttivitaImpatto(impatto.esito, prodotto: p, il: impatto.il)
                verifica("DD25 Stato: ripetuta, nessuna attività in più", Double(s.dati.attivita.count - dopo), 0)
            } else {
                verifica.vero("DD25 Stato: impatto del nuovo KID in Prodotti", false)
            }
        }

        // DD26. Un'appendice non collegata: suggerimento, collegamento e scollegamento
        do {
            let s = StatoShell(persistente: false)
            let pianoId = "pos-giulia-piano-di-risparmio-rivalutabile"
            let scadenza = s.dati.posizioni.first { $0.id == pianoId }?.scadenza ?? AiutiProva.data(2037, 3, 15)
            let appendice = DatiConfrontoDemo.appendice(scadenza: scadenza)
            s.dati.documenti.append(appendice)
            let suggerimento = s.suggerimentoCollegamento(appendice)
            verifica.vero("DD26 Stato: suggerito il piano di risparmio dal numero di polizza",
                          suggerimento?.0 == .posizione(pianoId) && suggerimento?.1 == .numeroContratto)
            s.collegaDocumento(appendice.id, a: .posizione(pianoId))
            let collegato = s.documento(appendice.id)
            verifica.vero("DD26 Stato: collegato alla posizione", collegato?.posizioneId == pianoId)
            verifica("DD26 Stato: un bersaglio", Double(collegato.map { s.bersagli($0).count } ?? 0), 1)
            s.scollegaDocumento(appendice.id, da: .posizione(pianoId))
            verifica.vero("DD26 Stato: scollegato", s.documento(appendice.id) != nil && s.documento(appendice.id)?.posizioneId == nil)
            if let estratto = s.documento("doc-giulia-estratto") {
                let candidate = s.candidateCollegamento(estratto).map { $0.0 }
                verifica.vero("DD26 Stato: per l'estratto c'è il piano di risparmio", candidate.contains(.posizione(pianoId)))
                verifica.vero("DD26 Stato: per l'estratto nessuna scheda prodotto", !candidate.contains(where: diProdotto))
            } else {
                verifica.vero("DD26 Stato: estratto di prova presente", false)
            }
        }
    }
    #endif

    private static func diProdotto(_ b: BersaglioConfronto) -> Bool {
        if case .prodotto = b { return true }
        return false
    }
}
