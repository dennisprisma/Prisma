import Foundation

/// Prove delle scadenze di conformità («In regola», specifica 3, casi K1–K16): stato a una data, validità dei
/// questionari, adeguata verifica per rischio, voci richieste per canale, documento, privacy, consenso
/// commerciale, scadenza proposta del documento, scheda di adeguatezza, riesame, avvisi, filtri, lettura
/// tollerante e dati di prova. Chiamata da `ProvaCalcoli.esegui()`: gli errori si sommano.
enum ProvaCalcoliConformita {
    static func esegui(_ verifica: VerificaCalcoli) {
        statoEValidita(verifica)
        vociRichieste(verifica)
        documentoEConsensi(verifica)
        schedaERiesame(verifica)
        avvisiEFiltri(verifica)
        lettura(verifica)
        datiDiProva(verifica)
    }

    // MARK: - Aiuti

    private static let cal = Calendar(identifier: .gregorian)
    /// Il giorno delle prove: 28 ottobre 2026.
    private static var oggi: Date { AiutiProva.data(2026, 10, 28) }

    private static func d(_ anno: Int, _ mese: Int, _ giorno: Int) -> Date { AiutiProva.data(anno, mese, giorno) }

    /// Un cliente di prova con i canali indicati e la privacy in regola (salvo diversa indicazione).
    private static func cliente(_ id: String, canali: [Canale] = [], privacy: Bool = true) -> Cliente {
        var c = Cliente(id: id, nome: "Cliente \(id)", iniziali: "CK", tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: d(2024, 1, 1))
        c.canali = canali
        if privacy { c.consensi = Consensi(privacy: true, dataPrivacy: d(2024, 1, 1), marketing: false) }
        return c
    }

    /// Una posizione del cliente di prova.
    private static func posizione(_ id: String, _ area: AreaPosizione, _ canale: Canale, _ stato: StatoPosizione) -> Posizione {
        AiutiProva.posizione("Prova \(area.rawValue)", area, 10_000, canale: canale) {
            $0.clienteId = id
            $0.stato = stato
        }
    }

    private static func calcola(_ c: Cliente, _ p: [Posizione] = [], _ r: RegoleConformita = RegoleConformita()) -> EsitoConformita {
        MotoreConformita.calcola(cliente: c, posizioni: p, regole: r, oggi: oggi, calendario: cal)
    }

    private static func giorni(_ v: VoceConformita?) -> Double { Double(v?.giorni ?? -999) }

    private static func stessoGiorno(_ a: Date?, _ b: Date) -> Bool {
        a.map { cal.isDate($0, inSameDayAs: b) } ?? false
    }

    private static func conformita(_ modifica: (inout ConformitaCliente) -> Void) -> ConformitaCliente {
        var k = ConformitaCliente()
        modifica(&k)
        return k
    }

    // MARK: - K1–K4: stato e validità

