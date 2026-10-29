import Foundation

/// Prove del riesame con memoria (specifica 12 §8.1): fotografia (MF), variazioni (MV), precedente (MP), registrazione
/// (MR), ordine del giorno (MA) e testi (MT). Valori attesi controllati con `calcoli_memoria.py`.
/// Chiamata da `ProvaCalcoli.esegui()` dopo le prove della specifica 11: gli errori si sommano.
enum ProvaCalcoliMemoria {
    typealias Foto = FotografiaRiesame

    static func esegui(_ verifica: VerificaCalcoli) {
        let cal = Calendar(identifier: .gregorian)
        let oggi = AiutiProva.data(2026, 10, 29)
        func giorno(_ a: Int, _ m: Int, _ g: Int) -> Date { cal.startOfDay(for: AiutiProva.data(a, m, g)) }
        func testi(_ v: [VariazioneRiesame]) -> [String] { v.map(\.testo) }
        func chiavi(_ v: [VariazioneRiesame]) -> [String] { v.map(\.chiave) }

        provaFotografia(verifica, cal: cal, oggi: oggi)

        // MV · Variazioni tra due fotografie costruite a mano
        let p = primaDiProva(cal: cal)
        let o = oggiDiProva(cal: cal)
        let v = MotoreMemoria.variazioni(da: p, a: o)
        func una(_ chiave: String) -> VariazioneRiesame? { v.first { $0.chiave == chiave } }

        // MV1 conteggio
        verifica("MV1 Memoria: 13 variazioni", Double(v.count), 13)
        verifica("MV1 Memoria: 6 in meglio", Double(v.filter { $0.verso == .meglio }.count), 6)
        verifica("MV1 Memoria: 1 in peggio", Double(v.filter { $0.verso == .peggio }.count), 1)
        verifica("MV1 Memoria: 6 neutre", Double(v.filter { $0.verso == .neutro }.count), 6)

        // MV2 chiavi e ordine
        verifica.vero("MV2 Memoria: chiavi nell'ordine dei temi",
                      chiavi(v) == ["profilo.propensione", "famiglia.ingresso.f-sofia", "semaforo.riserva", "semaforo.previdenza",
                                    "semaforo.obiettivi", "pensione.divario", "obiettivo.o-casa", "obiettivo.nuovo.o-uni",
                                    "obiettivo.tolto.o-auto", "patrimonio.alleanza", "patrimonio.debiti", "completezza",
                                    "conformita.questionarioAlleanza"])

        // MV3 testi
        verifica.vero("MV3 Memoria: testi delle variazioni",
                      testi(v) == ["Propensione da dinamica a moderata",
                                   "In famiglia: Sofia (figlia, a carico)",
                                   "Semaforo «Riserva di emergenza» da verde a giallo",
                                   "Semaforo «Pensione» da giallo a verde",
                                   "Semaforo «Obiettivi» da grigio a verde",
                                   "Divario pensione da 640 a 410 €/mese",
                                   "Obiettivo «Casa» dal 40% al 77%",
                                   "Nuovo obiettivo «Università di Sofia»: 30.000 €, raggiunto al 10%",
                                   "Obiettivo «Auto» tolto (era al 70%)",
                                   "Patrimonio Alleanza da 42.000 a 51.500 €",
                                   "Debiti da 96.000 a 90.000 €",
                                   "Completezza dei dati dal 62% al 77%",
                                   "Questionario di adeguatezza Alleanza: da scadenza superata a in regola"])

        // MV4 versi
        verifica.vero("MV4 Memoria: semaforo della riserva in peggio", una("semaforo.riserva")?.verso == .peggio)
        verifica.vero("MV4 Memoria: semaforo della pensione in meglio", una("semaforo.previdenza")?.verso == .meglio)
        verifica.vero("MV4 Memoria: semaforo grigio neutro", una("semaforo.obiettivi")?.verso == .neutro)
        verifica.vero("MV4 Memoria: divario sceso in meglio", una("pensione.divario")?.verso == .meglio)
        verifica.vero("MV4 Memoria: obiettivo salito in meglio", una("obiettivo.o-casa")?.verso == .meglio)
        verifica.vero("MV4 Memoria: patrimonio non giudicato", una("patrimonio.alleanza")?.verso == .neutro)
        verifica.vero("MV4 Memoria: debiti scesi in meglio", una("patrimonio.debiti")?.verso == .meglio)
        verifica.vero("MV4 Memoria: completezza salita in meglio", una("completezza")?.verso == .meglio)
        verifica.vero("MV4 Memoria: conformità sistemata in meglio", una("conformita.questionarioAlleanza")?.verso == .meglio)

        // MV5 differenze
        let meno = Formati.meno
        verifica.vero("MV5 Memoria: differenza del divario «−230 €/mese»", una("pensione.divario")?.differenza == "\(meno)230 €/mese")
        verifica.vero("MV5 Memoria: differenza dell'obiettivo «+37 punti»", una("obiettivo.o-casa")?.differenza == "+37 punti")
        verifica.vero("MV5 Memoria: differenza del patrimonio «+9.500 €»", una("patrimonio.alleanza")?.differenza == "+9.500 €")
        verifica.vero("MV5 Memoria: differenza dei debiti «−6.000 €»", una("patrimonio.debiti")?.differenza == "\(meno)6.000 €")
        verifica.vero("MV5 Memoria: differenza della completezza «+15 punti»", una("completezza")?.differenza == "+15 punti")
        verifica.vero("MV5 Memoria: la propensione non ha differenza", una("profilo.propensione") != nil && una("profilo.propensione")?.differenza == nil)

        // MV6 prima e oggi
        verifica.vero("MV6 Memoria: semaforo della pensione prima «giallo · 40% del divario»",
                      una("semaforo.previdenza")?.prima == "giallo · 40% del divario")
        verifica.vero("MV6 Memoria: semaforo della pensione oggi «verde · 85% del divario»",
                      una("semaforo.previdenza")?.oggi == "verde · 85% del divario")
        verifica.vero("MV6 Memoria: divario da «640 €/mese» a «410 €/mese»",
                      una("pensione.divario")?.prima == "640 €/mese" && una("pensione.divario")?.oggi == "410 €/mese")
        verifica.vero("MV6 Memoria: ingresso in famiglia da «—» a «figlia, a carico»",
                      una("famiglia.ingresso.f-sofia")?.prima == "—" && una("famiglia.ingresso.f-sofia")?.oggi == "figlia, a carico")

        // MV7 canali
        verifica.vero("MV7 Memoria: canale Alleanza su patrimonio e conformità",
                      una("patrimonio.alleanza")?.canale == .alleanza && una("conformita.questionarioAlleanza")?.canale == .alleanza)
        verifica.vero("MV7 Memoria: nessun canale sulle altre",
                      v.filter { $0.chiave != "patrimonio.alleanza" && $0.chiave != "conformita.questionarioAlleanza" }.allSatisfy { $0.canale == nil })

        // MV8 aumento
        verifica.vero("MV8 Memoria: divario sceso", una("pensione.divario")?.aumento == false)
        verifica.vero("MV8 Memoria: patrimonio Alleanza salito", una("patrimonio.alleanza")?.aumento == true)
        verifica.vero("MV8 Memoria: propensione senza freccia", una("profilo.propensione") != nil && una("profilo.propensione")?.aumento == nil)

        // MV9 soglie sotto: divario Δ19, scoperto Δ4.999, patrimonio +1,83%, obiettivo 40 → 44 punti
        do {
            var base = p
            base.patrimonioIndipendente = 30_000
            var q = base
            q.divarioPensione = 621
            q.scopertoCasoMorte = 180_001
            q.patrimonioIndipendente = 30_550
            q.obiettivi[0].quota = 0.444
            let w = MotoreMemoria.variazioni(da: base, a: q)
            verifica.vero("MV9 Memoria: sotto le soglie nessuna variazione (\(chiavi(w).joined(separator: ", ")))", w.isEmpty)
        }

        // MV10 soglie sopra: ammanco Δ50, patrimonio da zero, completezza +2 punti con cambio di livello
        do {
            var base = p
            base.patrimonioAlleanza = 0
            base.completezza = 88
            base.livelloCompletezza = "Quasi completi"
            var q = base
            q.ammancoInvalidita = 1_350
            q.patrimonioAlleanza = 600
            q.completezza = 90
            q.livelloCompletezza = "Dati completi"
            let w = MotoreMemoria.variazioni(da: base, a: q)
            verifica.vero("MV10 Memoria: sulle soglie (\(chiavi(w).joined(separator: ", ")))",
                          chiavi(w) == ["protezione.ammanco", "patrimonio.alleanza", "completezza"])
            verifica.vero("MV10 Memoria: testi sulle soglie",
                          testi(w) == ["Ammanco in caso di invalidità da 1.400 a 1.350 €/mese",
                                       "Patrimonio Alleanza da 0 a 600 €",
                                       "Completezza dei dati dall'88% al 90%"])
        }

        // MV11 virgola mobile: 0,40 → 0,45 sono 5 punti interi
        do {
            var q = p
            q.obiettivi[0].quota = 0.45
            let w = MotoreMemoria.variazioni(da: p, a: q)
            verifica.vero("MV11 Memoria: obiettivo dal 40% al 45% (\(testi(w).joined(separator: "; ")))",
                          testi(w) == ["Obiettivo «Casa» dal 40% al 45%"])
        }

        // MV12 patrimonio al 2,5%
        do {
            var base = p
            base.patrimonioIndipendente = 20_000
            var q = base
            q.patrimonioIndipendente = 20_500
            let w = MotoreMemoria.variazioni(da: base, a: q)
            verifica.vero("MV12 Memoria: patrimonio indipendente +500 € (2,5%)",
                          testi(w) == ["Patrimonio Indipendente da 20.000 a 20.500 €"] && w.first?.canale == .indipendente)
        }

        // MV13 fotografie uguali
        verifica.vero("MV13 Memoria: nessuna variazione tra fotografie uguali", MotoreMemoria.variazioni(da: p, a: p).isEmpty)

        // MV14 propensione indicata e tolta
        do {
            var senza = p
            senza.propensione = nil
            var moderata = p
            moderata.propensione = "moderata"
            verifica.vero("MV14 Memoria: propensione indicata",
                          testi(MotoreMemoria.variazioni(da: senza, a: moderata)) == ["Propensione indicata: moderata"])
            verifica.vero("MV14 Memoria: propensione non più indicata",
                          testi(MotoreMemoria.variazioni(da: p, a: senza)) == ["Propensione non più indicata (era dinamica)"])
        }

        // MV15 uscita dalla famiglia e a carico
        do {
            var q = o
            q.famiglia = [Foto.FamiliareFoto(id: "f-luca", nome: "Luca", relazione: "convivente", aCarico: true)]
            let w = MotoreMemoria.variazioni(da: o, a: q)
            verifica.vero("MV15 Memoria: uscita prima di a carico (\(testi(w).joined(separator: "; ")))",
                          testi(w) == ["Non più in famiglia: Sofia (figlia)", "Luca ora è a carico"])
        }

        // MV16 conformità o completezza assenti da un lato
        do {
            var q = o
            q.conformita = nil
            verifica.vero("MV16 Memoria: conformità non rilevata, nessuna variazione di conformità",
                          !MotoreMemoria.variazioni(da: p, a: q).contains { $0.chiave.hasPrefix("conformita.") })
            var r = o
            r.completezza = nil
            verifica.vero("MV16 Memoria: completezza non rilevata, nessuna variazione di completezza",
                          !MotoreMemoria.variazioni(da: p, a: r).contains { $0.chiave == "completezza" })
        }

        // MV17 valori sconosciuti
        do {
            var q = o
            if let i = q.semafori.firstIndex(where: { $0.id == "previdenza" }) { q.semafori[i].colore = "blu" }
            let s = MotoreMemoria.variazioni(da: p, a: q).first { $0.chiave == "semaforo.previdenza" }
            verifica.vero("MV17 Memoria: colore sconosciuto «non indicato» e neutro",
                          s?.testo == "Semaforo «Pensione» da giallo a non indicato" && s?.verso == .neutro)
            var r = o
            r.propensione = "speculativa"
            let t = MotoreMemoria.variazioni(da: p, a: r).first { $0.chiave == "profilo.propensione" }
            verifica.vero("MV17 Memoria: propensione sconosciuta com'è", t?.testo == "Propensione da dinamica a speculativa")
        }

        // MP · Precedente (oggi 29/10/2026, limite 29/9/2026)
        do {
            let vecchia = foto("foto-mp-1", giorno(2025, 10, 1))
            let marzo = foto("foto-mp-2", giorno(2026, 3, 12))
            let recente = foto("foto-mp-3", giorno(2026, 10, 20))
            let altro = foto("foto-mp-altro", giorno(2026, 9, 1), cliente: "altro")
            let elenco = [vecchia, marzo, recente, altro]
            let pr = MotoreMemoria.precedente(elenco, cliente: "prova-memoria", oggi: oggi, cal: cal)
            verifica.vero("MP1 Memoria: la precedente è quella del 12/3/2026", pr?.id == "foto-mp-2")
            verifica.vero("MP2 Memoria: solo una fotografia recente, nessuna precedente",
                          MotoreMemoria.precedente([recente], cliente: "prova-memoria", oggi: oggi, cal: cal) == nil)
            let bordo = foto("foto-mp-bordo", giorno(2026, 9, 29))
            let dopo = foto("foto-mp-dopo", giorno(2026, 9, 30))
            verifica.vero("MP3 Memoria: 30 giorni esatti bastano",
                          MotoreMemoria.precedente([bordo], cliente: "prova-memoria", oggi: oggi, cal: cal)?.id == "foto-mp-bordo")
            verifica.vero("MP3 Memoria: 29 giorni non bastano",
                          MotoreMemoria.precedente([dopo], cliente: "prova-memoria", oggi: oggi, cal: cal) == nil)
            verifica.vero("MP4 Memoria: cronologia dalla più recente",
                          MotoreMemoria.cronologia(elenco, cliente: "prova-memoria").map(\.id) == ["foto-mp-3", "foto-mp-2", "foto-mp-1"])
        }
        let ventiOttobre = foto("foto-20-ottobre", giorno(2026, 10, 20))
        let m = MotoreMemoria.memoria(attuale: o, fotografie: [p, ventiOttobre], oggi: oggi, cal: cal)
        verifica.vero("MP5 Memoria: precedente è P", m.precedente?.id == p.id)
        verifica("MP5 Memoria: 13 variazioni nella memoria", Double(m.variazioni.count), 13)
        verifica("MP5 Memoria: 2 fotografie in cronologia", Double(m.cronologia.count), 2)
        verifica.vero("MP5 Memoria: non è il primo riesame", !m.primoRiesame)

        provaRegistra(verifica, cal: cal)

        // MA · Ordine del giorno
        do {
            let note = "Ordine del giorno:\n1. Rivedere «Fondo»\n2. Recuperare i KID"
            let atteso = ["Ordine del giorno:",
                          "Cosa è cambiato dal riesame del 12 marzo 2026:",
                          "• Propensione da dinamica a moderata",
                          "• In famiglia: Sofia (figlia, a carico)",
                          "• Semaforo «Riserva di emergenza» da verde a giallo",
                          "• Semaforo «Pensione» da giallo a verde",
                          "• Semaforo «Obiettivi» da grigio a verde",
                          "• Divario pensione da 640 a 410 €/mese",
                          "…e altre 7 variazioni nel prospetto del riesame.",
                          "Punti da trattare:",
                          "1. Rivedere «Fondo»",
                          "2. Recuperare i KID"].joined(separator: "\n")
            let a1 = MotoreMemoria.apriConVariazioni(note, memoria: m)
            verifica.vero("MA1 Memoria: l'ordine del giorno si apre con le variazioni", a1 == atteso)
            let a2 = MotoreMemoria.apriConVariazioni(note, memoria: m, massimo: 12)
            let righe2 = a2.components(separatedBy: "\n")
            verifica.vero("MA2 Memoria: con 12 righe «…e un'altra variazione»",
                          righe2.count > 15 && righe2[14] =="…e un'altra variazione nel prospetto del riesame." && righe2[15] == "Punti da trattare:")
            let senza = MotoreMemoria.memoria(attuale: o, fotografie: [], oggi: oggi, cal: cal)
            verifica.vero("MA3 Memoria: senza memoria o senza precedente le note restano uguali",
                          MotoreMemoria.apriConVariazioni(note, memoria: nil) == note
                          && MotoreMemoria.apriConVariazioni(note, memoria: senza) == note)
            var uguale = p
            uguale.id = "foto-uguale"
            uguale.data = cal.startOfDay(for: oggi)
            let ferma = MotoreMemoria.memoria(attuale: uguale, fotografie: [p], oggi: oggi, cal: cal)
            let righe4 = MotoreMemoria.apriConVariazioni(note, memoria: ferma).components(separatedBy: "\n")
            verifica.vero("MA4 Memoria: nessuna variazione dal riesame precedente",
                          righe4.count > 2 && righe4[1] == "Dal riesame del 12 marzo 2026 nessuna variazione delle cifre chiave."
                          && righe4[2] == "Punti da trattare:")
            let libere = "Note libere\nOrdine del giorno:\n1. Altro"
            verifica.vero("MA5 Memoria: note che non cominciano con l'ordine del giorno restano uguali",
                          MotoreMemoria.apriConVariazioni(libere, memoria: m) == libere)
            verifica.vero("MA6 Memoria: comincia sempre con «Ordine del giorno»",
                          [a1, a2, MotoreMemoria.apriConVariazioni(note, memoria: ferma)].allSatisfy { $0.hasPrefix("Ordine del giorno") })
        }

        // MT · Testi
        let tm = TestiMemoria.self
        // Coppie (ottenuto, atteso): niente catene lunghe di && con le stringhe (controllo dei tipi)
        let articoli: [(String, String)] = [(tm.dal(8), "dall'8%"), (tm.al(11), "all'11%"), (tm.dal(80), "dall'80%"),
                                            (tm.al(1), "all'1%"), (tm.dal(0), "dallo 0%"), (tm.al(100), "al 100%"),
                                            (tm.dal(40), "dal 40%")]
        verifica.vero("MT1 Memoria: articoli con le percentuali", articoli.allSatisfy { $0.0 == $0.1 })
        let tempi: [(String, String)] = [(tm.tempoFa(mesi: 0), "meno di un mese fa"), (tm.tempoFa(mesi: 1), "1 mese fa"),
                                         (tm.tempoFa(mesi: 7), "7 mesi fa"), (tm.tempoFa(mesi: 12), "1 anno fa"),
                                         (tm.tempoFa(mesi: 14), "1 anno e 2 mesi fa"), (tm.tempoFa(mesi: 24), "2 anni fa"),
                                         (tm.tempoFa(mesi: 25), "2 anni e 1 mese fa")]
        verifica.vero("MT2 Memoria: quanto tempo fa", tempi.allSatisfy { $0.0 == $0.1 })
        verifica("MT3 Memoria: mesi dal 12/3/2026 al 29/10/2026", Double(tm.mesi(da: AiutiProva.data(2026, 3, 12), a: oggi, cal: cal)), 7)
        verifica("MT3 Memoria: mesi dal 10/8/2025 al 29/10/2026", Double(tm.mesi(da: AiutiProva.data(2025, 8, 10), a: oggi, cal: cal)), 14)
        verifica("MT3 Memoria: mesi dal 1/10/2026 al 29/10/2026", Double(tm.mesi(da: AiutiProva.data(2026, 10, 1), a: oggi, cal: cal)), 0)
        verifica.vero("MT4 Memoria: cifre",
                      tm.cifra(51_500) == "51.500" && tm.cifra(409.6) == "410" && tm.cifra(-6_000) == "\(meno)6.000")
        do {
            var f = foto("foto-mt5", giorno(2026, 10, 29))
            func s(_ c: String) -> Foto.SemaforoFoto { Foto.SemaforoFoto(id: c + "-\(UUID().uuidString.prefix(4))", titolo: "", colore: c, valore: "") }
            f.semafori = [s("rosso"), s("rosso"), s("giallo"), s("verde"), s("verde"), s("verde"), s("verde")]
            verifica.vero("MT5 Memoria: «2 rossi · 1 giallo · 4 verdi»", tm.semafori(f: f) == "2 rossi · 1 giallo · 4 verdi")
            f.semafori = [s("rosso"), s("verde")]
            verifica.vero("MT5 Memoria: «1 rosso · 1 verde»", tm.semafori(f: f) == "1 rosso · 1 verde")
        }
        let d = tm.domande(v)
        verifica.vero("MT6 Memoria: due domande dalle variazioni",
                      d.count == 2 && d[0].hasPrefix("La propensione è passata da dinamica a moderata") && d[1].contains("Sofia"))
    }

