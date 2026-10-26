import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

// La veste comune dei report per i clienti (A4 orizzontale), nell'identità di Prisma: copertina in
// cuoio come il dossier del cliente, pagine di carta avorio come le slide di Presentazioni del
// template, testata ◈ PRISMA, capitoli numerati, piede con il motto.

/// Mette in fila copertina e pagine interne: numera le pagine e applica la tavolozza di Prisma.
enum ImpaginaReport {
    static func pagine(copertina: AnyView, interne: [AnyView], intestazione: String, lettera: LetteraConsulente? = nil) -> [AnyView] {
        // La lettera del consulente, se c'è, apre il report subito dopo la copertina
        let interne = (lettera.map { [AnyView($0)] } ?? []) + interne
        let totale = interne.count + 1
        let numerate = interne.enumerated().map { i, s in
            AnyView(CorniceReport(intestazione: intestazione, numero: i + 2, totale: totale) { s })
        }
        return ([copertina] + numerate).map {
            AnyView($0.environment(\.paletteDocumento, Colori.Documento.prisma))
        }
    }
}

private struct ChiaveNumeroPaginaReport: EnvironmentKey {
    static let defaultValue = 1
}

extension EnvironmentValues {
    /// Numero della pagina del report, per il capitolo ("05 —").
    var numeroPaginaReport: Int {
        get { self[ChiaveNumeroPaginaReport.self] }
        set { self[ChiaveNumeroPaginaReport.self] = newValue }
    }
}

/// La cornice di una pagina interna, come le slide di Presentazioni del template: testata con il
/// marchio e l'intestazione, carta avorio nei suoi toni, filigrana ◈, piede con il motto e il numero.
struct CorniceReport<Contenuto: View>: View {
    @Environment(\.paletteDocumento) private var C
    let intestazione: String
    let numero: Int
    let totale: Int
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        let tono = Colori.Documento.toniReport[numero % Colori.Documento.toniReport.count]
        FoglioDocumento(formato: D.report, sfondo: tono.0) {
            ZStack(alignment: .bottomTrailing) {
                RadialGradient(colors: [tono.0, tono.1], center: UnitPoint(x: 0.1, y: 0.05), startRadius: 0, endRadius: D.report.width)
                if numero % 4 == 0 {
                    Text(verbatim: "◈").font(T.filigrana).foregroundColor(C.marchio.opacity(0.06))
                        .padding(.trailing, 30).padding(.bottom, 20)
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        Text(verbatim: "◈ PRISMA").font(T.marchio).tracking(3).foregroundColor(C.marchio)
                        Spacer()
                        Text(verbatim: intestazione.uppercased()).font(T.testata).tracking(1.6)
                            .foregroundColor(C.tenue).lineLimit(1)
                    }
                    .padding(.bottom, 9)
                    .overlay(Rectangle().fill(C.filetto).frame(height: 0.8), alignment: .bottom)
                    contenuto()
                        .padding(.top, 14)
                        .environment(\.numeroPaginaReport, numero)
                    Spacer(minLength: 0)
                    HStack {
                        Text(verbatim: "PERSONE. PRIORITÀ. PROSPETTIVE.")
                        Spacer()
                        Text(verbatim: "\(numero) / \(totale)")
                    }
                    .font(T.piede).tracking(1.5).foregroundColor(C.tenue)
                    .padding(.top, 7)
                    .overlay(Rectangle().fill(C.filetto).frame(height: 0.8), alignment: .top)
                }
                .padding(EdgeInsets(top: 22, leading: D.margineReport, bottom: 14, trailing: D.margineReport))
            }
        }
    }
}

