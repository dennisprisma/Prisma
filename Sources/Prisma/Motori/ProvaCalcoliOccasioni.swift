import Foundation

/// Prove del calendario delle occasioni (casi O1–O20): regole per tipo, caso morte contro debito residuo,
/// fisco, tipi spenti, finestra, notifiche, promemoria del Mac, riesame, lettura delle impostazioni e
/// coerenza con i clienti di prova. Chiamate da `ProvaCalcoli.esegui()`: gli errori si sommano.
enum ProvaCalcoliOccasioni {
    private static let cal = Calendar(identifier: .gregorian)
    private static let oggi = AiutiProva.data(2026, 3, 10)

    private static func d(_ a: Int, _ m: Int, _ g: Int) -> Date { AiutiProva.data(a, m, g) }

    private static func stessoGiorno(_ x: Date?, _ y: Date) -> Bool {
        x.map { cal.isDate($0, inSameDayAs: y) } ?? false
    }

    private static func tipo(_ elenco: [Occasione], _ t: TipoOccasione) -> [Occasione] {
        elenco.filter { $0.tipo == t }
    }

    /// Il cliente di prova: id "prova", come le posizioni di `AiutiProva.posizione`.
    private static func cliente(nascita: Date? = nil, famiglia: [Familiare] = [], canali: [Canale] = []) -> Cliente {
        var c = Cliente(id: "prova", nome: "Cliente di prova", iniziali: "CP", tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: d(2020, 1, 1))
        c.dataNascita = nascita
        c.famiglia = famiglia
        c.canali = canali
        return c
    }

    /// La polizza di O1: rivalutabile di Ramo I, decorrenza 15/9/2025, 12 mesi di blocco, penali per 4 anni.
    private static func polizza(_ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        AiutiProva.posizione("Polizza GS", .risparmio, 10_000) {
            $0.tipologia = "Polizza rivalutabile (Ramo I)"
            $0.decorrenza = d(2025, 9, 15)
            $0.mesiBloccoRiscatto = 12
            $0.penali = [2.5, 2, 1.5, 1]
            modifica(&$0)
        }
    }

    /// La famiglia di O7: Sara a carico, Luca con il carico fino a 23 anni, Tea non autosufficiente.
    private static var figli: [Familiare] {
        [Familiare(id: "f-sara", nome: "Sara", relazione: .figlia, dataNascita: d(2008, 6, 30), aCarico: true),
         Familiare(id: "f-luca", nome: "Luca", relazione: .figlio, dataNascita: d(2010, 1, 20), etaFineCarico: 23),
         Familiare(id: "f-tea", nome: "Tea", relazione: .figlia, dataNascita: d(2012, 4, 4), nonAutosufficiente: true)]
    }

    /// Maria, coniuge senza reddito (O8).
    private static var maria: Familiare {
        Familiare(id: "f-maria", nome: "Maria", relazione: .coniuge, dataNascita: d(1960, 8, 1))
    }

    private static func calcola(_ c: Cliente, _ posizioni: [Posizione], prodotti: [Prodotto] = [], da: Date? = nil, a: Date,
                                regole: ImpostazioniOccasioni = ImpostazioniOccasioni()) -> [Occasione] {
        MotoreOccasioni.calcola(cliente: c, posizioni: posizioni, prodotti: prodotti, da: da ?? oggi, a: a,
                                regole: regole, oggi: oggi, cal: cal)
    }

    static func esegui(_ verifica: VerificaCalcoli) {
        contratti(verifica)
        previdenza(verifica)
        casoMorte(verifica)
        famiglia(verifica)
        fiscoEFiltri(verifica)
        chiLeUsa(verifica)
        impostazioni(verifica)
        coerenza(verifica)
    }

    // MARK: - Contratti (O1–O3)

