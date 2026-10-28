import Foundation

/// Prove delle multiramo a due parti nei motori di rischio (resistenza, crisi storiche, coerenza, Monte
/// Carlo): M6, M7, M9. Chiamate da `ProvaCalcoliMultiramo.esegui`: gli errori si sommano. (Gruppo C.)
/// Valori attesi della specifica del giro 2, calcolati a parte con la replica in Python del motore mensile.
/// Le posizioni si costruiscono qui: nessuna prova legge le posizioni dei dati di prova.
enum ProvaCalcoliMultiramoRischio {
    static func esegui(_ verifica: VerificaCalcoli) {
        monteCarlo(verifica)
        resistenza(verifica)
        coerenza(verifica)
    }

    /// Una multiramo di prova in essere (investimento, «Polizza multiramo»).
    private static func multiramo(_ valore: Double, _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        AiutiProva.posizione("Multiramo", .investimento, valore) {
            $0.tipologia = "Polizza multiramo"
            modifica(&$0)
        }
    }

    // MARK: - M6. Monte Carlo con volatilità zero = proiezione

    private static func monteCarlo(_ verifica: VerificaCalcoli) {
        // I dati di M1 su una posizione in essere: 50.000 €, 60% in gestione separata al 2,8% lordo con
        // trattenuto 1,2 (accreditato 1,6%), 40% nei fondi al 5% con costi del 2% e bollo dello 0,2%.
        // Volatilità zero: ogni percorso è la proiezione, netto 58.318,34 come M1 (aliquota 26% su tutte e due).
        let base: (inout Posizione) -> Void = {
            $0.totaleVersato = 50_000
            $0.quotaGestioneSeparata = 60
            $0.rendimentoGestione = 2.8
            $0.trattenuto = 1.2
            $0.minimoGarantito = 0
            $0.consolidamento = true
            $0.rendimentoFondi = 5
            $0.costoFondi = 2
            $0.volatilitaFondi = 0
        }
        let p = multiramo(50_000, base)
        verifica.vero("M6 La posizione è a due parti", p.multiramoDivisa)
        let l = MotoreMonteCarlo.linea(p, rendimentoPredefinito: 3, mesi: 120, data: AiutiProva.oggi)
        verifica("M6 Linea: rendimento lordo dei fondi", l.rendimento, 5, tolleranza: 0.0001)
        verifica("M6 Linea: costi dei fondi più il bollo", l.costoAnnuo, 2.2, tolleranza: 0.0001)
        verifica("M6 Linea: volatilità dei fondi", l.volatilita, 0, tolleranza: 0.0001)
        verifica.vero("M6 Linea: nessuna garanzia sui fondi", !l.capitaleGarantito)
        verifica("M6 Linea: 60% in gestione separata", l.gestione?.quota ?? -1, 0.6, tolleranza: 0.0001)
        verifica("M6 Linea: accreditato della gestione 2,8 − 1,2", l.gestione?.accreditato ?? -1, 1.6, tolleranza: 0.0001)
        verifica.vero("M6 Linea: nessun ribilanciamento se non indicato", l.gestione?.ribilanciamento == false)
        if case let .guadagno(aliquota, versato) = l.imposta {
            verifica("M6 Linea: un'imposta sola sul guadagno, al 26%", aliquota, 26, tolleranza: 0.0001)
            verifica("M6 Linea: guadagno oltre i 50.000 € versati", versato, 50_000)
        } else {
            verifica.vero("M6 Linea: imposta sul guadagno", false)
        }

        let e = MotoreMonteCarlo.simula([l], mesi: 120, traguardo: 0, traiettorie: 50, seme: 1)
        verifica("M6 Volatilità zero: mediano = netto della proiezione (M1)", e.p50, 58_318.34, tolleranza: 0.05)
        verifica("M6 Volatilità zero: sfavorevole = mediano", e.p10, 58_318.34, tolleranza: 0.05)
        verifica("M6 Volatilità zero: favorevole = mediano", e.p90, 58_318.34, tolleranza: 0.05)
        verifica("M6 Volatilità zero: lordo all'anno 10 (35.160,77 + 26.080,24)", e.anni.last?.p50 ?? -1, 61_241.00, tolleranza: 0.05)
        verifica("M6 Volatilità zero: lordo all'anno 1 (30.480 + 20.538)", e.anni.first { $0.anno == 1 }?.p50 ?? -1, 51_018.00, tolleranza: 0.05)
        verifica("M6 Volatilità zero: tutti i percorsi raggiungono il traguardo zero", e.probabilita, 1, tolleranza: 0.0001)

        // Ribilanciamento annuo: come M4, fattore 0,6 × 1,016 + 0,4 × 1,0269 ogni anno → 61.165,18, netto 58.262,23
        var ribilanciata = p
        ribilanciata.ribilanciamento = true
        let lr = MotoreMonteCarlo.linea(ribilanciata, rendimentoPredefinito: 3, mesi: 120, data: AiutiProva.oggi)
        verifica.vero("M6 Linea: ribilanciamento indicato", lr.gestione?.ribilanciamento == true)
        let er = MotoreMonteCarlo.simula([lr], mesi: 120, traguardo: 0, traiettorie: 50, seme: 1)
        verifica("M6 Ribilanciamento: lordo all'anno 10 come M4", er.anni.last?.p50 ?? -1, 61_165.18, tolleranza: 0.05)
        verifica("M6 Ribilanciamento: netto come M4", er.p50, 58_262.23, tolleranza: 0.05)

        // Con la volatilità dei fondi: la gestione separata non scende e i fondi non vanno sotto zero,
        // quindi anche lo scenario sfavorevole resta sopra 30.000 × 1,016^10 = 35.160,77.
        var volatile = p
        volatile.volatilitaFondi = 14
        let ev = MotoreMonteCarlo.simula([MotoreMonteCarlo.linea(volatile, rendimentoPredefinito: 3, mesi: 120, data: AiutiProva.oggi)],
                                         mesi: 120, traguardo: 0, traiettorie: 50, seme: 1)
        verifica.vero("M6 Volatilità 14%: sfavorevole < mediano < favorevole", ev.p10 < ev.p50 && ev.p50 < ev.p90)
        verifica.vero("M6 Volatilità 14%: lo sfavorevole non scende sotto la gestione separata (35.160,77)", ev.p10 >= 35_160.77)
        verifica("M6 Volatilità per le schede: quella della combinazione 0,4 × 14", MotoreMonteCarlo.volatilita(volatile), 5.6, tolleranza: 0.0001)

        // Compatibilità: una multiramo senza dati separati resta una linea sola, come prima
        let unica = multiramo(50_000) { $0.quotaGestioneSeparata = 40; $0.rendimentoAtteso = 4; $0.costoAnnuo = 1.8; $0.sri = 3 }
        let lu = MotoreMonteCarlo.linea(unica, rendimentoPredefinito: 3, mesi: 120, data: AiutiProva.oggi)
        verifica.vero("M6 Multiramo senza dati separati: nessuna gestione nella linea", !unica.multiramoDivisa && lu.gestione == nil)
        verifica("M6 Multiramo senza dati separati: rendimento complessivo", lu.rendimento, 4, tolleranza: 0.0001)
        verifica("M6 Multiramo senza dati separati: volatilità dall'SRI sulla parte esposta (8,5 × 0,6)", lu.volatilita, 8.5 * 0.6, tolleranza: 0.0001)
    }

