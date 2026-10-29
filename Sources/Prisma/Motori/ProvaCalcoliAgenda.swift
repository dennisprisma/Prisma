import Foundation

/// Prove del motore della pianificazione (riesami in Agenda, giro 3): festività, spazio libero negli orari di
/// lavoro, sovrapposizioni, fuori orario, fasce e descrizione degli orari, canale del riesame, riesami del mese,
/// note con l'ordine del giorno e lettura tollerante degli orari (A1–A35). Chiamate da `ProvaCalcoli.esegui()`:
/// gli errori si sommano. Date fisse lontane dal cambio dell'ora legale (25 ottobre 2026 e 28 marzo 2027).
/// Riferimento: mercoledì 28 ottobre 2026; il 29 è giovedì, il 30 venerdì, il 31 sabato, il 2 novembre lunedì,
/// il 7 dicembre lunedì, l'8 dicembre martedì (Immacolata).
enum ProvaCalcoliAgenda {
    static func esegui(_ verifica: VerificaCalcoli) {
        festivita(verifica)
        spazio(verifica)
        orari(verifica)
        canale(verifica)
        mese(verifica)
        note(verifica)
        archivio(verifica)
    }

    // MARK: - Aiuti

    private static var cal: Calendar { MotorePianificazione.calendario }

    /// Il giorno a mezzanotte (fuso del Mac).
    private static func g(_ a: Int, _ m: Int, _ d: Int) -> Date { cal.startOfDay(for: AiutiProva.data(a, m, d)) }

    /// L'ora di un giorno.
    private static func h(_ giorno: Date, _ ora: Int, _ min: Int = 0) -> Date {
        cal.date(bySettingHour: ora, minute: min, second: 0, of: giorno) ?? giorno
    }

    private static func app(_ id: String, _ inizio: Date, _ minuti: Int, tipo: TipoAppuntamento = .altro,
                            stato: Appuntamento.Stato = .pianificato) -> Appuntamento {
        Appuntamento(id: id, clienteId: "prova", titolo: id, inizio: inizio, durataMinuti: minuti, luogo: "In studio",
                     note: "", stato: stato, tipo: tipo)
    }

    /// Un giorno pieno negli orari predefiniti: 9:00-13:00 e 14:30-18:30.
    private static func pieno(_ giorno: Date, _ nome: String) -> [Appuntamento] {
        [app("\(nome)-mattina", h(giorno, 9), 240), app("\(nome)-pomeriggio", h(giorno, 14, 30), 240)]
    }

    /// Lo spazio trovato comincia all'ora attesa (e, se indicato, dopo quei giorni pieni).
    private static func vale(_ verifica: VerificaCalcoli, _ nome: String, _ s: SpazioLibero?, _ inizio: Date, pieni: Int? = nil) {
        let ok = s?.inizio == inizio && (pieni.map { s?.giorniPieni == $0 } ?? true)
        let trovato = s.map { "\(Formati.dataBreve.string(from: $0.inizio)) \(Formati.ora.string(from: $0.inizio)), pieni \($0.giorniPieni)" } ?? "nessuno"
        verifica.vero("\(nome) (trovato: \(trovato))", ok)
    }

    private static func cerca(da: Date, _ appuntamenti: [Appuntamento] = [], orari: OrariLavoro = OrariLavoro(),
                              durata: Int = MotorePianificazione.durataRiesame,
                              giorni: Int = MotorePianificazione.giorniRicerca) -> SpazioLibero? {
        MotorePianificazione.primoSpazio(durata: durata, da: da, appuntamenti: appuntamenti, orari: orari, cal: cal, giorni: giorni)
    }

    private static func cliente(_ id: String, canali: [Canale] = []) -> Cliente {
        var c = Cliente(id: id, nome: id, iniziali: id, tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: AiutiProva.data(2020, 1, 1))
        c.canali = canali
        return c
    }

    // MARK: - A1-A4 Festività