    private static func statoEValidita(_ verifica: VerificaCalcoli) {
        // K1. Stato di una scadenza: il giorno della scadenza vale ancora; 30 e 60 compresi
        let casi: [(Date?, VoceConformita.Stato, Int?)] = [
            (d(2026, 10, 27), .scaduta, -1), (d(2026, 10, 28), .entro30, 0), (d(2026, 11, 27), .entro30, 30),
            (d(2026, 11, 28), .entro60, 31), (d(2026, 12, 27), .entro60, 60), (d(2026, 12, 28), .inRegola, 61),
            (nil, .mancante, nil),
        ]
        for (i, caso) in casi.enumerated() {
            let s = MotoreConformita.stato(scadenza: caso.0, oggi: oggi, calendario: cal)
            verifica.vero("K1 Conformità: stato della scadenza \(i + 1)", s.stato == caso.1 && s.giorni == caso.2)
        }

        // K2. Questionario Alleanza del 15/11/2023, regole predefinite: 36 mesi, fino al 15/11/2026
        var k2 = cliente("k", canali: [.alleanza])
        k2.conformita = conformita { $0.questionarioAlleanza = QuestionarioAdeguatezza(compilatoIl: d(2023, 11, 15)) }
        let q2 = calcola(k2).voce(.questionarioAlleanza)
        verifica.vero("K2 Conformità: questionario fino al 15/11/2026", stessoGiorno(q2?.scadenza, d(2026, 11, 15)))
        verifica("K2 Conformità: 18 giorni alla scadenza", giorni(q2), 18, tolleranza: 0)
        verifica.vero("K2 Conformità: entro 30 giorni", q2?.stato == .entro30)
        verifica("K2 Conformità: validità 36 mesi", Double(q2?.mesi ?? 0), 36, tolleranza: 0)

        // K2b. Validità del questionario 24 mesi: scaduto da 347 giorni
        var k2b = k2
        k2b.conformita?.questionarioAlleanza?.validitaMesi = 24
        let q2b = calcola(k2b).voce(.questionarioAlleanza)
        verifica.vero("K2b Conformità: validità propria, fino al 15/11/2025", stessoGiorno(q2b?.scadenza, d(2025, 11, 15)))
        verifica("K2b Conformità: scaduto da 347 giorni", giorni(q2b), -347, tolleranza: 0)
        verifica.vero("K2b Conformità: scaduto", q2b?.stato == .scaduta)

        // K2c. Validità del canale in Impostazioni a 48 mesi
        var r2c = RegoleConformita()
        r2c.mesiQuestionarioAlleanza = 48
        let q2c = calcola(k2, [], r2c).voce(.questionarioAlleanza)
        verifica.vero("K2c Conformità: 48 mesi da Impostazioni, fino al 15/11/2027", stessoGiorno(q2c?.scadenza, d(2027, 11, 15)))
        verifica("K2c Conformità: 383 giorni alla scadenza", giorni(q2c), 383, tolleranza: 0)
        verifica.vero("K2c Conformità: in regola", q2c?.stato == .inRegola)

        // K3. 29 febbraio 2024 + 24 mesi = 28 febbraio 2026
        verifica.vero("K3 Conformità: 29/02/2024 + 24 mesi = 28/02/2026",
                      stessoGiorno(MotoreConformita.aggiungiMesi(24, a: d(2024, 2, 29), calendario: cal), d(2026, 2, 28)))

        // K4. Adeguata verifica Alleanza: rischio alto 12 mesi; senza rischio la periodicità del medio
        func verificaAlleanza(_ data: Date, _ rischio: RischioRiciclaggio?) -> VoceConformita? {
            var c = cliente("k", canali: [.alleanza])
            c.conformita = conformita { $0.verificaAlleanza = AdeguataVerifica(eseguitaIl: data, rischio: rischio) }
            return calcola(c).voce(.verificaAlleanza)
        }
        let v4 = verificaAlleanza(d(2026, 1, 10), .alto)
        verifica.vero("K4 Conformità: rischio alto, fino al 10/01/2027", stessoGiorno(v4?.scadenza, d(2027, 1, 10)))
        verifica("K4 Conformità: 74 giorni alla scadenza", giorni(v4), 74, tolleranza: 0)
        verifica.vero("K4 Conformità: in regola", v4?.stato == .inRegola)
        verifica("K4 Conformità: periodicità 12 mesi", Double(v4?.mesi ?? 0), 12, tolleranza: 0)
        let v4b = verificaAlleanza(d(2025, 11, 10), .alto)
        verifica("K4b Conformità: rischio alto dal 10/11/2025, 13 giorni", giorni(v4b), 13, tolleranza: 0)
        verifica.vero("K4b Conformità: entro 30 giorni", v4b?.stato == .entro30)
        let v4c = verificaAlleanza(d(2024, 12, 1), nil)
        verifica("K4c Conformità: rischio non indicato, 24 mesi", Double(v4c?.mesi ?? 0), 24, tolleranza: 0)
        verifica("K4c Conformità: 34 giorni alla scadenza", giorni(v4c), 34, tolleranza: 0)
        verifica.vero("K4c Conformità: entro 60 giorni con il rischio stimato", v4c?.stato == .entro60 && v4c?.rischioStimato == true)
    }

