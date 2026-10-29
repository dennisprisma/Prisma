import Foundation

/// I testi del riesame con memoria (specifica 12 §4): formati delle cifre, nomi, frasi della scheda «Riesami», dei
/// riquadri brevi, del prospetto e degli avvisi. Solo costanti e funzioni pure, in italiano. Le soglie citate nei
/// testi vengono dalle costanti di `MotoreMemoria`: nessun numero scritto due volte.
enum TestiMemoria {
    typealias Origine = FotografiaRiesame.Origine

    // MARK: - Formati (§3.4)

    /// Il segno di un valore che non c'era.
    static let vuoto = "—"
    static let euroUnita = "€"
    static let euroMese = "€/mese"

    /// Intero arrotondato con i separatori italiani: 51500 → «51.500», 409,6 → «410», −6000 → «−6.000».
    static func cifra(_ v: Double) -> String {
        guard v.isFinite else { return vuoto }
        var r = v.rounded()
        if r == 0 { r = 0 }   // niente «−0»
        return Formati.numeroFormatter.string(from: NSNumber(value: r)) ?? String(format: "%.0f", r)
    }

    /// Una quota 0–1 in percentuale intera (le quote si confrontano sempre così: 0,45 − 0,40 fa 0,04999…).
    static func percento(_ q: Double) -> Int {
        guard q.isFinite else { return 0 }
        return Int(min(max(q * 100, -1_000_000), 1_000_000).rounded())
    }

    /// Con l'elisione davanti a una vocale: 1, 8, 11, 80–89, 800–899 («dall'8%», «all'11%»).
    private static func elide(_ n: Int) -> Bool {
        n == 1 || n == 8 || n == 11 || (80...89).contains(n) || (800...899).contains(n)
    }

    /// «dal 40%», «dall'8%», «dallo 0%».
    static func dal(_ n: Int) -> String {
        if n == 0 { return "dallo 0%" }
        return (elide(n) ? "dall'" : "dal ") + "\(n)%"
    }

    /// «al 77%», «all'11%», «allo 0%».
    static func al(_ n: Int) -> String {
        if n == 0 { return "allo 0%" }
        return (elide(n) ? "all'" : "al ") + "\(n)%"
    }

    /// La differenza con il segno attaccato alla cifra: «+9.500 €», «−230 €/mese».
    static func differenza(_ d: Double, unita: String) -> String {
        let r = d.isFinite ? d.rounded() : 0
        let segno = r > 0 ? "+" : (r < 0 ? Formati.meno : "")
        return "\(segno)\(cifra(abs(r))) \(unita)"
    }

    /// «+15 punti», «−6 punti», «+1 punto».
    static func punti(_ n: Int) -> String {
        let segno = n > 0 ? "+" : (n < 0 ? Formati.meno : "")
        return "\(segno)\(abs(n)) \(abs(n) == 1 ? "punto" : "punti")"
    }

    /// «1 anno», «10 anni».
    static func anni(_ n: Int) -> String { n == 1 ? "1 anno" : "\(n) anni" }

    /// «12 marzo 2026».
    static func data(_ d: Date) -> String { Formati.dataEstesa.string(from: d) }

    /// Un importo in euro o «—»: «185.000 €».
    static func euro(_ v: Double?) -> String { v.map { "\(cifra($0)) \(euroUnita)" } ?? vuoto }

    /// Un importo al mese o «—»: «410 €/mese».
    static func euroAlMese(_ v: Double?) -> String { v.map { "\(cifra($0)) \(euroMese)" } ?? vuoto }

    // MARK: - Nomi

    /// Il nome della propensione in minuscolo («moderata»); un valore sconosciuto resta com'è.
    static func propensione(_ raw: String) -> String {
        ProfiloInvestitore.Propensione(rawValue: raw)?.nome.lowercased() ?? raw
    }

    /// La propensione di una fotografia o «—».
    static func propensioneBreve(_ raw: String?) -> String { raw.map(propensione) ?? vuoto }

    /// Il nome dell'esperienza in minuscolo («media»); un valore sconosciuto resta com'è.
    static func esperienza(_ raw: String) -> String {
        ProfiloInvestitore.Esperienza(rawValue: raw)?.nome.lowercased() ?? raw
    }

    /// «convivente», «coniugato/a»; un valore sconosciuto resta com'è.
    static func statoCivile(_ raw: String) -> String {
        StatoCivile(rawValue: raw)?.nome.lowercased() ?? raw
    }

