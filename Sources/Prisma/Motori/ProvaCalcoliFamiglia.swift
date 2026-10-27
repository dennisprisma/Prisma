import Foundation

/// Prove dei motori della famiglia: pensione pubblica con il metodo contributivo e divario previdenziale,
/// protezione per persona (caso morte, invalidità, non autosufficienza, mutuo), fisco delle polizze.
/// Chiamate da `ProvaCalcoli.esegui()` prima del riepilogo: gli errori si sommano.
enum ProvaCalcoliFamiglia {
    static func esegui(_ verifica: VerificaCalcoli) {
        pensione(verifica)
        protezione(verifica)
        fisco(verifica)
    }

    /// Un cliente di prova con la data di nascita indicata.
    private static func cliente(_ id: String, _ nome: String, nascita: Date?) -> Cliente {
        var c = Cliente(id: id, nome: nome, iniziali: Cliente.iniziali(di: nome), tinta: .blu, tema: "", email: "", telefono: "",
                        preferito: false, nota: "", creatoIl: AiutiProva.data(2020, 1, 1))
        c.dataNascita = nascita
        return c
    }

    // MARK: - Pensione pubblica (miglioramento 7)

    private static func pensione(_ verifica: VerificaCalcoli) {
        // F1. Coefficienti di trasformazione 2025–2026 (D.M. 20/11/2024): letti dalla tabella; fuori tabella l'età più vicina
        do {
            verifica("F1 Coefficiente a 57 anni", RegolePensione.coefficiente(eta: 57), 4.204, tolleranza: 0.000_1)
            verifica("F1 Coefficiente a 64 anni", RegolePensione.coefficiente(eta: 64), 5.088, tolleranza: 0.000_1)
            verifica("F1 Coefficiente a 67 anni", RegolePensione.coefficiente(eta: 67), 5.608, tolleranza: 0.000_1)
            verifica("F1 Coefficiente a 71 anni", RegolePensione.coefficiente(eta: 71), 6.510, tolleranza: 0.000_1)
            verifica("F1 Coefficiente oltre la tabella (75 → 71)", RegolePensione.coefficiente(eta: 75), 6.510, tolleranza: 0.000_1)
            verifica("F1 Coefficiente sotto la tabella (55 → 57)", RegolePensione.coefficiente(eta: 55), 4.204, tolleranza: 0.000_1)
            verifica("F1 Coefficienti in tabella (57–71)", Double(RegolePensione.coefficienti.count), 15)
        }

        // F2. IRPEF della pensione (art. 13 TUIR): detrazione e netto annuo con le addizionali al 2,53%
        // 8.000 €: IRPEF 23% = 1.840, detrazione 1.955 → nulla da pagare, niente addizionali: netto 8.000.
        // 27.000 €: IRPEF 6.210; detrazione 700 + 1.255 × 1.000 / 19.500 = 764,36 + 50 (tra 25 e 29 mila) = 814,36;
        //           IRPEF netta 5.395,64; addizionali 683,10; netto 27.000 − 5.395,64 − 683,10 = 20.921,26.
        // 30.000 €: IRPEF 28.000 × 23% + 2.000 × 33% = 7.100; detrazione 700 × 20.000 / 22.000 = 636,36;
        //           IRPEF netta 6.463,64; addizionali 759; netto 22.777,36.
        // 60.000 €: IRPEF 6.440 + 7.260 + 4.300 = 18.000; nessuna detrazione; addizionali 1.518; netto 40.482.
        do {
            verifica("F2 Detrazione pensione fino a 8.500 €", RegolePensione.detrazionePensione(reddito: 8_000), 1_955)
            verifica("F2 Detrazione pensione a 28.000 € (700 + 50 di maggiorazione)", RegolePensione.detrazionePensione(reddito: 28_000), 750)
            verifica("F2 Detrazione pensione a 50.000 €", RegolePensione.detrazionePensione(reddito: 50_000), 0)
            verifica("F2 Detrazione pensione a 27.000 €", RegolePensione.detrazionePensione(reddito: 27_000), 814.36, tolleranza: 0.01)
            verifica("F2 Netto di 8.000 € lordi (no tax area)", RegolePensione.nettoAnnuo(lordo: 8_000).netto, 8_000)
            verifica("F2 Netto di 27.000 € lordi", RegolePensione.nettoAnnuo(lordo: 27_000).netto, 20_921.26, tolleranza: 0.01)
            let n30 = RegolePensione.nettoAnnuo(lordo: 30_000)
            verifica("F2 IRPEF netta su 30.000 € lordi", n30.irpef, 6_463.64, tolleranza: 0.01)
            verifica("F2 Addizionali su 30.000 € lordi", n30.addizionali, 759, tolleranza: 0.01)
            verifica("F2 Netto di 30.000 € lordi", n30.netto, 22_777.36, tolleranza: 0.01)
            verifica("F2 Netto di 60.000 € lordi", RegolePensione.nettoAnnuo(lordo: 60_000).netto, 40_482, tolleranza: 0.01)
        }

        // F3. Montante noto e contributi futuri, senza capitalizzazione né inflazione (conto a mano):
        // 100.000 € dall'estratto conto + 10 anni × 33% × 30.000 = 9.900 → montante 199.000 €.
        // A 67 anni: 199.000 × 5,608% = 11.159,92 € lordi l'anno, 858,46 € al mese su 13 mensilità.
        // IRPEF 23% = 2.566,78; detrazione 700 + 1.255 × (28.000 − 11.159,92) / 19.500 = 1.783,81 → IRPEF 782,97;
        // addizionali 2,53% = 282,35; netto 10.094,60 l'anno, 776,51 al mese. Obiettivo 1.500 € → divario 723,49.
        // Tasso di sostituzione 11.159,92 / 30.000 = 37,20%.
        var senzaRivalutazione = IpotesiPensione()
        senzaRivalutazione.tassoCapitalizzazione = 0
        senzaRivalutazione.inflazione = 0
        do {
            let lavoro = DatiLavoro(tipo: .dipendente, redditoLavoro: 30_000, crescitaReddito: 0, anniContributi: 20,
                                    montanteContributivo: 100_000, etaPensione: 67)
            if let s = MotorePensionePubblica.stima(lavoro: lavoro, eta: 57, etaPensione: 67, reddito: nil, ipotesi: senzaRivalutazione) {
                verifica("F3 Montante alla pensione", s.montante, 199_000)
                verifica("F3 Montante dopo il primo anno", s.punti.count > 1 ? s.punti[1] : 0, 109_900)
                verifica("F3 Pensione lorda annua", s.lordaAnnua, 11_159.92)
                verifica("F3 Pensione lorda mensile (13 mensilità)", s.lordaMensile, 858.46)
                verifica("F3 IRPEF netta sulla pensione", s.irpef, 782.97)
                verifica("F3 Addizionali stimate", s.addizionali, 282.35)
                verifica("F3 Pensione netta mensile", s.nettaMensile, 776.51)
                verifica("F3 Divario con un obiettivo di 1.500 € al mese", s.divario(obiettivo: 1_500), 723.49)
                verifica("F3 Tasso di sostituzione", s.tassoSostituzione ?? 0, 37.20)
                verifica("F3 Anni di contributi all'uscita (20 + 10)", s.anniContributi, 30)
                verifica.vero("F3 Requisiti raggiunti e montante dall'estratto conto", s.requisitoRaggiunto && !s.montanteStimato)
            } else {
                verifica.vero("F3 Stima della pensione calcolata", false)
            }
        }

        // F4. Crescita del reddito e capitalizzazione: 20.000 € al 33%, reddito +2% reale l'anno, PIL nominale 3%,
        // inflazione 1% → capitalizzazione reale 1,03 / 1,01 − 1 = 1,980198%. Da 62 a 65 anni (3 anni, montante 0):
        // contributi 6.600, 6.732, 6.866,64; montante = 6.600 × 1,0198² + 6.732 × 1,0198 + 6.866,64
        // = 6.863,97 + 6.865,31 + 6.866,64 = 20.595,92 €; a 65 anni × 5,250% = 1.081,29 € lordi l'anno.
        // Ultimo reddito 20.000 × 1,02² = 20.808 €.
        do {
            var ipotesi = IpotesiPensione()
            ipotesi.tassoCapitalizzazione = 3
            ipotesi.inflazione = 1
            let lavoro = DatiLavoro(tipo: .dipendente, redditoLavoro: 20_000, crescitaReddito: 2, montanteContributivo: 0)
            if let s = MotorePensionePubblica.stima(lavoro: lavoro, eta: 62, etaPensione: 65, reddito: nil, ipotesi: ipotesi) {
                verifica("F4 Capitalizzazione reale", s.capitalizzazioneReale, 1.980198, tolleranza: 0.000_01)
                verifica("F4 Montante con crescita e capitalizzazione", s.montante, 20_595.92)
                verifica("F4 Pensione lorda annua a 65 anni", s.lordaAnnua, 1_081.29)
                verifica("F4 Ultimo reddito in euro di oggi", s.redditoFinale, 20_808)
                verifica.vero("F4 Pochi anni di contributi: requisiti non raggiunti", !s.requisitoRaggiunto)
            } else {
                verifica.vero("F4 Stima della pensione calcolata", false)
            }
        }

        // F5. Montante stimato dagli anni (nessun estratto conto), uscita subito a 67 anni:
        // 10 anni × 30.000 × 33% = 99.000 € → 99.000 × 5,608% = 5.551,92 € lordi; sotto 8.500 € niente IRPEF:
        // netto 5.551,92, 427,07 al mese. Con 10 anni di contributi a 67 anni i requisiti (20 anni) non ci sono.
        do {
            let lavoro = DatiLavoro(tipo: .collaboratore, redditoLavoro: 30_000, anniContributi: 10, etaPensione: 67)
            if let s = MotorePensionePubblica.stima(lavoro: lavoro, eta: 67, etaPensione: 67, reddito: nil, ipotesi: senzaRivalutazione) {
                verifica("F5 Montante stimato dagli anni di contributi", s.montanteOggi, 99_000)
                verifica("F5 Pensione lorda annua", s.lordaAnnua, 5_551.92)
                verifica("F5 Pensione netta mensile (nessuna IRPEF)", s.nettaMensile, 427.07)
                verifica.vero("F5 Montante stimato e requisiti non raggiunti", s.montanteStimato && !s.requisitoRaggiunto)
                verifica.vero("F5 Avviso sui requisiti", s.avvisi.contains { $0.contains("requisiti non sono raggiunti") })
            } else {
                verifica.vero("F5 Stima della pensione calcolata", false)
            }
        }

        // F6. Aliquote e casi senza stima: artigiano 24% (1 anno, 40.000 € → 9.600 € di montante), cassa professionale
        // senza aliquota → nessuna stima; con l'aliquota indicata (14,5%) sì; sistema misto (primo contributo 1990) segnalato.
        do {
            let artigiano = DatiLavoro(tipo: .autonomo, redditoLavoro: 40_000, montanteContributivo: 0)
            let s = MotorePensionePubblica.stima(lavoro: artigiano, eta: 66, etaPensione: 67, reddito: nil, ipotesi: senzaRivalutazione)
            verifica("F6 Artigiano: aliquota 24%", s?.aliquota ?? 0, 24)
            verifica("F6 Artigiano: montante di un anno", s?.montante ?? 0, 9_600)
            let cassa = DatiLavoro(tipo: .cassaProfessionale, redditoLavoro: 50_000)
            verifica.vero("F6 Cassa professionale senza aliquota: nessuna stima",
                          MotorePensionePubblica.stima(lavoro: cassa, eta: 50, etaPensione: 67, reddito: nil) == nil
                          && MotorePensionePubblica.motivoAssente(cassa, reddito: nil) != nil)
            let cassaConAliquota = DatiLavoro(tipo: .cassaProfessionale, aliquotaContributiva: 14.5, redditoLavoro: 50_000)
            verifica("F6 Cassa professionale con l'aliquota indicata",
                     MotorePensionePubblica.stima(lavoro: cassaConAliquota, eta: 50, etaPensione: 67, reddito: nil)?.aliquota ?? 0, 14.5)
            let misto = DatiLavoro(tipo: .dipendente, redditoLavoro: 30_000, anniContributi: 36, annoPrimoContributo: 1990)
            let sm = MotorePensionePubblica.stima(lavoro: misto, eta: 60, etaPensione: 67, reddito: nil)
            verifica.vero("F6 Sistema misto: stima indicativa con avviso",
                          sm?.sistemaMisto == true && (sm?.avvisi.contains { $0.contains("sistema misto") } ?? false))
            verifica.vero("F6 Senza dati del lavoro: motivo spiegato", MotorePensionePubblica.motivoAssente(nil, reddito: 30_000) != nil)
            verifica.vero("F6 Con tipo e reddito: nessun motivo di assenza",
                          MotorePensionePubblica.motivoAssente(DatiLavoro(tipo: .dipendente), reddito: 30_000) == nil)
        }

        // F7. Stima del cliente e confronto con la pensione inserita a mano: nato il 15/6/1976, al 20/6/2026 ha 50 anni;
        // uscita a 67 dall'Analisi 360 → 17 anni; reddito dal profilo (35.000 € lordi) → 33% = 11.550 € il primo anno.
        // La pensione inserita a mano (1.400 €) vince nel divario; la stima si usa solo se l'analisi non è compilata.
        do {
            let data = AiutiProva.data(2026, 6, 20)
            var c = cliente("prova-pensione", "Carla Neri", nascita: AiutiProva.data(1976, 6, 15))
            c.profilo.redditoLordoAnnuo = 35_000
            c.profilo.lavoro = DatiLavoro(tipo: .dipendente, crescitaReddito: 0, montanteContributivo: 0)
            var prev = IpotesiPrevidenza()
            prev.etaPensione = 67
            prev.pensionePubblica = 1_400
            prev.redditoDesiderato = 2_200
            let s = MotorePensionePubblica.stima(cliente: c, previdenza: prev, data: data, ipotesi: senzaRivalutazione)
            verifica("F7 Età del cliente alla data", Double(s?.eta ?? 0), 50)
            verifica("F7 Anni alla pensione", Double(s?.anniAllaPensione ?? 0), 17)
            verifica("F7 Reddito dal profilo", s?.redditoOggi ?? 0, 35_000)
            verifica("F7 Montante: 17 anni × 11.550 €", s?.montante ?? 0, 17 * 11_550)
            verifica("F7 Pensione inserita a mano: vince", MotorePensionePubblica.pensioneDaUsare(prev, stima: s, inseritaAMano: true), 1_400)
            verifica("F7 Analisi non compilata: si usa la stima",
                     MotorePensionePubblica.pensioneDaUsare(prev, stima: s, inseritaAMano: false), MotoreFiscale.centesimi(s?.nettaMensile ?? -1))
            // Nel piano previdenziale la stima è affiancata: pensione pubblica e divario restano quelli dell'analisi
            let piano = MotorePrevidenza.calcola([], cliente: c, analisi: prev, data: data)
            let stimaPiano = MotorePensionePubblica.stima(cliente: c, previdenza: prev, data: data)
            verifica("F7 Piano: pensione pubblica dell'analisi", piano.pensionePubblica, 1_400)
            verifica("F7 Piano: divario con la pensione dell'analisi", piano.divario, 800)
            verifica("F7 Piano: stima affiancata", piano.stimaPensione?.nettaMensile ?? -1, stimaPiano?.nettaMensile ?? -2)
            verifica("F7 Piano: divario con la stima", piano.divarioStimato ?? -1, max(0, 2_200 - (stimaPiano?.nettaMensile ?? 0)))
        }
    }

