import Foundation

/// Prove dell'aggiornamento dei valori in blocco (giro 5, specifica 8, §7): lettura dell'elenco, abbinamento,
/// catena per posizione, variazioni, registrazione, griglia dei valori fermi, Excel, importazione e testi.
/// Chiamate da `ProvaCalcoli.esegui()`: gli errori si sommano. Date fisse: oggi è il 29 ottobre 2026 (ore 12).
/// Valori attesi calcolati con `calcoli_valori.py`.
enum ProvaCalcoliAggiornaValori {
    static func esegui(_ verifica: VerificaCalcoli) {
        colonne(verifica)
        elenco(verifica)
        casiSingoli(verifica)
        griglia(verifica)
        excel(verifica)
        importazione(verifica)
        testi(verifica)
    }

    // MARK: - Dati delle prove (§7.1)

    private typealias AV = AggiornaValori

    private static let oggi = AiutiProva.data(2026, 10, 29)

    private static func d(_ anno: Int, _ mese: Int, _ giorno: Int) -> Date { AiutiProva.data(anno, mese, giorno) }

    private static func stessoGiorno(_ a: Date?, _ b: Date) -> Bool {
        a.map { Calendar.current.isDate($0, inSameDayAs: b) } ?? false
    }

    private static func cliente(_ id: String, _ nome: String, codiceFiscale: String = "") -> Cliente {
        var c = Cliente(id: id, nome: nome, iniziali: "", tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: AiutiProva.data(2019, 1, 1))
        c.codiceFiscale = codiceFiscale
        return c
    }

    private static let clienti: [Cliente] = [
        cliente("av-anna", "Anna Verdi", codiceFiscale: "VRDNNA80A41H501X"),
        cliente("av-bruno", "Bruno Neri"),
        cliente("av-carla", "Carla Neri"),
    ]

    private static func posizione(_ id: String, _ cliente: String, _ canale: Canale, _ stato: StatoPosizione,
                                  _ area: AreaPosizione, _ nome: String, numero: String = "", valore: Double,
                                  data: Date?, versato: Double? = nil,
                                  _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        var p = Posizione(id: id, clienteId: "av-\(cliente)", canale: canale, stato: stato, area: area, nome: nome)
        p.numeroContratto = numero
        p.controvalore = valore
        p.dataValore = data
        p.totaleVersato = versato
        p.creataIl = AiutiProva.data(2019, 1, 10)
        modifica(&p)
        return p
    }

    private static var posizioni: [Posizione] {
        [
            posizione("av-p1", "anna", .alleanza, .inEssere, .risparmio, "Piano rivalutabile", numero: "AL-2019-000111",
                      valore: 20_000, data: d(2025, 9, 30), versato: 18_000) {
                $0.premio = 100
                $0.frequenza = .mensile
                $0.tipologia = "Polizza rivalutabile (Ramo I)"
            },
            posizione("av-p2", "anna", .indipendente, .inEssere, .investimento, "ETF globale",
                      valore: 10_000, data: d(2025, 6, 30), versato: 9_000),
            posizione("av-p3", "bruno", .alleanza, .inEssere, .investimento, "Multiramo", numero: "AL-2021-000222",
                      valore: 50_000, data: d(2026, 3, 31), versato: 48_000) {
                $0.tipologia = "Polizza multiramo (Ramo I e Ramo III)"
                $0.quotaGestioneSeparata = 40
            },
            posizione("av-p4", "bruno", .alleanza, .inEssere, .protezione, "Temporanea caso morte", numero: "AL-2022-000333",
                      valore: 0, data: d(2025, 9, 30)),
            posizione("av-p5", "carla", .alleanza, .chiusa, .risparmio, "Polizza scaduta", numero: "AL-2010-000444",
                      valore: 15_000, data: d(2025, 9, 30)),
            posizione("av-p6", "carla", .indipendente, .inEssere, .investimento, "Fondo bilanciato",
                      valore: 8_000, data: d(2025, 10, 15), versato: 8_000),
            posizione("av-p7", "carla", .indipendente, .inEssere, .investimento, "Fondo bilanciato",
                      valore: 5_000, data: d(2025, 10, 15), versato: 5_000),
            posizione("av-p8", "anna", .indipendente, .inEssere, .liquidita, "Conto corrente",
                      valore: 3_000, data: d(2026, 10, 1)),
            posizione("av-p9", "bruno", .indipendente, .inEssere, .debiti, "Mutuo",
                      valore: 90_000, data: d(2024, 1, 1)),
            posizione("av-p10", "bruno", .indipendente, .inEssere, .previdenza, "Fondo pensione",
                      valore: 12_000, data: nil, versato: 11_000) {
                $0.creataIl = AiutiProva.data(2024, 1, 10)
            },
            posizione("av-p11", "anna", .indipendente, .inEssere, .liquidita, "Conto deposito",
                      valore: 6_000, data: d(2025, 10, 29)),
            posizione("av-p12", "anna", .indipendente, .inEssere, .immobili, "Casa",
                      valore: 200_000, data: nil),
        ]
    }

