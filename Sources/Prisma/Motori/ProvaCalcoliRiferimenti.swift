import Foundation

/// Prove del rendimento contro un riferimento (giro 6, specifica 11, §8.1, RF1–RF13): giorni e fattore del
/// riferimento, anni stimati e mancanti, TFR ricavato dall'inflazione, valori del consulente, confronto con
/// l'andamento, versamenti al riferimento (PME), metro per tipo di posizione, lettura dall'archivio, valori di Prisma.
/// Chiamate da `ProvaCalcoli.esegui()`: gli errori si sommano. Le tabelle di prova usano i valori del consulente
/// (o un indice), così non dipendono dai valori precompilati, salvo RF12. Valori attesi da `calcoli_riferimenti.py`.
enum ProvaCalcoliRiferimenti {
    static func esegui(_ verifica: VerificaCalcoli) {
        fattori(verifica)
        tfr(verifica)
        confronto(verifica)
        versamenti(verifica)
        famiglie(verifica)
        archivio(verifica)
        valoriDiPrisma(verifica)
        periodoBreve(verifica)
        testi(verifica)
    }

    // MARK: - Aiuti

    private static let indice = "indice-prova"

    private static func d(_ anno: Int, _ mese: Int, _ giorno: Int) -> Date { AiutiProva.data(anno, mese, giorno) }

    /// Una tabella con l'indice di prova e i suoi valori (e, se servono, valori del consulente per le serie di Prisma).
    private static func tabella(indice valori: [Int: Double], altri: [ValoreRiferimento] = []) -> TabellaRiferimenti {
        var r = RiferimentiRendimento()
        r.indici = [IndiceRiferimento(id: indice, nome: "Prova")]
        r.valori = valori.sorted { $0.key < $1.key }.map { ValoreRiferimento(serie: indice, anno: $0.key, valore: $0.value) } + altri
        return TabellaRiferimenti(r)
    }

    private static func fattore(_ valori: [Int: Double], _ dal: Date, _ al: Date) -> FattoreRiferimento {
        MotoreRiferimenti.fattore(indice, dal: dal, al: al, tabella: tabella(indice: valori))
    }

    // MARK: - RF1–RF5b: giorni e fattore

    private static func fattori(_ verifica: VerificaCalcoli) {
        let f1 = fattore([2024: 2.0], d(2024, 1, 1), d(2025, 1, 1))
        verifica("Riferimenti: RF1 fattore di un anno intero", f1.fattore ?? -1, 1.02, tolleranza: 1e-9)
        verifica("Riferimenti: RF1 un solo anno", Double(f1.anni.count), 1)
        verifica("Riferimenti: RF1 366 giorni su 366",
                 f1.anni.first.map { Double($0.giorni * 1_000 + $0.giorniAnno) } ?? -1, 366_366)

        let f2 = fattore([2023: 6.0, 2024: 1.0], d(2023, 7, 1), d(2024, 7, 1))
        verifica("Riferimenti: RF2 giorni del 2023", Double(f2.anni.first { $0.anno == 2023 }?.giorni ?? -1), 184)
        verifica("Riferimenti: RF2 giorni del 2024", Double(f2.anni.first { $0.anno == 2024 }?.giorni ?? -1), 182)
        verifica("Riferimenti: RF2 fattore a cavallo di due anni", f2.fattore ?? -1, 1.0349176870, tolleranza: 1e-8)

        let f3 = fattore([2024: 1.0], d(2025, 1, 1), d(2026, 1, 1))
        verifica("Riferimenti: RF3 anno stimato con l'ultimo noto", f3.fattore ?? -1, 1.01, tolleranza: 1e-9)
        verifica.vero("Riferimenti: RF3 il 2025 è stimato", f3.stimati == [2025])
        verifica.vero("Riferimenti: RF3 non da aggiornare", !f3.daAggiornare)
        verifica.vero("Riferimenti: RF3 origine stimata", f3.anni.first?.origine == .stimato)

        let f4 = fattore([2022: 8.0, 2024: 1.0], d(2022, 1, 1), d(2025, 1, 1))
        verifica.vero("Riferimenti: RF4 anno mancante in mezzo: nessun fattore", f4.fattore == nil)
        verifica.vero("Riferimenti: RF4 manca il 2023", f4.mancanti == [2023])

        let f5 = fattore([2023: 5.4], d(2025, 1, 1), d(2026, 6, 1))
        verifica.vero("Riferimenti: RF5 valori troppo vecchi: nessun fattore", f5.fattore == nil)
        verifica.vero("Riferimenti: RF5 da aggiornare", f5.daAggiornare)

        let f5b = fattore([2024: 1.0], d(2025, 1, 1), d(2026, 6, 1))
        verifica("Riferimenti: RF5b due anni stimati", f5b.fattore ?? -1, 1.0141661716, tolleranza: 1e-8)
        verifica.vero("Riferimenti: RF5b stimati 2025 e 2026", f5b.stimati == [2025, 2026])

        let vuoto = fattore([2024: 1.0], d(2025, 1, 1), d(2025, 1, 1))
        verifica("Riferimenti: periodo vuoto, fattore 1", vuoto.fattore ?? -1, 1, tolleranza: 1e-12)
    }