    // MARK: - Protezione per persona (miglioramento 8)

    private static func protezione(_ verifica: VerificaCalcoli) {
        // F8. Debito residuo alla francese: 100.000 € al 3,6% per 24 mesi (i = 0,3% al mese).
        // Rata = 100.000 × 0,003 / (1 − 1,003^−24) = 4.324,71 €; dopo 12 mesi
        // residuo = 100.000 × (1,003^24 − 1,003^12) / (1,003^24 − 1) = 50.898,56 €. Senza tasso: quote uguali,
        // dopo 6 mesi su 24 restano 75.000 €.
        do {
            verifica("F8 Rata alla francese", MotoreProtezioneFamiglia.rataDebito(capitale: 100_000, tasso: 3.6, mesi: 24), 4_324.71)
            verifica("F8 Debito residuo dopo 12 mesi", MotoreProtezioneFamiglia.debitoResiduo(capitale: 100_000, tasso: 3.6, mesi: 24, dopo: 12), 50_898.56)
            verifica("F8 Debito residuo senza tasso", MotoreProtezioneFamiglia.debitoResiduo(capitale: 100_000, tasso: nil, mesi: 24, dopo: 6), 75_000)
            verifica("F8 Debito estinto alla fine", MotoreProtezioneFamiglia.debitoResiduo(capitale: 100_000, tasso: 3.6, mesi: 24, dopo: 24), 0)
        }

        // F9. Famiglia di prova al 30/6/2026: Paolo (45 anni, 30.000 € netti), Paola coniuge (43 anni, 10.000 € netti),
        // Leo (10 anni, a carico: 15 anni ai 25) e Sara (14 anni, a carico: 11 anni). Analisi 360: fabbisogno 2.500 € al mese,
        // spese immediate 10.000, capitale disponibile 20.000, entrate sostitutive 500 € al mese, 10 anni di sostegno.
        // Debiti: mutuo 120.000 € al 3% fino al 30/6/2041 (180 mesi) cointestato al 50%; prestito 8.000 € tutto di Paolo.
        // Quote del reddito: 30.000 / 40.000 = 75% e 25%.
        // Paolo, caso morte: debiti 60.000 + 8.000 = 68.000; sostegno 2.500 × 12 × 75% = 22.500 l'anno × 15 anni = 337.500;
        //   fabbisogno 68.000 + 10.000 + 337.500 − 20.000 = 395.500. Coperture: TCM 200.000 + TCM decrescente 120.000
        //   (2021–2041, 240 mesi, ne restano 180: 120.000 × 180 / 240 = 90.000) = 290.000 → scoperti 105.500.
        //   La TCM scaduta nel 2025 non conta.
        //   Invalidità: (30.000 − 500 × 12) × (67 − 45) = 24.000 × 22 = 528.000; IPM 150.000 → scoperti 378.000.
        //   Non autosufficienza: 1.500 × 12 × 5 = 90.000, nessuna copertura.
        // Paola, caso morte: debiti 120.000 × 50% = 60.000; sostegno 2.500 × 12 × 25% = 7.500 × 15 = 112.500;
        //   fabbisogno 60.000 + 10.000 + 112.500 − 20.000 = 162.500; TCM 100.000 (riconosciuta dal nome) → 62.500,
        //   con la proposta da 50.000 → 12.500. La sua TCM scade nel 2036, prima dei 15 anni che servono: avviso.
        //   Invalidità: 10.000 × (67 − 43) = 240.000. LTC: 90.000 − 30.000 = 60.000.
        // Il fabbisogno del nucleo resta quello di prima: 10.000 + 2.500 × 12 × 10 − 20.000 = 290.000.
        do {
            let data = AiutiProva.data(2026, 6, 30)
            var c = cliente("f-paolo", "Paolo Verdi", nascita: AiutiProva.data(1981, 3, 10))
            c.profilo.redditoNettoAnnuo = 30_000
            var paola = Familiare(id: "f-paola", nome: "Paola Verdi", relazione: .coniuge, dataNascita: AiutiProva.data(1983, 5, 1))
            paola.redditoNettoAnnuo = 10_000
            let leo = Familiare(id: "f-leo", nome: "Leo Verdi", relazione: .figlio, dataNascita: AiutiProva.data(2016, 1, 20), aCarico: true)
            let sara = Familiare(id: "f-sara", nome: "Sara Verdi", relazione: .figlia, dataNascita: AiutiProva.data(2011, 9, 1), aCarico: true)
            c.famiglia = [paola, leo, sara]
            var ip = IpotesiProtezione()
            ip.fabbisognoMensile = 2_500; ip.anniSostegno = 10; ip.debiti = 0; ip.speseImmediate = 10_000
            ip.capitaleDisponibile = 20_000; ip.entrateSostitutive = 500

            let posizioni: [Posizione] = [
                AiutiProva.posizione("Mutuo", .debiti, 120_000) { $0.scadenza = AiutiProva.data(2041, 6, 30); $0.tassoDebito = 3; $0.quotaDebito = 50 },
                AiutiProva.posizione("Prestito auto", .debiti, 8_000) { $0.scadenza = AiutiProva.data(2028, 6, 30) },
                AiutiProva.posizione("TCM Paolo", .protezione, 0) {
                    $0.rischio = .vita; $0.capitaleAssicurato = 200_000; $0.assicuratoId = "f-paolo"; $0.scadenza = AiutiProva.data(2046, 6, 30)
                },
                AiutiProva.posizione("TCM mutuo", .protezione, 0) {
                    $0.rischio = .vita; $0.capitaleAssicurato = 120_000; $0.capitaleDecrescente = true; $0.assicuratoId = "f-paolo"
                    $0.decorrenza = AiutiProva.data(2021, 6, 30); $0.scadenza = AiutiProva.data(2041, 6, 30)
                },
                AiutiProva.posizione("TCM vecchia", .protezione, 0) {
                    $0.rischio = .vita; $0.capitaleAssicurato = 500_000; $0.assicuratoId = "f-paolo"; $0.scadenza = AiutiProva.data(2025, 1, 1)
                },
                AiutiProva.posizione("TCM Paola", .protezione, 0) {
                    $0.rischio = .vita; $0.capitaleAssicurato = 100_000; $0.assicurato = "Paola Verdi"; $0.scadenza = AiutiProva.data(2036, 6, 30)
                },
                AiutiProva.posizione("Proposta TCM Paola", .protezione, 0) {
                    $0.stato = .proposta; $0.esito = .bozza; $0.rischio = .vita; $0.capitaleAssicurato = 50_000; $0.assicuratoId = "f-paola"
                },
                AiutiProva.posizione("Invalidità permanente", .protezione, 0) { $0.rischio = .invalidita; $0.capitaleAssicurato = 150_000 },
                AiutiProva.posizione("LTC Paola", .protezione, 0) { $0.rischio = .ltc; $0.capitaleAssicurato = 30_000; $0.assicuratoId = "f-paola" },
            ]
            let e = MotoreProtezioneFamiglia.calcola(posizioni, cliente: c, analisi: ip, data: data)
            verifica("F9 Nucleo: fabbisogno caso morte invariato", e.fabbisogno, 290_000)
            verifica("F9 Persone che portano reddito", Double(e.persone.count), 2)
            verifica.vero("F9 TCM riconosciuta dal nome dell'assicurato",
                          MotoreProtezioneFamiglia.assicurato(posizioni[5], cliente: c) == "f-paola")
            verifica("F9 Capitale decrescente oggi", MotoreProtezioneFamiglia.capitaleAttuale(posizioni[3], al: data), 90_000)
            if let paolo = e.persone.first(where: { $0.id == "f-paolo" }) {
                verifica("F9 Paolo: quota del reddito", paolo.quotaReddito, 0.75, tolleranza: 0.000_1)
                verifica("F9 Paolo: debiti a carico", paolo.debiti, 68_000)
                verifica("F9 Paolo: mesi residui del mutuo", Double(paolo.mesiDebiti ?? 0), 180)
                verifica("F9 Paolo: anni di sostegno (Leo fino a 25 anni)", Double(paolo.anniSostegno), 15)
                verifica("F9 Paolo: sostegno alla famiglia", paolo.sostegno, 337_500)
                verifica("F9 Paolo: fabbisogno caso morte", paolo.fabbisognoMorte, 395_500)
                verifica("F9 Paolo: capitale caso morte (TCM + decrescente)", paolo.capitaleMorte, 290_000)
                verifica("F9 Paolo: scoperto caso morte", paolo.divarioMorte, 105_500)
                verifica("F9 Paolo: fabbisogno invalidità", paolo.fabbisognoInvalidita, 528_000)
                verifica("F9 Paolo: scoperto invalidità", paolo.divarioInvalidita, 378_000)
                verifica("F9 Paolo: scoperto non autosufficienza", paolo.divarioLTC, 90_000)
                verifica("F9 Paolo: anni di copertura (mutuo 15, figli 15)", Double(paolo.anniCopertura), 15)
            } else {
                verifica.vero("F9 Paolo presente", false)
            }
            if let p = e.persone.first(where: { $0.id == "f-paola" }) {
                verifica("F9 Paola: debiti a carico (metà mutuo)", p.debiti, 60_000)
                verifica("F9 Paola: fabbisogno caso morte", p.fabbisognoMorte, 162_500)
                verifica("F9 Paola: scoperto caso morte", p.divarioMorte, 62_500)
                verifica("F9 Paola: scoperto con la proposta", p.divarioMorteConProposte, 12_500)
                verifica("F9 Paola: fabbisogno invalidità", p.fabbisognoInvalidita, 240_000)
                verifica("F9 Paola: scoperto non autosufficienza", p.divarioLTC, 60_000)
                verifica.vero("F9 Paola: avviso sulla TCM che scade prima", p.avvisi.contains { $0.contains("TCM Paola scade") })
            } else {
                verifica.vero("F9 Paola presente", false)
            }
            // Piano del mutuo: 120.000 € al 3% per 180 mesi (i = 0,25%): residuo dopo un anno
            // 120.000 × (1,0025^180 − 1,0025^12) / (1,0025^180 − 1) = 113.567,66 €; 16 anniversari, l'ultimo a zero.
            let piano = MotoreProtezioneFamiglia.pianoDebito(posizioni[0], al: data)
            verifica("F9 Piano del mutuo: anniversari", Double(piano.count), 16)
            verifica("F9 Piano del mutuo: residuo dopo un anno", piano.count > 1 ? piano[1] : 0, 113_567.66)
            verifica("F9 Piano del mutuo: estinto alla fine", piano.last ?? -1, 0)
        }

        // F10. Familiare non autosufficiente: sostegno per tutta la vita (fino a 85 anni). Cliente unico percettore (40 anni),
        // fratello non autosufficiente di 55 anni → 30 anni; un figlio di 20 anni con un reddito non è a carico.
        do {
            let data = AiutiProva.data(2026, 6, 30)
            var c = cliente("f-ugo", "Ugo Gialli", nascita: AiutiProva.data(1986, 1, 1))
            c.profilo.redditoNettoAnnuo = 25_000
            var fratello = Familiare(id: "f-dino", nome: "Dino Gialli", relazione: .fratelloSorella, dataNascita: AiutiProva.data(1971, 1, 1))
            fratello.nonAutosufficiente = true
            var figlio = Familiare(id: "f-ivo", nome: "Ivo Gialli", relazione: .figlio, dataNascita: AiutiProva.data(2006, 1, 1))
            figlio.redditoNettoAnnuo = 12_000
            c.famiglia = [fratello, figlio]
            let persone = MotoreProtezioneFamiglia.perPersona([], cliente: c, analisi: IpotesiProtezione(), data: data)
            let ugo = persone.first { $0.id == "f-ugo" }
            verifica("F10 Anni di sostegno al fratello non autosufficiente", Double(ugo?.anniSostegno ?? 0), 30)
            verifica("F10 Dipendenti (il figlio con reddito no)", Double(ugo?.dipendenti.count ?? 0), 1)
            verifica.vero("F10 Sostegno a vita segnato", ugo?.dipendenti.first?.aVita == true)
        }
    }

