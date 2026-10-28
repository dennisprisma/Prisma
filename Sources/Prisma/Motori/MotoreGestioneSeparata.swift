import Foundation

/// La gestione separata di una polizza rivalutabile di Ramo I, letta dai dati della posizione:
/// rendimento lordo ipotizzato, quanto trattiene la compagnia (trattenuto fisso o retrocessione),
/// rendimento accreditato con il minimo garantito, consolidamento e rendimento reale.
struct EsitoGestioneSeparata {
    /// Rendimento lordo della gestione ipotizzato (% annuo): il rendimento atteso della posizione.
    let lordo: Double
    /// Trattenuto indicato (punti l'anno) e retrocessione indicata (% del lordo), se ci sono.
    let trattenutoIndicato: Double?
    let retrocessione: Double?
    /// Rendimento al cliente prima del minimo garantito (%).
    let netto: Double
    let minimoGarantito: Double?
    /// true: i rendimenti si consolidano ogni anno; false: garanzia solo a scadenza o al decesso; nil: non indicato.
    let consolidamento: Bool?
    /// Rendimento accreditato ogni anno (%): il netto, ma mai sotto il minimo garantito (o sotto zero)
    /// quando i rendimenti si consolidano.
    let accreditato: Double
    /// Inflazione ipotizzata (% annuo).
    let inflazione: Double
    /// Euro che la compagnia trattiene in un anno sul valore di oggi.
    let trattenutoEuro: Double
    /// Valore minimo garantito alla scadenza, prima delle imposte (nil senza scadenza).
    let garantitoAScadenza: Double?

    /// Punti di rendimento che restano alla compagnia (mai negativi).
    var trattenuto: Double { max(0, lordo - accreditato) }
    /// true se il minimo garantito (o il capitale garantito) alza il rendimento netto.
    var minimoDecisivo: Bool { accreditato > netto + 0.000_001 }
    /// Rendimento accreditato tolta l'inflazione ipotizzata (%): (1 + accreditato) / (1 + inflazione) − 1.
    var reale: Double { MotoreGestioneSeparata.reale(accreditato, inflazione: inflazione) }
}

enum MotoreGestioneSeparata {
    /// Nota di metodo per prospetti e schede.
    static let metodo = "Gestione separata: rendimento al cliente = lordo meno trattenuto, o la quota retrocessa del lordo (non oltre il lordo meno il trattenuto minimo, se indicato). Con il consolidamento annuo il rendimento accreditato non scende mai sotto il minimo garantito (o sotto zero): il capitale non scende. Senza consolidamento la garanzia vale solo a scadenza o al decesso: prima il valore può scendere. Rendimento reale: tolta l'inflazione ipotizzata. Nelle multiramo la garanzia vale solo sulla parte in gestione separata; per una posizione in essere il garantito a scadenza è stimato sulla quota di oggi dei versamenti."

    /// Rendimento al cliente (%) prima del minimo garantito. Senza retrocessione: lordo meno trattenuto
    /// (come sempre in Prisma). Con la retrocessione: la quota retrocessa del lordo e, se c'è anche il
    /// trattenuto, non più del lordo meno il trattenuto (trattenuto minimo). Con un lordo negativo o nullo
    /// la retrocessione non attenua la perdita: si toglie solo il trattenuto (scelta prudente).
    static func netto(lordo: Double, trattenuto: Double?, retrocessione: Double?) -> Double {
        guard let retrocessione else { return lordo - (trattenuto ?? 0) }
        guard lordo > 0 else { return lordo - (trattenuto ?? 0) }
        let retrocesso = lordo * min(max(retrocessione, 0), 100) / 100
        if let trattenuto { return min(retrocesso, lordo - trattenuto) }
        return retrocesso
    }

    /// Rendimento accreditato (%): con il consolidamento mai sotto il minimo garantito (0 se non indicato:
    /// il capitale non scende); senza consolidamento il minimo vale solo a scadenza, non anno per anno.
    static func accreditato(lordo: Double, trattenuto: Double?, retrocessione: Double?, minimo: Double?, consolidamento: Bool) -> Double {
        let n = netto(lordo: lordo, trattenuto: trattenuto, retrocessione: retrocessione)
        return consolidamento ? max(n, max(0, minimo ?? 0)) : n
    }