    private static func contratti(_ verifica: VerificaCalcoli) {
        // O1. Blocco di 12 mesi dal 15/9/2025 → 15/9/2026; penali fino al 5° anno → senza penali dal 6°, il 15/9/2030
        do {
            let pol = polizza()
            let e = calcola(cliente(), [pol], a: d(2036, 1, 1))
            let blocco = tipo(e, .fineBloccoRiscatto)
            let penali = tipo(e, .senzaPenali)
            verifica("O1 Blocco: una occasione", Double(blocco.count), 1)
            verifica.vero("O1 Blocco: il 15/9/2026", stessoGiorno(blocco.first?.data, d(2026, 9, 15)))
            verifica("O1 Blocco: valore 12 mesi", blocco.first?.valore ?? -1, 12)
            verifica("O1 Senza penali: una occasione", Double(penali.count), 1)
            verifica.vero("O1 Senza penali: il 15/9/2030", stessoGiorno(penali.first?.data, d(2030, 9, 15)))
            verifica("O1 Senza penali: dal 6° anno", penali.first?.valore ?? -1, 6)
            let r = MotoreRiscatto.calcola(pol, data: oggi)
            verifica.vero("O1 Blocco: stesso giorno di MotoreRiscatto",
                          r?.riscattabileDal.map { stessoGiorno(blocco.first?.data, $0) } ?? false)
            verifica.vero("O1 Senza penali: stesso giorno di MotoreRiscatto",
                          r?.senzaPenaliDal.map { stessoGiorno(penali.first?.data, $0) } ?? false)
            verifica.vero("O1 Fine blocco (regola singola)", stessoGiorno(MotoreOccasioni.fineBlocco(pol, prodotto: nil, cal: cal), d(2026, 9, 15)))
            verifica.vero("O1 Titoli senza euro", !e.contains { $0.titolo.contains("€") })
        }

        // O2. Ripiego della scheda prodotto: blocco, penali (3 anni) e periodo raccomandato del KID
        do {
            var scheda = Prodotto(nome: "Rivalutabile di prova", canale: .indipendente, area: .risparmio)
            scheda.id = "x"
            var condizioni = CondizioniContratto()
            condizioni.mesiBloccoRiscatto = 12
            condizioni.penali = [3.5, 2.5, 1]
            condizioni.periodoRaccomandato = 10
            scheda.condizioni = condizioni
            let pol = polizza {
                $0.penali = nil
                $0.mesiBloccoRiscatto = nil
                $0.prodottoId = "x"
            }
            let e = calcola(cliente(), [pol], prodotti: [scheda], a: d(2036, 1, 1))
            verifica.vero("O2 Scheda: blocco il 15/9/2026", stessoGiorno(tipo(e, .fineBloccoRiscatto).first?.data, d(2026, 9, 15)))
            verifica.vero("O2 Scheda: senza penali il 15/9/2029", stessoGiorno(tipo(e, .senzaPenali).first?.data, d(2029, 9, 15)))
            verifica("O2 Scheda: senza penali dal 5° anno", tipo(e, .senzaPenali).first?.valore ?? -1, 5)
            verifica.vero("O2 Scheda: periodo del KID il 15/9/2035", stessoGiorno(tipo(e, .periodoRaccomandato).first?.data, d(2035, 9, 15)))
            verifica("O2 Scheda: periodo del KID 10 anni", tipo(e, .periodoRaccomandato).first?.valore ?? -1, 10)
            let s = MotoreOccasioni.senzaPenali(pol, prodotto: scheda, cal: cal)
            verifica("O2 Senza penali (regola singola): anno", Double(s?.anno ?? -1), 5)
        }

        // O3. Ricorrenze della gestione separata: ogni anniversario nella finestra, non il giorno di scadenza
        do {
            let fine = d(2028, 3, 10)
            let r = tipo(calcola(cliente(), [polizza()], a: fine), .ricorrenzaGestione)
            verifica("O3 Ricorrenze: due nella finestra", Double(r.count), 2)
            let prima = r.first
            let seconda = r.dropFirst().first
            verifica.vero("O3 Ricorrenze: la 1ª il 15/9/2026", stessoGiorno(prima?.data, d(2026, 9, 15)))
            verifica("O3 Ricorrenze: valore della 1ª", prima?.valore ?? -1, 1)
            verifica.vero("O3 Ricorrenze: la 2ª il 15/9/2027", stessoGiorno(seconda?.data, d(2027, 9, 15)))
            verifica("O3 Ricorrenze: valore della 2ª", seconda?.valore ?? -1, 2)
            verifica.vero("O3 Ricorrenze: importanza bassa", r.allSatisfy { $0.importanza == .bassa })
            let conScadenza = tipo(calcola(cliente(), [polizza { $0.scadenza = d(2027, 9, 15) }], a: fine), .ricorrenzaGestione)
            verifica("O3 Ricorrenze: quella del giorno di scadenza non conta", Double(conScadenza.count), 1)
            let fondo = AiutiProva.posizione("Fondo", .investimento, 10_000) {
                $0.tipologia = "Fondo comune"
                $0.decorrenza = d(2025, 9, 15)
            }
            verifica("O3 Ricorrenze: nessuna per un fondo", Double(tipo(calcola(cliente(), [fondo], a: fine), .ricorrenzaGestione).count), 0)
        }
    }

