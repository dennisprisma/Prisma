import Foundation

/// Il portafoglio del consulente: tutte le posizioni di tutti i clienti, per capire dove sta il
/// lavoro (quanto è seguito, per canale e per area), cosa scade nei prossimi mesi, quanto pesano
/// i singoli emittenti e come vanno le proposte.
struct Portafoglio {
    struct VoceCliente: Identifiable {
        let cliente: Cliente
        /// Attività in essere (debiti esclusi) e premi annui.
        let attivita: Double
        let premiAnnui: Double
        let capitaleAssicurato: Double
        let proposteAperte: Int
        let valoreProposte: Double
        let canali: [Canale]
        /// Parte delle attività del portafoglio (0…1).
        let quota: Double

        var id: String { cliente.id }
    }

    /// Le posizioni in essere che scadono in un mese.
    struct Mese: Identifiable {
        let inizio: Date
        let posizioni: [Posizione]
        /// Valore delle posizioni che liberano un capitale (le coperture a parte).
        let capitale: Double
        let coperture: Int

        var id: Date { inizio }
    }

    struct Emittente: Identifiable {
        let nome: String
        let valore: Double
        let quota: Double
        let posizioni: Int
        /// Il canale, se tutte le posizioni dell'emittente sono dello stesso.
        let canale: Canale?

        var id: String { nome }
    }

    let riepilogo: RiepilogoPosizioni
    let clienti: [VoceCliente]
    let scadenze: [Mese]
    let emittenti: [Emittente]
    let esiti: [EsitoProposta: Int]

    /// Proposte accettate sul totale di quelle decise (accettate più rifiutate); nil se nessuna è decisa.
    var tassoAccettazione: Double? {
        let si = esiti[.accettata] ?? 0, no = esiti[.rifiutata] ?? 0
        return si + no > 0 ? Double(si) / Double(si + no) : nil
    }

    static let mesiScadenze = 12
    static let massimoEmittenti = 6
    static let altriEmittenti = "Altri emittenti"
    static let senzaEmittente = "Emittente non indicato"
}

enum MotorePortafoglio {
    static func calcola(_ posizioni: [Posizione], clienti: [Cliente], oggi: Date = Date()) -> Portafoglio {
        let r = RiepilogoPosizioni(posizioni)
        let totale = r.attivita

        // Per cliente, dal più seguito
        let perCliente = Dictionary(grouping: posizioni, by: \.clienteId)
        let voci = clienti.compactMap { c -> Portafoglio.VoceCliente? in
            guard let sue = perCliente[c.id], !sue.isEmpty else { return nil }
            let rc = RiepilogoPosizioni(sue)
            let canali = Canale.allCases.filter { k in sue.contains { $0.canale == k } }
            return Portafoglio.VoceCliente(cliente: c, attivita: rc.attivita, premiAnnui: rc.premiAnnui,
                                           capitaleAssicurato: rc.capitaleAssicurato, proposteAperte: rc.proposteAperte,
                                           valoreProposte: rc.valoreProposte, canali: canali,
                                           quota: totale > 0 ? rc.attivita / totale : 0)
        }
        .sorted { $0.attivita != $1.attivita ? $0.attivita > $1.attivita : $0.cliente.nome < $1.cliente.nome }

        // Scadenze dei prossimi 12 mesi, mese per mese (solo i mesi con qualcosa)
        let cal = Calendar.current
        let inizioMese = cal.date(from: cal.dateComponents([.year, .month], from: oggi)) ?? oggi
        let oggiInizio = cal.startOfDay(for: oggi)
        let fine = cal.date(byAdding: .month, value: Portafoglio.mesiScadenze, to: inizioMese) ?? oggi
        let inScadenza = posizioni.filter { p in
            guard p.stato == .inEssere, let s = p.scadenza else { return false }
            return s >= oggiInizio && s < fine
        }
        let perMese = Dictionary(grouping: inScadenza) { p in
            cal.date(from: cal.dateComponents([.year, .month], from: p.scadenza ?? oggi)) ?? oggi
        }
        let mesi = perMese.keys.sorted().map { m -> Portafoglio.Mese in
            let elenco = (perMese[m] ?? []).sorted { ($0.scadenza ?? oggi) < ($1.scadenza ?? oggi) }
            let capitali = elenco.filter { $0.area != .protezione && !$0.area.passivo }
            return Portafoglio.Mese(inizio: m, posizioni: elenco, capitale: capitali.reduce(0) { $0 + $1.valore },
                                    coperture: elenco.filter { $0.area == .protezione }.count)
        }

        // Concentrazione per emittente (attività in essere, debiti esclusi)
        let attive = posizioni.filter { $0.stato == .inEssere && !$0.area.passivo && $0.valore > 0 }
        let perEmittente = Dictionary(grouping: attive) { p -> String in
            let e = p.emittente.trimmingCharacters(in: .whitespacesAndNewlines)
            return e.isEmpty ? Portafoglio.senzaEmittente : e
        }
        var emittenti = perEmittente.map { nome, elenco -> Portafoglio.Emittente in
            let valore = elenco.reduce(0) { $0 + $1.valore }
            let canali = Set(elenco.map(\.canale))
            return Portafoglio.Emittente(nome: nome, valore: valore, quota: totale > 0 ? valore / totale : 0,
                                         posizioni: elenco.count, canale: canali.count == 1 ? canali.first : nil)
        }
        .sorted { $0.valore != $1.valore ? $0.valore > $1.valore : $0.nome < $1.nome }
        if emittenti.count > Portafoglio.massimoEmittenti {
            let resto = emittenti.dropFirst(Portafoglio.massimoEmittenti - 1)
            let valore = resto.reduce(0) { $0 + $1.valore }
            emittenti = Array(emittenti.prefix(Portafoglio.massimoEmittenti - 1)) + [
                Portafoglio.Emittente(nome: Portafoglio.altriEmittenti, valore: valore, quota: totale > 0 ? valore / totale : 0,
                                      posizioni: resto.reduce(0) { $0 + $1.posizioni }, canale: nil),
            ]
        }

        // Proposte per esito
        var esiti: [EsitoProposta: Int] = [:]
        for p in posizioni where p.stato == .proposta { esiti[p.esito ?? .bozza, default: 0] += 1 }

        return Portafoglio(riepilogo: r, clienti: voci, scadenze: mesi, emittenti: emittenti, esiti: esiti)
    }
}
