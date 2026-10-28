import Foundation

// Letture derivate delle polizze multiramo a due parti (dalla versione 20 dell'archivio): gestione separata
// e fondi con dati separati. Le quote sono frazioni 0–1, salvo dove è scritto «0–100».
// I motori usano queste letture solo se `multiramoDivisa` è vero; altrimenti eseguono il codice di prima.

extension Posizione {
    /// Quota in gestione separata ipotizzata quando una multiramo non la indica (come la resistenza): un solo valore.
    static let quotaGestionePredefinita = MotoreResistenza.quotaGestioneSeparataPredefinita

    /// Multiramo con i dati delle due parti: i motori le calcolano separatamente.
    var multiramoDivisa: Bool {
        multiramo && (rendimentoGestione != nil || rendimentoFondi != nil || costoFondi != nil || sriFondi != nil
                      || volatilitaFondi != nil || quotaAzionariaFondi != nil || titoliStatoGestione != nil
                      || titoliStatoFondi != nil || ribilanciamento == true
                      // le condizioni della gestione separata valgono solo per la sua parte
                      || trattenuto != nil || retrocessione != nil || minimoGarantito != nil || consolidamento != nil)
    }

    /// Unit linked pura (Ramo III senza gestione separata).
    var unitLinked: Bool {
        guard regime == .polizza, !multiramo, !gestioneSeparata else { return false }
        return Self.ramoIII(tipologia.lowercased())
    }