    // MARK: - K5–K6: voci richieste

    private static func vociRichieste(_ verifica: VerificaCalcoli) {
        // K5. Seguito con Alleanza, con una proposta d'investimento indipendente: servono anche le voci indipendenti
        let alleanza = cliente("k", canali: [.alleanza])
        let proposta = posizione("k", .investimento, .indipendente, .proposta)
        let e5 = calcola(alleanza, [proposta])
        verifica.vero("K5 Conformità: questionario indipendente da raccogliere", e5.voce(.questionarioIndipendente)?.stato == .mancante)
        verifica.vero("K5 Conformità: adeguata verifica indipendente da raccogliere", e5.voce(.verificaIndipendente)?.stato == .mancante)

        // K5b. Solo una posizione indipendente chiusa: il canale non è seguito
        let e5b = calcola(alleanza, [posizione("k", .investimento, .indipendente, .chiusa)])
        verifica.vero("K5b Conformità: posizione chiusa, voci indipendenti non richieste",
                      [e5b.voce(.questionarioIndipendente), e5b.voce(.verificaIndipendente)]
                        .allSatisfy { $0?.stato == .nonRichiesta && $0?.motivo == .canaleNonSeguito })

        // K5c. Senza canali, solo una protezione Alleanza in essere: niente questionario, il documento sì
        let e5c = calcola(cliente("k"), [posizione("k", .protezione, .alleanza, .inEssere)])
        verifica.vero("K5c Conformità: solo protezione, questionario Alleanza non richiesto",
                      e5c.voce(.questionarioAlleanza)?.stato == .nonRichiesta)
        verifica.vero("K5c Conformità: posizione non chiusa, documento da raccogliere", e5c.voce(.documento)?.stato == .mancante)

        // K5d. Adeguata verifica indipendente spenta in Impostazioni
        var r5d = RegoleConformita()
        r5d.verificaIndipendente = false
        let e5d = calcola(alleanza, [proposta], r5d)
        verifica.vero("K5d Conformità: verifica indipendente non tenuta (Impostazioni)",
                      e5d.voce(.verificaIndipendente)?.stato == .nonRichiesta && e5d.voce(.verificaIndipendente)?.motivo == .impostazioni)
        verifica.vero("K5d Conformità: il questionario indipendente resta da raccogliere",
                      e5d.voce(.questionarioIndipendente)?.stato == .mancante)

        // K6. Scelta del consulente: vale per il documento, non per la privacy
        var k6 = cliente("k", canali: [.alleanza], privacy: false)
        k6.conformita = conformita { $0.nonRichieste = ["documento", "privacy"] }
        let e6 = calcola(k6)
        verifica.vero("K6 Conformità: documento non richiesto per scelta",
                      e6.voce(.documento)?.stato == .nonRichiesta && e6.voce(.documento)?.motivo == .sceltaConsulente)
        verifica.vero("K6 Conformità: la privacy resta da raccogliere", e6.voce(.privacy)?.stato == .mancante)
    }

    // MARK: - K7–K10: documento e consensi

