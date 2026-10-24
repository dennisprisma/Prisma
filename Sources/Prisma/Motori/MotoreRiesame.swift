import Foundation

/// Il riesame annuale di un cliente: tutto ciò che serve per preparare l'incontro di revisione,
/// ricavato dai motori di Prisma. Com'è andata ogni posizione rispetto all'atteso, cosa scade, gli
/// obiettivi, le aree del check-up da rivedere, le proposte rimaste aperte, i dati da aggiornare;
/// da qui l'ordine del giorno dell'incontro e le domande da fare.
struct Riesame {
    enum Tema: Int, CaseIterable {
        case posizioni, scadenze, protezione, obiettivi, proposte, rischio, costi, famiglia, fisco, dati

        var nome: String {
            switch self {
            case .posizioni: return "Posizioni"
            case .scadenze: return "Scadenze"
            case .protezione: return "Check-up"
            case .obiettivi: return "Obiettivi"
            case .proposte: return "Proposte"
            case .rischio: return "Rischio"
            case .costi: return "Costi"
            case .famiglia: return "Famiglia"
            case .fisco: return "Fisco"
            case .dati: return "Dati"
            }
        }
    }

    enum Priorita: Int, Comparable {
        case alta, media, bassa

        var nome: String {
            switch self {
            case .alta: return "Alta"
            case .media: return "Media"
            case .bassa: return "Bassa"
            }
        }

        static func < (a: Priorita, b: Priorita) -> Bool { a.rawValue < b.rawValue }
    }

    /// Un punto dell'ordine del giorno.
    struct Punto: Identifiable {
        let tema: Tema
        let titolo: String
        let dettaglio: String
        let priorita: Priorita
        var canale: Canale? = nil

        var id: String { "\(tema.rawValue)·\(titolo)" }
    }

    let cliente: Cliente
    let oggi: Date
    /// L'ultimo incontro o appuntamento passato con il cliente.
    let ultimoContatto: Date?
    /// Il prossimo appuntamento già in agenda, se c'è.
    let prossimo: Appuntamento?
    let andamenti: [(posizione: Posizione, andamento: AndamentoPosizione)]
    /// Posizioni finanziarie in essere con un solo valore: l'andamento non si può ancora misurare.
    let senzaStorico: [Posizione]
    /// Posizioni il cui valore è fermo da più di un anno (o non ha una data).
    let valoriDaAggiornare: [Posizione]
    let scadenze: [Posizione]
    let proposte: [Posizione]
    let obiettivi: [(obiettivo: Obiettivo, avanzamento: AvanzamentoObiettivo)]
    let checkUp: EsitoCheckUp
    let attivitaAperte: [Attivita]
    /// Il calendario fiscale dell'anno.
    let fineAnno: FineAnno
    let punti: [Punto]
    let domande: [String]

    /// Mesi dall'ultimo contatto (nil se non ce ne sono).
    var mesiDallUltimo: Int? {
        ultimoContatto.flatMap { Calendar.current.dateComponents([.month], from: $0, to: oggi).month }
    }

    /// Il riesame è dovuto: un anno (meno un mese) dall'ultimo contatto, o nessun contatto registrato.
    /// Stessa soglia del calendario dei riesami (`MotoreRiesame.dovuti`): dovuto entro i prossimi mesi.
    var dovuto: Bool { (mesiDallUltimo ?? MotoreRiesame.mesiRiesame) >= MotoreRiesame.mesiRiesame - MotoreRiesame.mesiAvanti }

    var sottoAtteso: [(posizione: Posizione, andamento: AndamentoPosizione)] { andamenti.filter { $0.andamento.giudizio == .sotto } }
}

/// Un cliente il cui riesame annuale è dovuto (o lo sarà a breve): per pianificare le revisioni dell'anno.
struct RiesameDovuto: Identifiable {
    let cliente: Cliente
    let ultimoContatto: Date?
    /// Un anno dopo l'ultimo contatto; nil se non c'è mai stato un incontro.
    let dovutoDal: Date?

    var id: String { cliente.id }

