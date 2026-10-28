import Foundation

/// Motori dell'Analisi 360. Le formule sono quelle del template (advice-math), con le coperture
/// e i piani letti dalle posizioni del cliente. Sono conteggi semplificati: servono a capire
/// gli ordini di grandezza e a preparare l'incontro, non sostituiscono la lettura dei contratti.
enum MotoreAnalisi {

    // MARK: - Versamento necessario

    /// Versamento mensile che porta il netto finale all'obiettivo (ricerca per bisezione).
    /// nil se nemmeno 100 milioni al mese bastano, 0 se il capitale iniziale è già sufficiente.
    static func versamentoNecessario(_ p: ParametriProiezione, obiettivo: Double) -> Double? {
        var q = p
        q.frequenza = .mensile
        func netto(_ v: Double) -> Double {
            q.versamento = v
            return MotoreProiezione.calcola(q).netto
        }
        if netto(0) >= obiettivo { return 0 }
        guard q.anni > 0 else { return nil }
        var alto = 1_000.0
        while alto < 1e8 && netto(alto) < obiettivo { alto *= 2 }
        if netto(alto) < obiettivo { return nil }
        var basso = 0.0
        for _ in 0..<55 {
            let mezzo = (basso + alto) / 2
            if netto(mezzo) < obiettivo { basso = mezzo } else { alto = mezzo }
        }
        return alto
    }

    // MARK: - Previdenza

    struct EsitoPrevidenza {
        let anniAccumulo: Int
        /// Differenza mensile tra il reddito desiderato e la pensione pubblica.
        let divario: Double
        /// Capitale che servirebbe per integrare il divario negli anni scelti.
        let capitaleObiettivo: Double
        /// Montante del piano alla pensione.
        let montante: Double
        /// Integrazione mensile che il montante permette.
        let integrazione: Double
        let divarioResiduo: Double
        /// Versamento mensile teorico per coprire tutto il divario (nil se non c'è tempo).
        let versamentoTeorico: Double?
        let punti: [PuntoProiezione]
    }

    static func previdenza(_ i: IpotesiPrevidenza) -> EsitoPrevidenza {
        let anni = max(0, i.etaPensione - i.eta)
        let divario = max(0, i.redditoDesiderato - i.pensionePubblica)
        let mesiIntegrazione = Double(max(1, i.anniIntegrazione) * 12)
        let obiettivo = divario * mesiIntegrazione
        let p = ParametriProiezione(capitaleIniziale: i.capitale, versamento: i.versamentoMensile, frequenza: .mensile,
                                    anni: anni, rendimento: i.rendimentoReale, aliquotaFiscale: 0, inflazione: 0)
        let e = MotoreProiezione.calcola(p)
        let integrazione = e.netto / mesiIntegrazione
        return EsitoPrevidenza(
            anniAccumulo: anni, divario: divario, capitaleObiettivo: obiettivo, montante: e.netto,
            integrazione: integrazione, divarioResiduo: max(0, divario - integrazione),
            versamentoTeorico: anni > 0 ? versamentoNecessario(p, obiettivo: obiettivo) : nil, punti: e.punti
        )
    }

    // MARK: - Protezione

    struct EsitoProtezione {
        /// Capitale che servirebbe alla famiglia in caso di morte.
        let fabbisogno: Double
        /// Capitali caso morte in essere (dalle posizioni).
        let capitaleVita: Double
        let divario: Double
        /// Divario se le proposte aperte venissero accettate.
        let divarioConProposte: Double
        /// Reddito mensile che mancherebbe in caso di invalidità o malattia lunga.
        let ammanco: Double
        let riservaNecessaria: Double
        let riservaMancante: Double
        let premiAnnui: Double
        /// Rischi coperti dalle posizioni in essere.
        let rischiCoperti: Set<RischioCoperto>
    }

    /// Le coperture caso morte valide: in essere e non scadute.
    static func capitaleVita(_ posizioni: [Posizione], stato: StatoPosizione = .inEssere) -> Double {
        posizioni
            .filter { $0.area == .protezione && $0.stato == stato && $0.rischio == .vita && !$0.scaduta }
            .filter { stato != .proposta || ($0.esito != .rifiutata && $0.esito != .accettata) }
            .reduce(0) { $0 + ($1.capitaleAssicurato ?? 0) }
    }

    static func protezione(_ i: IpotesiProtezione, posizioni: [Posizione]) -> EsitoProtezione {
        let fabbisogno = max(0, i.debiti + i.speseImmediate + i.fabbisognoMensile * 12 * Double(i.anniSostegno) - i.capitaleDisponibile)
        let vita = capitaleVita(posizioni)
        let proposte = capitaleVita(posizioni, stato: .proposta)
        let ammanco = max(0, i.fabbisognoMensile - i.entrateSostitutive)
        let riserva = ammanco * Double(i.mesiRiserva)
        let coperture = posizioni.filter { $0.area == .protezione && $0.stato == .inEssere && !$0.scaduta }
        return EsitoProtezione(
            fabbisogno: fabbisogno, capitaleVita: vita, divario: max(0, fabbisogno - vita),
            divarioConProposte: max(0, fabbisogno - vita - proposte),
            ammanco: ammanco, riservaNecessaria: riserva, riservaMancante: max(0, riserva - i.riserva),
            premiAnnui: coperture.reduce(0) { $0 + ($1.premioAnnuo > 0 ? $1.premioAnnuo : 0) },
            rischiCoperti: Set(coperture.compactMap(\.rischio))
        )
    }

