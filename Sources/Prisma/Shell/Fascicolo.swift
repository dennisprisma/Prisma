import SwiftUI

private typealias T = Tipo.Report

/// Il fascicolo dell'incontro: i report scelti per il cliente in un solo PDF, con una copertina,
/// un indice e la password del cliente come per ogni documento.
extension TipoProspetto {
    /// I report che possono entrare nel fascicolo, nell'ordine in cui si leggono.
    static let inFascicolo: [TipoProspetto] = [.checkUp, .resoconto, .patrimonio, .resistenza, .costi, .successione, .previdenza, .protezione, .liquidita]
    /// Quelli spuntati all'inizio: il quadro e le tre analisi nuove.
    static let fascicoloPredefinito: Set<TipoProspetto> = [.resoconto, .patrimonio, .resistenza, .costi, .successione]

    /// I report adatti a un appuntamento: dal tipo d'incontro e dalla posizione di cui si parla.
    static func perIncontro(_ a: Appuntamento, posizione: Posizione?, oggi: Date = Date()) -> Set<TipoProspetto> {
        var scelti: Set<TipoProspetto>
        switch a.tipo {
        case .primoIncontro: scelti = [.checkUp, .patrimonio]
        case .analisi: scelti = [.resoconto, .patrimonio, .resistenza, .costi]
        case .revisione: scelti = [.resoconto, .patrimonio, .resistenza, .costi, .successione]
        case .proposta: scelti = [.resoconto, .patrimonio, .costi]
        case .firma: scelti = [.resoconto]
        case .telefonata, .altro: scelti = fascicoloPredefinito
        }
        if let p = posizione {
            // Una scadenza vicina: il capitale da destinare e chi lo riceverebbe
            let fraUnAnno = Calendar.current.date(byAdding: .month, value: 12, to: oggi) ?? oggi
            if let s = p.scadenza, s <= fraUnAnno { scelti.formUnion([.liquidita, .successione]) }
            if p.area == .previdenza { scelti.insert(.previdenza) }
            if p.area == .protezione { scelti.insert(.protezione) }
        }
        return scelti
    }

    /// La scelta del report per il cliente di questo tipo (nil se non ha un report).
    var report: SceltaProspetto? {
        switch self {
        case .checkUp: return .checkUp(report: true)
        case .resoconto: return .resoconto(report: true)
        case .patrimonio: return .patrimonio(report: true)
        case .resistenza: return .resistenza(report: true)
        case .costi: return .costi(report: true)
        case .successione: return .successione(report: true)
        case .previdenza: return .previdenza(report: true)
        case .protezione: return .protezione(report: true)
        case .liquidita: return .liquidita(report: true)
        default: return nil
        }
    }
}

extension DocumentoStampabile {
    /// Un documento già impaginato in A4 orizzontale (il fascicolo).
    init(report titolo: String, cliente: String, pagine: [AnyView]) {
        self.titolo = titolo
        self.cliente = cliente
        genere = "Report"
        formato = Misure.Documento.report
        self.pagine = pagine
        tipo = .report
    }
}