    private static func festivita(_ verifica: VerificaCalcoli) {
        for (anno, atteso) in [(2026, 405.0), (2027, 328.0), (2028, 416.0), (2030, 421.0)] {
            let p = MotorePianificazione.pasqua(anno)
            verifica("A1 Agenda: Pasqua \(anno) (mese × 100 + giorno)", Double(p.mese * 100 + p.giorno), atteso)
        }
        let festivi = [(g(2026, 4, 6), "Pasquetta 2026"), (g(2026, 12, 8), "8 dicembre 2026"), (g(2027, 3, 29), "Pasquetta 2027"),
                       (g(2027, 6, 2), "2 giugno 2027"), (g(2026, 12, 26), "Santo Stefano 2026"), (g(2027, 10, 4), "4 ottobre 2027")]
        for (giorno, nome) in festivi {
            verifica.vero("A2 Agenda: \(nome) è festivo", MotorePianificazione.festivo(giorno, cal: cal))
        }
        let feriali = [(g(2027, 3, 30), "30 marzo 2027"), (g(2026, 12, 7), "7 dicembre 2026"), (g(2025, 10, 4), "4 ottobre 2025 (prima del 2026)")]
        for (giorno, nome) in feriali {
            verifica.vero("A3 Agenda: \(nome) non è festivo", !MotorePianificazione.festivo(giorno, cal: cal))
        }
        verifica("A4 Agenda: festività nazionali del 2027", Double(MotorePianificazione.festivita(2027, cal: cal).count), 13)
    }

    // MARK: - A5-A23 Spazio libero, sovrapposizioni, fuori orario

