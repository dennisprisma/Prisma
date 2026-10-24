import Foundation

/// Dagli estratti conto allo storico delle posizioni: il valore letto (e confermato) in un documento,
/// la posizione a cui con ogni probabilità si riferisce e come entra nello storico. Il più recente
/// diventa il valore attuale (quello di prima resta tra le rilevazioni); uno più vecchio si aggiunge
/// tra i valori passati.
enum ValoriDaDocumento {
    struct Valore: Equatable {
        let data: Date
        let valore: Double
        let versato: Double?
    }

    enum Esito: Equatable {
        /// Diventato il valore attuale della posizione.
        case attuale
        /// Aggiunto tra i valori passati.
        case passato
    }

    /// Il valore confermato del documento: controvalore e data del valore, il versato se c'è.
    static func valore(_ d: Documento) -> Valore? {
        guard let v = EstrattoreDocumento.numero(d.confermato(.controvalore)), v >= 0,
              let data = EstrattoreDocumento.data(d.confermato(.dataValore)),
              // Una data futura è una proiezione (tabelle dei valori di riscatto), non un valore rilevato
              data < (Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()) else { return nil }
        return Valore(data: mezzogiorno(data), valore: v, versato: EstrattoreDocumento.numero(d.confermato(.totaleVersato)))
    }

    /// Il documento parla del valore di una posizione: estratti conto e documenti con un controvalore.
    static func pertinente(_ d: Documento) -> Bool {
        !d.tipo.creatoDaPrisma && d.tipo != .kid && (d.tipo == .estrattoConto || d.campo(.controvalore) != nil)
    }

    /// Le posizioni del cliente che possono ricevere un valore (in essere, non coperture né debiti).
    static func candidate(_ d: Documento, tra posizioni: [Posizione]) -> [Posizione] {
        posizioni.filter { $0.clienteId == d.clienteId && $0.stato == .inEssere && $0.area != .protezione && !$0.area.passivo }
    }

    /// La posizione più probabile: quella già collegata, poi il numero di contratto, poi il nome del prodotto.
    static func posizioneProbabile(_ d: Documento, tra posizioni: [Posizione]) -> Posizione? {
        let elenco = candidate(d, tra: posizioni)
        if let id = d.posizioneId, let p = elenco.first(where: { $0.id == id }) { return p }
        let numero = (d.campo(.numeroContratto)?.valore).map(compatto) ?? ""
        if !numero.isEmpty, let p = elenco.first(where: { !$0.numeroContratto.isEmpty && compatto($0.numeroContratto) == numero }) { return p }
        // Dal nome, a parole intere; mai una posizione con un altro numero di contratto, mai a caso tra due uguali
        let nome = d.campo(.nomeProdotto)?.valore ?? ""
        let parole = " " + piega(nome + " " + d.titolo).split { !$0.isLetter && !$0.isNumber }.joined(separator: " ") + " "
        let trovate = elenco.filter { p in
            let suo = piega(p.nome).split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
            guard !suo.isEmpty, parole.contains(" \(suo) ") else { return false }
            return numero.isEmpty || p.numeroContratto.isEmpty || compatto(p.numeroContratto) == numero
        }
        guard let lunghezza = trovate.map(\.nome.count).max() else { return nil }
        let migliori = trovate.filter { $0.nome.count == lunghezza }
        return migliori.count == 1 ? migliori.first : nil
    }

    /// true se lo storico della posizione ha già questo valore in quel giorno.
    static func registrato(_ v: Valore, in p: Posizione) -> Bool {
        p.storicoValori.contains { Calendar.current.isDate($0.data, inSameDayAs: v.data) && abs($0.controvalore - v.valore) < 0.5 }
    }

    /// Porta il valore nella posizione: dal giorno del valore attuale in poi lo sostituisce, prima si aggiunge allo storico.
    @discardableResult
    static func applica(_ v: Valore, a p: inout Posizione) -> Esito {
        let cal = Calendar.current
        // Senza la data del valore, quello attuale vale dal giorno in cui la posizione è stata inserita
        let riferimento = p.dataValore ?? (p.controvalore == nil ? nil : p.creataIl)
        if riferimento.map({ cal.startOfDay(for: v.data) >= cal.startOfDay(for: $0) }) ?? true {
            let prima = p
            p.controvalore = v.valore
            p.dataValore = v.data
            if let versato = v.versato {
                p.totaleVersato = versato
            } else if let vecchio = p.totaleVersato, let dal = riferimento, p.premioAnnuo > 0 {
                // Senza il versato nell'estratto: quello di prima più i premi del periodo (non un versato fermo,
                // che farebbe passare i premi per guadagno)
                p.totaleVersato = vecchio + p.premioAnnuo * max(0, v.data.timeIntervalSince(dal)) / MotoreAndamento.anno
            }
            p.registraValorePrecedente(prima)
            return .attuale
        }
        var elenco = p.rilevazioni ?? []
        elenco.removeAll { cal.isDate($0.data, inSameDayAs: v.data) }
        elenco.append(Rilevazione(data: v.data, controvalore: v.valore, versato: v.versato))
        p.rilevazioni = elenco.sorted { $0.data < $1.data }
        return .passato
    }

    /// A mezzogiorno e a secondi interi, come il resto dell'archivio: il giorno non cambia col fuso.
    static func mezzogiorno(_ d: Date) -> Date {
        let g = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: d) ?? d
        return Date(timeIntervalSinceReferenceDate: g.timeIntervalSinceReferenceDate.rounded(.down))
    }

    private static func compatto(_ s: String) -> String {
        s.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func piega(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Formati.italiano)
    }
}