    // MARK: - Fotografia del cliente di prova (MF)

    private static func provaFotografia(_ verifica: VerificaCalcoli, cal: Calendar, oggi: Date) {
        var c = Cliente(id: "prova-memoria", nome: "Elena Prova", iniziali: "EP", tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: oggi)
        c.dataNascita = AiutiProva.data(1981, 5, 10)
        c.statoCivile = .convivente
        c.profilo.propensione = .moderata
        c.profilo.orizzonteAnni = 10
        c.profilo.esperienza = .media
        c.famiglia = [Familiare(nome: "Luca", relazione: .convivente),
                      Familiare(nome: "Sofia", relazione: .figlia, aCarico: true)]

        func pos(_ nome: String, _ area: AreaPosizione, _ valore: Double, _ canale: Canale,
                 _ modifica: @escaping (inout Posizione) -> Void = { _ in }) -> Posizione {
            AiutiProva.posizione(nome, area, valore, canale: canale) { p in
                p.clienteId = "prova-memoria"
                modifica(&p)
            }
        }
        let a = pos("Risparmio Alleanza", .risparmio, 40_000, .alleanza)
        let b = pos("Fondo azionario", .investimento, 25_000, .indipendente)
        let cc = pos("Conto", .liquidita, 12_000, .indipendente)
        let tcm = pos("TCM Alleanza", .protezione, 0, .alleanza) { p in
            p.rischio = .vita
            p.capitaleAssicurato = 150_000
        }
        let mutuo = pos("Mutuo", .debiti, 90_000, .indipendente)
        let posizioni = [a, b, cc, tcm, mutuo]

        var analisi = Analisi360()
        analisi.previdenza.redditoDesiderato = 2_200
        analisi.previdenza.pensionePubblica = 1_790
        analisi.protezione.fabbisognoMensile = 2_000
        analisi.protezione.anniSostegno = 10
        analisi.protezione.debiti = 90_000
        analisi.protezione.speseImmediate = 15_000
        analisi.protezione.capitaleDisponibile = 10_000
        analisi.protezione.entrateSostitutive = 600
        analisi.protezione.mesiRiserva = 12
        analisi.protezione.riserva = 5_000

        var casa = Obiettivo(clienteId: "prova-memoria", titolo: "Casa", area: .casa, importo: 60_000, scadenza: AiutiProva.data(2030, 1, 1))
        casa.accantonato = 6_000
        casa.posizioniCollegate = [a.id]

        func scatta(_ an: Analisi360, completezza: DatiCompletezzaFoto? = nil,
                    conformita: [Foto.VoceConformitaFoto]? = nil) -> Foto {
            MotoreMemoria.fotografia(cliente: c, posizioni: posizioni, analisi: an, obiettivi: [casa], oggi: oggi,
                                     origine: .manuale, completezza: completezza, conformita: conformita, cal: cal)
        }
        let f = scatta(analisi)

        verifica.vero("MF1 Memoria: data all'inizio del giorno", f.data == cal.startOfDay(for: oggi))
        verifica.vero("MF1 Memoria: origine «manuale» e schema 1", f.origini == ["manuale"] && f.schema == 1)
        verifica.vero("MF2 Memoria: profilo e stato civile",
                      f.propensione == "moderata" && f.orizzonteAnni == 10 && f.esperienza == "media" && f.statoCivile == "convivente")
        verifica("MF3 Memoria: due familiari", Double(f.famiglia.count), 2)
        verifica("MF3 Memoria: uno a carico", Double(f.aCarico), 1)
        verifica.vero("MF3 Memoria: la seconda è la figlia", f.famiglia.count == 2 && f.famiglia[1].relazione == "figlia")
        verifica("MF4 Memoria: reddito desiderato", f.redditoDesiderato ?? -1, 2_200)
        verifica("MF4 Memoria: pensione pubblica", f.pensionePubblica ?? -1, 1_790)
        verifica("MF4 Memoria: rendita dei piani", f.renditaPiani ?? -1, 0)
        verifica("MF4 Memoria: divario pensione", f.divarioPensione ?? -1, 410)
        verifica("MF5 Memoria: fabbisogno caso morte", f.fabbisognoCasoMorte ?? -1, 335_000)
        verifica("MF5 Memoria: capitale caso morte", f.capitaleCasoMorte ?? -1, 150_000)
        verifica("MF5 Memoria: scoperto caso morte", f.scopertoCasoMorte ?? -1, 185_000)
        verifica("MF5 Memoria: ammanco in caso di invalidità", f.ammancoInvalidita ?? -1, 1_400)
        verifica("MF6 Memoria: un obiettivo", Double(f.obiettivi.count), 1)
        verifica("MF6 Memoria: quota dell'obiettivo (46.000 / 60.000)", f.obiettivi.first?.quota ?? -1, 46_000.0 / 60_000.0, tolleranza: 0.0001)
        verifica("MF6 Memoria: 77%", Double(TestiMemoria.percento(f.obiettivi.first?.quota ?? 0)), 77)
        verifica("MF7 Memoria: patrimonio Alleanza", f.patrimonioAlleanza, 40_000)
        verifica("MF7 Memoria: patrimonio indipendente", f.patrimonioIndipendente, 37_000)
        verifica("MF7 Memoria: debiti", f.debiti, 90_000)
        verifica("MF7 Memoria: patrimonio netto", f.patrimonioNetto, -13_000)
        verifica("MF7 Memoria: proposte aperte", Double(f.proposteAperte), 0)
        let colori = ["riserva": "giallo", "morte": "rosso", "invalidita": "rosso", "previdenza": "rosso",
                      "obiettivi": "verde", "investimenti": "verde", "debiti": "verde"]
        for (id, colore) in colori.sorted(by: { $0.key < $1.key }) {
            verifica.vero("MF8 Memoria: semaforo «\(id)» \(colore) (\(f.semaforo(id)?.colore ?? "assente"))", f.semaforo(id)?.colore == colore)
        }
        verifica.vero("MF9 Memoria: senza completezza e conformità",
                      f.completezza == nil && f.livelloCompletezza == nil && f.conformita == nil)
        let voce = Foto.VoceConformitaFoto(tipo: "questionarioAlleanza", titolo: "Questionario di adeguatezza", canale: .alleanza, stato: "inRegola")
        let g = scatta(analisi, completezza: DatiCompletezzaFoto(percentuale: 77, livello: "Quasi completi"), conformita: [voce])
        verifica.vero("MF10 Memoria: con completezza e conformità",
                      g.completezza == 77 && g.livelloCompletezza == "Quasi completi" && g.conformita?.count == 1 && g.conformitaDaSistemare == 0)
        var rotta = analisi
        rotta.previdenza.pensionePubblica = .nan
        let n = scatta(rotta)
        let cifre: [Double?] = [n.redditoDesiderato, n.pensionePubblica, n.renditaPiani, n.divarioPensione, n.fabbisognoCasoMorte,
                                n.capitaleCasoMorte, n.scopertoCasoMorte, n.ammancoInvalidita]
        let cifreFinite = cifre.allSatisfy { c in c.map { $0.isFinite } ?? true }
        let patrimonioFinito = [n.patrimonioAlleanza, n.patrimonioIndipendente, n.debiti].allSatisfy { $0.isFinite }
        let obiettiviFiniti = n.obiettivi.allSatisfy { $0.quota.isFinite && $0.importo.isFinite }
        verifica.vero("MF11 Memoria: nessun numero non finito nella fotografia", cifreFinite && patrimonioFinito && obiettiviFiniti)
    }

