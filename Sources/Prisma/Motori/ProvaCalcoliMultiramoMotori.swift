import Foundation

/// Prove delle multiramo a due parti nei motori a valle (fiscale, riscatto, costi, sostituzione, obiettivo,
/// andamento, importazione, Analisi 360): M5 sulla posizione, M8, M8b, M12 `areaDal`, M14, più le verifiche
/// dei singoli motori (M19–M24). Chiamate da `ProvaCalcoliMultiramo.esegui`: gli errori si sommano. (Gruppo B.)
/// Valori attesi calcolati a parte con la replica in Python del motore mensile a due parti.
enum ProvaCalcoliMultiramoMotori {
    static func esegui(_ verifica: VerificaCalcoli) {
        fiscale(verifica)
        costi(verifica)
        riscatto(verifica)
        sostituzioneEObiettivo(verifica)
        andamentoEAnalisi(verifica)
        importazione(verifica)
    }

    /// Una multiramo con i numeri di Marco: 62.000 € in essere (versati 62.000 €), 40% in gestione separata
    /// al 3,0% lordo con trattenuto 1,3 e minimo 0 consolidato; 60% nei fondi al 5,5% lordo con costi del 2,3%.
    private static func marco(_ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        AiutiProva.posizione("Marco multiramo", .investimento, 62_000) {
            $0.tipologia = "Polizza multiramo (Ramo I e Ramo III)"
            $0.totaleVersato = 62_000
            $0.quotaGestioneSeparata = 40
            $0.rendimentoGestione = 3.0
            $0.trattenuto = 1.3
            $0.minimoGarantito = 0
            $0.consolidamento = true
            $0.rendimentoFondi = 5.5
            $0.costoFondi = 2.3
            modifica(&$0)
        }
    }

    // MARK: - M5, M8, M8b: fiscale

    private static func fiscale(_ verifica: VerificaCalcoli) {
        // M5 sulla posizione: aliquota pesata sulle quote di oggi, 0,4 × 17,9 + 0,6 × 24,65
        do {
            let p = AiutiProva.posizione("M", .investimento, 62_000) {
                $0.tipologia = "Polizza multiramo"
                $0.quotaGestioneSeparata = 40
                $0.rendimentoGestione = 3
                $0.titoliStatoGestione = 60
                $0.titoliStatoFondi = 10
            }
            verifica("M5 Posizione: aliquota sul guadagno pesata 0,4 × 17,9 + 0,6 × 24,65",
                     MotoreFiscale.aliquotaGuadagno(p), 21.95, tolleranza: 0.0001)
            let f = MotoreFiscale.calcola(p)
            verifica("M5 Fiscale: aliquota applicata", f.aliquota, 21.95, tolleranza: 0.0001)
            verifica.vero("M5 Fiscale: la nota dice l'aliquota pesata sulle due parti",
                          f.note.contains { $0.hasPrefix("Aliquota pesata sulle due parti") && $0.contains("titoli di Stato 60%") })
            // Senza dati separati: l'aliquota di sempre
            let vecchia = AiutiProva.posizione("M", .investimento, 62_000) {
                $0.tipologia = "Polizza multiramo"; $0.quotaGestioneSeparata = 40; $0.aliquotaFiscale = 24
            }
            verifica("M5 Senza dati separati: aliquota indicata", MotoreFiscale.aliquotaGuadagno(vecchia), 24, tolleranza: 0.0001)
        }

        // M8. Costi di un anno per parte: fondi 37.200 × 2,3%, trattenuto 24.800 × 1,3%, bollo 37.200 × 0,2%
        do {
            let p = marco()
            let f = MotoreFiscale.calcola(p)
            verifica("M8 Costi dei fondi sulla parte in fondi 37.200 × 2,3%", f.costoGestione, 855.60)
            verifica("M8 Trattenuto sulla parte in gestione separata 24.800 × 1,3%", f.costoTrattenuto, 322.40)
            verifica("M8 Bollo sulla sola parte in fondi 37.200 × 0,2%", f.costoBollo, 74.40)
            verifica("M8 Costo complessivo 0,4 × 1,3 + 0,6 × 2,3", p.costoComplessivo ?? -1, 1.90, tolleranza: 0.0001)
            verifica("M8 Rendimento netto composto 0,4 × 1,7 + 0,6 × 3,2", p.rendimentoNettoComposto, 2.60, tolleranza: 0.0001)
            verifica("M8 Aliquota senza titoli di Stato: 26%", f.aliquota, 26, tolleranza: 0.0001)

            // Quota non indicata, con la decorrenza (bollo maturato): la stima del 50% dichiarata
            let stimata = marco { $0.quotaGestioneSeparata = nil; $0.decorrenza = AiutiProva.data(2023, 1, 1) }
            let fs = MotoreFiscale.calcola(stimata, data: AiutiProva.data(2026, 1, 1))
            verifica.vero("M8 Quota non indicata: la nota dice la stima del 50%",
                          fs.note.contains { $0.contains("stimata al 50%") })
            verifica("M8 Quota non indicata: bollo sulla metà stimata 31.000 × 0,2%", fs.costoBollo, 62.00)
        }

        // M8b. Ramo I puro con la sola retrocessione: 10.000 × (3 − 3 × 80%) = 60 € (prima 0)
        do {
            let p = AiutiProva.posizione("Ramo I", .risparmio, 10_000) {
                $0.tipologia = "Polizza rivalutabile Ramo I"
                $0.rendimentoAtteso = 3
                $0.retrocessione = 80
            }
            verifica.vero("M8b Ramo I puro: gestione separata", p.gestioneSeparata && !p.multiramo)
            verifica("M8b Trattenuto dalla sola retrocessione", MotoreFiscale.calcola(p).costoTrattenuto, 60.00)
            // Con il solo trattenuto: come prima
            let t = AiutiProva.posizione("Ramo I", .risparmio, 10_000) {
                $0.tipologia = "Polizza rivalutabile Ramo I"; $0.rendimentoAtteso = 3; $0.trattenuto = 1.2
            }
            verifica("M8b Ramo I con il trattenuto: come prima", MotoreFiscale.calcola(t).costoTrattenuto, 120.00)
        }
    }

