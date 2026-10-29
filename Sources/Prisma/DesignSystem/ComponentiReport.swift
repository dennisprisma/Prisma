import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

// La veste comune dei report per i clienti (A4 orizzontale), nell'identità di Prisma: copertina blu
// notte con il logo bianco, pagine di carta avorio come le slide di Presentazioni, testata con il logo,
// capitoli numerati, piede con il motto. Colori fissi: il report resta chiaro anche con l'app in scuro.

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

/// La numerazione di un report dentro il fascicolo: le sue pagine contano dall'inizio del fascicolo.
struct NumerazioneFascicolo {
    /// Pagine del fascicolo prima della copertina del report.
    let scostamento: Int
    /// Pagine dell'intero fascicolo.
    let totale: Int
}

private struct ChiaveDocumentoInSala: EnvironmentKey {
    static let defaultValue = false
}

private struct ChiaveNumerazioneFascicolo: EnvironmentKey {
    static let defaultValue: NumerazioneFascicolo? = nil
}

extension EnvironmentValues {
    /// Numero della pagina del report, per il capitolo ("05 —").
    var numeroPaginaReport: Int {
        get { self[ChiaveNumeroPaginaReport.self] }
        set { self[ChiaveNumeroPaginaReport.self] = newValue }
    }

    /// Il documento mostrato nella sala della presentazione: le etichette piccole crescono e scuriscono.
    /// Nel PDF resta false.
    var documentoInSala: Bool {
        get { self[ChiaveDocumentoInSala.self] }
        set { self[ChiaveDocumentoInSala.self] = newValue }
    }

    /// Dentro il fascicolo il piede stampa la pagina del fascicolo («13 / 24»), come l'indice; fuori è nil.
    var numerazioneFascicolo: NumerazioneFascicolo? {
        get { self[ChiaveNumerazioneFascicolo.self] }
        set { self[ChiaveNumerazioneFascicolo.self] = newValue }
    }
}

/// La cornice di una pagina interna, come le slide di Presentazioni del template: testata con il
/// logo e l'intestazione, carta avorio nei suoi toni, logo in filigrana, piede con il motto e il numero.
struct CorniceReport<Contenuto: View>: View {
    @Environment(\.paletteDocumento) private var C
    @Environment(\.numerazioneFascicolo) private var fascicolo
    @Environment(\.documentoInSala) private var inSala
    let intestazione: String
    let numero: Int
    let totale: Int
    @ViewBuilder let contenuto: () -> Contenuto

    /// «4 / 10» nel report, «13 / 24» dentro il fascicolo.
    private var numerazione: String {
        guard let f = fascicolo else { return "\(numero) / \(totale)" }
        return "\(numero + f.scostamento) / \(f.totale)"
    }

    var body: some View {
        let tono = Colori.Documento.toniReport[numero % Colori.Documento.toniReport.count]
        FoglioDocumento(formato: D.report, sfondo: tono.0) {
            ZStack(alignment: .bottomTrailing) {
                RadialGradient(colors: [tono.0, tono.1], center: UnitPoint(x: 0.1, y: 0.05), startRadius: 0, endRadius: D.report.width)
                if numero % 4 == 0 {
                    LogoPrisma(colore: Colori.Documento.logo)
                        .frame(height: D.logoFiligrana)
                        .opacity(Colori.Documento.filigrana)
                        .padding(.trailing, 30).padding(.bottom, 26)
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        LogoPrismaConNome(colore: Colori.Documento.logo, altezza: D.logoReport)
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
                        Text(verbatim: numerazione)
                    }
                    .font(inSala ? T.piedeSala : T.piede).tracking(1.5).foregroundColor(inSala ? C.testo : C.tenue)
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

/// Copertina blu notte del tema (#0F2433 → #1E3A4F): logo bianco, titolo, cartellini bianchi,
/// il consulente con le etichette dei canali (opache, da stampa).
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
                LinearGradient(colors: [C.copertina, C.copertinaFine], startPoint: .topLeading, endPoint: .bottomTrailing)
                // Il logo grande in filigrana, in basso a destra, tagliato dal bordo del foglio
                LogoPrisma(colore: Colori.Documento.logoCopertina)
                    .frame(height: D.logoCopertinaFiligrana)
                    .opacity(Colori.Documento.filigranaCopertina)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: D.logoCopertinaFiligrana * 0.18, y: D.logoCopertinaFiligrana * 0.16)
                RoundedRectangle(cornerRadius: D.copertinaRaggio)
                    .strokeBorder(C.copertinaFilo, lineWidth: 0.8)
                    .padding(D.copertinaCornice)
                HStack(alignment: .center, spacing: 36) {
                    VStack(alignment: .leading, spacing: 0) {
                        LogoPrismaConNome(colore: Colori.Documento.logoCopertina, altezza: D.logoCopertina)
                        Spacer(minLength: 0)
                        OcchielloDoc(testo: occhiello, font: T.copertinaOcchiello, colore: C.copertinaTesto)
                        Text(verbatim: titolo).font(T.copertinaTitolo).foregroundColor(.white)
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

    /// Cartellino bianco sul blu notte.
    private func cartellino(_ titolo: String, _ righe: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            OcchielloDoc(testo: titolo, font: T.copertinaEtichetta, colore: C.copertinaEtichetta)
            ForEach(righe, id: \.self) { Text(verbatim: $0).font(T.copertinaValore).foregroundColor(C.titolo) }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        // L'ombra va solo al cartoncino, non alle scritte
        .background(RoundedRectangle(cornerRadius: D.cartellinoRaggio).fill(C.copertinaRiquadro)
            .shadow(color: C.ombraCartellino, radius: D.cartellinoOmbra, x: 0, y: D.cartellinoOmbraY))
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
