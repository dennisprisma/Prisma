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
        verifica("IRPEF: aliquota marginale con 32.000 €", RegoleFiscali.aliquotaMarginale(reddito: 32_000), 35)
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
        verifica("Previdenza: deducibile fino al limite (7.200 € versati)", ded.deducibiliOggi, 5_164.57)
        verifica("Previdenza: risparmio IRPEF al 35%", ded.risparmioOggi, 5_164.57 * 0.35, tolleranza: 0.01)

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

        if errori == 0 {
            print("OK: motori di calcolo verificati")
            return 0
        }
        print("ERRORE: \(errori) verifiche non riuscite")
        return 1
    }
}
