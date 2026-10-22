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
        let cinque = MotoreResoconto.Flussi(versamenti: [(36, 10_000)], valore: 10_000 * pow(1.05, 3))
        verifica("Resoconto: rendimento annuo di 10.000 € diventati 11.576 € in 3 anni", MotoreResoconto.tir([cinque]) ?? 0, 5)
        let due = MotoreResoconto.Flussi(versamenti: [(24, 5_000)], valore: 5_000 * pow(1.05, 2))
        verifica("Resoconto: rendimento annuo di due posizioni al 5%", MotoreResoconto.tir([cinque, due]) ?? 0, 5)
        let mensili = MotoreResoconto.Flussi(versamenti: (0..<12).map { (Double(12 - $0), 100.0) }, valore: 1_200)
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
        let giulia = MotoreResoconto.calcola(DatiDemo.posizioni().filter { $0.clienteId == "giulia" }, cliente: "Giulia Rossi")
        verifica("Resoconto di Giulia: versato nelle posizioni finanziarie", giulia.versato, 58_000)
        verifica("Resoconto di Giulia: valore delle posizioni finanziarie", giulia.valoreFinanziario, 65_050)
        verifica("Resoconto di Giulia: patrimonio netto", giulia.riepilogo.patrimonioNetto, 204_050)
        verifica("Resoconto di Giulia: costi stimati di un anno", giulia.costoAnnuo, 395.6)
        verifica("Resoconto di Giulia: posizioni in essere", Double(giulia.voci.count), 7)
        verifica("Resoconto di Giulia: storico di 12 mesi su tutte le finanziarie", Double(giulia.conStorico.count), 3)

        if errori == 0 {
            print("OK: motori di calcolo verificati")
            return 0
        }
        print("ERRORE: \(errori) verifiche non riuscite")
        return 1
    }
}
