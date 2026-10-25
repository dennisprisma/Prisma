import SwiftUI

private typealias T = Tipo.Report

/// Il fascicolo dell'incontro: i report scelti per il cliente in un solo PDF, con una copertina,
/// un indice e la password del cliente come per ogni documento.
extension TipoProspetto {
    /// I report che possono entrare nel fascicolo, nell'ordine in cui si leggono.
    static let inFascicolo: [TipoProspetto] = [.checkUp, .resoconto, .patrimonio, .resistenza, .costi, .successione, .previdenza, .protezione, .liquidita]
    /// Quelli spuntati all'inizio: il quadro e le tre analisi nuove.
    static let fascicoloPredefinito: Set<TipoProspetto> = [.resoconto, .patrimonio, .resistenza, .costi, .successione]

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
        let ruolo = canali == [.alleanza] ? "Consulente Alleanza Assicurazioni" : (canali == [.indipendente] ? "Consulenza finanziaria" : "Consulente Alleanza Assicurazioni e consulenza finanziaria")
        let copertina = CopertinaReport(occhiello: "Fascicolo dell'incontro", titolo: "Il punto insieme",
                                        sottotitolo: "I documenti che abbiamo visto oggi, in un solo fascicolo",
                                        nomi: c.nome, ruolo: ruolo, data: Date(), canali: canali.isEmpty ? [.indipendente] : canali,
                                        cartellini: [("Documenti", ["\(parti.count)"]), ("Pagine", ["\(pagina - 1)"])])
        let apertura = ImpaginaReport.pagine(copertina: AnyView(copertina), interne: [AnyView(IndiceFascicolo(voci: voci))],
                                             intestazione: "Fascicolo dell'incontro · \(c.nome)")
        return DocumentoStampabile(report: "Fascicolo dell'incontro", cliente: c.nome, pagine: apertura + parti.flatMap(\.1.pagine))
    }
}

/// L'indice del fascicolo: ogni documento con la pagina da cui comincia.
struct IndiceFascicolo: View {
    @Environment(\.paletteDocumento) private var C
    let voci: [(String, Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Indice", titolo: "Cosa trovi in questo fascicolo",
                        sottotitolo: "Ogni documento ha la sua copertina e le sue pagine; i numeri qui sotto contano dall'inizio del fascicolo.")
            VStack(spacing: 0) {
                ForEach(Array(voci.enumerated()), id: \.offset) { i, v in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(verbatim: String(format: "%02d", i + 1)).font(T.sintesiNumero).foregroundColor(C.occhiello).frame(width: 40, alignment: .leading)
                        Text(verbatim: v.0).font(T.titoloRiquadro).foregroundColor(C.titolo)
                        Spacer(minLength: 10)
                        Text(verbatim: "pagina \(v.1)").font(T.piccolo).foregroundColor(C.tenue)
                    }
                    .padding(.vertical, 9)
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