    // MARK: - Fisco delle polizze (miglioramento 9)

    private static func fisco(_ verifica: VerificaCalcoli) {
        let data = AiutiProva.data(2026, 6, 30)

        // F11. Detrazione del 19% dei premi (art. 15 TUIR): vita fino a 530 €, con la LTC fino a 1.291,14 € in tutto.
        // 300 + 500 = 800; 700 di soli premi vita → 530; 1.500 di soli premi LTC → 1.291,14.
        // Riduzione per reddito (art. 15, c. 3-bis): piena fino a 120.000, a 180.000 (240.000 − 180.000) / 120.000 = 50%, nulla da 240.000.
        do {
            verifica("F11 Premi detraibili: 300 vita + 500 LTC", RegoleFiscali.detraibili(vita: 300, ltc: 500), 800)
            verifica("F11 Premi detraibili: vita oltre il limite", RegoleFiscali.detraibili(vita: 700, ltc: 0), 530)
            verifica("F11 Premi detraibili: LTC oltre il limite", RegoleFiscali.detraibili(vita: 0, ltc: 1_500), 1_291.14)
            verifica("F11 Detrazione piena fino a 120.000 €", RegoleFiscali.quotaDetrazione(reddito: 100_000), 1)
            verifica("F11 Detrazione ridotta a 180.000 €", RegoleFiscali.quotaDetrazione(reddito: 180_000), 0.5, tolleranza: 0.000_1)
            verifica("F11 Nessuna detrazione da 240.000 €", RegoleFiscali.quotaDetrazione(reddito: 240_000), 0)
            verifica("F11 Detrazione piena senza reddito indicato", RegoleFiscali.quotaDetrazione(reddito: nil), 1)
        }

        // F12. Detrazione per persona: Marco (180.000 € di reddito) paga la sua TCM (50 € al mese = 600) e la LTC del figlio
        // a carico (300); Anna, coniuge non a carico, paga la sua TCM (500). Marco: min(530, 600) + 300 = 830 × 19% × 50% = 78,85;
        // Anna: 500 × 19% = 95,00; totale 173,85. Sommati insieme (come il nucleo) i premi vita sarebbero 530 + 300 = 830.
        do {
            var c = cliente("f-marco", "Marco Blu", nascita: AiutiProva.data(1975, 1, 1))
            c.profilo.redditoLordoAnnuo = 180_000
            let anna = Familiare(id: "f-anna", nome: "Anna Blu", relazione: .coniuge, dataNascita: AiutiProva.data(1977, 1, 1))
            let figlio = Familiare(id: "f-teo", nome: "Teo Blu", relazione: .figlio, dataNascita: AiutiProva.data(2012, 1, 1), aCarico: true)
            c.famiglia = [anna, figlio]
            let coperture: [Posizione] = [
                AiutiProva.posizione("TCM Marco", .protezione, 0) { $0.clienteId = "f-marco"; $0.rischio = .vita; $0.premio = 50; $0.frequenza = .mensile; $0.assicuratoId = "f-marco" },
                AiutiProva.posizione("TCM Anna", .protezione, 0) { $0.clienteId = "f-marco"; $0.rischio = .vita; $0.premio = 500; $0.frequenza = .annuale; $0.assicuratoId = "f-anna" },
                AiutiProva.posizione("LTC Teo", .protezione, 0) { $0.clienteId = "f-marco"; $0.rischio = .ltc; $0.premio = 300; $0.frequenza = .annuale; $0.assicuratoId = "f-teo" },
            ]
            let d = FiscoPolizze.detrazioniPerPersona(cliente: c, posizioni: coperture, data: data)
            let marco = d.first { $0.id == "f-marco" }
            let annaD = d.first { $0.id == "f-anna" }
            verifica("F12 Marco: premi detraibili (vita nel limite + LTC del figlio a carico)", marco?.detraibili ?? 0, 830)
            verifica("F12 Marco: detrazione ridotta al 50%", marco?.detrazione ?? 0, 78.85)
            verifica("F12 Anna: detrazione sui suoi premi", annaD?.detrazione ?? 0, 95)
            let r = FiscoPolizze.riepilogo(cliente: c, posizioni: coperture, data: data)
            verifica("F12 Detrazione totale per persona", r.detrazioneTotale, 173.85)
            verifica("F12 Nucleo insieme: premi detraibili", RegoleFiscali.premiDetraibili(coperture), 830)
        }

        // F13. Al decesso (al 30/6/2026):
        // TCM da 150.000 €: tutto rischio demografico, esente IRPEF e fuori successione → 150.000.
        // Ramo I: valore 54.300, premi 50.000, 60% in titoli di Stato → aliquota 26 × 40% + 12,5 × 60% = 17,90%;
        //   imposta 4.300 × 17,9% = 769,70; niente bollo (Ramo I); netto 53.530,30, fuori successione.
        // Unit linked: valore 30.000, premi 25.000, capitale caso morte 30.300 (maggiorazione 300 esente); imposta 26% × 5.000 = 1.300;
        //   bollo maturato 0,20% × 30.000 × 2 anni (730 giorni / 365,25) = 119,92; netto 30.300 − 1.300 − 119,92 = 28.880,08.
        // Capitalizzazione (Ramo V): valore 50.000, premi 45.000 → imposta 1.300, nessuna parte esente, nell'asse.
        // Fondo pensione: 20.000 € tutti dedotti, prima adesione 20 anni fa → 15 − 5 × 0,30 = 13,50%: imposta 2.700, netto 17.300.
        do {
            let tcm = AiutiProva.posizione("TCM", .protezione, 0) { $0.rischio = .vita; $0.capitaleAssicurato = 150_000 }
            let morte = FiscoPolizze.alDecesso(tcm, data: data)
            verifica("F13 TCM: netto ai beneficiari", morte?.netto ?? 0, 150_000)
            verifica("F13 TCM: tutto esente IRPEF", morte?.parteEsente ?? 0, 150_000)
            verifica.vero("F13 TCM: fuori dalla successione", morte?.fuoriSuccessione == true)
            let scaduta = AiutiProva.posizione("TCM scaduta", .protezione, 0) {
                $0.rischio = .vita; $0.capitaleAssicurato = 150_000; $0.scadenza = AiutiProva.data(2025, 1, 1)
            }
            verifica.vero("F13 TCM scaduta: non paga", FiscoPolizze.alDecesso(scaduta, data: data) == nil)

            let ramoI = AiutiProva.posizione("Rivalutabile", .risparmio, 54_300, canale: .alleanza) {
                $0.tipologia = "Polizza rivalutabile a premio unico (Ramo I)"; $0.totaleVersato = 50_000; $0.quotaTitoliStato = 60
            }
            let r1 = FiscoPolizze.alDecesso(ramoI, data: data)
            verifica("F13 Ramo I: aliquota ponderata", r1?.aliquota ?? 0, 17.9, tolleranza: 0.000_1)
            verifica("F13 Ramo I: imposta sul guadagno", r1?.imposta ?? 0, 769.70)
            verifica("F13 Ramo I: netto ai beneficiari", r1?.netto ?? 0, 53_530.30)
            verifica.vero("F13 Ramo I: fuori successione, nessuna parte esente", r1?.fuoriSuccessione == true && r1?.parteEsente == 0)

            let unit = AiutiProva.posizione("Unit", .investimento, 30_000, canale: .alleanza) {
                $0.tipologia = "Polizza unit linked (Ramo III)"; $0.totaleVersato = 25_000; $0.capitaleAssicurato = 30_300
                $0.decorrenza = AiutiProva.data(2024, 6, 30)
            }
            let u = FiscoPolizze.alDecesso(unit, data: data)
            verifica("F13 Unit: maggiorazione caso morte esente", u?.parteEsente ?? 0, 300)
            verifica("F13 Unit: imposta sul guadagno finanziario", u?.imposta ?? 0, 1_300)
            verifica("F13 Unit: bollo maturato", u?.bolloMaturato ?? 0, 119.92)
            verifica("F13 Unit: netto ai beneficiari", u?.netto ?? 0, 28_880.08)

            let cap = AiutiProva.posizione("Capitalizzazione", .risparmio, 50_000, canale: .alleanza) {
                $0.tipologia = "Contratto di capitalizzazione rivalutabile (Ramo V)"; $0.totaleVersato = 45_000
            }
            let rc = FiscoPolizze.alDecesso(cap, data: data)
            verifica("F13 Capitalizzazione: imposta", rc?.imposta ?? 0, 1_300)
            verifica.vero("F13 Capitalizzazione: nell'asse, nessuna parte esente", rc?.fuoriSuccessione == false && rc?.parteEsente == 0)

            let fp = AiutiProva.posizione("Fondo pensione", .previdenza, 20_000) {
                $0.totaleVersato = 20_000; $0.contributiNonDedotti = 0; $0.primaAdesione = AiutiProva.data(2006, 6, 30)
            }
            let rp = FiscoPolizze.alDecesso(fp, data: data)
            verifica("F13 Previdenza: aliquota dopo 20 anni", rp?.aliquota ?? 0, 13.5, tolleranza: 0.000_1)
            verifica("F13 Previdenza: imposta", rp?.imposta ?? 0, 2_700)
            verifica("F13 Previdenza: netto", rp?.netto ?? 0, 17_300)
            let fondo = AiutiProva.posizione("Fondo azionario", .investimento, 10_000) { $0.tipologia = "Fondo comune" }
            verifica.vero("F13 Fondo comune: nell'asse, non è una polizza", FiscoPolizze.alDecesso(fondo, data: data) == nil)
            // Successione: polizze vita e capitali caso morte ai beneficiari, capitalizzazione e fondi nell'asse
            verifica.vero("F13 Successione: TCM ai beneficiari", MotoreSuccessione.classifica(tcm, oggi: data).1 == .beneficiari)
            verifica.vero("F13 Successione: Ramo I ai beneficiari", MotoreSuccessione.classifica(ramoI, oggi: data).1 == .beneficiari)
            verifica.vero("F13 Successione: capitalizzazione nell'asse", MotoreSuccessione.classifica(cap, oggi: data).1 == .asse)
            verifica.vero("F13 Successione: fondo nell'asse", MotoreSuccessione.classifica(fondo, oggi: data).1 == .asse)
        }

        // F14. Bollo dello 0,20%: esenti il Ramo I e i fondi pensione; soggetti Ramo III e Ramo V (capitalizzazione, anche se
        // rivalutabile: 50.000 × 0,20% = 100 €); conto corrente 34,20 € solo oltre 5.000 € di giacenza.
        // Aliquota sui guadagni: 26% × 40% + 12,5% × 60% = 17,90% con il 60% in titoli di Stato.
        do {
            let ramoI = AiutiProva.posizione("Rivalutabile", .risparmio, 10_000) { $0.tipologia = "Polizza rivalutabile (Ramo I)" }
            let cap = AiutiProva.posizione("Capitalizzazione", .risparmio, 50_000) { $0.tipologia = "Contratto di capitalizzazione rivalutabile" }
            let fp = AiutiProva.posizione("Fondo pensione", .previdenza, 10_000)
            let unit = AiutiProva.posizione("Unit", .investimento, 10_000) { $0.tipologia = "Polizza unit linked (Ramo III)" }
            verifica("F14 Bollo: Ramo I esente", ramoI.quotaBollo, 0)
            verifica("F14 Bollo: capitalizzazione soggetta", cap.quotaBollo, 1)
            verifica("F14 Bollo annuo della capitalizzazione", MotoreFiscale.bolloAnnuo(cap, valore: 50_000), 100)
            verifica("F14 Bollo: fondo pensione esente", fp.quotaBollo, 0)
            verifica("F14 Bollo: Ramo III soggetto", unit.quotaBollo, 1)
            let conto = AiutiProva.posizione("Conto corrente", .liquidita, 4_000)
            verifica("F14 Conto corrente sotto 5.000 €", MotoreFiscale.bolloAnnuo(conto, valore: 4_000), 0)
            verifica("F14 Conto corrente oltre 5.000 €", MotoreFiscale.bolloAnnuo(conto, valore: 6_000), 34.20)
            verifica("F14 Aliquota con il 60% in titoli di Stato", RegoleFiscali.aliquotaEffettiva(quotaTitoliStato: 60), 17.9, tolleranza: 0.000_1)
            verifica("F14 Aliquota senza titoli di Stato", RegoleFiscali.aliquotaEffettiva(quotaTitoliStato: 0), 26)
            verifica("F14 Aliquota tutta in titoli di Stato", RegoleFiscali.aliquotaEffettiva(quotaTitoliStato: 100), 12.5)
        }

        // F15. Previdenza complementare: prestazione 15% fino al 15° anno, −0,30 punti l'anno, minimo 9% dal 35°;
        // 23% sulle anticipazioni per casa e ulteriori esigenze; rendimenti del fondo al 20%, 12,5% sui titoli di Stato:
        // con il 50% in titoli di Stato 20 × 50% + 12,5 × 50% = 16,25%; 4% lordo con l'1,5% di costi:
        // (1,04 × 0,985 − 1) = 2,44% → 2,44 × (1 − 16,25%) = 2,0435%; senza quota 2,44 × 0,8 = 1,952%; un anno negativo non si tassa.
        do {
            verifica("F15 Prestazione dopo 15 anni", RegoleFiscali.aliquotaPrevidenza(anni: 15), 15)
            verifica("F15 Prestazione dopo 16 anni", RegoleFiscali.aliquotaPrevidenza(anni: 16), 14.7, tolleranza: 0.000_1)
            verifica("F15 Prestazione dopo 25 anni", RegoleFiscali.aliquotaPrevidenza(anni: 25), 12, tolleranza: 0.000_1)
            verifica("F15 Prestazione dopo 35 anni", RegoleFiscali.aliquotaPrevidenza(anni: 35), 9, tolleranza: 0.000_1)
            verifica("F15 Prestazione dopo 40 anni (minimo 9%)", RegoleFiscali.aliquotaPrevidenza(anni: 40), 9, tolleranza: 0.000_1)
            verifica("F15 Anticipazione per la casa", CausaPrevidenza.anticipazioneCasa.aliquota(anni: 30), 23)
            verifica("F15 Rendimenti del fondo senza titoli di Stato", RegoleFiscali.aliquotaRendimentiPrevidenza(quotaTitoliStato: nil), 20)
            verifica("F15 Rendimenti del fondo con il 50% in titoli di Stato", RegoleFiscali.aliquotaRendimentiPrevidenza(quotaTitoliStato: 50), 16.25, tolleranza: 0.000_1)
            verifica("F15 Rendimenti del fondo tutti in titoli di Stato", RegoleFiscali.aliquotaRendimentiPrevidenza(quotaTitoliStato: 100), 12.5, tolleranza: 0.000_1)
            verifica("F15 Rendimento netto con il 50% in titoli di Stato",
                     RegoleFiscali.rendimentoNettoPrevidenza(lordo: 4, costo: 1.5, quotaTitoliStato: 50), 2.0435, tolleranza: 0.000_1)
            verifica("F15 Rendimento netto senza quota: come prima",
                     RegoleFiscali.rendimentoNettoPrevidenza(lordo: 4, costo: 1.5, quotaTitoliStato: nil), 1.952, tolleranza: 0.000_1)
            verifica("F15 Rendimento negativo non tassato",
                     RegoleFiscali.rendimentoNettoPrevidenza(lordo: -2, costo: 0, quotaTitoliStato: 50), -2, tolleranza: 0.000_1)
            // Le proiezioni del fondo (schede, obiettivi, sostituzione, scenari) usano la stessa aliquota del piano:
            // 20 × 50% + 12,5 × 50% = 16,25% con la quota indicata, 20% senza (come prima)
            let fondoConQuota = AiutiProva.posizione("Fondo pensione", .previdenza, 10_000) { $0.quotaTitoliStato = 50 }
            verifica("F15 Proiezione del fondo pensione con il 50% in titoli di Stato",
                     ParametriProiezione(posizione: fondoConQuota).tassazioneAnnua, 16.25, tolleranza: 0.000_1)
            let fondoSenzaQuota = AiutiProva.posizione("Fondo pensione", .previdenza, 10_000)
            verifica("F15 Proiezione del fondo pensione senza quota: 20% come prima",
                     ParametriProiezione(posizione: fondoSenzaQuota).tassazioneAnnua, 20, tolleranza: 0.000_1)
        }

        // F16. Deducibilità con il datore di lavoro (limite 2026: 5.300 €; il TFR non conta):
        // cliente 3.000 + datore 2.000 + TFR 2.500 → al cliente restano 3.300: deduce 3.000, spazio 300, nessuna eccedenza.
        // Cliente 4.000 + datore 2.000 = 6.000 → deduce 3.300, eccedenza 700, spazio 0.
        // Reddito 40.000 €: 3.000 dedotti al 33% = 990; usando tutto lo spazio (3.300) 1.089 → 99 in più.
        do {
            verifica("F16 Limite di deducibilità 2026", RegoleFiscali.limiteDeducibilita, 5_300)
            let a = DeducibilitaPrevidenza(lavoratore: 3_000, datore: 2_000, tfr: 2_500)
            verifica("F16 Deducibili del cliente", a.deducibili, 3_000)
            verifica("F16 Spazio che resta", a.spazio, 300)
            verifica("F16 Nessuna eccedenza", a.eccedenza, 0)
            verifica("F16 Risparmio IRPEF con 40.000 €", a.risparmio(reddito: 40_000), 990)
            verifica("F16 Risparmio in più usando lo spazio", a.risparmioPossibile(reddito: 40_000), 99)
            let b = DeducibilitaPrevidenza(lavoratore: 4_000, datore: 2_000)
            verifica("F16 Oltre il limite: deducibili", b.deducibili, 3_300)
            verifica("F16 Oltre il limite: eccedenza", b.eccedenza, 700)
            verifica("F16 Oltre il limite: spazio", b.spazio, 0)
        }

        // F17. Piano previdenziale con datore e TFR (rendimento 0, 57 → 67 anni, adesione il 30/6/2016):
        // 10.000 € oggi + 10 anni × (250 × 12 + 1.200 + 1.800) = 6.000 l'anno → montante 70.000; tutto tassabile (contributi nel limite,
        // TFR sempre): 70.000 × 13,50% (20 anni di partecipazione) = 9.450. Deducibili del cliente: min(3.000, 5.300 − 1.200) = 3.000;
        // spazio 5.300 − 1.200 − 3.000 = 1.100; reddito 40.000: risparmio 990, con tutto lo spazio 4.100 × 33% = 1.353 → 363 in più.
        // Oltre il limite: 400 × 12 = 4.800 + 1.200 = 6.000 > 5.300: dei 60.000 versati in 10 anni si tassano 60.000 × 5.300 / 6.000 = 53.000,
        // imposta 53.000 × 13,5% = 7.155; deducibili del cliente 4.100, spazio 0.
        do {
            var ipotesi = IpotesiPrevidenza()
            ipotesi.eta = 57; ipotesi.etaPensione = 67; ipotesi.redditoDesiderato = 2_000; ipotesi.pensionePubblica = 1_500; ipotesi.anniIntegrazione = 25
            var c = cliente("prova", "Lia Rosa", nascita: nil)
            c.profilo.redditoLordoAnnuo = 40_000
            let fondo = AiutiProva.posizione("Fondo con datore", .previdenza, 10_000) {
                $0.totaleVersato = 10_000; $0.rendimentoAtteso = 0; $0.premio = 250; $0.frequenza = .mensile
                $0.contributoDatore = 1_200; $0.tfrConferito = 1_800; $0.decorrenza = AiutiProva.data(2016, 6, 30)
            }
            let e = MotorePrevidenza.calcola([fondo], cliente: c, analisi: ipotesi, data: data)
            if let p = e.piani.first {
                verifica("F17 Montante con datore e TFR", p.montante, 70_000)
                verifica("F17 Parte tassabile alla prestazione", p.dedotti, 70_000)
                verifica("F17 Imposta sulla prestazione", p.imposta, 9_450)
            } else {
                verifica.vero("F17 Piano presente", false)
            }
            verifica("F17 Deducibili del cliente", e.deducibiliOggi, 3_000)
            verifica("F17 Spazio deducibile", e.spazioResiduo, 1_100)
            verifica("F17 Risparmio IRPEF oggi", e.risparmioOggi, 990)
            verifica("F17 Risparmio in più usando lo spazio", e.risparmioPossibile, 363)
            verifica.vero("F17 Nessuna stima della pensione senza dati del lavoro", e.stimaPensione == nil)
            let fa = MotoreFineAnno.calcola(cliente: c, posizioni: [fondo], oggi: data)
            verifica("F17 Fine anno: spazio con il datore", fa.spazio, 1_100)
            verifica("F17 Fine anno: risparmio possibile", fa.risparmioPossibile, 363)

            let oltre = AiutiProva.posizione("Fondo oltre il limite", .previdenza, 0) {
                $0.totaleVersato = 0; $0.rendimentoAtteso = 0; $0.premio = 400; $0.frequenza = .mensile
                $0.contributoDatore = 1_200; $0.decorrenza = AiutiProva.data(2016, 6, 30)
            }
            let eo = MotorePrevidenza.calcola([oltre], cliente: c, analisi: ipotesi, data: data)
            verifica("F17 Oltre il limite: parte tassabile", eo.piani.first?.dedotti ?? 0, 53_000)
            verifica("F17 Oltre il limite: imposta", eo.piani.first?.imposta ?? 0, 7_155)
            verifica("F17 Oltre il limite: deducibili del cliente", eo.deducibiliOggi, 4_100)
            verifica("F17 Oltre il limite: nessuno spazio", eo.spazioResiduo, 0)
        }

        // F18. Dati di prova: ogni cliente ha i dati del lavoro e quindi la sua stima della pensione; Sofia (contributi
        // dal 1993) è nel sistema misto. Nella famiglia di Marco portano reddito Marco (31.500 € netti) ed Elena (16.000):
        // quota di Marco 31.500 / 47.500 = 66,3158%; la sua TCM da 300.000 € è sua (assicuratoId), gli infortuni non contano.
        do {
            let clienti = DatiDemo.clienti()
            let posizioni = DatiDemo.posizioni()
            for c in clienti {
                verifica.vero("F18 Stima della pensione di \(c.nome)",
                              MotorePensionePubblica.stima(cliente: c, previdenza: IpotesiPrevidenza()) != nil)
            }
            let sofia = clienti.first { $0.id == "sofia" }
            verifica.vero("F18 Sofia nel sistema misto",
                          sofia.flatMap { MotorePensionePubblica.stima(cliente: $0, previdenza: IpotesiPrevidenza()) }?.sistemaMisto == true)
            if let marco = clienti.first(where: { $0.id == "marco" }) {
                let persone = MotoreProtezioneFamiglia.perPersona(posizioni.filter { $0.clienteId == "marco" }, cliente: marco,
                                                                  analisi: IpotesiProtezione())
                verifica("F18 Marco ed Elena portano reddito", Double(persone.count), 2)
                let m = persone.first { $0.id == "marco" }
                verifica("F18 Quota del reddito di Marco", m?.quotaReddito ?? 0, 0.663158, tolleranza: 0.000_01)
                verifica("F18 TCM di Marco attribuita a lui", m?.capitaleMorte ?? 0, 300_000)
                verifica.vero("F18 Elena tra le persone", persone.contains { $0.id == "fam-marco-elena" })
            } else {
                verifica.vero("F18 Marco presente nei dati di prova", false)
            }
        }
    }
}