    private static func spazio(_ verifica: VerificaCalcoli) {
        let base = OrariLavoro()
        let mer28 = g(2026, 10, 28), gio29 = g(2026, 10, 29), ven30 = g(2026, 10, 30), sab31 = g(2026, 10, 31)
        let lun2 = g(2026, 11, 2), lun7 = g(2026, 12, 7), mar8 = g(2026, 12, 8), mer9 = g(2026, 12, 9)

        // A5 Griglia della mezz'ora
        let secondi = cal.date(bySettingHour: 10, minute: 0, second: 30, of: gio29) ?? gio29
        verifica.vero("A5 Agenda: allineato 12:10 → 12:30", MotorePianificazione.allineato(h(gio29, 12, 10), cal: cal) == h(gio29, 12, 30))
        verifica.vero("A5 Agenda: allineato 10:15 → 10:30", MotorePianificazione.allineato(h(gio29, 10, 15), cal: cal) == h(gio29, 10, 30))
        verifica.vero("A5 Agenda: allineato 10:00 resta 10:00", MotorePianificazione.allineato(h(gio29, 10), cal: cal) == h(gio29, 10))
        verifica.vero("A5 Agenda: allineato 10:00:30 → 10:30", MotorePianificazione.allineato(secondi, cal: cal) == h(gio29, 10, 30))

        // A6 Agenda vuota: le 9:00 del giorno dopo
        let a6 = cerca(da: gio29)
        vale(verifica, "A6 Agenda: agenda vuota, giovedì alle 9:00", a6, h(gio29, 9), pieni: 0)
        verifica.vero("A6 Agenda: l'incontro finisce alle 10:00", a6?.fine == h(gio29, 10))
        // A7 Alle 12:30 l'ora sforerebbe le 13:00: si va al pomeriggio
        vale(verifica, "A7 Agenda: da mercoledì 12:10, mercoledì alle 14:30", cerca(da: h(mer28, 12, 10)), h(mer28, 14, 30))
        // A8-A9 Margine
        let nove = [app("occupato", h(gio29, 9), 60)]
        vale(verifica, "A8 Agenda: 9:00-10:00 occupato con margine 15, alle 10:30", cerca(da: gio29, nove), h(gio29, 10, 30))
        var senzaMargine = base
        senzaMargine.margineMinuti = 0
        vale(verifica, "A9 Agenda: senza margine, alle 10:00", cerca(da: gio29, nove, orari: senzaMargine), h(gio29, 10))
        // A10 Estremi che si toccano: nessuna sovrapposizione
        let due = nove + [app("breve", h(gio29, 10, 45), 30)]
        vale(verifica, "A10 Agenda: 9:00-10:00 e 10:45-11:15, alle 11:30", cerca(da: gio29, due), h(gio29, 11, 30))
        // A11-A12 Giorni pieni
        vale(verifica, "A11 Agenda: giovedì pieno, venerdì alle 9:00", cerca(da: gio29, pieno(gio29, "gio")), h(ven30, 9), pieni: 1)
        vale(verifica, "A12 Agenda: giovedì e venerdì pieni, il weekend non conta: lunedì alle 9:00",
             cerca(da: gio29, pieno(gio29, "gio") + pieno(ven30, "ven")), h(lun2, 9), pieni: 2)
        // A13-A14 Festività
        vale(verifica, "A13 Agenda: 7 dicembre pieno e 8 festivo, il 9 alle 9:00", cerca(da: lun7, pieno(lun7, "lun")), h(mer9, 9), pieni: 1)
        var senzaFeste = base
        senzaFeste.festivi = false
        vale(verifica, "A14 Agenda: senza festività, l'8 dicembre alle 9:00", cerca(da: lun7, pieno(lun7, "lun"), orari: senzaFeste), h(mar8, 9))
        // A15-A16 Riesami al giorno
        let riesami = [app("r1", h(gio29, 9), 60, tipo: .revisione), app("r2", h(gio29, 11), 60, tipo: .revisione)]
        vale(verifica, "A15 Agenda: due riesami giovedì (limite 2), venerdì alle 9:00", cerca(da: gio29, riesami), h(ven30, 9), pieni: 1)
        var senzaLimite = base
        senzaLimite.riesamiAlGiorno = 0
        vale(verifica, "A16 Agenda: senza limite, giovedì alle 14:30", cerca(da: gio29, riesami, orari: senzaLimite), h(gio29, 14, 30))
        // A17 Anche un appuntamento concluso occupa il tempo
        vale(verifica, "A17 Agenda: concluso 9:00-10:00, alle 10:30",
             cerca(da: gio29, [app("concluso", h(gio29, 9), 60, stato: .concluso)]), h(gio29, 10, 30))
        // A18 Da metà mattina, con un occupato a cavallo della pausa
        vale(verifica, "A18 Agenda: da 11:30 con 12:30-15:00 occupato, alle 15:30",
             cerca(da: h(gio29, 11, 30), [app("lungo", h(gio29, 12, 30), 150)]), h(gio29, 15, 30))
        // A19 Orario continuato da lunedì a giovedì
        var continuato = base
        continuato.giorni = [2, 3, 4, 5]
        continuato.mattina = FasciaOraria(inizio: 8 * 60 + 30, fine: 17 * 60)
        continuato.pomeriggioAttivo = false
        vale(verifica, "A19 Agenda: lun-gio 8:30-17:00 da venerdì, lunedì alle 8:30", cerca(da: ven30, orari: continuato), h(lun2, 8, 30), pieni: 0)
        // A20-A21 Nessuno spazio
        verifica.vero("A20 Agenda: giovedì e venerdì pieni, tre giorni di ricerca: nessuno spazio",
                      cerca(da: gio29, pieno(gio29, "gio") + pieno(ven30, "ven"), giorni: 3) == nil)
        var spenti = base
        spenti.mattina = FasciaOraria(inizio: 800, fine: 700)
        spenti.pomeriggioAttivo = false
        verifica.vero("A21 Agenda: durata zero, nessuno spazio", cerca(da: gio29, durata: 0) == nil)
        verifica.vero("A21 Agenda: mattina non valida e pomeriggio spento, nessuno spazio", cerca(da: gio29, orari: spenti) == nil)

        // A22 Sovrapposizioni
        let bozza = app("b", h(gio29, 10), 60)
        let elenco = [bozza, app("x", h(gio29, 10, 30), 60), app("y", h(gio29, 11), 60)]
        let stretti = MotorePianificazione.sovrapposti(bozza, in: elenco)
        verifica("A22 Agenda: sovrapposti senza margine", Double(stretti.count), 1)
        verifica.vero("A22 Agenda: si sovrappone solo a x", stretti.first?.id == "x")
        verifica("A22 Agenda: sovrapposti con margine 15", Double(MotorePianificazione.sovrapposti(bozza, in: elenco, margine: 15).count), 2)

        // A23 Fuori orario (un'ora)
        let fuori: [(Date, Bool, String)] = [
            (h(sab31, 10), true, "sabato 31 ottobre alle 10:00"),
            (h(mer28, 13, 30), true, "mercoledì 28 ottobre alle 13:30 (pausa pranzo)"),
            (h(gio29, 9), false, "giovedì 29 ottobre alle 9:00"),
            (h(gio29, 12, 30), true, "giovedì 29 ottobre alle 12:30 (sfora le 13:00)"),
            (h(mar8, 10), true, "martedì 8 dicembre alle 10:00 (festivo)"),
        ]
        for (inizio, atteso, nome) in fuori {
            verifica.vero("A23 Agenda: \(nome) \(atteso ? "fuori orario" : "dentro gli orari")",
                          MotorePianificazione.fuoriOrario(app("f", inizio, 60), orari: base, cal: cal) == atteso)
        }
    }