    // MARK: - M7. Resistenza e crisi sulla sola parte in fondi

    private static func resistenza(_ verifica: VerificaCalcoli) {
        // a) 100.000 €, 40% in gestione separata, fondi SRI 4 (calo del 20%) → 100.000 × 0,6 × 20% = 12.000 €
        do {
            let a = multiramo(100_000) { $0.quotaGestioneSeparata = 40; $0.sriFondi = 4; $0.rendimentoFondi = 5 }
            let r = MotoreResistenza.calcola([a], profilo: nil)
            let voce = r.scenario(.mercati)?.voci.first
            verifica("M7a Mercati: perde solo la parte in fondi, SRI 4", voce?.perdita ?? -1, 12_000)
            verifica("M7a Quota protetta: la gestione separata", r.quotaProtetta, 0.4, tolleranza: 0.0001)
            let motivo = voce?.motivo ?? ""
            verifica.vero("M7a Il motivo dice l'SRI dei fondi e la gestione separata garantita",
                          motivo.contains("SRI 4 su 7") && motivo.contains("garantita") && !motivo.contains("(stimato)"))

            // d) Senza consolidamento: stessa perdita, ma la gestione separata non è detta garantita [R6]
            var d = a
            d.consolidamento = false
            let vd = MotoreResistenza.calcola([d], profilo: nil).scenario(.mercati)?.voci.first
            verifica("M7d Senza consolidamento: perdita sempre 12.000 €", vd?.perdita ?? -1, 12_000)
            verifica.vero("M7d Senza consolidamento: il motivo non dice «garantita»",
                          vd.map { !$0.motivo.contains("garantita") } == true)
        }

        // b) Senza SRI dei fondi, con l'SRI 3 del KID della combinazione: σ fondi = 8,5 / 0,6 = 14,17 → classe 4
        // → 12.000 €. Senza dati separati la stessa posizione perde 100.000 × 0,6 × 10% = 6.000 € (doppio sconto).
        do {
            let b = multiramo(100_000) { $0.quotaGestioneSeparata = 40; $0.sri = 3; $0.rendimentoFondi = 5 }
            let vb = MotoreResistenza.calcola([b], profilo: nil).scenario(.mercati)?.voci.first
            verifica("M7b SRI dei fondi stimato dalla combinazione: classe 4, 12.000 €", vb?.perdita ?? -1, 12_000)
            verifica.vero("M7b Il motivo dice che l'SRI dei fondi è stimato", vb?.motivo.contains("(stimato)") == true)
            let oggi = multiramo(100_000) { $0.quotaGestioneSeparata = 40; $0.sri = 3 }
            verifica.vero("M7b Senza dati separati la posizione non è divisa", !oggi.multiramoDivisa)
            verifica("M7b Senza dati separati: come prima, 6.000 €",
                     MotoreResistenza.calcola([oggi], profilo: nil).scenario(.mercati)?.perdita ?? -1, 6_000)
        }

        // Quota in gestione separata non indicata: stimata al 50%, detto nel motivo e nella composizione
        do {
            let s = multiramo(100_000) { $0.sriFondi = 4; $0.rendimentoFondi = 5; $0.quotaAzionariaFondi = 60 }
            let vs = MotoreResistenza.calcola([s], profilo: nil).scenario(.mercati)?.voci.first
            verifica("M7 Quota non indicata: 100.000 × 0,5 × 20%", vs?.perdita ?? -1, 10_000)
            verifica.vero("M7 Quota non indicata: il motivo la dice stimata", vs?.motivo.contains("in gestione separata (stimato)") == true)
            verifica.vero("M7 Quota non indicata: composizione stimata", MotoreResistenza.composizione(s)?.stimata == true)
        }

        // Inflazione alta: rende l'accreditato della GS e il netto dei fondi, pesati sulle quote:
        // 0,4 × (3,0 − 1,3) + 0,6 × (5,5 − 2,3) = 2,60% → 100.000 × (1 − (1,026 / 1,05)^3) = 6.701,60 €
        do {
            let i = multiramo(100_000) {
                $0.quotaGestioneSeparata = 40; $0.rendimentoGestione = 3; $0.trattenuto = 1.3; $0.minimoGarantito = 0
                $0.consolidamento = true; $0.rendimentoFondi = 5.5; $0.costoFondi = 2.3; $0.costoAnnuo = 1.8; $0.rendimentoAtteso = 4.5
            }
            let vi = MotoreResistenza.calcola([i], profilo: nil).scenario(.inflazione)?.voci.first
            verifica("M7 Inflazione alta: netto composto 2,60%", vi?.perdita ?? -1, 6_701.60)
        }

        // c) Crisi su 50.000 €, 60% in gestione separata, fondi con il 60% in azioni:
        // azioni 0,4 × 0,6 = 0,24; governativi e societarie 0,4 × 0,4 × 0,5 = 0,08; gestione separata 0,60.
        do {
            let c = multiramo(50_000) { $0.quotaGestioneSeparata = 60; $0.quotaAzionariaFondi = 60; $0.rendimentoFondi = 5 }
            let k = MotoreResistenza.composizione(c)
            verifica("M7c Composizione: azioni", k?.azioni ?? -1, 0.24, tolleranza: 0.0001)
            verifica("M7c Composizione: titoli di Stato", k?.governativi ?? -1, 0.08, tolleranza: 0.0001)
            verifica("M7c Composizione: obbligazioni societarie", k?.societarie ?? -1, 0.08, tolleranza: 0.0001)
            verifica("M7c Composizione: gestione separata", k?.gestioneSeparata ?? -1, 0.60, tolleranza: 0.0001)
            let somma = (k?.azioni ?? 0) + (k?.governativi ?? 0) + (k?.societarie ?? 0) + (k?.liquidita ?? 0)
                + (k?.gestioneSeparata ?? 0) + (k?.immobili ?? 0)
            verifica("M7c Composizione: la somma fa 1", somma, 1, tolleranza: 0.0001)
            verifica.vero("M7c Composizione: quota azionaria dei fondi indicata, non stimata", k?.stimata == false)

            let crisi = MotoreResistenza.crisi([c], profilo: nil)
            func perdita(_ anno: Int) -> Double { crisi.first { $0.crisi.anno == anno }?.perdita ?? -1 }
            // 2008: 50.000 × (0,24 × 37 − 0,08 × 4 + 0,08 × 4)%; 2020: (0,24 × 33 + 0,08 × 4 + 0,08 × 7)%;
            // 2022: (0,24 × 13 + 0,08 × 17 + 0,08 × 14)%
            verifica("M7c Crisi 2008: 4.440 €", perdita(2008), 4_440)
            verifica("M7c Crisi 2020: 4.400 €", perdita(2020), 4_400)
            verifica("M7c Crisi 2022: 2.800 €", perdita(2022), 2_800)

            // d) I titoli di Stato del contratto non entrano tra i governativi dei fondi [R5]
            var conTitoli = c
            conTitoli.quotaTitoliStato = 70
            verifica("M7d Titoli di Stato del contratto: governativi dei fondi sempre 0,08",
                     MotoreResistenza.composizione(conTitoli)?.governativi ?? -1, 0.08, tolleranza: 0.0001)
            // Con i titoli di Stato dei fondi (50% della parte, oltre la sua parte obbligazionaria del 40%):
            // tutte governative, 0,4 × 0,4 = 0,16
            var titoliFondi = c
            titoliFondi.titoliStatoFondi = 50
            verifica("M7d Titoli di Stato dei fondi: governativi 0,4 × min(50%, 40%)",
                     MotoreResistenza.composizione(titoliFondi)?.governativi ?? -1, 0.16, tolleranza: 0.0001)
        }
    }