    private static let csv = """
        Contraente;Codice fiscale;Numero polizza;Prodotto;Valore di riscatto;Data valore;Totale premi versati;Valore gestione separata
        Anna Verdi;VRDNNA80A41H501X;AL-2019-000111;Piano rivalutabile;20.900,00;30/09/2026;19.200,00;
        Anna Verdi;;;ETF globale;11.500;;;
        Bruno Neri;;AL 2021 000222;Multiramo;52.000,00;30/09/2026;;22.100,00
        Bruno Neri;;AL-2022-000333;Temporanea caso morte;0;30/09/2026;;
        Carla Neri;;AL-2010-000444;Polizza scaduta;15.500;30/09/2026;;
        Carla Neri;;;Fondo bilanciato;8.400;30/09/2026;;
        Dario Gialli;;AL-2024-000999;Piano nuovo;5.000;30/09/2026;;
        Anna Verdi;VRDNNA80A41H501X;AL-2019-000111;Piano rivalutabile;20.100,00;31/03/2026;18.600,00;
        Anna Verdi;VRDNNA80A41H501X;AL-2019-000111;Piano rivalutabile;20.900,00;30/09/2026;19.200,00;
        Bruno Neri;;AL-2021-000222;Multiramo;80.000;31/10/2026;;
        Bruno Neri;;AL-2021-000222;Multiramo;49.000;31/12/2025;;
        Bruno Neri;;AL-2021-000222;Multiramo;50.000;31/03/2026;;
        Carla Neri;;AL-2019-000111;Piano rivalutabile;20.900;30/09/2026;;
        Anna Verdi;;;Conto deposito;abc;;;

        """

    private static var tabella: [[String]] { ImportaClienti.righeCSV(csv) }

    /// L'esito della riga `id` (numero della riga sotto l'intestazione).
    private static func riga(_ esiti: [AV.Esito], _ id: Int) -> AV.Esito? { esiti.first { $0.id == id } }

    private static func cerca(_ elenco: [Posizione], _ id: String) -> Posizione? { elenco.first { $0.id == id } }

    /// Un valore passato con quell'importo, quel giorno e (se indicato) quel versato.
    private static func rilevazione(_ r: Rilevazione, _ valore: Double, _ giorno: Date, versato: Double? = nil) -> Bool {
        guard abs(r.controvalore - valore) < 0.005, stessoGiorno(r.data, giorno) else { return false }
        guard let versato else { return true }
        guard let suo = r.versato else { return false }
        return abs(suo - versato) < 0.005
    }

    /// Gli esiti di una tabella CSV di poche righe, con la data comune di oggi.
    private static func esitiDi(_ testo: String, posizioni: [Posizione], scelte: [Int: String] = [:]) -> [AV.Esito] {
        AV.esiti(AV.righe(ImportaClienti.righeCSV(testo)).righe, posizioni: posizioni, clienti: clienti,
                 dataComune: oggi, oggi: oggi, scelte: scelte)
    }

    // MARK: - AV1: colonne

    private static func colonne(_ verifica: VerificaCalcoli) {
        typealias C = ImportaPosizioni.Colonna
        verifica.vero("AV1 Colonna «Valore gestione separata» → valoreGestione", C.da("Valore gestione separata") == .valoreGestione)
        verifica.vero("AV1 Colonna «Valore di riscatto» → controvalore", C.da("Valore di riscatto") == .controvalore)
        verifica.vero("AV1 Colonna «Valore» → controvalore", C.da("Valore") == .controvalore)
        verifica.vero("AV1 Colonna «Totale premi versati» → versato", C.da("Totale premi versati") == .versato)
        verifica.vero("AV1 Colonna «Numero polizza» → numeroContratto", C.da("Numero polizza") == .numeroContratto)
    }

    // MARK: - AV2–AV18: l'elenco della compagnia