    // MARK: - Previdenza (O4, O5, O9)

    private static func previdenza(_ verifica: VerificaCalcoli) {
        // O4. Anni contati dalla prima adesione (20/5/2019), non dalla decorrenza (10/1/2023)
        do {
            let fp = AiutiProva.posizione("Fondo pensione", .previdenza, 20_000) {
                $0.decorrenza = d(2023, 1, 10)
                $0.primaAdesione = d(2019, 5, 20)
            }
            let e = calcola(cliente(), [fp], a: d(2055, 1, 1))
            let anticipazioni = tipo(e, .anticipazioniPrevidenza)
            verifica("O4 Anticipazioni: una occasione", Double(anticipazioni.count), 1)
            verifica.vero("O4 Anticipazioni: il 20/5/2027", stessoGiorno(anticipazioni.first?.data, d(2027, 5, 20)))
            let aliquote = tipo(e, .aliquotaPrevidenza)
            verifica("O4 Aliquota: due traguardi", Double(aliquote.count), 2)
            let sedicesimo = aliquote.first
            let trentacinquesimo = aliquote.dropFirst().first
            verifica.vero("O4 Aliquota: oltre il 15° anno il 20/5/2035", stessoGiorno(sedicesimo?.data, d(2035, 5, 20)))
            verifica("O4 Aliquota: 14,70%", sedicesimo?.valore ?? -1, 14.7, tolleranza: 0.001)
            verifica.vero("O4 Aliquota: al minimo il 20/5/2054", stessoGiorno(trentacinquesimo?.data, d(2054, 5, 20)))
            verifica("O4 Aliquota: 9%", trentacinquesimo?.valore ?? -1, 9, tolleranza: 0.001)
            let gradino = MotoreFiscale.calcola(fp, data: oggi).gradini.first?.dal
            verifica.vero("O4 Aliquota: stesso giorno del primo gradino di MotoreFiscale",
                          gradino.map { stessoGiorno(aliquote.first?.data, $0) } ?? false)
        }

        // O5. Senza prima adesione si conta dalla decorrenza
        do {
            let fp = AiutiProva.posizione("Fondo pensione", .previdenza, 20_000) { $0.decorrenza = d(2020, 2, 1) }
            let anticipazioni = tipo(calcola(cliente(), [fp], a: d(2055, 1, 1)), .anticipazioniPrevidenza)
            verifica.vero("O5 Anticipazioni dalla decorrenza: il 1/2/2028", stessoGiorno(anticipazioni.first?.data, d(2028, 2, 1)))
        }

        // O9. Pensione: 5 anni prima dei 67 (o dell'età di pensione del lavoro)
        do {
            let senzaLavoro = tipo(calcola(cliente(nascita: d(1964, 7, 15)), [], a: d(2027, 3, 10)), .pensioneVicina)
            verifica("O9 Pensione: una occasione", Double(senzaLavoro.count), 1)
            verifica.vero("O9 Pensione: il 15/7/2026", stessoGiorno(senzaLavoro.first?.data, d(2026, 7, 15)))
            verifica("O9 Pensione: a 67 anni", senzaLavoro.first?.valore ?? -1, 67)
            verifica.vero("O9 Pensione: importanza alta", senzaLavoro.first?.importanza == .alta)
            var c = cliente(nascita: d(1964, 7, 15))
            c.profilo.lavoro = DatiLavoro(etaPensione: 64)
            verifica("O9 Pensione a 64 anni: nessuna nella finestra", Double(tipo(calcola(c, [], a: d(2027, 3, 10)), .pensioneVicina).count), 0)
            let passata = tipo(calcola(c, [], da: d(2023, 1, 1), a: d(2024, 1, 1)), .pensioneVicina)
            verifica.vero("O9 Pensione a 64 anni: il 15/7/2023", passata.count == 1 && stessoGiorno(passata.first?.data, d(2023, 7, 15)))
        }
    }

    // MARK: - Caso morte sotto il debito residuo (O6)