    // MARK: - M14, M19, M20: costi e incidenza come nel KID

    private static func costi(_ verifica: VerificaCalcoli) {
        // M14. Multiramo divisa senza nessun costo indicato: costo complessivo nil, tra le posizioni senza dati
        do {
            let p = AiutiProva.posizione("Senza costi", .investimento, 30_000) {
                $0.tipologia = "Polizza multiramo"; $0.quotaGestioneSeparata = 40; $0.rendimentoGestione = 3
            }
            verifica.vero("M14 Divisa senza costi: costo complessivo non indicato", p.multiramoDivisa && p.costoComplessivo == nil)
            let a = MotoreCosti.calcola([p])
            verifica.vero("M14 Divisa senza costi: tra le posizioni senza costi indicati",
                          a.senzaDati.map(\.id) == [p.id] && a.voci.isEmpty)
        }

        // M19. Peso dei costi per parte: 62.000 × 1,90% quest'anno; in 10 anni senza trattenuto e costi dei
        // fondi (resta il bollo) 86.873,34 netti contro 74.346,07
        do {
            let p = marco()
            let v = MotoreCosti.voce(p, prodotti: [], cliente: "prova")
            verifica("M19 Costi: annuo composto", v.annuo, 1.90, tolleranza: 0.0001)
            verifica("M19 Costi: quest'anno 62.000 × 1,90%", v.euroAnno, 1_178.00)
            verifica("M19 Costi: in 10 anni tolgono 86.873,34 − 74.346,07", v.perso10, 12_527.26, tolleranza: 0.05)
            verifica("M19 Costi: in 20 anni", v.perso20, 36_195.38, tolleranza: 0.05)
            let s = MotoreCosti.serie(AnalisiCosti(voci: [v], senzaDati: []), durata: 10)
            verifica("M19 Serie: con i costi all'anno 10 (prima delle imposte)", s.con.last ?? -1, 78_683.88)
            verifica.vero("M19 Serie: senza i costi del prodotto lascia di più", (s.senza.last ?? 0) > (s.con.last ?? 0))

            // Incidenza come nel KID: senza costi 4,5636% l'anno, con i costi (senza bollo) 2,5438%
            if let k = MotoreCosti.incidenzaKID(p) {
                verifica("M19 RIY: periodo raccomandato 10 anni", Double(k.periodoRaccomandato), 10)
                verifica("M19 RIY a 1 anno", k.periodi.first?.riy ?? -1, 1.9759, tolleranza: 0.0001)
                verifica("M19 RIY a 10 anni: 4,5636 − 2,5438", k.calcolato ?? -1, 2.0198, tolleranza: 0.0001)
                verifica("M19 RIY: senza costi la gestione separata rende il lordo", k.periodi.first?.senzaCosti ?? -1, 4.5, tolleranza: 0.0001)
            } else {
                verifica.vero("M19 RIY: calcolato", false)
            }
        }

        // M20. Alternativa più economica: una multiramo solo con un'altra multiramo, con la stessa quota
        do {
            let p = marco { $0.sri = 3 }
            func scheda(_ nome: String, _ modifica: (inout Prodotto) -> Void) -> Prodotto {
                var x = Prodotto(nome: nome, canale: .indipendente, area: .investimento)
                x.id = "prodotto-" + nome.lowercased().replacingOccurrences(of: " ", with: "-")
                x.sri = 3
                modifica(&x)
                return x
            }
            func multiramo(_ nome: String, _ modifica: (inout Prodotto) -> Void = { _ in }) -> Prodotto {
                scheda(nome) {
                    $0.tipologia = "Polizza multiramo"; $0.costoAnnuo = 1.2
                    $0.trattenuto = 0.8; $0.minimoGarantito = 0; $0.consolidamento = true; $0.costoFondi = 1.2
                    modifica(&$0)
                }
            }
            let fondo = scheda("Fondo economico") { $0.tipologia = "Fondo comune"; $0.costoAnnuo = 0.5 }
            let conLimiti = multiramo("Multiramo leggera") { $0.quotaGestioneMinima = 30; $0.quotaGestioneMassima = 70 }
            let senzaQuota = multiramo("Multiramo senza quota")
            let vicina = multiramo("Multiramo vicina") { $0.quotaGestioneSeparata = 45 }
            let lontana = multiramo("Multiramo lontana") { $0.quotaGestioneSeparata = 60 }

            let a = MotoreCosti.alternativa(p, prodotti: [fondo, conLimiti], cliente: "prova")
            verifica.vero("M20 Alternativa: la multiramo ammessa, non il fondo", a?.prodotto.id == conLimiti.id)
            verifica("M20 Alternativa: costo composto sulla stessa quota 0,4 × 0,8 + 0,6 × 1,2", a?.costoAnnuo ?? -1, 1.04, tolleranza: 0.0001)
            verifica.vero("M20 Alternativa: lascia di più, uscita compresa", (a?.guadagno ?? 0) >= MotoreCosti.guadagnoMinimo)
            verifica.vero("M20 Alternativa: un fondo non sostituisce una multiramo",
                          MotoreCosti.alternativa(p, prodotti: [fondo], cliente: "prova") == nil)
            verifica.vero("M20 Alternativa: una scheda senza quota si scarta",
                          MotoreCosti.alternativa(p, prodotti: [senzaQuota], cliente: "prova") == nil)
            verifica.vero("M20 Alternativa: quota della scheda entro 10 punti",
                          MotoreCosti.alternativa(p, prodotti: [vicina], cliente: "prova")?.prodotto.id == vicina.id)
            verifica.vero("M20 Alternativa: quota della scheda troppo lontana",
                          MotoreCosti.alternativa(p, prodotti: [lontana], cliente: "prova") == nil)
        }
    }

