import Foundation

/// Prove dei motori di rischio: scenari probabilistici (Monte Carlo leggero con seme), crisi storiche
/// 2008, 2020 e 2022, coerenza con il profilo del cliente (rischio, orizzonte, concentrazione su
/// emittente e canale). Chiamate da `ProvaCalcoli.esegui()` prima del riepilogo: gli errori si sommano.
enum ProvaCalcoliRischio {
    static func esegui(_ verifica: VerificaCalcoli) {
        func pos(_ nome: String, _ area: AreaPosizione, _ valore: Double, canale: Canale = .indipendente,
                 _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
            AiutiProva.posizione(nome, area, valore, canale: canale, modifica)
        }

        // K1. Multiramo senza la quota in gestione separata: metà esposta, come dice il metodo.
        // 100.000 € SRI 3 (calo 10%) × 50% esposto = 5.000 €; al riparo il 50%.
        do {
            let multi = pos("Multiramo", .investimento, 100_000) { $0.tipologia = "Polizza multiramo"; $0.sri = 3 }
            verifica("K1 Multiramo senza quota: esposta la metà", MotoreResistenza.quotaARischio(multi), 0.5, tolleranza: 0.0001)
            let r = MotoreResistenza.calcola([multi], profilo: nil)
            verifica("K1 Multiramo senza quota: perdita sui mercati 100.000 × 50% × 10%", r.scenario(.mercati)?.perdita ?? -1, 5_000)
            verifica("K1 Multiramo senza quota: al riparo il 50%", r.quotaProtetta, 0.5, tolleranza: 0.0001)
            verifica.vero("K1 Multiramo senza quota: il motivo dice che la quota è stimata",
                          r.scenario(.mercati)?.voci.first?.motivo.contains("(stimato)") == true)
            var indicata = multi
            indicata.quotaGestioneSeparata = 40
            verifica("K1 Multiramo con il 40% in gestione separata: esposto il 60%", MotoreResistenza.quotaARischio(indicata), 0.6, tolleranza: 0.0001)
            // Il bollo resta prudente: senza quota tutta la multiramo è soggetta
            verifica("K1 Multiramo senza quota: il bollo resta su tutto il valore", multi.quotaBollo, 1, tolleranza: 0.0001)
        }

        // K2. Composizione per classe di attivo (quote del valore).
        do {
            let bilanciato = pos("Bilanciato", .investimento, 10_000) { $0.tipologia = "Fondo comune bilanciato" }
            let c1 = MotoreResistenza.composizione(bilanciato)
            verifica("K2 Bilanciato senza quota: azioni stimate al 50%", c1?.azioni ?? -1, 0.5, tolleranza: 0.0001)
            verifica("K2 Bilanciato: titoli di Stato metà della parte obbligazionaria (25%)", c1?.governativi ?? -1, 0.25, tolleranza: 0.0001)
            verifica.vero("K2 Bilanciato: quota azionaria stimata", c1?.stimata == true)
            let sri4 = pos("Fondo", .investimento, 10_000) { $0.tipologia = "Fondo comune"; $0.sri = 4 }
            verifica("K2 Fondo SRI 4 senza quota: azioni al 70%", MotoreResistenza.composizione(sri4)?.azioni ?? -1, 0.7, tolleranza: 0.0001)
            let pensione = pos("Fondo pensione", .previdenza, 10_000) { $0.tipologia = "Fondo pensione aperto" }
            verifica("K2 Previdenza senza SRI (stimato 3): azioni al 35%", MotoreResistenza.composizione(pensione)?.azioni ?? -1, 0.35, tolleranza: 0.0001)
            let monetario = pos("Monetario", .investimento, 10_000) { $0.tipologia = "Fondo monetario"; $0.sri = 1 }
            verifica("K2 Fondo monetario: tutto liquidità", MotoreResistenza.composizione(monetario)?.liquidita ?? -1, 1, tolleranza: 0.0001)
            // Multiramo 40% in gestione separata, quota azionaria indicata 80%: le azioni non superano il 60% esposto
            let multi = pos("Multiramo", .investimento, 10_000) { $0.tipologia = "Polizza multiramo"; $0.quotaGestioneSeparata = 40; $0.quotaAzionaria = 80 }
            let c2 = MotoreResistenza.composizione(multi)
            verifica("K2 Multiramo: azioni al massimo la parte esposta (60%)", c2?.azioni ?? -1, 0.6, tolleranza: 0.0001)
            verifica("K2 Multiramo: 40% in gestione separata", c2?.gestioneSeparata ?? -1, 0.4, tolleranza: 0.0001)
            verifica.vero("K2 Protezione: nessuna composizione", MotoreResistenza.composizione(pos("TCM", .protezione, 0)) == nil)
        }

        // K3. Crisi del passato su un portafoglio di 50.000 € più la casa.
        // ETF 10.000 (azioni 100%); fondo obbligazionario 10.000 (azioni 0, titoli di Stato 60%, societarie 40%);
        // rivalutabile Ramo I 10.000 e conto 10.000 (non cambiano); multiramo 10.000 con il 40% in gestione
        // separata e il 30% in azioni (resta 30% obbligazioni: 15% Stato, 15% societarie); casa 100.000.
        // A mano, 2008 (azioni −37, Stato +4, societarie −4, immobili −5):
        //   ETF 3.700; fondo 10.000·(0,6·4 − 0,4·4)% = +80 (guadagno, perdita −80);
        //   multiramo 10.000·(0,3·37 − 0,15·4 + 0,15·4)% = 1.110 → totale 4.730 (9,46%); casa 5.000.
        // 2020 (azioni −33, Stato −4, societarie −7): 3.300 + 10.000·(0,6·4 + 0,4·7)% = 520
        //   + 10.000·(0,3·33 + 0,15·4 + 0,15·7)% = 1.155 → 4.975 (9,95%): la peggiore.
        // 2022 (azioni −13, Stato −17, societarie −14): 1.300 + 10.000·(0,6·17 + 0,4·14)% = 1.580
        //   + 10.000·(0,3·13 + 0,15·17 + 0,15·14)% = 855 → 3.735 (7,47%).
        do {
            let etf = pos("ETF", .investimento, 10_000) { $0.tipologia = "ETF"; $0.sri = 4; $0.quotaAzionaria = 100 }
            let obbligazioni = pos("Obbligazionario", .investimento, 10_000) { $0.tipologia = "Fondo obbligazionario"; $0.sri = 2; $0.quotaAzionaria = 0; $0.quotaTitoliStato = 60 }
            let ramoI = pos("Rivalutabile", .risparmio, 10_000) { $0.tipologia = "Polizza rivalutabile (Ramo I)" }
            let conto = pos("Conto", .liquidita, 10_000)
            let multi = pos("Multiramo", .investimento, 10_000) { $0.tipologia = "Polizza multiramo"; $0.sri = 3; $0.quotaGestioneSeparata = 40; $0.quotaAzionaria = 30 }
            let casa = pos("Casa", .immobili, 100_000)
            var proposta = pos("Proposta", .investimento, 50_000) { $0.sri = 6; $0.quotaAzionaria = 100 }
            proposta.stato = .proposta
            var profilo = ProfiloInvestitore()
            profilo.propensione = .moderata
            let tutte = [etf, obbligazioni, ramoI, conto, multi, casa, proposta]
            let crisi = MotoreResistenza.crisi(tutte, profilo: profilo)
            let k2008 = crisi.first { $0.crisi.anno == 2008 }
            let k2020 = crisi.first { $0.crisi.anno == 2020 }
            let k2022 = crisi.first { $0.crisi.anno == 2022 }
            verifica("K3 Tre crisi: 2008, 2020, 2022", Double(crisi.count), 3)
            verifica("K3 Crisi 2008: perdita 4.730 €", k2008?.perdita ?? -1, 4_730)
            verifica("K3 Crisi 2008: base il patrimonio finanziario (proposte, casa escluse)", k2008?.base ?? -1, 50_000)
            verifica("K3 Crisi 2008: 9,46% del patrimonio finanziario", (k2008?.quota ?? -1) * 100, 9.46)
            verifica("K3 Crisi 2008: titoli di Stato in guadagno (−80 €)",
                     k2008?.voci.first { $0.posizione.id == obbligazioni.id }?.perdita ?? -1, -80)
            verifica.vero("K3 Crisi 2008: gestione separata e conto non cambiano",
                          k2008?.voci.contains { $0.posizione.id == ramoI.id || $0.posizione.id == conto.id } == false)
            verifica("K3 Crisi 2008: la casa a parte, −5% = 5.000 €", k2008?.perditaImmobili ?? -1, 5_000)
            verifica("K3 Crisi 2020: perdita 4.975 €", k2020?.perdita ?? -1, 4_975)
            verifica("K3 Crisi 2022: perdita 3.735 €", k2022?.perdita ?? -1, 3_735)
            verifica("K3 Crisi 2022: obbligazionario −1.580 €", k2022?.voci.first { $0.posizione.id == obbligazioni.id }?.perdita ?? -1, 1_580)
            let r = MotoreResistenza.calcola(tutte, profilo: profilo)
            verifica("K3 La prova di resistenza porta le stesse crisi", r.crisi.first { $0.crisi.anno == 2020 }?.perdita ?? -1, 4_975)
            verifica("K3 La crisi peggiore è il 2020", Double(r.crisiPeggiore?.crisi.anno ?? 0), 2_020)
            verifica.vero("K3 Profilo moderato: 9,95% dentro il 10%", r.crisiPeggiore?.giudizio == .dentro)
            profilo.propensione = .prudente
            verifica.vero("K3 Profilo prudente: 9,95% oltre il 5% (e oltre il margine del 6,25%)",
                          MotoreResistenza.crisi(tutte, profilo: profilo).allSatisfy { $0.giudizio == .oltre })
            verifica.vero("K3 Senza propensione nessun giudizio", MotoreResistenza.crisi(tutte, profilo: nil).allSatisfy { $0.giudizio == nil })
            verifica.vero("K3 La sintesi per Eve chiude con le crisi del passato",
                          MotoreResistenza.sintesi(r).last?.hasPrefix("Se tornassero le crisi del passato") == true)
            verifica.vero("K3 Il giudizio della prova resta quello dei mercati", r.giudizio == .dentro)
            verifica.vero("K3 Metodo delle crisi: una riga per crisi più le ipotesi", MotoreResistenza.metodoCrisi.count == 4)
        }

        // K4. Crisi e resistenza sui dati di prova.
        // Giulia: ETF 36.400 € (azioni 100%) × 37% = 13.468 €; il fondo obbligazionario (metà Stato +4%,
        // metà societarie −4%) pareggia; sul patrimonio finanziario di 89.050 € (7.650 + 36.400 + 21.000
        // + 24.000) è il 15,12%: oltre il 12,5% (10% × 1,25) del profilo moderato.
        // Marco: multiramo con il 40% in gestione separata e i fondi SRI 4: 62.000 × 0,6 × 20% = 7.440 €;
        // PIP 38.000 € SRI stimato 3: 3.800 € → 11.240 € (con la sola combinazione erano 6.900 €).
        do {
            let demo = DatiPrisma.demo()
            if let giulia = demo.clienti.first(where: { $0.id == "giulia" }) {
                let r = MotoreResistenza.calcola(demo.posizioni.filter { $0.clienteId == "giulia" }, profilo: giulia.profilo)
                let k = r.crisi.first { $0.crisi.anno == 2008 }
                verifica("K4 Giulia, crisi 2008: 13.468 €", k?.perdita ?? -1, 13_468, tolleranza: 1)
                verifica("K4 Giulia, crisi 2008: 15,12% del patrimonio finanziario", (k?.quota ?? -1) * 100, 13_468 / 89_050.0 * 100, tolleranza: 0.01)
                verifica.vero("K4 Giulia, crisi 2008: oltre il profilo moderato", k?.giudizio == .oltre)
            } else {
                verifica.vero("K4 Giulia nei dati di prova", false)
            }
            if let marco = demo.clienti.first(where: { $0.id == "marco" }) {
                let r = MotoreResistenza.calcola(demo.posizioni.filter { $0.clienteId == "marco" }, profilo: marco.profilo)
                verifica("K4 Marco, mercati: fondi della multiramo al 60% con SRI 4, più il PIP (11.240 €)", r.scenario(.mercati)?.perdita ?? -1, 11_240, tolleranza: 1)
            } else {
                verifica.vero("K4 Marco nei dati di prova", false)
            }
        }

        // K5. Generatore con seme (SplitMix64): valori di riferimento pubblicati dell'algoritmo
        // (seme 1234567 → 6457827717110365317; seme 0 → 0xE220A8397B1DCDAF), stessa sequenza a parità di seme.
        do {
            var a = GeneratoreSeme(seme: 1_234_567)
            verifica.vero("K5 SplitMix64, seme 1234567: primo valore di riferimento", a.next() == 6_457_827_717_110_365_317)
            var zero = GeneratoreSeme(seme: 0)
            verifica.vero("K5 SplitMix64, seme 0: primo valore di riferimento", zero.next() == 0xE220_A839_7B1D_CDAF)
            var g1 = GeneratoreSeme(seme: 42)
            var g2 = GeneratoreSeme(seme: 42)
            var uguali = true
            for _ in 0..<100 {
                if g1.normale() != g2.normale() { uguali = false }
            }
            verifica.vero("K5 Stesso seme, stessi numeri", uguali)
            // 10.000 estrazioni: media delle uniformi 0,5 (±0,01), normali con media 0 (±0,03) e varianza 1 (±0,04).
            // Ricalcolate fuori dall'app con lo stesso algoritmo: 0,50204; −0,01900; 0,99750.
            var u = GeneratoreSeme(seme: 42)
            var somma = 0.0
            for _ in 0..<10_000 { somma += u.uniforme() }
            verifica("K5 Uniformi: media 0,5", somma / 10_000, 0.5, tolleranza: 0.01)
            var g = GeneratoreSeme(seme: 42)
            var z: [Double] = []
            for _ in 0..<10_000 { z.append(g.normale()) }
            let media = z.reduce(0, +) / 10_000
            let varianza = z.reduce(0) { $0 + ($1 - media) * ($1 - media) } / 10_000
            verifica("K5 Normali: media 0", media, 0, tolleranza: 0.03)
            verifica("K5 Normali: varianza 1", varianza, 1, tolleranza: 0.04)
            verifica.vero("K5 Seme da un testo: stabile (FNV-1a del testo vuoto = base dell'algoritmo)", MotoreMonteCarlo.seme("") == 0xCBF2_9CE4_8422_2325)
            verifica.vero("K5 Seme da un testo: testi diversi, semi diversi", MotoreMonteCarlo.seme("obiettivo-a") != MotoreMonteCarlo.seme("obiettivo-b"))
        }

        // K6. Monte Carlo con volatilità zero: è la proiezione deterministica.
        do {
            // 10.000 € al 4% con costo dell'1% per 10 anni: 10.000 × (1,04 × 0,99)^10 = 10.000 × 1,0296^10 = 13.387,06 €
            var l = LineaMonteCarlo(nome: "Fondo", capitale: 10_000, rendimento: 4)
            l.costoAnnuo = 1
            let e = MotoreMonteCarlo.simula([l], mesi: 120, traguardo: 13_000, traiettorie: 10, seme: 7)
            verifica("K6 Volatilità zero: 10.000 × 1,0296^10", e.p50, 13_387.06, tolleranza: 0.01)
            verifica("K6 Volatilità zero: p10 = p90", e.p90 - e.p10, 0, tolleranza: 0.0001)
            verifica("K6 Volatilità zero, traguardo 13.000 €: probabilità 100%", e.probabilita, 1)
            verifica("K6 Volatilità zero, traguardo 14.000 €: probabilità 0%",
                     MotoreMonteCarlo.simula([l], mesi: 120, traguardo: 14_000, traiettorie: 10, seme: 7).probabilita, 0)
            verifica("K6 Anni del ventaglio: da 0 a 10", Double(e.anni.count), 11)
            // 100 € al mese per 10 anni, rendimento zero, ingresso 2%: 120 × 98 = 11.760 €
            var piano = LineaMonteCarlo(nome: "Piano", capitale: 0, rendimento: 0)
            piano.versamento = 100
            piano.frequenza = .mensile
            piano.costoIngresso = 2
            verifica("K6 Versamenti mensili: 120 × 98 €", MotoreMonteCarlo.simula([piano], mesi: 120, traguardo: 0, traiettorie: 3, seme: 7).p50, 11_760)
            // Ramo I: rendimento 0,5% con trattenuto 1,3% sarebbe negativo, ma il capitale non scende
            var ramoI = LineaMonteCarlo(nome: "Ramo I", capitale: 10_000, rendimento: 0.5)
            ramoI.costoAnnuo = 1.3
            ramoI.capitaleGarantito = true
            verifica("K6 Capitale garantito: resta 10.000 €", MotoreMonteCarlo.simula([ramoI], mesi: 60, traguardo: 0, traiettorie: 3, seme: 7).p50, 10_000)
            // Fondo pensione: 20% sul risultato mese per mese, 10.000 € al 4% per un anno:
            // 10.000 × (1 + (1,04^(1/12) − 1) × 0,8)^12 = 10.318,85 €, come MotoreProiezione con tassazione annua
            var fp = LineaMonteCarlo(nome: "Fondo pensione", capitale: 10_000, rendimento: 4)
            fp.tassazioneAnnua = 20
            var par = ParametriProiezione(capitaleIniziale: 10_000, versamento: 0, frequenza: .unica, anni: 1, rendimento: 4,
                                          aliquotaFiscale: 0, inflazione: 0)
            par.tassazioneAnnua = 20
            let attesoFP = MotoreProiezione.calcola(par).lordo
            verifica("K6 Tassazione annua: a mano 10.318,85 €", attesoFP, 10_318.85, tolleranza: 0.01)
            verifica("K6 Tassazione annua: come MotoreProiezione",
                     MotoreMonteCarlo.simula([fp], mesi: 12, traguardo: 0, traiettorie: 3, seme: 7).p50, attesoFP, tolleranza: 0.01)
            verifica("K6 Traiettorie al massimo 2.000",
                     Double(MotoreMonteCarlo.simula([l], mesi: 12, traguardo: 0, traiettorie: 5_000, seme: 7).traiettorie), 2_000)
            verifica("K6 Nessuna linea: capitale zero", MotoreMonteCarlo.simula([], mesi: 12, traguardo: 1, traiettorie: 10, seme: 7).p50, 0)
        }

        // K7. Con volatilità zero il Monte Carlo dell'obiettivo coincide con il piano (MotoreObiettivo):
        // fondo bilanciato 10.000 € (versati 9.000), 150 € al mese con ingresso 1%, rendimento 4%, costo 1,2%
        // più bollo 0,20%, imposta 26% sul guadagno; accantonato 2.000 € al 2%; 89 mesi (7 anni e 5 mesi).
        do {
            let data = AiutiProva.data(2026, 1, 15)
            let fondo = pos("Fondo bilanciato", .investimento, 10_000) {
                $0.tipologia = "Fondo comune bilanciato"; $0.totaleVersato = 9_000; $0.premio = 150; $0.frequenza = .mensile
                $0.costoIngresso = 1; $0.costoAnnuo = 1.2; $0.rendimentoAtteso = 4; $0.aliquotaFiscale = 26
                $0.volatilita = 0
            }
            var o = Obiettivo(clienteId: "prova", titolo: "Casa", area: .casa, importo: 30_000, scadenza: AiutiProva.data(2033, 6, 15))
            o.accantonato = 2_000
            o.posizioniCollegate = [fondo.id]
            let piano = MotoreObiettivo.calcola(o, posizioni: [fondo], data: data)
            let mc = MotoreMonteCarlo.obiettivo(o, posizioni: [fondo], data: data, traiettorie: 50)
            verifica("K7 Mesi dell'obiettivo: 89", Double(mc.mesi), 89)
            verifica("K7 Stesso traguardo del piano (rivalutato all'inflazione)", mc.traguardo, piano.importoScadenza, tolleranza: 0.01)
            verifica("K7 Volatilità zero: mediana = proiezione del piano", mc.p50, piano.proiezione, tolleranza: 0.01)
            verifica("K7 Volatilità zero: probabilità 0 o 1 come il piano", mc.probabilita, piano.proiezione >= piano.importoScadenza ? 1 : 0)
            verifica("K7 Ventaglio: anno 0 = valore di oggi + accantonato", mc.anni.first?.p50 ?? -1, 12_000)
            verifica("K7 Ventaglio: 8 passi (7 anni e 5 mesi) più oggi", Double(mc.anni.count), 9)
            // Seme dall'id dell'obiettivo: stesso obiettivo, stesso risultato
            var mosso = fondo
            mosso.volatilita = nil
            mosso.sri = 3
            let a = MotoreMonteCarlo.obiettivo(o, posizioni: [mosso], data: data, traiettorie: 300)
            let b = MotoreMonteCarlo.obiettivo(o, posizioni: [mosso], data: data, traiettorie: 300)
            verifica("K7 Stesso obiettivo, stesso risultato", a.p50 - b.p50 + a.probabilita - b.probabilita, 0, tolleranza: 0)
            verifica.vero("K7 Con volatilità i percentili si aprono", a.p90 > a.p50 && a.p50 > a.p10)
        }

        // K8. Monte Carlo con volatilità: 10.000 € per 10 anni, rendimento medio 5%, volatilità 16%, 2.000 percorsi.
        // Lognormale con μ = ln(1,05) − 0,16²/2 = 0,035990 l'anno: mediana teorica 10.000·e^(10μ) = 14.331,88 €;
        // p10 = 10.000·e^(10μ − 1,28155·0,16·√10) = 7.493,73 €; p90 = 27.409,95 €; media 10.000·1,05^10 = 16.288,95 €.
        // Con il traguardo alla mediana la probabilità è circa 50%. Tolleranze di circa 3 errori campionari.
        // Ricalcolato fuori dall'app con lo stesso generatore (seme 2026): p50 14.491,89; p10 7.627,26;
        // p90 28.421,37; media 16.652,96; probabilità 51,05%.
        do {
            var l = LineaMonteCarlo(nome: "Azionario", capitale: 10_000, rendimento: 5)
            l.volatilita = 16
            let mediana = 10_000 * exp(10 * (log(1.05) - 0.0128))
            verifica("K8 Mediana teorica a mano", mediana, 14_331.88, tolleranza: 0.01)
            let e = MotoreMonteCarlo.simula([l], mesi: 120, traguardo: mediana, traiettorie: 2_000, seme: 2_026)
            verifica("K8 Traguardo alla mediana: probabilità circa 50%", e.probabilita, 0.5, tolleranza: 0.035)
            verifica("K8 Mediana vicina alla teorica (±3%)", e.p50, 14_331.88, tolleranza: 430)
            verifica("K8 p10 vicino al teorico (±6%)", e.p10, 7_493.73, tolleranza: 450)
            verifica("K8 p90 vicino al teorico (±6%)", e.p90, 27_409.95, tolleranza: 1_650)
            verifica("K8 Media vicina a 10.000 × 1,05^10 (±4%)", e.media, 16_288.95, tolleranza: 650)
            verifica("K8 Riproducibile: p50 ricalcolato fuori dall'app", e.p50, 14_491.89, tolleranza: 1)
            verifica("K8 Riproducibile: probabilità ricalcolata fuori dall'app", e.probabilita, 0.5105, tolleranza: 0.001)
            verifica("K8 In decimi: 5 su 10", Double(e.suDieci), 5)
            let altro = MotoreMonteCarlo.simula([l], mesi: 120, traguardo: mediana, traiettorie: 2_000, seme: 2_027)
            verifica.vero("K8 Seme diverso, risultato diverso (ma vicino)", altro.p50 != e.p50 && abs(altro.p50 - e.p50) < 600)
            // Leggerezza: 2.000 percorsi, 30 anni, 5 posizioni con versamenti mensili: pochi ms su un M1, margine largo per il server di prova
            var pesante = l
            pesante.versamento = 100
            pesante.frequenza = .mensile
            let inizio = Date()
            _ = MotoreMonteCarlo.simula(Array(repeating: pesante, count: 5), mesi: 360, traguardo: 0, traiettorie: 2_000, seme: 9)
            let millisecondi = Date().timeIntervalSince(inizio) * 1_000
            verifica("K8 Monte Carlo leggero: millisecondi per 2.000 percorsi di 30 anni (sotto 1.000 sul server di prova)", millisecondi, 0, tolleranza: 1_000)
        }

        // K9. Volatilità di una posizione: indicata, dall'SRI (sulla parte esposta), dalla composizione, dall'area.
        do {
            verifica("K9 Indicata: 12%", MotoreMonteCarlo.volatilita(pos("A", .investimento, 1) { $0.volatilita = 12; $0.sri = 6 }), 12)
            verifica("K9 SRI 4: 16%", MotoreMonteCarlo.volatilita(pos("B", .investimento, 1) { $0.sri = 4 }), 16)
            verifica("K9 Multiramo SRI 3 con 40% in gestione separata: 8,5 × 0,6 = 5,1%",
                     MotoreMonteCarlo.volatilita(pos("C", .investimento, 1) { $0.tipologia = "Polizza multiramo"; $0.sri = 3; $0.quotaGestioneSeparata = 40 }), 5.1)
            verifica("K9 Quota azionaria 50% senza SRI: 0,5 × 16 + 0,5 × 5 = 10,5%",
                     MotoreMonteCarlo.volatilita(pos("D", .investimento, 1) { $0.tipologia = "Fondo"; $0.quotaAzionaria = 50 }), 10.5)
            verifica("K9 Gestione separata: zero",
                     MotoreMonteCarlo.volatilita(pos("E", .risparmio, 1) { $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.sri = 2 }), 0)
            verifica("K9 Liquidità: zero", MotoreMonteCarlo.volatilita(pos("F", .liquidita, 1)), 0)
            verifica("K9 Previdenza senza dati: SRI stimato 3, 8,5%", MotoreMonteCarlo.volatilita(pos("G", .previdenza, 1)), 8.5)
        }

        // K10. Coerenza con il profilo: rischio.
        do {
            func cliente(_ propensione: ProfiloInvestitore.Propensione?, orizzonte: Int? = nil) -> Cliente {
                var c = DatiPrisma.demo().clienti[0]
                c.profilo = ProfiloInvestitore()
                c.profilo.propensione = propensione
                c.profilo.orizzonteAnni = orizzonte
                return c
            }
            // Prudente: ETF 30.000 € (SRI 4, azioni 100%) e conto 70.000 €.
            // SRI medio (30.000·4 + 70.000·1)/100.000 = 1,9 ≤ 2: va bene; azioni 30% > 20%: troppe;
            // crisi 2008: 30.000 × 37% = 11.100 € = 11,1% > 6,25% (5% × 1,25): oltre.
            let etf = pos("ETF", .investimento, 30_000) { $0.tipologia = "ETF azionario"; $0.sri = 4; $0.quotaAzionaria = 100 }
            let conto = pos("Conto", .liquidita, 70_000)
            let e1 = MotoreCoerenza.calcola(cliente: cliente(.prudente), posizioni: [etf, conto])
            verifica("K10 SRI medio ponderato 1,9", e1.oggi.sriMedio ?? -1, 1.9, tolleranza: 0.0001)
            verifica("K10 Quota azionaria 30%", (e1.oggi.quotaAzionaria ?? -1) * 100, 30, tolleranza: 0.0001)
            verifica.vero("K10 Prudente: troppe azioni e crisi oltre il profilo, SRI medio dentro",
                          e1.incoerenze.map(\.tipo) == [.azioni, .crisi])
            verifica("K10 Crisi peggiore 2008: 11,1%", e1.incoerenze.first { $0.tipo == .crisi }?.valore ?? -1, 11.1, tolleranza: 0.0001)
            // Moderata: fondo SRI 5 di 60.000 € (azioni stimate 100%) e rivalutabile 40.000 € (SRI stimato 1).
            // SRI medio (60.000·5 + 40.000·1)/100.000 = 3,4 > 3; azioni 60% > 50%; crisi 2008: 22.200 € = 22,2% > 12,5%;
            // emittente: 60.000 € su 100.000 presso la stessa SGR, 60% > 50%.
            let fondo = pos("Fondo", .investimento, 60_000) { $0.tipologia = "Fondo comune"; $0.sri = 5; $0.emittente = "SGR Uno" }
            let ramoI = pos("Rivalutabile", .risparmio, 40_000) { $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.emittente = "Compagnia A" }
            let e2 = MotoreCoerenza.calcola(cliente: cliente(.moderata), posizioni: [fondo, ramoI])
            verifica("K10 Moderata: SRI medio 3,4", e2.incoerenze.first { $0.tipo == .rischioMedio }?.valore ?? -1, 3.4, tolleranza: 0.0001)
            verifica.vero("K10 Moderata: rischio medio, azioni, crisi ed emittente",
                          e2.incoerenze.map(\.tipo) == [.rischioMedio, .azioni, .crisi, .emittente])
            verifica("K10 Moderata: emittente al 60%", e2.concentrazione.first?.valore ?? -1, 60, tolleranza: 0.0001)
            verifica.vero("K10 Aggressiva: nessun limite di SRI e azioni, crisi al 22,2% dentro il 30%",
                          MotoreCoerenza.calcola(cliente: cliente(.aggressiva), posizioni: [fondo, ramoI]).rischio.isEmpty)
            verifica.vero("K10 Senza propensione: nessun controllo sul rischio",
                          MotoreCoerenza.calcola(cliente: cliente(nil), posizioni: [fondo, ramoI]).rischio.isEmpty)

            // Proposte: moderata con orizzonte 3 anni e un conto di 50.000 €; proposta di 20.000 € con SRI 5 e
            // periodo raccomandato 5 anni → proposta oltre il profilo e orizzonte. Con la proposta: SRI medio
            // (50.000 + 100.000)/70.000 = 2,14; azioni 28,6%; crisi 2008 7.400/70.000 = 10,6% ≤ 12,5%: niente altro.
            var proposta = pos("Fondo azionario Europa", .investimento, 0) {
                $0.tipologia = "Fondo comune"; $0.sri = 5; $0.versamentoIniziale = 20_000; $0.periodoRaccomandato = 5
            }
            proposta.controvalore = nil
            proposta.stato = .proposta
            proposta.esito = .presentata
            var rifiutata = proposta
            rifiutata.id = "prova-rifiutata"
            rifiutata.esito = .rifiutata
            let conto50 = pos("Conto", .liquidita, 50_000)
            let e3 = MotoreCoerenza.calcola(cliente: cliente(.moderata, orizzonte: 3), posizioni: [conto50, proposta, rifiutata])
            verifica.vero("K10 Proposta: oltre il profilo e oltre l'orizzonte", e3.incoerenze.map(\.tipo) == [.proposta, .orizzonte])
            verifica.vero("K10 Proposta: segnalate come «con le proposte»", e3.incoerenze.allSatisfy { $0.dopoLeProposte && $0.posizione?.id == proposta.id })
            verifica("K10 Con le proposte (la rifiutata non conta): 70.000 €", e3.conProposte?.patrimonioFinanziario ?? -1, 70_000)
            verifica("K10 Con le proposte: SRI medio 2,14", e3.conProposte?.sriMedio ?? -1, 150_000 / 70_000.0, tolleranza: 0.0001)
            verifica.vero("K10 Oggi senza proposte: nulla da segnalare sul rischio", e3.oggi.sriMedio == 1)
        }

        // K11. Coerenza: concentrazione su un emittente o sul canale Alleanza.
        do {
            let c = DatiPrisma.demo().clienti[0]
            // «Alleanza Assicurazioni S.p.A.» 30.000 € e «ALLEANZA» 25.000 € sono lo stesso emittente: 55.000 € su
            // 100.000 di patrimonio finanziario (il conto di 25.000 € conta nella base, non nell'emittente) = 55% > 50%.
            let a1 = pos("Rivalutabile", .risparmio, 30_000, canale: .alleanza) { $0.tipologia = "Polizza rivalutabile (Ramo I)"; $0.emittente = "Alleanza Assicurazioni S.p.A." }
            let a2 = pos("Multiramo", .investimento, 25_000, canale: .alleanza) { $0.tipologia = "Polizza multiramo"; $0.emittente = "ALLEANZA" }
            let b = pos("Fondo", .investimento, 20_000) { $0.emittente = "Banca X" }
            let conto = pos("Conto", .liquidita, 25_000) { $0.emittente = "Banca X" }
            verifica.vero("K11 Lo stesso emittente scritto in due modi", MotoreCoerenza.chiaveEmittente("Alleanza Assicurazioni S.p.A.") == MotoreCoerenza.chiaveEmittente("ALLEANZA"))
            let e1 = MotoreCoerenza.calcola(cliente: c, posizioni: [a1, a2, b, conto])
            verifica("K11 Emittente al 55%", e1.oggi.emittenti.first?.quota ?? -1, 0.55, tolleranza: 0.0001)
            verifica("K11 Emittente: due posizioni", Double(e1.oggi.emittenti.first?.posizioni ?? 0), 2)
            verifica.vero("K11 Concentrazione su un emittente (e non anche sul canale)", e1.concentrazione.map(\.tipo) == [.emittente])
            // Canale: Alleanza 40.000 + Genertellife 45.000 € nel canale Alleanza, 10.000 € indipendenti, conto 5.000 €.
            // Nessun emittente oltre il 50% (45%), ma nel canale Alleanza è investito l'85% (85.000 su 100.000) > 80%.
            let x1 = pos("Rivalutabile", .risparmio, 40_000, canale: .alleanza) { $0.emittente = "Alleanza Assicurazioni" }
            let x2 = pos("Unit", .investimento, 45_000, canale: .alleanza) { $0.emittente = "Genertellife" }
            let x3 = pos("ETF", .investimento, 10_000) { $0.emittente = "Banca Y" }
            let x4 = pos("Conto", .liquidita, 5_000)
            let e2 = MotoreCoerenza.calcola(cliente: c, posizioni: [x1, x2, x3, x4])
            verifica.vero("K11 Canale: solo la concentrazione sul canale Alleanza", e2.concentrazione.map(\.tipo) == [.canale])
            verifica("K11 Canale Alleanza: 85% del patrimonio finanziario", e2.concentrazione.first?.valore ?? -1, 85, tolleranza: 0.0001)
            // Dopo le proposte: oggi Alleanza 20.000 € su 50.000 (40%, anche come canale); con una proposta Alleanza
            // di 30.000 € diventa 50.000 su 80.000 = 62,5% > 50%.
            let y1 = pos("Rivalutabile", .risparmio, 20_000, canale: .alleanza) { $0.emittente = "Alleanza Assicurazioni" }
            let y2 = pos("Conto", .liquidita, 30_000)
            var y3 = pos("Nuova rivalutabile", .risparmio, 0, canale: .alleanza) { $0.emittente = "Alleanza Assicurazioni"; $0.versamentoIniziale = 30_000 }
            y3.controvalore = nil
            y3.stato = .proposta
            y3.esito = .bozza
            let e3 = MotoreCoerenza.calcola(cliente: c, posizioni: [y1, y2, y3])
            verifica.vero("K11 Oggi: 40%, nessuna concentrazione", e3.concentrazione.allSatisfy(\.dopoLeProposte))
            verifica("K11 Con la proposta: 62,5% presso Alleanza", e3.concentrazione.first?.valore ?? -1, 62.5, tolleranza: 0.0001)
            verifica.vero("K11 Con la proposta: il titolo lo dice", e3.concentrazione.first?.titolo.hasPrefix("Con le proposte") == true)
            // Sotto i 10.000 € non si segnala
            let piccoli = MotoreCoerenza.calcola(cliente: c, posizioni: [pos("Fondo", .investimento, 6_000) { $0.emittente = "SGR" }, pos("Conto", .liquidita, 2_000)])
            verifica.vero("K11 Sotto 10.000 € nessuna concentrazione", piccoli.concentrazione.isEmpty)
        }

        // K12. Attenzioni sui dati di prova: Marco ha l'81,5% presso Alleanza (54.300 + 62.000 + 38.000 =
        // 154.300 € su 189.300); Giulia nella crisi del 2008 perderebbe il 15,1% (K4), oltre il profilo moderato.
        do {
            let demo = DatiPrisma.demo()
            let attenzioni = MotoreAttenzioni.calcola(clienti: demo.clienti, posizioni: demo.posizioni)
            verifica.vero("K12 Marco: concentrazione su un emittente",
                          attenzioni.contains { $0.cliente.id == "marco" && $0.tipo == .concentrazione && $0.titolo == "Concentrazione su un emittente" })
            verifica.vero("K12 Giulia: rischio oltre il profilo nelle crisi vere",
                          attenzioni.contains { $0.cliente.id == "giulia" && $0.tipo == .rischio && $0.titolo == "Nelle crisi vere, oltre il profilo" })
            verifica.vero("K12 Le attenzioni di prima restano (beneficiari di Marco, convivente di Giulia)",
                          attenzioni.contains { $0.cliente.id == "marco" && $0.tipo == .beneficiari } && attenzioni.contains { $0.cliente.id == "giulia" && $0.tipo == .convivente })
            if let marco = demo.clienti.first(where: { $0.id == "marco" }) {
                let e = MotoreCoerenza.calcola(cliente: marco, posizioni: demo.posizioni.filter { $0.clienteId == "marco" })
                verifica("K12 Marco: 154.300 € presso Alleanza", e.oggi.emittenti.first?.valore ?? -1, 154_300, tolleranza: 1)
                verifica("K12 Marco: l'81,5% del patrimonio finanziario", (e.oggi.emittenti.first?.quota ?? -1) * 100, 154_300 / 189_300.0 * 100, tolleranza: 0.01)
            }
            verifica.vero("K12 Metodo della coerenza", MotoreCoerenza.metodo.count == 3 && MotoreMonteCarlo.metodo.count == 3)
        }
    }
}
