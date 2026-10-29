import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

// I pezzi comuni dei prospetti per il consulente (A4 verticale, tavolozza moderna): foglio con il logo
// e il piede, titoli di sezione, riquadri con la barra, cifre in evidenza, firme.

/// Margini, logo piccolo in alto a destra (nel margine, fuori dall'impaginazione) e piè di pagina del prospetto.
struct FoglioProspetto<Contenuto: View>: View {
    @Environment(\.paletteDocumento) private var C
    let piede: String
    let avvertenza: String
    let numero: Int
    let totale: Int
    @ViewBuilder let contenuto: () -> Contenuto

    /// Larghezza utile della pagina.
    static var larghezza: CGFloat { D.prospetto.width - D.margineProspetto * 2 }

    var body: some View {
        FoglioDocumento(formato: D.prospetto) {
            VStack(alignment: .leading, spacing: 0) {
                contenuto()
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    Rectangle().fill(C.filetto).frame(height: 0.6)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: piede)
                            Text(verbatim: avvertenza)
                        }
                        Spacer()
                        Text(verbatim: "pag. \(numero) di \(totale)")
                    }
                    .font(T.pPiede).foregroundColor(C.tenue)
                }
            }
            .padding(EdgeInsets(top: 34, leading: D.margineProspetto, bottom: 22, trailing: D.margineProspetto))
            .overlay(alignment: .topTrailing) {
                LogoPrismaConNome(colore: Colori.Documento.logo, altezza: D.logoProspetto)
                    .padding(.top, D.logoProspettoAlto)
                    .padding(.trailing, D.margineProspetto)
            }
        }
    }
}

/// Titolo di sezione con il paragrafo sotto.
struct SezioneProspetto: View {
    @Environment(\.paletteDocumento) private var C
    let titolo: String
    var testo: Text? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: titolo).font(T.pSezione).foregroundColor(C.titolo)
            if let testo {
                testo.font(T.pCorpo).foregroundColor(C.tenue).lineSpacing(1.6).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Riquadro con la barra blu a sinistra ("In sintesi", "Se il bisogno di liquidità è probabile").
struct RiquadroBarra<Contenuto: View>: View {
    @Environment(\.paletteDocumento) private var C
    let titolo: String
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: titolo).font(T.pSezione).foregroundColor(C.titolo)
            contenuto()
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.evidenza)
        .overlay(Rectangle().fill(C.barraLaterale).frame(width: 3), alignment: .leading)
    }
}

struct PuntoElenco: View {
    @Environment(\.paletteDocumento) private var C
    let testo: Text

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Text(verbatim: "•").font(T.pCorpoForte)
            testo.font(T.pCorpo).lineSpacing(1.6).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(C.testo)
    }
}

/// Una fila di cifre in evidenza alte uguali: se una nota va su due righe, le schede accanto la seguono.
/// Senza la fila (un `HStack` qualunque) ogni scheda resta alta quanto il suo testo.
struct FilaCifre<Contenuto: View>: View {
    var spazio: CGFloat = D.spazioCifre
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        HStack(spacing: spazio) { contenuto() }
            .environment(\.cifreAltezzaPiena, true)
            // L'altezza della fila è quella della scheda più alta, non lo spazio libero della pagina
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ChiaveCifreAltezzaPiena: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Dentro `FilaCifre` le schede prendono l'altezza della fila.
    var cifreAltezzaPiena: Bool {
        get { self[ChiaveCifreAltezzaPiena.self] }
        set { self[ChiaveCifreAltezzaPiena.self] = newValue }
    }
}

/// Una cifra in evidenza: etichetta, valore, nota (fino a due righe, sempre allo stesso corpo).
struct CifraProspetto: View {
    @Environment(\.paletteDocumento) private var C
    @Environment(\.cifreAltezzaPiena) private var altezzaPiena
    let etichetta: String
    let valore: String
    let nota: String
    var colore: Color? = nil

    init(_ etichetta: String, _ valore: String, _ nota: String, colore: Color? = nil) {
        self.etichetta = etichetta
        self.valore = valore
        self.nota = nota
        self.colore = colore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: etichetta).font(T.pKpiEtichetta).foregroundColor(C.tenue).lineLimit(1).minimumScaleFactor(0.8)
            Text(verbatim: valore).font(T.pKpiValore).foregroundColor(colore ?? C.titolo).lineLimit(1).minimumScaleFactor(0.7)
            // La nota va a capo invece di rimpicciolirsi o troncarsi
            Text(verbatim: nota).font(T.pKpiNota).foregroundColor(C.tenue).lineLimit(D.righeNotaCifra)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: altezzaPiena ? CGFloat.infinity : nil, alignment: .topLeading)
        .riquadroDoc(C.riquadro, raggio: D.raggioPiccolo)
    }
}

/// Riga di intestazione compilata: "Cliente ____ Consulente ____ Data ____".
struct CampoProspetto: View {
    @Environment(\.paletteDocumento) private var C
    let etichetta: String
    let valore: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Text(verbatim: etichetta).font(T.pTabellaNota).foregroundColor(C.tenue)
            VStack(spacing: 2) {
                Text(verbatim: valore).font(T.pCorpo).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.7)
                Rectangle().fill(C.tenue).frame(height: 0.5)
            }
        }
    }
}

/// Le firme in fondo al prospetto: "Per presa visione · Cliente ____ · Consulente ____".
struct FirmeProspetto: View {
    @Environment(\.paletteDocumento) private var C

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            etichetta("Per presa visione", 92)
            etichetta("Cliente", 40)
            linea
            Spacer(minLength: 0)
            etichetta("Consulente", 56)
            linea
        }
        .frame(width: FoglioProspetto<EmptyView>.larghezza)
        .padding(.top, 14)
    }

    private func etichetta(_ testo: String, _ larghezza: CGFloat) -> some View {
        Text(verbatim: testo).font(T.pTabellaNota).foregroundColor(C.tenue).lineLimit(1).fixedSize()
            .frame(width: larghezza, alignment: .leading)
    }

    private var linea: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle().fill(C.tenue).frame(height: 0.8)
        }
        .frame(width: 145, height: 14)
    }
}

/// Le righe di un canale, sotto la sua etichetta (blu Alleanza, cuoio indipendente).
struct GruppoCanale {
    let canale: Canale
    let righe: [RigaDoc]
    var nota = ""
}

/// Una tabella divisa per canale: l'etichetta del canale, poi le sue righe.
struct TabellaCanali: View {
    @Environment(\.paletteDocumento) private var C
    let colonne: [ColonnaDoc]
    let gruppi: [GruppoCanale]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(gruppi.enumerated()), id: \.offset) { _, g in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center) {
                        EtichettaCanale(canale: g.canale)
                        Spacer()
                        Text(verbatim: g.nota).font(T.pTabellaNota).foregroundColor(C.tenue)
                    }
                    TabellaDoc(larghezza: FoglioProspetto<EmptyView>.larghezza, colonne: colonne, righe: g.righe, fontTesta: T.pTabellaTesta,
                               fontTestaSotto: T.pTabellaNota, altezzaTesta: 12, margine: 4)
                }
            }
        }
    }
}
