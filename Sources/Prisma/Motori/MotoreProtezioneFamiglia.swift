import Foundation

/// Come è messo un rischio: coperto, solo in proposta, scoperto.
enum StatoTutela: String {
    case coperto, inProposta, scoperto

    var nome: String {
        switch self {
        case .coperto: return "Coperto"
        case .inProposta: return "In proposta"
        case .scoperto: return "Scoperto"
        }
    }
}

/// Un rischio della famiglia con le coperture che lo proteggono.
struct TutelaRischio: Identifiable {
    let rischio: RischioCoperto
    var id: RischioCoperto { rischio }
    let coperture: [Posizione]
    let proposte: [Posizione]
    /// Perché conta per questa famiglia (vuoto se è secondario).
    let perche: String
    /// true se, per questa famiglia, è una tutela da avere.
    let importante: Bool

    var stato: StatoTutela {
        if !coperture.isEmpty { return .coperto }
        return proposte.isEmpty ? .scoperto : .inProposta
    }
    var capitale: Double { coperture.reduce(0) { $0 + ($1.capitaleAssicurato ?? 0) } }
    var capitaleProposte: Double { proposte.reduce(0) { $0 + ($1.capitaleAssicurato ?? 0) } }
    var premioAnnuo: Double { coperture.reduce(0) { $0 + $1.premioAnnuo } }
}

/// Un avviso su una copertura: scade prima del mutuo, prima che i figli siano autonomi…
struct AvvisoTutela: Identifiable {
    let testo: String
    var id: String { testo }
}

/// La protezione della famiglia: fabbisogno caso morte, invalidità, mappa dei rischi, costi e detrazioni.
struct EsitoProtezioneFamiglia {
    let famiglia: [Familiare]
    let eta: Int?
    let ipotesi: IpotesiProtezione
    // Caso morte
    var sostegno: Double { ipotesi.fabbisognoMensile * 12 * Double(ipotesi.anniSostegno) }
    var fabbisogno: Double { max(0, ipotesi.debiti + ipotesi.speseImmediate + sostegno - ipotesi.capitaleDisponibile) }
    let capitaleVita: Double
    let capitaleVitaProposte: Double
    var divario: Double { max(0, fabbisogno - capitaleVita) }
    var divarioConProposte: Double { max(0, fabbisogno - capitaleVita - capitaleVitaProposte) }
    /// Anni di sostegno che la famiglia avrebbe oggi (capitali e liquidità, tolti debiti e spese).
    var anniCoperti: Double {
        let mensile = ipotesi.fabbisognoMensile * 12
        guard mensile > 0 else { return 0 }
        return max(0, (capitaleVita + ipotesi.capitaleDisponibile - ipotesi.debiti - ipotesi.speseImmediate) / mensile)
    }
    /// Anni di sostegno suggeriti: fino ai 25 anni del figlio più giovane a carico.
    let anniSuggeriti: Int?
    // Invalidità e malattia
    var ammanco: Double { max(0, ipotesi.fabbisognoMensile - ipotesi.entrateSostitutive) }
    var riservaNecessaria: Double { ammanco * Double(ipotesi.mesiRiserva) }
    var riservaMancante: Double { max(0, riservaNecessaria - ipotesi.riserva) }
    // Mappa, costi, detrazioni
    let tutele: [TutelaRischio]
    let coperture: [Posizione]
    let proposte: [Posizione]
    var premiAnnui: Double { coperture.reduce(0) { $0 + $1.premioAnnuo } }
    var premiProposte: Double { proposte.reduce(0) { $0 + $1.premioAnnuo } }
    let reddito: Double?
    /// Premi detraibili e detrazione IRPEF del 19%, oggi e con le proposte.
    let detraibili: Double
    let detraibiliConProposte: Double
    var detrazione: Double { detraibili * RegoleFiscali.detrazionePremi / 100 }
    var detrazioneConProposte: Double { detraibiliConProposte * RegoleFiscali.detrazionePremi / 100 }
    let avvisi: [AvvisoTutela]
    let note: [String]

    var scoperti: [TutelaRischio] { tutele.filter { $0.importante && $0.stato == .scoperto } }
    var canali: [Canale] { Canale.allCases.filter { c in (coperture + proposte).contains { $0.canale == c } } }
}

