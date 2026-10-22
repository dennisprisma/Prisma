import Foundation

/// Il colore di un indicatore del check-up.
enum Semaforo: String {
    case verde, giallo, rosso, grigio

    var nome: String {
        switch self {
        case .verde: return "In ordine"
        case .giallo: return "Da migliorare"
        case .rosso: return "Da affrontare"
        case .grigio: return "Dati da raccogliere"
        }
    }

    /// Ordine di urgenza: prima i rossi.
    var urgenza: Int {
        switch self {
        case .rosso: return 0
        case .giallo: return 1
        case .grigio: return 2
        case .verde: return 3
        }
    }
}

/// Un indicatore del check-up: un'area della vita finanziaria con il suo semaforo.
struct IndicatoreCheckUp: Identifiable {
    let id: String
    let titolo: String
    let semaforo: Semaforo
    /// La cifra che lo riassume ("3 mesi su 6", "€ 800 al mese").
    let valore: String
    let lettura: String
    let azione: String
    let area: AreaBisogno
}

/// Il check-up del primo incontro: chi è il cliente, la fotografia, i semafori, le priorità.
struct EsitoCheckUp {
    let cliente: Cliente?
    let riepilogo: RiepilogoPosizioni
    let indicatori: [IndicatoreCheckUp]
    let bisogni: [BisognoRilevato]
    let priorita: [AreaBisogno]
    let proposte: [Posizione]
    let obiettivi: [(Obiettivo, AvanzamentoObiettivo)]
    let note: [String]

    var rossi: [IndicatoreCheckUp] { indicatori.filter { $0.semaforo == .rosso } }
    var gialli: [IndicatoreCheckUp] { indicatori.filter { $0.semaforo == .giallo } }
    var verdi: [IndicatoreCheckUp] { indicatori.filter { $0.semaforo == .verde } }
    var daAffrontare: [IndicatoreCheckUp] { indicatori.filter { $0.semaforo == .rosso || $0.semaforo == .giallo }.sorted { $0.semaforo.urgenza < $1.semaforo.urgenza } }
}

