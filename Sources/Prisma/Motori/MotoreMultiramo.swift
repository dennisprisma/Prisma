import Foundation

/// Polizze multiramo a due parti (dalla versione 20 dell'archivio): una quota in gestione separata e una
/// quota nei fondi (Ramo III), ognuna con i suoi rendimenti, costi e rischio. Qui ci sono le regole comuni ai
/// motori: classi di rischio, le due parti come posizioni a sé, la copia dalla scheda prodotto e i testi.
/// I motori le usano solo se `Posizione.multiramoDivisa` è vero; altrimenti resta il calcolo di prima.
enum MotoreMultiramo {
    /// Soglie di volatilità delle classi di rischio di mercato (MRM) del Regolamento delegato UE 2017/653,
    /// allegato II: 1 sotto 0,5%; 2 fino al 5%; 3 fino al 12%; 4 fino al 20%; 5 fino al 30%; 6 fino all'80%; 7 oltre.
    static let soglieSRI: [Double] = [0.5, 5, 12, 20, 30, 80]

    /// Classe di rischio (1–7) di una volatilità annua (%). Solo rischio di mercato, senza il rischio di
    /// credito: una stima, da marcare «stimato».
    static func classeSRI(volatilita v: Double) -> Int { (soglieSRI.firstIndex { v < $0 } ?? 6) + 1 }

    /// Volatilità della parte in fondi (%): indicata; dall'SRI dei fondi; dalla quota azionaria dei fondi;
    /// dall'SRI della combinazione riportato alla sola parte in fondi; dall'SRI probabile dell'area.
    static func volatilitaFondi(_ p: Posizione) -> Double {
        if let v = p.volatilitaFondi { return max(0, v) }
        if let s = p.sriFondi { return MotoreMonteCarlo.volatilitaPerSRI[min(max(s, 1), 7)] ?? 0 }
        if let a = p.quotaAzionariaFondi {
            let q = min(max(a, 0), 100) / 100
            return q * MotoreMonteCarlo.volatilitaAzioni + (1 - q) * MotoreMonteCarlo.volatilitaObbligazioni
        }
        if let s = p.sri, p.parteFondi >= 0.2 {
            // L'SRI del KID è della combinazione, GS compresa: la volatilità dei soli fondi è più alta.
            // Sotto il 20% in fondi la divisione amplifica troppo (SRI 2 con il 10% in fondi darebbe 30%,
            // SRI 6): meglio l'SRI probabile dell'area.
            return min((MotoreMonteCarlo.volatilitaPerSRI[min(max(s, 1), 7)] ?? 0) / p.parteFondi,
                       MotoreMonteCarlo.volatilitaPerSRI[7] ?? 50)
        }
        return MotoreMonteCarlo.volatilitaPerSRI[MotoreResistenza.sriProbabile(p.area)] ?? 0
    }

    // MARK: - Le due parti come posizioni a sé

    /// La parte in fondi come posizione a sé (Ramo III), per riusare composizione e crisi.
    static func posizioneFondi(_ p: Posizione) -> Posizione {
        var f = parte(p, quota: p.parteFondi)
        f.tipologia = "Unit linked (Ramo III)"
        f.rendimentoAtteso = p.lordoFondi()
        f.costoAnnuo = p.costoParteFondi
        f.trattenuto = nil
        f.retrocessione = nil
        f.minimoGarantito = nil
        f.consolidamento = nil
        f.sri = p.sriParteFondi
        f.volatilita = p.volatilitaParteFondi
        f.quotaAzionaria = p.quotaAzionariaFondi
        // Senza ripiego sui titoli di Stato del contratto: rimetterebbe tra i governativi dei fondi quelli
        // della gestione separata (l'aliquota dei fondi la dà `aliquotaFondi`)
        f.quotaTitoliStato = p.titoliStatoFondi
        return f
    }

    /// La parte in gestione separata come Ramo I a sé, per riusare `MotoreGestioneSeparata.calcola`.
    static func posizioneGestione(_ p: Posizione) -> Posizione {
        var g = parte(p, quota: p.parteGestione)
        g.tipologia = "Polizza rivalutabile Ramo I"
        g.rendimentoAtteso = p.lordoGestione()
        g.costoAnnuo = nil
        // trattenuto, retrocessione, minimo garantito e consolidamento restano quelli della posizione
        g.quotaTitoliStato = p.titoliStatoGestione ?? p.quotaTitoliStato
        g.conBollo = false
        // La gestione separata non segue i mercati
        g.sri = nil
        g.volatilita = nil
        g.quotaAzionaria = nil
        return g
    }