    // MARK: - M21: riscatto anno per anno

    private static func riscatto(_ verifica: VerificaCalcoli) {
        // Aliquota pesata sul valore di ogni parte nell'anno del riscatto: titoli di Stato 60% nella GS e 10%
        // nei fondi; anno 1: 63.486,45 di cui GS 25.221,60 → 21,9684%; anno 3: 66.573,29 → 22,0050%
        let inizio = AiutiProva.data(2023, 1, 1)
        let oggi = AiutiProva.data(2026, 6, 1)
        let p = marco {
            $0.titoliStatoGestione = 60
            $0.titoliStatoFondi = 10
            $0.decorrenza = inizio
        }
        guard let r = MotoreRiscatto.calcola(p, anni: 3, data: oggi), r.righe.count == 4 else {
            verifica.vero("M21 Riscatto multiramo: quattro righe", false)
            return
        }
        verifica("M21 Riscatto: valore all'anno 1", r.righe[1].valore, 63_486.45)
        verifica("M21 Riscatto: imposta all'anno 1 con l'aliquota pesata sul valore", r.righe[1].imposta, 326.55)
        verifica("M21 Riscatto: imposta all'anno 3", r.righe[3].imposta, 1_006.35)
        verifica("M21 Riscatto: oggi nessun guadagno, nessuna imposta", r.righe[0].imposta, 0)
        // Bollo maturato sulla sola parte in fondi: 0,2% × 62.000 × 0,6 per gli anni trascorsi
        let anni = oggi.timeIntervalSince(inizio) / (365.25 * 86_400)
        verifica("M21 Riscatto: bollo maturato sui fondi", r.righe[1].bollo, RegoleFiscali.bollo / 100 * 62_000 * 0.6 * anni)
    }