    // MARK: - Registrazione (MR)

    private static func provaRegistra(_ verifica: VerificaCalcoli, cal: Calendar) {
        func giorno(_ a: Int, _ m: Int, _ g: Int) -> Date { cal.startOfDay(for: AiutiProva.data(a, m, g)) }
        var a = foto("foto-mr-a", giorno(2026, 3, 12))
        a.origini = ["prospetto"]
        var n1 = foto("foto-mr-1", giorno(2026, 10, 20))
        n1.origini = ["incontro"]
        let r1 = MotoreMemoria.registra(n1, in: [a], cal: cal)
        verifica.vero("MR1 Memoria: la nuova si aggiunge in fondo", r1.map(\.id) == ["foto-mr-a", "foto-mr-1"])

        var n2 = foto("foto-mr-2", giorno(2026, 10, 29))
        n2.origini = ["prospetto"]
        n2.patrimonioAlleanza = 51_500
        let r2 = MotoreMemoria.registra(n2, in: r1, cal: cal)
        verifica("MR2 Memoria: 9 giorni dopo sostituisce, restano 2", Double(r2.count), 2)
        let s: Foto? = r2.count == 2 ? r2[1] : nil
        verifica.vero("MR2 Memoria: tiene l'id della fotografia del 20/10", s?.id == "foto-mr-1")
        verifica.vero("MR2 Memoria: data e cifre della nuova", s?.data == giorno(2026, 10, 29) && s?.patrimonioAlleanza == 51_500)
        verifica.vero("MR2 Memoria: origini unite", s?.origini == ["incontro", "prospetto"])

        let bordo = foto("foto-mr-bordo", giorno(2026, 9, 29))
        verifica("MR3 Memoria: 30 giorni dopo non sostituisce", Double(MotoreMemoria.registra(n2, in: [bordo], cal: cal).count), 2)

        let altro = foto("foto-mr-altro", giorno(2026, 10, 25), cliente: "altro")
        let r4 = MotoreMemoria.registra(n2, in: [altro, a, n1], cal: cal)
        verifica.vero("MR4 Memoria: la fotografia di un altro cliente resta dov'era",
                      r4.map(\.id) == ["foto-mr-altro", "foto-mr-a", "foto-mr-1"] && r4[0] == altro)

        var elenco: [Foto] = []
        let inizio = giorno(2023, 1, 1)
        for i in 0..<31 {
            let d = cal.date(byAdding: .day, value: 40 * i, to: inizio) ?? inizio
            elenco = MotoreMemoria.registra(foto("foto-mr5-\(i)", cal.startOfDay(for: d)), in: elenco, cal: cal)
        }
        let mie = MotoreMemoria.cronologia(elenco, cliente: "prova-memoria")
        verifica("MR5 Memoria: tetto di 20 fotografie", Double(mie.count), Double(MotoreMemoria.massimoPerCliente))
        verifica.vero("MR5 Memoria: la più vecchia rimasta è del 16/3/2024", mie.last?.data == giorno(2024, 3, 16))
        verifica.vero("MR5 Memoria: c'è l'ultima del 15/4/2026", mie.first?.data == giorno(2026, 4, 15))
    }

