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

        if errori == 0 {
            print("OK: motori di calcolo verificati")
            return 0
        }
        print("ERRORE: \(errori) verifiche non riuscite")
        return 1
    }
}