    /// «Unit» come parola intera (non «comunità», «unità»), «Ramo III», fondi interni. Il testo va già in minuscolo.
    static func ramoIII(_ t: String) -> Bool {
        t.range(of: #"\bunit\b"#, options: .regularExpression) != nil
            || t.contains("ramo iii") || t.contains("fondo interno") || t.contains("fondi interni")
    }

    /// Riconoscimento della multiramo dal solo testo della tipologia (anche per le schede prodotto):
    /// «multiramo», «ibrida», oppure Ramo I (o gestione separata) insieme a Ramo III (unit linked, fondi interni).
    static func multiramo(tipologia: String) -> Bool {
        let t = tipologia.lowercased()
        if t.contains("multiramo") || t.contains("ibrid") { return true }
        // Nomi locali diversi dalle funzioni: `let ramoI = ramoI(t)` non compilerebbe
        let terzo = Self.ramoIII(t)
        let primo = Self.ramoI(t) || t.contains("gestione separata") || t.contains("gestioni separate")
        return primo && terzo
    }

    // MARK: - Le due parti

    /// Quota (0–1) in gestione separata: multiramo → indicata o 50%; Ramo I puro → 1; altrimenti 0.
    var parteGestione: Double {
        if multiramo { return min(max(quotaGestioneSeparata ?? Self.quotaGestionePredefinita, 0), 100) / 100 }
        return gestioneSeparata ? 1 : 0
    }

    /// Quota (0–1) nei fondi.
    var parteFondi: Double { 1 - parteGestione }

    /// true se la quota in gestione separata di una multiramo è la stima del 50%.
    var quotaGestioneStimata: Bool { multiramo && quotaGestioneSeparata == nil }

    /// Rendimento lordo della gestione separata (%). Se manca ma ci sono quello dei fondi e il complessivo, si
    /// ricava perché la media pesata torni al complessivo (solo se la parte GS è almeno il 10%, e mai sotto
    /// zero); altrimenti il complessivo, poi l'ipotesi predefinita. Usare il complessivo per la GS la
    /// sopravvaluterebbe e sottovaluterebbe i fondi.
    func lordoGestione(predefinito: Double = IpotesiCalcolo.rendimentoPredefinito) -> Double {
        if let r = rendimentoGestione { return r }
        if let c = rendimentoAtteso, let f = rendimentoFondi, parteGestione >= 0.1 {
            return max(0, (c - parteFondi * f) / parteGestione)
        }
        return rendimentoAtteso ?? predefinito
    }

    /// Rendimento lordo dei fondi (%), con la stessa regola di `lordoGestione` (parte fondi almeno il 10%).
    func lordoFondi(predefinito: Double = IpotesiCalcolo.rendimentoPredefinito) -> Double {
        if let r = rendimentoFondi { return r }
        if let c = rendimentoAtteso, let g = rendimentoGestione, parteFondi >= 0.1 {
            return (c - parteGestione * g) / parteFondi
        }
        return rendimentoAtteso ?? predefinito
    }

    /// true se il rendimento di una parte non è indicato (ricavato dal complessivo o ipotizzato): va tra le ipotesi.
    var rendimentiPartiStimati: Bool { rendimentoGestione == nil || rendimentoFondi == nil }

    /// true se c'è almeno un rendimento (complessivo o di una parte): senza, l'andamento non ha la linea dell'atteso.
    var rendimentoIndicato: Bool { rendimentoAtteso != nil || rendimentoGestione != nil || rendimentoFondi != nil }

    /// Costi annui della parte in fondi (%): quelli dei fondi o, se mancano, il costo annuo del contratto.
    var costoParteFondi: Double { max(0, costoFondi ?? costoAnnuo ?? 0) }

    /// true se la posizione indica almeno un costo (dei fondi, di commissione o della GS).
    var costiIndicati: Bool { costoFondi != nil || costoAnnuo != nil || trattenuto != nil || retrocessione != nil }

    /// Bollo annuo (%) della parte in fondi: 0,20% se la polizza lo paga.
    var bolloFondi: Double { soggettaBollo ? RegoleFiscali.bollo : 0 }

    /// Rendimento accreditato dalla gestione separata (%): come `MotoreGestioneSeparata.accreditato`, con il
    /// consolidamento annuo se non indicato (come per il Ramo I).
    func accreditatoGestione(lordo: Double? = nil) -> Double {
        MotoreGestioneSeparata.accreditato(lordo: lordo ?? lordoGestione(), trattenuto: trattenuto,
                                           retrocessione: retrocessione, minimo: minimoGarantito,
                                           consolidamento: consolidamento ?? true)
    }

    /// Punti trattenuti davvero dalla gestione separata (mai negativi: il pavimento li riduce).
    var trattenutoGestione: Double { max(0, lordoGestione() - accreditatoGestione()) }

    /// Rendimento della parte in fondi al netto dei suoi costi (%), senza bollo: lordo − costi.
    var nettoFondi: Double { lordoFondi() - costoParteFondi }

    // MARK: - Complessivi, pesati sulle quote di oggi (per testi, Analisi 360, andamento, attenzioni)

    /// Rendimento lordo complessivo (%): media pesata dei lordi delle due parti.
    var rendimentoLordoComposto: Double { parteGestione * lordoGestione() + parteFondi * lordoFondi() }
    /// Rendimento netto complessivo (%): accreditato della GS e netto dei fondi, pesati.
    var rendimentoNettoComposto: Double { parteGestione * accreditatoGestione() + parteFondi * nettoFondi }
    /// Costo annuo complessivo: punti trattenuti sulla GS e costi dei fondi, ognuno sul suo capitale.
    var costoComposto: Double { parteGestione * trattenutoGestione + parteFondi * costoParteFondi }

    // MARK: - Fiscalità per parte

    /// Se il consulente indica i titoli di Stato di una parte sola, l'altra (senza i suoi e senza
    /// `quotaTitoliStato`) va al 26%: `aliquotaFiscale` è l'aliquota media del contratto e contiene già i
    /// titoli di Stato della GS, che così si conterebbero due volte.
    private var titoliPerParte: Bool { titoliStatoGestione != nil || titoliStatoFondi != nil }

    /// Aliquota sul guadagno della parte in gestione separata (%).
    var aliquotaGestione: Double {
        if let q = titoliStatoGestione ?? quotaTitoliStato { return RegoleFiscali.aliquotaEffettiva(quotaTitoliStato: q) }
        return titoliPerParte ? RegoleFiscali.ordinaria : (aliquotaFiscale ?? RegoleFiscali.ordinaria)
    }

    /// Aliquota sul guadagno della parte in fondi (%).
    var aliquotaFondi: Double {
        if let q = titoliStatoFondi ?? quotaTitoliStato { return RegoleFiscali.aliquotaEffettiva(quotaTitoliStato: q) }
        return titoliPerParte ? RegoleFiscali.ordinaria : (aliquotaFiscale ?? RegoleFiscali.ordinaria)
    }

    /// Aliquota pesata sui valori indicati: `valore` del contratto, di cui `valoreGestione` in gestione separata.
    func aliquotaPesata(valore: Double, valoreGestione: Double) -> Double {
        guard valore > 0 else { return aliquotaFondi }
        let g = min(max(valoreGestione, 0), valore)
        return (g * aliquotaGestione + (valore - g) * aliquotaFondi) / valore
    }

    // MARK: - Rischio

    /// Volatilità annua della parte in fondi (%), indicata o stimata (`MotoreMultiramo.volatilitaFondi`).
    var volatilitaParteFondi: Double { MotoreMultiramo.volatilitaFondi(self) }
    /// Volatilità della combinazione (%): la gestione separata non oscilla.
    var volatilitaComposta: Double { parteFondi * volatilitaParteFondi }
    /// SRI della parte in fondi: indicato o stimato dalla sua volatilità.
    var sriParteFondi: Int { sriFondi.map { min(max($0, 1), 7) } ?? MotoreMultiramo.classeSRI(volatilita: volatilitaParteFondi) }
    /// SRI stimato della combinazione dalla volatilità combinata (classi del Regolamento 2017/653).
    var sriStimatoComposto: Int { MotoreMultiramo.classeSRI(volatilita: volatilitaComposta) }
    /// SRI della combinazione per il profilo: quello del KID, altrimenti la stima.
    var sriComposto: Int { sri.map { min(max($0, 1), 7) } ?? sriStimatoComposto }
}
