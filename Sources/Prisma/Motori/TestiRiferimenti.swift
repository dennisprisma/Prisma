import Foundation

/// I testi del rendimento contro un riferimento (giro 6, specifica 11, §6.1): pannello del dettaglio della posizione
/// e scheda Impostazioni › Riferimenti. Le cifre con `CifreDoc`, gli scarti con `MotoreAndamento.punti`.
enum TestiRiferimenti {
    // MARK: Le serie

    static let nomeInflazione = "Inflazione (FOI)"
    static let fraseInflazione = "l'inflazione"
    static let nomeTFR = "Rivalutazione del TFR"
    static let fraseTFR = "il TFR"
    static let nomeGestioniSeparate = "Gestioni separate"
    static let fraseGestioniSeparate = "le gestioni separate"
    /// Un indice senza nome (il consulente l'ha cancellato) e un indice senza fonte.
    static let indiceSenzaNome = "Indice senza nome"
    static let fonteIndice = "Indicata dal consulente"
    /// Il nome di un indice appena aggiunto.
    static let nuovoIndice = "Nuovo indice"

    /// «del TFR», «dell'inflazione», «delle gestioni separate», «di Azionario globale».
    static func del(_ s: SerieRiferimento) -> String {
        switch s.tipo {
        case .inflazione: return "dell'inflazione"
        case .tfr: return "del TFR"
        case .gestioniSeparate: return "delle gestioni separate"
        case .indice: return "di \(s.nome)"
        }
    }

    /// Nelle note brevi: «inflazione», «TFR», «gestioni separate», il nome dell'indice.
    static func nomeBreve(_ s: SerieRiferimento) -> String {
        switch s.tipo {
        case .inflazione: return "inflazione"
        case .tfr: return "TFR"
        case .gestioniSeparate: return "gestioni separate"
        case .indice: return s.nome
        }
    }

    // MARK: Pannello del dettaglio

    static let titoloPannello = "Contro un riferimento"

    /// "Lo stesso periodo, dal 3 novembre 2025 al 24 ottobre 2026, misurato con un metro esterno."
    static func notaPannello(dal: Date, al: Date) -> String {
        "Lo stesso periodo, dal \(CifreDoc.data(dal)) al \(CifreDoc.data(al)), misurato con un metro esterno."
    }

    static let etichettaMetro = "Metro"

    /// "Rivalutazione del TFR · del tipo": la prima voce della tendina del metro.
    static func opzionePredefinita(_ s: SerieRiferimento) -> String { "\(s.nome) · del tipo" }

    /// "Sopra il TFR", "In linea con l'inflazione", "Sotto le gestioni separate", "Sopra MSCI World".
    static func pillola(_ g: ConfrontoRiferimento.Giudizio, _ s: SerieRiferimento) -> String {
        switch g {
        case .sopra: return "Sopra \(s.nomeFrase)"
        case .inLinea: return "In linea con \(s.nomeFrase)"
        case .sotto: return "Sotto \(s.nomeFrase)"
        }
    }

    static func kpiPosizione(annuo: Bool) -> (titolo: String, nota: String) {
        ("La posizione", annuo ? "all'anno, tolti i versamenti" : "nel periodo, tolti i versamenti")
    }

    /// La nota della tessera del riferimento: "stessi giorni" oppure "stessi giorni · 2026 stimato".
    static func kpiRiferimento(_ s: SerieRiferimento, stimati: [Int]) -> String {
        guard !stimati.isEmpty else { return "stessi giorni" }
        let anni = elenco(stimati.map(String.init))
        return "stessi giorni · \(anni) \(stimati.count == 1 ? "stimato" : "stimati")"
    }

    static let kpiDifferenza = "Differenza"

    /// Con l'inflazione: "rendimento reale +3,95% all'anno"; con gli altri: "all'anno" / "nel periodo".
    static func notaDifferenza(_ c: ConfrontoRiferimento) -> String {
        let orizzonte = c.annuo ? "all'anno" : "nel periodo"
        if let r = c.reale { return "rendimento reale \(CifreDoc.variazione(r, decimali: 2)) \(orizzonte)" }
        return orizzonte
    }