extension StatoShell {
    /// Il fascicolo del cliente attivo con i report spuntati (con il commento di ciascuno, se c'è).
    func documentoFascicolo() -> DocumentoStampabile? {
        let parti = TipoProspetto.inFascicolo.filter { sceltaFascicolo.contains($0) }.compactMap { t -> (String, DocumentoStampabile)? in
            guard let scelta = t.report, let d = documentoProspetto(scelta) else { return nil }
            return (d.titolo, d)
        }
        guard !parti.isEmpty, let c = clienteAttivo else { return nil }
        var voci: [(String, Int)] = []
        var pagina = 3
        for (titolo, d) in parti {
            voci.append((titolo, pagina))
            pagina += d.pagine.count
        }
        let canali = Canale.allCases.filter { k in posizioniCliente(c.id).contains { $0.canale == k && $0.stato != .chiusa } }
        let ruolo = canali == [.alleanza] ? "Consulente Alleanza Assicurazioni" : (canali == [.indipendente] ? "Consulenza finanziaria" : "Alleanza Assicurazioni · consulenza finanziaria")
        // Per un appuntamento: la data e il tipo d'incontro
        let incontro = fascicoloAppuntamento.flatMap { id in appuntamenti.first { $0.id == id && $0.clienteId == c.id } }
        let data = incontro?.inizio ?? Date()
        let copertina = CopertinaReport(occhiello: "Fascicolo dell'incontro", titolo: "Il punto insieme",
                                        sottotitolo: incontro.map { "\($0.tipo.nome) del \(CifreDoc.data($0.inizio)): i documenti che abbiamo visto insieme" }
                                            ?? "I documenti che abbiamo visto oggi, in un solo fascicolo",
                                        nomi: c.nome, ruolo: ruolo, data: data, canali: canali.isEmpty ? [.indipendente] : canali,
                                        cartellini: [("Documenti", ["\(parti.count)"]), ("Pagine", ["\(pagina - 1)"])])
        let apertura = ImpaginaReport.pagine(copertina: AnyView(copertina), interne: [AnyView(IndiceFascicolo(voci: voci))],
                                             intestazione: "Fascicolo dell'incontro · \(c.nome)")
        // Il piede di ogni pagina conta dall'inizio del fascicolo, come l'indice
        let totalePagine = pagina - 1
        var tutte: [AnyView] = apertura.map {
            AnyView($0.environment(\.numerazioneFascicolo, NumerazioneFascicolo(scostamento: 0, totale: totalePagine)))
        }
        for (i, parte) in parti.enumerated() {
            let numerazione = NumerazioneFascicolo(scostamento: voci[i].1 - 1, totale: totalePagine)
            tutte += parte.1.pagine.map { AnyView($0.environment(\.numerazioneFascicolo, numerazione)) }
        }
        return DocumentoStampabile(report: Self.titoloFascicolo(data, conOra: incontro != nil), cliente: c.nome, pagine: tutte)
    }

    /// «Fascicolo dell'incontro del 28/10/2026 ore 10:00»: con data e ora dell'appuntamento l'archivio in Documenti
    /// tiene un fascicolo per incontro, anche con due incontri nello stesso giorno.
    static func titoloFascicolo(_ data: Date, conOra: Bool = true) -> String {
        "Fascicolo dell'incontro del \(CifreDoc.dataBreve(data))" + (conOra ? " ore \(Formati.ora.string(from: data))" : "")
    }

    /// Dall'Agenda: i report adatti all'appuntamento, già spuntati, nel fascicolo del cliente.
    func preparaFascicolo(per a: Appuntamento) {
        clienteAttivoId = a.clienteId
        sceltaFascicolo = TipoProspetto.perIncontro(a, posizione: a.posizioneId.flatMap { id in posizioni.first { $0.id == id } })
        fascicoloAppuntamento = a.id
        apriProspetto(.fascicolo)
    }

    /// Il fascicolo già archiviato nei Documenti del cliente per questo appuntamento.
    func fascicoloArchiviato(per a: Appuntamento) -> Documento? {
        let titolo = "Report · " + Self.titoloFascicolo(a.inizio)
        return dati.documenti.first { $0.clienteId == a.clienteId && $0.titolo == titolo }
    }
}

/// L'indice del fascicolo: ogni documento con la pagina da cui comincia.
struct IndiceFascicolo: View {
    @Environment(\.paletteDocumento) private var C
    let voci: [(String, Int)]

    /// Con molti documenti le righe si stringono, per restare nella pagina.
    private var fitto: Bool { voci.count > Misure.Documento.schedeReport + 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Indice", titolo: "Cosa trovi in questo fascicolo",
                        sottotitolo: "Ogni documento ha la sua copertina e le sue pagine; i numeri qui sotto contano dall'inizio del fascicolo.")
            VStack(spacing: 0) {
                ForEach(Array(voci.enumerated()), id: \.offset) { i, v in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(verbatim: String(format: "%02d", i + 1)).font(fitto ? T.titoloRiquadro : T.sintesiNumero).foregroundColor(C.occhiello).frame(width: 40, alignment: .leading)
                        Text(verbatim: v.0).font(T.titoloRiquadro).foregroundColor(C.titolo)
                        Spacer(minLength: 10)
                        Text(verbatim: "pagina \(v.1)").font(T.piccolo).foregroundColor(C.tenue)
                    }
                    .padding(.vertical, fitto ? 4 : 9)
                    Rectangle().fill(C.filetto).frame(height: 0.6)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .riquadroDoc()
            Spacer(minLength: 0)
        }
    }
}