    // MARK: - RF6–RF7: TFR ricavato dall'inflazione e valori del consulente

    private static func tfr(_ verifica: VerificaCalcoli) {
        verifica("Riferimenti: RF6 TFR netto con inflazione 11,3", RegoleTFR.rivalutazioneNetta(inflazione: 11.3), 8.27925, tolleranza: 1e-9)
        verifica("Riferimenti: RF6 TFR netto con inflazione negativa", RegoleTFR.rivalutazioneNetta(inflazione: -0.2), 1.245, tolleranza: 1e-9)
        verifica("Riferimenti: RF6 TFR netto con inflazione 0,6", RegoleTFR.rivalutazioneNetta(inflazione: 0.6), 1.6185, tolleranza: 1e-9)
        verifica("Riferimenti: RF6 TFR lordo con inflazione 11,3", RegoleTFR.rivalutazioneLorda(inflazione: 11.3), 9.975, tolleranza: 1e-9)

        var r = RiferimentiRendimento()
        r.valori = [ValoreRiferimento(serie: SerieRiferimento.idInflazione, anno: 2022, valore: 11.6)]
        let t = TabellaRiferimenti(r)
        let inflazione = t.valore(SerieRiferimento.idInflazione, anno: 2022)
        verifica("Riferimenti: RF7 inflazione corretta dal consulente", inflazione?.valore ?? -1, 11.6, tolleranza: 1e-9)
        verifica.vero("Riferimenti: RF7 origine del consulente", inflazione?.origine == .consulente)
        let tfr = t.valore(SerieRiferimento.idTFR, anno: 2022)
        verifica("Riferimenti: RF7 TFR dall'inflazione corretta", tfr?.valore ?? -1, 8.466, tolleranza: 1e-9)
        verifica.vero("Riferimenti: RF7 TFR con l'origine dell'inflazione", tfr?.origine == .consulente)
    }

    // MARK: - RF8: confronto con l'andamento

