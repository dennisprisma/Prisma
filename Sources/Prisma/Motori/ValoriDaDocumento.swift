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
              let data = EstrattoreDocumento.data(d.confermato(.dataValore)) else { return nil }
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
        let nome = d.campo(.nomeProdotto)?.valore ?? ""
        let testo = piega(nome + " " + d.titolo)
        return elenco.filter { !$0.nome.isEmpty && testo.contains(piega($0.nome)) }.max { $0.nome.count < $1.nome.count }
    }

    /// true se lo storico della posizione ha già questo valore in quel giorno.
    static func registrato(_ v: Valore, in p: Posizione) -> Bool {
        p.storicoValori.contains { Calendar.current.isDate($0.data, inSameDayAs: v.data) && abs($0.controvalore - v.valore) < 0.5 }
    }

    /// Porta il valore nella posizione: dal giorno del valore attuale in poi lo sostituisce, prima si aggiunge allo storico.
    @discardableResult
    static func applica(_ v: Valore, a p: inout Posizione) -> Esito {
        let cal = Calendar.current
        if p.dataValore.map({ cal.startOfDay(for: v.data) >= cal.startOfDay(for: $0) }) ?? true {
            let prima = p
            p.controvalore = v.valore
            p.dataValore = v.data
            if let versato = v.versato { p.totaleVersato = versato }
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