    private static func elenco(_ verifica: VerificaCalcoli) {
        let base = posizioni
        let letto = AV.righe(tabella)
        let righe = letto.righe

        // AV2. Lettura
        verifica("AV2 Righe lette dall'elenco", Double(righe.count), 14)
        verifica.vero("AV2 Id delle righe da 1 a 14", righe.map(\.id) == Array(1...14))
        verifica.vero("AV2 Colonne del valore e della gestione separata riconosciute",
                      letto.colonne.contains(.valoreGestione) && letto.colonne.contains(.controvalore))
        verifica("AV2 Riga 3: valore", righe.first { $0.id == 3 }?.valore ?? -1, 52_000)
        verifica("AV2 Riga 3: valore in gestione separata", righe.first { $0.id == 3 }?.valoreGestione ?? -1, 22_100)
        verifica.vero("AV2 Riga 2: senza data, leggibile",
                      righe.first { $0.id == 2 }.map { $0.data == nil && !$0.dataIllegibile } ?? false)
        verifica.vero("AV2 Riga 14: valore illeggibile", righe.first { $0.id == 14 }.map { $0.valore == nil } ?? false)

        // AV3. Stati
        let e = AV.esiti(righe, posizioni: base, clienti: clienti, dataComune: oggi, oggi: oggi)
        let attesi: [AV.Stato] = [.aggiorna, .aggiorna, .aggiorna, .copertura, .nonInEssere, .daScegliere, .nonTrovata,
                                  .aggiorna, .ripetuta, .dataFutura, .storico, .giaRegistrato, .daScegliere, .senzaValore]
        verifica.vero("AV3 Stati delle 14 righe (\(e.map(\.stato.rawValue)))", e.map(\.stato) == attesi)

        // AV4. Abbinamenti
        verifica.vero("AV4 Riga 1 dal numero", riga(e, 1)?.abbinamento == .numero)
        verifica.vero("AV4 Riga 3 dal numero, malgrado gli spazi", riga(e, 3)?.abbinamento == .numero && riga(e, 3)?.posizioneId == "av-p3")
        verifica.vero("AV4 Riga 2 dal nome", riga(e, 2)?.abbinamento == .nome && riga(e, 2)?.posizioneId == "av-p2")
        verifica.vero("AV4 Riga 6: candidate p6 e p7", riga(e, 6)?.candidate == ["av-p6", "av-p7"])
        verifica.vero("AV4 Riga 13: candidata la p1 di Anna", riga(e, 13)?.candidate == ["av-p1"])

        // AV5. Riga 8, la prima della catena di p1
        let r8 = riga(e, 8)
        verifica("AV5 Riga 8: valore di prima", r8?.precedente ?? -1, 20_000)
        verifica("AV5 Riga 8: variazione", r8?.variazione ?? -1, 100)
        verifica("AV5 Riga 8: variazione %", r8?.variazionePct ?? -1, 0.5)
        verifica("AV5 Riga 8: versamenti", r8?.versamenti ?? -1, 600)
        verifica("AV5 Riga 8: al netto dei versamenti", r8?.risultato ?? 0, -500)
        verifica("AV5 Riga 8: al netto %", r8?.risultatoPct ?? 0, -2.5)
        verifica.vero("AV5 Riga 8: non insolita", r8?.insolita == false)

        // AV6. Riga 1, dopo la riga 8
        let r1 = riga(e, 1)
        verifica("AV6 Riga 1: valore di prima (dalla riga 8)", r1?.precedente ?? -1, 20_100)
        verifica.vero("AV6 Riga 1: data di prima 31/03/2026", stessoGiorno(r1?.dataPrecedente, d(2026, 3, 31)))
        verifica("AV6 Riga 1: variazione", r1?.variazione ?? -1, 800)
        verifica("AV6 Riga 1: variazione %", r1?.variazionePct ?? -1, 3.9801, tolleranza: 0.001)
        verifica("AV6 Riga 1: versamenti", r1?.versamenti ?? -1, 600)
        verifica("AV6 Riga 1: al netto", r1?.risultato ?? -1, 200)
        verifica("AV6 Riga 1: al netto %", r1?.risultatoPct ?? -1, 0.995, tolleranza: 0.001)

        // AV7. Riga 2, l'ETF dal nome con la data comune
        let r2 = riga(e, 2)
        verifica.vero("AV7 Riga 2: data comune 29/10/2026", stessoGiorno(r2?.data, oggi))
        verifica("AV7 Riga 2: valore di prima", r2?.precedente ?? -1, 10_000)
        verifica("AV7 Riga 2: variazione", r2?.variazione ?? -1, 1_500)
        verifica("AV7 Riga 2: variazione %", r2?.variazionePct ?? -1, 15)
        verifica("AV7 Riga 2: versamenti", r2?.versamenti ?? -1, 0)
        verifica("AV7 Riga 2: al netto", r2?.risultato ?? -1, 1_500)
        verifica("AV7 Riga 2: mesi", Double(r2?.mesi ?? -1), 15)
        verifica.vero("AV7 Riga 2: versato non stimato", r2?.versatoStimato == false)

        // AV8. Riga 3, la multiramo
        let r3 = riga(e, 3)
        verifica("AV8 Riga 3: variazione", r3?.variazione ?? -1, 2_000)
        verifica("AV8 Riga 3: variazione %", r3?.variazionePct ?? -1, 4)
        verifica("AV8 Riga 3: versamenti", r3?.versamenti ?? -1, 0)
        verifica("AV8 Riga 3: quota in gestione separata", r3?.quotaGestione ?? -1, 42.5)

        // AV9. Storico e già registrato
        verifica.vero("AV9 Riga 11 nello storico, senza variazione", riga(e, 11)?.stato == .storico && riga(e, 11)?.variazione == nil)
        verifica.vero("AV9 Riga 12 già registrata", riga(e, 12)?.stato == .giaRegistrato)

        // AV10. Nessuna riga parte esclusa
        verifica.vero("AV10 Nessuna esclusione iniziale", AV.esclusiIniziali(e).isEmpty)

        // AV11. Registrazione
        var pos = base
        let r = AV.applica(e, esclusi: [], a: &pos)
        verifica("AV11 Valori attuali registrati", Double(r.attuali), 4)
        verifica("AV11 Valori nello storico", Double(r.storico), 1)
        verifica.vero("AV11 Posizioni toccate (\(r.posizioni))", r.posizioni == ["av-p1", "av-p2", "av-p3"])
        verifica("AV11 Totale prima", r.totale.prima, 80_000)
        verifica("AV11 Totale dopo", r.totale.dopo, 84_400)
        verifica("AV11 Variazione", r.totale.variazione, 4_400)
        verifica("AV11 Variazione %", r.totale.variazionePct ?? -1, 5.5)
        verifica("AV11 Versamenti", r.totale.versamenti, 1_200)
        verifica("AV11 Al netto dei versamenti", r.totale.risultato, 3_200)
        verifica("AV11 Al netto %", r.totale.risultatoPct ?? -1, 4.0)

        // AV12. Per canale
        let alleanza = r.perCanale[.alleanza]
        let indipendente = r.perCanale[.indipendente]
        verifica("AV12 Alleanza: posizioni", Double(alleanza?.posizioni ?? -1), 2)
        verifica("AV12 Alleanza: prima", alleanza?.prima ?? -1, 70_000)
        verifica("AV12 Alleanza: dopo", alleanza?.dopo ?? -1, 72_900)
        verifica("AV12 Alleanza: versamenti", alleanza?.versamenti ?? -1, 1_200)
        verifica("AV12 Indipendente: posizioni", Double(indipendente?.posizioni ?? -1), 1)
        verifica("AV12 Indipendente: prima", indipendente?.prima ?? -1, 10_000)
        verifica("AV12 Indipendente: dopo", indipendente?.dopo ?? -1, 11_500)
        verifica("AV12 Indipendente: versamenti", indipendente?.versamenti ?? -1, 0)

        // AV13. p1 dopo
        let p1 = cerca(pos, "av-p1")
        verifica("AV13 p1: valore", p1?.controvalore ?? -1, 20_900)
        verifica.vero("AV13 p1: data del valore 30/09/2026", stessoGiorno(p1?.dataValore, d(2026, 9, 30)))
        verifica("AV13 p1: versato", p1?.totaleVersato ?? -1, 19_200)
        verifica("AV13 p1: punti dello storico", Double(p1?.storicoValori.count ?? -1), 3)
        let ril1 = p1?.rilevazioni ?? []
        // Condizioni a pezzi: catene lunghe di confronti con i letterali rallentano il controllo dei tipi
        let ril1Primo = ril1.count == 2 && rilevazione(ril1[0], 20_000, d(2025, 9, 30), versato: 18_000)
        let ril1Secondo = ril1.count == 2 && rilevazione(ril1[1], 20_100, d(2026, 3, 31), versato: 18_600)
        verifica.vero("AV13 p1: valori passati 20.000 al 30/09/2025 e 20.100 al 31/03/2026, con il versato",
                      ril1Primo && ril1Secondo)

        // AV14. p3 dopo
        let p3 = cerca(pos, "av-p3")
        verifica("AV14 p3: valore", p3?.controvalore ?? -1, 52_000)
        verifica("AV14 p3: quota in gestione separata", p3?.quotaGestioneSeparata ?? -1, 42.5)
        let ril3 = p3?.rilevazioni ?? []
        let ril3Primo = ril3.count == 2 && rilevazione(ril3[0], 49_000, d(2025, 12, 31))
        let ril3Secondo = ril3.count == 2 && rilevazione(ril3[1], 50_000, d(2026, 3, 31))
        verifica.vero("AV14 p3: valori passati 49.000 al 31/12/2025 e 50.000 al 31/03/2026", ril3Primo && ril3Secondo)

        // AV15. p2 dopo, le altre identiche
        let p2 = cerca(pos, "av-p2")
        verifica("AV15 p2: valore", p2?.controvalore ?? -1, 11_500)
        verifica.vero("AV15 p2: valore al 29/10/2026", stessoGiorno(p2?.dataValore, oggi))
        let ril2 = p2?.rilevazioni ?? []
        verifica.vero("AV15 p2: valore passato 10.000 al 30/06/2025",
                      ril2.count == 1 && rilevazione(ril2[0], 10_000, d(2025, 6, 30)))
        verifica.vero("AV15 p4, p5, p6 e p7 non cambiano",
                      ["av-p4", "av-p5", "av-p6", "av-p7"].allSatisfy { cerca(pos, $0) == cerca(base, $0) })

        // AV16. Un secondo giro non registra niente
        let e2 = AV.esiti(righe, posizioni: pos, clienti: clienti, dataComune: oggi, oggi: oggi)
        verifica.vero("AV16 Di nuovo: nessuna riga da aggiornare o nello storico",
                      !e2.contains { $0.stato == .aggiorna || $0.stato == .storico })
        verifica.vero("AV16 Di nuovo: righe 1, 2, 3, 8, 11 e 12 già registrate",
                      [1, 2, 3, 8, 11, 12].allSatisfy { riga(e2, $0)?.stato == .giaRegistrato })
        var pos2 = pos
        let r2bis = AV.applica(e2, esclusi: [], a: &pos2)
        verifica.vero("AV16 Di nuovo: niente registrato, posizioni identiche",
                      r2bis.attuali == 0 && r2bis.storico == 0 && pos2 == pos)

        // AV17. La scelta a mano
        let e3 = AV.esiti(righe, posizioni: base, clienti: clienti, dataComune: oggi, oggi: oggi, scelte: [6: "av-p6"])
        let r6 = riga(e3, 6)
        verifica.vero("AV17 Riga 6 scelta a mano: si aggiorna", r6?.stato == .aggiorna && r6?.abbinamento == .scelta)
        verifica("AV17 Riga 6: variazione", r6?.variazione ?? -1, 400)
        verifica("AV17 Riga 6: variazione %", r6?.variazionePct ?? -1, 5)
        var pos3 = base
        let r3bis = AV.applica(e3, esclusi: [], a: &pos3)
        verifica("AV17 Indipendente con la scelta: posizioni", Double(r3bis.perCanale[.indipendente]?.posizioni ?? -1), 2)
        verifica("AV17 Indipendente con la scelta: prima", r3bis.perCanale[.indipendente]?.prima ?? -1, 18_000)
        verifica("AV17 Indipendente con la scelta: dopo", r3bis.perCanale[.indipendente]?.dopo ?? -1, 19_900)

        // AV18. Una riga esclusa non sposta le altre
        let e4 = AV.esiti(righe, posizioni: base, clienti: clienti, dataComune: oggi, oggi: oggi, esclusi: [8])
        let r1bis = riga(e4, 1)
        verifica("AV18 Riga 1 senza la riga 8: valore di prima", r1bis?.precedente ?? -1, 20_000)
        verifica("AV18 Riga 1 senza la riga 8: variazione", r1bis?.variazione ?? -1, 900)
        verifica("AV18 Riga 1 senza la riga 8: variazione %", r1bis?.variazionePct ?? -1, 4.5)
        verifica("AV18 Riga 1 senza la riga 8: versamenti", r1bis?.versamenti ?? -1, 1_200)
        verifica("AV18 Riga 1 senza la riga 8: al netto", r1bis?.risultato ?? 0, -300)
        verifica("AV18 Riga 1 senza la riga 8: al netto %", r1bis?.risultatoPct ?? 0, -1.5)
        var pos4 = base
        AV.applica(e4, esclusi: [8], a: &pos4)
        verifica("AV18 p1 senza la riga 8: punti dello storico", Double(cerca(pos4, "av-p1")?.storicoValori.count ?? -1), 2)
    }