    /// "I versamenti al ritmo del TFR".
    static func kpiVersamenti(_ s: SerieRiferimento) -> String { "I versamenti al ritmo \(del(s))" }

    /// "oggi valgono 38.000 €: + 1.100 €".
    static func notaVersamenti(_ v: VersamentiAlRiferimento) -> String {
        "oggi valgono \(Formati.euro(v.valoreEffettivo)): \(CifreDoc.euroSegno(v.differenza))"
    }

    /// L'aiuto della tessera dei versamenti: i due rendimenti dei versamenti alle loro date.
    static func aiutoVersamenti(_ v: VersamentiAlRiferimento, _ s: SerieRiferimento) -> String {
        let effettivo = v.tassoEffettivo.map { CifreDoc.variazione($0, decimali: 2) } ?? "—"
        let riferimento = v.tassoRiferimento.map { CifreDoc.variazione($0, decimali: 2) } ?? "—"
        return "Rendimento dei versamenti dal \(CifreDoc.data(v.dal)): \(effettivo) l'anno, contro \(riferimento) l'anno al ritmo \(del(s))."
    }

    /// "Al ritmo del TFR", "Al ritmo dell'inflazione".
    static func legendaLinea(_ s: SerieRiferimento) -> String { "Al ritmo \(del(s))" }
    static let legendaValore = "Valore rilevato"
    static let legendaVersato = "Versato"

    /// "di Prisma", "inserito da te", "stimato".
    static func origine(_ o: OrigineValore) -> String {
        switch o {
        case .prisma: return "di Prisma"
        case .consulente: return "inserito da te"
        case .stimato: return "stimato"
        }
    }

    /// Il gettone di un anno: "2025 · +2,5% · inserito da te" (senza valore: "2019 · manca").
    static func gettoneAnno(_ a: AnnoRiferimento) -> String {
        guard let v = a.valore, let o = a.origine else { return "\(a.anno) · manca" }
        return "\(a.anno) · \(CifreDoc.variazione(v)) · \(origine(o))"
    }

    /// Una frase sul confronto, sotto il pannello.
    static func sintesi(_ c: ConfrontoRiferimento, nome: String) -> String {
        guard let r = c.riferimento, let s = c.scarto else { return "" }
        let orizzonte = c.annuo ? "all'anno" : "nel periodo"
        var testo = "\(nome) dal \(CifreDoc.data(c.dal)) al \(CifreDoc.data(c.al)) ha reso \(CifreDoc.variazione(c.effettivo)) \(orizzonte), contro \(CifreDoc.variazione(r)) \(del(c.serie))"
        switch c.giudizio {
        case .sopra?: testo += ": \(puntiSenzaSegno(s)) in più."
        case .sotto?: testo += ": \(puntiSenzaSegno(s)) in meno."
        case .inLinea?, nil: testo += ": \(MotoreAndamento.punti(s)) di differenza."
        }
        if let reale = c.reale { testo += " Tolta l'inflazione, \(CifreDoc.variazione(reale)) \(orizzonte)." }
        if c.giudizio == nil { testo += " " + senzaGiudizio }
        return testo
    }

    static let senzaGiudizio = "Meno di tre mesi di storico: il confronto si mostra ma non si giudica."

    /// "4,0 punti": lo scarto senza segno, per le frasi con «in più» e «in meno».
    private static func puntiSenzaSegno(_ s: Double) -> String {
        let p = MotoreAndamento.punti(abs(s))
        return p.hasPrefix("+") ? String(p.dropFirst()) : p
    }