    // MARK: - A24-A25 Fasce e descrizione

    private static func orari(_ verifica: VerificaCalcoli) {
        let base = OrariLavoro()
        verifica("A24 Agenda: fasce predefinite", Double(base.fasce.count), 2)
        var unite = base
        unite.pomeriggio = FasciaOraria(inizio: 12 * 60, fine: 18 * 60)
        verifica("A24 Agenda: pomeriggio che si accavalla alla mattina, una fascia", Double(unite.fasce.count), 1)
        verifica.vero("A24 Agenda: la fascia unita va dalle 9:00 alle 18:00", unite.fasce.first == FasciaOraria(inizio: 9 * 60, fine: 18 * 60))
        var spento = base
        spento.pomeriggioAttivo = false
        verifica("A24 Agenda: pomeriggio spento, una fascia", Double(spento.fasce.count), 1)

        verifica.vero("A25 Agenda: descrizione predefinita «\(base.descrizione)»", base.descrizione == "lun–ven, 09:00–13:00 e 14:30–18:30")
        var alterni = base
        alterni.giorni = [2, 4, 6]
        alterni.mattina = FasciaOraria(inizio: 8 * 60 + 30, fine: 17 * 60)
        alterni.pomeriggioAttivo = false
        verifica.vero("A25 Agenda: descrizione a giorni alterni «\(alterni.descrizione)»", alterni.descrizione == "lun, mer, ven, 08:30–17:00")
    }

    // MARK: - A26-A27 Canale del riesame

    private static func canale(_ verifica: VerificaCalcoli) {
        let demo = DatiDemo.posizioni()
        func di(_ id: String) -> [Posizione] { demo.filter { $0.clienteId == id } }
        verifica.vero("A26 Agenda: canale del riesame di Marco: Alleanza", MotorePianificazione.canale(di("marco"), cliente: nil) == .alleanza)
        verifica.vero("A26 Agenda: canale del riesame di Laura: indipendente", MotorePianificazione.canale(di("laura"), cliente: nil) == .indipendente)
        verifica.vero("A26 Agenda: canale del riesame di Giulia: entrambi (nil)", MotorePianificazione.canale(di("giulia"), cliente: nil) == nil)
        verifica.vero("A26 Agenda: canale del riesame di Andrea (solo Alleanza, anche proposte): Alleanza",
                      MotorePianificazione.canale(di("andrea"), cliente: nil) == .alleanza)
        verifica("A26 Agenda: canali di Giulia", Double(MotorePianificazione.canali(di("giulia")).count), 2)

        let indipendente = AiutiProva.posizione("Fondo", .investimento, 10_000, canale: .indipendente)
        let chiusa = AiutiProva.posizione("Polizza chiusa", .risparmio, 5_000, canale: .alleanza) { $0.stato = .chiusa }
        let rifiutata = AiutiProva.posizione("Proposta rifiutata", .risparmio, 5_000, canale: .alleanza) {
            $0.stato = .proposta
            $0.esito = .rifiutata
        }
        let presentata = AiutiProva.posizione("Proposta presentata", .risparmio, 5_000, canale: .alleanza) {
            $0.stato = .proposta
            $0.esito = .presentata
        }
        verifica.vero("A27 Agenda: indipendente in essere e Alleanza chiusa: indipendente",
                      MotorePianificazione.canale([indipendente, chiusa], cliente: nil) == .indipendente)
        verifica.vero("A27 Agenda: con una proposta Alleanza rifiutata resta indipendente",
                      MotorePianificazione.canale([indipendente, rifiutata], cliente: nil) == .indipendente)
        verifica.vero("A27 Agenda: con una proposta Alleanza presentata: entrambi (nil)",
                      MotorePianificazione.canale([indipendente, presentata], cliente: nil) == nil)
        verifica.vero("A27 Agenda: senza posizioni, il canale del cliente (Alleanza)",
                      MotorePianificazione.canale([], cliente: cliente("prova", canali: [.alleanza])) == .alleanza)
    }

