import Foundation

/// Prove delle polizze multiramo a due parti (gestione separata e fondi con dati separati): proiezione a due
/// saldi (M1–M5 sui parametri), archivio (M11), riconoscimento (M12, parte `Posizione`), compatibilità
/// (M13, M13c), più le letture e le funzioni comuni di `MotoreMultiramo` (M15–M18). Chiamate da
/// `ProvaCalcoli.esegui()` prima del riepilogo: gli errori si sommano. Valori attesi calcolati a parte con
/// la replica in Python del motore mensile (conti della specifica del giro 2).
/// In fondo chiama le prove degli altri file: motori a valle, rischio, dati di prova.
enum ProvaCalcoliMultiramo {
    static func esegui(_ verifica: VerificaCalcoli) {
        proiezione(verifica)
        posizioni(verifica)
        archivio(verifica)
        ProvaCalcoliMultiramoMotori.esegui(verifica)
        ProvaCalcoliMultiramoRischio.esegui(verifica)
        ProvaCalcoliMultiramoDati.esegui(verifica)
    }

    /// Lo scenario base di M1–M4: 50.000 € per 10 anni, 60% in gestione separata al 2,8% lordo con
    /// trattenuto 1,2 e minimo 0 consolidato; 40% nei fondi al 5% lordo con costi del 2% e bollo dello 0,2%.
    private static func parametriBase(_ m: (inout ParametriProiezione) -> Void = { _ in }) -> ParametriProiezione {
        var par = ParametriProiezione(capitaleIniziale: 50_000, versamento: 0, frequenza: .unica, anni: 10,
                                      rendimento: 5, costoIngresso: 0, costoAnnuo: 2 + 0.2, aliquotaFiscale: 26, inflazione: 2)
        par.gestione = ParteGestioneProiezione(quota: 0.6, lordo: 2.8, trattenuto: 1.2, retrocessione: nil,
                                               minimoGarantito: 0, consolidamento: true, mesiGaranzia: nil, aliquota: 26)
        m(&par)
        return par
    }

    private static func base(_ m: (inout ParametriProiezione) -> Void = { _ in }) -> EsitoProiezione {
        MotoreProiezione.calcola(parametriBase(m))
    }

    private static func punto(_ e: EsitoProiezione, _ anno: Int) -> PuntoProiezione? {
        e.punti.first { $0.anno == anno }
    }

    /// Una multiramo di prova in essere (investimento, «Polizza multiramo»).
    private static func multiramo(_ valore: Double, _ modifica: (inout Posizione) -> Void = { _ in }) -> Posizione {
        AiutiProva.posizione("Multiramo", .investimento, valore) {
            $0.tipologia = "Polizza multiramo"
            modifica(&$0)
        }
    }

    // MARK: - M1–M5: proiezione a due parti