    // MARK: - Dati di prova

    /// Una fotografia vuota del cliente di prova.
    private static func foto(_ id: String, _ data: Date, cliente: String = "prova-memoria") -> Foto {
        var f = Foto(clienteId: cliente, data: data)
        f.id = id
        return f
    }

    /// La fotografia `P` del 12/3/2026 (§8.1).
    static func primaDiProva(cal: Calendar = Calendar(identifier: .gregorian)) -> Foto {
        var p = foto("foto-p", cal.startOfDay(for: AiutiProva.data(2026, 3, 12)))
        p.origini = ["prospetto"]
        p.propensione = "dinamica"
        p.orizzonteAnni = 15
        p.esperienza = "media"
        p.statoCivile = "convivente"
        p.famiglia = [Foto.FamiliareFoto(id: "f-luca", nome: "Luca", relazione: "convivente", aCarico: false)]
        p.semafori = [Foto.SemaforoFoto(id: "previdenza", titolo: "Pensione", colore: "giallo", valore: "40% del divario"),
                      Foto.SemaforoFoto(id: "morte", titolo: "Protezione della famiglia", colore: "rosso", valore: "45% coperto"),
                      Foto.SemaforoFoto(id: "riserva", titolo: "Riserva di emergenza", colore: "verde", valore: "12 mesi su 12"),
                      Foto.SemaforoFoto(id: "obiettivi", titolo: "Obiettivi", colore: "grigio", valore: "da definire")]
        p.divarioPensione = 640
        p.scopertoCasoMorte = 185_000
        p.ammancoInvalidita = 1_400
        p.obiettivi = [Foto.ObiettivoFoto(id: "o-casa", titolo: "Casa", importo: 60_000, scadenza: nil, quota: 0.40),
                       Foto.ObiettivoFoto(id: "o-auto", titolo: "Auto", importo: 15_000, scadenza: nil, quota: 0.70)]
        p.patrimonioAlleanza = 42_000
        p.patrimonioIndipendente = 37_000
        p.debiti = 96_000
        p.completezza = 62
        p.livelloCompletezza = "Quasi completi"
        p.conformita = [Foto.VoceConformitaFoto(tipo: "questionarioAlleanza", titolo: "Questionario di adeguatezza", canale: .alleanza, stato: "scaduta"),
                        Foto.VoceConformitaFoto(tipo: "privacy", titolo: "Informativa privacy", canale: nil, stato: "inRegola")]
        return p
    }