    private static func casoMorte(_ verifica: VerificaCalcoli) {
        let fine = d(2046, 3, 10)
        func mutuo(_ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
            AiutiProva.posizione("Mutuo", .debiti, 100_000) {
                $0.tassoDebito = 3
                $0.scadenza = d(2046, 3, 10)
                modifica(&$0)
            }
        }
        func tcm(_ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
            AiutiProva.posizione("Temporanea caso morte", .protezione, 0) {
                $0.rischio = .vita
                $0.capitaleAssicurato = 150_000
                $0.capitaleDecrescente = true
                $0.decorrenza = d(2026, 3, 10)
                $0.scadenza = d(2041, 3, 10)
                $0.assicuratoId = "prova"
                modifica(&$0)
            }
        }

        // O6. Capitale decrescente in 15 anni contro un mutuo di 20 anni al 3%: sotto dal mese 103
        // (150.000 × 77/180 = 64.166,67 contro 64.267,51; al mese 102 65.000 contro 64.660,46)
        do {
            let copertura = tcm()
            let o = tipo(calcola(cliente(), [mutuo(), copertura], a: fine), .capitaleSottoDebito)
            verifica("O6 Caso morte sotto il debito: una occasione", Double(o.count), 1)
            verifica.vero("O6 Caso morte sotto il debito: il 10/10/2034", stessoGiorno(o.first?.data, d(2034, 10, 10)))
            verifica("O6 Caso morte sotto il debito: debito residuo", o.first?.valore ?? -1, 64_267.51, tolleranza: 0.01)
            verifica.vero("O6 Caso morte sotto il debito: la copertura", o.first?.posizioneId == copertura.id)
            verifica.vero("O6 Caso morte sotto il debito: importanza alta", o.first?.importanza == .alta)
        }
        // O6b. Capitale costante che finisce cinque anni prima del mutuo
        do {
            let o = tipo(calcola(cliente(), [mutuo(), tcm { $0.capitaleDecrescente = false }], a: fine), .capitaleSottoDebito)
            verifica.vero("O6b Capitale costante: alla scadenza della copertura (10/3/2041)",
                          o.count == 1 && stessoGiorno(o.first?.data, d(2041, 3, 10)))
            verifica("O6b Capitale costante: debito residuo", o.first?.valore ?? -1, 30_864.66, tolleranza: 0.01)
        }
        // O6c. Già sotto oggi: lo dice l'avviso della protezione, non è un'occasione
        do {
            let o = tipo(calcola(cliente(), [mutuo(), tcm { $0.capitaleAssicurato = 80_000; $0.capitaleDecrescente = false }], a: fine),
                         .capitaleSottoDebito)
            verifica("O6c Già sotto oggi: nessuna occasione", Double(o.count), 0)
        }
        // O6d. Mutuo cointestato al 50%: il debito a carico del cliente è la metà
        do {
            let r = MotoreOccasioni.sottoDebito(persona: "prova", cliente: cliente(), posizioni: [mutuo { $0.quotaDebito = 50 }, tcm()],
                                                oggi: oggi, cal: cal)
            let m = r.flatMap { cal.dateComponents([.month], from: oggi, to: $0.data).month } ?? 0
            verifica.vero("O6d Cointestato: più tardi del mese 103", m > 103)
            let atteso = 0.5 * MotoreProtezioneFamiglia.debitoResiduo(capitale: 100_000, tasso: 3, mesi: 240, dopo: m)
            verifica("O6d Cointestato: metà del debito residuo", r?.debito ?? -1, atteso, tolleranza: 0.01)
        }
    }

    // MARK: - Famiglia e limiti d'età (O7, O8)