    private static func proiezione(_ verifica: VerificaCalcoli) {
        // M1. Due parti, premio unico 50.000 €, 10 anni.
        // GS = 30.000 × 1,016^10 = 35.160,77; fondi = 20.000 × (1,05 × 0,978)^10 = 26.080,24;
        // imposte = 11.241,00 × 26% = 2.922,66; reale = 58.318,34 / 1,02^10.
        do {
            let e = base()
            verifica("M1 Multiramo: lordo 35.160,77 + 26.080,24", e.lordo, 61_241.00)
            verifica("M1 Multiramo: imposte 26% su 11.241,00", e.imposte, 2_922.66)
            verifica("M1 Multiramo: netto", e.netto, 58_318.34)
            verifica("M1 Multiramo: reale (inflazione 2%)", e.reale, 47_841.35)
            verifica("M1 Multiramo: costi (trattenuto, costi dei fondi e bollo in euro)", e.costi, 8_927.81)
            verifica("M1 Multiramo: di cui gestione separata all'anno 10", punto(e, 10)?.valoreGestione ?? -1, 35_160.77)
            verifica("M1 Multiramo: valore all'anno 1", punto(e, 1)?.valore ?? -1, 51_018.00)
            verifica("M1 Multiramo: di cui gestione separata all'anno 1", punto(e, 1)?.valoreGestione ?? -1, 30_480.00)
            verifica("M1 Multiramo: valore all'anno 2", punto(e, 2)?.valore ?? -1, 52_058.15)
            verifica("M1 Multiramo: di cui gestione separata all'anno 2", punto(e, 2)?.valoreGestione ?? -1, 30_967.68)
            verifica("M1 Multiramo: valore all'anno 5", punto(e, 5)?.valore ?? -1, 55_316.71)
            verifica("M1 Multiramo: di cui gestione separata all'anno 5", punto(e, 5)?.valoreGestione ?? -1, 32_478.04)
            verifica("M1 Multiramo: valore iniziale di cui GS 60%", punto(e, 0)?.valoreGestione ?? -1, 30_000)
            verifica("M1 Multiramo: 11 punti (anni 0–10)", Double(e.punti.count), 11)

            // Grandezze equivalenti di un comparto unico
            let par = parametriBase()
            verifica("M1 Rendimento equivalente 0,6 × 2,8 + 0,4 × 5", par.rendimentoEquivalente, 3.68, tolleranza: 0.0001)
            verifica("M1 Costo equivalente 0,6 × 1,2 + 0,4 × 2,2", par.costoAnnuoEquivalente, 1.60, tolleranza: 0.0001)
            verifica("M1 Aliquota equivalente", par.aliquotaEquivalente, 26, tolleranza: 0.0001)
            verifica("M1 Accreditato della gestione 2,8 − 1,2", par.gestione?.accreditato ?? -1, 1.6, tolleranza: 0.0001)
            // Senza costi la GS rende il lordo e i fondi il loro rendimento: 66.368,30 − 58.318,34
            verifica("M1 Impatto dei costi (trattenuto, costi dei fondi e bollo)", MotoreProiezione.impattoCosti(par), 8_049.96)

            // Senza gestione: un comparto solo, punti senza la parte in gestione separata
            var unico = par
            unico.gestione = nil
            let u = MotoreProiezione.calcola(unico)
            verifica.vero("M1 Comparto unico: nessun valore della gestione nei punti", u.punti.allSatisfy { $0.valoreGestione == nil })
            verifica("M1 Comparto unico: equivalenti uguali ai campi di sempre", unico.rendimentoEquivalente + unico.costoAnnuoEquivalente, 5 + 2.2, tolleranza: 0.0001)
        }

        // M1b. Imposta unica sul contratto: con i fondi al −5% la perdita compensa il guadagno della GS
        // (con due imposte separate sarebbero 1.341,80 €).
        do {
            let e = base { $0.rendimento = -5 }
            verifica("M1b Fondi in perdita: lordo 35.160,77 + 9.586,38", e.lordo, 44_747.15)
            verifica("M1b Imposta unica: nessuna imposta", e.imposte, 0)
            verifica("M1b Imposta unica: netto uguale al lordo", e.netto, 44_747.15)
            verifica("M1b Fondi in perdita: gestione separata invariata", punto(e, 10)?.valoreGestione ?? -1, 35_160.77)
        }

        // M1c. Ingresso dell'1% e 100 € al mese: versamenti divisi 60/40 al netto dell'ingresso.
        do {
            let e = base { $0.costoIngresso = 1; $0.versamento = 100; $0.frequenza = .mensile }
            verifica("M1c Ingresso e versamenti: versato", e.versato, 62_000)
            verifica("M1c Ingresso e versamenti: lordo", e.lordo, 73_807.02)
            verifica("M1c Ingresso e versamenti: di cui gestione separata", punto(e, 10)?.valoreGestione ?? -1, 42_539.16)
            verifica("M1c Ingresso e versamenti: imposte", e.imposte, 3_069.83)
            verifica("M1c Ingresso e versamenti: netto", e.netto, 70_737.20)
            verifica("M1c Ingresso e versamenti: costi", e.costi, 10_489.19)
        }

        // M2. Scenari: la GS si sposta di ±1 punto, i fondi di ±2; la tupla porta il rendimento equivalente.
        do {
            let s = MotoreProiezione.scenari(parametriBase())
            verifica("M2 Scenari: tre scenari", Double(s.count), 3)
            if s.count == 3 {
                verifica("M2 Prudente: rendimento equivalente 0,6 × 1,8 + 0,4 × 3", s[0].rendimento, 2.28, tolleranza: 0.0001)
                verifica("M2 Atteso: rendimento equivalente", s[1].rendimento, 3.68, tolleranza: 0.0001)
                verifica("M2 Favorevole: rendimento equivalente 0,6 × 3,8 + 0,4 × 7", s[2].rendimento, 5.08, tolleranza: 0.0001)
                verifica("M2 Prudente: lordo", s[0].esito.lordo, 53_366.84)
                verifica("M2 Prudente: netto", s[0].esito.netto, 52_491.46)
                verifica("M2 Prudente: GS all'anno 10 (accredita lo 0,6%)", punto(s[0].esito, 10)?.valoreGestione ?? -1, 31_849.39)
                verifica("M2 Atteso: uguale a M1", s[1].esito.netto, 58_318.34)
                verifica("M2 Favorevole: lordo", s[2].esito.lordo, 70_274.91)
                verifica("M2 Favorevole: netto", s[2].esito.netto, 65_003.43)
                verifica("M2 Favorevole: GS all'anno 10", punto(s[2].esito, 10)?.valoreGestione ?? -1, 38_778.84)
            }
            let q = parametriBase().conScarto(-2)
            verifica("M2 Scarto: fondi −2 punti", q.rendimento, 3, tolleranza: 0.0001)
            verifica("M2 Scarto: gestione separata −1 punto", q.gestione?.lordo ?? -1, 1.8, tolleranza: 0.0001)
            // Senza gestione la tupla resta quella di prima: rendimento ± 2
            var unico = parametriBase()
            unico.gestione = nil
            verifica("M2 Comparto unico: prudente al 3%", MotoreProiezione.scenari(unico).first?.rendimento ?? -1, 3, tolleranza: 0.0001)
        }

        // M3. Garanzia della sola parte in gestione separata.
        do {
            // a) lordo 1,0 con trattenuto 1,2, consolidata: accreditato 0 (pavimento), la GS resta 30.000
            let a = base { $0.gestione?.lordo = 1.0 }
            verifica.vero("M3a Pavimento: la gestione separata resta 30.000 € ogni anno",
                          a.punti.allSatisfy { abs(($0.valoreGestione ?? -1) - 30_000) < 0.01 })
            verifica("M3a Pavimento: lordo", a.lordo, 56_080.24)
            verifica("M3a Pavimento: netto", a.netto, 54_499.38)
            // b) senza consolidamento, garanzia alla scadenza del contratto (120 mesi): −0,2% l'anno, poi 30.000
            let b = base { $0.gestione?.lordo = 1.0; $0.gestione?.consolidamento = false; $0.gestione?.mesiGaranzia = 120 }
            verifica("M3b Senza consolidamento: GS all'anno 1", punto(b, 1)?.valoreGestione ?? -1, 29_940.00)
            verifica("M3b Senza consolidamento: GS all'anno 5", punto(b, 5)?.valoreGestione ?? -1, 29_701.20)
            verifica("M3b Senza consolidamento: GS alla scadenza torna al garantito", punto(b, 10)?.valoreGestione ?? -1, 30_000.00)
            verifica("M3b Senza consolidamento: netto", b.netto, 54_499.38)
            verifica("M3b Senza consolidamento: costi", b.costi, 8_657.42)
        }

        // M4. Ribilanciamento annuo: ogni anno il fattore è 0,6 × 1,016 + 0,4 × 1,0269 = 1,02036.
        do {
            let e = base { $0.gestione?.ribilanciamento = true }
            verifica("M4 Ribilanciamento: anno 1", punto(e, 1)?.valore ?? -1, 51_018.00)
            verifica("M4 Ribilanciamento: GS all'anno 1 (60%)", punto(e, 1)?.valoreGestione ?? -1, 30_610.80)
            verifica("M4 Ribilanciamento: anno 2", punto(e, 2)?.valore ?? -1, 52_056.73)
            verifica("M4 Ribilanciamento: GS all'anno 2", punto(e, 2)?.valoreGestione ?? -1, 31_234.04)
            verifica("M4 Ribilanciamento: anno 10 = 50.000 × 1,02036^10", punto(e, 10)?.valore ?? -1, 61_165.18)
            verifica("M4 Ribilanciamento: GS all'anno 10 (60%)", punto(e, 10)?.valoreGestione ?? -1, 36_699.11)
            verifica("M4 Ribilanciamento: netto", e.netto, 58_262.23)
            verifica.vero("M4 Ribilanciamento: meno della deriva (61.241,00), toglie ai fondi la crescita in più", e.lordo < base().lordo)
        }

        // M5. Aliquota pesata sui valori finali: GS 26 − 0,7 × 13,5 = 16,55 (70% in titoli di Stato),
        // fondi 26 − 0,2 × 13,5 = 23,3.
        do {
            let e = base { $0.gestione?.aliquota = 16.55; $0.aliquotaFiscale = 23.3 }
            let aliquota = e.lordo > e.versato ? e.imposte / (e.lordo - e.versato) * 100 : -1
            verifica("M5 Aliquota pesata sui valori finali", aliquota, 19.4246, tolleranza: 0.0001)
            verifica("M5 Aliquota pesata: imposte", e.imposte, 2_183.52)
            verifica("M5 Aliquota pesata: netto", e.netto, 59_057.49)
            let par = parametriBase { $0.gestione?.aliquota = 16.55; $0.aliquotaFiscale = 23.3 }
            verifica("M5 Aliquota equivalente sulle quote iniziali 0,6 × 16,55 + 0,4 × 23,3", par.aliquotaEquivalente, 19.25, tolleranza: 0.0001)
        }
    }