    /// «figlia», «fratello / sorella»; un valore sconosciuto resta com'è.
    static func relazione(_ raw: String) -> String {
        Familiare.Relazione(rawValue: raw)?.nome.lowercased() ?? raw
    }

    /// «verde», «giallo», «rosso», «grigio», altrimenti «non indicato».
    static func colore(_ raw: String) -> String {
        switch raw {
        case "verde", "giallo", "rosso", "grigio": return raw
        default: return "non indicato"
        }
    }

    /// L'etichetta di uno stato di conformità (regola 18): «scadenza superata», «mancante», «in scadenza»,
    /// «in regola»; uno sconosciuto resta com'è.
    static func statoConformita(_ raw: String) -> String {
        switch raw {
        case "scaduta": return "scadenza superata"
        case "mancante": return "mancante"
        case "entro30", "entro60": return "in scadenza"
        case "inRegola": return "in regola"
        default: return raw
        }
    }

    // MARK: - Tempo

    /// «meno di un mese fa», «7 mesi fa», «1 anno fa», «1 anno e 2 mesi fa», «2 anni e 1 mese fa».
    static func tempoFa(mesi: Int) -> String {
        let n = max(0, mesi)
        if n == 0 { return "meno di un mese fa" }
        if n < 12 { return n == 1 ? "1 mese fa" : "\(n) mesi fa" }
        let a = n / 12
        let m = n % 12
        let anni = a == 1 ? "1 anno" : "\(a) anni"
        if m == 0 { return "\(anni) fa" }
        return "\(anni) e \(m == 1 ? "1 mese" : "\(m) mesi") fa"
    }

    /// I mesi interi tra due date, mai negativi.
    static func mesi(da: Date, a: Date, cal: Calendar = .current) -> Int {
        max(0, cal.dateComponents([.month], from: da, to: a).month ?? 0)
    }

    // MARK: - Origini

    /// La pillola dell'origine.
    static func origine(_ o: Origine) -> String {
        switch o {
        case .prospetto: return "Prospetto"
        case .incontro: return "Incontro"
        case .appuntamento: return "Appuntamento"
        case .manuale: return "A mano"
        }
    }

    /// L'aiuto della pillola.
    static func origineEstesa(_ o: Origine) -> String {
        switch o {
        case .prospetto: return "Prospetto del riesame archiviato, salvato, stampato o presentato"
        case .incontro: return "Incontro di revisione concluso"
        case .appuntamento: return "Appuntamento di revisione segnato concluso"
        case .manuale: return "Salvata a mano"
        }
    }

    // MARK: - Scheda «Riesami»

    static let titoloCambiato = "Cosa è cambiato"

    /// «Dal riesame del 12 marzo 2026 · 7 mesi fa».
    static func notaCambiato(data d: Date, tempo: String) -> String { "Dal riesame del \(data(d)) · \(tempo)" }

    static let primaFotografia = "Prima fotografia: da questo riesame Prisma conserva le cifre chiave del cliente e al prossimo mostra che cosa è cambiato."

    static let nessunaFotografia = "Nessuna fotografia salvata. Prisma ne salva una a ogni riesame: quando archivi, salvi, stampi o presenti il prospetto del riesame, quando concludi un incontro o un appuntamento di revisione, oppure con «\(salvaOggi)»."

    /// «L'ultima fotografia è del 20 ottobre 2026, meno di 30 giorni fa: …».
    static func soloRecenti(data d: Date) -> String {
        let g = MotoreMemoria.giorniTraRiesami
        return "L'ultima fotografia è del \(data(d)), meno di \(g) giorni fa: fa parte di questo riesame. Il confronto si fa con una fotografia di almeno \(g) giorni prima."
    }

    /// «Dal riesame del 12 marzo 2026 nessuna variazione delle cifre chiave.»
    static func nessunaVariazione(data d: Date) -> String {
        "Dal riesame del \(data(d)) nessuna variazione delle cifre chiave."
    }

    /// «13 variazioni: 6 in meglio, 1 in peggio.»; «3 variazioni, nessuna da giudicare.»
    static func riassunto(_ v: [VariazioneRiesame]) -> String {
        let n = v.count
        if n == 0 { return "Nessuna variazione." }
        let quante = n == 1 ? "1 variazione" : "\(n) variazioni"
        let meglio = v.filter { $0.verso == .meglio }.count
        let peggio = v.filter { $0.verso == .peggio }.count
        var parti: [String] = []
        if meglio > 0 { parti.append("\(meglio) in meglio") }
        if peggio > 0 { parti.append("\(peggio) in peggio") }
        if parti.isEmpty { return "\(quante), nessuna da giudicare." }
        return "\(quante): \(parti.joined(separator: ", "))."
    }