    private static func confronto(_ verifica: VerificaCalcoli) {
        let p = AiutiProva.posizione("ETF di prova", .investimento, 10_500) {
            $0.tipologia = "ETF"
            $0.rilevazioni = [Rilevazione(data: d(2024, 1, 1), controvalore: 10_000, versato: 10_000)]
            $0.dataValore = d(2025, 1, 1)
            $0.totaleVersato = 10_000
        }
        var r = RiferimentiRendimento()
        r.valori = [ValoreRiferimento(serie: SerieRiferimento.idInflazione, anno: 2024, valore: 1.0)]
        let t = TabellaRiferimenti(r)
        guard let a = MotoreAndamento.calcola(p) else {
            verifica.vero("Riferimenti: RF8 andamento della posizione di prova", false)
            return
        }
        let scelta = MotoreRiferimenti.serieDi(p, impostazioni: r, tabella: t)
        verifica.vero("Riferimenti: RF8 metro dell'ETF: inflazione", scelta.serie.id == SerieRiferimento.idInflazione && scelta.rispettata)
        let c = MotoreRiferimenti.confronto(p, andamento: a, flussi: nil, serie: scelta.serie, rispettata: scelta.rispettata, tabella: t)
        verifica.vero("Riferimenti: RF8 confronto annuo", c.annuo)
        verifica("Riferimenti: RF8 anni", c.anni, 1.002053, tolleranza: 1e-6)
        verifica("Riferimenti: RF8 rendimento della posizione", c.effettivo, 4.989503, tolleranza: 1e-4)
        verifica("Riferimenti: RF8 rendimento del riferimento", c.riferimento ?? -1, 0.997941, tolleranza: 1e-4)
        verifica("Riferimenti: RF8 differenza", c.scarto ?? -1, 3.991562, tolleranza: 1e-4)
        verifica("Riferimenti: RF8 rendimento reale", c.reale ?? -1, 3.952122, tolleranza: 1e-4)
        verifica.vero("Riferimenti: RF8 giudizio sopra", c.giudizio == .sopra)
        verifica("Riferimenti: RF8 linea al ritmo del riferimento", c.punti.last?.atteso ?? -1, 10_100, tolleranza: 0.01)
        verifica("Riferimenti: RF8 linea dal primo valore", c.punti.first?.atteso ?? -1, 10_000, tolleranza: 0.01)
        verifica.vero("Riferimenti: RF8 senza flussi nessun confronto dei versamenti", c.versamenti == nil && c.versamentiMancantiDal == nil)
    }

    // MARK: - RF9: versamenti al riferimento (PME)

    private static func versamenti(_ verifica: VerificaCalcoli) {
        let f = MotoreResoconto.FlussiDatati(flussi: [(data: d(2023, 1, 1), importo: 10_000), (data: d(2024, 1, 1), importo: 5_000)],
                                             valore: 16_000, fine: d(2025, 1, 1), reali: true)
        let t = tabella(indice: [2023: 6.0, 2024: 1.0])
        let v = MotoreRiferimenti.versamenti(f, serie: indice, tabella: t)
        verifica("Riferimenti: RF9 versamenti al ritmo del riferimento", v.esito?.valoreRiferimento ?? -1, 15_756, tolleranza: 0.01)
        verifica("Riferimenti: RF9 differenza con il valore vero", v.esito?.differenza ?? -1, 244, tolleranza: 0.01)
        verifica("Riferimenti: RF9 rendimento dei versamenti al riferimento", v.esito?.tassoRiferimento ?? -1, 2.983323, tolleranza: 0.001)
        verifica("Riferimenti: RF9 rendimento dei versamenti effettivo", v.esito?.tassoEffettivo ?? -1, 3.931415, tolleranza: 0.001)
        verifica.vero("Riferimenti: RF9 nessun anno mancante", v.mancantiDal == nil)

        // Un flusso prima dei valori: niente confronto, e l'anno da cui servono i valori
        let vecchio = MotoreResoconto.FlussiDatati(flussi: [(data: d(2021, 6, 1), importo: 10_000)],
                                                   valore: 12_000, fine: d(2025, 1, 1), reali: true)
        let m = MotoreRiferimenti.versamenti(vecchio, serie: indice, tabella: t)
        verifica.vero("Riferimenti: RF9 versamenti con anni mancanti: nessun confronto", m.esito == nil)
        verifica("Riferimenti: RF9 servono i valori dal 2021", Double(m.mancantiDal ?? -1), 2021)
    }

    // MARK: - RF10: il metro per tipo di posizione