    private static func famiglia(_ verifica: VerificaCalcoli) {
        // O7. Maggiore età dei tre figli; fine del carico per Sara (25) e Luca (23), non per Tea
        do {
            let e = calcola(cliente(famiglia: figli), [], a: d(2040, 1, 1))
            let maggiorenni = tipo(e, .maggiorenne)
            verifica("O7 Maggiorenni: tre", Double(maggiorenni.count), 3)
            let attesi: [(id: String, data: Date)] = [("f-sara", d(2026, 6, 30)), ("f-luca", d(2028, 1, 20)), ("f-tea", d(2030, 4, 4))]
            for (i, atteso) in attesi.enumerated() {
                let o = i < maggiorenni.count ? maggiorenni[i] : nil
                let giusto = o?.familiareId == atteso.id && stessoGiorno(o?.data, atteso.data)
                verifica.vero("O7 Maggiorenni: \(atteso.id) il \(Formati.dataBreve.string(from: atteso.data))", giusto)
            }
            verifica.vero("O7 Maggiorenni: valore 18", maggiorenni.allSatisfy { $0.valore == 18 })
            let carico = tipo(e, .fineCarico)
            verifica("O7 Fine del carico: due (non per Tea)", Double(carico.count), 2)
            let sara = carico.first { $0.familiareId == "f-sara" }
            let luca = carico.first { $0.familiareId == "f-luca" }
            verifica.vero("O7 Fine del carico: Sara il 30/6/2033", stessoGiorno(sara?.data, d(2033, 6, 30)))
            verifica("O7 Fine del carico: Sara a 25 anni", sara?.valore ?? -1, 25)
            verifica.vero("O7 Fine del carico: Luca il 20/1/2033", stessoGiorno(luca?.data, d(2033, 1, 20)))
            verifica("O7 Fine del carico: Luca a 23 anni", luca?.valore ?? -1, 23)
        }

        // O8. Limiti d'età: il cliente compie 69 anni il 2/4/2026; Maria senza reddito non ha la TCM, la LTC è nel 2029
        let fine = d(2027, 3, 10)
        do {
            let e = calcola(cliente(nascita: d(1957, 4, 2), famiglia: [maria]), [], a: fine)
            let tcm = tipo(e, .limiteEtaTCM)
            let ltc = tipo(e, .limiteEtaLTC)
            verifica("O8 TCM: una (del cliente)", Double(tcm.count), 1)
            verifica.vero("O8 TCM del cliente: il 2/4/2026", stessoGiorno(tcm.first?.data, d(2026, 4, 2)) && tcm.first?.familiareId == nil)
            verifica("O8 TCM del cliente: a 70 anni", tcm.first?.valore ?? -1, 70)
            verifica("O8 LTC: una (del cliente)", Double(ltc.count), 1)
            verifica.vero("O8 LTC del cliente: il 2/4/2026", stessoGiorno(ltc.first?.data, d(2026, 4, 2)) && ltc.first?.familiareId == nil)
            verifica("O8 LTC del cliente: a 70 anni", ltc.first?.valore ?? -1, 70)
            verifica.vero("O8 Niente per Maria", !e.contains { $0.familiareId == "f-maria" })
            verifica.vero("O8 Canale neutro senza canali del cliente", tcm.first.map { $0.canale == nil } ?? false)
            let alleanza = tipo(calcola(cliente(nascita: d(1957, 4, 2), famiglia: [maria], canali: [.alleanza]), [], a: fine), .limiteEtaTCM)
            verifica.vero("O8 Canale comune Alleanza", alleanza.first?.canale == .alleanza)
        }
        // O8b. Con una caso morte in essere niente TCM, la LTC resta
        do {
            let vita = AiutiProva.posizione("Caso morte", .protezione, 0) {
                $0.rischio = .vita
                $0.capitaleAssicurato = 100_000
                $0.scadenza = d(2030, 1, 1)
                $0.assicuratoId = "prova"
            }
            let e = calcola(cliente(nascita: d(1957, 4, 2), famiglia: [maria]), [vita], a: fine)
            verifica("O8b Con la caso morte: niente TCM", Double(tipo(e, .limiteEtaTCM).count), 0)
            verifica("O8b Con la caso morte: la LTC resta", Double(tipo(e, .limiteEtaLTC).count), 1)
        }
        // O8c. Età limite della LTC a 75: il 2/4/2031, fuori dalla finestra
        do {
            var regole = ImpostazioniOccasioni()
            regole.etaLimiteLTC = 75
            let e = calcola(cliente(nascita: d(1957, 4, 2), famiglia: [maria]), [], a: fine, regole: regole)
            verifica("O8c LTC a 75 anni: nessuna nella finestra", Double(tipo(e, .limiteEtaLTC).count), 0)
        }
    }

    // MARK: - Fisco, tipi spenti, proposte, finestra (O10–O13)