/// Capitolo, titolo che dice la conclusione e sottotitolo (.slides-chapter, .slides-stage h2).
struct TestaReport: View {
    @Environment(\.paletteDocumento) private var C
    @Environment(\.numeroPaginaReport) private var numero
    let occhiello: String
    let titolo: String
    var sottotitolo: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Text(verbatim: String(format: "%02d", numero)).font(T.capitolo)
                Rectangle().fill(C.filetto).frame(width: 25, height: 1)
                Text(verbatim: occhiello.uppercased()).font(T.capitolo).tracking(1.9)
            }
            .foregroundColor(C.occhiello)
            Text(verbatim: titolo).font(T.titoloSlide).tracking(-0.4).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.7)
            if let sottotitolo, !sottotitolo.isEmpty {
                Text(verbatim: sottotitolo).font(T.sottotitoloSlide).foregroundColor(C.tenue)
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Copertina in cuoio come il dossier del cliente: impuntura, marchio impresso, cartellini di carta,
/// il consulente con le etichette dei canali.
struct CopertinaReport: View {
    @Environment(\.paletteDocumento) private var C
    let occhiello: String
    let titolo: String
    let sottotitolo: String
    let nomi: String
    let ruolo: String
    let data: Date
    let canali: [Canale]
    let cartellini: [(String, [String])]

    var body: some View {
        FoglioDocumento(formato: D.report, sfondo: C.copertina) {
            ZStack {
                Materiale.Pelle()
                    .frame(width: D.report.width, height: D.report.height)
                    .clipped()
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(C.cucitura.opacity(0.6), style: StrokeStyle(lineWidth: 1.3, dash: [6, 4]))
                    .padding(18)
                HStack(alignment: .center, spacing: 36) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            Text(verbatim: "◈").font(T.copertinaMarchio)
                            Text(verbatim: "PRISMA").font(T.copertinaMarchio).tracking(4)
                        }
                        .foregroundColor(C.copertinaTesto)
                        .shadow(color: Color.black.opacity(0.45), radius: 0, x: 0, y: -1)
                        Spacer(minLength: 0)
                        OcchielloDoc(testo: occhiello, font: T.copertinaOcchiello, colore: C.copertinaTesto.opacity(0.75))
                        Text(verbatim: titolo).font(T.copertinaTitolo).foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.4), radius: 0, x: 0, y: -1)
                            .lineLimit(3).minimumScaleFactor(0.7).padding(.top, 12)
                        // Larghezza limitata: le righe del sottotitolo vanno a capo bilanciate
                        Text(verbatim: sottotitolo).font(T.copertinaSottotitolo).italic().foregroundColor(C.copertinaTesto)
                            .frame(maxWidth: 440, alignment: .leading)
                            .padding(.top, 10)
                        Text(verbatim: nomi).font(T.copertinaNomi).foregroundColor(.white).padding(.top, 22)
                        Spacer(minLength: 0)
                        HStack(alignment: .bottom, spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: TestiValutazione.consulente).font(T.copertinaConsulente).foregroundColor(.white)
                                Text(verbatim: ruolo).font(T.copertinaRuolo).foregroundColor(C.copertinaTesto)
                                    .fixedSize(horizontal: true, vertical: false)
                                Text(verbatim: CifreDoc.data(data)).font(T.copertinaRuolo).foregroundColor(C.copertinaTesto)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(canali, id: \.self) { EtichettaCanale(canale: $0) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    VStack(spacing: 12) {
                        ForEach(Array(cartellini.enumerated()), id: \.offset) { _, c in cartellino(c.0, c.1) }
                    }
                    .frame(width: 240)
                }
                .padding(EdgeInsets(top: 52, leading: 56, bottom: 50, trailing: 56))
            }
        }
    }

    /// Cartellino di carta avorio sul cuoio.
    private func cartellino(_ titolo: String, _ righe: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            OcchielloDoc(testo: titolo, font: T.copertinaEtichetta, colore: C.copertinaEtichetta)
            ForEach(righe, id: \.self) { Text(verbatim: $0).font(T.copertinaValore).foregroundColor(C.titolo) }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        // L'ombra va solo al cartoncino, non alle scritte
        .background(RoundedRectangle(cornerRadius: 4).fill(C.copertinaRiquadro)
            .shadow(color: C.ombraCartellino, radius: 3, x: 0, y: 2))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(C.ombraCartellino, lineWidth: 0.8))
    }
}

/// La lettera del consulente al cliente, dopo la copertina: il commento scritto con Eve e riletto
/// dal consulente, con la firma.
struct LetteraConsulente: View {
    @Environment(\.paletteDocumento) private var C
    let testo: String
    let ruolo: String
    let data: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Il commento del consulente", titolo: "Due parole per te")
            HStack(alignment: .top, spacing: 22) {
                Text(verbatim: testo)
                    .font(T.lettera).foregroundColor(C.titolo).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .riquadroDoc()
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: TestiValutazione.consulente).font(T.letteraFirma).foregroundColor(C.titolo)
                    Rectangle().fill(C.filetto).frame(width: 150, height: 0.8)
                    Text(verbatim: ruolo).font(T.piccolo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: CifreDoc.data(data)).font(T.piccolo).foregroundColor(C.tenue)
                }
                .padding(.top, 18)
                .frame(width: 190, alignment: .topLeading)
            }
            Spacer(minLength: 0)
        }
    }
}