    private static func famiglie(_ verifica: VerificaCalcoli) {
        let vuote = RiferimentiRendimento()
        let t = tabella(indice: [2024: 5.0])
        let pip = AiutiProva.posizione("PIP di prova", .previdenza, 10_000)
        let polizza = AiutiProva.posizione("Polizza rivalutabile (Ramo I)", .risparmio, 10_000) {
            $0.tipologia = "Polizza rivalutabile (Ramo I)"
        }
        let etf = AiutiProva.posizione("ETF di prova", .investimento, 10_000) { $0.tipologia = "ETF" }

        verifica.vero("Riferimenti: RF10 famiglia del PIP", FamigliaRiferimento.di(pip) == .previdenza)
        verifica.vero("Riferimenti: RF10 famiglia della rivalutabile", FamigliaRiferimento.di(polizza) == .gestioneSeparata)
        verifica.vero("Riferimenti: RF10 famiglia dell'ETF", FamigliaRiferimento.di(etf) == .mercato)

        let sPip = MotoreRiferimenti.serieDi(pip, impostazioni: vuote, tabella: t)
        verifica.vero("Riferimenti: RF10 PIP contro il TFR", sPip.serie.id == SerieRiferimento.idTFR && sPip.rispettata)
        let sPolizza = MotoreRiferimenti.serieDi(polizza, impostazioni: vuote, tabella: t)
        verifica.vero("Riferimenti: RF10 gestioni separate vuote: ripiego sull'inflazione",
                      sPolizza.serie.id == SerieRiferimento.idInflazione && !sPolizza.rispettata)
        let sEtf = MotoreRiferimenti.serieDi(etf, impostazioni: vuote, tabella: t)
        verifica.vero("Riferimenti: RF10 ETF contro l'inflazione", sEtf.serie.id == SerieRiferimento.idInflazione && sEtf.rispettata)

        var etfIndice = etf
        etfIndice.riferimento = indice
        let sScelta = MotoreRiferimenti.serieDi(etfIndice, impostazioni: vuote, tabella: t)
        verifica.vero("Riferimenti: RF10 metro scelto per la posizione", sScelta.serie.id == indice && sScelta.rispettata)

        var perMercato = RiferimentiRendimento()
        perMercato.indici = [IndiceRiferimento(id: indice, nome: "Prova")]
        perMercato.perMercato = indice
        let sTipo = MotoreRiferimenti.serieDi(etf, impostazioni: perMercato, tabella: t)
        verifica.vero("Riferimenti: RF10 metro del tipo nelle impostazioni", sTipo.serie.id == indice && sTipo.rispettata)

        var etfVecchio = etf
        etfVecchio.riferimento = "indice-eliminato"
        let sVecchio = MotoreRiferimenti.serieDi(etfVecchio, impostazioni: vuote, tabella: t)
        verifica.vero("Riferimenti: RF10 indice che non c'è più: regola successiva",
                      sVecchio.serie.id == SerieRiferimento.idInflazione && sVecchio.rispettata)

        // Una scelta esplicita senza valori non ripiega: il pannello chiede i valori
        var esplicita = RiferimentiRendimento()
        esplicita.perGestioneSeparata = SerieRiferimento.idGestioniSeparate
        let sEsplicita = MotoreRiferimenti.serieDi(polizza, impostazioni: esplicita, tabella: t)
        verifica.vero("Riferimenti: RF10 scelta esplicita senza valori non ripiega",
                      sEsplicita.serie.id == SerieRiferimento.idGestioniSeparate && sEsplicita.rispettata)
    }

    // MARK: - RF11: lettura dall'archivio