    // MARK: - M12, M13, M13c, M15–M18: letture della posizione e funzioni comuni

    private static func posizioni(_ verifica: VerificaCalcoli) {
        // M12. Riconoscimento dal testo della tipologia.
        do {
            verifica.vero("M12 «Unit linked con gestione separata» è multiramo", Posizione.multiramo(tipologia: "Unit linked con gestione separata"))
            let ulgs = AiutiProva.posizione("UL", .investimento, 10_000) { $0.tipologia = "Unit linked con gestione separata" }
            verifica.vero("M12 «Unit linked con gestione separata»: multiramo, non gestione separata", ulgs.multiramo && !ulgs.gestioneSeparata)
            verifica.vero("M12 «Ramo I e Ramo III» è multiramo", Posizione.multiramo(tipologia: "Ramo I e Ramo III"))
            verifica.vero("M12 «Polizza multiramo (Ramo I e Ramo III)» è multiramo", Posizione.multiramo(tipologia: "Polizza multiramo (Ramo I e Ramo III)"))
            verifica.vero("M12 «Polizza ibrida» è multiramo", Posizione.multiramo(tipologia: "Polizza ibrida"))
            verifica.vero("M12 «Polizza rivalutabile Ramo I» non è multiramo", !Posizione.multiramo(tipologia: "Polizza rivalutabile Ramo I"))
            verifica.vero("M12 «Unit linked» non è multiramo", !Posizione.multiramo(tipologia: "Unit linked"))
            let ul = AiutiProva.posizione("UL", .investimento, 10_000) { $0.tipologia = "Unit linked" }
            verifica.vero("M12 «Unit linked»: unit linked pura", ul.unitLinked && !ul.multiramo)
            let trattino = AiutiProva.posizione("UL", .investimento, 10_000) { $0.tipologia = "Polizza unit-linked" }
            verifica.vero("M12 «Polizza unit-linked»: unit linked pura", trattino.unitLinked)
            let comunita = AiutiProva.posizione("Comunità", .risparmio, 10_000) { $0.tipologia = "Polizza rivalutabile per la comunità" }
            verifica.vero("M12 «per la comunità»: non è unit linked, è gestione separata", !comunita.unitLinked && comunita.gestioneSeparata)
            let ramoI = AiutiProva.posizione("Ramo I", .risparmio, 10_000) { $0.tipologia = "Polizza rivalutabile Ramo I" }
            verifica("M12 Ramo I puro: tutto in gestione separata", ramoI.parteGestione, 1, tolleranza: 0.0001)
            verifica("M12 Unit linked pura: niente in gestione separata", ul.parteGestione, 0, tolleranza: 0.0001)
            // Un fondo con «unità» o «comunità» nel nome non è un Ramo III
            verifica.vero("M12 «unit» come parola intera", !Posizione.ramoIII("fondo per la comunità") && !Posizione.ramoIII("unità di conto"))
        }

        // M13. Compatibilità: multiramo senza campi separati, tutto come prima.
        do {
            let vecchia = multiramo(10_000) { $0.quotaGestioneSeparata = 40; $0.rendimentoAtteso = 4; $0.costoAnnuo = 1.8 }
            let par = ParametriProiezione(posizione: vecchia)
            verifica.vero("M13 Senza campi separati: non è divisa, proiezione a un comparto", !vecchia.multiramoDivisa && par.gestione == nil)
            verifica("M13 Senza campi separati: costo annuo 1,8 + 0,2 × 0,6", par.costoAnnuo, 1.92, tolleranza: 0.0001)
            verifica("M13 Senza campi separati: rendimento", par.rendimento, 4, tolleranza: 0.0001)
            verifica("M13 Senza campi separati: costo complessivo", vecchia.costoComplessivo ?? -1, 1.8, tolleranza: 0.0001)
            // Basta il trattenuto: il trattenuto vale sulla sola gestione separata
            var divisa = vecchia
            divisa.trattenuto = 0.5
            let parDivisa = ParametriProiezione(posizione: divisa)
            verifica.vero("M13 Con il trattenuto: divisa", divisa.multiramoDivisa)
            verifica("M13 Con il trattenuto: costo complessivo 0,4 × 0,5 + 0,6 × 1,8", divisa.costoComplessivo ?? -1, 1.28, tolleranza: 0.0001)
            verifica("M13 Con il trattenuto: lordo della gestione dal complessivo", parDivisa.gestione?.lordo ?? -1, 4, tolleranza: 0.0001)
            verifica("M13 Con il trattenuto: rendimento dei fondi dal complessivo", parDivisa.rendimento, 4, tolleranza: 0.0001)
            verifica("M13 Con il trattenuto: costo dei fondi 1,8 più bollo 0,2", parDivisa.costoAnnuo, 2.0, tolleranza: 0.0001)
            verifica("M13 Con il trattenuto: bollo sui fondi (60%)", divisa.quotaBollo, 0.6, tolleranza: 0.0001)
            // Senza la quota: bollo su tutto se non è divisa (come K1), sulla metà se è divisa
            let senzaQuota = multiramo(10_000) { $0.rendimentoAtteso = 4 }
            verifica("M13 Senza quota né campi separati: bollo su tutto", senzaQuota.quotaBollo, 1, tolleranza: 0.0001)
            var senzaQuotaDivisa = senzaQuota
            senzaQuotaDivisa.minimoGarantito = 0
            verifica("M13 Senza quota, divisa: bollo sulla metà stimata", senzaQuotaDivisa.quotaBollo, 0.5, tolleranza: 0.0001)
            verifica.vero("M13 Senza quota: quota stimata", senzaQuotaDivisa.quotaGestioneStimata)
            // Nessun costo indicato: il costo complessivo resta nil
            let senzaCosti = multiramo(10_000) { $0.quotaGestioneSeparata = 40; $0.rendimentoGestione = 3 }
            verifica.vero("M13 Divisa senza costi: costo complessivo non indicato", senzaCosti.multiramoDivisa && senzaCosti.costoComplessivo == nil)
        }

        // M13c. Rendimento di una parte ricavato dal complessivo.
        do {
            let a = multiramo(10_000) { $0.quotaGestioneSeparata = 40; $0.rendimentoAtteso = 4; $0.rendimentoFondi = 8 }
            verifica("M13c GS ricavata: (4 − 0,6 × 8) / 0,4, mai sotto zero", a.lordoGestione(), 0, tolleranza: 0.0001)
            let b = multiramo(10_000) { $0.quotaGestioneSeparata = 5; $0.rendimentoAtteso = 4; $0.rendimentoFondi = 6 }
            verifica("M13c GS sotto il 10%: si usa il complessivo", b.lordoGestione(), 4, tolleranza: 0.0001)
            let c = multiramo(10_000) { $0.quotaGestioneSeparata = 30; $0.rendimentoAtteso = 4.7; $0.rendimentoGestione = 3 }
            verifica("M13c Fondi ricavati: (4,7 − 0,3 × 3) / 0,7", c.lordoFondi(), 5.428571, tolleranza: 0.0001)
            verifica("M13c Composto torna al complessivo", c.rendimentoLordoComposto, 4.7, tolleranza: 0.0001)
            verifica.vero("M13c Rendimento ricavato: tra le ipotesi", c.rendimentiPartiStimati && c.rendimentoIndicato)
            let d = multiramo(10_000) { $0.quotaGestioneSeparata = 40 }
            verifica("M13c Senza rendimenti: l'ipotesi predefinita", d.lordoGestione() + d.lordoFondi(predefinito: 5), 3 + 5, tolleranza: 0.0001)
            verifica.vero("M13c Senza rendimenti: nessun rendimento indicato", !d.rendimentoIndicato)
        }

        // M15. La posizione di Marco (in essere): 62.000 €, 40% in GS al 3,0% lordo con trattenuto 1,3
        // consolidata; fondi al 5,5% con costi del 2,3%.
        let marco = AiutiProva.posizione("Marco", .investimento, 62_000, canale: .alleanza) {
            $0.tipologia = "Polizza multiramo (Ramo I e Ramo III)"
            $0.quotaGestioneSeparata = 40; $0.rendimentoGestione = 3.0; $0.trattenuto = 1.3; $0.minimoGarantito = 0
            $0.consolidamento = true; $0.rendimentoFondi = 5.5; $0.costoFondi = 2.3
        }
        do {
            verifica("M15 Marco: accreditato della gestione 3,0 − 1,3", marco.accreditatoGestione(), 1.7, tolleranza: 0.0001)
            verifica("M15 Marco: punti trattenuti", marco.trattenutoGestione, 1.3, tolleranza: 0.0001)
            verifica("M15 Marco: netto dei fondi 5,5 − 2,3", marco.nettoFondi, 3.2, tolleranza: 0.0001)
            verifica("M15 Marco: rendimento lordo composto 0,4 × 3 + 0,6 × 5,5", marco.rendimentoLordoComposto, 4.5, tolleranza: 0.0001)
            verifica("M15 Marco: rendimento netto composto 0,4 × 1,7 + 0,6 × 3,2", marco.rendimentoNettoComposto, 2.6, tolleranza: 0.0001)
            verifica("M15 Marco: costo composto 0,4 × 1,3 + 0,6 × 2,3", marco.costoComposto, 1.9, tolleranza: 0.0001)
            verifica("M15 Marco: bollo dei fondi", marco.bolloFondi, 0.2, tolleranza: 0.0001)
            let par = ParametriProiezione(posizione: marco)
            verifica("M15 Marco: proiezione dei fondi al 5,5%", par.rendimento, 5.5, tolleranza: 0.0001)
            verifica("M15 Marco: costo dei fondi 2,3 più bollo 0,2", par.costoAnnuo, 2.5, tolleranza: 0.0001)
            verifica("M15 Marco: 40% in gestione separata al 3% lordo", { () -> Double in let a: Double = par.gestione?.quota ?? -1; let b: Double = par.gestione?.lordo ?? -1; return a + b }(), 3.4, tolleranza: 0.0001)
            verifica.vero("M15 Marco: la garanzia è nella parte GS, non nel contratto", !par.capitaleGarantito && par.gestione?.consolidamento == true)
            verifica("M15 Marco: costo equivalente = costo composto + bollo × 0,6", par.costoAnnuoEquivalente, 1.9 + 0.2 * 0.6, tolleranza: 0.0001)
            verifica("M15 Marco: scarto equivalente di 2 punti 0,4 × 1 + 0,6 × 2", MotoreMultiramo.scartoEquivalente(marco, scarto: 2), 1.6, tolleranza: 0.0001)
            let riga = MotoreMultiramo.rigaComposizione(marco)
            verifica.vero("M15 Marco: riga di composizione «\(riga)»", riga == "di cui gestione separata 40% al 3,00% · fondi 60% al 5,50%")
            let senza = MotoreMultiramo.senzaCostiProdotto(par, marco)
            verifica.vero("M15 Senza costi del prodotto: resta solo il bollo",
                          senza.costoIngresso == 0 && abs(senza.costoAnnuo - 0.2) < 0.0001 && senza.gestione?.trattenuto == nil)
        }

        // M16. Le due parti come posizioni a sé.
        do {
            let f = MotoreMultiramo.posizioneFondi(marco)
            verifica("M16 Parte fondi: 60% del valore", f.valore, 37_200)
            verifica.vero("M16 Parte fondi: unit linked pura, non divisa", f.unitLinked && !f.multiramo && !f.multiramoDivisa)
            verifica("M16 Parte fondi: rendimento e costi dei fondi", { () -> Double in let a: Double = f.rendimentoAtteso ?? -1; let b: Double = f.costoAnnuo ?? -1; return a + b }(), 7.8, tolleranza: 0.0001)
            verifica("M16 Parte fondi: bollo su tutta la parte", f.quotaBollo, 1, tolleranza: 0.0001)
            let g = MotoreMultiramo.posizioneGestione(marco)
            verifica("M16 Parte GS: 40% del valore", g.valore, 24_800)
            verifica.vero("M16 Parte GS: Ramo I a sé, senza bollo", g.gestioneSeparata && g.quotaBollo == 0 && !g.multiramoDivisa)
            // Il pannello della gestione separata sulla sola parte: 24.800 × 1,3% = 322,40 €
            let esito = MotoreGestioneSeparata.calcolaParte(marco)
            verifica("M16 Gestione separata della parte: accreditato", esito?.accreditato ?? -1, 1.7, tolleranza: 0.0001)
            verifica("M16 Gestione separata della parte: trattenuto in euro sul 40%", esito?.trattenutoEuro ?? -1, 322.40)
            verifica.vero("M16 Gestione separata della parte: nil se non è divisa",
                          MotoreGestioneSeparata.calcolaParte(multiramo(10_000) { $0.quotaGestioneSeparata = 40 }) == nil)
            verifica.vero("M16 Il Ramo I di una multiramo non è più un Ramo I", MotoreGestioneSeparata.calcola(marco) == nil)
        }

        // M17. Volatilità e SRI dei fondi e della combinazione (le prove dei motori di rischio sono in M6–M9).
        do {
            let v = multiramo(10_000) { $0.quotaGestioneSeparata = 40; $0.rendimentoFondi = 5; $0.volatilitaFondi = 14 }
            verifica("M17 Volatilità indicata dei fondi", v.volatilitaParteFondi, 14, tolleranza: 0.0001)
            verifica("M17 Volatilità composta 0,6 × 14", v.volatilitaComposta, 8.4, tolleranza: 0.0001)
            verifica("M17 SRI stimato della combinazione (8,4% → 3)", Double(v.sriComposto), 3)
            let s = multiramo(10_000) { $0.quotaGestioneSeparata = 40; $0.rendimentoFondi = 5; $0.sri = 3 }
            verifica("M17 Dall'SRI 3 della combinazione: 8,5 / 0,6", s.volatilitaParteFondi, 8.5 / 0.6, tolleranza: 0.0001)
            verifica("M17 SRI dei fondi stimato (14,17% → 4)", Double(s.sriParteFondi), 4)
            verifica("M17 SRI della combinazione: quello del KID", Double(s.sriComposto), 3)
            let poca = multiramo(10_000) { $0.quotaGestioneSeparata = 90; $0.rendimentoFondi = 5; $0.sri = 2 }
            verifica("M17 Meno del 20% in fondi: SRI probabile dell'area, non la divisione", poca.volatilitaParteFondi, 16, tolleranza: 0.0001)
            verifica("M17 Classi del Regolamento: 4,99 → 2, 12 → 4", Double(MotoreMultiramo.classeSRI(volatilita: 4.99) * 10 + MotoreMultiramo.classeSRI(volatilita: 12)), 24)
            // Aliquote per parte: titoli di Stato di una parte sola, l'altra al 26%
            let t = multiramo(10_000) { $0.quotaGestioneSeparata = 40; $0.titoliStatoGestione = 60; $0.aliquotaFiscale = 24 }
            verifica("M17 Aliquota GS con il 60% in titoli di Stato", t.aliquotaGestione, 17.9, tolleranza: 0.0001)
            verifica("M17 Aliquota dei fondi senza i loro titoli: 26%", t.aliquotaFondi, 26, tolleranza: 0.0001)
            verifica("M17 Aliquota pesata 0,4 × 17,9 + 0,6 × 26", t.aliquotaPesata(valore: 100, valoreGestione: 40), 22.76, tolleranza: 0.0001)
        }

        // M18. Dalla scheda prodotto: campi diretti, poi le parti delle condizioni.
        do {
            var scheda = Prodotto(nome: "Multiramo di prova", canale: .indipendente, area: .investimento)
            scheda.tipologia = "Polizza multiramo"
            scheda.rendimentoAtteso = 4.5
            scheda.rendimentoGestione = 3.1
            var gs1 = ComponenteContratto(tipo: .gestioneSeparata, nome: "GS uno", quota: 20)
            gs1.trattenuto = 1.0; gs1.rendimentoAtteso = 2.5; gs1.titoliStato = 60; gs1.consolidamento = true; gs1.minimoGarantito = 0
            var gs2 = ComponenteContratto(tipo: .gestioneSeparata, nome: "GS due", quota: 20)
            gs2.trattenuto = 1.4; gs2.titoliStato = 40
            var fi = ComponenteContratto(tipo: .fondoInterno, nome: "Fondo", quota: 60)
            fi.commissione = 1.5; fi.costiSottostanti = 0.5; fi.rendimentoAtteso = 6; fi.sri = 4; fi.volatilita = 15
            fi.quotaAzionaria = 70; fi.titoliStato = 10
            var condizioni = CondizioniContratto()
            condizioni.componenti = [gs1, gs2, fi]
            scheda.condizioni = condizioni
            let p = scheda.proposta(per: "prova")
            verifica("M18 Dalle parti: quota in gestione separata", p.quotaGestioneSeparata ?? -1, 40, tolleranza: 0.0001)
            verifica("M18 Dalle parti: trattenuto pesato (20 × 1,0 + 20 × 1,4) / 40", p.trattenuto ?? -1, 1.2, tolleranza: 0.0001)
            verifica("M18 Il campo della scheda prevale sulle parti: rendimento della gestione", p.rendimentoGestione ?? -1, 3.1, tolleranza: 0.0001)
            verifica("M18 Dalle parti: titoli di Stato della gestione", p.titoliStatoGestione ?? -1, 50, tolleranza: 0.0001)
            verifica("M18 Dalle parti: costi dei fondi 1,5 + 0,5", p.costoFondi ?? -1, 2.0, tolleranza: 0.0001)
            verifica("M18 Dalle parti: rendimento, volatilità e azioni dei fondi", { () -> Double in let a: Double = p.rendimentoFondi ?? -1; let b: Double = p.volatilitaFondi ?? -1; let c: Double = p.quotaAzionariaFondi ?? -1; return a + b + c }(), 91, tolleranza: 0.0001)
            verifica("M18 Dalle parti: SRI e titoli di Stato dei fondi", { () -> Double in let a = Double(p.sriFondi ?? -1); let b: Double = p.titoliStatoFondi ?? -1; return a + b }(), 14, tolleranza: 0.0001)
            verifica.vero("M18 Dalle parti: consolidamento e minimo della prima gestione", p.consolidamento == true && p.minimoGarantito == 0)
            verifica.vero("M18 La proposta è una multiramo a due parti", p.multiramoDivisa)
            // In essere la quota non si copia: resta la stima del 50%, da completare con l'estratto conto
            var inEssere = Posizione(clienteId: "prova", canale: .indipendente, stato: .inEssere, area: .investimento, nome: "In essere")
            inEssere.tipologia = "Polizza multiramo"
            MotoreMultiramo.applica(scheda, a: &inEssere)
            verifica.vero("M18 In essere: la quota della scheda non si copia", inEssere.quotaGestioneSeparata == nil && inEssere.quotaGestioneStimata)
            // Ciò che la posizione indica già non cambia
            var giaIndicata = inEssere
            giaIndicata.trattenuto = 0.8
            MotoreMultiramo.applica(scheda, a: &giaIndicata)
            verifica("M18 Il dato della posizione non si sovrascrive", giaIndicata.trattenuto ?? -1, 0.8, tolleranza: 0.0001)
            // Un Ramo I puro porta le condizioni della gestione separata, non i dati delle due parti
            var ramoI = Prodotto(nome: "Rivalutabile", canale: .alleanza, area: .risparmio)
            ramoI.tipologia = "Polizza rivalutabile Ramo I"
            ramoI.trattenuto = 1.2; ramoI.minimoGarantito = 0; ramoI.consolidamento = true; ramoI.rendimentoFondi = 5
            let r = ramoI.proposta(per: "prova")
            verifica.vero("M18 Ramo I dalla scheda: trattenuto, minimo e consolidamento",
                          r.trattenuto == 1.2 && r.minimoGarantito == 0 && r.consolidamento == true)
            verifica.vero("M18 Ramo I dalla scheda: niente dati dei fondi", r.rendimentoFondi == nil && !r.multiramoDivisa)
            // KPI della scheda a due parti: la proiezione tiene la gestione, senza bollo
            let esempio = scheda.parametriEsempio
            verifica.vero("M18 Esempio della scheda: due parti", esempio.gestione != nil && esempio.capitaleIniziale == 10_000 && esempio.anni == 10)
            verifica("M18 Esempio della scheda: costo dei fondi senza bollo", esempio.costoAnnuo, 2.0, tolleranza: 0.0001)

            // Ipotesi di partenza della valutazione dal rendimento indicato delle parti
            var c = CondizioniContratto()
            var g = ComponenteContratto(tipo: .gestioneSeparata, nome: "GS", quota: 30)
            g.rendimentoAtteso = 3.2
            var f = ComponenteContratto(tipo: .fondoInterno, nome: "FI", quota: 70)
            f.rendimentoAtteso = 6; f.commissione = 1.7; f.costiSottostanti = 0.99
            c.componenti = [g, f]
            let ipotesi = ValutazioneInvestimento.ipotesiDiPartenza(c)
            let intermedio = ipotesi.first { $0.tipo == .intermedio }
            verifica("M18 Valutazione: GS dal rendimento indicato 3,2 + 0,1", intermedio?.rendimento(g) ?? -1, 3.3, tolleranza: 0.0001)
            verifica("M18 Valutazione: FI al netto dei costi (1,06 × 0,9731 − 1, al decimo)", intermedio?.rendimento(f) ?? -1, 3.1, tolleranza: 0.0001)
        }
    }