    // MARK: - M9. SRI della combinazione

    private static func coerenza(_ verifica: VerificaCalcoli) {
        // Classi di rischio di mercato del Regolamento delegato 2017/653: 0,6 × 16 = 9,6 → 3; 0,7 × 25 = 17,5 → 4
        verifica("M9 Classe di 9,6%", Double(MotoreMultiramo.classeSRI(volatilita: 9.6)), 3)
        verifica("M9 Classe di 17,5%", Double(MotoreMultiramo.classeSRI(volatilita: 17.5)), 4)
        verifica("M9 Classe di 12% (la soglia va alla classe sopra)", Double(MotoreMultiramo.classeSRI(volatilita: 12)), 4)
        verifica("M9 Classe di 4,99%", Double(MotoreMultiramo.classeSRI(volatilita: 4.99)), 2)

        // 40% in gestione separata, fondi SRI 4 (σ 16%), senza SRI del KID: σ composta 0,6 × 16 = 9,6 → 3
        let p = multiramo(100_000) { $0.quotaGestioneSeparata = 40; $0.sriFondi = 4; $0.quotaAzionariaFondi = 58 }
        verifica.vero("M9 La posizione è a due parti", p.multiramoDivisa)
        verifica("M9 Volatilità composta 0,6 × 16", p.volatilitaComposta, 9.6, tolleranza: 0.0001)
        verifica("M9 SRI della combinazione stimato", Double(p.sriComposto), 3)
        var conKID = p
        conKID.sri = 5
        verifica("M9 Con l'SRI del KID vale il KID", Double(conKID.sriComposto), 5)

        verifica("M9 Coerenza: SRI per la media = quello della combinazione", Double(MotoreCoerenza.sriStimato(p)), 3)
        verifica("M9 Coerenza: con il KID", Double(MotoreCoerenza.sriStimato(conKID)), 5)
        let m = MotoreCoerenza.misure([p], profilo: nil)
        verifica("M9 Coerenza: SRI medio del portafoglio", m.sriMedio ?? -1, 3, tolleranza: 0.0001)
        verifica("M9 Coerenza: azioni 0,6 × 0,58", m.quotaAzionaria ?? -1, 0.348, tolleranza: 0.0001)

        // Proposte: conta la combinazione. Fondi SRI 6 con la combinazione SRI 3 (KID) per un profilo moderato
        // (fino a 3): nessuna incoerenza. Senza il KID la combinazione si stima: σ 0,6 × 35 = 21 → 5, oltre.
        guard var cliente = DatiPrisma.demo().clienti.first else {
            verifica.vero("M9 Un cliente nei dati di prova", false)
            return
        }
        cliente.profilo = ProfiloInvestitore()
        cliente.profilo.propensione = .moderata
        func proposta(_ modifica: (inout Posizione) -> Void) -> Posizione {
            var q = multiramo(0) {
                $0.quotaGestioneSeparata = 40
                $0.sriFondi = 6
                $0.rendimentoFondi = 5
                $0.versamentoIniziale = 20_000
                modifica(&$0)
            }
            q.controvalore = nil
            q.stato = .proposta
            q.esito = .presentata
            return q
        }
        let conto = AiutiProva.posizione("Conto", .liquidita, 50_000)
        let dentro = proposta { $0.sri = 3 }
        let eDentro = MotoreCoerenza.calcola(cliente: cliente, posizioni: [conto, dentro])
        verifica.vero("M9 Proposta: fondi SRI 6 ma combinazione SRI 3, dentro il profilo moderato",
                      !eDentro.incoerenze.contains { $0.tipo == .proposta })
        let oltre = proposta { $0.sri = nil }
        let eOltre = MotoreCoerenza.calcola(cliente: cliente, posizioni: [conto, oltre])
        verifica("M9 Proposta: combinazione stimata SRI 5, oltre il profilo",
                 eOltre.incoerenze.first { $0.tipo == .proposta }?.valore ?? -1, 5)
    }
}