    // MARK: - A28-A29 Riesami del mese

    private static func mese(_ verifica: VerificaCalcoli) {
        let oggi = g(2026, 10, 28)
        verifica("A28 Agenda: orizzonte per ottobre", Double(MotorePianificazione.mesiOrizzonte(mese: g(2026, 10, 1), oggi: oggi, cal: cal)), 1)
        verifica("A28 Agenda: orizzonte per dicembre", Double(MotorePianificazione.mesiOrizzonte(mese: g(2026, 12, 15), oggi: oggi, cal: cal)), 3)
        verifica("A28 Agenda: orizzonte per settembre (mai meno di 1)", Double(MotorePianificazione.mesiOrizzonte(mese: g(2026, 9, 10), oggi: oggi, cal: cal)), 1)

        let date: [(String, Date?)] = [("A", g(2026, 10, 3)), ("B", g(2026, 10, 30)), ("C", nil),
                                       ("D", g(2026, 11, 18)), ("E", g(2026, 12, 5)), ("F", g(2026, 8, 10))]
        let dovuti = date.map { id, d in
            RiesameDovuto(cliente: cliente(id), ultimoContatto: d.flatMap { cal.date(byAdding: .month, value: -12, to: $0) }, dovutoDal: d)
        }
        func ids(_ m: Date) -> [String] { MotorePianificazione.delMese(dovuti, mese: m, oggi: oggi, cal: cal).map(\.id) }
        let ottobre = ids(g(2026, 10, 15))
        verifica.vero("A29 Agenda: ottobre, scaduti, mai incontrati e dovuti nel mese (\(ottobre.joined(separator: ", ")))", ottobre == ["A", "B", "C", "F"])
        verifica.vero("A29 Agenda: novembre, solo i dovuti nel mese", ids(g(2026, 11, 1)) == ["D"])
        verifica.vero("A29 Agenda: dicembre, solo i dovuti nel mese", ids(g(2026, 12, 31)) == ["E"])
        verifica.vero("A29 Agenda: settembre (passato), nessuno", ids(g(2026, 9, 10)).isEmpty)
    }

    // MARK: - A30-A32 Note dell'appuntamento