    // MARK: - AV19–AV24: casi singoli

    private static func casiSingoli(_ verifica: VerificaCalcoli) {
        let base = posizioni

        // AV19. Versato stimato con i premi del periodo
        let soloP1 = base.filter { $0.id == "av-p1" }
        let e19 = esitiDi("Numero polizza;Controvalore;Data valore\nAL-2019-000111;21.000;29/03/2026\n", posizioni: soloP1)
        let r19 = e19.first
        verifica.vero("AV19 Senza versato: si aggiorna con il versato stimato", r19?.stato == .aggiorna && r19?.versatoStimato == true)
        verifica("AV19 Versamenti stimati", r19?.versamenti ?? -1, 591.38, tolleranza: 0.5)
        verifica("AV19 Al netto dei versamenti", r19?.risultato ?? -1, 408.62, tolleranza: 0.5)
        verifica("AV19 Al netto %", r19?.risultatoPct ?? -1, 2.043, tolleranza: 0.01)
        var pos19 = soloP1
        AV.applica(e19, esclusi: [], a: &pos19)
        verifica("AV19 Versato registrato", pos19.first?.totaleVersato ?? -1, 18_591.38, tolleranza: 0.5)

        // AV20. Stesso giorno: corregge il valore
        let soloP3 = base.filter { $0.id == "av-p3" }
        let e20 = esitiDi("Numero polizza;Controvalore;Data valore\nAL-2021-000222;50.500;31/03/2026\n", posizioni: soloP3)
        verifica.vero("AV20 Stesso giorno: corregge", e20.first?.stato == .aggiorna && e20.first?.correzione == true)
        verifica("AV20 Correzione: variazione", e20.first?.variazione ?? -1, 500)
        var pos20 = soloP3
        AV.applica(e20, esclusi: [], a: &pos20)
        verifica("AV20 Correzione: valore", pos20.first?.controvalore ?? -1, 50_500)
        verifica("AV20 Correzione: un solo punto nello storico", Double(pos20.first?.storicoValori.count ?? -1), 1)

        // AV21. Insolita: +40%
        let e21 = esitiDi("Contraente;Prodotto;Controvalore\nAnna Verdi;ETF globale;14.000\n", posizioni: base)
        verifica.vero("AV21 +40%: insolita, ma non esclusa", e21.first?.insolita == true && AV.esclusiIniziali(e21).isEmpty)

        // AV22. Valore zero dalla griglia
        guard let p6 = base.first(where: { $0.id == "av-p6" }) else { return }
        let righe22 = AV.righe(bozze: ["av-p6": AV.Bozza(valore: "0")], elenco: [p6])
        let e22 = AV.esiti(righe22, posizioni: base, clienti: clienti, dataComune: oggi, oggi: oggi)
        verifica.vero("AV22 Valore zero: insolita ed esclusa", e22.first?.insolita == true && AV.esclusiIniziali(e22) == [1])

        // AV23. Un numero di due clienti, riga senza cliente
        var conP13 = base
        conP13.append(posizione("av-p13", "carla", .indipendente, .inEssere, .risparmio, "Altro piano", numero: "AL-2019-000111",
                                valore: 1_000, data: d(2026, 1, 1)))
        let e23 = esitiDi("Numero polizza;Controvalore\nAL-2019-000111;1.000\n", posizioni: conP13)
        verifica.vero("AV23 Due posizioni con lo stesso numero: si sceglie (\(e23.first?.candidate ?? []))",
                      e23.first?.stato == .daScegliere && e23.first?.candidate == ["av-p13", "av-p1"])

        // AV24. Il nome non vince su un numero diverso
        let testo24 = "Contraente;Numero polizza;Prodotto;Controvalore\nAnna Verdi;AL-2099-000001;ETF globale;11.000\n"
        let e24 = esitiDi(testo24, posizioni: base)
        verifica.vero("AV24 Numero sconosciuto: l'ETF senza numero dal nome",
                      e24.first?.stato == .aggiorna && e24.first?.posizioneId == "av-p2" && e24.first?.abbinamento == .nome)
        let conNumero = base.map { p -> Posizione in
            var q = p
            if q.id == "av-p2" { q.numeroContratto = "X-1" }
            return q
        }
        verifica.vero("AV24 Con un altro numero: non trovata", esitiDi(testo24, posizioni: conNumero).first?.stato == .nonTrovata)
    }

