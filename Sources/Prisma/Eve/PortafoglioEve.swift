import Foundation

/// Eve sul portafoglio: domande su tutti i clienti insieme (chi richiamare, cosa scade, la
/// settimana, gli emittenti, le proposte). Le risposte usano gli stessi calcoli della vista
/// Portafoglio di Posizioni; Qwen le racconta senza cambiare i numeri.
enum SpuntoPortafoglio: String, CaseIterable, Identifiable {
    case quadro, ricontattare, riesami, fineAnno, settimana, scadenze, concentrazione, proposte

    var id: String { rawValue }

    var domanda: String {
        switch self {
        case .quadro: return "Fammi il quadro del portafoglio"
        case .ricontattare: return "Chi devo ricontattare?"
        case .riesami: return "Quali riesami devo fare?"
        case .fineAnno: return "Chi può ancora dedurre entro fine anno?"
        case .settimana: return "Cosa ho questa settimana?"
        case .scadenze: return "Cosa scade nei prossimi mesi?"
        case .concentrazione: return "Quanto dipendo da un emittente?"
        case .proposte: return "Come vanno le proposte?"
        }
    }

    var simbolo: String {
        switch self {
        case .quadro: return "≡"
        case .ricontattare: return "☎"
        case .riesami: return "↻"
        case .fineAnno: return "%"
        case .settimana: return "◷"
        case .scadenze: return "!"
        case .concentrazione: return "◔"
        case .proposte: return "✚"
        }
    }

    /// L'argomento di una domanda scritta a mano (il quadro se non si riconosce).
    static func da(_ testo: String) -> SpuntoPortafoglio {
        let t = testo.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
        if let s = allCases.first(where: { $0.domanda.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
            == t.trimmingCharacters(in: .whitespacesAndNewlines) }) { return s }
        let regole: [(SpuntoPortafoglio, [String])] = [
            (.riesami, ["riesam", "revision", "rivedere i clienti"]),
            (.fineAnno, ["dedur", "deducib", "fine anno", "fine dell'anno", "31 dicembre", "irpef"]),
            (.ricontattare, ["ricontatt", "richiam", "chiamar", "sentire", "non vedo", "trascurat"]),
            (.settimana, ["settimana", "oggi", "domani", "agenda", "appuntament"]),
            (.scadenze, ["scaden", "scade", "scadono", "reinvest"] + EvePortafoglio.mesi),
            (.concentrazione, ["emittent", "concentra", "compagni", "dipend"]),
            (.proposte, ["propost", "accett", "rifiut", "conversion"]),
        ]
        return regole.first { r in r.1.contains { t.contains($0) } }?.0 ?? .quadro
    }
}