    /// "Le gestioni separate non hanno ancora valori: per ora il confronto è con l'inflazione. Inseriscili in
    /// Impostazioni › Riferimenti."
    static func ripiego(_ voluto: SerieRiferimento) -> String {
        let soggetto = voluto.tipo == .gestioniSeparate ? "Le gestioni separate non hanno" : "«\(voluto.nome)» non ha"
        return "\(soggetto) ancora valori: per ora il confronto è con l'inflazione. Inseriscili in Impostazioni › Riferimenti."
    }

    /// "Il 2026 non è ancora pubblicato: Prisma usa il valore del 2025. A inizio anno aggiorna i valori."
    /// (plurale: "Il 2025 e il 2026 non sono ancora pubblicati: …").
    static func stimati(_ anni: [Int], ultimo: Int) -> String {
        let ordinati = anni.sorted()
        guard !ordinati.isEmpty else { return "" }
        let soggetto = elenco(ordinati.map { "il \($0)" })
        let maiuscolo = soggetto.prefix(1).uppercased() + soggetto.dropFirst()
        let verbo = ordinati.count == 1 ? "non è ancora pubblicato" : "non sono ancora pubblicati"
        return "\(maiuscolo) \(verbo): Prisma usa il valore del \(ultimo). A inizio anno aggiorna i valori."
    }

    /// "Mancano i valori del 2018 e del 2019 per «Inflazione (FOI)»: senza, il confronto non si può fare."
    static func mancanti(_ anni: [Int], _ s: SerieRiferimento) -> String {
        let ordinati = Array(Set(anni)).sorted()
        guard let primo = ordinati.first, let ultimo = ordinati.last else { return "" }
        let quali: String
        if ordinati.count == 1 {
            quali = "Manca il valore del \(primo)"
        } else if ordinati.count >= 3 && ultimo - primo == ordinati.count - 1 {
            quali = "Mancano i valori dal \(primo) al \(ultimo)"
        } else {
            quali = "Mancano i valori " + elenco(ordinati.map { "del \($0)" })
        }
        return "\(quali) per «\(s.nome)»: senza, il confronto non si può fare."
    }

    /// ultimo != nil: "I valori di «Inflazione (FOI)» arrivano al 2023: aggiungi gli anni dopo in Impostazioni › Riferimenti."
    /// ultimo == nil: "«Gestioni separate» non ha ancora valori: inseriscili in Impostazioni › Riferimenti."
    static func daAggiornare(_ s: SerieRiferimento, ultimo: Int?) -> String {
        guard let ultimo else { return "«\(s.nome)» non ha ancora valori: inseriscili in Impostazioni › Riferimenti." }
        return "I valori di «\(s.nome)» arrivano al \(ultimo): aggiungi gli anni dopo in Impostazioni › Riferimenti."
    }

    /// "Per confrontare anche i versamenti servono i valori dal 2016."
    static func versamentiMancanti(dal anno: Int) -> String {
        "Per confrontare anche i versamenti, alle loro date, servono i valori dal \(anno)."
    }

    static let apriImpostazioni = "Apri i riferimenti ↗"
    static let apriTFR = "TFR in azienda o nel fondo? ↗"
    static let mostraMetodo = "Come si confronta?"
    static let nascondiMetodo = "Nascondi il metodo"
    static let titoloMetodo = "Il confronto, senza scorciatoie"

    static let metodo: [String] = [
        "Il rendimento della posizione è quello dell'andamento: i periodi tra due valori rilevati pesano allo stesso modo, tolti i versamenti. I valori rilevati sono già al netto dei costi; per fondi pensione e PIP anche dell'imposta sui rendimenti. Per fondi, ETF e polizze l'imposta sul guadagno si paga all'uscita e qui non è tolta.",
        "Il riferimento si compone anno per anno sui giorni del periodo: (1 + valore dell'anno)^(giorni nel periodo / giorni dell'anno). L'anno non ancora pubblicato prende il valore dell'ultimo anno noto, per al massimo due anni.",
        "Inflazione: indice FOI senza tabacchi dell'ISTAT, dicembre su dicembre. Rivalutazione del TFR: 1,5% più il 75% dell'inflazione (art. 2120 c.c.), meno l'imposta sostitutiva del 17%: è il confronto che la COVIP pubblica ogni anno con i fondi pensione.",
        "I versamenti al ritmo del riferimento: ogni versamento, alla sua data, cresce come il riferimento fino alla data del valore (metodo \"public market equivalent\"); gli incassi tolgono il loro valore cresciuto.",
        "In linea: entro mezzo punto all'anno; sotto i tre mesi di storico nessun giudizio.",
    ]