    func scaduto(_ oggi: Date = Date()) -> Bool { dovutoDal.map { $0 <= oggi } ?? true }
}

enum MotoreRiesame {
    /// Ogni quanti mesi si rivede un cliente.
    static let mesiRiesame = 12
    /// Quanto avanti guarda il calendario dei riesami.
    static let mesiAvanti = 2

    /// I riesami da fare: clienti con posizioni in essere, niente in agenda e un anno dall'ultimo contatto
    /// entro i prossimi mesi. Prima chi non è mai stato incontrato, poi chi aspetta da più tempo.
    static func dovuti(clienti: [Cliente], posizioni: [Posizione], appuntamenti: [Appuntamento], incontri: [Incontro],
                       oggi: Date = Date(), mesiAvanti: Int = mesiAvanti) -> [RiesameDovuto] {
        let cal = Calendar.current
        let inizio = cal.startOfDay(for: oggi)
        let orizzonte = cal.date(byAdding: .month, value: mesiAvanti, to: inizio) ?? inizio
        let conPosizioni = Set(posizioni.filter { $0.stato == .inEssere }.map(\.clienteId))
        let appuntamentiPer = Dictionary(grouping: appuntamenti, by: \.clienteId)
        let incontriPer = Dictionary(grouping: incontri, by: \.clienteId)
        let elenco = clienti.compactMap { c -> RiesameDovuto? in
            guard conPosizioni.contains(c.id) else { return nil }
            let suoi = appuntamentiPer[c.id] ?? []
            guard !suoi.contains(where: { $0.stato == .pianificato && $0.inizio >= inizio }) else { return nil }
            let ultimo = (suoi.filter { $0.inizio < oggi }.map(\.inizio) + (incontriPer[c.id] ?? []).filter { $0.data < oggi }.map(\.data)).max()
            let dovuto = ultimo.flatMap { cal.date(byAdding: .month, value: mesiRiesame, to: $0) }
            guard dovuto.map({ $0 < orizzonte }) ?? true else { return nil }
            return RiesameDovuto(cliente: c, ultimoContatto: ultimo, dovutoDal: dovuto)
        }
        return elenco.sorted { ($0.dovutoDal ?? .distantPast, $0.cliente.nome) < ($1.dovutoDal ?? .distantPast, $1.cliente.nome) }
    }

    /// Una scadenza così vicina va affrontata subito.
    static let mesiScadenzaVicina = 6