    // MARK: - AV25–AV30: la griglia dei valori fermi

    private static func griglia(_ verifica: VerificaCalcoli) {
        let base = posizioni

        // AV25–AV27. Valori fermi, filtri e mesi
        let fermi = AV.valoriFermi(posizioni: base, clienti: clienti, oggi: oggi)
        verifica.vero("AV25 Valori fermi (\(fermi.map(\.id)))", fermi.map(\.id) == ["av-p2", "av-p1", "av-p10", "av-p6", "av-p7"])
        verifica.vero("AV26 Solo Anna", AV.valoriFermi(posizioni: base, clienti: clienti, oggi: oggi, clienteId: "av-anna").map(\.id)
                      == ["av-p2", "av-p1"])
        verifica.vero("AV26 Solo Alleanza", AV.valoriFermi(posizioni: base, clienti: clienti, oggi: oggi, canale: .alleanza).map(\.id)
                      == ["av-p1"])
        verifica("AV27 p2 fermo da 15 mesi", Double(cerca(base, "av-p2").flatMap { AV.fermoDa($0, oggi: oggi) } ?? -1), 15)
        verifica("AV27 p1 fermo da 12 mesi", Double(cerca(base, "av-p1").flatMap { AV.fermoDa($0, oggi: oggi) } ?? -1), 12)
        verifica.vero("AV27 p10 senza data", cerca(base, "av-p10").map { AV.fermoDa($0, oggi: oggi) == nil } ?? false)

        // AV28. Le caselle scritte
        let bozze: [String: AV.Bozza] = [
            "av-p2": AV.Bozza(valore: "11.500"),
            "av-p10": AV.Bozza(valore: "12.600", data: "30/09/2026", versato: "12.000"),
            "av-p6": AV.Bozza(valore: "7.000", data: "31/12/2024"),
            "av-p7": AV.Bozza(valore: "0"),
            "av-p1": AV.Bozza(),
        ]
        let righe = AV.righe(bozze: bozze, elenco: fermi)
        verifica.vero("AV28 Righe della griglia (\(righe.map(\.id)))", righe.map(\.id) == [1, 3, 4, 5])
        let g = AV.esiti(righe, posizioni: base, clienti: clienti, dataComune: oggi, oggi: oggi)
        verifica.vero("AV28 Stati della griglia (\(g.map(\.stato.rawValue)))", g.map(\.stato) == [.aggiorna, .aggiorna, .storico, .aggiorna])
        let p10 = riga(g, 3)
        verifica("AV28 p10: valore di prima", p10?.precedente ?? -1, 12_000)
        verifica.vero("AV28 p10: riferimento dalla data d'inserimento", stessoGiorno(p10?.dataPrecedente, d(2024, 1, 10)))
        verifica("AV28 p10: variazione", p10?.variazione ?? -1, 600)
        verifica("AV28 p10: variazione %", p10?.variazionePct ?? -1, 5)
        verifica("AV28 p10: versamenti", p10?.versamenti ?? -1, 1_000)
        verifica("AV28 p10: al netto", p10?.risultato ?? 0, -400)
        verifica("AV28 p10: al netto %", p10?.risultatoPct ?? 0, -3.3333, tolleranza: 0.001)
        verifica.vero("AV28 Il valore zero parte escluso", AV.esclusiIniziali(g) == [5])

        // AV29. Registrazione dalla griglia
        var pos = base
        let r = AV.applica(g, esclusi: [5], a: &pos)
        verifica("AV29 Griglia: attuali", Double(r.attuali), 2)
        verifica("AV29 Griglia: nello storico", Double(r.storico), 1)
        verifica("AV29 Griglia: prima", r.totale.prima, 22_000)
        verifica("AV29 Griglia: dopo", r.totale.dopo, 24_100)
        verifica("AV29 Griglia: variazione", r.totale.variazione, 2_100)
        verifica("AV29 Griglia: variazione %", r.totale.variazionePct ?? -1, 9.5455, tolleranza: 0.001)
        verifica("AV29 Griglia: versamenti", r.totale.versamenti, 1_000)
        verifica("AV29 Griglia: al netto", r.totale.risultato, 1_100)
        verifica("AV29 Griglia: al netto %", r.totale.risultatoPct ?? -1, 5.0)
        verifica.vero("AV29 Griglia: solo il canale indipendente, 2 posizioni",
                      r.perCanale[.alleanza] == nil && r.perCanale[.indipendente]?.posizioni == 2)
        let q10 = cerca(pos, "av-p10")
        let ril10 = q10?.rilevazioni ?? []
        let ril10Prima = ril10.count == 1 && rilevazione(ril10[0], 12_000, d(2024, 1, 10), versato: 11_000)
        verifica.vero("AV29 p10: valore al 30/09/2026, quello di prima al 10/01/2024 con il versato",
                      stessoGiorno(q10?.dataValore, d(2026, 9, 30)) && ril10Prima)
        let q6 = cerca(pos, "av-p6")
        let ril6 = q6?.rilevazioni ?? []
        let ril6Passato = ril6.count == 1 && rilevazione(ril6[0], 7_000, d(2024, 12, 31))
        let q6Invariato = (q6?.controvalore ?? -1) == 8_000
        verifica.vero("AV29 p6: 7.000 al 31/12/2024 tra i valori passati, valore attuale invariato", ril6Passato && q6Invariato)
        verifica.vero("AV29 p7 invariata", cerca(pos, "av-p7") == cerca(base, "av-p7"))

        // AV30. Data illeggibile
        let illeggibile = AV.righe(bozze: ["av-p2": AV.Bozza(valore: "11.000", data: "a fine mese")], elenco: fermi)
        let e30 = AV.esiti(illeggibile, posizioni: base, clienti: clienti, dataComune: oggi, oggi: oggi)
        verifica.vero("AV30 Data illeggibile: senza valore", e30.first?.stato == .senzaValore)
    }