    /// Rendimento accreditato da una parte di un contratto (`MotoreValutazione`): senza i dati nuovi è il
    /// lordo meno il trattenuto senza alcun pavimento, come prima. Il pavimento (minimo garantito, o zero)
    /// vale solo se il consolidamento annuo è indicato: un riscatto anticipato non ha la garanzia di scadenza.
    static func accreditato(_ c: ComponenteContratto, lordo: Double) -> Double {
        // Con la retrocessione il trattenuto, se indicato, è il minimo trattenuto
        let trattenuto: Double? = c.retrocessione == nil || c.trattenuto > 0 ? c.trattenuto : nil
        let n = netto(lordo: lordo, trattenuto: trattenuto, retrocessione: c.retrocessione)
        guard c.consolidamento == true else { return n }
        return max(n, max(0, c.minimoGarantito ?? 0))
    }

    /// Punti di rendimento da trattare come costo annuo nella proiezione di una posizione: senza retrocessione
    /// il trattenuto indicato (come prima); con la retrocessione la parte del rendimento atteso non retrocessa.
    static func trattenuto(_ p: Posizione) -> Double {
        guard p.retrocessione != nil else { return p.trattenuto ?? 0 }
        let lordo = p.rendimentoAtteso ?? IpotesiCalcolo.rendimentoPredefinito
        return max(0, lordo - netto(lordo: lordo, trattenuto: p.trattenuto, retrocessione: p.retrocessione))
    }

    /// Rendimento reale (%): (1 + nominale) / (1 + inflazione) − 1.
    static func reale(_ nominale: Double, inflazione: Double = IpotesiCalcolo.inflazione) -> Double {
        ((1 + nominale / 100) / (1 + inflazione / 100) - 1) * 100
    }

    /// I numeri della gestione separata di una posizione (solo polizze rivalutabili di Ramo I).
    static func calcola(_ p: Posizione, inflazione: Double = IpotesiCalcolo.inflazione) -> EsitoGestioneSeparata? {
        guard p.gestioneSeparata else { return nil }
        let lordo = p.rendimentoAtteso ?? IpotesiCalcolo.rendimentoPredefinito
        let n = netto(lordo: lordo, trattenuto: p.trattenuto, retrocessione: p.retrocessione)
        // Come nella proiezione: senza indicazione i rendimenti si considerano consolidati
        let accreditatoAnno = Self.accreditato(lordo: lordo, trattenuto: p.trattenuto, retrocessione: p.retrocessione,
                                               minimo: p.minimoGarantito, consolidamento: p.consolidamento ?? true)
        let valore = p.stato == .inEssere ? p.valore : p.versamentoIniziale
        return EsitoGestioneSeparata(lordo: lordo, trattenutoIndicato: p.trattenuto, retrocessione: p.retrocessione,
                                     netto: n, minimoGarantito: p.minimoGarantito, consolidamento: p.consolidamento,
                                     accreditato: accreditatoAnno, inflazione: inflazione,
                                     trattenutoEuro: valore * max(0, lordo - accreditatoAnno) / 100,
                                     garantitoAScadenza: garantitoAScadenza(p))
    }

    /// La parte in gestione separata di una multiramo a due parti, come un Ramo I a sé: lordo, accreditato e
    /// trattenuto in euro valgono sul valore della sola parte; il garantito a scadenza sui versamenti in
    /// gestione separata, rivalutati al minimo. nil se la posizione non è una multiramo a due parti.
    static func calcolaParte(_ p: Posizione, inflazione: Double = IpotesiCalcolo.inflazione) -> EsitoGestioneSeparata? {
        guard p.multiramoDivisa, p.parteGestione > 0 else { return nil }
        return calcola(MotoreMultiramo.posizioneGestione(p), inflazione: inflazione)
    }

    /// Il valore minimo garantito alla scadenza, prima delle imposte: con il consolidamento il valore di oggi
    /// (già consolidato), senza il versato; più i versamenti futuri al netto dell'ingresso, tutto rivalutato
    /// al minimo garantito (0% se non indicato). nil senza scadenza.
    static func garantitoAScadenza(_ p: Posizione) -> Double? {
        guard p.gestioneSeparata, p.scadenza != nil else { return nil }
        var par = ParametriProiezione(posizione: p)
        par.rendimento = max(0, p.minimoGarantito ?? 0)
        par.costoAnnuo = 0
        par.aliquotaFiscale = 0
        par.tassazioneAnnua = 0
        par.aliquotaSulVersato = 0
        par.nonDedotti = 0
        par.inflazione = 0
        par.capitaleGarantito = false
        par.minimoGarantito = nil
        par.mesiGaranzia = nil
        if p.stato == .inEssere && p.consolidamento == false {
            // Garanzia solo a scadenza: vale sul versato al netto dell'ingresso, non sul valore di oggi
            par.capitaleIniziale = (p.totaleVersato ?? p.valore) * (1 - min(max(p.costoIngresso ?? 0, 0), 99) / 100)
        }
        return MotoreProiezione.calcola(par).lordo
    }
}
