import SwiftUI

extension Tema.Misura.Componenti {
    /// Pulsante principale dell'intestazione ("Nuovo cliente") e pulsante piccolo ("Modifica").
    static let margineAqua = EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
    static let marginePiccolo = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
    /// Barra delle schede del dossier.
    static let barraSchedeDossier: CGFloat = 44
    static let margineSchedeDossier: CGFloat = 17
    /// Fila delle metriche e riga etichetta/valore.
    static let etichettaCampo: CGFloat = 150
    static let rigaCampo: CGFloat = 8
    /// Scheda di collegamento a un'app del dossier.
    static let schedaCollegata = EdgeInsets(top: 9, leading: 10, bottom: 9, trailing: 10)
    static let contatoreScheda: CGFloat = 20
}

/// Pulsante principale dell'intestazione ("Nuovo cliente"): capsula piena dell'accento.
struct StileAqua: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CorpoPulsante(etichetta: configuration.label, aspetto: .principale, premuto: configuration.isPressed,
                      margine: Tema.Misura.Componenti.margineAqua, altezza: Misure.Pulsante.altezzaAqua)
    }
}

/// Pulsante piccolo ("Modifica" del dossier): capsula di vetro.
struct StileCuoioChiaro: ButtonStyle {
    /// Altezza fissa, per affiancarlo a un pulsante principale (nil: quanto il testo più il margine).
    var altezza: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        CorpoPulsante(etichetta: configuration.label, aspetto: .vetro, premuto: configuration.isPressed,
                      margine: Tema.Misura.Componenti.marginePiccolo, altezza: altezza)
    }
}

/// Schede del dossier: controllo a segmenti del tema in una barra con il filo sotto.
struct SchedeRubrica<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore

    var body: some View {
        // Nelle finestre strette le schede si stringono e, se ancora non bastano, scorrono di lato:
        // mai una parola spezzata a metà.
        ViewThatFits(in: .horizontal) {
            riga(compatto: false)
            riga(compatto: true)
            ScrollView(.horizontal, showsIndicators: false) {
                riga(compatto: true)
            }
        }
        .padding(.horizontal, Tema.Misura.Componenti.margineSchedeDossier)
        .frame(height: Tema.Misura.Componenti.barraSchedeDossier)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
        }
    }

    private func riga(compatto: Bool) -> some View {
        HStack(spacing: 0) {
            ControlloSegmenti(opzioni: opzioni, selezione: $selezione, compatto: compatto)
                .fixedSize()
            Spacer(minLength: 0)
        }
    }
}

/// Occhiello di sezione del dossier ("Il quadro d'insieme").
struct OcchielloSezione: View {
    let titolo: String
    var nota: String? = nil

    var body: some View {
        HStack {
            Text(titolo)
                .font(Tema.Testo.occhiello)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
            Spacer()
            if let nota {
                Text(nota).font(Tema.Testo.didascalia).foregroundColor(Tema.Colore.inchiostroTerziario)
            }
        }
    }
}

/// Fila di metriche in tessere del tema (.tiles), tutte alte uguali.
struct FasciaMetriche: View {
    struct Metrica: Identifiable {
        let id = UUID()
        let etichetta: String
        let valore: String
        let nota: String
    }

    let metriche: [Metrica]

    var body: some View {
        HStack(alignment: .top, spacing: Tema.Misura.Componenti.spazioTessere) {
            ForEach(metriche) { m in
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.etichetta).font(Tema.Testo.secondario).foregroundColor(Tema.Colore.inchiostroSecondario)
                    Text(m.valore)
                        .font(Tema.Testo.valoreTessera)
                        .tracking(Tema.Testo.Componenti.spaziaturaValore)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(m.nota).font(Tema.Testo.didascalia).foregroundColor(Tema.Colore.inchiostroSecondario).lineLimit(1)
                }
                .padding(Tema.Misura.Componenti.tessera)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .vetro(.sottile, forma: .arrotondata(Tema.Raggio.tessera))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Riga etichetta/valore della scheda (anagrafica, profilo), come le coppie .kv del tema.
struct RigaCampo: View {
    let etichetta: String
    let valore: String
    var vuoto = "—"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(etichetta)
                .font(Tema.Testo.corpo)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .frame(width: Tema.Misura.Componenti.etichettaCampo, alignment: .leading)
            Text(valore.isEmpty ? vuoto : valore)
                .font(Tema.Testo.corpo)
                .foregroundColor(valore.isEmpty ? Tema.Colore.inchiostroTerziario : Tema.Colore.inchiostro)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Tema.Misura.Componenti.rigaCampo)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
        }
    }
}

/// Scheda di collegamento a un'app del dossier: tessera del tema, più chiara al passaggio del mouse.
struct SchedaAppCollegata: View {
    let app: AppPrisma
    let sottotitolo: String
    var conteggio: Int? = nil
    let azione: () -> Void

    var body: some View {
        let m = Tema.Misura.Componenti.self
        let forma = FormaVetro.arrotondata(Tema.Raggio.tessera)
        Button(action: azione) {
            HStack(spacing: 10) {
                IconaApp(app: app, lato: Misure.Rubrica.iconaApp)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.titolo).font(Tema.Testo.titolo).foregroundColor(Tema.Colore.inchiostro).lineLimit(1)
                    Text(sottotitolo).font(Tema.Testo.secondario).foregroundColor(Tema.Colore.inchiostroSecondario).lineLimit(1)
                }
                Spacer(minLength: 4)
                if let conteggio {
                    Text("\(conteggio)")
                        .font(Tema.Testo.chipPiccolo)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .frame(minWidth: m.contatoreScheda, minHeight: m.contatoreScheda)
                        .background { FormaVetro.capsula.fill(Tema.Colore.pozzetto) }
                }
            }
            .padding(m.schedaCollegata)
            .frame(maxWidth: .infinity)
            .fondoPassaggio(forma, sopra: Tema.Colore.chip)
            .vetro(.sottile, forma: forma)
            .contentShape(forma)
        }
        .buttonStyle(StileSemplice())
    }
}