    /// Il riassunto delle variazioni di una memoria.
    static func riassunto(m: MemoriaRiesame) -> String { riassunto(m.variazioni) }

    static let titoloCronologia = "Cronologia dei riesami"

    /// «4 fotografie · al massimo 20 per cliente».
    static func notaCronologia(n: Int) -> String {
        "\(n == 1 ? "1 fotografia" : "\(n) fotografie") · al massimo \(MotoreMemoria.massimoPerCliente) per cliente"
    }

    static let salvaOggi = "Salva la fotografia di oggi"
    static let aiutoSalvaOggi = "Conserva le cifre chiave di oggi per il confronto al prossimo riesame. Una fotografia di meno di \(MotoreMemoria.giorniTraRiesami) giorni fa viene sostituita."
    static let preparaRiesame = "Prepara il riesame"

    /// «Mostra tutte (13)».
    static func mostraTutte(n: Int) -> String { "Mostra tutte (\(n))" }
    static let mostraMeno = "Mostra meno"

    /// «Rispetto al 12 marzo 2026: 3 variazioni» / «…: nessuna variazione».
    static func rispettoA(data d: Date, n: Int) -> String {
        let quante = n == 0 ? "nessuna variazione" : (n == 1 ? "1 variazione" : "\(n) variazioni")
        return "Rispetto al \(data(d)): \(quante)"
    }

    /// «Eliminare la fotografia del 12 marzo 2026?»
    static func eliminaTitolo(data d: Date) -> String { "Eliminare la fotografia del \(data(d))?" }
    static let eliminaMessaggio = "Le cifre di quel giorno non si possono recuperare, se non da un backup."
    static let eliminaQuesta = "Elimina questa fotografia"
    static let eliminaQuestaMenu = "Elimina questa fotografia…"

    /// L'avviso dopo una fotografia nuova.
    static func avvisoSalvata(data d: Date) -> String { "Fotografia del riesame salvata" }

    /// L'avviso dopo una fotografia che ne sostituisce una di meno di 30 giorni prima.
    static func avvisoSostituita(data d: Date) -> String {
        "Fotografia del riesame aggiornata (sostituisce quella del \(data(d)))"
    }

    /// Le etichette delle cifre nella scheda di una fotografia.
    struct EtichetteCifre {
        let propensione = "Propensione"
        let divarioPensione = "Divario pensione"
        let scopertoCasoMorte = "Scoperto caso morte"
        let patrimonio = "Patrimonio"
        let debiti = "Debiti"
        let semafori = "Semafori"
        let datiAnalisi = "Dati per l'analisi"
        let inRegola = "In regola"
    }
    static let cifre = EtichetteCifre()

    /// «2 rossi · 1 giallo · 4 verdi» (colori a zero omessi; tutti a zero «—»).
    static func semafori(f: FotografiaRiesame) -> String {
        let r = f.conta(.rosso)
        let g = f.conta(.giallo)
        let v = f.conta(.verde)
        var parti: [String] = []
        if r > 0 { parti.append(r == 1 ? "1 rosso" : "\(r) rossi") }
        if g > 0 { parti.append(g == 1 ? "1 giallo" : "\(g) gialli") }
        if v > 0 { parti.append(v == 1 ? "1 verde" : "\(v) verdi") }
        return parti.isEmpty ? vuoto : parti.joined(separator: " · ")
    }

    /// «tutto in regola», «1 voce da sistemare», «3 voci da sistemare»; nil → «—».
    static func conformitaBreve(n: Int?) -> String {
        guard let n else { return vuoto }
        switch n {
        case 0: return "tutto in regola"
        case 1: return "1 voce da sistemare"
        default: return "\(n) voci da sistemare"
        }
    }

    /// «77% · Quasi completi», «77%», oppure «—» se la completezza non c'è.
    static func completezzaBreve(f: FotografiaRiesame) -> String {
        guard let c = f.completezza else { return vuoto }
        return "\(c)%" + (f.livelloCompletezza.map { " · \($0)" } ?? "")
    }

    // MARK: - Riquadri brevi (Prospetti, Incontri, Panoramica)

    /// «COSA È CAMBIATO DAL 12 MARZO 2026».
    static func occhielloCambiato(data d: Date) -> String { "COSA È CAMBIATO DAL \(data(d).uppercased())" }

