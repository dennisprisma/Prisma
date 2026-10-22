import Foundation

/// Eve spiega i documenti del cliente (KID, polizze, estratti conto, proposte): i dati trovati con
/// la pagina da cui vengono, cosa significano per il consulente, cosa non torna con il dossier e
/// cosa resta da verificare. Tutto dai dati estratti da Prisma: niente cifre inventate.
extension MotoreSintesi {

    func documento(_ d: Documento, fonte f: FonteEve) -> RispostaEve {
        var parti: [String] = []
        let campi = d.campi
        guard !d.tipo.creatoDaPrisma else {
            return RispostaEve(titolo: d.titolo, testo: "È un documento impaginato da Prisma con i dati del dossier: le cifre sono quelle dei calcoli dell'app. Lo trovi in Prospetti e report, dove posso spiegarlo con «Chiedi a Eve».")
        }
        guard !campi.isEmpty else {
            return RispostaEve(titolo: d.titolo, testo: d.lettura == .illeggibile
                ? "Non riesco a leggere il testo del documento: serve una scansione più nitida o il PDF originale."
                : "Nel documento non ho trovato dati riconoscibili. Il testo letto è nella scheda «Testo letto» di Documenti.")
        }

        // Che cos'è
        var chi = [valore(d, .nomeProdotto), valore(d, .tipologia)].compactMap { $0 }.joined(separator: ", ")
        if let e = valore(d, .emittente) { chi += chi.isEmpty ? e : " di \(e)" }
        if !chi.isEmpty { parti.append("\(d.tipo.nome): \(chi).") }

        switch d.tipo {
        case .kid, .proposta:
            parti.append(contentsOf: kid(d, fonte: f))
        case .polizza:
            parti.append(contentsOf: polizza(d))
        case .estrattoConto:
            if let c = d.campo(.controvalore) { parti.append("Controvalore \(cifra(c)) \(pagina(c)).") }
        case .altro, .prospetto, .report:
            break
        }

        // Il resto dei dati trovati, se non già detti
        let detti: Set<CampoDocumento> = [.nomeProdotto, .tipologia, .emittente, .sri, .periodoDetenzione, .costoIngresso, .costoUscita, .costoAnnuo,
                                          .incidenzaCosti, .rendimentoModerato, .contraente, .assicurato, .beneficiari, .decorrenza, .scadenza,
                                          .premio, .capitaleAssicurato, .controvalore, .numeroContratto]
        let altri = campi.filter { !detti.contains($0.chiave) }
        if !altri.isEmpty { parti.append(altri.map { "\($0.chiave.nome): \(cifra($0)) \(pagina($0))" }.joined(separator: "; ") + ".") }

        // Confronto con il dossier
        let differenze = confronta(d, fonte: f)
        if !differenze.isEmpty {
            parti.append("Non torna con il dossier:\n" + differenze.map { "• " + $0 }.joined(separator: "\n"))
        } else if let p = posizione(d, f) {
            parti.append("I dati confermati coincidono con la posizione \(p.nome) (\(p.canale.nomeBreve)).")
        }

        // Da confermare e da verificare
        let daConfermare = campi.filter { !$0.confermato }
        if !daConfermare.isEmpty {
            parti.append("Da confermare in Documenti: \(daConfermare.map { $0.chiave.nome.lowercased() }.joined(separator: ", ")). Finché non li confermi non entrano nel dossier.")
        }
        let mancano = attesi(d.tipo).filter { d.campo($0) == nil }
        if !mancano.isEmpty {
            parti.append("Non li ho trovati: \(mancano.map { $0.nome.lowercased() }.joined(separator: ", ")). Vanno cercati nel documento o chiesti alla compagnia.")
        }
        parti.append(verifiche(d.tipo))
        return RispostaEve(titolo: "\(d.tipo.breve): \(d.titolo)", testo: parti.joined(separator: "\n\n"))
    }