enum EvePortafoglio {
    /// La conversazione del portafoglio, accanto a quelle dei clienti.
    static let chiave = "·portafoglio"
    static let mesi = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto",
                       "settembre", "ottobre", "novembre", "dicembre"]

    private static func euro(_ v: Double) -> String { Formati.euro(v) }
    private static func quota(_ q: Double) -> String { Formati.percentuale((q * 100).rounded()) }

    static func portafoglio(_ dati: DatiPrisma, oggi: Date) -> Portafoglio {
        MotorePortafoglio.calcola(dati.posizioni, clienti: dati.clienti, appuntamenti: dati.appuntamenti, incontri: dati.incontri, oggi: oggi)
    }

    /// Il mese nominato nella domanda (1…12), se c'è.
    static func mese(_ domanda: String) -> Int? {
        let t = domanda.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
        return mesi.firstIndex { t.contains($0) }.map { $0 + 1 }
    }

    static func risposta(_ spunto: SpuntoPortafoglio, domanda: String, dati: DatiPrisma, oggi: Date = Date()) -> RispostaEve {
        let p = portafoglio(dati, oggi: oggi)
        func nome(_ id: String) -> String { dati.clienti.first { $0.id == id }?.nome ?? "" }
        let r = p.riepilogo
        switch spunto {
        case .quadro:
            var righe = ["Segui \(p.clienti.count) clienti per \(euro(r.attivita)) di attività in essere: Alleanza \(quota(r.quota(.alleanza))), indipendente \(quota(r.quota(.indipendente)))."]
            righe.append("Premi e versamenti: \(euro(r.premiAnnui)) all'anno; capitale assicurato \(euro(r.capitaleAssicurato)).")
            if let primo = p.clienti.first {
                righe.append("Il cliente più seguito è \(primo.cliente.nome), con il \(quota(primo.quota)) del portafoglio.")
            }
            let daReinvestire = p.scadenze.reduce(0) { $0 + $1.capitale }
            let quante = p.scadenze.reduce(0) { $0 + $1.posizioni.count }
            if quante > 0 {
                righe.append("Nei prossimi \(Portafoglio.mesiScadenze) mesi scadono \(quante) posizioni, \(euro(daReinvestire)) da reinvestire.")
            }
            righe.append("Proposte aperte: \(r.proposteAperte) per \(euro(r.valoreProposte))" + (p.tassoAccettazione.map { ", accettate il \(quota($0)) di quelle decise." } ?? "."))
            if !p.daRicontattare.isEmpty {
                righe.append("Da ricontattare: \(p.daRicontattare.count) \(p.daRicontattare.count == 1 ? "cliente" : "clienti") (chiedimi «Chi devo ricontattare?»).")
            }
            return RispostaEve(titolo: "Il tuo portafoglio", testo: righe.joined(separator: "\n"))

        case .ricontattare:
            guard !p.daRicontattare.isEmpty else {
                return RispostaEve(titolo: "Nessuno da ricontattare",
                                   testo: "Tutti i clienti hanno un incontro negli ultimi \(Portafoglio.mesiSenzaContatto) mesi o un appuntamento in agenda.")
            }
            let righe = p.daRicontattare.map { d -> String in
                let quando = d.ultimoContatto.map { "ultimo contatto il \(Formati.dataEstesa.string(from: $0))" } ?? "mai incontrato in Prisma"
                return "• \(d.cliente.nome): \(d.motivo.map { $0 + "; " } ?? "")\(quando)"
            }
            return RispostaEve(titolo: "Da ricontattare: \(p.daRicontattare.count)",
                               testo: righe.joined(separator: "\n") + "\n\nPrima chi ha un motivo per chiamare, poi chi manca da più tempo. Un appuntamento in agenda li toglie dall'elenco.")

        case .riesami:
            let dovuti = MotoreRiesame.dovuti(clienti: dati.clienti, posizioni: dati.posizioni, appuntamenti: dati.appuntamenti,
                                              incontri: dati.incontri, oggi: oggi)
            guard !dovuti.isEmpty else {
                return RispostaEve(titolo: "Nessun riesame da fare",
                                   testo: "Nei prossimi \(MotoreRiesame.mesiAvanti) mesi non scade nessun riesame: tutti i clienti con posizioni sono stati visti nell'ultimo anno o hanno un incontro in agenda.")
            }
            let righe = dovuti.prefix(10).map { d -> String in
                let quando = d.dovutoDal.map { d.scaduto(oggi) ? "scaduto dal \(Formati.dataEstesa.string(from: $0))" : "dovuto dal \(Formati.dataEstesa.string(from: $0))" }
                    ?? "mai incontrato in Prisma"
                return "• \(d.cliente.nome): \(quando)"
            }
            let scaduti = dovuti.filter { $0.scaduto(oggi) }.count
            return RispostaEve(titolo: "Riesami annuali: \(dovuti.count)",
                               testo: (scaduti > 0 ? "\(scaduti) già scaduti.\n" : "") + righe.joined(separator: "\n")
                                   + "\n\nIn Posizioni → Portafoglio ognuno ha «Prepara» (il prospetto con l'ordine del giorno) e «Fissa» (l'incontro di un'ora).")

        case .fineAnno:
            let fine = MotoreFineAnno.conSpazio(clienti: dati.clienti, posizioni: dati.posizioni, oggi: oggi)
            guard !fine.isEmpty else {
                return RispostaEve(titolo: "Nessuno spazio deducibile da usare",
                                   testo: "I clienti con un piano di previdenza versano già fino al limite di \(euro(RegoleFiscali.limiteDeducibilita)) l'anno, o non hanno piani in essere.")
            }
            let righe = fine.prefix(10).map { f in
                "• \(f.cliente.nome): versa \(euro(f.contributi)), può dedurre ancora \(euro(f.spazio))"
                    + (f.reddito == nil ? " (reddito non indicato)" : ", circa \(euro(f.risparmioPossibile)) di IRPEF in meno")
            }
            return RispostaEve(titolo: "Spazio deducibile entro il 31 dicembre",
                               testo: righe.joined(separator: "\n") + "\n\nVale per i versamenti alla previdenza complementare fatti entro fine anno, fino a \(euro(RegoleFiscali.limiteDeducibilita)) compresi i contributi del datore di lavoro (che Prisma non conosce: chiedili al cliente).")

        case .settimana:
            let cal = Calendar.current
            let inizio = cal.startOfDay(for: oggi)
            let fine = cal.date(byAdding: .day, value: 7, to: inizio) ?? inizio
            let incontri = dati.appuntamenti.filter { $0.stato == .pianificato && $0.inizio >= inizio && $0.inizio < fine }.sorted { $0.inizio < $1.inizio }
            let attivita = dati.attivita.filter { !$0.completata && $0.scadenza < fine }.sorted { $0.scadenza < $1.scadenza }
            let scadono = dati.posizioni.filter { $0.stato == .inEssere && ($0.scadenza.map { $0 >= inizio && $0 < fine } ?? false) }
            var parti: [String] = []
            parti.append(incontri.isEmpty ? "Nessun appuntamento nei prossimi 7 giorni."
                         : "Appuntamenti:\n" + incontri.map { "• \(Formati.barraData.string(from: $0.inizio)), \(Formati.ora.string(from: $0.inizio)) · \(nome($0.clienteId)): \($0.titolo)" }.joined(separator: "\n"))
            if !attivita.isEmpty {
                let scadute = attivita.filter { $0.scadenza < inizio }.count
                parti.append("Attività entro la settimana: \(attivita.count)\(scadute > 0 ? ", di cui \(scadute) già scadute" : "").\n"
                             + attivita.prefix(5).map { "• \($0.titolo) (\(nome($0.clienteId)), \(Formati.giornoMese.string(from: $0.scadenza)))" }.joined(separator: "\n"))
            }
            if !scadono.isEmpty {
                parti.append("In scadenza: " + scadono.map { "\($0.nome) di \(nome($0.clienteId)) (\($0.canale.nomeBreve))" }.joined(separator: "; ") + ".")
            }
            return RispostaEve(titolo: "La tua settimana", testo: parti.joined(separator: "\n\n"))

        case .scadenze:
            var mesiScelti = p.scadenze
            var titolo = "Scadenze dei prossimi \(Portafoglio.mesiScadenze) mesi"
            if let m = mese(domanda) {
                mesiScelti = p.scadenze.filter { Calendar.current.component(.month, from: $0.inizio) == m }
                titolo = "Scadenze di \(mesi[m - 1])"
            }
            guard !mesiScelti.isEmpty else {
                return RispostaEve(titolo: titolo, testo: "Nessuna posizione in essere scade in questo periodo.")
            }
            let righe = mesiScelti.map { m -> String in
                let capitale = m.capitale > 0 ? " · \(euro(m.capitale)) da reinvestire" : ""
                return "\(Formati.meseAnno.string(from: m.inizio).capitalized)\(capitale)\n"
                    + m.posizioni.map { "• \(Formati.giornoMese.string(from: $0.scadenza ?? m.inizio)): \($0.nome) di \(nome($0.clienteId)) (\($0.canale.nomeBreve))\($0.area == .protezione ? ", copertura da rinnovare" : ", \(euro($0.valore))")" }.joined(separator: "\n")
            }
            return RispostaEve(titolo: titolo, testo: righe.joined(separator: "\n\n") + "\n\nI valori sono quelli di oggi, prima delle imposte: il netto di ciascuna lo trovi nel prospetto «Capitale in scadenza e liquidità» del cliente.")

        case .concentrazione:
            guard let primo = p.emittenti.first else {
                return RispostaEve(titolo: "Concentrazione per emittente", testo: "Non ci sono attività finanziarie in essere.")
            }
            var testo = "Su \(euro(p.attivitaFinanziarie)) di attività finanziarie (immobili e debiti esclusi):\n"
                + p.emittenti.map { "• \($0.nome): \(euro($0.valore)), \(quota($0.quota))\($0.canale.map { " (\($0.nomeBreve))" } ?? "")" }.joined(separator: "\n")
            if primo.quota > 0.5, primo.nome != Portafoglio.senzaEmittente {
                testo += "\n\n\(primo.nome) pesa più della metà: vale la pena tenerlo presente nelle prossime proposte."
            }
            if p.emittenti.contains(where: { $0.nome == Portafoglio.senzaEmittente }) {
                testo += "\n\nAlcune posizioni non hanno l'emittente: completarlo in Posizioni rende il quadro più preciso."
            }
            return RispostaEve(titolo: "Concentrazione per emittente", testo: testo)

        case .proposte:
            let aperte = dati.posizioni.filter { $0.stato == .proposta && $0.esito != .accettata && $0.esito != .rifiutata }
            var testo = EsitoProposta.allCases.map { "\($0.nome): \(p.esiti[$0] ?? 0)" }.joined(separator: " · ")
            testo += "\n" + (p.tassoAccettazione.map { "Accettate il \(quota($0)) delle proposte decise." } ?? "Nessuna proposta ancora decisa.")
            if !aperte.isEmpty {
                testo += "\n\nAperte:\n" + aperte.prefix(8).map { a in
                    "• \(a.nome) per \(nome(a.clienteId)) (\(a.canale.nomeBreve), \((a.esito ?? .bozza).nome.lowercased()))\(a.versamentoIniziale > 0 ? ", \(euro(a.versamentoIniziale))" : "")"
                }.joined(separator: "\n")
            }
            return RispostaEve(titolo: "Le proposte", testo: testo)
        }
    }

    /// La scheda del portafoglio per Qwen: le cifre calcolate da Prisma.
    static func scheda(_ dati: DatiPrisma, oggi: Date = Date()) -> String {
        [SpuntoPortafoglio.quadro, .ricontattare, .riesami, .scadenze, .concentrazione, .proposte]
            .map { s in let r = risposta(s, domanda: "", dati: dati, oggi: oggi); return "\((r.titolo ?? "").uppercased()):\n\(r.testo)" }
            .joined(separator: "\n\n")
            .prefix(ContestoEve.limite)
            .description
    }
}