    private static func documentoEConsensi(_ verifica: VerificaCalcoli) {
        // K7. Documento con la scadenza scritta
        var k7 = cliente("k", canali: [.alleanza])
        k7.conformita = conformita { $0.documento = DocumentoIdentita(tipo: .cartaIdentita, scadenza: d(2026, 11, 17)) }
        let v7 = calcola(k7).voce(.documento)
        verifica("K7 Conformità: documento, 20 giorni alla scadenza", giorni(v7), 20, tolleranza: 0)
        verifica.vero("K7 Conformità: documento entro 30 giorni", v7?.stato == .entro30)
        var k7b = k7
        k7b.conformita?.documento?.scadenza = nil
        verifica.vero("K7b Conformità: documento senza scadenza da raccogliere", calcola(k7b).voce(.documento)?.stato == .mancante)
        let e7c = calcola(cliente("k", privacy: false))
        verifica.vero("K7c Conformità: nessun canale né posizione, documento non richiesto",
                      e7c.voce(.documento)?.stato == .nonRichiesta && e7c.voce(.documento)?.motivo == .clienteNonSeguito)
        verifica.vero("K7c Conformità: privacy da raccogliere", e7c.voce(.privacy)?.stato == .mancante)

        // K8. Informativa aggiornata dopo la firma: da riconsegnare
        var r8 = RegoleConformita()
        r8.informativaAggiornataIl = d(2026, 6, 1)
        var k8 = cliente("k")
        k8.consensi = Consensi(privacy: true, dataPrivacy: d(2025, 3, 1), marketing: false)
        let v8 = calcola(k8, [], r8).voce(.privacy)
        verifica.vero("K8 Conformità: informativa da riconsegnare", v8?.stato == .scaduta && stessoGiorno(v8?.scadenza, d(2026, 6, 1)))
        verifica("K8 Conformità: 149 giorni dall'aggiornamento", giorni(v8), -149, tolleranza: 0)
        k8.consensi.dataPrivacy = d(2026, 7, 1)
        verifica.vero("K8b Conformità: firmata dopo l'aggiornamento, in regola", calcola(k8, [], r8).voce(.privacy)?.stato == .inRegola)

        // K9. Consenso commerciale dato il 20/12/2024, da riconfermare ogni 24 mesi
        var k9 = cliente("k")
        k9.consensi.marketing = true
        k9.consensi.dataMarketing = d(2024, 12, 20)
        let v9 = calcola(k9).voce(.commerciale)
        verifica.vero("K9 Conformità: commerciale fino al 20/12/2026", stessoGiorno(v9?.scadenza, d(2026, 12, 20)))
        verifica("K9 Conformità: 53 giorni alla riconferma", giorni(v9), 53, tolleranza: 0)
        verifica.vero("K9 Conformità: entro 60 giorni", v9?.stato == .entro60)
        var r9b = RegoleConformita()
        r9b.mesiCommerciale = 0
        let v9b = calcola(k9, [], r9b).voce(.commerciale)
        verifica.vero("K9b Conformità: «Non scade», in regola senza scadenza", v9b?.stato == .inRegola && v9b?.scadenza == nil)
        var k9c = k9
        k9c.consensi.marketing = false
        let v9c = calcola(k9c).voce(.commerciale)
        verifica.vero("K9c Conformità: consenso non dato, non richiesto", v9c?.stato == .nonRichiesta && v9c?.motivo == .consensoNonDato)
        var k9d = k9
        k9d.consensi.dataMarketing = nil
        verifica.vero("K9d Conformità: consenso senza data da raccogliere", calcola(k9d).voce(.commerciale)?.stato == .mancante)

        // K10. Scadenza proposta del documento
        let nascita = d(1989, 3, 14)
        verifica.vero("K10 Conformità: carta d'identità di un adulto, fino al compleanno dopo 10 anni",
                      stessoGiorno(MotoreConformita.scadenzaProposta(tipo: .cartaIdentita, rilascio: d(2020, 3, 5), nascita: nascita,
                                                                     calendario: cal), d(2030, 3, 14)))
        verifica.vero("K10b Conformità: carta d'identità a 9 anni, 5 anni fino al compleanno",
                      stessoGiorno(MotoreConformita.scadenzaProposta(tipo: .cartaIdentita, rilascio: d(2022, 2, 1), nascita: d(2012, 5, 10),
                                                                     calendario: cal), d(2027, 5, 10)))
        verifica.vero("K10c Conformità: passaporto, 10 anni dal rilascio",
                      stessoGiorno(MotoreConformita.scadenzaProposta(tipo: .passaporto, rilascio: d(2020, 3, 5), nascita: nascita,
                                                                     calendario: cal), d(2030, 3, 5)))
        verifica.vero("K10d Conformità: patente e carta senza nascita, nessuna proposta",
                      MotoreConformita.scadenzaProposta(tipo: .patente, rilascio: d(2020, 3, 5), nascita: nascita, calendario: cal) == nil
                        && MotoreConformita.scadenzaProposta(tipo: .cartaIdentita, rilascio: d(2020, 3, 5), nascita: nil, calendario: cal) == nil)
    }