    /// La fotografia `O` del 29/10/2026 (§8.1).
    static func oggiDiProva(cal: Calendar = Calendar(identifier: .gregorian)) -> Foto {
        var o = primaDiProva(cal: cal)
        o.id = "foto-o"
        o.data = cal.startOfDay(for: AiutiProva.data(2026, 10, 29))
        o.origini = ["manuale"]
        o.propensione = "moderata"
        o.famiglia.append(Foto.FamiliareFoto(id: "f-sofia", nome: "Sofia", relazione: "figlia", aCarico: true))
        o.semafori = [Foto.SemaforoFoto(id: "riserva", titolo: "Riserva di emergenza", colore: "giallo", valore: "6 mesi su 12"),
                      Foto.SemaforoFoto(id: "morte", titolo: "Protezione della famiglia", colore: "rosso", valore: "52% coperto"),
                      Foto.SemaforoFoto(id: "previdenza", titolo: "Pensione", colore: "verde", valore: "85% del divario"),
                      Foto.SemaforoFoto(id: "obiettivi", titolo: "Obiettivi", colore: "verde", valore: "77% in media")]
        o.divarioPensione = 410
        o.scopertoCasoMorte = 182_000
        o.ammancoInvalidita = 1_400
        o.obiettivi = [Foto.ObiettivoFoto(id: "o-casa", titolo: "Casa", importo: 60_000, scadenza: nil, quota: 0.77),
                       Foto.ObiettivoFoto(id: "o-uni", titolo: "Università di Sofia", importo: 30_000, scadenza: nil, quota: 0.10)]
        o.patrimonioAlleanza = 51_500
        o.patrimonioIndipendente = 37_300
        o.debiti = 90_000
        o.completezza = 77
        o.livelloCompletezza = "Quasi completi"
        o.conformita = [Foto.VoceConformitaFoto(tipo: "questionarioAlleanza", titolo: "Questionario di adeguatezza", canale: .alleanza, stato: "inRegola"),
                        Foto.VoceConformitaFoto(tipo: "privacy", titolo: "Informativa privacy", canale: nil, stato: "inRegola")]
        return o
    }
}
