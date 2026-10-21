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

        if errori == 0 {
            print("OK: motori di calcolo verificati")
            return 0
        }
        print("ERRORE: \(errori) verifiche non riuscite")
        return 1
    }
}