    // MARK: - K11–K12: scheda di adeguatezza e riesame

    private static func schedaERiesame(_ verifica: VerificaCalcoli) {
        // K11. Per la scheda: questionario scaduto (blocca), documento in regola, verifica mancante (non blocca)
        var k11 = cliente("k", canali: [.alleanza])
        k11.conformita = conformita {
            $0.questionarioAlleanza = QuestionarioAdeguatezza(compilatoIl: d(2023, 1, 10))
            $0.documento = DocumentoIdentita(tipo: .cartaIdentita, scadenza: d(2030, 1, 1))
        }
        let s11 = MotoreConformita.perScheda(calcola(k11), canale: .alleanza, firmaIl: nil, calendario: cal)
        verifica.vero("K11 Conformità: la scheda non è pronta", !s11.pronta)
        verifica.vero("K11 Conformità: blocca solo il questionario", s11.bloccanti.map(\.tipo) == [.questionarioAlleanza])
        verifica("K11 Conformità: 4 voci per la scheda (niente commerciale)", Double(s11.voci.count), 4, tolleranza: 0)
        verifica("K11 Conformità: un avviso", Double(s11.avvisi.count), 1, tolleranza: 0)

        // K11b. Questionario valido fino al 15/11/2026 e firma prevista il 20/11/2026
        var k11b = k11
        k11b.conformita?.questionarioAlleanza?.compilatoIl = d(2023, 11, 15)
        let s11b = MotoreConformita.perScheda(calcola(k11b), canale: .alleanza, firmaIl: d(2026, 11, 20), calendario: cal)
        verifica.vero("K11b Conformità: la scheda è pronta", s11b.pronta)
        verifica("K11b Conformità: un avviso (scade prima della firma)", Double(s11b.avvisi.count), 1, tolleranza: 0)

        // K12. Punti del riesame: questionario Alleanza scaduto, documento entro 30, verifica Alleanza mancante
        var k12 = cliente("k", canali: [.alleanza])
        k12.conformita = conformita {
            $0.questionarioAlleanza = QuestionarioAdeguatezza(compilatoIl: d(2023, 1, 10))
            $0.documento = DocumentoIdentita(tipo: .cartaIdentita, scadenza: d(2026, 11, 17))
        }
        let e12 = calcola(k12)
        let punti = MotoreRiesame.puntiConformita(e12)
        verifica("K12 Conformità: 3 punti nel riesame", Double(punti.count), 3, tolleranza: 0)
        verifica.vero("K12 Conformità: priorità alta, media, bassa", punti.map(\.priorita) == [.alta, .media, .bassa])
        verifica.vero("K12 Conformità: tutti nel tema «In regola»", punti.allSatisfy { $0.tema == .conformita })
        verifica.vero("K12 Conformità: il primo è del canale Alleanza", punti.first?.canale == .alleanza)
        verifica.vero("K12 Conformità: titolo del primo punto",
                      punti.first?.titolo == "Questionario di adeguatezza Alleanza da rinnovare")
        let domande = MotoreRiesame.domandeConformita(e12)
        verifica("K12b Conformità: 2 domande", Double(domande.count), 2, tolleranza: 0)
        verifica.vero("K12b Conformità: la prima sul questionario", domande.first?.contains("questionario di adeguatezza (Alleanza)") == true)
        verifica.vero("K12b Conformità: la seconda sul documento",
                      domande.dropFirst().first?.hasPrefix("Può portare un documento d'identità valido?") == true)
    }

    // MARK: - K13–K14: avvisi e filtri