/// Calcoli della protezione della famiglia, dalle ipotesi dell'Analisi 360 e dalle coperture nelle Posizioni.
enum MotoreProtezioneFamiglia {
    static func calcola(_ posizioni: [Posizione], cliente: Cliente?, analisi: IpotesiProtezione, data: Date = Date()) -> EsitoProtezioneFamiglia {
        let famiglia = cliente?.famiglia ?? []
        let eta = cliente?.eta
        let coperture = posizioni.filter { $0.area == .protezione && $0.stato == .inEssere && !$0.scaduta }
        let proposte = posizioni.filter { $0.area == .protezione && $0.stato == .proposta && $0.esito != .rifiutata && $0.esito != .accettata }
        var note: [String] = []

        // Chi dipende dal cliente
        let figli = famiglia.filter { [.figlio, .figlia].contains($0.relazione) }
        let aCarico = famiglia.filter { $0.aCarico || (([.figlio, .figlia].contains($0.relazione)) && ($0.eta ?? 99) < 25) }
        let partner = famiglia.contains { [.coniuge, .convivente].contains($0.relazione) }
        let debiti = posizioni.filter { $0.area == .debiti && $0.stato == .inEssere }
        let piuGiovane = aCarico.filter { [.figlio, .figlia].contains($0.relazione) }.compactMap(\.eta).min()
        let anniSuggeriti = piuGiovane.map { max(0, 25 - $0) }

        func tutela(_ r: RischioCoperto, importante: Bool, perche: String) -> TutelaRischio {
            TutelaRischio(rischio: r, coperture: coperture.filter { ($0.rischio ?? .altro) == r },
                          proposte: proposte.filter { ($0.rischio ?? .altro) == r }, perche: perche, importante: importante)
        }
        let dipendono = !aCarico.isEmpty || partner
        var tutele = [
            tutela(.vita, importante: dipendono || !debiti.isEmpty,
                   perche: dipendono ? "\(aCarico.isEmpty ? "Il partner" : "Chi è a carico") e \(debiti.isEmpty ? "il tenore di vita" : "i debiti") dipendono dal tuo reddito."
                                     : (debiti.isEmpty ? "" : "Ci sono debiti da estinguere.")),
            tutela(.invalidita, importante: true, perche: "Senza reddito da lavoro mancherebbero \(CifreDoc.euro(max(0, analisi.fabbisognoMensile - analisi.entrateSostitutive))) al mese."),
            tutela(.infortuni, importante: true, perche: "Un infortunio può fermare il lavoro anche per mesi."),
            tutela(.salute, importante: (eta ?? 0) >= 40, perche: (eta ?? 0) >= 40 ? "Con gli anni crescono le spese sanitarie private." : ""),
            tutela(.ltc, importante: (eta ?? 0) >= 50, perche: (eta ?? 0) >= 50 ? "La non autosufficienza costa in media oltre 1.500 € al mese." : ""),
            tutela(.casa, importante: posizioni.contains { $0.area == .immobili && $0.stato == .inEssere }, perche: "La casa è spesso il bene più grande della famiglia."),
            tutela(.rc, importante: dipendono, perche: dipendono ? "I danni causati a terzi da te o dai familiari." : ""),
        ]
        // Le coperture con un rischio "altro" restano visibili
        let altre = tutela(.altro, importante: false, perche: "")
        if !altre.coperture.isEmpty || !altre.proposte.isEmpty { tutele.append(altre) }

        // Avvisi: coperture che finiscono troppo presto
        var avvisi: [AvvisoTutela] = []
        for c in coperture where c.rischio == .vita {
            if let s = c.scadenza {
                for d in debiti {
                    if let fine = d.scadenza, s < fine {
                        avvisi.append(AvvisoTutela(testo: "\(c.nome) scade il \(CifreDoc.dataBreve(s)), prima della fine di \(d.nome.lowercased()) (\(CifreDoc.dataBreve(fine)))."))
                    }
                }
                if let anni = anniSuggeriti, let fine = Calendar.current.date(byAdding: .year, value: anni, to: data), s < fine {
                    avvisi.append(AvvisoTutela(testo: "\(c.nome) scade il \(CifreDoc.dataBreve(s)), prima che il figlio più giovane compia 25 anni."))
                }
            }
        }
        for c in coperture where c.scadeEntro(90) {
            avvisi.append(AvvisoTutela(testo: "\(c.nome) scade o si rinnova il \(CifreDoc.dataBreve(c.scadenza ?? data)): verificare le somme assicurate."))
        }
        if let suggeriti = anniSuggeriti, suggeriti > analisi.anniSostegno {
            avvisi.append(AvvisoTutela(testo: "Gli anni di sostegno (\(analisi.anniSostegno)) sono meno di quelli che servono al figlio più giovane per arrivare a 25 anni (\(suggeriti))."))
        }
        if figli.isEmpty && !partner { note.append("Nessun familiare indicato nel dossier: il fabbisogno è quello delle ipotesi dell'Analisi 360.") }

        // Detrazione del 19%: vita, invalidità e infortuni fino a 530 €, con la LTC fino a 1.291,14 €
        func detraibili(_ elenco: [Posizione]) -> Double {
            let vita = elenco.filter { [.vita, .invalidita, .infortuni].contains($0.rischio ?? .altro) }.reduce(0) { $0 + $1.premioAnnuo }
            let ltc = elenco.filter { $0.rischio == .ltc }.reduce(0) { $0 + $1.premioAnnuo }
            let primi = min(vita, RegoleFiscali.limitePremiVita)
            return min(primi + ltc, RegoleFiscali.limitePremiLTC)
        }
        note.append("Detrazione IRPEF del 19% sui premi: caso morte, invalidità e infortuni fino a \(CifreDoc.euroCentesimi(RegoleFiscali.limitePremiVita)) l'anno, insieme alla non autosufficienza fino a \(CifreDoc.euroCentesimi(RegoleFiscali.limitePremiLTC)); spetta se il contraente ha capienza d'imposta.")
        note.append("Fabbisogno caso morte: debiti da estinguere + spese immediate + fabbisogno mensile per gli anni di sostegno − capitale già disponibile per la famiglia (ipotesi dell'Analisi 360).")

        return EsitoProtezioneFamiglia(
            famiglia: famiglia, eta: eta, ipotesi: analisi,
            capitaleVita: MotoreAnalisi.capitaleVita(posizioni), capitaleVitaProposte: MotoreAnalisi.capitaleVita(posizioni, stato: .proposta),
            anniSuggeriti: anniSuggeriti, tutele: tutele, coperture: coperture, proposte: proposte,
            reddito: cliente?.profilo.redditoLordoAnnuo,
            detraibili: detraibili(coperture), detraibiliConProposte: detraibili(coperture + proposte),
            avvisi: avvisi, note: note + Semplificazioni.protezione)
    }
}