    static func calcola(_ f: FonteEve) -> Riesame {
        let cal = Calendar.current
        let oggi = f.oggi
        let inizio = cal.startOfDay(for: oggi)
        let fineAnno = cal.date(byAdding: .month, value: mesiRiesame, to: inizio) ?? inizio
        let vicina = cal.date(byAdding: .month, value: mesiScadenzaVicina, to: inizio) ?? inizio
        let unAnnoFa = cal.date(byAdding: .month, value: -mesiRiesame, to: inizio) ?? inizio
        let euro: (Double) -> String = { Formati.euro($0) }
        let data: (Date) -> String = { Formati.dataEstesa.string(from: $0) }

        let passati = f.appuntamenti.filter { $0.inizio < oggi }.map(\.inizio) + f.incontri.filter { $0.data < oggi }.map(\.data)
        let prossimo = f.appuntamenti.filter { $0.stato == .pianificato && $0.inizio >= inizio }.min { $0.inizio < $1.inizio }

        let inEssere = f.posizioni.filter { $0.stato == .inEssere }
        let finanziarie = inEssere.filter(\.area.proiettabile)
        let andamenti = finanziarie.compactMap { p in MotoreAndamento.calcola(p).map { (posizione: p, andamento: $0) } }
        let senzaStorico = finanziarie.filter { p in !andamenti.contains { $0.posizione.id == p.id } }
        let valoriDaAggiornare = inEssere.filter { p in
            guard p.area != .protezione, !p.area.passivo, p.area != .immobili else { return false }
            return p.dataValore.map { $0 < unAnnoFa } ?? true
        }
        // I debiti che finiscono non liberano capitali da reinvestire
        let scadenze = inEssere.filter { p in !p.area.passivo && (p.scadenza.map { $0 >= inizio && $0 < fineAnno } ?? false) }
            .sorted { ($0.scadenza ?? oggi) < ($1.scadenza ?? oggi) }
        let scadute = inEssere.filter { !$0.area.passivo && $0.scaduta }
        let proposte = f.posizioni.filter { $0.stato == .proposta && $0.esito != .accettata && $0.esito != .rifiutata }
        let obiettivi = f.obiettivi.sorted { $0.scadenza < $1.scadenza }.map { (obiettivo: $0, avanzamento: AvanzamentoObiettivo($0, posizioni: f.posizioni)) }
        let checkUp = MotoreCheckUp.calcola(cliente: f.cliente, posizioni: f.posizioni, analisi: f.analisi, obiettivi: f.obiettivi)
        let attivita = f.attivita.filter { !$0.completata }.sorted { $0.scadenza < $1.scadenza }

        // L'ordine del giorno
        var punti: [Riesame.Punto] = []
        for (p, a) in andamenti {
            switch a.giudizio {
            case .sotto?:
                punti.append(.init(tema: .posizioni, titolo: "Rivedere «\(p.nome)»",
                                   dettaglio: "Rende \(TestiResoconto.rendimento(a)) contro \(a.attesoConfrontabile.map { CifreDoc.percento($0) } ?? "—") atteso (\(a.scarto.map(MotoreAndamento.punti) ?? "")): costi, composizione, un'alternativa?",
                                   priorita: .alta, canale: p.canale))
            case .sopra?:
                punti.append(.init(tema: .posizioni, titolo: "Confermare «\(p.nome)»",
                                   dettaglio: "Sopra le attese: \(TestiResoconto.rendimento(a)). Va bene anche il rischio che comporta?",
                                   priorita: .bassa, canale: p.canale))
            default:
                break
            }
        }
        let inLinea = andamenti.filter { $0.andamento.giudizio == .inLinea }
        if !inLinea.isEmpty {
            punti.append(.init(tema: .posizioni, titolo: inLinea.count == 1 ? "Una posizione in linea" : "\(inLinea.count) posizioni in linea",
                               dettaglio: inLinea.map(\.posizione.nome).joined(separator: ", ") + ": nessun intervento, solo da raccontare.",
                               priorita: .bassa))
        }
        for p in scadute {
            punti.append(.init(tema: .scadenze, titolo: "«\(p.nome)» è già scaduta",
                               dettaglio: "Scaduta il \(p.scadenza.map(data) ?? "—") ma ancora in essere: capitale da reinvestire o stato da aggiornare in Posizioni.",
                               priorita: .alta, canale: p.canale))
        }
        for p in scadenze {
            guard let s = p.scadenza else { continue }
            let presto = s < vicina
            if p.area == .protezione {
                punti.append(.init(tema: .scadenze, titolo: "Rinnovo di «\(p.nome)»",
                                   dettaglio: "La copertura scade il \(data(s)): rinnovarla, adeguare il capitale o cambiarla.",
                                   priorita: presto ? .alta : .media, canale: p.canale))
            } else {
                punti.append(.init(tema: .scadenze, titolo: "Scadenza di «\(p.nome)»",
                                   dettaglio: "Il \(data(s)) si liberano circa \(euro(p.valore)) prima delle imposte: dove reinvestirli, in vista di quali obiettivi.",
                                   priorita: presto ? .alta : .media, canale: p.canale))
            }
        }
        for i in checkUp.daAffrontare {
            punti.append(.init(tema: .protezione, titolo: i.titolo, dettaglio: "\(i.valore). \(i.azione)",
                               priorita: i.semaforo == .rosso ? .alta : .media))
        }
        for (o, av) in obiettivi {
            let necessario = av.versamentoNecessario ?? 0
            if av.quota < 1, necessario > av.versamentiAttivi + 1 {
                punti.append(.init(tema: .obiettivi, titolo: "Obiettivo «\(o.titolo)»",
                                   dettaglio: "Raggiunto il \(Formati.percentuale((av.quota * 100).rounded())): servono circa \(euro(necessario)) al mese, oggi ne versa \(euro(av.versamentiAttivi)).",
                                   priorita: .media))
            }
        }
        for p in proposte {
            punti.append(.init(tema: .proposte, titolo: "Proposta «\(p.nome)»",
                               dettaglio: "\((p.esito ?? .bozza).nome): è ancora di interesse? Va aggiornata alle nuove cifre?",
                               priorita: .media, canale: p.canale))
        }
        // Rischio, costi e famiglia: dalle analisi del dossier Posizioni
        let prova = MotoreResistenza.calcola(f.posizioni, profilo: f.cliente.profilo)
        if let g = prova.giudizio, g != .dentro, let m = prova.scenario(.mercati), let s = prova.sopportabile {
            punti.append(.init(tema: .rischio, titolo: g == .oltre ? "Rischio oltre il profilo" : "Rischio al limite del profilo",
                               dettaglio: "In un anno di crisi perderebbe circa \(euro(m.perdita)) (\(CifreDoc.percento(m.quota * 100))) contro il \(CifreDoc.condizione(s)) che sopporta: ridurre il rischio o rivedere il profilo.",
                               priorita: g == .oltre ? .alta : .media))
        }
        let costi = MotoreCosti.calcola(f.posizioni, prodotti: f.prodotti, cliente: f.cliente.id)
        for v in costi.conAlternativa.prefix(2) {
            guard let x = v.alternativa else { continue }
            punti.append(.init(tema: .costi, titolo: "Costi di «\(v.posizione.nome)»",
                               dettaglio: "\(CifreDoc.percento(v.annuo, decimali: 2)) l'anno; \(x.prodotto.nome) con lo stesso rischio lascerebbe circa \(euro(x.guadagno)) in più in \(x.anni) anni, uscita compresa.",
                               priorita: .media, canale: v.posizione.canale))
        }
        for v in costi.voci where v.livello == .alto && v.alternativa == nil {
            punti.append(.init(tema: .costi, titolo: "Costo alto di «\(v.posizione.nome)»",
                               dettaglio: "\(CifreDoc.percento(v.annuo, decimali: 2)) l'anno, \(euro(v.perso20)) in \(v.anni20) anni: cosa offre in cambio (garanzie, coperture)?",
                               priorita: .bassa, canale: v.posizione.canale))
        }
        let successione = MotoreSuccessione.calcola(cliente: f.cliente, posizioni: f.posizioni, oggi: oggi)
        let senzaBeneficiari = successione.daSistemare.filter { $0.posizione.beneficiari.trimmingCharacters(in: .whitespaces).isEmpty }
        if !senzaBeneficiari.isEmpty {
            punti.append(.init(tema: .famiglia, titolo: "Indicare i beneficiari",
                               dettaglio: senzaBeneficiari.map(\.posizione.nome).joined(separator: ", ") + ": senza, il capitale va agli eredi legittimi.",
                               priorita: .alta))
        }
        for v in successione.daSistemare where !senzaBeneficiari.contains(where: { $0.id == v.id }) {
            punti.append(.init(tema: .famiglia, titolo: "Beneficiari di «\(v.posizione.nome)»", dettaglio: v.avviso ?? "", priorita: .alta, canale: v.posizione.canale))
        }
        if let cv = successione.conviventeEscluso {
            punti.append(.init(tema: .famiglia, titolo: "Tutelare \(cv)",
                               dettaglio: "Convivente: senza testamento non eredita. Una polizza con lui come beneficiario o un testamento, con il notaio.",
                               priorita: .alta))
        }
        if !costi.senzaDati.isEmpty {
            punti.append(.init(tema: .dati, titolo: "Recuperare i KID",
                               dettaglio: "Costi non indicati: " + costi.senzaDati.map(\.nome).joined(separator: ", ") + ".",
                               priorita: .bassa))
        }
        // Fisco: le scadenze dei prossimi due mesi che chiedono un'azione
        let fisco = MotoreFineAnno.calcola(cliente: f.cliente, posizioni: f.posizioni, oggi: oggi)
        for s in fisco.scadenze where (s.tipo == .deduzione || s.tipo == .nonDedotti) && MotoreFineAnno.vicina(s, oggi: oggi) {
            punti.append(.init(tema: .fisco, titolo: s.titolo, dettaglio: s.dettaglio, priorita: .media))
        }
        if !valoriDaAggiornare.isEmpty {
            punti.append(.init(tema: .dati, titolo: "Chiedere gli estratti conto",
                               dettaglio: valoriDaAggiornare.map { p in "\(p.nome) (\(p.dataValore.map { "valore al \(Formati.dataBreve.string(from: $0))" } ?? "senza data"))" }.joined(separator: ", ") + ".",
                               priorita: .bassa))
        }
        if f.cliente.profilo.aggiornatoIl.map({ $0 < (cal.date(byAdding: .year, value: -2, to: inizio) ?? inizio) }) ?? true {
            punti.append(.init(tema: .dati, titolo: "Aggiornare il profilo dell'investitore",
                               dettaglio: f.cliente.profilo.aggiornatoIl.map { "Ultimo aggiornamento il \(data($0))." } ?? "Non è mai stato compilato in Prisma.",
                               priorita: .bassa))
        }
        if f.cliente.bisogni.aggiornatoIl.map({ $0 < unAnnoFa }) ?? true {
            punti.append(.init(tema: .dati, titolo: "Rivedere il profilo dei bisogni",
                               dettaglio: f.cliente.bisogni.aggiornatoIl.map { "Rilevato il \(data($0)): priorità ed eventi di vita sono ancora quelli?" } ?? "Non ancora rilevato: si compila nella scheda Bisogni del cliente.",
                               priorita: .bassa))
        }
        punti.sort { $0.priorita != $1.priorita ? $0.priorita < $1.priorita : $0.tema.rawValue < $1.tema.rawValue }

        // Le domande da fare
        var domande = [
            "Rispetto all'ultima volta è cambiato qualcosa nel lavoro, nel reddito o in famiglia?",
            "Ci sono spese importanti o progetti nei prossimi due o tre anni?",
        ]
        if finanziarie.contains(where: { $0.area == .investimento }) {
            domande.append("Come ha vissuto l'andamento dei mercati? Il rischio che corre è ancora quello giusto per lui?")
        }
        for p in scadenze {
            guard let s = p.scadenza else { continue }
            domande.append(p.area == .protezione
                ? "La copertura «\(p.nome)» scade il \(data(s)): la rinnoviamo così o va rivista?"
                : "Come vorrebbe usare il capitale di «\(p.nome)» che si libera il \(data(s))?")
        }
        for (o, _) in obiettivi {
            domande.append("L'obiettivo «\(o.titolo)» (\(euro(o.importo)) entro il \(Formati.dataBreve.string(from: o.scadenza))) è ancora attuale?")
        }
        for p in proposte {
            domande.append("La proposta «\(p.nome)» è ancora di suo interesse?")
        }
        if !successione.daSistemare.isEmpty || successione.conviventeEscluso != nil {
            domande.append("Chi vorrebbe che ricevesse il capitale delle sue polizze, se venisse a mancare?")
        }

        return Riesame(cliente: f.cliente, oggi: oggi, ultimoContatto: passati.max(), prossimo: prossimo,
                       andamenti: andamenti, senzaStorico: senzaStorico, valoriDaAggiornare: valoriDaAggiornare,
                       scadenze: scadenze, proposte: proposte, obiettivi: obiettivi, checkUp: checkUp,
                       attivitaAperte: attivita, fineAnno: fisco, punti: punti, domande: domande)
    }

    /// L'ordine del giorno da mettere nelle note dell'appuntamento.
    static func agenda(_ r: Riesame, massimo: Int = 8) -> String {
        var righe = r.punti.prefix(massimo).enumerated().map { i, p in "\(i + 1). \(p.titolo)" }
        if r.punti.count > massimo { righe.append("…e altri \(r.punti.count - massimo) punti nel prospetto del riesame.") }
        return "Ordine del giorno:\n" + righe.joined(separator: "\n")
    }
}