    /// «DAL RIESAME DEL 12 MARZO 2026».
    static func occhielloDalRiesame(data d: Date) -> String { "DAL RIESAME DEL \(data(d).uppercased())" }

    /// «…e altre 3 nel prospetto.» (1: «…e un'altra nel prospetto.»).
    static func altreNelProspetto(_ n: Int) -> String {
        n == 1 ? "…e un'altra nel prospetto." : "…e altre \(n) nel prospetto."
    }

    static let piedeRiepilogo = "La fotografia di oggi si salva quando il prospetto si archivia, si salva, si stampa o si presenta."

    /// La riga della Panoramica: «Dal riesame del 12 marzo 2026: 13 variazioni: … Propensione…; Divario…; …».
    static func rigaPanoramica(m: MemoriaRiesame) -> String? {
        guard let p = m.precedente, !m.variazioni.isEmpty else { return nil }
        let prime = m.variazioni.prefix(2).map(\.testo).joined(separator: "; ")
        let altre = m.variazioni.count > 2 ? "…" : ""
        return "Dal riesame del \(data(p.data)): \(riassunto(m: m)) \(prime)\(altre)"
    }

    static let collegamentoCronologia = "Cronologia ↗"

    // MARK: - Prospetto

    /// «Cosa è cambiato dal riesame del 12 marzo 2026 (7 mesi fa). 13 variazioni: 6 in meglio, 1 in peggio.»
    static func testoProspetto(m: MemoriaRiesame, cal: Calendar = .current) -> String? {
        guard let p = m.precedente else { return nil }
        let tempo = tempoFa(mesi: mesi(da: p.data, a: m.oggi, cal: cal))
        return "Cosa è cambiato dal riesame del \(data(p.data)) (\(tempo)). \(riassunto(m: m))"
    }

    /// Al massimo 2 domande dalle variazioni: il cambio di propensione e il primo ingresso in famiglia.
    static func domande(_ v: [VariazioneRiesame]) -> [String] {
        var d: [String] = []
        if let p = v.first(where: { $0.chiave == "profilo.propensione" }), p.prima != vuoto, p.oggi != vuoto {
            d.append("La propensione è passata da \(p.prima) a \(p.oggi): che cosa l'ha fatta cambiare, e vale per tutti gli investimenti?")
        }
        if let f = v.first(where: { $0.chiave.hasPrefix("famiglia.ingresso.") }) {
            // Il nome dalla frase «In famiglia: Sofia (figlia, a carico)»
            var nome = f.testo
            if nome.hasPrefix("In famiglia: ") { nome = String(nome.dropFirst("In famiglia: ".count)) }
            if let r = nome.range(of: " (", options: .backwards) { nome = String(nome[..<r.lowerBound]) }
            d.append("In famiglia c'è anche \(nome): cambia qualcosa nella protezione e negli obiettivi?")
        }
        return Array(d.prefix(2))
    }

    /// Il piede della scheda Riesami.
    static let fonti = "Tenere traccia nel tempo delle informazioni sul cliente aiuta a mantenerle aggiornate, come chiedono l'art. 54, par. 7, del Reg. delegato (UE) 2017/565 e gli Orientamenti ESMA sull'adeguatezza (ESMA35-43-3172, 2022) e, per i prodotti d'investimento assicurativi, l'art. 121-septies del Codice delle assicurazioni private. Le fotografie restano sul Mac, entrano nei backup e si cancellano con il cliente."

    /// Si aggiunge alla nota di metodo del prospetto del riesame.
    static var metodo: String {
        let m = MotoreMemoria.self
        let quota = percento(m.sogliaPatrimonioQuota)
        return "Memoria dei riesami: a ogni riesame Prisma conserva le cifre chiave del cliente (profilo, famiglia, semafori del check-up, divario pensione, protezione, obiettivi, patrimonio per canale, completezza dei dati, conformità) e le confronta con la fotografia di almeno \(m.giorniTraRiesami) giorni prima. Si segnalano: divario pensione da \(cifra(m.sogliaDivarioPensione)) \(euroMese), ammanco da \(cifra(m.sogliaAmmanco)) \(euroMese), scoperto caso morte da \(cifra(m.sogliaCasoMorte)) \(euroUnita), patrimonio e debiti da \(cifra(m.sogliaPatrimonio)) \(euroUnita) e \(dal(quota)), obiettivi e completezza da \(m.sogliaPuntiObiettivo) punti, ogni cambio di profilo, famiglia, semaforo e conformità. Il patrimonio che cresce o cala non si giudica: può dipendere da versamenti o riscatti."
    }
}
