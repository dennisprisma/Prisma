import Foundation

/// Prova automatica dei motori di calcolo (`Prisma --prova-calcoli`), eseguita dal workflow.
/// Ogni caso confronta il motore con un risultato calcolato a parte (formula chiusa o conto a mano).
enum ProvaCalcoli {
    static func esegui() -> Int32 {
        var errori = 0
        func verifica(_ nome: String, _ ottenuto: Double, _ atteso: Double, tolleranza: Double = 0.01) {
            let ok = abs(ottenuto - atteso) <= tolleranza
            print("\(ok ? "OK   " : "ERRORE") \(nome): \(String(format: "%.2f", ottenuto)) (atteso \(String(format: "%.2f", atteso)))")
            if !ok { errori += 1 }
        }

        // 1. Senza costi né imposte: formula chiusa dell'interesse composto con versamenti a inizio mese
        let r = pow(1.05, 1.0 / 12) - 1
        let n = 120.0
        let formula = 1_000 * pow(1 + r, n) + 100 * (pow(1 + r, n) - 1) / r * (1 + r)
        let e1 = MotoreProiezione.calcola(.init(capitaleIniziale: 1_000, versamento: 100, frequenza: .mensile, anni: 10,
                                                rendimento: 5, aliquotaFiscale: 0, inflazione: 0))
        verifica("Interesse composto, 1.000 € + 100 €/mese, 5%, 10 anni", e1.netto, formula)
        verifica("Versato in 10 anni", e1.versato, 13_000)

        // 2. Rendimento zero e nessun costo: si riottiene il versato
        let e2 = MotoreProiezione.calcola(.init(capitaleIniziale: 5_000, versamento: 250, frequenza: .trimestrale, anni: 3,
                                                rendimento: 0, aliquotaFiscale: 26, inflazione: 0))
        verifica("Rendimento zero: netto uguale al versato", e2.netto, 8_000)

        // 3. Costo annuo dell'1% su 10.000 € a rendimento zero per un anno
        let e3 = MotoreProiezione.calcola(.init(capitaleIniziale: 10_000, versamento: 0, frequenza: .unica, anni: 1,
                                                rendimento: 0, costoAnnuo: 1, aliquotaFiscale: 0, inflazione: 0))
        verifica("Costo annuo 1%: valore dopo un anno", e3.netto, 9_900)
        verifica("Costo annuo 1%: costi", e3.costi, 100)

        // 4. Costo d'ingresso del 3% sul capitale
        let e4 = MotoreProiezione.calcola(.init(capitaleIniziale: 10_000, versamento: 0, frequenza: .unica, anni: 1,
                                                rendimento: 0, costoIngresso: 3, aliquotaFiscale: 0, inflazione: 0))
        verifica("Costo d'ingresso 3%", e4.netto, 9_700)

        // 5. Imposte del 26% sulla plusvalenza e inflazione del 2%
        let e5 = MotoreProiezione.calcola(.init(capitaleIniziale: 10_000, versamento: 0, frequenza: .unica, anni: 1,
                                                rendimento: 10, aliquotaFiscale: 26, inflazione: 2))
        verifica("Lordo a un anno al 10%", e5.lordo, 11_000)
        verifica("Imposte al 26% sui 1.000 € di guadagno", e5.imposte, 260)
        verifica("Netto", e5.netto, 10_740)
        verifica("In euro di oggi (inflazione 2%)", e5.reale, 10_740 / 1.02)

        // 6. Nessuna imposta se c'è una perdita
        let e6 = MotoreProiezione.calcola(.init(capitaleIniziale: 10_000, versamento: 0, frequenza: .unica, anni: 2,
                                                rendimento: -5, aliquotaFiscale: 26, inflazione: 0))
        verifica("Nessuna imposta in perdita", e6.imposte, 0)
        verifica("Valore in perdita (-5% per 2 anni)", e6.netto, 10_000 * 0.95 * 0.95)

        // 7. Riepilogo delle posizioni di prova di Giulia Rossi (conto a mano)
        let giulia = DatiDemo.posizioni().filter { $0.clienteId == "giulia" }
        let r7 = RiepilogoPosizioni(giulia)
        verifica("Giulia: attività in essere", r7.attivita, 7_650 + 36_400 + 21_000 + 24_000 + 210_000)
        verifica("Giulia: debiti", r7.debiti, 95_000)
        verifica("Giulia: patrimonio netto", r7.patrimonioNetto, 299_050 - 95_000)
        verifica("Giulia: premi e versamenti annui (rate del mutuo escluse)", r7.premiAnnui, (150 + 22 + 300) * 12)
        verifica("Giulia: capitale assicurato", r7.capitaleAssicurato, 150_000)
        verifica("Giulia: proposte aperte", Double(r7.proposteAperte), 1)
        verifica("Giulia: valore delle proposte (un anno di premi)", r7.valoreProposte, 200 * 12)
        verifica("Giulia: quota Alleanza sulle attività", r7.quota(.alleanza), 7_650 / 299_050, tolleranza: 0.000_1)

        // 8. Versamento necessario: con il versamento trovato si raggiunge l'obiettivo
        let base = ParametriProiezione(capitaleIniziale: 5_000, versamento: 0, frequenza: .mensile, anni: 10,
                                       rendimento: 3, costoAnnuo: 1, aliquotaFiscale: 26, inflazione: 0)
        if let v = MotoreAnalisi.versamentoNecessario(base, obiettivo: 60_000) {
            var q = base
            q.versamento = v
            verifica("Versamento necessario: netto all'obiettivo", MotoreProiezione.calcola(q).netto, 60_000, tolleranza: 0.5)
        } else {
            verifica("Versamento necessario trovato", 0, 1)
        }
        verifica("Versamento necessario nullo se il capitale basta",
                 MotoreAnalisi.versamentoNecessario(base, obiettivo: 1_000) ?? -1, 0)
        // Senza rendimento né costi: (obiettivo − capitale) / mesi
        let piatto = ParametriProiezione(capitaleIniziale: 0, versamento: 0, frequenza: .mensile, anni: 5, rendimento: 0,
                                         aliquotaFiscale: 0, inflazione: 0)
        verifica("Versamento necessario a rendimento zero", MotoreAnalisi.versamentoNecessario(piatto, obiettivo: 30_000) ?? 0,
                 500, tolleranza: 0.01)

        // 9. Previdenza: divario 800 €/mese per 25 anni
        var prev = IpotesiPrevidenza()
        prev.eta = 40; prev.etaPensione = 67; prev.redditoDesiderato = 2_200; prev.pensionePubblica = 1_400
        prev.capitale = 0; prev.versamentoMensile = 0; prev.rendimentoReale = 0; prev.anniIntegrazione = 25
        let p9 = MotoreAnalisi.previdenza(prev)
        verifica("Previdenza: divario mensile", p9.divario, 800)
        verifica("Previdenza: capitale obiettivo", p9.capitaleObiettivo, 800 * 12 * 25)
        verifica("Previdenza: versamento teorico a rendimento zero", p9.versamentoTeorico ?? 0, 240_000 / Double(27 * 12))

        // 10. Protezione di Giulia: fabbisogno e divario con la sua temporanea caso morte da 150.000 €
        var prot = IpotesiProtezione()
        prot.debiti = 95_000; prot.speseImmediate = 15_000; prot.fabbisognoMensile = 1_800; prot.anniSostegno = 10
        prot.capitaleDisponibile = 10_000; prot.entrateSostitutive = 600; prot.mesiRiserva = 12; prot.riserva = 5_000
        let p10 = MotoreAnalisi.protezione(prot, posizioni: giulia)
        verifica("Protezione: fabbisogno", p10.fabbisogno, 95_000 + 15_000 + 216_000 - 10_000)
        verifica("Protezione: capitale caso morte in essere", p10.capitaleVita, 150_000)
        verifica("Protezione: divario", p10.divario, 316_000 - 150_000)
        verifica("Protezione: riserva mancante", p10.riservaMancante, 1_200 * 12 - 5_000)

        // 11. Risparmio: obiettivo rivalutato all'inflazione
        var ris = IpotesiRisparmio()
        ris.obiettivo = 50_000; ris.inflazione = 2; ris.anni = 10
        verifica("Risparmio: obiettivo a scadenza", MotoreAnalisi.risparmio(ris).obiettivoNominale, 50_000 * pow(1.02, 10))

        // 12. Analisi ricavata dalle posizioni di Giulia
        let a12 = Analisi360(cliente: nil, posizioni: giulia)
        verifica("Analisi di Giulia: capitale degli investimenti", a12.investimenti.capitale, 36_400 + 21_000)
        verifica("Analisi di Giulia: debiti", a12.protezione.debiti, 95_000)

        // 13. Profilo dei bisogni: rilevazione dai dati e ruota
        let clienti = DatiDemo.clienti()
        if let cg = clienti.first(where: { $0.id == "giulia" }), let cm = clienti.first(where: { $0.id == "marco" }) {
            let marco = DatiDemo.posizioni().filter { $0.clienteId == "marco" }
            let rg = MotoreBisogni.rileva(cliente: cg, posizioni: giulia, analisi: Analisi360(cliente: cg, posizioni: giulia))
            let rm = MotoreBisogni.rileva(cliente: cm, posizioni: marco, analisi: Analisi360(cliente: cm, posizioni: marco))
            verifica("Giulia: rilevata la previdenza da avviare", rg.contains { $0.id == "previdenza-assente" } ? 1 : 0, 1)
            verifica("Giulia: rilevato l'acquisto della casa (evento di vita)", rg.contains { $0.area == .casa && $0.importanza == .alta } ? 1 : 0, 1)
            verifica("Marco: rilevata la protezione della famiglia", rm.contains { $0.id == "protezione-famiglia" } ? 1 : 0, 1)
            let ruota = MotoreBisogni.ruota(rg, profilo: cg.bisogni)
            verifica("Giulia: casa al massimo nella ruota", Double(ruota[.casa]?.rawValue ?? 0), 3)
            var scartato = cg.bisogni
            scartato.esiti["previdenza-assente"] = false
            scartato.imposta(ValutazioneBisogno(area: .pensione, importanza: .nessuna))
            verifica("Bisogno scartato: la pensione esce dalla ruota", Double(MotoreBisogni.ruota(rg, profilo: scartato)[.pensione]?.rawValue ?? 9), 0)
        }

        // 14. Estrazione dagli appunti di un incontro (regole)
        let anno = Calendar(identifier: .gregorian).component(.year, from: Date())
        let appunti = """
        Mi preoccupa molto il mutuo se dovesse succedere qualcosa a mio marito.
        Vorremmo comprare casa nel \(anno + 2), una villetta da 300.000 €.
        Preparare il confronto tra le due polizze
        """
        let proposte = EstrattoreIncontro.conRegole(appunti)
        verifica("Appunti: bisogno casa con importanza alta (preoccupazione)",
                 proposte.contains { $0.tipo == .bisogno(.casa, .alta) } ? 1 : 0, 1)
        verifica("Appunti: evento acquisto casa con l'anno citato",
                 proposte.contains { $0.tipo == .evento(.acquistoCasa, anno + 2) } ? 1 : 0, 1)
        verifica("Appunti: decisione trasformata in attività",
                 proposte.contains { if case .attivita = $0.tipo { return true } else { return false } } ? 1 : 0, 1)
        verifica("Appunti: i numeri come 300.000 non spezzano le frasi",
                 Double(EstrattoreIncontro.frasi("Una villetta da 300.000 €. Poi altro").count), 2)
        let dalleRisposte = EstrattoreIncontro.conRegole("Comprare un trilocale in città nel \(anno + 3)",
                                                          preoccupazioni: "Il mutuo, se succedesse qualcosa a uno dei due")
        verifica("Risposte: trilocale riconosciuto come acquisto della casa",
                 dalleRisposte.contains { $0.tipo == .evento(.acquistoCasa, anno + 3) } ? 1 : 0, 1)
        verifica("Risposte: ciò che preoccupa vale importanza alta",
                 dalleRisposte.contains { $0.tipo == .bisogno(.casa, .alta) } ? 1 : 0, 1)
        let dalModello = EstrattoreIncontro.daRisposta("BISOGNO|pensione|alta|vuole smettere presto\nEVENTO|pensione|\(anno + 9)|\nVOCE|non valida\nBISOGNO|marte|alta|x")
        verifica("Risposta del modello: righe valide accettate, le altre scartate", Double(dalModello.count), 2)

        // 15. Obiettivi: avanzamento con le posizioni collegate e versamento necessario
        var o = Obiettivo(clienteId: "giulia", titolo: "Prova", area: .casa, importo: 30_000,
                          scadenza: Calendar.current.date(byAdding: .month, value: 66, to: Date()) ?? Date())
        o.accantonato = 6_000
        o.rendimento = 0
        let av = AvanzamentoObiettivo(o, posizioni: giulia)
        verifica("Obiettivo: quota raggiunta", av.quota, 0.2, tolleranza: 0.000_1)
        verifica("Obiettivo: versamento necessario a rendimento zero (6 anni)", av.versamentoNecessario ?? 0, 24_000 / 72, tolleranza: 0.01)
        o.posizioniCollegate = ["pos-giulia-conto-corrente-e-conto-deposito"]
        verifica("Obiettivo: le posizioni collegate contano come accantonato",
                 AvanzamentoObiettivo(o, posizioni: giulia).accantonato, 6_000 + 24_000)

        // 16. Scheda prodotto: la proposta eredita condizioni, canale e collegamento
        if let pip = DatiDemo.prodotti().first(where: { $0.id == "prodotto-previdenza-pip" }) {
            let proposta = pip.proposta(per: "andrea")
            verifica("Proposta dalla scheda: costo annuo", proposta.costoAnnuo ?? 0, 1.4)
            verifica("Proposta dalla scheda: canale Alleanza e stato proposta",
                     proposta.canale == .alleanza && proposta.stato == .proposta && proposta.prodottoId == pip.id ? 1 : 0, 1)
        }

        // 17. Lettura dei documenti: regole sul KID e sulla polizza di prova, con la pagina giusta
        if let kid = DatiDemo.testoDocumento("doc-giulia-kid") {
            let campi = EstrattoreDocumento.conRegole(kid)
            func c(_ k: CampoDocumento) -> CampoEstratto? { campi.first { $0.chiave == k } }
            verifica("KID: indicatore di rischio 3 su 7", Double(c(.sri)?.valore ?? "") ?? 0, 3)
            verifica("KID: SRI trovato a pagina 2", Double(c(.sri)?.pagina ?? 0), 2)
            verifica("KID: periodo di detenzione 15 anni", EstrattoreDocumento.numero(c(.periodoDetenzione)?.valore) ?? 0, 15)
            verifica("KID: costi correnti 0,85%", EstrattoreDocumento.numero(c(.costoAnnuo)?.valore) ?? 0, 0.85, tolleranza: 0.000_1)
            verifica("KID: incidenza annuale dei costi 0,95%", EstrattoreDocumento.numero(c(.incidenzaCosti)?.valore) ?? 0, 0.95, tolleranza: 0.000_1)
            verifica("KID: rendimento scenario moderato 3,2%", EstrattoreDocumento.numero(c(.rendimentoModerato)?.valore) ?? 0, 3.2, tolleranza: 0.000_1)
            verifica("KID: riconosciuto come KID", EstrattoreDocumento.tipoProbabile(kid) == .kid ? 1 : 0, 1)
        } else {
            verifica("KID di prova presente", 0, 1)
        }
        if let polizza = DatiDemo.testoDocumento("doc-marco-polizza") {
            let campi = EstrattoreDocumento.conRegole(polizza)
            func c(_ k: CampoDocumento) -> CampoEstratto? { campi.first { $0.chiave == k } }
            verifica("Polizza: numero AL-2025-551203", c(.numeroContratto)?.valore == "AL-2025-551203" ? 1 : 0, 1)
            verifica("Polizza: capitale assicurato", EstrattoreDocumento.numero(c(.capitaleAssicurato)?.valore) ?? 0, 150_000)
            verifica("Polizza: premio annuo", EstrattoreDocumento.numero(c(.premio)?.valore) ?? 0, 380)
            let giorni = EstrattoreDocumento.data(c(.decorrenza)?.valore).flatMap { d in
                EstrattoreDocumento.data(c(.scadenza)?.valore).map { Calendar(identifier: .gregorian).dateComponents([.day], from: d, to: $0).day ?? 0 }
            } ?? 0
            verifica("Polizza: da decorrenza a scadenza un anno", Double(giorni), 365)
        } else {
            verifica("Polizza di prova presente", 0, 1)
        }

        // 17b. Lettura dei documenti: le varianti dei documenti reali (testi inventati, con le formule
        // standard del KID PRIIPs dal 2023, di polizze e di estratti conto)
        do {
            let kid = [
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
            let campi = EstrattoreDocumento.conRegole(kid)
            func c(_ k: CampoDocumento) -> CampoEstratto? { campi.first { $0.chiave == k } }
            verifica("KID 2023: nome del prodotto", c(.nomeProdotto)?.valore == "Esempio Multiramo Futuro" ? 1 : 0, 1)
            verifica("KID 2023: ideatore", c(.emittente)?.valore == "Esempio Vita S.p.A." ? 1 : 0, 1)
            verifica("KID 2023: rischio «al livello 4 su 7»", Double(c(.sri)?.valore ?? "") ?? 0, 4)
            verifica("KID 2023: periodo raccomandato sulla riga sotto", EstrattoreDocumento.numero(c(.periodoDetenzione)?.valore) ?? 0, 8)
            verifica("KID 2023: scenario moderato, colonna del periodo raccomandato", EstrattoreDocumento.numero(c(.rendimentoModerato)?.valore) ?? 0, 2.7, tolleranza: 0.000_1)
            verifica("KID 2023: incidenza dei costi, colonna del periodo raccomandato", EstrattoreDocumento.numero(c(.incidenzaCosti)?.valore) ?? 0, 1.9, tolleranza: 0.000_1)
            verifica("KID 2023: costi di ingresso", EstrattoreDocumento.numero(c(.costoIngresso)?.valore) ?? 0, 2.5, tolleranza: 0.000_1)
            verifica("KID 2023: «non addebitiamo» costi di uscita = 0", c(.costoUscita)?.valore == "0" ? 1 : 0, 1)
            verifica("KID 2023: costi correnti", EstrattoreDocumento.numero(c(.costoAnnuo)?.valore) ?? 0, 1.6, tolleranza: 0.000_1)
            verifica("KID 2023: dati alla pagina giusta", Double(c(.incidenzaCosti)?.pagina ?? 0) * 10 + Double(c(.sri)?.pagina ?? 0), 32)

            let polizza = ["""
                Numero di polizza: 0045/778812
                Contraente: Paola Esempio
                Assicurato: Paola Esempio
                Beneficiari caso morte: gli eredi testamentari o, in mancanza, legittimi
                Data di decorrenza ore 24 del 15 marzo 2024
                Data di scadenza: 15/03/2034
                Capitale assicurato caso morte: € 120.000,00
                Premio annuo lordo: € 456,30
                """]
            let cp = EstrattoreDocumento.conRegole(polizza)
            func p(_ k: CampoDocumento) -> CampoEstratto? { cp.first { $0.chiave == k } }
            verifica("Polizza: «Numero di polizza»", p(.numeroContratto)?.valore == "0045/778812" ? 1 : 0, 1)
            verifica("Polizza: beneficiari caso morte", p(.beneficiari)?.valore.hasPrefix("gli eredi") == true ? 1 : 0, 1)
            let decorrenza = EstrattoreDocumento.data(p(.decorrenza)?.valore)
            verifica("Polizza: decorrenza scritta in lettere", decorrenza.map { Double(Calendar(identifier: .gregorian).component(.month, from: $0)) } ?? 0, 3)
            verifica("Polizza: capitale «caso morte» con il simbolo €", EstrattoreDocumento.numero(p(.capitaleAssicurato)?.valore) ?? 0, 120_000)
            verifica("Polizza: «premio annuo lordo»", EstrattoreDocumento.numero(p(.premio)?.valore) ?? 0, 456.3, tolleranza: 0.001)

            let estratto = ["""
                Estratto conto al 30/09/2026
                Controvalore complessivo al 30/09/2026: € 25.430,12
                """]
            let ce = EstrattoreDocumento.conRegole(estratto)
            verifica("Estratto conto: controvalore dopo la data", EstrattoreDocumento.numero(ce.first { $0.chiave == .controvalore }?.valore) ?? 0, 25_430.12, tolleranza: 0.001)
            verifica("Estratto conto: riconosciuto", EstrattoreDocumento.tipoProbabile(estratto) == .estrattoConto ? 1 : 0, 1)
            // Percentuali e anni non sono importi
            let trappole = ["""
                Valore di riscatto pari al 95% del capitale investito
                Capitale caso morte: 101% del capitale versato
                Somma assicurata rivalutata del 2,5% ogni anno
                Scenario moderato  Rendimento medio per ciascun anno  −3,2%
                Costi correnti 1.20% all'anno
                """]
            let ct = EstrattoreDocumento.conRegole(trappole)
            func t(_ k: CampoDocumento) -> CampoEstratto? { ct.first { $0.chiave == k } }
            verifica("Trappole: «95% del capitale» non è un controvalore", t(.controvalore) == nil ? 1 : 0, 1)
            verifica("Trappole: «101% del capitale» né «2,5%» sono un capitale assicurato", t(.capitaleAssicurato) == nil ? 1 : 0, 1)
            verifica("Trappole: «−3,2%» resta negativo", EstrattoreDocumento.numero(t(.rendimentoModerato)?.valore) ?? 0, -3.2, tolleranza: 0.000_1)
            verifica("Trappole: «1.20%» con il punto decimale", EstrattoreDocumento.numero(t(.costoAnnuo)?.valore) ?? 0, 1.2, tolleranza: 0.000_1)
            verifica("Numeri dal modello: «1200.50»", EstrattoreDocumento.numero("1200.50") ?? 0, 1200.5, tolleranza: 0.001)
            let dalModello = EstrattoreDocumento.daRisposta("sri|3/7\nperiodoDetenzione|5 anni\ncostoAnnuo|1,20%", pagina: 1)
            verifica("Valori del modello normalizzati («3/7», «5 anni», «1,20%»)",
                     dalModello.map(\.valore) == ["3", "5", "1,20"] ? 1 : 0, 1)
        }
        verifica("Numeri all'italiana: 1.250,50", EstrattoreDocumento.numero("1.250,50 €") ?? 0, 1_250.5, tolleranza: 0.000_1)
        let modello = EstrattoreDocumento.daRisposta("sri|9\ncostoAnnuo|1,10\ninventato|x\npremio|", pagina: 4)
        verifica("Risposta del modello: tiene solo le righe valide", Double(modello.count), 1)
        let uniti = EstrattoreDocumento.unisci([CampoEstratto(chiave: .costoAnnuo, valore: "0,90", pagina: 2)], modello)
        verifica("Le regole hanno la precedenza sul modello", EstrattoreDocumento.numero(uniti.first?.valore) ?? 0, 0.9, tolleranza: 0.000_1)

        // 18. Valutazione di riscatto: le cifre del prospetto illustrativo di Denis (Orizzonte Valore, € 50.000, 30/70)
        if let v = DatiDemo.valutazioni().first, let c = DatiDemo.orizzonteValore().condizioni {
            let e = MotoreValutazione.calcola(v, condizioni: c)
            verifica("Valutazione: costo d'ingresso con il massimo di € 200", e.ingresso, 200)
            verifica("Valutazione: capitale nel Fondo Interno", e.partiIniziali["fi-allocazione-dinamica"] ?? 0, 34_860)
            let attesi: [(TipoScenario, Int, Double)] = [
                (.favorevole, 2, 52_227), (.intermedio, 2, 50_178), (.sfavorevole, 2, 47_168),
                (.favorevole, 3, 56_852), (.intermedio, 3, 52_317), (.sfavorevole, 3, 46_794),
                (.intermedio, 4, 54_804), (.intermedio, 5, 57_228),
                (.favorevole, 6, 74_684), (.intermedio, 6, 59_330), (.sfavorevole, 6, 45_554),
            ]
            for (t, anno, netto) in attesi {
                verifica("Valutazione: \(t.nome.lowercased()), riscatto all'inizio del \(anno)° anno",
                         e.scenario(t)?.riscatto(anno: anno)?.netto ?? 0, netto, tolleranza: 1.5)
            }
            if let i = e.scenario(.intermedio), let r2 = i.riscatto(anno: 2), let r3 = i.riscatto(anno: 3), let r6 = i.riscatto(anno: 6) {
                verifica("Valutazione: valore del contratto al 13° mese", r2.valore, 52_161, tolleranza: 1)
                verifica("Valutazione: penale del 3,5% al 13° mese", r2.penale, 1_826, tolleranza: 1)
                verifica("Valutazione: imposta sostitutiva al 13° mese", r2.imposta, 83, tolleranza: 1)
                verifica("Valutazione: bollo maturato al 25° mese", r3.bollo, 152, tolleranza: 1)
                verifica("Valutazione: rendimento lordo medio al 13° mese (come il KID)", r2.rendimentoLordo, 0.67)
                verifica("Valutazione: rendimento lordo medio al 61° mese", r6.rendimentoLordo, 4.73)
                verifica("Valutazione: rendimento netto medio al 61° mese", r6.rendimentoMedio, 3.48)
                verifica("Valutazione: costi del 1° anno", i.costi[0].totale, 1_434, tolleranza: 1.5)
                verifica("Valutazione: costi del 5° anno", i.costi[4].totale, 1_521, tolleranza: 1.5)
                verifica("Valutazione: incidenza dei costi nel 1° anno", i.costi[0].incidenza, 2.81)
                let cascata = MotoreValutazione.cascata(e, i)
                verifica("Valutazione: rendimento dei mercati nel 1° anno", cascata.first { $0.genere == .piu }?.importo ?? 0, 3_521, tolleranza: 1.5)
                verifica("Valutazione: la cascata arriva al netto", cascata.last?.importo ?? 0, r2.netto, tolleranza: 0.01)
            }
            verifica("Valutazione: aliquota media delle parti", MotoreValutazione.aliquotaMedia(c), 24.77)
        } else {
            verifica("Valutazione di prova presente", 0, 1)
        }

        // 19. Resoconto delle posizioni in essere: rendimento dei versamenti, ultimi 12 mesi, totali
        let cinque = MotoreResoconto.Flussi(versamenti: [(mesi: 36, importo: 10_000)], valore: 10_000 * pow(1.05, 3))
        verifica("Resoconto: rendimento annuo di 10.000 € diventati 11.576 € in 3 anni", MotoreResoconto.tir([cinque]) ?? 0, 5)
        let due = MotoreResoconto.Flussi(versamenti: [(mesi: 24, importo: 5_000)], valore: 5_000 * pow(1.05, 2))
        verifica("Resoconto: rendimento annuo di due posizioni al 5%", MotoreResoconto.tir([cinque, due]) ?? 0, 5)
        let mensili = MotoreResoconto.Flussi(versamenti: (0..<12).map { (mesi: Double(12 - $0), importo: 100.0) }, valore: 1_200)
        verifica("Resoconto: versamenti senza guadagno, rendimento zero", MotoreResoconto.tir([mensili]) ?? 1, 0)
        let cal = Calendar(identifier: .gregorian)
        let oggi = cal.startOfDay(for: Date())
        var prova = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .investimento, nome: "Prova")
        prova.decorrenza = cal.date(byAdding: .year, value: -2, to: oggi)
        prova.dataValore = oggi
        prova.versamentoIniziale = 10_000
        prova.totaleVersato = 10_000
        prova.controvalore = 11_025
        verifica("Resoconto: rendimento di una posizione (10.000 € → 11.025 € in 2 anni)", MotoreResoconto.voce(prova).rendimentoAnnuo ?? 0, 5, tolleranza: 0.05)
        verifica("Resoconto: risultato sul versato", MotoreResoconto.voce(prova).risultato ?? 0, 1_025)
        prova.totaleVersato = 21_200
        prova.controvalore = 22_400
        prova.rilevazioni = [Rilevazione(data: cal.date(byAdding: .day, value: -365, to: oggi) ?? oggi, controvalore: 20_000, versato: 20_000)]
        verifica("Resoconto: ultimi 12 mesi al netto dei 1.200 € versati", MotoreResoconto.voce(prova).variazione12 ?? 0, 1_200)
        verifica("Resoconto: ultimi 12 mesi in percentuale (Dietz)", MotoreResoconto.voce(prova).variazione12Percento ?? 0, 1_200 / 20_600 * 100)
        var aggiornata = prova
        aggiornata.controvalore = 23_000
        aggiornata.dataValore = cal.date(byAdding: .day, value: 1, to: oggi)
        aggiornata.registraValorePrecedente(prova)
        verifica("Resoconto: il valore precedente resta nello storico", Double(aggiornata.rilevazioni?.count ?? 0), 2)
        verifica("Resoconto: storico con il valore attuale in fondo", aggiornata.storicoValori.last?.controvalore ?? 0, 23_000)

        // Andamento effettivo: periodi tra un valore e l'altro (Dietz), concatenati, contro l'atteso netto
        let unAnno = MotoreAndamento.anno
        var storica = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .investimento, nome: "Fondo storico")
        storica.decorrenza = oggi.addingTimeInterval(-2 * unAnno)
        storica.versamentoIniziale = 10_000
        storica.rilevazioni = [Rilevazione(data: oggi.addingTimeInterval(-2 * unAnno), controvalore: 10_000, versato: 10_000),
                               Rilevazione(data: oggi.addingTimeInterval(-unAnno), controvalore: 10_500, versato: 10_000)]
        storica.controvalore = 11_000
        storica.totaleVersato = 10_000
        storica.dataValore = oggi
        storica.rendimentoAtteso = 6
        storica.costoAnnuo = 1
        if let a = MotoreAndamento.calcola(storica) {
            verifica("Andamento: due periodi", Double(a.periodi.count), 2)
            verifica("Andamento: +5% poi +4,76%, in tutto +10%", a.rendimentoPeriodo, 10)
            verifica("Andamento: all'anno √1,10 − 1", a.rendimentoAnnuo ?? 0, (sqrt(1.1) - 1) * 100)
            verifica("Andamento: atteso netto dei costi (6% − 1%)", a.attesoAnnuo ?? 0, 5)
            verifica("Andamento: 4,88% contro 5% è in linea", a.giudizio == .inLinea ? 1 : 0, 1)
            verifica("Andamento: la linea dell'atteso parte dal primo valore", a.punti.first?.atteso ?? 0, 10_000)
            verifica("Andamento: all'atteso in due anni senza versamenti", a.punti.last?.atteso ?? 0, 10_000 * 1.05 * 1.05, tolleranza: 0.5)
        } else {
            verifica("Andamento: calcolato con tre valori", 0, 1)
        }
        // Un versamento a metà: non è guadagno
        storica.rilevazioni?[1] = Rilevazione(data: oggi.addingTimeInterval(-unAnno), controvalore: 11_500, versato: 11_000)
        storica.totaleVersato = 11_000
        storica.controvalore = 11_000
        if let a = MotoreAndamento.calcola(storica) {
            verifica("Andamento: 1.000 € versati tolti dal guadagno del primo periodo", a.periodi[0].guadagno, 500)
            verifica("Andamento: rendimento del primo periodo su 10.000 + metà dei versamenti", a.periodi[0].rendimento ?? 0, 500 / 10_500 * 100)
            verifica("Andamento: il secondo periodo perde", a.periodi[1].guadagno, -500)
            verifica("Andamento: sotto l'atteso", a.giudizio == .sotto ? 1 : 0, 1)
        }
        // Senza il versato: i premi periodici del periodo come versamenti stimati
        storica.rilevazioni = [Rilevazione(data: oggi.addingTimeInterval(-unAnno), controvalore: 10_000, versato: nil)]
        storica.totaleVersato = nil
        storica.premio = 100
        storica.frequenza = .mensile
        storica.controvalore = 11_700
        if let a = MotoreAndamento.calcola(storica) {
            verifica("Andamento: versamenti stimati dai premi (1.200 € in un anno)", a.versamenti, 1_200)
            verifica("Andamento: guadagno tolti i premi", a.guadagno, 500)
            verifica("Andamento: segnalati come stimati", a.stimati ? 1 : 0, 1)
            verifica("Andamento: un anno si annualizza", a.rendimentoAnnuo == nil ? 0 : 1, 1)
        }
        // Meno di un anno: rendimento del periodo, atteso in proporzione
        storica.rilevazioni = [Rilevazione(data: oggi.addingTimeInterval(-unAnno / 2), controvalore: 10_000, versato: 10_000)]
        storica.totaleVersato = 10_000
        storica.premio = 0
        storica.controvalore = 10_100
        if let a = MotoreAndamento.calcola(storica) {
            verifica("Andamento: sei mesi non si annualizzano", a.rendimentoAnnuo == nil ? 1 : 0, 1)
            verifica("Andamento: atteso netto su sei mesi", a.attesoConfrontabile ?? 0, (sqrt(1.05) - 1) * 100)
        }
        // Riscatto parziale: escono metà del valore e metà del versato, il rendimento resta zero
        var riscatto = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .investimento, nome: "Riscatto")
        riscatto.rilevazioni = [Rilevazione(data: oggi.addingTimeInterval(-unAnno), controvalore: 20_000, versato: 10_000)]
        riscatto.controvalore = 10_000
        riscatto.totaleVersato = 5_000
        riscatto.dataValore = oggi
        verifica("Andamento: un riscatto parziale non è una perdita", MotoreAndamento.calcola(riscatto)?.rendimentoPeriodo ?? -99, 0, tolleranza: 0.05)
        // Tre settimane di storico: l'andamento c'è, il giudizio no
        var breve = riscatto
        breve.rilevazioni = [Rilevazione(data: oggi.addingTimeInterval(-21 * 86_400), controvalore: 10_000, versato: 5_000)]
        breve.controvalore = 9_800
        breve.rendimentoAtteso = 3.5
        verifica("Andamento: tre settimane non bastano per un giudizio", MotoreAndamento.calcola(breve).map { $0.giudizio == nil ? 1 : 0 } ?? 0, 1)
        // Posizione senza data del valore: il nuovo valore è di oggi e lo storico resta in ordine
        var senzaData = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .investimento, nome: "Senza data")
        senzaData.decorrenza = cal.date(byAdding: .year, value: -6, to: oggi)
        senzaData.creataIl = cal.date(byAdding: .month, value: -10, to: oggi) ?? oggi
        senzaData.controvalore = 10_000
        senzaData.totaleVersato = 10_000
        let primaSenzaData = senzaData
        senzaData.controvalore = 12_000
        senzaData.registraValorePrecedente(primaSenzaData)
        let ordinato = senzaData.storicoValori
        verifica("Storico: senza data del valore resta in ordine, l'ultimo è quello nuovo",
                 zip(ordinato, ordinato.dropFirst()).allSatisfy { $0.data < $1.data } && ordinato.last?.controvalore == 12_000 ? 1 : 0, 1)
        verifica("Storico: 10.000 → 12.000 è un guadagno", MotoreAndamento.calcola(senzaData)?.guadagno ?? 0, 2_000)
        storica.rilevazioni = nil
        verifica("Andamento: con un solo valore non c'è", MotoreAndamento.calcola(storica) == nil ? 1 : 0, 1)
        var copertura = storica
        copertura.area = .protezione
        copertura.rilevazioni = [Rilevazione(data: oggi.addingTimeInterval(-unAnno), controvalore: 10_000, versato: 10_000)]
        verifica("Andamento: le coperture non hanno andamento", MotoreAndamento.calcola(copertura) == nil ? 1 : 0, 1)
        let demoConStorico = DatiDemo.posizioni().filter { $0.stato == .inEssere && $0.area.proiettabile }.compactMap(MotoreAndamento.calcola)
        verifica("Andamento: le posizioni di prova hanno un andamento annuo", demoConStorico.filter { $0.rendimentoAnnuo != nil }.isEmpty ? 0 : 1, 1)
        let resocontoGiulia = MotoreResoconto.calcola(DatiDemo.posizioni().filter { $0.clienteId == "giulia" }, cliente: "Giulia Rossi")
        verifica("Resoconto di Giulia: versato nelle posizioni finanziarie", resocontoGiulia.versato, 58_000)
        verifica("Resoconto di Giulia: valore delle posizioni finanziarie", resocontoGiulia.valoreFinanziario, 65_050)
        verifica("Resoconto di Giulia: patrimonio netto", resocontoGiulia.riepilogo.patrimonioNetto, 204_050)
        // Gestione, trattenuto e bollo: piano 91,80 (trattenuto) + ETF 72,80 + 72,80 + fondo 231 + 42 + conto deposito 48
        verifica("Resoconto di Giulia: costi stimati di un anno", resocontoGiulia.costoAnnuo, 558.4)
        verifica("Resoconto di Giulia: posizioni in essere", Double(resocontoGiulia.voci.count), 7)
        verifica("Resoconto di Giulia: storico di 12 mesi su tutte le finanziarie", Double(resocontoGiulia.conStorico.count), 3)

        // 20. Fiscalità: aliquote della previdenza, imposte sul guadagno, netto incassabile (conti a mano)
        for (anni, attesa) in [(5, 15.0), (15, 15.0), (16, 14.7), (25, 12.0), (34, 9.3), (35, 9.0), (40, 9.0)] {
            verifica("Previdenza: aliquota con \(anni) anni di partecipazione", RegoleFiscali.aliquotaPrevidenza(anni: anni), attesa, tolleranza: 0.0001)
        }
        verifica("Previdenza: anticipazione per la casa al 23% anche con 5 anni", CausaPrevidenza.anticipazioneCasa.aliquota(anni: 5), 23)
        verifica("Aliquota effettiva con il 60% in titoli di Stato", RegoleFiscali.aliquotaEffettiva(quotaTitoliStato: 60), 17.9, tolleranza: 0.0001)
        let demo = DatiDemo.posizioni()
        if let pip = demo.first(where: { $0.id == "pos-marco-piano-individuale-pensionistico" }) {
            let f = MotoreFiscale.calcola(pip)
            let uscita: (CausaPrevidenza) -> UscitaPrevidenza? = { c in f.uscite.first { $0.causa == c } }
            verifica("PIP di Marco: anni di partecipazione", Double(f.anniPartecipazione ?? 0), 10)
            verifica("PIP di Marco: imposta al pensionamento (15% su 28.000 € dedotti)", uscita(.pensione)?.imposta ?? 0, 4_200)
            verifica("PIP di Marco: netto al pensionamento", uscita(.pensione)?.netto ?? 0, 33_800)
            verifica("PIP di Marco: anticipazione casa, 75% di 38.000 €", uscita(.anticipazioneCasa)?.importo ?? 0, 28_500)
            verifica("PIP di Marco: anticipazione casa, imposta al 23% sulla parte dedotta", uscita(.anticipazioneCasa)?.imposta ?? 0, 4_830)
            verifica("PIP di Marco: ulteriori esigenze, imposta al 23% su 8.400 €", uscita(.anticipazioneUlteriori)?.imposta ?? 0, 1_932)
        } else {
            verifica("PIP di Marco presente", 0, 1)
        }
        if let fp = demo.first(where: { $0.id == "pos-laura-fondo-pensione-aperto" }) {
            let f = MotoreFiscale.calcola(fp)
            verifica("Fondo pensione di Laura: 17 anni dalla prima adesione, aliquota 14,40%", f.aliquota, 14.4, tolleranza: 0.0001)
            verifica("Fondo pensione di Laura: imposta al pensionamento", f.imposta, 2_073.6)
            verifica("Fondo pensione di Laura: anticipazione casa non ancora possibile? (17 anni: sì)", (f.uscite.first { $0.causa == .anticipazioneCasa }?.possibile ?? false) ? 1 : 0, 1)
        }
        if let pol = demo.first(where: { $0.id == "pos-marco-polizza-rivalutabile-a-premio-unico" }) {
            let f = MotoreFiscale.calcola(pol)
            verifica("Polizza rivalutabile di Marco: imposta al 17,90% su 4.300 €", f.imposta, 769.7)
            verifica("Polizza rivalutabile di Marco: nessun bollo (Ramo I)", f.bolloMaturato + f.costoBollo, 0)
            verifica("Polizza rivalutabile di Marco: trattenuto 1,30% su 54.300 €", f.costoTrattenuto, 705.9)
            verifica("Polizza rivalutabile di Marco: netto incassabile", f.netto, 53_530.3)
        }
        if let etf = demo.first(where: { $0.id == "pos-giulia-etf-azionario-globale" }) {
            let f = MotoreFiscale.calcola(etf)
            verifica("ETF di Giulia: imposta al 26% su 5.600 €", f.imposta, 1_456)
            verifica("ETF di Giulia: bollo annuo 0,20%", f.costoBollo, 72.8)
        }
        var giovane = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .previdenza, nome: "Prova")
        giovane.decorrenza = Calendar(identifier: .gregorian).date(byAdding: .year, value: -40, to: Date())
        giovane.controvalore = 10_000
        giovane.totaleVersato = 8_000
        verifica("Previdenza con 40 anni: nessun gradino futuro, aliquota minima", Double(MotoreFiscale.calcola(giovane).gradini.count), 0)

        // 21. Sostituzione: uscita tassata, netto anno per anno, pareggio, trasferimento della previdenza
        let oggiS = Calendar(identifier: .gregorian).startOfDay(for: Date())
        func fondo(_ nome: String, stato: StatoPosizione, rendimento: Double, costo: Double) -> Posizione {
            var p = Posizione(clienteId: "prova", canale: .indipendente, stato: stato, area: .investimento, nome: nome)
            p.tipologia = "Fondo comune"
            p.decorrenza = Calendar(identifier: .gregorian).date(byAdding: .year, value: -3, to: oggiS)
            p.dataValore = oggiS
            p.controvalore = stato == .inEssere ? 12_000 : nil
            p.totaleVersato = stato == .inEssere ? 10_000 : nil
            p.versamentoIniziale = stato == .inEssere ? 10_000 : 0
            p.rendimentoAtteso = rendimento
            p.costoAnnuo = costo
            p.conBollo = false
            p.aliquotaFiscale = 26
            return p
        }
        let uguali = MotoreSostituzione.calcola(attuale: fondo("A", stato: .inEssere, rendimento: 0, costo: 0),
                                                alternativa: fondo("B", stato: .proposta, rendimento: 0, costo: 0), anni: 5)
        verifica("Sostituzione: imposta all'uscita (26% su 2.000 €)", uguali.impostaUscita, 520)
        verifica("Sostituzione: netto reinvestito", uguali.reinvestito, 11_480)
        // Senza rendimento né costi le due strade danno lo stesso netto: 12.000 − 520 restando, 11.480 cambiando
        verifica("Sostituzione: a rendimento zero le due strade si equivalgono", uguali.finale?.differenza ?? 1, 0, tolleranza: 0.01)
        let migliore = MotoreSostituzione.calcola(attuale: fondo("A", stato: .inEssere, rendimento: 3, costo: 2),
                                                  alternativa: fondo("B", stato: .proposta, rendimento: 3, costo: 0.5), anni: 10)
        verifica("Sostituzione: con costi più bassi conviene cambiare", (migliore.finale?.differenza ?? 0) > 0 ? 1 : 0, 1)
        verifica("Sostituzione: pareggio entro il periodo", migliore.pareggio != nil ? 1 : 0, 1)
        verifica("Sostituzione: tre scenari", Double(migliore.scenari.count), 3)
        var pipA = fondo("PIP A", stato: .inEssere, rendimento: 2, costo: 1.5)
        pipA.area = .previdenza
        var pipB = fondo("PIP B", stato: .proposta, rendimento: 2, costo: 0.5)
        pipB.area = .previdenza
        let trasferito = MotoreSostituzione.calcola(attuale: pipA, alternativa: pipB, anni: 10)
        verifica("Sostituzione: trasferimento tra fondi pensione senza imposte", trasferito.impostaUscita, 0)
        verifica("Sostituzione: trasferimento dell'intero valore", trasferito.reinvestito, 12_000)
        if let sofia = demo.first(where: { $0.id == "pos-sofia-polizza-rivalutabile" }),
           let obbl = demo.first(where: { $0.id == "pos-sofia-obbligazionario-a-scadenza-2030" }) {
            let s = MotoreSostituzione.calcola(attuale: sofia, alternativa: obbl)
            // 41.000 − 35.000 = 6.000 di guadagno, aliquota 17,90% (60% in titoli di Stato)
            verifica("Sostituzione di Sofia: imposta all'uscita", s.impostaUscita, 1_074)
            verifica("Sostituzione di Sofia: orizzonte della proposta", Double(s.anni), Double(obbl.anniAllaScadenza ?? 0))
        } else {
            verifica("Posizioni di Sofia per la sostituzione presenti", 0, 1)
        }

        // 22. Previdenza: aliquota IRPEF marginale, piano alla pensione, deducibilità
        verifica("IRPEF: aliquota marginale con 27.000 €", RegoleFiscali.aliquotaMarginale(reddito: 27_000), 23)
        // Dalla revisione dei calcoli: casi verificati a mano
        do {
            // Fondo in essere: 120.000 € oggi, 100.000 versati, 3% per 10 anni, imposta del 26% su tutto il guadagno
            var fondo = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .investimento, nome: "Fondo")
            fondo.tipologia = "Fondo comune"; fondo.controvalore = 120_000; fondo.totaleVersato = 100_000
            fondo.rendimentoAtteso = 3; fondo.conBollo = false
            let ef = MotoreProiezione.calcola(ParametriProiezione(posizione: fondo, orizzonteCliente: 10))
            let lordo: Double = 120_000 * Foundation.pow(1.03, 10.0)
            verifica("Proiezione: il guadagno già maturato si tassa (versato 100.000)", ef.netto, lordo - (lordo - 100_000) * 0.26, tolleranza: 0.05)
            verifica("Proiezione: versato storico", ef.versato, 100_000)
            // Deposito: interessi tassati al 26% man mano
            var conto = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .liquidita, nome: "Conto deposito")
            conto.controvalore = 20_000; conto.rendimentoAtteso = 3
            let ed = MotoreProiezione.calcola(ParametriProiezione(posizione: conto, orizzonteCliente: 5))
            let mese: Double = Foundation.pow(1.03, 1.0 / 12) - 1
            verifica("Proiezione: deposito con interessi tassati all'accredito", ed.netto, 20_000 * Foundation.pow(1 + mese * 0.74, 60.0), tolleranza: 0.05)
            // Obiettivo a 13 mesi: 13 versamenti, non 24
            let tredici = MotoreProiezione.calcola(ParametriProiezione(capitaleIniziale: 0, versamento: 500, frequenza: .mensile, anni: 2,
                                                                     rendimento: 0, aliquotaFiscale: 0, inflazione: 0).perMesi(13))
            verifica("Proiezione in mesi esatti: 13 versamenti da 500 €", tredici.versato, 6_500)
            // Ramo I: il capitale non scende anche se i costi superano il rendimento
            var garantita = ParametriProiezione(capitaleIniziale: 10_000, versamento: 0, frequenza: .unica, anni: 5,
                                                rendimento: 0.5, costoAnnuo: 1.2, aliquotaFiscale: 0, inflazione: 0)
            garantita.capitaleGarantito = true
            verifica("Ramo I: capitale garantito con rendimento sotto i costi", MotoreProiezione.calcola(garantita).lordo, 10_000, tolleranza: 0.01)
            // Bollo: Ramo I esente anche senza parentesi, multiramo solo sulla parte fuori dalla gestione separata
            var ramoI = Posizione(clienteId: "prova", canale: .alleanza, stato: .inEssere, area: .risparmio, nome: "Rivalutabile")
            ramoI.tipologia = "Polizza Ramo I – gestione separata"
            var multi = Posizione(clienteId: "prova", canale: .alleanza, stato: .inEssere, area: .investimento, nome: "Multiramo")
            multi.tipologia = "Polizza multiramo (Ramo I e Ramo III)"; multi.quotaGestioneSeparata = 50
            var unit = Posizione(clienteId: "prova", canale: .alleanza, stato: .inEssere, area: .investimento, nome: "Unit")
            unit.tipologia = "Polizza unit linked (Ramo III)"
            verifica("Bollo: Ramo I esente", ramoI.quotaBollo, 0)
            verifica("Bollo: multiramo 50% in gestione separata", multi.quotaBollo, 0.5)
            verifica("Bollo: Ramo III intero", unit.quotaBollo, 1)
            verifica("Bollo annuo della multiramo su 50.000 €", MotoreFiscale.bolloAnnuo(multi, valore: 50_000), 50)
        }

        verifica("IRPEF: aliquota marginale con 32.000 € (33% dal 2026)", RegoleFiscali.aliquotaMarginale(reddito: 32_000), 33)
        // 30.000 € di reddito, 5.300 dedotti: 2.000 al 33% e 3.300 al 23%
        verifica("IRPEF: risparmio di una deduzione a cavallo di due scaglioni", RegoleFiscali.risparmioDeduzione(reddito: 30_000, deduzione: 5_300),
                 2_000 * 0.33 + 3_300 * 0.23, tolleranza: 0.01)
        verifica("Previdenza: limite di deducibilità 2026", RegoleFiscali.limiteDeducibilita, 5_300)
        // Fondo pensione: 4% lordo, 1,5% di costi, 20% sul risultato netto: (1,04 × 0,985 − 1) × 0,8 = 1,952%
        verifica("Previdenza: rendimento netto dopo costi e imposta del fondo", RegoleFiscali.rendimentoNettoPrevidenza(lordo: 4, costo: 1.5), 1.952, tolleranza: 0.000_1)
        verifica("IRPEF: aliquota marginale con 60.000 €", RegoleFiscali.aliquotaMarginale(reddito: 60_000), 43)
        var fp = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .previdenza, nome: "Fondo")
        fp.decorrenza = Calendar(identifier: .gregorian).date(byAdding: .year, value: -10, to: oggiS)
        fp.controvalore = 10_000
        fp.totaleVersato = 10_000
        fp.rendimentoAtteso = 0
        var ipotesi = IpotesiPrevidenza()
        ipotesi.eta = 57
        ipotesi.etaPensione = 67
        ipotesi.redditoDesiderato = 2_000
        ipotesi.pensionePubblica = 1_500
        ipotesi.anniIntegrazione = 25
        let pp = MotorePrevidenza.calcola([fp], cliente: nil, analisi: ipotesi)
        if let piano = pp.piani.first {
            // 20 anni di partecipazione alla pensione: 15 − 5 × 0,30 = 13,50% su 10.000 € dedotti
            verifica("Previdenza: aliquota alla pensione dopo 20 anni", piano.aliquota, 13.5, tolleranza: 0.0001)
            verifica("Previdenza: imposta sulla prestazione", piano.imposta, 1_350)
            verifica("Previdenza: netto in euro di oggi (inflazione 2% per 10 anni)", piano.nettoReale, 8_650 / pow(1.02, 10), tolleranza: 0.01)
            verifica("Previdenza: rendita mensile per 25 anni", piano.renditaMensile, 8_650 / pow(1.02, 10) / 300, tolleranza: 0.01)
        } else {
            verifica("Previdenza: piano di prova presente", 0, 1)
        }
        verifica("Previdenza: divario mensile", pp.divario, 500)
        var conVersamenti = fp
        conVersamenti.premio = 600
        conVersamenti.frequenza = .mensile
        var cli = DatiDemo.clienti()[0]
        cli.profilo.redditoLordoAnnuo = 40_000
        let ded = MotorePrevidenza.calcola([conVersamenti], cliente: cli, analisi: ipotesi)
        verifica("Previdenza: deducibile fino al limite (7.200 € versati)", ded.deducibiliOggi, 5_300)
        verifica("Previdenza: risparmio IRPEF al 33% (40.000 € di reddito)", ded.risparmioOggi, 5_300 * 0.33, tolleranza: 0.01)

        // 23. Protezione della famiglia: fabbisogno, divario, detrazione dei premi (conti a mano)
        var ip = IpotesiProtezione()
        ip.fabbisognoMensile = 2_000; ip.anniSostegno = 10; ip.debiti = 100_000; ip.speseImmediate = 10_000; ip.capitaleDisponibile = 20_000
        ip.entrateSostitutive = 800; ip.mesiRiserva = 12; ip.riserva = 6_000
        var tcm = Posizione(clienteId: "prova", canale: .alleanza, stato: .inEssere, area: .protezione, nome: "TCM")
        tcm.rischio = .vita; tcm.capitaleAssicurato = 200_000; tcm.premio = 50; tcm.frequenza = .mensile
        var ltc = Posizione(clienteId: "prova", canale: .alleanza, stato: .inEssere, area: .protezione, nome: "LTC")
        ltc.rischio = .ltc; ltc.capitaleAssicurato = 30_000; ltc.premio = 900; ltc.frequenza = .annuale
        let pf = MotoreProtezioneFamiglia.calcola([tcm, ltc], cliente: nil, analisi: ip)
        // 100.000 + 10.000 + 2.000 × 12 × 10 − 20.000 = 330.000
        verifica("Protezione: fabbisogno caso morte", pf.fabbisogno, 330_000)
        verifica("Protezione: divario con 200.000 € assicurati", pf.divario, 130_000)
        verifica("Protezione: anni di sostegno coperti oggi", pf.anniCoperti, (200_000 + 20_000 - 100_000 - 10_000) / 24_000.0)
        verifica("Protezione: riserva da costruire", pf.riservaMancante, 1_200 * 12 - 6_000)
        // Premi 600 (vita) + 900 (LTC): vita fino a 530, totale fino a 1.291,14
        verifica("Protezione: premi detraibili nei limiti", pf.detraibili, 1_291.14)
        verifica("Protezione: detrazione del 19%", pf.detrazione, 1_291.14 * 0.19, tolleranza: 0.001)

        // 24. Piano obiettivo: rivalutazione, accantonato, versamento che colma il mancante
        let fra5 = Calendar(identifier: .gregorian).date(byAdding: .month, value: 60, to: oggiS) ?? oggiS
        var ob = Obiettivo(clienteId: "prova", titolo: "Prova", area: .casa, importo: 10_000, scadenza: fra5)
        ob.accantonato = 5_000
        ob.rendimento = 0
        let eo = MotoreObiettivo.calcola(ob, posizioni: [], data: oggiS)
        verifica("Obiettivo: importo rivalutato al 2% per 5 anni", eo.importoScadenza, 10_000 * pow(1.02, 5), tolleranza: 0.01)
        verifica("Obiettivo: accantonato a rendimento zero", eo.proiezione, 5_000)
        if let v = eo.versamentoNecessario {
            // A rendimento zero (e quindi senza imposte) il versamento è il mancante diviso 60 mesi
            verifica("Obiettivo: versamento mensile a rendimento zero", v, (10_000 * pow(1.02, 5) - 5_000) / 60, tolleranza: 0.05)
        } else {
            verifica("Obiettivo: versamento calcolato", 0, 1)
        }
        verifica("Obiettivo: versamento unico a rendimento zero", eo.unaTantum ?? 0, ((10_000 * pow(1.02, 5) - 5_000) / 10).rounded(.up) * 10, tolleranza: 10)
        verifica("Obiettivo: quattro strade", Double(eo.strade.count), 4)

        // 25. Liquidità: capitale in scadenza netto, riserva, salvadanai
        if let polizza = demo.first(where: { $0.id == "pos-sofia-polizza-rivalutabile" }),
           let conto = demo.first(where: { $0.id == "pos-sofia-liquidità" }) {
            var ipl = IpotesiProtezione()
            ipl.fabbisognoMensile = 2_000
            ipl.mesiRiserva = 6
            let el = MotoreLiquidita.calcola([polizza, conto], obiettivi: [], analisi: ipl)
            // 41.000 − 17,90% di 6.000 = 39.926
            verifica("Liquidità: netto della polizza in scadenza", el.nettoInScadenza, 39_926)
            verifica("Liquidità: totale disponibile (27.000 di conto)", el.totale, 66_926)
            verifica("Liquidità: riserva di 6 mesi", el.salvadanai.first?.importo ?? 0, 12_000)
            verifica("Liquidità: il resto va alla crescita senza obiettivi", el.salvadanai.last?.importo ?? 0, 54_926)
        } else {
            verifica("Posizioni di Sofia per la liquidità presenti", 0, 1)
        }

        // 26. Check-up: semafori di Andrea (primo incontro, solo liquidità)
        let clientiDemo = DatiDemo.clienti()
        if let andrea = clientiDemo.first(where: { $0.id == "andrea" }) {
            let sue = demo.filter { $0.clienteId == "andrea" }
            var an = Analisi360(cliente: andrea, posizioni: sue)
            an.protezione.fabbisognoMensile = 2_000
            an.protezione.mesiRiserva = 6
            let ck = MotoreCheckUp.calcola(cliente: andrea, posizioni: sue, analisi: an, obiettivi: [])
            let riserva = ck.indicatori.first { $0.id == "riserva" }
            // 12.000 € di liquidità = 6 mesi da 2.000 €: riserva piena
            verifica("Check-up: riserva piena con 6 mesi su 6", riserva?.semaforo == .verde ? 1 : 0, 1)
            verifica("Check-up: obiettivi da definire (grigio)", ck.indicatori.first { $0.id == "obiettivi" }?.semaforo == .grigio ? 1 : 0, 1)
            verifica("Check-up: sette indicatori", Double(ck.indicatori.count), 7)
        }

        // Lettura dei documenti: numeri e date in ogni formato, solo date vere
        verifica("Documenti: «1.250,50» è 1250,50", EstrattoreDocumento.numero("1.250,50") ?? -1, 1250.5)
        verifica("Documenti: «1,250.50» (all'inglese) è 1250,50", EstrattoreDocumento.numero("1,250.50") ?? -1, 1250.5)
        verifica("Documenti: «1200.50» resta 1200,50", EstrattoreDocumento.numero("1200.50") ?? -1, 1200.5)
        let gregoriano = Calendar(identifier: .gregorian)
        verifica("Documenti: «2025-12-01» è il primo dicembre", EstrattoreDocumento.data("2025-12-01").map { Double(gregoriano.component(.month, from: $0) * 100 + gregoriano.component(.day, from: $0)) } ?? -1, 1201)
        verifica("Documenti: «31/06/2026» non è una data", EstrattoreDocumento.data("31/06/2026") == nil ? 1 : 0, 1)
        verifica("Documenti: «1° dicembre 2025»", EstrattoreDocumento.data("1° dicembre 2025").map { Double(gregoriano.component(.year, from: $0)) } ?? -1, 2025)
        var unito = EstrattoreDocumento.unisci([CampoEstratto(chiave: .premio, valore: "1.000", pagina: 1, confermato: true)],
                                               [CampoEstratto(chiave: .premio, valore: "999", pagina: 2), CampoEstratto(chiave: .sri, valore: "3", pagina: 1)])
        verifica("Documenti: il modello completa senza toccare i dati confermati",
                 unito.first { $0.chiave == .premio }?.valore == "1.000" && unito.first { $0.chiave == .premio }?.confermato == true && unito.count == 2 ? 1 : 0, 1)
        if let i = unito.firstIndex(where: { $0.chiave == .premio }) { unito[i].valore = "  " }
        var docVuoto = Documento(clienteId: "giulia", titolo: "Prova", tipo: .kid)
        docVuoto.campi = unito
        verifica("Documenti: un campo svuotato non vale come confermato", docVuoto.confermato(.premio) == nil ? 1 : 0, 1)
        // Testi in memoria con un tetto: si dimenticano i meno recenti, il più recente resta
        var memoria = MemoriaTesti()
        memoria.limite = 10
        memoria["a"] = ["1234"]
        memoria["b"] = ["1234"]
        memoria["a"] = ["1234"]
        memoria["c"] = ["1234"]
        verifica("Documenti: in memoria restano i testi più recenti", memoria["b"] == nil && memoria["a"] != nil && memoria["c"] != nil ? 1 : 0, 1)
        verifica("Documenti: i caratteri in memoria restano sotto il tetto", Double(memoria.caratteri), 8)
        memoria["d"] = [String(repeating: "x", count: 50)]
        verifica("Documenti: un testo più grande del tetto resta da solo", memoria.conta == 1 && memoria["d"] != nil ? 1 : 0, 1)
        memoria["d"] = nil
        verifica("Documenti: memoria vuota dopo aver tolto l'ultimo", Double(memoria.caratteri + memoria.conta), 0)

        // Estratti conto: valore, data del valore e versato, poi nello storico della posizione
        let estratto = EstrattoreDocumento.conRegole(DatiDemo.testoDocumento("doc-giulia-estratto") ?? [])
        func letto(_ k: CampoDocumento, in campi: [CampoEstratto]) -> String { campi.first { $0.chiave == k }?.valore ?? "" }
        verifica("Estratto: controvalore 4.712,40", EstrattoreDocumento.numero(letto(.controvalore, in: estratto)) ?? 0, 4_712.40)
        verifica("Estratto: totale versato 4.500", EstrattoreDocumento.numero(letto(.totaleVersato, in: estratto)) ?? 0, 4_500)
        verifica("Estratto: data del valore diciotto mesi fa",
                 EstrattoreDocumento.data(letto(.dataValore, in: estratto)).map { Double(Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0) } ?? 0, 548, tolleranza: 1)
        verifica("Estratto: numero di polizza", letto(.numeroContratto, in: estratto) == "AL-2022-104851" ? 1 : 0, 1)
        let varianti = EstrattoreDocumento.conRegole(["Rendiconto annuale\nData di riferimento: 31/12/2025\nControvalore complessivo 12.345,67\nTotale dei versamenti effettuati: euro 10.000,00"])
        verifica("Estratto: «Data di riferimento»", letto(.dataValore, in: varianti) == "31/12/2025" ? 1 : 0, 1)
        verifica("Estratto: «Totale dei versamenti effettuati: euro»", EstrattoreDocumento.numero(letto(.totaleVersato, in: varianti)) ?? 0, 10_000)
        verifica("Estratto: «Controvalore complessivo» senza simbolo", EstrattoreDocumento.numero(letto(.controvalore, in: varianti)) ?? 0, 12_345.67)
        let nonVersato = EstrattoreDocumento.conRegole(["Premi versati nel 2025: 12 rate"])
        verifica("Estratto: «12 rate» non è un versato", letto(.totaleVersato, in: nonVersato).isEmpty ? 1 : 0, 1)
        // Calendario fiscale: spazio deducibile, risparmio IRPEF, detrazione dei premi, eccedenza da comunicare
        var contribuente = Cliente(id: "fisco", nome: "Prova Fisco", iniziali: "PF", tinta: DatiDemo.clienti()[0].tinta, tema: "", email: "", telefono: "",
                                   preferito: false, nota: "", creatoIl: Date())
        contribuente.profilo.redditoLordoAnnuo = 40_000
        var pip = Posizione(clienteId: "fisco", canale: .alleanza, stato: .inEssere, area: .previdenza, nome: "PIP")
        pip.premio = 200
        pip.frequenza = .mensile
        var tcmFisco = Posizione(clienteId: "fisco", canale: .alleanza, stato: .inEssere, area: .protezione, nome: "TCM")
        tcmFisco.premio = 50
        tcmFisco.frequenza = .mensile
        tcmFisco.rischio = .vita
        let annoFisco = Calendar.current.component(.year, from: Date())
        let primoDicembre = Calendar.current.date(from: DateComponents(year: annoFisco, month: 12, day: 1, hour: 10)) ?? Date()
        let fa = MotoreFineAnno.calcola(cliente: contribuente, posizioni: [pip, tcmFisco], oggi: primoDicembre)
        verifica("Fine anno: contributi 2.400 €, spazio deducibile 2.900 €", fa.spazio, RegoleFiscali.limiteDeducibilita - 2_400)
        verifica("Fine anno: risparmio IRPEF usando tutto lo spazio (al 33%)", fa.risparmioPossibile, (RegoleFiscali.limiteDeducibilita - 2_400) * 0.33, tolleranza: 0.01)
        verifica("Fine anno: premi detraibili fino a 530 €", fa.detraibili, 530)
        verifica("Fine anno: detrazione del 19%", fa.detrazione, 530 * 0.19, tolleranza: 0.001)
        verifica("Fine anno: il 1° dicembre la deduzione è vicina",
                 (fa.scadenze.first(where: { $0.tipo == ScadenzaFiscale.Tipo.deduzione }).map { MotoreFineAnno.vicina($0, oggi: primoDicembre) } ?? false) ? 1 : 0, 1)
        verifica("Fine anno: tra i clienti con spazio deducibile",
                 MotoreFineAnno.conSpazio(clienti: [contribuente], posizioni: [pip, tcmFisco], oggi: primoDicembre).count == 1 ? 1 : 0, 1)
        pip.premio = 500
        let oltre = MotoreFineAnno.calcola(cliente: contribuente, posizioni: [pip], oggi: primoDicembre)
        verifica("Fine anno: oltre il limite niente spazio, eccedenza da comunicare",
                 oltre.spazio == 0 && oltre.eccedenza == 6_000 - RegoleFiscali.limiteDeducibilita && oltre.scadenze.contains { $0.tipo == ScadenzaFiscale.Tipo.nonDedotti }
                    && !oltre.scadenze.contains { $0.tipo == ScadenzaFiscale.Tipo.deduzione } ? 1 : 0, 1)

        // Revisione: versato di un periodo, saldo iniziale e finale, proiezioni future
        let giorni: (Int) -> String = { Formati.dataBreve.string(from: Calendar.current.date(byAdding: .day, value: $0, to: Date()) ?? Date()) }
        let periodo = EstrattoreDocumento.conRegole(["Premi versati nel periodo: € 1.200,00\nTotale premi versati: € 14.500,00\nContributi versati nell'anno € 2.400,00"])
        verifica("Estratto: il versato totale, non quello del periodo", EstrattoreDocumento.numero(letto(.totaleVersato, in: periodo)) ?? 0, 14_500)
        let saldi = EstrattoreDocumento.conRegole(["Rendiconto al \(giorni(-200))\nSaldo al \(giorni(-120)): € 10.000,00\nSaldo al \(giorni(-30)): € 10.400,00\nValore di riscatto al \(giorni(400)): € 11.000,00"])
        verifica("Estratto: la data più recente non futura", letto(.dataValore, in: saldi) == giorni(-30) ? 1 : 0, 1)
        var futuro = Documento(clienteId: "giulia", titolo: "Polizza", tipo: .polizza)
        futuro.campi = [CampoEstratto(chiave: .controvalore, valore: "11.000,00", pagina: 1, confermato: true),
                        CampoEstratto(chiave: .dataValore, valore: giorni(400), pagina: 1, confermato: true)]
        verifica("Estratto: un valore futuro è una proiezione, non si registra", ValoriDaDocumento.valore(futuro) == nil ? 1 : 0, 1)
        // Due posizioni con lo stesso nome: nessuna scelta a caso; numero diverso: esclusa
        var gemella1 = Posizione(clienteId: "c", canale: .alleanza, stato: .inEssere, area: .risparmio, nome: "Piano")
        gemella1.id = "g1"
        var gemella2 = gemella1
        gemella2.id = "g2"
        var docNome = Documento(clienteId: "c", titolo: "Estratto conto Piano", tipo: .estrattoConto)
        verifica("Estratto: due posizioni con lo stesso nome, nessuna riconosciuta", ValoriDaDocumento.posizioneProbabile(docNome, tra: [gemella1, gemella2]) == nil ? 1 : 0, 1)
        gemella1.numeroContratto = "111"
        docNome.campi = [CampoEstratto(chiave: .numeroContratto, valore: "222", pagina: 1)]
        verifica("Estratto: il nome non vince su un numero di contratto diverso", ValoriDaDocumento.posizioneProbabile(docNome, tra: [gemella1, gemella2])?.id == "g2" ? 1 : 0, 1)
        var spirito = gemella1
        spirito.nome = "PIR"
        verifica("Estratto: il nome si cerca a parole intere («PIR» non è in «spirito»)",
                 ValoriDaDocumento.posizioneProbabile(Documento(clienteId: "c", titolo: "Lo spirito del risparmio", tipo: .estrattoConto), tra: [spirito]) == nil ? 1 : 0, 1)
        // Dal documento alla posizione
        var docEstratto = Documento(clienteId: "giulia", titolo: "Estratto conto", tipo: .estrattoConto)
        docEstratto.campi = estratto.map { var c = $0; c.confermato = true; return c }
        let posizioniGiulia = DatiDemo.posizioni()
        let riconosciuta = ValoriDaDocumento.posizioneProbabile(docEstratto, tra: posizioniGiulia)
        verifica("Estratto: posizione riconosciuta dal numero di polizza", riconosciuta?.id == "pos-giulia-piano-di-risparmio-rivalutabile" ? 1 : 0, 1)
        if var piano = riconosciuta, let v = ValoriDaDocumento.valore(docEstratto) {
            let prima = piano.storicoValori.count
            let attuale = piano.controvalore
            verifica("Estratto: un valore più vecchio va tra i valori passati", ValoriDaDocumento.applica(v, a: &piano) == .passato ? 1 : 0, 1)
            verifica("Estratto: lo storico ha un valore in più", Double(piano.storicoValori.count), Double(prima + 1))
            verifica("Estratto: il valore attuale non cambia", piano.controvalore ?? 0, attuale ?? -1)
            verifica("Estratto: ora risulta registrato", ValoriDaDocumento.registrato(v, in: piano) ? 1 : 0, 1)
            ValoriDaDocumento.applica(v, a: &piano)
            verifica("Estratto: registrarlo di nuovo non lo duplica", Double(piano.storicoValori.count), Double(prima + 1))
            // Un estratto senza versato: al versato di prima si aggiungono i premi del periodo
            var senzaVersato = piano
            let dopo = ValoriDaDocumento.mezzogiorno(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            let premiAttesi = (piano.totaleVersato ?? 0) + piano.premioAnnuo * dopo.timeIntervalSince(piano.dataValore ?? dopo) / MotoreAndamento.anno
            ValoriDaDocumento.applica(ValoriDaDocumento.Valore(data: dopo, valore: 7_900, versato: nil), a: &senzaVersato)
            verifica("Estratto: senza versato si aggiungono i premi del periodo", senzaVersato.totaleVersato ?? 0, premiAttesi, tolleranza: 1)
            let recente = ValoriDaDocumento.Valore(data: ValoriDaDocumento.mezzogiorno(Date()), valore: 7_800, versato: 7_350)
            verifica("Estratto: un valore più recente diventa quello attuale", ValoriDaDocumento.applica(recente, a: &piano) == .attuale ? 1 : 0, 1)
            verifica("Estratto: valore e versato aggiornati", (piano.controvalore ?? 0) + (piano.totaleVersato ?? 0), 15_150)
            verifica("Estratto: il valore di prima resta nello storico", piano.storicoValori.contains { abs($0.controvalore - (attuale ?? 0)) < 0.5 } ? 1 : 0, 1)
        } else {
            verifica("Estratto: valore confermato e posizione", 0, 1)
        }

        // Portafoglio del consulente: le somme per cliente ed emittente tornano con il totale
        do {
            let demo = DatiPrisma.demo()
            let pf = MotorePortafoglio.calcola(demo.posizioni, clienti: demo.clienti)
            verifica("Portafoglio: attività per cliente uguali al totale", pf.clienti.reduce(0) { $0 + $1.attivita }, pf.riepilogo.attivita)
            verifica("Portafoglio: quote dei clienti al 100%", pf.clienti.reduce(0) { $0 + $1.quota }, 1)
            verifica("Portafoglio: emittenti uguali alle attività finanziarie", pf.emittenti.reduce(0) { $0 + $1.valore }, pf.attivitaFinanziarie)
            verifica("Portafoglio: quote degli emittenti al 100%", pf.emittenti.reduce(0) { $0 + $1.quota }, 1)
            verifica("Portafoglio: immobili fuori dalla concentrazione",
                     pf.attivitaFinanziarie, pf.riepilogo.attivita - (pf.riepilogo.perArea[.immobili] ?? 0))
            verifica("Portafoglio: clienti dal più seguito", zip(pf.clienti, pf.clienti.dropFirst()).allSatisfy { $0.attivita >= $1.attivita } ? 1 : 0, 1)
            verifica("Portafoglio: al massimo \(Portafoglio.massimoEmittenti) emittenti", pf.emittenti.count <= Portafoglio.massimoEmittenti ? 1 : 0, 1)
            let fine = Calendar.current.date(byAdding: .month, value: 13, to: Date()) ?? Date()
            verifica("Portafoglio: scadenze nei prossimi 12 mesi, in ordine",
                     pf.scadenze.allSatisfy { m in m.posizioni.allSatisfy { ($0.scadenza ?? .distantFuture) < fine } }
                     && zip(pf.scadenze, pf.scadenze.dropFirst()).allSatisfy { $0.inizio < $1.inizio } ? 1 : 0, 1)
            var esiti = demo.posizioni
            let base = Posizione(clienteId: "giulia", canale: .alleanza, stato: .proposta, area: .risparmio, nome: "Prova")
            for (k, e) in [EsitoProposta.accettata, .accettata, .accettata, .rifiutata].enumerated() {
                var x = base
                x.id = "prova-esito-\(k)"
                x.esito = e
                esiti.append(x)
            }
            let conEsiti = MotorePortafoglio.calcola(esiti, clienti: demo.clienti)
            let gia = MotorePortafoglio.calcola(demo.posizioni, clienti: demo.clienti).esiti
            let si = Double((gia[.accettata] ?? 0) + 3), no = Double((gia[.rifiutata] ?? 0) + 1)
            // Da ricontattare: un cliente senza contatti da un anno, con una posizione che scade, viene per primo
            var conContatti = demo
            conContatti.appuntamenti.removeAll { $0.clienteId == "laura" }
            conContatti.incontri.removeAll { $0.clienteId == "laura" }
            var vecchio = Appuntamento(id: "prova-vecchio", clienteId: "laura", titolo: "Vecchio incontro", inizio: Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date(),
                                       durataMinuti: 60, luogo: "", note: "", stato: .concluso)
            vecchio.tipo = .altro
            conContatti.appuntamenti.append(vecchio)
            if let i = conContatti.posizioni.firstIndex(where: { $0.clienteId == "laura" && $0.stato == .inEssere }) {
                conContatti.posizioni[i].scadenza = Calendar.current.date(byAdding: .day, value: 40, to: Date())
            }
            let ric = MotorePortafoglio.calcola(conContatti.posizioni, clienti: conContatti.clienti, appuntamenti: conContatti.appuntamenti, incontri: conContatti.incontri)
            verifica("Portafoglio: Laura da ricontattare, per prima (scadenza in arrivo)", ric.daRicontattare.first?.cliente.id == "laura" && ric.daRicontattare.first?.motivo != nil ? 1 : 0, 1)
            verifica("Portafoglio: chi ha un appuntamento in agenda non è da ricontattare",
                     ric.daRicontattare.contains { r in conContatti.appuntamenti.contains { $0.clienteId == r.cliente.id && $0.stato == .pianificato && $0.inizio >= Calendar.current.startOfDay(for: Date()) } } ? 0 : 1, 1)
            // Riesami annuali: un anno dall'ultimo incontro e niente in agenda
            let oggiRiesami = Calendar.current.startOfDay(for: Date())
            let dovuti = MotoreRiesame.dovuti(clienti: conContatti.clienti, posizioni: conContatti.posizioni,
                                              appuntamenti: conContatti.appuntamenti, incontri: conContatti.incontri)
            verifica("Riesami: Laura, vista un anno fa, ha il riesame scaduto", dovuti.first { $0.id == "laura" }?.scaduto() == true ? 1 : 0, 1)
            verifica("Riesami: chi ha un incontro in agenda non è nel calendario",
                     dovuti.contains { d in conContatti.appuntamenti.contains { $0.clienteId == d.id && $0.stato == .pianificato && $0.inizio >= oggiRiesami } } ? 0 : 1, 1)
            verifica("Riesami: tra chi è da ricontattare, Laura ha il riesame scaduto", ric.daRicontattare.first { $0.id == "laura" }?.riesameScaduto == true ? 1 : 0, 1)
            for (mesi, atteso, descrizione) in [(-3, false, "vista tre mesi fa non è nel calendario"), (-11, true, "vista undici mesi fa è nel calendario, non ancora scaduto")] {
                var spostati = conContatti
                if let i = spostati.appuntamenti.firstIndex(where: { $0.id == "prova-vecchio" }) {
                    spostati.appuntamenti[i].inizio = Calendar.current.date(byAdding: .month, value: mesi, to: Date()) ?? Date()
                }
                let elenco = MotoreRiesame.dovuti(clienti: spostati.clienti, posizioni: spostati.posizioni, appuntamenti: spostati.appuntamenti, incontri: spostati.incontri)
                let laura = elenco.first { $0.id == "laura" }
                verifica("Riesami: Laura \(descrizione)", (laura != nil) == atteso && (laura?.scaduto() ?? false) == false ? 1 : 0, 1)
            }
            var attivata = base
            attivata.id = "prova-attivata"
            attivata.stato = .inEssere
            attivata.esito = .accettata
            let conAttivata = MotorePortafoglio.calcola(demo.posizioni + [attivata], clienti: demo.clienti)
            verifica("Portafoglio: una proposta attivata conta come accettata",
                     Double(conAttivata.esiti[.accettata] ?? 0), Double((gia[.accettata] ?? 0) + 1))
            var chiusa = Posizione(clienteId: "ex", canale: .alleanza, stato: .chiusa, area: .risparmio, nome: "Vecchia")
            chiusa.id = "prova-chiusa"
            let ex = Cliente(id: "ex", nome: "Ex Cliente", iniziali: "EC", tinta: demo.clienti[0].tinta, tema: "", email: "", telefono: "",
                             preferito: false, nota: "", creatoIl: Date())
            let conEx = MotorePortafoglio.calcola(demo.posizioni + [chiusa], clienti: demo.clienti + [ex], appuntamenti: demo.appuntamenti, incontri: demo.incontri)
            verifica("Portafoglio: chi ha solo posizioni chiuse non è un cliente seguito né da ricontattare",
                     conEx.clienti.contains { $0.id == "ex" } || conEx.daRicontattare.contains { $0.id == "ex" } ? 0 : 1, 1)
            let finePf = MotorePortafoglio.finestra(Date())
            verifica("Portafoglio: la finestra delle scadenze è di 12 mesi da oggi",
                     Double(Calendar.current.dateComponents([.month], from: Calendar.current.startOfDay(for: Date()), to: finePf).month ?? 0), 12)
            verifica("Portafoglio: tasso di accettazione delle proposte", conEsiti.tassoAccettazione ?? -1, si / (si + no), tolleranza: 0.0001)
        }

        // Prova di resistenza: mercati per SRI, capitale garantito, inflazione e immobili
        do {
            func pos(_ nome: String, _ area: AreaPosizione, _ valore: Double, _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
                var p = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: area, nome: nome)
                p.controvalore = valore
                modifica(&p)
                return p
            }
            let fondo = pos("Fondo azionario", .investimento, 100_000) { $0.tipologia = "Fondo comune"; $0.sri = 4; $0.rendimentoAtteso = 6; $0.costoAnnuo = 1 }
            let ramoI = pos("Rivalutabile", .risparmio, 50_000) { $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.rendimentoAtteso = 2.5; $0.costoAnnuo = 1.2 }
            let multi = pos("Multiramo", .investimento, 100_000) { $0.tipologia = "Polizza multiramo"; $0.sri = 3; $0.quotaGestioneSeparata = 40; $0.rendimentoAtteso = 5 }
            let conto = pos("Conto", .liquidita, 20_000)
            let casa = pos("Casa", .immobili, 300_000)
            var mutuo = pos("Mutuo", .debiti, 100_000)
            mutuo.canale = .alleanza
            var proposta = pos("Proposta", .investimento, 80_000) { $0.sri = 6 }
            proposta.stato = .proposta
            let tutte = [fondo, ramoI, multi, conto, casa, mutuo, proposta]
            var profilo = ProfiloInvestitore()
            profilo.propensione = .moderata
            let r = MotoreResistenza.calcola(tutte, profilo: profilo)
            let m = r.scenario(.mercati)
            verifica("Resistenza: patrimonio finanziario senza immobili, debiti e proposte", r.patrimonioFinanziario, 270_000)
            verifica("Resistenza: mercati, SRI 4 perde il 20% e la multiramo solo fuori dalla gestione separata", m?.perdita ?? -1, 20_000 + 100_000 * 0.6 * 0.10)
            verifica("Resistenza: la gestione separata e il conto non perdono sui mercati",
                     m?.voci.contains { $0.posizione.id == ramoI.id || $0.posizione.id == conto.id } == true ? 1 : 0, 0)
            verifica("Resistenza: quota garantita o senza rischio di mercato", r.quotaProtetta, (50_000 + 40_000 + 20_000) / 270_000.0, tolleranza: 0.0001)
            let reale: (Double) -> Double = { netto in 1 - pow((1 + netto / 100) / 1.05, 3) }
            let inflazione = r.scenario(.inflazione)
            verifica("Resistenza: inflazione, il conto perde potere d'acquisto", inflazione?.voci.first { $0.posizione.id == conto.id }?.perdita ?? -1, 20_000 * reale(0), tolleranza: 1)
            verifica("Resistenza: inflazione, la rivalutabile al netto dei costi", inflazione?.voci.first { $0.posizione.id == ramoI.id }?.perdita ?? -1, 50_000 * reale(1.3), tolleranza: 1)
            verifica("Resistenza: inflazione, chi rende più dei prezzi non perde",
                     inflazione?.voci.contains { $0.posizione.id == fondo.id || $0.posizione.id == multi.id } == true ? 1 : 0, 0)
            verifica("Resistenza: immobili −15%", r.scenario(.immobili)?.perdita ?? -1, 45_000)
            verifica("Resistenza: immobili sul patrimonio netto", r.scenario(.immobili)?.base ?? -1, 270_000 + 300_000 - 100_000)
            verifica("Resistenza: profilo moderato, perdita del 9,6% dentro il 10%", r.giudizio == .dentro ? 1 : 0, 1)
            profilo.propensione = .prudente
            verifica("Resistenza: profilo prudente, oltre il 5% (e oltre il margine)", MotoreResistenza.calcola(tutte, profilo: profilo).giudizio == .oltre ? 1 : 0, 1)
            profilo.propensione = .moderata
            let alLimite = MotoreResistenza.calcola([pos("Bilanciato", .investimento, 100_000) { $0.sri = 3 }, pos("Azionario", .investimento, 10_000) { $0.sri = 4 }], profilo: profilo)
            verifica("Resistenza: perdita dell'11%, al limite del 10% moderato", alLimite.giudizio == .alLimite ? 1 : 0, 1)
            verifica("Resistenza: senza propensione nessun giudizio", MotoreResistenza.calcola(tutte, profilo: ProfiloInvestitore()).giudizio == nil ? 1 : 0, 1)
            let senzaSRI = MotoreResistenza.calcola([pos("Fondo pensione", .previdenza, 10_000)], profilo: nil)
            verifica("Resistenza: senza SRI si stima dall'area (previdenza 3 su 7)", senzaSRI.scenario(.mercati)?.perdita ?? -1, 1_000)
            verifica("Resistenza: nessuna posizione, prova vuota", MotoreResistenza.calcola([proposta], profilo: nil).vuota ? 1 : 0, 1)
            let demo = DatiPrisma.demo()
            for c in demo.clienti {
                let rc = MotoreResistenza.calcola(demo.posizioni.filter { $0.clienteId == c.id }, profilo: c.profilo)
                verifica("Resistenza: \(c.nome), perdite mai oltre il valore", rc.scenari.allSatisfy { s in s.voci.allSatisfy { $0.perdita >= 0 && $0.perdita <= $0.posizione.valore } } ? 1 : 0, 1)
            }
        }

        // Peso dei costi: quanto tolgono nel tempo e l'alternativa a parità di rischio
        do {
            func pos(_ nome: String, _ area: AreaPosizione, _ valore: Double, _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
                var p = Posizione(clienteId: "prova", canale: .alleanza, stato: .inEssere, area: area, nome: nome)
                p.controvalore = valore
                p.totaleVersato = valore
                modifica(&p)
                return p
            }
            let fondo = pos("Fondo caro", .investimento, 100_000) { $0.tipologia = "Fondo comune"; $0.sri = 4; $0.rendimentoAtteso = 5; $0.costoAnnuo = 2; $0.aliquotaFiscale = 26 }
            let b = RegoleFiscali.bollo * fondo.quotaBollo
            let netto: (Double, Int) -> Double = { c, anni in
                let f = 100_000 * pow(1.05 * (1 - (c + b) / 100), Double(anni))
                return f - max(0, f - 100_000) * 0.26
            }
            let scade = pos("Polizza a 5 anni", .risparmio, 50_000) {
                $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.costoAnnuo = 1.2; $0.costoIngresso = 3; $0.premio = 1_000; $0.frequenza = .annuale
                $0.scadenza = Calendar.current.date(byAdding: .year, value: 5, to: Date())
            }
            let senza = pos("Senza KID", .investimento, 20_000)
            let catalogo = DatiDemo.prodotti()
            let a = MotoreCosti.calcola([fondo, scade, senza], prodotti: catalogo, cliente: "prova")
            let vf = a.voci.first { $0.posizione.id == fondo.id }
            verifica("Costi: quest'anno il 2% del valore", vf?.euroAnno ?? -1, 2_000)
            verifica("Costi: in 10 anni tolgono il netto senza costi meno quello con", vf?.perso10 ?? -1, netto(0, 10) - netto(2, 10), tolleranza: 1)
            verifica("Costi: in 20 anni di più che in 10", (vf?.perso20 ?? 0) > (vf?.perso10 ?? 0) ? 1 : 0, 1)
            let vs = a.voci.first { $0.posizione.id == scade.id }
            verifica("Costi: con la scadenza a 5 anni il calcolo si ferma lì", Double(vs?.anni20 ?? -1), 5)
            verifica("Costi: ingresso sui versamenti dell'anno", vs?.euroAnno ?? -1, 50_000 * 0.012 + 1_000 * 0.03)
            verifica("Costi: le posizioni senza costi indicati a parte", a.senzaDati.map(\.id) == [senza.id] ? 1 : 0, 1)
            verifica("Costi: alternativa a parità di rischio (ETF, SRI 4, 0,2%)", vf?.alternativa?.prodotto.id == "prodotto-etf-globale" ? 1 : 0, 1)
            verifica("Costi: l'alternativa lascia di più, uscita compresa", (vf?.alternativa?.guadagno ?? 0) >= MotoreCosti.guadagnoMinimo ? 1 : 0, 1)
            verifica("Costi: la gestione separata non si confronta con un fondo", vs?.alternativa == nil ? 1 : 0, 1)
            var diverso = fondo
            diverso.sri = 5
            verifica("Costi: con un altro SRI nessuna alternativa", MotoreCosti.alternativa(diverso, prodotti: catalogo, cliente: "prova") == nil ? 1 : 0, 1)
            verifica("Costi: costo medio pesato sul valore", a.costoMedio ?? -1, (2 * 100_000 + 1.2 * 50_000) / 150_000.0, tolleranza: 0.0001)
        }

        // Passaggio generazionale: quote degli eredi, beneficiari fuori dall'asse, imposte e avvisi
        do {
            let demo = DatiDemo.clienti()
            let posizioni = DatiDemo.posizioni()
            if let marco = demo.first(where: { $0.id == "marco" }) {
                let s = MotoreSuccessione.calcola(cliente: marco, posizioni: posizioni)
                verifica("Successione: Marco, coniuge e due figli, al coniuge un terzo", s.eredi.first { $0.relazione == .coniuge }?.quota ?? -1, 1.0 / 3, tolleranza: 0.0001)
                verifica("Successione: ai figli due terzi in parti uguali", s.eredi.filter { $0.relazione != .coniuge }.map(\.quota).reduce(0, +), 2.0 / 3, tolleranza: 0.0001)
                verifica("Successione: i figli minorenni segnalati", s.avvisi.contains { $0.contains("minorenni") } ? 1 : 0, 1)
                let tcm = s.voci.first { $0.posizione.rischio == .vita }
                verifica("Successione: la TCM porta il capitale ai beneficiari", tcm?.destino == .beneficiari && tcm?.importo == tcm?.posizione.capitaleAssicurato ? 1 : 0, 1)
                verifica("Successione: polizze e previdenza fuori dall'asse", s.voci.filter { $0.posizione.regime == .polizza || $0.posizione.area == .previdenza }.allSatisfy { $0.destino == .beneficiari } ? 1 : 0, 1)
                verifica("Successione: asse netto = attività meno debiti", s.asseNetto, max(0, s.attivoAsse - s.debiti))
                verifica("Successione: sotto il milione nessuna imposta per coniuge e figli", s.impostaSuccessione, 0)
            }
            if let giulia = demo.first(where: { $0.id == "giulia" }) {
                let s = MotoreSuccessione.calcola(cliente: giulia, posizioni: posizioni)
                verifica("Successione: Giulia, il convivente non eredita", s.conviventeEscluso == "Luca Ferri" && s.eredi.isEmpty ? 1 : 0, 1)
                verifica("Successione: «Eredi legittimi» escluderebbe il convivente", s.daSistemare.contains { $0.avviso?.contains("Luca Ferri") == true } ? 1 : 0, 1)
            }
            var ricco = Cliente(id: "r", nome: "Prova", iniziali: "P", tinta: demo[0].tinta, tema: "", email: "", telefono: "", preferito: false, nota: "", creatoIl: Date())
            ricco.statoCivile = .celibeNubile
            ricco.famiglia = [Familiare(nome: "Fratello", relazione: .fratelloSorella)]
            var conto = Posizione(clienteId: "r", canale: .indipendente, stato: .inEssere, area: .liquidita, nome: "Conto")
            conto.controvalore = 300_000
            var casa = Posizione(clienteId: "r", canale: .indipendente, stato: .inEssere, area: .immobili, nome: "Seconda casa")
            casa.controvalore = 100_000
            let sr = MotoreSuccessione.calcola(cliente: ricco, posizioni: [conto, casa])
            verifica("Successione: al fratello il 6% oltre 100.000", sr.impostaSuccessione, (400_000 - 100_000) * 0.06)
            verifica("Successione: ipotecaria e catastale 3% sulla seconda casa", sr.ipocatastali, 3_000)
            verifica("Successione: frazioni leggibili", MotoreSuccessione.frazione(2.0 / 3) == "due terzi" ? 1 : 0, 1)
            // Coniuge senza figli con un genitore e tre fratelli: al genitore almeno un quarto (art. 582 c.c.)
            var sposato = ricco
            sposato.statoCivile = .coniugato
            sposato.famiglia = [Familiare(nome: "Moglie", relazione: .coniuge), Familiare(nome: "Padre", relazione: .genitore),
                                Familiare(nome: "F1", relazione: .fratelloSorella), Familiare(nome: "F2", relazione: .fratelloSorella),
                                Familiare(nome: "F3", relazione: .fratelloSorella)]
            let quote = MotoreSuccessione.legittimi(sposato)
            verifica("Successione: al genitore un quarto", quote.first { $0.relazione == .genitore }?.quota ?? -1, 0.25, tolleranza: 0.0001)
            verifica("Successione: le quote fanno l'intero", quote.map(\.quota).reduce(0, +), 1, tolleranza: 0.0001)
            // Stato civile non indicato: il coniuge registrato eredita
            var senzaStato = sposato
            senzaStato.statoCivile = nil
            senzaStato.famiglia = [Familiare(nome: "Moglie", relazione: .coniuge), Familiare(nome: "A", relazione: .figlio), Familiare(nome: "B", relazione: .figlia)]
            verifica("Successione: stato civile mancante, al coniuge un terzo", MotoreSuccessione.legittimi(senzaStato).first { $0.relazione == .coniuge }?.quota ?? -1, 1.0 / 3, tolleranza: 0.0001)
            // Capitalizzazione nell'asse; TCM scaduta non conta; una sola prima casa
            var capitalizzazione = Posizione(clienteId: "r", canale: .alleanza, stato: .inEssere, area: .risparmio, nome: "Contratto di capitalizzazione")
            capitalizzazione.tipologia = "Contratto di capitalizzazione"
            capitalizzazione.controvalore = 50_000
            verifica("Successione: la capitalizzazione resta nell'asse", MotoreSuccessione.classifica(capitalizzazione).1 == .asse ? 1 : 0, 1)
            var tcm = Posizione(clienteId: "r", canale: .alleanza, stato: .inEssere, area: .protezione, nome: "TCM")
            tcm.capitaleAssicurato = 100_000
            tcm.scadenza = Calendar.current.date(byAdding: .day, value: -10, to: Date())
            verifica("Successione: una TCM scaduta non paga", MotoreSuccessione.classifica(tcm).0, 0)
            tcm.scadenza = nil
            verifica("Successione: TCM senza rischio indicato, dal nome", MotoreSuccessione.classifica(tcm).0, 100_000)
            var casaA = Posizione(clienteId: "r", canale: .indipendente, stato: .inEssere, area: .immobili, nome: "Abitazione Milano")
            casaA.controvalore = 400_000
            var casaB = Posizione(clienteId: "r", canale: .indipendente, stato: .inEssere, area: .immobili, nome: "Abitazione al mare")
            casaB.controvalore = 300_000
            verifica("Successione: prima casa per una sola abitazione", MotoreSuccessione.calcola(cliente: sposato, posizioni: [casaA, casaB]).ipocatastali, 400 + 9_000)
        }

        // Patrimonio nel tempo: debiti che si estinguono, immobili fermi, proposte senza doppio conteggio
        do {
            func pos(_ nome: String, _ area: AreaPosizione, _ valore: Double, _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
                var p = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: area, nome: nome)
                p.controvalore = valore
                modifica(&p)
                return p
            }
            let mutuo = pos("Mutuo", .debiti, 100_000) { $0.scadenza = Calendar.current.date(byAdding: .year, value: 10, to: Date()) }
            let casa = pos("Casa", .immobili, 300_000)
            let conto = pos("Conto", .liquidita, 20_000)
            let fondo = pos("Fondo", .investimento, 50_000) { $0.rendimentoAtteso = 4; $0.premio = 100; $0.frequenza = .mensile }
            var proposta = Posizione(clienteId: "prova", canale: .alleanza, stato: .proposta, area: .risparmio, nome: "Proposta")
            proposta.versamentoIniziale = 10_000
            proposta.rendimentoAtteso = 2.5
            let pn = MotorePatrimonio.calcola([mutuo, casa, conto, fondo, proposta], anni: 20)
            verifica("Patrimonio: netto di oggi", pn.nettoOggi, 300_000 + 20_000 + 50_000 - 100_000)
            verifica("Patrimonio: a metà durata il mutuo è dimezzato", MotorePatrimonio.andamento(mutuo, anni: 20)[5].valore, -50_000, tolleranza: 1)
            verifica("Patrimonio: il mutuo si estingue alla scadenza", MotorePatrimonio.andamento(mutuo, anni: 20)[15].valore, 0)
            verifica("Patrimonio: l'immobile resta al valore di oggi", MotorePatrimonio.andamento(casa, anni: 20)[20].valore, 300_000)
            verifica("Patrimonio: con le proposte, oggi lo stesso netto (il capitale viene dal conto)", pn.valore(0, conProposte: true), pn.nettoOggi, tolleranza: 1)
            verifica("Patrimonio: il fondo con i versamenti cresce", pn.valore(20) > pn.valore(10) && pn.valore(10) > pn.nettoOggi ? 1 : 0, 1)
            verifica("Patrimonio: versamenti dell'anno", pn.versamentiAnnui, 1_200)
            verifica("Patrimonio: senza proposte nessuna seconda linea", MotorePatrimonio.calcola([casa]).conProposte == nil ? 1 : 0, 1)
            // Il conto che finanzia la proposta smette di rendere su quella parte; oltre i conti è capitale nuovo
            let contoRende = pos("Conto", .liquidita, 50_000) { $0.rendimentoAtteso = 2 }
            var tutto = Posizione(clienteId: "prova", canale: .alleanza, stato: .proposta, area: .risparmio, nome: "Tutto il conto")
            tutto.versamentoIniziale = 50_000
            tutto.rendimentoAtteso = 0
            tutto.tipologia = "Polizza rivalutabile (Ramo I)"
            let spostato = MotorePatrimonio.calcola([contoRende, tutto], anni: 20)
            verifica("Patrimonio: il conto spostato non rende più", spostato.valore(20, conProposte: true), 50_000, tolleranza: 1)
            var grande = tutto
            grande.versamentoIniziale = 80_000
            let oltre = MotorePatrimonio.calcola([contoRende, grande], anni: 20)
            verifica("Patrimonio: oltre i conti è capitale nuovo, dichiarato", oltre.capitaleNuovo, 30_000)
            let passato = Obiettivo(clienteId: "prova", titolo: "Già passato", area: .casa, importo: 10_000,
                                    scadenza: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date())
            verifica("Patrimonio: un obiettivo già passato non è lungo la strada", MotorePatrimonio.calcola([casa], obiettivi: [passato]).traguardi.isEmpty ? 1 : 0, 1)
        }

        // 27. Dati nuovi per i motori: letture con i ripieghi e compatibilità dell'archivio
        do {
            let scheda = DatiDemo.orizzonteValore() // penali [3,5; 2,5; 1,0] dal 2° anno, blocco di 12 mesi
            var p = Posizione(clienteId: "prova", canale: .alleanza, stato: .inEssere, area: .risparmio, nome: "Penali")
            p.penali = [2.5, 2, 1.5, 1]
            // Convenzione di CondizioniContratto.penale(anno:): anno 2 = primo valore; nel 1° anno e dopo l'ultimo, zero
            verifica("Penali della posizione: 2° anno", p.penale(anno: 2, prodotto: scheda), 2.5)
            verifica("Penali della posizione: 5° anno", p.penale(anno: 5, prodotto: scheda), 1)
            verifica("Penali della posizione: dal 6° anno nessuna", p.penale(anno: 6, prodotto: scheda), 0)
            verifica("Penali della posizione: nel 1° anno nessuna (c'è il blocco)", p.penale(anno: 1, prodotto: scheda), 0)
            p.penali = nil
            verifica("Penali dalla scheda prodotto: 3° anno", p.penale(anno: 3, prodotto: scheda), 2.5)
            verifica("Penali: senza posizione né scheda nessuna", p.penale(anno: 3, prodotto: nil), 0)
            p.penali = []
            verifica("Penali: la posizione senza penali prevale sulla scheda", p.penale(anno: 3, prodotto: scheda), 0)
            verifica("Blocco del riscatto dalla scheda", Double(p.bloccoRiscatto(prodotto: scheda) ?? -1), 12)
            verifica("Blocco del riscatto: non indicato", p.bloccoRiscatto(prodotto: nil) == nil ? 1 : 0, 1)
            p.mesiBloccoRiscatto = 6
            verifica("Blocco del riscatto della posizione", Double(p.bloccoRiscatto(prodotto: scheda) ?? -1), 6)

            // Durata residua: 18 mesi esatti da una data fissa; dopo la scadenza zero; senza scadenza nil
            let inizio = Date(timeIntervalSinceReferenceDate: 800_000_000)
            p.scadenza = Calendar.current.date(byAdding: .month, value: 18, to: inizio)
            verifica("Durata residua: 18 mesi", Double(p.mesiResidui(al: inizio) ?? -1), 18)
            let dopo = Calendar.current.date(byAdding: .day, value: 40, to: p.scadenza ?? inizio) ?? inizio
            verifica("Durata residua: scaduta", Double(p.mesiResidui(al: dopo) ?? -1), 0)
            p.scadenza = nil
            verifica("Durata residua: senza scadenza", p.mesiResidui(al: inizio) == nil ? 1 : 0, 1)

            // Dati di prova coerenti: rata alla francese = D·i / (1 − (1+i)^−n), i = tasso/12, n = mesi residui.
            // A mano: Giulia 95.000 € al 3,8% per 216 mesi ≈ 607,92 € (indicata 610); Marco 130.000 € al 3,6% per
            // 192 mesi ≈ 891,69 € (890); Laura 6.000 € al 3,8% per 24 mesi ≈ 260,02 € (260); Sofia 40.000 € al 3,6%
            // per 96 mesi ≈ 480,16 € (480)
            for m in DatiDemo.posizioni() where m.area == .debiti {
                guard let tasso = m.tassoDebito, let anni = m.anniAllaScadenza, let d = m.controvalore else { continue }
                let i = tasso / 100 / 12
                let rata = d * i / (1 - pow(1 + i, -Double(anni * 12)))
                verifica("Dati di prova: rata di «\(m.nome)» (\(m.clienteId)) dal tasso", rata, m.premio, tolleranza: 3)
            }

            // Pensione: aliquota di computo indicata o del tipo di lavoratore; sistema misto prima del 1996
            verifica("Lavoro: aliquota del dipendente", DatiLavoro(tipo: .dipendente).aliquota ?? -1, 33)
            verifica("Lavoro: aliquota della Gestione separata", DatiLavoro(tipo: .gestioneSeparata).aliquota ?? -1, 25)
            verifica("Lavoro: aliquota indicata dal consulente", DatiLavoro(tipo: .autonomo, aliquotaContributiva: 24.48).aliquota ?? -1, 24.48)
            verifica("Lavoro: cassa professionale non stimata", DatiLavoro(tipo: .cassaProfessionale).aliquota == nil ? 1 : 0, 1)
            verifica("Lavoro: contributi dal 1993, sistema misto", DatiLavoro(annoPrimoContributo: 1993).sistemaMisto ? 1 : 0, 1)
            verifica("Lavoro: contributi dal 1996, contributivo puro", DatiLavoro(annoPrimoContributo: 1996).sistemaMisto ? 1 : 0, 0)
            verifica("Lavoro: anno non indicato, non misto", DatiLavoro().sistemaMisto ? 1 : 0, 0)
            let clientiDemo = DatiDemo.clienti()
            let giuliaDemo = clientiDemo.first { $0.id == "giulia" }
            verifica("Lavoro: reddito da lavoro di Giulia dal reddito complessivo", giuliaDemo?.profilo.redditoDaLavoro ?? -1, 32_000)
            var profilo = ProfiloInvestitore()
            profilo.redditoLordoAnnuo = 50_000
            profilo.lavoro = DatiLavoro(redditoLavoro: 42_000)
            verifica("Lavoro: il reddito da lavoro indicato prevale", profilo.redditoDaLavoro ?? -1, 42_000)

            // Archivio: i campi nuovi sopravvivono ad andata e ritorno; quelli illeggibili non scartano nulla
            let posizioniDemo = DatiDemo.posizioni()
            let posizioniLette = (try? Archivio.codificatore.encode(posizioniDemo)).flatMap { try? Archivio.decodificatore.decode([Posizione].self, from: $0) }
            verifica("Archivio: posizioni di prova identiche dopo andata e ritorno", posizioniLette == posizioniDemo ? 1 : 0, 1)
            let andrea = posizioniLette?.first { $0.clienteId == "andrea" && $0.area == .risparmio }
            verifica("Archivio: penali della proposta di Andrea conservate", andrea?.penali == [2.5, 2, 1.5, 1] ? 1 : 0, 1)
            let clientiLetti = (try? Archivio.codificatore.encode(clientiDemo)).flatMap { try? Archivio.decodificatore.decode([Cliente].self, from: $0) }
            verifica("Archivio: clienti di prova identici dopo andata e ritorno", clientiLetti == clientiDemo ? 1 : 0, 1)
            let marcoLetto = clientiLetti?.first { $0.id == "marco" }
            verifica("Archivio: montante contributivo di Marco conservato", marcoLetto?.profilo.lavoro?.montanteContributivo ?? -1, 265_000)
            verifica("Archivio: reddito di Elena conservato", marcoLetto?.famiglia.first?.redditoNettoAnnuo ?? -1, 16_000)
            var etf = DatiDemo.prodotti().first { $0.id == "prodotto-etf-globale" } ?? DatiDemo.orizzonteValore()
            var gs = ComponenteContratto(tipo: .gestioneSeparata, nome: "Prova", quota: 100)
            gs.minimoGarantito = 0.5
            gs.consolidamento = false
            gs.retrocessione = 85
            var condizioni = CondizioniContratto()
            condizioni.componenti = [gs]
            etf.condizioni = condizioni
            let etfLetto = (try? Archivio.codificatore.encode(etf)).flatMap { try? Archivio.decodificatore.decode(Prodotto.self, from: $0) }
            verifica("Archivio: scheda prodotto identica dopo andata e ritorno", etfLetto == etf ? 1 : 0, 1)
            verifica("Archivio: incidenza dei costi del KID conservata", etfLetto?.incidenzaCostiKID ?? -1, 0.2)
            verifica("Archivio: retrocessione della gestione separata conservata", etfLetto?.condizioni?.componenti.first?.retrocessione ?? -1, 85)
            verifica("Archivio: la proposta dalla scheda porta il periodo raccomandato", Double(etf.proposta(per: "prova").periodoRaccomandato ?? -1), 5)
            // Un archivio di prima (senza i campi nuovi) si legge; un movimento o un tipo di lavoratore illeggibile diventano valori vuoti
            let vecchia = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .investimento, nome: "Vecchia")
            let grezzo = (try? Archivio.codificatore.encode(vecchia)).flatMap { try? JSONSerialization.jsonObject(with: $0) }
            var oggetto: [String: Any] = (grezzo as? [String: Any]) ?? [:]
            let lettaVecchia = (try? JSONSerialization.data(withJSONObject: oggetto)).flatMap { try? Archivio.decodificatore.decode(Posizione.self, from: $0) }
            verifica("Archivio: posizione senza i campi nuovi letta", lettaVecchia?.movimenti == nil && lettaVecchia?.nome == "Vecchia" ? 1 : 0, 1)
            let movimentiGrezzi: [[String: Any]] = [["data": "non è una data", "importo": "mille"],
                                                    ["data": "2025-01-01T00:00:00Z", "importo": 500]]
            oggetto["movimenti"] = movimentiGrezzi
            let conMovimenti = (try? JSONSerialization.data(withJSONObject: oggetto)).flatMap { try? Archivio.decodificatore.decode(Posizione.self, from: $0) }
            verifica("Archivio: movimenti illeggibili non scartano la posizione", Double(conMovimenti?.movimenti?.count ?? -1), 2)
            verifica("Archivio: importo illeggibile diventa zero", conMovimenti?.movimenti?.first?.importo ?? -1, 0)
            verifica("Archivio: movimento leggibile conservato", conMovimenti?.movimenti?.last?.importo ?? -1, 500)
            let lavoroIgnoto = try? Archivio.decodificatore.decode(DatiLavoro.self, from: Data(#"{"tipo":"pilota","anniContributi":12}"#.utf8))
            verifica("Archivio: tipo di lavoratore sconosciuto ignorato", lavoroIgnoto != nil && lavoroIgnoto?.tipo == nil ? 1 : 0, 1)
            verifica("Archivio: anni di contributi conservati", lavoroIgnoto?.anniContributi ?? -1, 12)
        }

        // Prove dei miglioramenti dei motori, in file separati: gli errori si sommano a quelli qui sopra
        let verificaEsterna = VerificaCalcoli { nome, ottenuto, atteso, tolleranza in
            verifica(nome, ottenuto, atteso, tolleranza: tolleranza)
        }
        ProvaCalcoliRendimenti.esegui(verificaEsterna)
        ProvaCalcoliRischio.esegui(verificaEsterna)
        ProvaCalcoliFamiglia.esegui(verificaEsterna)

        if errori == 0 {
            print("OK: motori di calcolo verificati")
            return 0
        }
        print("ERRORE: \(errori) verifiche non riuscite")
        return 1
    }
}