    private static func note(_ verifica: VerificaCalcoli) {
        let oggi = g(2026, 10, 28)
        var punti = [
            Riesame.Punto(tema: .famiglia, titolo: "Indicare i beneficiari", dettaglio: "", priorita: .alta),
            Riesame.Punto(tema: .scadenze, titolo: "Rinnovo di «Infortuni famiglia»", dettaglio: "", priorita: .alta, canale: .alleanza),
            Riesame.Punto(tema: .posizioni, titolo: "Rivedere «ETF azionario globale»", dettaglio: "", priorita: .alta, canale: .indipendente),
        ]
        for n in 1...7 {
            punti.append(Riesame.Punto(tema: .dati, titolo: "Dato \(n)", dettaglio: "", priorita: .bassa))
        }
        let due = MotorePianificazione.noteRiesame(punti: punti, canali: [.alleanza, .indipendente], canale: nil,
                                                   ultimoContatto: g(2025, 10, 3), dovutoDal: g(2026, 10, 3), oggi: oggi)
        let r = due.components(separatedBy: "\n")
        func riga(_ righe: [String], _ i: Int) -> String { i < righe.count ? righe[i] : "" }
        verifica("A30 Agenda: righe delle note", Double(r.count), 13)
        verifica.vero("A30 Agenda: prima riga", riga(r, 0) == "Ordine del giorno:")
        verifica.vero("A30 Agenda: punto senza canale", riga(r, 1) == "1. Indicare i beneficiari")
        verifica.vero("A30 Agenda: punto Alleanza con l'etichetta", riga(r, 2) == "2. Rinnovo di «Infortuni famiglia» (Alleanza)")
        verifica.vero("A30 Agenda: punto indipendente con l'etichetta", riga(r, 3) == "3. Rivedere «ETF azionario globale» (Indipendente)")
        verifica.vero("A30 Agenda: i punti oltre gli otto", riga(r, 9) == "…e altri 2 punti nel prospetto del riesame.")
        verifica.vero("A30 Agenda: riga vuota prima del canale", r.count > 10 && riga(r, 10).isEmpty)
        verifica.vero("A30 Agenda: tutti e due i canali",
                      riga(r, 11) == "Canale: Alleanza e indipendente. Proposte, documenti e firme restano distinti per canale.")
        verifica.vero("A30 Agenda: riesame scaduto «\(riga(r, 12))»",
                      riga(r, 12) == "Ultimo contatto il 3 ottobre 2025: riesame scaduto dal 3 ottobre 2026.")

        let una = MotorePianificazione.noteRiesame(punti: punti, canali: [.alleanza], canale: .alleanza,
                                                   ultimoContatto: g(2025, 10, 3), dovutoDal: g(2026, 11, 18), oggi: oggi)
        let u = una.components(separatedBy: "\n")
        verifica.vero("A31 Agenda: un canale solo, punto senza etichetta", riga(u, 2) == "2. Rinnovo di «Infortuni famiglia»")
        verifica.vero("A31 Agenda: canale Alleanza", una.contains("Canale: Alleanza Assicurazioni."))
        verifica.vero("A31 Agenda: riesame dovuto", una.hasSuffix("riesame dovuto dal 18 novembre 2026."))

        let vuote = MotorePianificazione.noteRiesame(punti: [], canali: [], canale: nil, ultimoContatto: nil, dovutoDal: nil, oggi: oggi)
        let v = vuote.components(separatedBy: "\n")
        verifica.vero("A32 Agenda: senza punti, prima riga", riga(v, 0) == "Ordine del giorno:")
        verifica.vero("A32 Agenda: senza punti, un punto generico", riga(v, 1) == "1. Fare il punto su posizioni, obiettivi e famiglia")
        verifica.vero("A32 Agenda: senza contatto, primo riesame", v.last == "Nessun incontro registrato in Prisma: è il primo riesame.")
    }

    // MARK: - A33-A35 Archivio

    private static func archivio(_ verifica: VerificaCalcoli) {
        let lettore = JSONDecoder()
        lettore.dateDecodingStrategy = .iso8601

        var o = OrariLavoro()
        o.giorni = [2, 4]
        o.mattina = FasciaOraria(inizio: 8 * 60, fine: 12 * 60)
        o.pomeriggioAttivo = false
        o.margineMinuti = 30
        o.riesamiAlGiorno = 1
        o.festivi = false
        let scritto = try? Archivio.codificatore.encode(o)
        let riletto = scritto.flatMap { try? lettore.decode(OrariLavoro.self, from: $0) }
        verifica.vero("A33 Agenda: orari di lavoro, andata e ritorno nell'archivio", riletto == o)

        let vecchie = try? lettore.decode(Impostazioni.self, from: Data(#"{"nomeUtente":"Denis"}"#.utf8))
        verifica.vero("A34 Agenda: impostazioni di prima della versione 21, orari predefiniti", vecchie?.orari == OrariLavoro())

        let strani = #"{"giorni":[9,0],"margineMinuti":7,"riesamiAlGiorno":5,"mattina":{"inizio":800,"fine":700},"pomeriggioAttivo":false}"#
        let letti = try? lettore.decode(OrariLavoro.self, from: Data(strani.utf8))
        let predefiniti = OrariLavoro()
        verifica.vero("A35 Agenda: giorni fuori scala, i predefiniti", letti?.giorni == predefiniti.giorni)
        verifica("A35 Agenda: margine fuori scelta, 15", Double(letti?.margineMinuti ?? -1), 15)
        verifica("A35 Agenda: riesami al giorno fuori scelta, 2", Double(letti?.riesamiAlGiorno ?? -1), 2)
        verifica.vero("A35 Agenda: mattina non valida, 9:00-13:00", letti?.mattina == predefiniti.mattina)
        verifica.vero("A35 Agenda: pomeriggio spento letto", letti?.pomeriggioAttivo == false)
    }
}