    private static func avvisiEFiltri(_ verifica: VerificaCalcoli) {
        // Quattro clienti con il consenso commerciale scaduto (il primo anche con il questionario Alleanza)
        func scaduto(_ id: String, _ giorno: Int) -> EsitoConformita {
            var c = cliente(id)
            c.consensi.marketing = true
            c.consensi.dataMarketing = d(2024, 1, giorno)
            if id == "s1" {
                c.canali = [.alleanza]
                c.conformita = conformita { $0.questionarioAlleanza = QuestionarioAdeguatezza(compilatoIl: d(2022, 1, 5)) }
            }
            return calcola(c)
        }
        // Un cliente con il documento entro 5 giorni, due con il consenso commerciale entro 60 giorni
        var vicino = cliente("d", canali: [.alleanza])
        vicino.conformita = conformita { $0.documento = DocumentoIdentita(tipo: .cartaIdentita, scadenza: d(2026, 11, 2)) }
        func entro60(_ id: String, _ giorno: Int) -> EsitoConformita {
            var c = cliente(id)
            c.consensi.marketing = true
            c.consensi.dataMarketing = d(2024, 12, giorno)
            return calcola(c)
        }
        let scaduti = [scaduto("s1", 10), scaduto("s2", 11), scaduto("s3", 12), scaduto("s4", 13)]
        let altri = [calcola(vicino), entro60("e1", 10), entro60("e2", 15)]

        // K13. Più di tre clienti scaduti: un avviso solo che apre la ricerca
        let a13 = MotoreConformita.avvisi(scaduti + altri, oggi: oggi, calendario: cal)
        verifica("K13 Conformità: 3 avvisi", Double(a13.count), 3, tolleranza: 0)
        if a13.count == 3 {
            verifica.vero("K13 Conformità: scadute in un avviso con la ricerca",
                          a13[0].urgenza == .scaduta && a13[0].testoRicerca == "conformita:scaduta"
                            && a13[0].id.hasPrefix("conformita-scaduta-") && a13[0].clienteId == nil)
            verifica.vero("K13 Conformità: entro 30 giorni per il cliente", a13[1].urgenza == .entro30 && a13[1].clienteId == "d")
            verifica("K13 Conformità: 5 giorni alla scadenza", Double(a13[1].giorni), 5, tolleranza: 0)
            verifica.vero("K13 Conformità: tra 31 e 60 giorni un avviso con la ricerca",
                          a13[2].urgenza == .entro60 && a13[2].testoRicerca == "conformita:inscadenza" && a13[2].clienteId == nil)
        }

        // K13b. Due clienti scaduti: un avviso ciascuno, con la scadenza più vecchia del cliente
        let a13b = MotoreConformita.avvisi(Array(scaduti.prefix(2)) + altri, oggi: oggi, calendario: cal).filter { $0.urgenza == .scaduta }
        verifica("K13b Conformità: 2 avvisi di scadute", Double(a13b.count), 2, tolleranza: 0)
        verifica.vero("K13b Conformità: un avviso per cliente", a13b.allSatisfy { $0.clienteId != nil && $0.testoRicerca == nil })
        verifica.vero("K13b Conformità: la data è la scadenza più vecchia (questionario del 05/01/2025)",
                      stessoGiorno(a13b.first { $0.clienteId == "s1" }?.data, d(2025, 1, 5)))
        verifica.vero("K13b Conformità: il cliente con due voci ha il titolo al plurale",
                      a13b.first { $0.clienteId == "s1" }?.titolo == "Cliente s1: 2 scadenze di conformità superate")

        // K14. Filtri della ricerca
        let soloAlleanza = scaduti[0]
        var conIndipendente = cliente("i", canali: [.indipendente])
        conIndipendente.conformita = conformita { $0.questionarioIndipendente = QuestionarioAdeguatezza(compilatoIl: d(2022, 1, 5)) }
        let eIndipendente = calcola(conIndipendente)
        var senzaScadute = cliente("n", canali: [])
        senzaScadute.consensi.marketing = false
        let eSenza = calcola(senzaScadute)
        let e5 = calcola(cliente("k", canali: [.alleanza]), [posizione("k", .investimento, .indipendente, .proposta)])
        verifica.vero("K14 Conformità: «scaduta» per chi ha voci scadute",
                      MotoreConformita.rispetta(soloAlleanza, .scaduta) && !MotoreConformita.rispetta(eSenza, .scaduta))
        verifica.vero("K14 Conformità: con il canale indipendente, il questionario Alleanza scaduto non conta",
                      !MotoreConformita.rispetta(calcola(clienteSoloQuestionarioAlleanza()), .scaduta, canale: .indipendente))
        verifica.vero("K14 Conformità: il questionario indipendente scaduto conta sul suo canale",
                      MotoreConformita.rispetta(eIndipendente, .scaduta, canale: .indipendente)
                        && !MotoreConformita.rispetta(eIndipendente, .scaduta, canale: .alleanza))
        verifica.vero("K14 Conformità: «mancante» per il caso K5", MotoreConformita.rispetta(e5, .mancante))
        verifica.vero("K14 Conformità: «da sistemare» comprende le mancanti", MotoreConformita.rispetta(e5, .daSistemare))
        verifica.vero("K14 Conformità: estratto della ricerca",
                      TestiConformita.estrattoRicerca(soloAlleanza, filtro: .scaduta, canale: nil)?.hasPrefix("Questionario Alleanza scaduto il") == true)
    }