/// Calcoli del check-up: riusa i motori di Prisma (Analisi 360, protezione, previdenza, bisogni)
/// e traduce ogni area in un semaforo con una frase e un'azione.
enum MotoreCheckUp {
    static func calcola(cliente c: Cliente?, posizioni: [Posizione], analisi: Analisi360, obiettivi: [Obiettivo]) -> EsitoCheckUp {
        let r = RiepilogoPosizioni(posizioni.filter { $0.stato != .chiusa })
        let inEssere = posizioni.filter { $0.stato == .inEssere }
        let liquidita = r.perArea[.liquidita] ?? 0
        var indicatori: [IndicatoreCheckUp] = []
        var note: [String] = []

        // 1. Riserva di emergenza
        let spese = analisi.protezione.fabbisognoMensile
        let mesiRiserva = analisi.protezione.mesiRiserva
        let mesiCoperti = spese > 0 ? liquidita / spese : 0
        let quotaRiserva = Double(mesiRiserva) > 0 ? mesiCoperti / Double(mesiRiserva) : 1
        indicatori.append(IndicatoreCheckUp(
            id: "riserva", titolo: "Riserva di emergenza",
            semaforo: quotaRiserva >= 1 ? .verde : (quotaRiserva >= 0.5 ? .giallo : .rosso),
            valore: "\(Int(mesiCoperti.rounded(.down))) mesi su \(mesiRiserva)",
            lettura: "La liquidità (\(CifreDoc.euro(liquidita))) copre \(Int(mesiCoperti.rounded(.down))) mesi di spese da \(CifreDoc.euro(spese)).",
            azione: quotaRiserva >= 1 ? (mesiCoperti > Double(mesiRiserva) * 2 ? "C'è liquidità in eccesso: si può destinare una parte." : "Mantenerla su un conto separato.")
                : "Costruire la riserva fino a \(CifreDoc.euro(spese * Double(mesiRiserva))).",
            area: .salute))

        // 2. Protezione caso morte
        let prot = MotoreAnalisi.protezione(analisi.protezione, posizioni: posizioni)
        let dipendono = (c?.famiglia.contains { $0.aCarico || [.coniuge, .convivente, .figlio, .figlia].contains($0.relazione) } ?? false) || r.debiti > 0
        if !dipendono {
            indicatori.append(IndicatoreCheckUp(id: "morte", titolo: "Protezione della famiglia", semaforo: .verde, valore: "non prioritaria",
                                                lettura: "Nessuno dipende oggi dal reddito del cliente e non ci sono debiti.",
                                                azione: "Rivederla se cambia la famiglia o arriva un mutuo.", area: .famiglia))
        } else {
            let quota = prot.fabbisogno > 0 ? prot.capitaleVita / prot.fabbisogno : 1
            indicatori.append(IndicatoreCheckUp(
                id: "morte", titolo: "Protezione della famiglia",
                semaforo: quota >= 0.9 ? .verde : (quota >= 0.5 ? .giallo : .rosso),
                valore: "\(CifreDoc.percento(min(quota, 1) * 100, decimali: 0)) coperto",
                lettura: "Fabbisogno caso morte \(CifreDoc.euro(prot.fabbisogno)), coperture \(CifreDoc.euro(prot.capitaleVita)).",
                azione: prot.divario > 1 ? "Valutare un capitale caso morte di circa \(CifreDoc.euro(prot.divario))." : "Verificare le scadenze delle coperture.",
                area: .famiglia))
        }

        // 3. Invalidità, infortuni, malattia
        let rischiReddito: Set<RischioCoperto> = [.invalidita, .infortuni]
        let copertoReddito = !prot.rischiCoperti.isDisjoint(with: rischiReddito)
        indicatori.append(IndicatoreCheckUp(
            id: "invalidita", titolo: "Reddito in caso di invalidità",
            semaforo: prot.ammanco < 1 ? .verde : (copertoReddito ? .giallo : .rosso),
            valore: prot.ammanco < 1 ? "nessun ammanco" : "\(CifreDoc.euro(prot.ammanco)) al mese",
            lettura: prot.ammanco < 1 ? "Le entrate sostitutive coprono il fabbisogno." : "Senza lavoro mancherebbero \(CifreDoc.euro(prot.ammanco)) al mese" + (copertoReddito ? "; c'è già una copertura da verificare." : " e non ci sono coperture."),
            azione: copertoReddito ? "Verificare capitali e franchigie delle coperture." : "Valutare una polizza infortuni e invalidità.",
            area: .lavoro))

        // 4. Previdenza
        let prev = MotorePrevidenza.calcola(posizioni, cliente: c, analisi: analisi.previdenza)
        let quotaPrev = prev.divario > 0 ? prev.renditaInEssere / prev.divario : 1
        indicatori.append(IndicatoreCheckUp(
            id: "previdenza", titolo: "Pensione",
            semaforo: prev.divario < 1 ? .verde : (quotaPrev >= 0.8 ? .verde : (quotaPrev >= 0.3 ? .giallo : .rosso)),
            valore: prev.divario < 1 ? "nessun divario" : "\(CifreDoc.percento(min(quotaPrev, 1) * 100, decimali: 0)) del divario",
            lettura: prev.divario < 1 ? "La pensione pubblica stimata copre il reddito desiderato."
                : "Divario stimato \(CifreDoc.euro(prev.divario)) al mese; i piani di oggi ne coprono \(CifreDoc.euro(prev.renditaInEssere)).",
            azione: prev.versamentoMancante.map { "Un piano di circa \(CifreDoc.euro($0)) al mese, con il vantaggio fiscale." } ?? "Rivedere il piano ogni anno.",
            area: .pensione))

        // 5. Investimenti e liquidità ferma
        let investito = (r.perArea[.investimento] ?? 0) + (r.perArea[.risparmio] ?? 0)
        let eccesso = max(0, liquidita - spese * Double(mesiRiserva))
        let fermo = eccesso > 10_000 && eccesso > investito
        indicatori.append(IndicatoreCheckUp(
            id: "investimenti", titolo: "Risparmi che lavorano",
            semaforo: fermo ? .giallo : (investito > 0 || eccesso < 1 ? .verde : .giallo),
            valore: fermo ? "\(CifreDoc.euro(eccesso)) fermi" : (investito < 1 ? "nessun investimento" : CifreDoc.euro(investito)),
            lettura: fermo ? "Oltre la riserva ci sono \(CifreDoc.euro(eccesso)) sul conto che perdono valore con l'inflazione."
                : (investito < 1 ? "La liquidità serve tutta alla riserva: non c'è ancora capitale da investire."
                                 : "Investimenti e risparmio per \(CifreDoc.euro(investito))."),
            azione: fermo ? "Destinare l'eccedenza secondo gli orizzonti degli obiettivi."
                : (investito < 1 ? "Avviare un piccolo piano di accumulo quando la riserva è completa." : "Verificare costi e rendimento con il resoconto."),
            area: .patrimonio))

        // 6. Debiti
        let rate = inEssere.filter { $0.area.passivo }.reduce(0) { $0 + $1.premioAnnuo } / 12
        if let reddito = c?.profilo.redditoLordoAnnuo, reddito > 0 {
            let nettoMensile = reddito * 0.72 / 13
            let peso = rate / nettoMensile
            indicatori.append(IndicatoreCheckUp(
                id: "debiti", titolo: "Peso dei debiti",
                semaforo: rate < 1 ? .verde : (peso <= 0.3 ? .verde : (peso <= 0.4 ? .giallo : .rosso)),
                valore: rate < 1 ? "nessuna rata" : "\(CifreDoc.percento(peso * 100, decimali: 0)) del reddito",
                lettura: rate < 1 ? "Nessun finanziamento in corso." : "Rate di \(CifreDoc.euro(rate)) al mese su un reddito netto stimato di \(CifreDoc.euro(nettoMensile)).",
                azione: peso > 0.3 ? "Evitare nuovi debiti; valutare la protezione del mutuo." : "Proteggere il debito residuo con una copertura caso morte.",
                area: .casa))
        } else {
            indicatori.append(IndicatoreCheckUp(id: "debiti", titolo: "Peso dei debiti", semaforo: rate < 1 ? .verde : .grigio,
                                                valore: rate < 1 ? "nessuna rata" : "\(CifreDoc.euro(rate)) al mese",
                                                lettura: rate < 1 ? "Nessun finanziamento in corso." : "Per valutarne il peso serve il reddito.",
                                                azione: "Indicare il reddito lordo annuo nel profilo del cliente.", area: .casa))
            note.append("Peso dei debiti: reddito netto stimato come il 72% del lordo diviso 13 mensilità, quando il reddito è indicato.")
        }

        // 7. Obiettivi
        let avanzamenti = obiettivi.map { ($0, AvanzamentoObiettivo($0, posizioni: posizioni)) }
        if avanzamenti.isEmpty {
            indicatori.append(IndicatoreCheckUp(id: "obiettivi", titolo: "Obiettivi", semaforo: .grigio, valore: "da definire",
                                                lettura: "Non ci sono ancora obiettivi con un importo e una data.",
                                                azione: "Fissare insieme 2 o 3 obiettivi con importo e scadenza.", area: .patrimonio))
        } else {
            let medio = avanzamenti.reduce(0) { $0 + $1.1.quota } / Double(avanzamenti.count)
            indicatori.append(IndicatoreCheckUp(
                id: "obiettivi", titolo: "Obiettivi", semaforo: medio >= 0.7 ? .verde : (medio >= 0.3 ? .giallo : .rosso),
                valore: "\(CifreDoc.percento(medio * 100, decimali: 0)) in media",
                lettura: "\(avanzamenti.count == 1 ? "1 obiettivo" : "\(avanzamenti.count) obiettivi"): " + avanzamenti.prefix(3).map { "\($0.0.titolo) al \(CifreDoc.percento($0.1.quota * 100, decimali: 0))" }.joined(separator: ", ") + ".",
                azione: "Un piano per ciascuno, con il versamento che serve.", area: .patrimonio))
        }

        let bisogni = c.map { MotoreBisogni.rileva(cliente: $0, posizioni: posizioni, analisi: analisi) } ?? []
        let priorita = c.map { MotoreBisogni.priorita(bisogni, profilo: $0.bisogni) } ?? []
        let proposte = posizioni.filter { $0.stato == .proposta && $0.esito != .rifiutata && $0.esito != .accettata }
        note.append("Semafori: verde se l'area è in ordine, giallo se va migliorata, rosso se va affrontata per prima, grigio se mancano dati. Soglie: riserva piena (verde) o almeno metà (giallo); protezione caso morte almeno 90% o 50%; pensione almeno 80% o 30% del divario coperto; rate fino al 30% o 40% del reddito netto.")
        note.append("Tutte le ipotesi (fabbisogno, riserva, pensione) vengono dall'Analisi 360 del cliente e si affinano negli incontri successivi.")

        return EsitoCheckUp(cliente: c, riepilogo: r, indicatori: indicatori, bisogni: bisogni, priorita: priorita,
                            proposte: proposte, obiettivi: avanzamenti, note: note)
    }
}