    /// Copia di una posizione ridotta a una parte: importi per la quota, dati del contratto intero tolti
    /// (garanzie, movimenti, rilevazioni), campi separati a nil perché la copia non sia a sua volta divisa.
    private static func parte(_ p: Posizione, quota: Double) -> Posizione {
        var c = p
        c.controvalore = p.valore * quota
        c.totaleVersato = p.totaleVersato.map { $0 * quota }
        c.versamentoIniziale = p.versamentoIniziale * quota
        c.premio = p.premio * quota
        c.quotaGestioneSeparata = nil
        c.garanzie = ""
        c.movimenti = nil
        c.rilevazioni = nil
        c.rendimentoGestione = nil
        c.rendimentoFondi = nil
        c.costoFondi = nil
        c.sriFondi = nil
        c.volatilitaFondi = nil
        c.quotaAzionariaFondi = nil
        c.titoliStatoGestione = nil
        c.titoliStatoFondi = nil
        c.ribilanciamento = nil
        return c
    }

    // MARK: - Dalla scheda prodotto

    /// Le condizioni della scheda prodotto che la posizione non ha: costi, garanzie della gestione separata e
    /// le due parti della multiramo (dai campi della scheda o, se mancano, dalle parti delle condizioni).
    /// Non sovrascrive ciò che la posizione indica già. La quota in gestione separata si copia solo per una
    /// posizione non in essere: la quota della scheda è la ripartizione del premio, quella di una posizione in
    /// essere è la ripartizione del valore di oggi e si legge sull'estratto conto.
    static func applica(_ s: Prodotto, a p: inout Posizione) {
        let multiramo = p.multiramo
        let copiaQuota = p.stato != .inEssere
        // 1. Campi diretti della scheda
        p.trattenuto = p.trattenuto ?? s.trattenuto
        p.retrocessione = p.retrocessione ?? s.retrocessione
        p.minimoGarantito = p.minimoGarantito ?? s.minimoGarantito
        p.consolidamento = p.consolidamento ?? s.consolidamento
        if multiramo {
            if copiaQuota { p.quotaGestioneSeparata = p.quotaGestioneSeparata ?? s.quotaGestioneSeparata }
            p.rendimentoGestione = p.rendimentoGestione ?? s.rendimentoGestione
            p.rendimentoFondi = p.rendimentoFondi ?? s.rendimentoFondi
            p.costoFondi = p.costoFondi ?? s.costoFondi
            p.sriFondi = p.sriFondi ?? s.sriFondi
            p.volatilitaFondi = p.volatilitaFondi ?? s.volatilitaFondi
            p.quotaAzionariaFondi = p.quotaAzionariaFondi ?? s.quotaAzionariaFondi
            p.titoliStatoGestione = p.titoliStatoGestione ?? s.titoliStatoGestione
            p.titoliStatoFondi = p.titoliStatoFondi ?? s.titoliStatoFondi
            p.ribilanciamento = p.ribilanciamento ?? s.ribilanciamento
        }

        // 2. Le parti delle condizioni del contratto, per ciò che manca ancora
        guard let parti = s.condizioni?.componenti, !parti.isEmpty, multiramo || p.gestioneSeparata else { return }
        let gs = parti.filter { $0.tipo == .gestioneSeparata }
        let fi = parti.filter { $0.tipo == .fondoInterno }
        let somma = max(parti.reduce(0) { $0 + $1.quota }, 0.0001)
        let sommaGS = gs.reduce(0) { $0 + $1.quota }
        let sommaFI = fi.reduce(0) { $0 + $1.quota }

        /// Media pesata per quota di un valore, sulle parti che lo hanno (nil se nessuna).
        func media(_ elenco: [ComponenteContratto], _ valore: (ComponenteContratto) -> Double?) -> Double? {
            let con: [(Double, Double)] = elenco.compactMap { c in valore(c).map { (c.quota, $0) } }
            let pesi = con.reduce(0) { $0 + $1.0 }
            guard !con.isEmpty else { return nil }
            guard pesi > 0 else { return con.reduce(0) { $0 + $1.1 } / Double(con.count) }
            return con.reduce(0) { $0 + $1.0 * $1.1 } / pesi
        }

        if let primaGS = gs.first {
            if p.trattenuto == nil {
                let t = gs.reduce(0) { $0 + $1.quota * $1.trattenuto } / max(sommaGS, 0.0001)
                if t > 0 || !gs.contains(where: { $0.retrocessione != nil }) { p.trattenuto = t }
            }
            p.retrocessione = p.retrocessione ?? primaGS.retrocessione
            p.minimoGarantito = p.minimoGarantito ?? primaGS.minimoGarantito
            p.consolidamento = p.consolidamento ?? primaGS.consolidamento
        }
        // Le regole delle due parti valgono solo per le multiramo
        guard multiramo else { return }

        if copiaQuota, p.quotaGestioneSeparata == nil { p.quotaGestioneSeparata = 100 * sommaGS / somma }
        if !gs.isEmpty {
            if p.rendimentoGestione == nil {
                if let r = media(gs, { $0.rendimentoAtteso }) {
                    p.rendimentoGestione = r
                } else if let storico = gs.first?.storico.compactMap(\.valore), !storico.isEmpty {
                    // La media dello storico della prima gestione separata, al decimo
                    p.rendimentoGestione = (storico.reduce(0, +) / Double(storico.count) * 10).rounded() / 10
                }
            }
            p.titoliStatoGestione = p.titoliStatoGestione ?? media(gs, { $0.titoliStato })
        }
        if !fi.isEmpty {
            if p.costoFondi == nil {
                p.costoFondi = fi.reduce(0) { $0 + $1.quota * ($1.commissione + $1.costiSottostanti) } / max(sommaFI, 0.0001)
            }
            p.rendimentoFondi = p.rendimentoFondi ?? media(fi, { $0.rendimentoAtteso })
            p.volatilitaFondi = p.volatilitaFondi ?? media(fi, { $0.volatilita })
            p.quotaAzionariaFondi = p.quotaAzionariaFondi ?? media(fi, { $0.quotaAzionaria })
            // Prudente: il più alto tra gli SRI dei fondi, non la media
            p.sriFondi = p.sriFondi ?? fi.compactMap(\.sri).max()
            p.titoliStatoFondi = p.titoliStatoFondi ?? media(fi, { $0.titoliStato })
        }
    }