    /// Spunto «Cosa dicono i documenti?»: una riga per documento, con le differenze dal dossier.
    func documenti(_ f: FonteEve) -> RispostaEve {
        let elenco = f.documenti.filter { !$0.tipo.creatoDaPrisma }.sorted { $0.importatoIl > $1.importatoIl }
        guard !elenco.isEmpty else {
            return RispostaEve(titolo: "Nessun documento",
                               testo: "\(f.cliente.nome) non ha ancora documenti. Si importano in Documenti (KID, polizze, estratti conto): Prisma li legge sul Mac e io li spiego.")
        }
        var righe: [String] = []
        var avvisi: [String] = []
        for d in elenco.prefix(6) {
            var r = "• \(d.tipo.breve) «\(d.titolo)», \(d.pagine) \(d.pagine == 1 ? "pagina" : "pagine")"
            var dati: [String] = []
            if let c = d.campo(.sri) { dati.append("rischio \(c.valore) su 7") }
            if let c = d.campo(.periodoDetenzione) { dati.append("\(c.valore) anni consigliati") }
            if let c = d.campo(.costoAnnuo) ?? d.campo(.incidenzaCosti) { dati.append("costi \(c.valore)% l'anno") }
            if let c = d.campo(.capitaleAssicurato) { dati.append("capitale \(cifra(c))") }
            if let c = d.campo(.scadenza) { dati.append("scadenza \(c.valore)") }
            if let c = d.campo(.controvalore) { dati.append("controvalore \(cifra(c))") }
            if !dati.isEmpty { r += ": " + dati.joined(separator: ", ") }
            let daConfermare = d.campi.filter { !$0.confermato }.count
            if daConfermare > 0 { r += " (\(daConfermare) dati da confermare)" }
            righe.append(r + ".")
            avvisi += confronta(d, fonte: f).map { "\(d.titolo): \($0)" }
        }
        var testo = righe.joined(separator: "\n")
        if !avvisi.isEmpty { testo += "\n\nNon torna con il dossier:\n" + avvisi.map { "• " + $0 }.joined(separator: "\n") }
        testo += "\n\nPer la spiegazione di un documento: apri Documenti e usa «Chiedi a Eve»."
        return RispostaEve(titolo: "I documenti di \(f.cliente.nome)", testo: testo)
    }

    // MARK: - Per tipo

    private func kid(_ d: Documento, fonte f: FonteEve) -> [String] {
        var parti: [String] = []
        if let c = d.campo(.sri), let n = Int(c.valore.trimmingCharacters(in: .whitespaces)) {
            let lettura = n <= 2 ? "basso" : n <= 4 ? "medio" : n <= 5 ? "medio-alto" : "alto"
            var r = "Rischio \(n) su 7 (\(lettura)) \(pagina(c))"
            if let p = f.cliente.profilo.propensione {
                let massimo: Int
                switch p {
                case .prudente: massimo = 2
                case .moderata: massimo = 4
                case .dinamica: massimo = 5
                case .aggressiva: massimo = 7
                }
                r += n > massimo ? ": più alto di quanto regge una propensione \(p.nome.lowercased())." : ": in linea con la propensione \(p.nome.lowercased())."
            } else {
                r += "."
            }
            parti.append(r)
        }
        if let c = d.campo(.periodoDetenzione) {
            var r = "Periodo di detenzione raccomandato \(c.valore) anni \(pagina(c))"
            if let anni = EstrattoreDocumento.numero(c.valore), let o = f.cliente.profilo.orizzonteAnni {
                r += Double(o) < anni ? ": più lungo dell'orizzonte del cliente (\(o) anni), uscire prima può costare." : ": compatibile con l'orizzonte del cliente (\(o) anni)."
            } else {
                r += "."
            }
            parti.append(r)
        }
        let costi = [CampoDocumento.costoIngresso, .costoUscita, .costoAnnuo, .incidenzaCosti].compactMap { k in d.campo(k).map { "\(k.nome.lowercased()) \(cifra($0)) \(pagina($0))" } }
        if !costi.isEmpty { parti.append("Costi: " + costi.joined(separator: "; ") + ".") }
        if let c = d.campo(.rendimentoModerato) {
            parti.append("Scenario moderato \(cifra(c)) l'anno \(pagina(c)): è una stima del documento, non una promessa.")
        }
        return parti
    }

    private func polizza(_ d: Documento) -> [String] {
        var parti: [String] = []
        let persone = [CampoDocumento.contraente, .assicurato, .beneficiari].compactMap { k in d.campo(k).map { "\(k.nome.lowercased()) \($0.valore) \(pagina($0))" } }
        if !persone.isEmpty { parti.append("Persone: " + persone.joined(separator: "; ") + ".") }
        let durata = [CampoDocumento.numeroContratto, .decorrenza, .scadenza].compactMap { k in d.campo(k).map { "\(k.nome.lowercased()) \($0.valore) \(pagina($0))" } }
        if !durata.isEmpty { parti.append("Contratto: " + durata.joined(separator: "; ") + ".") }
        let soldi = [CampoDocumento.premio, .capitaleAssicurato].compactMap { k in d.campo(k).map { "\(k.nome.lowercased()) \(cifra($0)) \(pagina($0))" } }
        if !soldi.isEmpty { parti.append("Importi: " + soldi.joined(separator: "; ") + ".") }
        return parti
    }

