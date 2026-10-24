import Foundation

/// Le cose da sistemare nei dossier che vengono dalle analisi delle posizioni: rischio oltre il profilo,
/// costi alti, beneficiari mancanti, convivente non tutelato. Calcoli leggeri (senza cercare alternative
/// nel catalogo), per tutto il portafoglio e per le notifiche.
struct Attenzione: Identifiable {
    enum Tipo: Int, CaseIterable {
        case beneficiari, convivente, rischio, costi

        var nome: String {
            switch self {
            case .beneficiari: return "Beneficiari"
            case .convivente: return "Convivente"
            case .rischio: return "Rischio"
            case .costi: return "Costi"
            }
        }

        /// Il pannello del dossier Posizioni che la spiega.
        var ancora: String {
            switch self {
            case .beneficiari, .convivente: return "successione"
            case .rischio: return "resistenza"
            case .costi: return "costi"
            }
        }
    }

    let cliente: Cliente
    let tipo: Tipo
    let titolo: String
    let dettaglio: String
    var id: String { "\(cliente.id)·\(tipo.rawValue)·\(titolo)" }
}

enum MotoreAttenzioni {
    static func calcola(cliente c: Cliente, posizioni: [Posizione]) -> [Attenzione] {
        var elenco: [Attenzione] = []
        let mie = posizioni.filter { $0.clienteId == c.id && $0.stato == .inEssere }
        guard !mie.isEmpty else { return [] }
        let s = MotoreSuccessione.calcola(cliente: c, posizioni: mie)
        let senza = s.daSistemare.filter { $0.posizione.senzaBeneficiari }
        let altri = s.daSistemare.filter { v in !senza.contains { $0.id == v.id } }
        if !senza.isEmpty {
            elenco.append(.init(cliente: c, tipo: .beneficiari, titolo: senza.count == 1 ? "Beneficiari da indicare" : "Beneficiari da indicare su \(senza.count) polizze",
                                dettaglio: senza.map(\.posizione.nome).joined(separator: ", ")))
        }
        if let cv = s.conviventeEscluso {
            elenco.append(.init(cliente: c, tipo: .convivente, titolo: "\(cv) non è tutelato",
                                dettaglio: altri.first?.avviso ?? "Convivente: senza testamento non eredita."))
        } else if let v = altri.first {
            elenco.append(.init(cliente: c, tipo: .beneficiari, titolo: "Beneficiari da rivedere", dettaglio: "\(v.posizione.nome): \(v.avviso ?? "")"))
        }
        let r = MotoreResistenza.calcola(mie, profilo: c.profilo)
        if let g = r.giudizio, g != .dentro, let m = r.scenario(.mercati) {
            elenco.append(.init(cliente: c, tipo: .rischio, titolo: g == .oltre ? "Rischio oltre il profilo" : "Rischio al limite del profilo",
                                dettaglio: "In un anno di crisi \(CifreDoc.percento(m.quota * 100)) contro il \(CifreDoc.condizione(r.sopportabile ?? 0)) sopportabile"))
        }
        // Solo il costo annuo dichiarato, senza proiezioni: il pannello gira su tutti i clienti
        let alti = mie.filter { $0.stato == .inEssere && $0.area.proiettabile && ($0.costoComplessivo ?? 0) > MotoreCosti.sogliaAlto }
        if !alti.isEmpty {
            elenco.append(.init(cliente: c, tipo: .costi, titolo: alti.count == 1 ? "Un costo alto" : "\(alti.count) costi alti",
                                dettaglio: alti.map { "\($0.nome) \(CifreDoc.percento($0.costoComplessivo ?? 0, decimali: 2))" }.joined(separator: ", ")))
        }
        return elenco
    }

    static func calcola(clienti: [Cliente], posizioni: [Posizione]) -> [Attenzione] {
        let perCliente = Dictionary(grouping: posizioni, by: \.clienteId)
        return clienti.flatMap { c in calcola(cliente: c, posizioni: perCliente[c.id] ?? []) }
            .sorted { ($0.tipo.rawValue, $0.cliente.nome) < ($1.tipo.rawValue, $1.cliente.nome) }
    }
}
