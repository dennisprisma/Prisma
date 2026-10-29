import Foundation

/// Fotografie dei riesami per le istantanee (specifica 12 §9): `DatiDemo` non cambia, le scene della memoria del
/// riesame preparano qui due fotografie passate di un cliente. Sono ricavate dalla fotografia di oggi con cifre
/// spostate in modo plausibile, così le variazioni si vedono tutte: profilo, famiglia, semafori, pensione,
/// protezione, obiettivi, patrimonio per canale, completezza e conformità.
/// Senza `@MainActor`: la chiamano le chiusure delle scene di `Istantanee` (come i suoi aiuti `nonisolated`) e
/// tocca solo `StatoShell`, che non è legato a un attore.
enum DatiMemoriaDemo {
    /// Due fotografie passate di un cliente ricavate da quella di oggi, con cifre spostate in modo plausibile:
    /// 19 mesi fa (origini ["incontro"]) e 7 mesi fa (["prospetto", "incontro"]). Le aggiunge a s.dati.fotografie
    /// (al posto di quelle di una preparazione precedente).
    static func prepara(_ s: StatoShell, cliente id: String = "giulia", oggi: Date = Date()) {
        guard let a = s.fotografiaAttuale(id) else { return }
        let cal = Calendar.current
        let inizio = cal.startOfDay(for: oggi)
        func mesiFa(_ n: Int) -> Date { cal.startOfDay(for: cal.date(byAdding: .month, value: -n, to: inizio) ?? inizio) }

        let sette = passata(a, id: "foto-demo-2", data: mesiFa(7), origini: ["prospetto", "incontro"],
                            divario: 230, alleanza: 0.82, previdenza: nil, completezza: 15)
        let diciannove = passata(a, id: "foto-demo-1", data: mesiFa(19), origini: ["incontro"],
                                 divario: 380, alleanza: 0.7, previdenza: .rosso, completezza: 29)
        var elenco = s.dati.fotografie.filter { $0.id != "foto-demo-1" && $0.id != "foto-demo-2" }
        elenco.append(diciannove)
        elenco.append(sette)
        s.dati.fotografie = elenco
    }

    /// Una fotografia passata: `previdenza` nil = il semaforo della pensione un colore peggio di oggi.
    private static func passata(_ a: FotografiaRiesame, id: String, data: Date, origini: [String],
                                divario: Double, alleanza: Double, previdenza: Semaforo?, completezza: Int) -> FotografiaRiesame {
        func centinaia(_ v: Double) -> Double { (v / 100).rounded() * 100 }
        var f = a
        f.id = id
        f.data = data
        f.origini = origini
        // Profilo: un'altra propensione
        f.propensione = a.propensione == ProfiloInvestitore.Propensione.dinamica.rawValue
            ? ProfiloInvestitore.Propensione.aggressiva.rawValue
            : ProfiloInvestitore.Propensione.dinamica.rawValue
        // Famiglia: senza l'ultimo familiare (così compare «In famiglia: …»)
        if !f.famiglia.isEmpty { f.famiglia.removeLast() }
        // Pensione e protezione
        f.divarioPensione = a.divarioPensione.map { centinaia($0 + divario) }
        f.scopertoCasoMorte = a.scopertoCasoMorte.map { centinaia($0 + 60_000) }
        // Patrimonio per canale
        f.patrimonioAlleanza = centinaia(a.patrimonioAlleanza * alleanza)
        f.patrimonioIndipendente = centinaia(a.patrimonioIndipendente * 0.95)
        // Semaforo della pensione
        if let i = f.semafori.firstIndex(where: { $0.id == "previdenza" }) {
            if let previdenza {
                f.semafori[i].colore = previdenza.rawValue
            } else {
                switch Semaforo(rawValue: f.semafori[i].colore) {
                case .verde?: f.semafori[i].colore = Semaforo.giallo.rawValue
                case .giallo?: f.semafori[i].colore = Semaforo.rosso.rawValue
                default: break
                }
            }
        }
        // Il primo obiettivo più indietro
        if !f.obiettivi.isEmpty { f.obiettivi[0].quota = max(0, f.obiettivi[0].quota - 0.15) }
        // Completezza più bassa
        if let c = a.completezza {
            let n = max(0, c - completezza)
            f.completezza = n
            if n < 60 { f.livelloCompletezza = LivelloCompletezza.scarso.nome }
        }
        // Il questionario Alleanza scaduto
        if var voci = f.conformita, let i = voci.firstIndex(where: { $0.tipo == VoceConformita.Tipo.questionarioAlleanza.rawValue }) {
            voci[i].stato = "scaduta"
            f.conformita = voci
        }
        return f
    }
}