    /// Un cliente Alleanza con solo il questionario scaduto (privacy in regola, nessun consenso commerciale).
    private static func clienteSoloQuestionarioAlleanza() -> Cliente {
        var c = cliente("a", canali: [.alleanza])
        c.conformita = conformita {
            $0.questionarioAlleanza = QuestionarioAdeguatezza(compilatoIl: d(2022, 1, 5))
            $0.verificaAlleanza = AdeguataVerifica(eseguitaIl: d(2026, 1, 5), rischio: .basso)
            $0.documento = DocumentoIdentita(tipo: .cartaIdentita, scadenza: d(2030, 1, 1))
        }
        return c
    }

    // MARK: - K15: lettura tollerante

    private static func lettura(_ verifica: VerificaCalcoli) {
        var piena = ConformitaCliente()
        piena.questionarioAlleanza = QuestionarioAdeguatezza(compilatoIl: d(2025, 3, 1), validitaMesi: 24, esito: "Moderato")
        piena.questionarioIndipendente = QuestionarioAdeguatezza(compilatoIl: d(2025, 4, 1))
        piena.verificaAlleanza = AdeguataVerifica(eseguitaIl: d(2025, 5, 1), rischio: .alto)
        piena.verificaIndipendente = AdeguataVerifica(eseguitaIl: d(2025, 6, 1), rischio: nil)
        piena.documento = DocumentoIdentita(tipo: .passaporto, numero: "YA1234567", rilasciatoIl: d(2020, 1, 1), scadenza: d(2030, 1, 1))
        piena.nonRichieste = ["commerciale"]
        var dati = DatiPrisma.demo()
        dati.clienti[0].conformita = piena
        dati.clienti[0].consensi.dataMarketing = d(2025, 2, 1)
        dati.impostazioni.conformita.mesiVerificaAlto = 6
        let riletti = (try? Archivio.codificatore.encode(dati)).flatMap { try? Archivio.decodifica($0) }
        verifica.vero("K15 Conformità: la conformità piena torna uguale dall'archivio", riletti?.clienti.first?.conformita == piena)
        verifica.vero("K15 Conformità: la data del consenso commerciale torna uguale",
                      riletti?.clienti.first?.consensi.dataMarketing == d(2025, 2, 1))
        verifica.vero("K15 Conformità: le regole tornano uguali", riletti?.impostazioni.conformita == dati.impostazioni.conformita)

        let json = Data(#"{"eseguitaIl":"2026-01-10T12:00:00Z","rischio":"altissimo"}"#.utf8)
        let v = try? Archivio.decodificatore.decode(AdeguataVerifica.self, from: json)
        verifica.vero("K15 Conformità: un rischio sconosciuto si legge come non indicato", v != nil && v?.rischio == nil && v?.eseguitaIl != nil)
        let regole = try? Archivio.decodificatore.decode(RegoleConformita.self, from: Data("{}".utf8))
        verifica.vero("K15 Conformità: regole vuote ai valori predefiniti", regole == RegoleConformita())
        let letto = try? Archivio.decodificatore.decode(Cliente.self, from: Data(#"{"id":"x","nome":"X","conformita":{"documento":12}}"#.utf8))
        verifica.vero("K15 Conformità: una conformità illeggibile non fa perdere il cliente", letto != nil && letto?.conformita == nil)
    }

    // MARK: - K16: dati di prova

    private static func datiDiProva(_ verifica: VerificaCalcoli) {
        let dati = DatiPrisma.demo()
        let esiti = MotoreConformita.calcola(clienti: dati.clienti, posizioni: dati.posizioni, regole: RegoleConformita(),
                                             oggi: AiutiProva.oggi, calendario: cal)
        func esito(_ id: String) -> EsitoConformita? { esiti.first { $0.cliente.id == id } }
        func tipi(_ voci: [VoceConformita]?) -> [VoceConformita.Tipo] { voci?.map(\.tipo) ?? [] }

        let giulia = esito("giulia")
        verifica.vero("K16 Conformità: giulia, commerciale scaduto", tipi(giulia?.scadute) == [.commerciale])
        verifica.vero("K16 Conformità: giulia, documento entro 30 giorni", tipi(giulia?.entro30) == [.documento])
        verifica.vero("K16 Conformità: giulia, questionario Alleanza entro 60 giorni", tipi(giulia?.entro60) == [.questionarioAlleanza])
        verifica.vero("K16 Conformità: giulia, il resto in regola",
                      [VoceConformita.Tipo.questionarioIndipendente, .verificaIndipendente, .verificaAlleanza]
                        .allSatisfy { giulia?.voce($0)?.stato == .inRegola })
        let marco = esito("marco")
        verifica.vero("K16 Conformità: marco, questionario e verifica Alleanza scaduti",
                      tipi(marco?.scadute) == [.questionarioAlleanza, .verificaAlleanza])
        verifica.vero("K16 Conformità: marco, voci indipendenti non richieste",
                      marco?.voce(.questionarioIndipendente)?.stato == .nonRichiesta && marco?.voce(.verificaIndipendente)?.stato == .nonRichiesta)
        verifica.vero("K16 Conformità: laura in regola", esito("laura")?.inRegola == true)
        verifica.vero("K16 Conformità: andrea, tre voci da raccogliere",
                      tipi(esito("andrea")?.mancanti) == [.questionarioAlleanza, .verificaAlleanza, .documento])
        let sofia = esito("sofia")
        verifica.vero("K16 Conformità: sofia, documento scaduto", tipi(sofia?.scadute) == [.documento])
        verifica.vero("K16 Conformità: sofia, verifica Alleanza entro 60 giorni", tipi(sofia?.entro60) == [.verificaAlleanza])

        let avvisi = MotoreConformita.avvisi(esiti, oggi: AiutiProva.oggi, calendario: cal)
        let scadute = avvisi.filter { $0.urgenza == .scaduta }
        verifica("K16 Conformità: 3 avvisi di scadute", Double(scadute.count), 3, tolleranza: 0)
        verifica.vero("K16 Conformità: scadute di giulia, marco e sofia",
                      Set(scadute.compactMap(\.clienteId)) == ["giulia", "marco", "sofia"])
        let entro30 = avvisi.filter { $0.urgenza == .entro30 }
        verifica.vero("K16 Conformità: entro 30 giorni il documento di giulia", entro30.count == 1 && entro30.first?.clienteId == "giulia")
        let entro60 = avvisi.filter { $0.urgenza == .entro60 }
        verifica.vero("K16 Conformità: entro 60 giorni un avviso per due clienti",
                      entro60.count == 1 && entro60.first?.clienteId == nil
                        && entro60.first?.titolo == "2 scadenze di conformità nei prossimi 60 giorni")
    }
}
