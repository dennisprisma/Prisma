import Foundation

/// Testi brevi delle multiramo per i documenti su carta (prospetti e report di sostituzione e resoconto),
/// dove una cella o una riga sta su una riga sola: composizione e costi per parte. Le cifre vengono dalle
/// letture di `Posizione` (Dati/PosizioneMultiramo.swift); la riga lunga dei prospetti è
/// `MotoreMultiramo.rigaComposizione`.
enum TestiMultiramo {
    /// «GS 40% al 3,0% · fondi 60% al 5,5%» (lordi ipotizzati); senza i dati separati «GS 40% · fondi 60%»;
    /// con la quota stimata al 50% « (stimata)». Vuoto se la posizione non è una multiramo.
    static func composizioneBreve(_ p: Posizione) -> String {
        guard p.multiramo else { return "" }
        let stimata = p.quotaGestioneStimata ? " (stimata)" : ""
        guard p.multiramoDivisa else { return "GS \(quota(p.parteGestione)) · fondi \(quota(p.parteFondi))\(stimata)" }
        return "GS \(quota(p.parteGestione)) al \(CifreDoc.percento(p.lordoGestione()))"
            + " · fondi \(quota(p.parteFondi)) al \(CifreDoc.percento(p.lordoFondi()))\(stimata)"
    }

    /// «GS 1,30 punti · fondi 2,30%»: punti trattenuti dalla gestione separata e costi annui dei fondi
    /// (senza il bollo). Vuoto se la multiramo non ha i dati separati.
    static func costiPerParte(_ p: Posizione) -> String {
        guard p.multiramoDivisa else { return "" }
        return "GS \(punti(p.trattenutoGestione)) punti · fondi \(CifreDoc.percento(p.costoParteFondi, decimali: 2))"
    }

    /// «sul 40% in GS»: a quale parte del valore si applica il trattenuto.
    static func sullaGestione(_ p: Posizione) -> String { "sul \(quota(p.parteGestione)) in GS" }
    /// «sul 60% in fondi»: a quale parte del valore si applicano commissioni, costi dei fondi e bollo.
    static func suiFondi(_ p: Posizione) -> String { "sul \(quota(p.parteFondi)) in fondi" }

    /// « (per la gestione separata delle multiramo 1 punto)» se una delle posizioni è una multiramo a due
    /// parti: negli scenari la gestione separata si sposta meno dei fondi. Altrimenti vuoto.
    static func notaScenari(_ posizioni: [Posizione]) -> String {
        guard posizioni.contains(where: { $0.multiramoDivisa }) else { return "" }
        let cifra = Formati.numeroFormatter.string(from: NSNumber(value: IpotesiCalcolo.ampiezzaScenariGestione)) ?? "1"
        return " (per la gestione separata delle multiramo \(cifra) \(IpotesiCalcolo.ampiezzaScenariGestione == 1 ? "punto" : "punti"))"
    }

    /// Punti di rendimento con due decimali, senza il simbolo: «1,30».
    static func punti(_ v: Double) -> String { String(CifreDoc.percento(v, decimali: 2).dropLast()) }

    /// Quota 0–1 come percentuale con al più un decimale: «40%», «62,5%».
    static func quota(_ q: Double) -> String { Formati.percentuale((q * 1000).rounded() / 10) }
}