    private static func fiscoEFiltri(_ verifica: VerificaCalcoli) {
        // O10. Previdenza con 2.400 € l'anno e 40.000 € di reddito: 2.900 € ancora deducibili, 957 € di IRPEF
        do {
            var c = cliente()
            c.profilo.redditoLordoAnnuo = 40_000
            let fp = AiutiProva.posizione("Fondo pensione", .previdenza, 10_000) {
                $0.premio = 200
                $0.frequenza = .mensile
            }
            let f = tipo(calcola(c, [fp], a: d(2027, 3, 10)), .scadenzaFiscale)
            verifica("O10 Fisco: una scadenza", Double(f.count), 1)
            verifica.vero("O10 Fisco: deduzione il 31/12/2026", f.first?.fiscale == .deduzione && stessoGiorno(f.first?.data, d(2026, 12, 31)))
            verifica("O10 Fisco: IRPEF risparmiata", f.first?.valore ?? -1, 957, tolleranza: 0.5)
            verifica.vero("O10 Fisco: posizione e canale del piano", f.first?.posizioneId == fp.id && f.first?.canale == .indipendente)
        }

        // O11. Contratti spenti: nessuna occasione
        do {
            var regole = ImpostazioniOccasioni()
            regole.imposta(.contratti, attivo: false)
            verifica("O11 Contratti spenti: nessuna occasione", Double(calcola(cliente(), [polizza()], a: d(2036, 1, 1), regole: regole).count), 0)
            verifica.vero("O11 Contratti spenti: gruppo spento", !regole.attivo(.contratti))
            verifica.vero("O11 Contratti spenti: i quattro tipi in ordine",
                          regole.tipiSpenti == [.fineBloccoRiscatto, .senzaPenali, .periodoRaccomandato, .ricorrenzaGestione])
        }

        // O12. Proposte e posizioni chiuse non hanno occasioni
        do {
            verifica("O12 Proposta: nessuna occasione", Double(calcola(cliente(), [polizza { $0.stato = .proposta }], a: d(2036, 1, 1)).count), 0)
            verifica("O12 Chiusa: nessuna occasione", Double(calcola(cliente(), [polizza { $0.stato = .chiusa }], a: d(2036, 1, 1)).count), 0)
        }

        // O13. Estremi: il giorno d'inizio è compreso, quello di fine no
        do {
            let e = calcola(cliente(), [polizza()], da: d(2026, 9, 15), a: d(2026, 9, 16))
            verifica.vero("O13 Finestra di un giorno: blocco e ricorrenza",
                          tipo(e, .fineBloccoRiscatto).count == 1 && tipo(e, .ricorrenzaGestione).count == 1)
            verifica("O13 Fine esclusa: nessuna occasione", Double(calcola(cliente(), [polizza()], da: d(2026, 9, 15), a: d(2026, 9, 15)).count), 0)
        }
    }

    // MARK: - Notifiche, promemoria, riesame, ordine (O14–O17)