    private static func archivio(_ verifica: VerificaCalcoli) {
        let json = #"{"valori":[{"serie":3,"anno":"x"},{"serie":"inflazione-foi","anno":2024,"valore":1.5}],"indici":[{"nome":7},{"id":"indice-a","nome":"A"}],"perMercato":"indice-a"}"#
        let r = try? Archivio.decodificatore.decode(RiferimentiRendimento.self, from: Data(json.utf8))
        verifica("Riferimenti: RF11 valore malformato scartato, l'altro resta", Double(r?.valori.count ?? -1), 1)
        verifica("Riferimenti: RF11 valore leggibile conservato", r?.valori.first?.valore ?? -1, 1.5)
        verifica("Riferimenti: RF11 indice illeggibile scartato", Double(r?.indici.count ?? -1), 1)
        verifica.vero("Riferimenti: RF11 scelta del tipo conservata", r?.perMercato == "indice-a")

        let impostazioni = try? Archivio.decodificatore.decode(Impostazioni.self, from: Data("{}".utf8))
        verifica.vero("Riferimenti: RF11 impostazioni senza riferimenti", impostazioni?.riferimenti == RiferimentiRendimento())

        var conMetro = AiutiProva.posizione("ETF di prova", .investimento, 10_000)
        conMetro.riferimento = indice
        let grezzo = (try? Archivio.codificatore.encode(conMetro)).flatMap { try? JSONSerialization.jsonObject(with: $0) }
        var oggetto: [String: Any] = (grezzo as? [String: Any]) ?? [:]
        verifica.vero("Riferimenti: RF11 metro della posizione scritto nell'archivio", oggetto["riferimento"] as? String == indice)
        oggetto["riferimento"] = nil
        let letta = (try? JSONSerialization.data(withJSONObject: oggetto)).flatMap { try? Archivio.decodificatore.decode(Posizione.self, from: $0) }
        verifica.vero("Riferimenti: RF11 posizione senza metro letta", letta != nil && letta?.riferimento == nil)

        let ipotesi = try? Archivio.decodificatore.decode(IpotesiTFR.self, from: Data(#"{"anni": 99, "retribuzione": "molta"}"#.utf8))
        verifica("Riferimenti: RF11 anni del TFR riportati al limite", Double(ipotesi?.anni ?? -1), 50)
        verifica("Riferimenti: RF11 retribuzione illeggibile: predefinita", ipotesi?.retribuzione ?? -1, 30_000)

        var andata = RiferimentiRendimento()
        andata.valori = [ValoreRiferimento(serie: SerieRiferimento.idInflazione, anno: 2025, valore: 2.0)]
        andata.indici = [IndiceRiferimento(id: indice, nome: "Prova", fonte: "prova")]
        andata.perPrevidenza = indice
        andata.rivistiIl = d(2026, 1, 20)
        let ritorno = (try? Archivio.codificatore.encode(andata)).flatMap { try? Archivio.decodificatore.decode(RiferimentiRendimento.self, from: $0) }
        verifica.vero("Riferimenti: RF11 riferimenti identici dopo andata e ritorno", ritorno == andata)
    }

    // MARK: - RF12: i valori di Prisma

    private static func valoriDiPrisma(_ verifica: VerificaCalcoli) {
        let t = TabellaRiferimenti(RiferimentiRendimento())
        let v2022 = t.valore(SerieRiferimento.idInflazione, anno: 2022)
        verifica("Riferimenti: RF12 inflazione 2022 di Prisma", v2022?.valore ?? -1, 11.3, tolleranza: 1e-9)
        verifica.vero("Riferimenti: RF12 origine di Prisma", v2022?.origine == .prisma)
        verifica.vero("Riferimenti: RF12 il 2020 non è precompilato", t.valore(SerieRiferimento.idInflazione, anno: 2020) == nil)
        verifica.vero("Riferimenti: RF12 il 2019 non è precompilato", t.valore(SerieRiferimento.idInflazione, anno: 2019) == nil)
        verifica("Riferimenti: RF12 ultimo anno dell'inflazione", Double(t.ultimoAnno(SerieRiferimento.idInflazione) ?? -1), 2023)
        verifica.vero("Riferimenti: RF12 gestioni separate vuote", t.ultimoAnno(SerieRiferimento.idGestioniSeparate) == nil)
        verifica("Riferimenti: RF12 ultimo anno del TFR", Double(t.ultimoAnno(SerieRiferimento.idTFR) ?? -1), 2023)
        verifica("Riferimenti: RF12 TFR 2023 dall'inflazione 0,6", t.valore(SerieRiferimento.idTFR, anno: 2023)?.valore ?? -1, 1.6185, tolleranza: 1e-9)
        let elenco: [SerieRiferimento] = t.serie
        verifica.vero("Riferimenti: RF12 serie di Prisma in ordine",
                      elenco.map(\.id) == [SerieRiferimento.idInflazione, SerieRiferimento.idTFR, SerieRiferimento.idGestioniSeparate])
        verifica.vero("Riferimenti: RF12 un indice sconosciuto non ha valori", t.valore("indice-sconosciuto", anno: 2022) == nil)
    }

    // MARK: - RF13: meno di tre mesi

    private static func periodoBreve(_ verifica: VerificaCalcoli) {
        let p = AiutiProva.posizione("ETF di prova", .investimento, 10_100) {
            $0.tipologia = "ETF"
            $0.rilevazioni = [Rilevazione(data: d(2025, 1, 1), controvalore: 10_000, versato: 10_000)]
            $0.dataValore = d(2025, 3, 2)
            $0.totaleVersato = 10_000
        }
        let t = tabella(indice: [2025: 2.0])
        guard let a = MotoreAndamento.calcola(p), let s = t.serie(indice) else {
            verifica.vero("Riferimenti: RF13 andamento della posizione di prova", false)
            return
        }
        let c = MotoreRiferimenti.confronto(p, andamento: a, flussi: nil, serie: s, rispettata: true, tabella: t)
        verifica.vero("Riferimenti: RF13 confronto nel periodo", !c.annuo)
        verifica.vero("Riferimenti: RF13 nessun giudizio sotto i tre mesi", c.giudizio == nil)
        verifica("Riferimenti: RF13 riferimento nel periodo", c.riferimento ?? -1, 0.326053, tolleranza: 1e-5)
        verifica.vero("Riferimenti: RF13 nessun rendimento reale con un indice", c.reale == nil)
    }

    // MARK: - Testi

    private static func testi(_ verifica: VerificaCalcoli) {
        let tfr = TabellaRiferimenti.serieTFR
        let inflazione = TabellaRiferimenti.serieInflazione
        let gestioni = TabellaRiferimenti.serieGestioniSeparate
        verifica.vero("Riferimenti: pillola sopra il TFR", TestiRiferimenti.pillola(.sopra, tfr) == "Sopra il TFR")
        verifica.vero("Riferimenti: pillola in linea con l'inflazione", TestiRiferimenti.pillola(.inLinea, inflazione) == "In linea con l'inflazione")
        verifica.vero("Riferimenti: pillola sotto le gestioni separate", TestiRiferimenti.pillola(.sotto, gestioni) == "Sotto le gestioni separate")
        verifica.vero("Riferimenti: legenda al ritmo dell'inflazione", TestiRiferimenti.legendaLinea(inflazione) == "Al ritmo dell'inflazione")
        verifica.vero("Riferimenti: anni stimati al plurale",
                      TestiRiferimenti.stimati([2025, 2026], ultimo: 2024).hasPrefix("Il 2025 e il 2026 non sono ancora pubblicati"))
        verifica.vero("Riferimenti: anno stimato al singolare",
                      TestiRiferimenti.stimati([2026], ultimo: 2025) == "Il 2026 non è ancora pubblicato: Prisma usa il valore del 2025. A inizio anno aggiorna i valori.")
        verifica.vero("Riferimenti: anni mancanti",
                      TestiRiferimenti.mancanti([2019, 2018], inflazione) == "Mancano i valori del 2018 e del 2019 per «Inflazione (FOI)»: senza, il confronto non si può fare.")
        verifica.vero("Riferimenti: valori da aggiornare",
                      TestiRiferimenti.daAggiornare(inflazione, ultimo: 2023) == "I valori di «Inflazione (FOI)» arrivano al 2023: aggiungi gli anni dopo in Impostazioni › Riferimenti.")
        verifica.vero("Riferimenti: ripiego sulle gestioni separate",
                      TestiRiferimenti.ripiego(gestioni).hasPrefix("Le gestioni separate non hanno ancora valori"))
        verifica.vero("Riferimenti: cinque punti di metodo", TestiRiferimenti.metodo.count == 5)
    }
}