    // MARK: Impostazioni › Riferimenti

    static let introduzione = "I metri con cui Prisma confronta il rendimento delle posizioni: l'inflazione, la rivalutazione del TFR e il rendimento medio delle gestioni separate, più gli indici che aggiungi tu. Sono valori annui in percentuale. Prisma ne porta alcuni con la fonte; gli altri li inserisci tu una volta l'anno, quando escono i dati dell'anno prima (l'ISTAT pubblica l'inflazione di dicembre a metà gennaio). Restano su questo Mac e nel backup."
    static let gruppoMetro = "Il metro per tipo di posizione"
    static let gruppoValori = "I valori anno per anno"
    static let gruppoIndici = "Indici"
    static let gruppoFonti = "Fonti"
    static let quelloDiPrisma = "Quello di Prisma"
    static func diPrisma(_ s: SerieRiferimento) -> String { "Di Prisma: \(s.nome)" }
    static let testaAnno = "Anno"
    /// La testata della colonna del TFR nella griglia (calcolata, sola lettura).
    static let testaTFR = "TFR netto"
    static let segnaposto = "—"
    static func tornaAPrisma(_ v: Double) -> String { "Torna al valore di Prisma (\(CifreDoc.percento(v)))" }

    /// "Ultimo anno: inflazione 2025 · gestioni separate — · Azionario globale 2025".
    static func ultimiAnni(_ voci: [(nome: String, anno: Int?)]) -> String {
        "Ultimo anno: " + voci.map { "\($0.nome) \($0.anno.map(String.init) ?? segnaposto)" }.joined(separator: " · ")
    }

    /// "Mancano i valori del 2024 e del 2025: aggiornali quando l'ISTAT li pubblica."
    static func inflazioneDaAggiornare(_ anni: [Int]) -> String {
        guard let primo = anni.first else { return "" }
        let quali = anni.count == 1 ? "Manca il valore del \(primo)" : "Mancano i valori " + elenco(anni.map { "del \($0)" })
        return "\(quali) dell'inflazione: \(anni.count == 1 ? "aggiornalo" : "aggiornali") quando l'ISTAT \(anni.count == 1 ? "lo pubblica" : "li pubblica")."
    }

    static let fonteNonIndicata = "Fonte non indicata"
    static let modifica = "Modifica"
    static let aggiungiIndice = "Aggiungi un indice"
    static let aggiungi = "Aggiungi"
    static let massimoIndici = "Al massimo tre indici"
    static let campoNome = "Nome"
    static let campoFonte = "Fonte"
    static let eliminaIndice = "Elimina l'indice"
    static let fatto = "Fatto"
    static func confermaElimina(_ nome: String) -> String { "Eliminare «\(nome)»?" }
    static let spiegaElimina = "I suoi valori e le scelte che lo usano tornano a quelli di Prisma."
    static let annulla = "Annulla"
    static let elimina = "Elimina"
    static let valoriRivisti = "Valori rivisti"
    static func ultimaRevisione(_ d: Date?) -> String { "Ultima revisione: \(d.map(CifreDoc.data) ?? "mai")" }
    static let segnaRivisti = "Segna come rivisti oggi"

    // MARK: Aiuti

    /// "2025", "2025 e 2026", "2024, 2025 e 2026".
    static func elenco(_ parti: [String]) -> String {
        guard parti.count > 1, let ultima = parti.last else { return parti.first ?? "" }
        return parti.dropLast().joined(separator: ", ") + " e " + ultima
    }
}