    // MARK: - AV31: Excel

    private static func excel(_ verifica: VerificaCalcoli) {
        let xml = """
            <worksheet><sheetData>
            <row r="1"><c r="A1" t="inlineStr"><is><t>Numero polizza</t></is></c><c r="B1" t="inlineStr"><is><t>Controvalore</t></is></c><c r="C1" t="inlineStr"><is><t>Data valore</t></is></c></row>
            <row r="2"><c r="A2" t="inlineStr"><is><t>AL-2021-000222</t></is></c><c r="B2"><v>52000.5</v></c><c r="C2"><v>46295</v></c></row>
            </sheetData></worksheet>
            """
        let tabella = FoglioExcel.righe(foglioXML: Data(xml.utf8), condivisi: [])
        let righe = AV.righe(tabella).righe
        verifica("AV31 Excel: valore con i decimali", righe.first?.valore ?? -1, 52_000.5)
        verifica.vero("AV31 Excel: data dal numero di serie 46295 (30/09/2026)", stessoGiorno(righe.first?.data, d(2026, 9, 30)))
        let soloP3 = posizioni.filter { $0.id == "av-p3" }
        let e = AV.esiti(righe, posizioni: soloP3, clienti: clienti, dataComune: oggi, oggi: oggi)
        verifica.vero("AV31 Excel: la multiramo si aggiorna", e.first?.stato == .aggiorna)
        verifica("AV31 Excel: variazione", e.first?.variazione ?? -1, 2_000.5)
    }