    // MARK: - M22: sostituzione e obiettivo

    private static func sostituzioneEObiettivo(_ verifica: VerificaCalcoli) {
        // Restare nella multiramo per 10 anni: 24.800 × 1,017^10 + 37.200 × (1,055 × 0,975)^10 = 78.683,88;
        // netto dopo il 26% sul guadagno 74.346,07. Nel prudente GS al 2% e fondi al 3,5%: 65.943,50
        do {
            let p = marco()
            var b = Posizione(clienteId: "prova", canale: .indipendente, stato: .proposta, area: .investimento, nome: "Fondo")
            b.tipologia = "Fondo comune"
            b.versamentoIniziale = 10_000
            b.rendimentoAtteso = 4.5
            b.costoAnnuo = 1
            let e = MotoreSostituzione.calcola(attuale: p, alternativa: b, anni: 10)
            verifica("M22 Sostituzione: rendimento equivalente 0,4 × 3 + 0,6 × 5,5", e.resto.rendimento, 4.5, tolleranza: 0.0001)
            verifica("M22 Sostituzione: costo equivalente 0,4 × 1,3 + 0,6 × (2,3 + 0,2)", e.resto.costoAnnuo, 2.02, tolleranza: 0.0001)
            verifica("M22 Sostituzione: restando, lordo a 10 anni", e.finale?.lordoResto ?? -1, 78_683.88)
            verifica("M22 Sostituzione: restando, netto a 10 anni", e.finale?.nettoResto ?? -1, 74_346.07)
            verifica("M22 Sostituzione: costi del periodo (trattenuto, costi dei fondi e bollo)", e.resto.costiPeriodo, 14_341.27, tolleranza: 0.05)
            verifica("M22 Sostituzione: prudente con la GS spostata di 1 punto", e.scenari.first?.nettoResto ?? -1, 65_943.50)
            verifica.vero("M22 Sostituzione: la nota dice lo scarto della gestione separata",
                          e.note.contains { $0.contains("per la gestione separata delle multiramo 1 punto") })
            // Senza multiramo divise la nota resta quella di sempre
            let f = MotoreSostituzione.calcola(attuale: b, alternativa: b, anni: 10)
            verifica.vero("M22 Sostituzione senza multiramo: nota di sempre",
                          !f.note.contains { $0.contains("gestione separata delle multiramo") })
        }

        // Obiettivo collegato alla multiramo: stesso calcolo, 120 mesi
        do {
            let p = marco()
            var o = Obiettivo(clienteId: "prova", titolo: "Capitale", area: .patrimonio, importo: 100_000,
                              scadenza: AiutiProva.data(2036, 1, 1))
            o.posizioniCollegate = [p.id]
            let e = MotoreObiettivo.calcola(o, posizioni: [p], data: AiutiProva.data(2026, 1, 1))
            verifica("M22 Obiettivo: 120 mesi", Double(e.mesi), 120)
            if let c = e.contributi.first {
                verifica("M22 Obiettivo: rendimento equivalente", c.rendimento, 4.5, tolleranza: 0.0001)
                verifica("M22 Obiettivo: costo equivalente", c.costoAnnuo, 2.02, tolleranza: 0.0001)
                verifica("M22 Obiettivo: netto alla scadenza", c.nettoScadenza, 74_346.07)
            } else {
                verifica.vero("M22 Obiettivo: la multiramo contribuisce", false)
            }
            // Senza rendimenti le due parti usano quello dell'obiettivo (2%)
            let senza = marco { $0.rendimentoGestione = nil; $0.rendimentoFondi = nil }
            var os = o
            os.posizioniCollegate = [senza.id]
            let es = MotoreObiettivo.calcola(os, posizioni: [senza], data: AiutiProva.data(2026, 1, 1))
            verifica("M22 Obiettivo senza rendimenti: quello dell'obiettivo per le due parti",
                     es.contributi.first?.rendimento ?? -1, 2, tolleranza: 0.0001)
        }
    }