    private static func chiLeUsa(_ verifica: VerificaCalcoli) {
        // O14. Notifiche: alte e medie entro l'anticipo, niente fisco né basse, in ordine di giorno
        do {
            func occasione(_ giorni: Int, _ importanza: ImportanzaOccasione, fisco: Bool = false) -> Occasione {
                let data = cal.date(byAdding: .day, value: giorni, to: oggi) ?? oggi
                return Occasione(tipo: fisco ? .scadenzaFiscale : .fineBloccoRiscatto, data: data, clienteId: "prova",
                                 posizioneId: nil, familiareId: nil, canale: nil, titolo: "Prova \(giorni)", dettaglio: "",
                                 fonte: "", valore: nil, importanza: importanza, fiscale: fisco ? .deduzione : nil,
                                 id: "prova-\(giorni)")
            }
            let elenco = [occasione(10, .media), occasione(45, .media), occasione(5, .bassa), occasione(3, .media, fisco: true),
                          occasione(0, .alta)]
            let trenta = MotoreOccasioni.daNotificare(elenco, oggi: oggi, anticipoGiorni: 30, cal: cal)
            verifica.vero("O14 Notifiche a 30 giorni: oggi e tra 10 giorni, in ordine", trenta.map(\.id) == ["prova-0", "prova-10"])
            verifica("O14 Notifiche a 60 giorni: tre", Double(MotoreOccasioni.daNotificare(elenco, oggi: oggi, anticipoGiorni: 60, cal: cal).count), 3)
        }

        // O15. Promemoria del Mac: 30 giorni prima e il giorno stesso alle 9, senza cifre; anonimi senza nomi
        do {
            let pol = polizza()
            let dati = DatiPrisma(clienti: [cliente()], appuntamenti: [], attivita: [], posizioni: [pol],
                                  clienteAttivoId: "prova", impostazioni: Impostazioni())
            let adesso = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 10)) ?? oggi
            func occasioni(_ scelte: ImpostazioniPromemoria) -> [PromemoriaPianificato] {
                MotoreNotifiche.promemoria(dati, impostazioni: scelte, adesso: adesso, cal: cal).filter { $0.gruppo == "occasioni" }
            }
            let p = occasioni(ImpostazioniPromemoria())
            let attese = [cal.date(from: DateComponents(year: 2026, month: 8, day: 16, hour: 9)),
                          cal.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 9))].compactMap { $0 }
            verifica("O15 Promemoria: due", Double(p.count), 2)
            verifica.vero("O15 Promemoria: alle 9 del 16/8 e del 15/9/2026", p.map(\.data).sorted() == attese)
            verifica.vero("O15 Promemoria: 30 giorni prima e il giorno stesso",
                          p.contains { $0.id.hasSuffix("-30") } && p.contains { $0.id.hasSuffix("-0") })
            verifica.vero("O15 Promemoria: del blocco di riscatto", p.allSatisfy { $0.id.hasPrefix("prisma-occasione-fineBloccoRiscatto-") })
            verifica.vero("O15 Promemoria: niente euro", !p.contains { $0.titolo.contains("€") || $0.corpo.contains("€") })
            var anonimi = ImpostazioniPromemoria()
            anonimi.nomiClienti = false
            let a = occasioni(anonimi)
            verifica.vero("O15 Promemoria anonimi: stessi id", a.map(\.id).sorted() == p.map(\.id).sorted())
            verifica.vero("O15 Promemoria anonimi: titolo senza nomi", a.allSatisfy { $0.titolo == "Una polizza si può riscattare" })
            verifica.vero("O15 Promemoria anonimi: niente cliente né polizza",
                          !a.contains { ($0.titolo + $0.corpo).contains("Cliente di prova") || ($0.titolo + $0.corpo).contains("Polizza GS") })
            var spenti = ImpostazioniPromemoria()
            spenti.occasioni = false
            verifica("O15 Promemoria delle occasioni spenti: nessuno", Double(occasioni(spenti).count), 0)
        }

        // O16. Riesame: blocco (oltre i 6 mesi, priorità bassa), TCM e LTC (alta); la ricorrenza no
        do {
            let c = cliente(nascita: d(1957, 4, 2), famiglia: [maria])
            let fine = cal.date(byAdding: .month, value: 12, to: oggi) ?? oggi
            let e = calcola(c, [polizza()], a: fine)
            let punti = MotoreOccasioni.puntiRiesame(e, oggi: oggi, cal: cal)
            verifica("O16 Riesame: tre punti", Double(punti.count), 3)
            verifica.vero("O16 Riesame: tema occasioni", punti.allSatisfy { $0.tema == .occasioni })
            let blocco = punti.first { $0.titolo.contains("si può riscattare") }
            let limiti = punti.filter { $0.titolo.hasPrefix("Ultimo anno") }
            verifica.vero("O16 Riesame: limiti d'età con priorità alta", limiti.count == 2 && limiti.allSatisfy { $0.priorita == .alta })
            verifica.vero("O16 Riesame: blocco con priorità bassa", blocco?.priorita == .bassa)
            verifica.vero("O16 Riesame: il dettaglio comincia con la data", blocco?.dettaglio.hasPrefix("15 settembre 2026: ") ?? false)
            let domande = MotoreOccasioni.domandeRiesame(e, oggi: oggi, cal: cal)
            verifica.vero("O16 Riesame: una domanda sul limite d'età",
                          domande.count == 1 && (domande.first?.hasSuffix("finché si può sottoscrivere?") ?? false))
        }

        // O17. Ordine per giorno e identificativi diversi
        do {
            let c = cliente(nascita: d(1957, 4, 2), famiglia: figli + [maria])
            let e = calcola(c, [polizza()], a: d(2040, 1, 1))
            verifica.vero("O17 Ordine per giorno", zip(e, e.dropFirst()).allSatisfy { coppia in
                cal.startOfDay(for: coppia.0.data) <= cal.startOfDay(for: coppia.1.data)
            })
            verifica.vero("O17 Identificativi diversi", Set(e.map(\.id)).count == e.count)
            verifica.vero("O17 Più tipi insieme", Set(e.map(\.tipo)).count >= 6)
        }
    }

    // MARK: - Impostazioni (O18, O19)

    private static func impostazioni(_ verifica: VerificaCalcoli) {
        // O18. Lettura tollerante: tipi sconosciuti ignorati, valori fuori elenco ai predefiniti
        do {
            let json = #"{"inAgenda":false,"anticipoGiorni":7,"tipiSpenti":["ricorrenzaGestione","sconosciuto"],"etaLimiteTCM":99}"#
            let i = try? Archivio.decodificatore.decode(ImpostazioniOccasioni.self, from: Data(json.utf8))
            verifica.vero("O18 Impostazioni: lette", i != nil)
            verifica.vero("O18 Impostazioni: strato spento", i?.inAgenda == false)
            verifica("O18 Impostazioni: anticipo 7 giorni", Double(i?.anticipoGiorni ?? -1), 7)
            verifica.vero("O18 Impostazioni: tipo sconosciuto ignorato", i?.tipiSpenti == [.ricorrenzaGestione])
            verifica("O18 Impostazioni: età TCM fuori elenco → 70", Double(i?.etaLimiteTCM ?? -1), 70)
            verifica("O18 Impostazioni: età LTC mancante → 70", Double(i?.etaLimiteLTC ?? -1), 70)
            let fuori = try? Archivio.decodificatore.decode(ImpostazioniOccasioni.self, from: Data(#"{"anticipoGiorni":45}"#.utf8))
            verifica("O18 Impostazioni: anticipo fuori elenco → 30", Double(fuori?.anticipoGiorni ?? -1), 30)
            let generali = try? Archivio.decodificatore.decode(Impostazioni.self, from: Data(#"{"nomeUtente":"Denis"}"#.utf8))
            verifica.vero("O18 Impostazioni di un archivio vecchio: occasioni predefinite", generali?.occasioni == ImpostazioniOccasioni())
            let promemoria = try? Archivio.decodificatore.decode(ImpostazioniPromemoria.self, from: Data("{}".utf8))
            verifica.vero("O18 Promemoria di un archivio vecchio: occasioni accese", promemoria?.occasioni == true)
        }

        // O19. Gruppi: tutti accesi; spegnere e riaccendere il fisco lascia l'elenco vuoto
        do {
            var regole = ImpostazioniOccasioni()
            verifica.vero("O19 Gruppi: tutti accesi", GruppoOccasione.allCases.allSatisfy { regole.attivo($0) })
            regole.imposta(.fisco, attivo: false)
            verifica.vero("O19 Fisco spento", !regole.attivo(.fisco) && regole.tipiSpenti == [.scadenzaFiscale])
            regole.imposta(.fisco, attivo: true)
            verifica.vero("O19 Fisco riacceso: nessun tipo spento", regole.tipiSpenti.isEmpty)
        }
    }

    // MARK: - Coerenza con i clienti di prova (O20)

    private static func coerenza(_ verifica: VerificaCalcoli) {
        let dati = DatiPrisma.demo()
        let adesso = Date()
        let fine = cal.date(byAdding: .month, value: 12, to: adesso) ?? adesso
        let e = MotoreOccasioni.calcola(clienti: dati.clienti, posizioni: dati.posizioni, prodotti: dati.prodotti,
                                        da: adesso, a: fine, regole: ImpostazioniOccasioni(), oggi: adesso, cal: cal)
        let perId = Dictionary(dati.posizioni.map { ($0.id, $0) }, uniquingKeysWith: { primo, _ in primo })
        verifica.vero("O20 Clienti di prova: nessun titolo con l'euro", !e.contains { $0.titolo.contains("€") })
        // Il fisco con piani di canali diversi resta senza canale (misto)
        verifica.vero("O20 Clienti di prova: il canale è quello della posizione", e.allSatisfy { o in
            guard let id = o.posizioneId, let p = perId[id] else { return true }
            return o.canale == p.canale || (o.tipo == .scadenzaFiscale && o.canale == nil)
        })
        verifica.vero("O20 Clienti di prova: niente occasioni dalle proposte", !e.contains { o in
            o.posizioneId.flatMap { perId[$0] }.map { $0.stato != .inEssere } ?? false
        })
        verifica.vero("O20 Clienti di prova: identificativi diversi", Set(e.map(\.id)).count == e.count)
    }
}