    // MARK: - Confronto con il dossier

    /// Le differenze tra i dati del documento e la posizione collegata (o con lo stesso nome).
    func confronta(_ d: Documento, fonte f: FonteEve) -> [String] {
        guard let p = posizione(d, f) else { return [] }
        var diff: [String] = []
        func numero(_ k: CampoDocumento) -> (Double, CampoEstratto)? {
            guard let c = d.campo(k), let n = EstrattoreDocumento.numero(c.valore) else { return nil }
            return (n, c)
        }
        let nomePos = "la posizione \(p.nome) (\(p.canale.nomeBreve))"
        if let x = numero(.capitaleAssicurato), let cap = p.capitaleAssicurato, abs(x.0 - cap) > 1 {
            diff.append("capitale assicurato \(CifreDoc.euro(x.0)) \(pagina(x.1)), \(nomePos) dice \(CifreDoc.euro(cap))")
        }
        if let x = numero(.premio), p.premio > 0, abs(x.0 - p.premio) > 1 {
            diff.append("premio \(CifreDoc.euroCentesimi(x.0)) \(pagina(x.1)), \(nomePos) dice \(CifreDoc.euroCentesimi(p.premio))")
        }
        if let x = numero(.controvalore), abs(x.0 - p.valore) > 1 {
            diff.append("controvalore \(CifreDoc.euroCentesimi(x.0)) \(pagina(x.1)), \(nomePos) vale \(CifreDoc.euroCentesimi(p.valore)): aggiorna il valore")
        }
        if let x = numero(.costoAnnuo) ?? numero(.incidenzaCosti), let k = p.costoAnnuo, abs(x.0 - k) > 0.05 {
            diff.append("costi annui \(CifreDoc.condizione(x.0)) \(pagina(x.1)), \(nomePos) indica \(CifreDoc.condizione(k))")
        }
        if let c = d.campo(.scadenza), let s = EstrattoreDocumento.data(c.valore), let ps = p.scadenza,
           !Calendar.current.isDate(s, inSameDayAs: ps) {
            diff.append("scadenza \(c.valore) \(pagina(c)), \(nomePos) indica \(CifreDoc.dataBreve(ps))")
        }
        return diff
    }

    private func posizione(_ d: Documento, _ f: FonteEve) -> Posizione? {
        if let id = d.posizioneId, let p = f.posizioni.first(where: { $0.id == id }) { return p }
        guard let nome = valore(d, .nomeProdotto)?.lowercased(), nome.count > 4 else { return nil }
        return f.posizioni.first { $0.nome.lowercased() == nome }
    }

    // MARK: - Aiuti

    private func valore(_ d: Documento, _ k: CampoDocumento) -> String? {
        d.campo(k)?.valore.trimmingCharacters(in: .whitespaces)
    }

    private func pagina(_ c: CampoEstratto) -> String { "(pag. \(c.pagina)\(c.confermato ? "" : ", da confermare"))" }

    private func cifra(_ c: CampoEstratto) -> String {
        switch c.chiave.unita {
        case "€": return "€ \(c.valore)"
        case "%": return "\(c.valore)%"
        case "": return c.valore
        default: return "\(c.valore) \(c.chiave.unita)"
        }
    }

    private func attesi(_ t: Documento.Tipo) -> [CampoDocumento] {
        switch t {
        case .kid: return [.sri, .periodoDetenzione, .costoIngresso, .incidenzaCosti]
        case .polizza: return [.contraente, .assicurato, .scadenza, .premio, .capitaleAssicurato]
        case .estrattoConto: return [.controvalore]
        case .proposta: return [.nomeProdotto, .premio]
        case .altro, .prospetto, .report: return []
        }
    }

    private func verifiche(_ t: Documento.Tipo) -> String {
        switch t {
        case .kid: return "Da verificare con il cliente: costi e penali se esce prima del periodo raccomandato, e che il rischio sia quello che accetta."
        case .polizza: return "Da verificare nelle condizioni di polizza: esclusioni, carenze, franchigie e massimali, che qui non leggo."
        case .estrattoConto: return "Da verificare: la data di riferimento dell'estratto e i movimenti del periodo."
        case .proposta: return "Da verificare: KID e set informativo del prodotto proposto prima della firma."
        case .altro, .prospetto, .report: return "Il testo completo è nella scheda «Testo letto» di Documenti."
        }
    }
}