    // MARK: - M23: andamento, simulatore e Analisi 360

    private static func andamentoEAnalisi(_ verifica: VerificaCalcoli) {
        do {
            let p = marco {
                $0.rilevazioni = [Rilevazione(data: AiutiProva.data(2024, 1, 1), controvalore: 60_000, versato: 62_000)]
                $0.dataValore = AiutiProva.data(2025, 1, 1)
            }
            verifica("M23 Andamento: atteso netto composto (senza bollo)", MotoreAndamento.calcola(p)?.attesoAnnuo ?? -1, 2.60, tolleranza: 0.0001)
            var senza = p
            senza.rendimentoGestione = nil
            senza.rendimentoFondi = nil
            let andamento = MotoreAndamento.calcola(senza)
            verifica.vero("M23 Andamento: senza rendimenti niente linea dell'atteso",
                          senza.multiramoDivisa && andamento != nil && andamento?.attesoAnnuo == nil)
        }

        do {
            let p = marco()
            let s = Simulazione(posizione: p, orizzonteCliente: nil)
            verifica("M23 Simulatore: rendimento equivalente", s.rendimento, 4.5, tolleranza: 0.0001)
            verifica("M23 Simulatore: costo equivalente", s.costoAnnuo, 2.02, tolleranza: 0.0001)
            verifica("M23 Simulatore: aliquota equivalente", s.aliquota, 26, tolleranza: 0.0001)

            let a = Analisi360(cliente: nil, posizioni: [p])
            verifica("M23 Analisi 360: rendimento lordo complessivo", a.investimenti.rendimento, 4.5, tolleranza: 0.0001)
            verifica("M23 Analisi 360: costo composto", a.investimenti.costoAnnuo, 1.9, tolleranza: 0.0001)
            var r = p
            r.area = .risparmio
            verifica("M23 Analisi 360: anche nel Risparmio", Analisi360(cliente: nil, posizioni: [r]).risparmio.rendimento, 4.5, tolleranza: 0.0001)
        }
    }

    // MARK: - M12 `areaDal`, M24: importazione

    private static func importazione(_ verifica: VerificaCalcoli) {
        verifica.vero("M12 Importazione: «Polizza multiramo (Ramo I e Ramo III)» va in Investimento",
                      ImportaPosizioni.areaDal("Polizza multiramo (Ramo I e Ramo III)") == .investimento)
        verifica.vero("M12 Importazione: «Polizza rivalutabile Ramo I» resta nel Risparmio",
                      ImportaPosizioni.areaDal("Polizza rivalutabile Ramo I") == .risparmio)
        verifica.vero("M12 Importazione: «Unit linked con gestione separata» va in Investimento",
                      ImportaPosizioni.areaDal("Unit linked con gestione separata") == .investimento)
        verifica.vero("M12 Importazione: «Polizza rivalutabile per la comunità» resta nel Risparmio",
                      ImportaPosizioni.areaDal("Polizza rivalutabile per la comunità") == .risparmio)

        // M24. Dalla scheda alla posizione importata: le due parti, ma non la quota di una posizione in essere
        var s = Prodotto(nome: "Multiramo importata", canale: .indipendente, area: .investimento)
        s.tipologia = "Polizza multiramo"
        s.quotaGestioneSeparata = 40
        s.rendimentoGestione = 3
        s.trattenuto = 1.3
        s.costoFondi = 2.3
        s.sriFondi = 4
        var p = AiutiProva.posizione("Multiramo importata", .investimento, 50_000)
        ImportaPosizioni.applica(s, a: &p)
        verifica.vero("M24 Importazione: tipologia dalla scheda, multiramo divisa", p.multiramo && p.multiramoDivisa)
        verifica("M24 Importazione: rendimento della gestione separata dalla scheda", p.rendimentoGestione ?? -1, 3, tolleranza: 0.0001)
        verifica("M24 Importazione: costi dei fondi dalla scheda", p.costoFondi ?? -1, 2.3, tolleranza: 0.0001)
        verifica("M24 Importazione: trattenuto dalla scheda", p.trattenuto ?? -1, 1.3, tolleranza: 0.0001)
        verifica.vero("M24 Importazione: in essere la quota resta da indicare (estratto conto)",
                      p.quotaGestioneSeparata == nil && p.quotaGestioneStimata)
    }
}