/// La funzione `verifica` di `ProvaCalcoli.esegui()`, passata alle prove che stanno in file separati
/// (`ProvaCalcoliRendimenti`, `ProvaCalcoliRischio`, `ProvaCalcoliFamiglia`): ogni verifica stampa
/// «OK» o «ERRORE» e un errore si somma allo stesso contatore del riepilogo finale.
/// Si chiama come quella originale: `verifica("nome", ottenuto, atteso)` o con `tolleranza: 1`.
struct VerificaCalcoli {
    let controlla: (String, Double, Double, Double) -> Void

    func callAsFunction(_ nome: String, _ ottenuto: Double, _ atteso: Double, tolleranza: Double = 0.01) {
        controlla(nome, ottenuto, atteso, tolleranza)
    }

    /// Una condizione che deve essere vera (come `verifica(nome, condizione ? 1 : 0, 1)`).
    func vero(_ nome: String, _ condizione: Bool) {
        controlla(nome, condizione ? 1 : 0, 1, 0.01)
    }
}

/// Aiuti comuni per scrivere i casi delle prove nei file separati.
enum AiutiProva {
    /// Una posizione di prova in essere, canale indipendente, con il valore indicato.
    static func posizione(_ nome: String, _ area: AreaPosizione, _ valore: Double,
                          canale: Canale = .indipendente, _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        var p = Posizione(clienteId: "prova", canale: canale, stato: .inEssere, area: area, nome: nome)
        p.controvalore = valore
        modifica(&p)
        return p
    }

    /// Una data fissa (calendario gregoriano, ore 12 per evitare i salti dell'ora legale): prove riproducibili.
    static func data(_ anno: Int, _ mese: Int, _ giorno: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: anno, month: mese, day: giorno, hour: 12)) ?? Date()
    }

    /// Oggi all'inizio del giorno, come `oggi` di `ProvaCalcoli`.
    static var oggi: Date { Calendar(identifier: .gregorian).startOfDay(for: Date()) }
}