    // MARK: - Investimenti

    struct EsitoInvestimento {
        let esito: EsitoProiezione
        let scenari: [(nome: String, rendimento: Double, esito: EsitoProiezione)]
        let impattoCosti: Double
        /// Valore subito dopo un calo improvviso del capitale.
        let dopoCalo: Double
        let perditaCalo: Double
        /// Rendimento annuo al netto dei costi annui.
        let rendimentoNetto: Double
    }

    static func investimenti(_ i: IpotesiInvestimento) -> EsitoInvestimento {
        let p = i.parametri
        let calo = i.capitale * min(max(i.calo, 0), 100) / 100
        return EsitoInvestimento(
            esito: MotoreProiezione.calcola(p), scenari: MotoreProiezione.scenari(p),
            impattoCosti: MotoreProiezione.impattoCosti(p),
            dopoCalo: i.capitale - calo, perditaCalo: calo,
            rendimentoNetto: ((1 + i.rendimento / 100) * (1 - i.costoAnnuo / 100) - 1) * 100
        )
    }

    // MARK: - Risparmio

    struct EsitoRisparmio {
        let esito: EsitoProiezione
        /// Obiettivo rivalutato all'inflazione fino alla scadenza.
        let obiettivoNominale: Double
        let mancante: Double
        let versamentoTeorico: Double?
        /// Quota dell'obiettivo raggiunta (0–100).
        let copertura: Double
    }

    static func risparmio(_ i: IpotesiRisparmio) -> EsitoRisparmio {
        let p = i.parametri
        let e = MotoreProiezione.calcola(p)
        let obiettivo = i.obiettivo * pow(1 + i.inflazione / 100, Double(max(0, i.anni)))
        return EsitoRisparmio(
            esito: e, obiettivoNominale: obiettivo, mancante: max(0, obiettivo - e.netto),
            versamentoTeorico: versamentoNecessario(p, obiettivo: obiettivo),
            copertura: obiettivo > 0 ? min(100, e.netto / obiettivo * 100) : 100
        )
    }

    // MARK: - Metodo

    static func metodo(_ a: AreaAnalisi) -> String {
        switch a {
        case .previdenza:
            return "Importi mensili netti in euro di oggi. La pensione pubblica e l'età di uscita sono ipotesi inserite: la stima con il metodo contributivo (dai dati «Lavoro e contributi» della scheda, con un controllo semplificato dei requisiti) è un aiuto da verificare sull'estratto conto INPS e conta solo se la copi nelle ipotesi. Divario = max(0, reddito desiderato − pensione pubblica). Capitale obiettivo = divario × 12 × anni di integrazione. Il montante parte dai piani previdenziali in essere e usa un rendimento annuo netto reale costante; il capitale è consumato negli anni scelti, senza rendimento dopo la pensione. Non è una rendita vitalizia né un preventivo di conversione. Contributo del datore, TFR conferito e deducibilità dei versamenti non entrano in questa proiezione semplificata: sono nel pannello «Il fisco dei versamenti» e nel prospetto della previdenza."
        case .protezione:
            return "Fabbisogno = max(0, debiti + spese immediate + sostegno mensile × 12 × anni − capitale destinato ai superstiti). Le coperture caso morte sono quelle in essere nelle posizioni del cliente, non scadute; il divario con le proposte somma anche le proposte caso morte ancora aperte. Riserva per un'interruzione del reddito = max(0, fabbisogno mensile − entrate sostitutive) × mesi. È un conteggio semplificato: non sconta i flussi futuri e non verifica le clausole. Esclusioni, carenze, franchigie, massimali e beneficiari vanno letti nelle condizioni di polizza."
        case .investimenti:
            return "Stesso modello delle posizioni: ogni mese il capitale cresce del rendimento mensile equivalente e paga la quota del costo annuo; i versamenti entrano al netto del costo d'ingresso. Alla fine l'imposta si applica alla sola plusvalenza; il valore reale divide per l'inflazione cumulata. Gli scenari spostano il rendimento di due punti. Il calo improvviso è una prova separata, non una previsione."
        case .risparmio:
            return "Stesso modello degli investimenti. L'obiettivo è in euro di oggi ed è rivalutato all'inflazione fino alla scadenza. Il versamento teorico è costante, mensile, e raggiunge l'obiettivo con le ipotesi inserite, senza garanzia di risultato."
        }
    }
}
