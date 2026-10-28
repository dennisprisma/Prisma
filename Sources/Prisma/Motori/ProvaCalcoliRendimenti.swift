import Foundation

/// Prove dei motori di rendimento e costi: rendimento sui flussi datati (XIRR), incidenza annua dei costi
/// come nel KID (RIY), riscatto anno per anno con penali, gestione separata (minimo garantito, consolidamento,
/// retrocessione). Chiamate da `ProvaCalcoli.esegui()` prima del riepilogo: gli errori si sommano.
/// I risultati attesi sono calcolati a parte (formula chiusa o bisezione indipendente) e scritti nel commento.
enum ProvaCalcoliRendimenti {
    static func esegui(_ verifica: VerificaCalcoli) {
        let d = AiutiProva.data

        // R1. XIRR con due versamenti: 10.000 € il 1/1/2024 e 5.000 € il 1/7/2024, valore 16.000 € il 1/1/2025.
        // A mano (giorni/365; 2024 bisestile: 366 giorni dal primo versamento, 184 dal secondo):
        // 10.000·(1+r)^(366/365) + 5.000·(1+r)^(184/365) = 16.000 → r = 7,9994% (bisezione indipendente)
        do {
            let r = Rendimenti.xirr([(data: d(2024, 1, 1), importo: 10_000), (data: d(2024, 7, 1), importo: 5_000)],
                                    valoreFinale: 16_000, al: d(2025, 1, 1)) ?? -99
            verifica("XIRR: due versamenti", r, 7.9994, tolleranza: 0.001)
        }

        // R2. Un anno esatto di 365 giorni: 10.000 € → 11.000 € = +10%
        do {
            let r = Rendimenti.xirr([(data: d(2025, 1, 1), importo: 10_000)], valoreFinale: 11_000, al: d(2026, 1, 1)) ?? -99
            verifica("XIRR: un anno esatto", r, 10, tolleranza: 0.000_1)
        }

        // R3. Con un riscatto parziale: 10.000 € il 1/1/2023, 3.000 € incassati il 1/1/2024, valore 8.000 € il 1/1/2025.
        // 10.000·(1+r)^(731/365) − 3.000·(1+r)^(366/365) = 8.000 → r = 5,6851% (bisezione indipendente)
        do {
            let r = Rendimenti.xirr([(data: d(2023, 1, 1), importo: 10_000), (data: d(2024, 1, 1), importo: -3_000)],
                                    valoreFinale: 8_000, al: d(2025, 1, 1)) ?? -99
            verifica("XIRR: riscatto parziale come incasso", r, 5.6851, tolleranza: 0.001)
        }

        // R4. Casi senza risultato e casi limite
        do {
            verifica.vero("XIRR: senza flussi nessun risultato", Rendimenti.xirr([], valoreFinale: 1_000, al: d(2025, 1, 1)) == nil)
            // Solo uscite per il cliente: i flussi non cambiano segno
            verifica.vero("XIRR: valore zero e nessun incasso, nessun risultato",
                          Rendimenti.xirr([(data: d(2024, 1, 1), importo: 1_000)], valoreFinale: 0, al: d(2025, 1, 1)) == nil)
            verifica.vero("XIRR: solo incassi, nessun risultato",
                          Rendimenti.tasso([(anni: 1, importo: -1_000)], valoreFinale: 500) == nil)
            // 10.000 → 100 in un anno esatto: −99% (il limite dell'intervallo), raggiunto
            verifica("XIRR: perdita del 99% in un anno", Rendimenti.tasso([(anni: 1, importo: 10_000)], valoreFinale: 100) ?? 0, -99, tolleranza: 0.000_1)
            // 10.000 → 50 in un anno: −99,5%, fuori dall'intervallo cercato (Newton e bisezione non trovano nulla)
            verifica.vero("XIRR: fuori dall'intervallo nessun risultato", Rendimenti.tasso([(anni: 1, importo: 10_000)], valoreFinale: 50) == nil)
            // Versamenti senza guadagno: zero
            let mensili = (0..<12).map { (anni: Double(12 - $0) / 12, importo: 100.0) }
            verifica("XIRR: versamenti senza guadagno, rendimento zero", Rendimenti.tasso(mensili, valoreFinale: 1_200) ?? 1, 0, tolleranza: 0.000_1)
        }

        // R5. Resoconto di una posizione con il solo versamento iniziale: 10.000 € il 1/3/2023, 11.576,25 € il 1/3/2026
        // (1.096 giorni, il 2024 è bisestile) → r = 1,157625^(365/1.096) − 1 = 4,9953%; il TIR in mesi sugli stessi
        // flussi dà lo stesso numero (mesi = giorni/365·12)
        do {
            let p = AiutiProva.posizione("Fondo", .investimento, 11_576.25) {
                $0.decorrenza = d(2023, 3, 1); $0.dataValore = d(2026, 3, 1)
                $0.versamentoIniziale = 10_000; $0.totaleVersato = 10_000
            }
            let voce = MotoreResoconto.voce(p, data: d(2026, 3, 1))
            verifica("Resoconto: rendimento sul versamento iniziale alle date reali", voce.rendimentoAnnuo ?? -99, 4.9953, tolleranza: 0.001)
            let tir = MotoreResoconto.flussi(p, data: d(2026, 3, 1)).flatMap { MotoreResoconto.tir([$0]) } ?? -99
            verifica("Resoconto: XIRR e TIR in mesi coincidono", tir, voce.rendimentoAnnuo ?? 99, tolleranza: 0.000_1)
        }

        // R6. Premi mensili alle date della frequenza: 100 € il 15 di ogni mese da gennaio a dicembre 2025 (12 premi;
        // quello del 15/1/2026 cade alla data del valore e non conta), valore 1.250 € il 15/1/2026.
        // Σ 100·(1+r)^(giorni_k/365) = 1.250 → r = 7,7495% (bisezione indipendente)
        do {
            let p = AiutiProva.posizione("Piano", .investimento, 1_250) {
                $0.decorrenza = d(2025, 1, 15); $0.dataValore = d(2026, 1, 15)
                $0.premio = 100; $0.frequenza = .mensile; $0.totaleVersato = 1_200
            }
            let f = MotoreResoconto.flussiDatati(p, data: d(2026, 1, 15))
            verifica("Flussi datati: dodici premi", Double(f?.flussi.count ?? 0), 12)
            verifica("Flussi datati: versato ricostruito", f?.flussi.reduce(0.0) { $0 + $1.importo } ?? 0, 1_200)
            verifica.vero("Flussi datati: ricostruiti, non movimenti reali", f?.reali == false)
            verifica("Resoconto: premi mensili alle loro date", MotoreResoconto.voce(p, data: d(2026, 1, 15)).rendimentoAnnuo ?? -99, 7.7495, tolleranza: 0.001)
            // Versato più alto dei premi (2.200 € contro 12 × 100): i 1.000 € in più alla decorrenza (trasferimento),
            // valore 2.300 € → Σ premi + 1.000·(1+r)^(365/365) = 2.300 → r = 6,0725%
            var q = p
            q.totaleVersato = 2_200
            q.controvalore = 2_300
            let fq = MotoreResoconto.flussiDatati(q, data: d(2026, 1, 15))
            let allaDecorrenza = fq?.flussi.filter { Calendar.current.isDate($0.data, inSameDayAs: d(2025, 1, 15)) }.reduce(0.0) { $0 + $1.importo } ?? 0
            verifica("Flussi datati: il versato in più va alla decorrenza", allaDecorrenza, 1_100)
            verifica("Resoconto: versato in più alla decorrenza", MotoreResoconto.voce(q, data: d(2026, 1, 15)).rendimentoAnnuo ?? -99, 6.0725, tolleranza: 0.001)
        }

        // R7. Riscatto parziale stimato dallo storico: 20.000 € il 1/1/2024; il 1/1/2025 vale 21.000 € con 20.000 versati;
        // il 1/1/2026 vale 11.000 € con 10.000 versati. Il versato scende di metà: uscita = 10.000/20.000 × 21.000 =
        // 10.500 € a metà del periodo (182,5 giorni → 183 giorni prima della fine).
        // 20.000·(1+r)^(731/365) − 10.500·(1+r)^(183/365) = 11.000 → r = 4,2030% (bisezione indipendente)
        do {
            let p = AiutiProva.posizione("Polizza", .investimento, 11_000) {
                $0.decorrenza = d(2024, 1, 1); $0.dataValore = d(2026, 1, 1)
                $0.versamentoIniziale = 20_000; $0.totaleVersato = 10_000
                $0.rilevazioni = [Rilevazione(data: d(2025, 1, 1), controvalore: 21_000, versato: 20_000)]
            }
            let f = MotoreResoconto.flussiDatati(p, data: d(2026, 1, 1))
            verifica("Flussi datati: riscatto parziale stimato", f?.flussi.first(where: { $0.importo < 0 })?.importo ?? 0, -10_500)
            verifica("Resoconto: rendimento con il riscatto parziale", MotoreResoconto.voce(p, data: d(2026, 1, 1)).rendimentoAnnuo ?? -99, 4.2030, tolleranza: 0.001)
        }

        // R8. Movimenti reali: con almeno un versamento sono l'elenco completo (il versamento iniziale indicato non
        // conta). Gli stessi flussi di R1 → 7,9994%. Con le sole uscite indicate, i versamenti si ricostruiscono e
        // l'uscita si aggiunge: gli stessi flussi di R3 → 5,6851%
        do {
            let p = AiutiProva.posizione("Con movimenti", .investimento, 16_000) {
                $0.decorrenza = d(2024, 1, 1); $0.dataValore = d(2025, 1, 1); $0.versamentoIniziale = 99_999
                $0.movimenti = [Movimento(data: d(2024, 1, 1), importo: 10_000), Movimento(data: d(2024, 7, 1), importo: 5_000)]
            }
            verifica.vero("Movimenti reali usati", MotoreResoconto.flussiDatati(p, data: d(2025, 1, 1))?.reali == true)
            verifica("Resoconto: rendimento sui movimenti reali", MotoreResoconto.voce(p, data: d(2025, 1, 1)).rendimentoAnnuo ?? -99, 7.9994, tolleranza: 0.001)
            let q = AiutiProva.posizione("Con uscita", .investimento, 8_000) {
                $0.decorrenza = d(2023, 1, 1); $0.dataValore = d(2025, 1, 1); $0.versamentoIniziale = 10_000
                $0.movimenti = [Movimento(data: d(2024, 1, 1), importo: -3_000, nota: "Riscatto parziale")]
            }
            verifica("Resoconto: uscita indicata e versamenti ricostruiti", MotoreResoconto.voce(q, data: d(2025, 1, 1)).rendimentoAnnuo ?? -99, 5.6851, tolleranza: 0.001)
        }

        // R9. Più posizioni insieme: due posizioni al 5% esatto con date diverse danno il 5% complessivo.
        // A: 10.000 € il 1/1/2023 → 10.000·1,05^(731/365) il 1/1/2025; B: 5.000 € il 1/6/2023 → 5.000·1,05^(549/365)
        // il 1/12/2024 (549 giorni). I valori finali contano come incassi alla loro data.
        do {
            let a = AiutiProva.posizione("A", .investimento, 10_000 * Foundation.pow(1.05, 731.0 / 365)) {
                $0.decorrenza = d(2023, 1, 1); $0.dataValore = d(2025, 1, 1); $0.versamentoIniziale = 10_000
            }
            let b = AiutiProva.posizione("B", .investimento, 5_000 * Foundation.pow(1.05, 549.0 / 365)) {
                $0.decorrenza = d(2023, 6, 1); $0.dataValore = d(2024, 12, 1); $0.versamentoIniziale = 5_000
            }
            let insieme = [a, b].compactMap { MotoreResoconto.flussiDatati($0, data: d(2025, 1, 1)) }
            verifica("Resoconto: rendimento di due posizioni al 5%", MotoreResoconto.rendimento(insieme) ?? -99, 5, tolleranza: 0.000_1)
            let e = MotoreResoconto.calcola([a, b], cliente: "Prova", data: d(2025, 1, 1))
            verifica("Resoconto: rendimento complessivo nel resoconto", e.rendimentoAnnuo ?? -99, 5, tolleranza: 0.000_1)
        }

        // R10. Dati di prova: tutte le posizioni finanziarie di Giulia (almeno un anno) hanno un rendimento plausibile
        do {
            let e = MotoreResoconto.calcola(DatiDemo.posizioni().filter { $0.clienteId == "giulia" }, cliente: "Giulia Rossi")
            verifica.vero("Resoconto di Giulia: rendimento complessivo tra 0 e 15%", (e.rendimentoAnnuo ?? -1) > 0 && (e.rendimentoAnnuo ?? 99) < 15)
            verifica.vero("Resoconto di Giulia: rendimento per ogni posizione finanziaria", e.finanziarie.allSatisfy { $0.rendimentoAnnuo != nil })
            verifica.vero("Resoconto di Giulia: rendimento netto calcolato", e.rendimentoNettoAnnuo != nil)
        }

        // R11. Incidenza annua dei costi come nel KID (RIY). Premio unico di 10.000 €, rendimento 5%, costo annuo 1%,
        // periodo raccomandato 10 anni (uscite dopo 1, 5 e 10 anni). Ogni anno il valore cresce di 1,05 × 0,99 = 1,0395:
        // RIY = 5 − 3,95 = 1,05 punti a ogni uscita. È un fondo (con bollo): il bollo è un'imposta e non entra.
        do {
            let p = AiutiProva.posizione("Fondo", .investimento, 0) {
                $0.stato = .proposta; $0.tipologia = "Fondo comune"; $0.versamentoIniziale = 10_000
                $0.rendimentoAtteso = 5; $0.costoAnnuo = 1; $0.periodoRaccomandato = 10; $0.incidenzaCostiKID = 1.1
            }
            if let k = MotoreCosti.incidenzaKID(p) {
                verifica("RIY: uscite del KID (1, 5 e 10 anni)", Double(k.periodi.count), 3)
                verifica("RIY: a metà del periodo (5 anni)", Double(k.periodi.count > 1 ? k.periodi[1].anni : 0), 5)
                for x in k.periodi { verifica("RIY: \(x.anni) anni, 5 − 3,95", x.riy, 1.05, tolleranza: 0.000_1) }
                verifica("RIY: senza costi rende il 5%", k.periodi.first?.senzaCosti ?? 0, 5, tolleranza: 0.000_1)
                verifica("RIY: dichiarato nel KID tenuto separato", k.dichiarato ?? 0, 1.1)
                verifica("RIY: calcolato meno dichiarato", k.scarto ?? 0, -0.05, tolleranza: 0.000_1)
                verifica("RIY: anno per anno fino al periodo raccomandato", Double(k.annoPerAnno.count), 10)
            } else {
                verifica.vero("RIY: calcolato per il premio unico", false)
            }
            // Con ingresso del 3%: dopo 1 anno 0,97 × 1,0395 = 1,008315 → RIY = 5 − 0,8315 = 4,1685;
            // dopo 10 anni 0,97^(1/10) × 1,0395 − 1 = 3,63386% → RIY 1,36614 (conto a parte)
            var q = p
            q.costoIngresso = 3
            if let k = MotoreCosti.incidenzaKID(q) {
                verifica("RIY con ingresso del 3%: 1 anno", k.periodi.first?.riy ?? 0, 4.1685, tolleranza: 0.000_1)
                verifica("RIY con ingresso del 3%: 10 anni", k.calcolato ?? 0, 1.36614, tolleranza: 0.000_1)
                verifica("RIY con ingresso: euro di costi dopo 1 anno", k.periodi.first?.costi ?? 0, 10_500 - 10_083.15, tolleranza: 0.01)
            } else {
                verifica.vero("RIY: calcolato con l'ingresso", false)
            }
        }

        // R12. RIY con premi annui di 1.000 € per 3 anni (5%, costo 1%): ogni premio cresce di 1,0395 l'anno,
        // il rendimento con i costi è 3,95% e il RIY 1,05 sia a 1 anno sia a 3 (sotto i 10 anni niente metà)
        do {
            let p = AiutiProva.posizione("Piano", .investimento, 0) {
                $0.stato = .proposta; $0.tipologia = "Fondo comune"; $0.premio = 1_000; $0.frequenza = .annuale
                $0.rendimentoAtteso = 5; $0.costoAnnuo = 1; $0.periodoRaccomandato = 3
            }
            let k = MotoreCosti.incidenzaKID(p)
            verifica("RIY premi annui: uscite a 1 e 3 anni", Double(k?.periodi.map(\.anni).reduce(0, +) ?? 0), 4)
            verifica("RIY premi annui: rendimento con i costi", k?.periodi.last?.conCosti ?? 0, 3.95, tolleranza: 0.000_1)
            verifica("RIY premi annui: 3 anni", k?.calcolato ?? 0, 1.05, tolleranza: 0.000_1)
        }

        // R13. RIY con la penale della posizione: 10.000 € al 5% senza costi, penale del 2% all'uscita dopo 1 anno
        // (inizio del 2° anno): 10.500 × 0,98 = 10.290 → 2,9% → RIY 2,1 punti, 210 € di costi
        do {
            let p = AiutiProva.posizione("Polizza", .investimento, 0) {
                $0.stato = .proposta; $0.tipologia = "Fondo comune"; $0.versamentoIniziale = 10_000
                $0.rendimentoAtteso = 5; $0.penali = [2]; $0.periodoRaccomandato = 1
            }
            let k = MotoreCosti.incidenzaKID(p)
            verifica("RIY con penale: 1 anno", k?.calcolato ?? 0, 2.1, tolleranza: 0.000_1)
            verifica("RIY con penale: euro", k?.periodi.first?.costi ?? 0, 210, tolleranza: 0.01)
            verifica("RIY: uscite del KID con 15 anni (1, 8, 15)", Double(MotoreCosti.periodiKID(15).reduce(0, +)), 24)
            verifica("RIY: uscite del KID con 5 anni (1, 5)", Double(MotoreCosti.periodiKID(5).count), 2)
            verifica("RIY: uscite del KID con 1 anno", Double(MotoreCosti.periodiKID(1).count), 1)
        }

        // R14. RIY della gestione separata: lordo 3%, trattenuto 1,2 → 1,03 × 0,988 = 1,01764 → RIY 1,236;
        // con la retrocessione dell'80% (trattenuto 0,6 punti) → 1,03 × 0,994 = 1,02382 → RIY 0,618
        do {
            let p = AiutiProva.posizione("Rivalutabile", .risparmio, 0) {
                $0.stato = .proposta; $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.versamentoIniziale = 10_000
                $0.rendimentoAtteso = 3; $0.trattenuto = 1.2; $0.periodoRaccomandato = 5
            }
            verifica("RIY gestione separata: trattenuto fisso", MotoreCosti.incidenzaKID(p)?.calcolato ?? 0, 1.236, tolleranza: 0.000_1)
            var q = p
            q.trattenuto = nil
            q.retrocessione = 80
            verifica("RIY gestione separata: retrocessione dell'80%", MotoreCosti.incidenzaKID(q)?.calcolato ?? 0, 0.618, tolleranza: 0.000_1)
        }

        // R15. Riscatto anno per anno di una proposta di Ramo I: 10.000 € al 2% (nessun costo), penali 3%, 2%, 1% nel
        // 2°, 3° e 4° anno, blocco di 12 mesi, imposta del 26% sul guadagno.
        // Subito: non riscattabile. Dopo 1 anno: 10.200 − 3% (306) = 9.894 € (nessuna imposta, sotto il versato).
        // Dopo 2 anni: 10.404 − 2% (208,08) = 10.195,92; imposta 26% di 195,92 = 50,94 → 10.144,98 €: primo recupero.
        // Dopo 4 anni (5° anno): nessuna penale, 10.824,32 − 26% di 824,32 = 10.610,00 €.
        do {
            let oggi = d(2026, 1, 15)
            let p = AiutiProva.posizione("Rivalutabile", .risparmio, 0) {
                $0.stato = .proposta; $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.versamentoIniziale = 10_000
                $0.rendimentoAtteso = 2; $0.aliquotaFiscale = 26; $0.penali = [3, 2, 1]; $0.mesiBloccoRiscatto = 12
            }
            if let e = MotoreRiscatto.calcola(p, data: oggi) {
                verifica.vero("Riscatto: subito non è possibile (blocco)", e.righe.first?.possibile == false)
                verifica("Riscatto: 1 anno, penale del 3%", e.righe.count > 1 ? e.righe[1].netto : 0, 9_894)
                verifica("Riscatto: 2 anni, penale del 2% e imposta", e.righe.count > 2 ? e.righe[2].netto : 0, 10_144.9808)
                verifica("Riscatto: 4 anni, senza penale", e.righe.count > 4 ? e.righe[4].netto : 0, 10_609.997984)
                verifica("Riscatto: primo anno che restituisce il versato", Double(e.primoRecupero?.anni ?? -1), 2)
                verifica("Riscatto: primo anno di contratto senza penali", Double(e.annoSenzaPenali), 5)
                verifica("Riscatto: primo riscatto senza penali tra 4 anni", Double(e.primoSenzaPenali?.anni ?? -1), 4)
                verifica("Riscatto: senza scadenza almeno 10 anni", Double(e.righe.count), 11)
            } else {
                verifica.vero("Riscatto: calcolato per la proposta", false)
            }
        }

        // R16. Riscatto di una polizza in essere ancora nel blocco: decorrenza 15/7/2025, oggi 15/1/2026 (6 mesi), blocco
        // di 12 mesi → riscattabile dal 15/7/2026. Valore 10.100 €, versati 10.000, 2%, penali 3%, 2%, 1%.
        // Tra 1 anno (2° anno di contratto): 10.302 − 3% (309,06) = 9.992,94 €; tra 2 anni (3° anno): 10.508,04 − 2%
        // (210,16) = 10.297,88, imposta 26% di 297,88 = 77,45 → 10.220,43 €: primo recupero.
        do {
            let oggi = d(2026, 1, 15)
            let p = AiutiProva.posizione("Rivalutabile", .risparmio, 10_100) {
                $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.decorrenza = d(2025, 7, 15); $0.totaleVersato = 10_000
                $0.rendimentoAtteso = 2; $0.aliquotaFiscale = 26; $0.penali = [3, 2, 1]; $0.mesiBloccoRiscatto = 12
            }
            if let e = MotoreRiscatto.calcola(p, anni: 5, data: oggi) {
                verifica.vero("Riscatto in essere: oggi nel blocco", e.righe.first?.possibile == false)
                verifica.vero("Riscatto in essere: riscattabile dal 15/7/2026", e.riscattabileDal.map { Calendar.current.isDate($0, inSameDayAs: d(2026, 7, 15)) } ?? false)
                verifica("Riscatto in essere: 2° anno di contratto tra 1 anno", Double(e.righe.count > 1 ? e.righe[1].annoContratto : 0), 2)
                verifica("Riscatto in essere: netto tra 1 anno", e.righe.count > 1 ? e.righe[1].netto : 0, 9_992.94)
                verifica("Riscatto in essere: netto tra 2 anni", e.righe.count > 2 ? e.righe[2].netto : 0, 10_220.430608)
                verifica("Riscatto in essere: primo recupero tra 2 anni", Double(e.primoRecupero?.anni ?? -1), 2)
                verifica("Riscatto in essere: anni chiesti", Double(e.righe.count), 6)
            } else {
                verifica.vero("Riscatto: calcolato per la posizione in essere", false)
            }
            // Senza penali né blocco, con costo d'uscita dell'1% su un fondo: nessun anno «senza penali» da attendere
            let fondo = AiutiProva.posizione("Fondo", .investimento, 10_000) {
                $0.tipologia = "Fondo comune"; $0.decorrenza = d(2020, 1, 1); $0.totaleVersato = 10_000; $0.costoUscita = 1
            }
            let ef = MotoreRiscatto.calcola(fondo, anni: 3, data: oggi)
            verifica("Riscatto: costo d'uscita nella penale", ef?.righe.first?.penalePercento ?? 0, 1)
            verifica("Riscatto: senza penali per anno", Double(ef?.annoSenzaPenali ?? 0), 1)
            var pip = fondo
            pip.area = .previdenza
            verifica.vero("Riscatto: la previdenza ha le sue regole (nessun calcolo)", MotoreRiscatto.calcola(pip, data: oggi) == nil)
        }

        // R17. Valutazione di un contratto: blocco del riscatto, primo recupero del premio, RIY anno per anno, pavimento
        // della gestione separata. Gestione separata 100%, lordo 3%, trattenuto 1 (→ 2%), premio 10.000 €, penali 2% e 1%.
        // Anno 2: 10.200 − 2% = 9.996 € (rendimento lordo −0,04% → RIY 3,04). Anno 3: 10.404 − 1% = 10.299,96;
        // imposta 26% di 299,96 = 77,99 → 10.221,97 € (rendimento lordo √1,029996 − 1 = 1,4887% → RIY 1,5113)
        do {
            func esito(lordo: Double, blocco: Int = 12, _ modifica: (inout ComponenteContratto) -> Void = { _ in }) -> EsitoScenarioValutazione? {
                var gs = ComponenteContratto(tipo: .gestioneSeparata, nome: "Prova", quota: 100)
                gs.trattenuto = 1
                modifica(&gs)
                var c = CondizioniContratto()
                c.componenti = [gs]
                c.penali = [2, 1]
                c.mesiBloccoRiscatto = blocco
                var v = ValutazioneInvestimento(clienteId: "prova", intestatari: "Prova", prodottoId: "prova", premio: 10_000)
                v.anni = 2
                var scenari: [ScenarioValutazione] = []
                for t in TipoScenario.allCases {
                    var s = ScenarioValutazione(tipo: t)
                    s.rendimenti = [gs.id: lordo]
                    scenari.append(s)
                }
                v.scenari = scenari
                return MotoreValutazione.calcola(v, condizioni: c).scenario(.intermedio)
            }
            if let s = esito(lordo: 3), s.riscatti.count == 2 {
                verifica("Valutazione: netto al 2° anno", s.riscatti[0].netto, 9_996)
                verifica("Valutazione: netto al 3° anno", s.riscatti[1].netto, 10_221.9704)
                verifica("Valutazione: RIY al 2° anno", s.riscatti[0].incidenzaCosti ?? 0, 3.04, tolleranza: 0.000_1)
                verifica("Valutazione: RIY al 3° anno", s.riscatti[1].incidenzaCosti ?? 0, 1.5113, tolleranza: 0.000_1)
                verifica("Valutazione: primo recupero del premio al 3° anno", Double(s.primoRecuperoPremio?.anno ?? -1), 3)
                verifica.vero("Valutazione: con 12 mesi di blocco il 2° anno è riscattabile", s.riscatti[0].possibile)
            } else {
                verifica.vero("Valutazione: due riscatti simulati", false)
            }
            // 24 mesi di blocco: il riscatto all'inizio del 2° anno non si può chiedere
            let bloccata = esito(lordo: 3, blocco: 24)
            verifica.vero("Valutazione: 24 mesi di blocco, 2° anno non riscattabile", bloccata?.riscatti.first?.possibile == false)
            verifica("Valutazione: primo riscatto possibile al 3° anno", Double(bloccata?.primoPossibile?.anno ?? -1), 3)
            // Pavimento: lordo 3 − 1 = 2%, minimo garantito 2,5% con consolidamento → 10.250 € dopo un anno;
            // senza consolidamento indicato nessun pavimento (come prima) → 10.200 €
            let conMinimo = esito(lordo: 3, { $0.minimoGarantito = 2.5; $0.consolidamento = true })
            verifica("Valutazione: minimo garantito con consolidamento", conMinimo?.riscatti.first?.valore ?? 0, 10_250)
            let minimoSolo = esito(lordo: 3, { $0.minimoGarantito = 2.5 })
            verifica("Valutazione: minimo senza consolidamento, nessun pavimento", minimoSolo?.riscatti.first?.valore ?? 0, 10_200)
            // Lordo −1 − 1 = −2%: con il consolidamento il capitale non scende (10.000), senza scende a 9.800
            let consolidata = esito(lordo: -1, { $0.consolidamento = true })
            verifica("Valutazione: consolidamento, il capitale non scende", consolidata?.riscatti.first?.valore ?? 0, 10_000)
            let senzaDati = esito(lordo: -1)
            verifica("Valutazione: senza dati, la gestione può scendere (come prima)", senzaDati?.riscatti.first?.valore ?? 0, 9_800)
            // Retrocessione del 90% su un lordo del 3% con trattenuto minimo 1: min(2,7; 2) = 2% → 10.200 €
            let retrocessione90 = esito(lordo: 3, { $0.retrocessione = 90 })
            verifica("Valutazione: retrocessione con trattenuto minimo", retrocessione90?.riscatti.first?.valore ?? 0, 10_200)
            // Retrocessione dell'80% senza trattenuto: 2,4% → 10.240 €, trattenuto in euro 0,6% di 10.000 = 60 €
            let retro = esito(lordo: 3, { $0.retrocessione = 80; $0.trattenuto = 0 })
            verifica("Valutazione: retrocessione dell'80%", retro?.riscatti.first?.valore ?? 0, 10_240)
            verifica("Valutazione: trattenuto in euro con la retrocessione", retro?.costi.first?.trattenuto ?? 0, 60)
        }

        // R18. Gestione separata: rendimento al cliente, minimo, consolidamento, reale
        do {
            verifica("GS: lordo 3 − trattenuto 1,2", MotoreGestioneSeparata.netto(lordo: 3, trattenuto: 1.2, retrocessione: nil), 1.8, tolleranza: 0.000_1)
            verifica("GS: retrocessione dell'80% di 3", MotoreGestioneSeparata.netto(lordo: 3, trattenuto: nil, retrocessione: 80), 2.4, tolleranza: 0.000_1)
            verifica("GS: retrocessione con trattenuto minimo 1", MotoreGestioneSeparata.netto(lordo: 3, trattenuto: 1, retrocessione: 80), 2, tolleranza: 0.000_1)
            verifica("GS: lordo negativo, la retrocessione non attenua", MotoreGestioneSeparata.netto(lordo: -1, trattenuto: nil, retrocessione: 80), -1, tolleranza: 0.000_1)
            verifica("GS: minimo 1% con consolidamento", MotoreGestioneSeparata.accreditato(lordo: 1.5, trattenuto: 1, retrocessione: nil, minimo: 1, consolidamento: true), 1, tolleranza: 0.000_1)
            verifica("GS: minimo senza consolidamento non vale ogni anno", MotoreGestioneSeparata.accreditato(lordo: 1.5, trattenuto: 1, retrocessione: nil, minimo: 1, consolidamento: false), 0.5, tolleranza: 0.000_1)
            // Reale: (1,025 / 1,02 − 1) × 100 = 0,4902
            verifica("GS: rendimento reale con inflazione al 2%", MotoreGestioneSeparata.reale(2.5, inflazione: 2), 0.4902, tolleranza: 0.000_1)
            // Polizza di Sofia: 2,5 − 1,3 = 1,2% > minimo 1% (non decide); reale (1,012/1,02 − 1) = −0,7843%;
            // trattenuto 1,3% di 41.000 = 533 €
            if let sofia = DatiDemo.posizioni().first(where: { $0.id == "pos-sofia-polizza-rivalutabile" }),
               let g = MotoreGestioneSeparata.calcola(sofia) {
                verifica("GS di Sofia: accreditato", g.accreditato, 1.2, tolleranza: 0.000_1)
                verifica.vero("GS di Sofia: il minimo non decide", !g.minimoDecisivo)
                verifica("GS di Sofia: rendimento reale", g.reale, -0.7843, tolleranza: 0.000_1)
                verifica("GS di Sofia: trattenuto in euro", g.trattenutoEuro, 533, tolleranza: 0.01)
            } else {
                verifica.vero("GS di Sofia calcolata", false)
            }
            // Senza retrocessione il costo annuo della proiezione resta il trattenuto indicato (come prima)
            if let piano = DatiDemo.posizioni().first(where: { $0.id == "pos-giulia-piano-di-risparmio-rivalutabile" }) {
                verifica("GS di Giulia: costo annuo della proiezione invariato", ParametriProiezione(posizione: piano).costoAnnuo, 1.2, tolleranza: 0.000_000_1)
            }
            var testo = AiutiProva.posizione("Rivalutabile", .risparmio, 10_000) { $0.tipologia = "Polizza rivalutabile (Ramo I)" }
            testo.consolidamento = false
            verifica.vero("GS: il testo dice la garanzia vera", TestiCosti.inCambio(testo).contains("a scadenza"))
        }

        // R19. Proiezione con minimo garantito: 10.000 € al 1% lordo con trattenuto 1,2 (netto negativo) per 5 anni.
        // Minimo 1% consolidato → 10.000 × 1,01^5 = 10.510,10 €; senza minimo il capitale non scende → 10.000 €.
        // Senza consolidamento (lordo 0, trattenuto 1, scadenza tra 5 anni): il valore scende (dopo 4 anni
        // 10.000 × 0,99^4 = 9.605,96) e alla scadenza torna al garantito, 10.000 € (o 10.000 × 1,005^5 = 10.252,51 con il minimo 0,5%)
        do {
            let base = AiutiProva.posizione("Rivalutabile", .risparmio, 0) {
                $0.stato = .proposta; $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.versamentoIniziale = 10_000
                $0.rendimentoAtteso = 1; $0.trattenuto = 1.2; $0.minimoGarantito = 1; $0.consolidamento = true
            }
            var par = ParametriProiezione(posizione: base)
            par.anni = 5
            verifica("Proiezione GS: minimo garantito consolidato", MotoreProiezione.calcola(par).lordo, 10_510.100501, tolleranza: 0.01)
            var senzaMinimo = base
            senzaMinimo.minimoGarantito = nil
            var parSenza = ParametriProiezione(posizione: senzaMinimo)
            parSenza.anni = 5
            verifica("Proiezione GS: senza minimo il capitale non scende", MotoreProiezione.calcola(parSenza).lordo, 10_000, tolleranza: 0.01)

            var scadenza = base
            scadenza.rendimentoAtteso = 0
            scadenza.trattenuto = 1
            scadenza.minimoGarantito = 0
            scadenza.consolidamento = false
            scadenza.scadenza = Calendar.current.date(byAdding: .year, value: 5, to: Date())
            let e = MotoreProiezione.calcola(ParametriProiezione(posizione: scadenza))
            verifica("Proiezione GS senza consolidamento: anni fino alla scadenza", Double(e.punti.count), 6)
            verifica("Proiezione GS senza consolidamento: il valore scende prima", e.punti.count > 4 ? e.punti[4].valore : 0, 9_605.9601, tolleranza: 0.01)
            verifica("Proiezione GS senza consolidamento: alla scadenza il garantito", e.lordo, 10_000, tolleranza: 0.01)
            scadenza.minimoGarantito = 0.5
            verifica("Proiezione GS senza consolidamento: garantito con il minimo", MotoreProiezione.calcola(ParametriProiezione(posizione: scadenza)).lordo, 10_252.512531, tolleranza: 0.01)
            verifica("GS: garantito a scadenza (10.000 × 1,005^5)", MotoreGestioneSeparata.garantitoAScadenza(scadenza) ?? 0, 10_252.512531, tolleranza: 0.01)
        }
    }
}