    // MARK: - AV32–AV35: importazione

    private static func importazione(_ verifica: VerificaCalcoli) {
        let base = posizioni

        // AV32. Il file della compagnia nell'importazione: Prisma propone l'aggiornamento
        let i = ImportaPosizioni.incollate(csv, clienti: clienti, posizioni: base)
        verifica("AV32 Importazione: righe della tabella conservate", Double(i?.righe.count ?? -1), 15)
        verifica("AV32 Importazione: righe già in Posizioni",
                 Double(i?.posizioni.filter { $0.problema == ImportaPosizioni.giaPresente }.count ?? -1), 12)
        verifica.vero("AV32 Importazione: aggiornamento proposto", i.map(ImportaPosizioni.propostoAggiornamento) ?? false)

        // AV33. Due posizioni nuove: niente proposta
        let nuove = ImportaPosizioni.incollate("Cliente;Prodotto;Controvalore\nAnna Verdi;Fondo nuovo;1.000\nBruno Neri;Altro fondo;2.000\n",
                                               clienti: clienti, posizioni: base)
        verifica.vero("AV33 Posizioni nuove: niente proposta", nuove.map { !ImportaPosizioni.propostoAggiornamento($0) } ?? false)

        // AV34. La colonna nuova nell'importazione normale
        let conGestione = ImportaPosizioni.daCSV("Cliente;Prodotto;Tipologia;Controvalore;Valore gestione separata\nZeno Blu;Multiramo X;Polizza multiramo;40.000;16.000\n",
                                                 clienti: clienti, posizioni: base).posizioni.first?.posizione
        verifica("AV34 Importazione: quota in gestione separata dal file", conGestione?.quotaGestioneSeparata ?? -1, 40)
        verifica.vero("AV34 Importazione: multiramo in investimento", conGestione?.area == .investimento && conGestione?.multiramo == true)
        let senza = ImportaPosizioni.daCSV("Cliente;Prodotto;Tipologia;Controvalore\nZeno Blu;Multiramo X;Polizza multiramo;40.000\n",
                                           clienti: clienti, posizioni: base).posizioni.first?.posizione
        verifica.vero("AV34 Importazione: senza la colonna nessuna quota", senza != nil && senza?.quotaGestioneSeparata == nil)

        // AV35. La quota
        verifica("AV35 Quota 22.100 su 52.000", AV.quotaGestione(valore: 52_000, gestione: 22_100) ?? -1, 42.5)
        verifica.vero("AV35 Quota senza valore: nessuna", AV.quotaGestione(valore: 0, gestione: 0) == nil)
        verifica.vero("AV35 Quota oltre il valore: nessuna", AV.quotaGestione(valore: 1_000, gestione: 1_200) == nil)
        verifica("AV35 Quota zero", AV.quotaGestione(valore: 1_000, gestione: 0) ?? -1, 0)
    }