    // MARK: - Costi, scenari e testi

    /// Toglie i costi del prodotto e lascia il bollo, che è un'imposta.
    static func senzaCostiProdotto(_ par: ParametriProiezione, _ p: Posizione) -> ParametriProiezione {
        var s = par
        s.costoIngresso = 0
        s.costoAnnuo = p.bolloFondi
        s.gestione?.trattenuto = nil
        s.gestione?.retrocessione = nil
        return s
    }

    /// Testo «di cui gestione separata 40% al 3,00% · fondi 60% al 5,50%» (lordi ipotizzati). Per una
    /// multiramo senza i dati separati solo le quote; «(quota stimata)» se la quota è la stima del 50%.
    /// Vuoto se la posizione non è una multiramo.
    static func rigaComposizione(_ p: Posizione) -> String {
        guard p.multiramo else { return "" }
        let quotaG = Formati.percentuale(p.parteGestione * 100)
        let quotaF = Formati.percentuale(p.parteFondi * 100)
        let stimata = p.quotaGestioneStimata ? " (quota stimata)" : ""
        guard p.multiramoDivisa else { return "di cui gestione separata \(quotaG) · fondi \(quotaF)\(stimata)" }
        return "di cui gestione separata \(quotaG) al \(CifreDoc.percento(p.lordoGestione(), decimali: 2))"
            + " · fondi \(quotaF) al \(CifreDoc.percento(p.lordoFondi(), decimali: 2))\(stimata)"
    }

    /// Di quanto si sposta il rendimento complessivo in uno scenario con scarto `scarto` sui fondi: per le
    /// multiramo divise q·scarto·(1/2) + (1−q)·scarto, altrimenti `scarto`. Per i testi «+2 punti» dei
    /// prospetti di sostituzione.
    static func scartoEquivalente(_ p: Posizione, scarto: Double) -> Double {
        guard p.multiramoDivisa else { return scarto }
        let q = p.parteGestione
        return q * scarto * IpotesiCalcolo.ampiezzaScenariGestione / IpotesiCalcolo.ampiezzaScenari + (1 - q) * scarto
    }

    /// Nota di metodo per prospetti e «Come viene calcolato».
    static let metodo = "Multiramo a due parti: la parte in gestione separata si rivaluta del rendimento lordo meno il trattenuto (o della quota retrocessa) e, se il consolidamento è annuo, non scende mai sotto il minimo garantito; la parte in fondi cresce del rendimento lordo meno commissioni e costi dei fondi e paga il bollo dello 0,20%, l'unica parte che lo paga. Senza ribilanciamento le due parti si allontanano dalle quote iniziali; con il ribilanciamento annuo si riportano ogni anno alla quota scelta; gli spostamenti interni non sono tassati. L'imposta è una sola, sul guadagno del contratto, con l'aliquota pesata sulle due parti (stima sulla quota di titoli di Stato indicata). Rischio di mercato solo sulla parte in fondi; la gestione separata non segue i mercati ed è garantita secondo il consolidamento: annuo, sempre; altrimenti solo a scadenza o al decesso. Per una posizione in essere la quota dei versamenti in gestione separata è stimata con la quota di oggi. I versamenti futuri si dividono con la quota di oggi."
}