    // MARK: - M11: archivio

    private static func archivio(_ verifica: VerificaCalcoli) {
        // Una posizione con tutti i campi nuovi torna uguale
        var p = AiutiProva.posizione("Multiramo completa", .investimento, 62_000) {
            $0.tipologia = "Polizza multiramo (Ramo I e Ramo III)"
            $0.quotaGestioneSeparata = 40; $0.trattenuto = 1.3; $0.minimoGarantito = 0; $0.consolidamento = true
            $0.rendimentoGestione = 3.0; $0.rendimentoFondi = 5.5; $0.costoFondi = 2.3; $0.sriFondi = 4
            $0.volatilitaFondi = 14; $0.quotaAzionariaFondi = 58; $0.titoliStatoGestione = 60; $0.titoliStatoFondi = 10
            $0.ribilanciamento = true
        }
        p.creataIl = AiutiProva.data(2025, 1, 15)
        let letta = (try? Archivio.codificatore.encode(p)).flatMap { try? Archivio.decodificatore.decode(Posizione.self, from: $0) }
        verifica.vero("M11 Archivio: multiramo con tutti i campi nuovi identica dopo andata e ritorno", letta == p)
        verifica.vero("M11 Archivio: campi delle due parti conservati",
                      letta?.rendimentoGestione == 3.0 && letta?.costoFondi == 2.3 && letta?.sriFondi == 4
                      && letta?.ribilanciamento == true && letta?.titoliStatoFondi == 10 && letta?.multiramoDivisa == true)

        // Una scheda prodotto con tutti i campi nuovi (le sue CodingKeys sono scritte a mano)
        var s = Prodotto(nome: "Scheda multiramo", canale: .alleanza, area: .investimento)
        s.id = "prodotto-prova-multiramo"
        s.tipologia = "Polizza multiramo"
        s.trattenuto = 1.3; s.retrocessione = 80; s.minimoGarantito = 0.5; s.consolidamento = false
        s.quotaGestioneSeparata = 40; s.quotaGestioneMinima = 30; s.quotaGestioneMassima = 70
        s.rendimentoGestione = 3.0; s.rendimentoFondi = 5.5; s.costoFondi = 2.3; s.sriFondi = 4
        s.volatilitaFondi = 14; s.quotaAzionariaFondi = 58; s.titoliStatoGestione = 60; s.titoliStatoFondi = 10
        s.ribilanciamento = false
        var fi = ComponenteContratto(tipo: .fondoInterno, nome: "Fondo", quota: 60)
        fi.id = "fi-prova"
        fi.rendimentoAtteso = 5.5; fi.sri = 4; fi.volatilita = 14; fi.quotaAzionaria = 58
        var c = CondizioniContratto()
        c.componenti = [fi]
        s.condizioni = c
        let schedaLetta = (try? Archivio.codificatore.encode(s)).flatMap { try? Archivio.decodificatore.decode(Prodotto.self, from: $0) }
        verifica.vero("M11 Archivio: scheda multiramo con tutti i campi nuovi identica dopo andata e ritorno", schedaLetta == s)
        verifica.vero("M11 Archivio: limiti della quota e ribilanciamento della scheda conservati",
                      schedaLetta?.quotaGestioneMinima == 30 && schedaLetta?.quotaGestioneMassima == 70
                      && schedaLetta?.ribilanciamento == false && schedaLetta?.retrocessione == 80)
        let parteLetta = schedaLetta?.condizioni?.componenti.first
        verifica.vero("M11 Archivio: rendimento, SRI, volatilità e azioni della parte conservati",
                      parteLetta?.rendimentoAtteso == 5.5 && parteLetta?.sri == 4 && parteLetta?.volatilita == 14 && parteLetta?.quotaAzionaria == 58)

        // Una multiramo dell'archivio 19 (quota, rendimento e costo, senza condizioni della GS): non divisa
        var vecchia = AiutiProva.posizione("Multiramo v19", .investimento, 50_000) {
            $0.tipologia = "Polizza multiramo"; $0.quotaGestioneSeparata = 40; $0.rendimentoAtteso = 4; $0.costoAnnuo = 1.8
        }
        vecchia.creataIl = AiutiProva.data(2024, 6, 1)
        let grezzo = (try? Archivio.codificatore.encode(vecchia)).flatMap { try? JSONSerialization.jsonObject(with: $0) }
        var oggetto: [String: Any] = (grezzo as? [String: Any]) ?? [:]
        let nuovi = ["rendimentoGestione", "rendimentoFondi", "costoFondi", "sriFondi", "volatilitaFondi", "quotaAzionariaFondi",
                     "titoliStatoGestione", "titoliStatoFondi", "ribilanciamento", "trattenuto", "retrocessione",
                     "minimoGarantito", "consolidamento"]
        verifica.vero("M11 Archivio 19: il JSON non ha i campi nuovi", !oggetto.isEmpty && nuovi.allSatisfy { oggetto[$0] == nil })
        let letta19 = (try? JSONSerialization.data(withJSONObject: oggetto)).flatMap { try? Archivio.decodificatore.decode(Posizione.self, from: $0) }
        verifica.vero("M11 Archivio 19: multiramo letta, non divisa", letta19 != nil && letta19?.multiramoDivisa == false && letta19?.quotaGestioneSeparata == 40)
        // Con il trattenuto la stessa multiramo passa al modo a due parti: è il cambiamento voluto
        oggetto["trattenuto"] = 1.3
        let conTrattenuto = (try? JSONSerialization.data(withJSONObject: oggetto)).flatMap { try? Archivio.decodificatore.decode(Posizione.self, from: $0) }
        verifica.vero("M11 Archivio 19 con il trattenuto: divisa", conTrattenuto?.multiramoDivisa == true)
        verifica("M11 Archivio 19 con il trattenuto: costo complessivo 0,4 × 1,3 + 0,6 × 1,8", conTrattenuto?.costoComplessivo ?? -1, 1.6, tolleranza: 0.0001)
        verifica("M11 Archivio: versione 22", Double(DatiPrisma.versioneAttuale), 22)
    }
}