    // MARK: - AV36: testi

    private static func testi(_ verifica: VerificaCalcoli) {
        verifica.vero("AV36 Percentuale con il segno: +15,0%", TestiAggiornaValori.percentualeSegno(15) == "+15,0%")
        verifica.vero("AV36 Percentuale con il segno: −2,5%", TestiAggiornaValori.percentualeSegno(-2.5) == "\u{2212}2,5%")
        verifica.vero("AV36 Percentuale con il segno: 0,0%", TestiAggiornaValori.percentualeSegno(0.04) == "0,0%")
        let base = posizioni
        let e = AV.esiti(AV.righe(tabella).righe, posizioni: base, clienti: clienti, dataComune: oggi, oggi: oggi)
        guard let r13 = riga(e, 13) else {
            verifica.vero("AV36 Riga 13 presente", false)
            return
        }
        let pillola = TestiAggiornaValori.pillola(r13)
        verifica.vero("AV36 Pillola della riga 13", pillola.testo == "Scegli la posizione" && pillola.tono == .attenzione)
        var perId: [String: Posizione] = [:]
        for p in base { perId[p.id] = p }
        var nomi: [String: String] = [:]
        for c in clienti { nomi[c.id] = c.nome }
        verifica.vero("AV36 Spiegazione della riga 13: il numero è di Anna Verdi",
                      TestiAggiornaValori.spiegazione(r13, posizioni: perId, clienti: nomi).contains("Anna Verdi"))
    }
}
