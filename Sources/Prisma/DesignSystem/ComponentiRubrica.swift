import SwiftUI

/// Pulsante principale aqua dell'intestazione ("Nuovo cliente").
struct StileAqua: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tipo.pulsanteAqua)
            .foregroundColor(Colori.Rubrica.aquaTesto)
            .incisione(Colori.Rubrica.aquaIncisione)
            .padding(.horizontal, 12)
            .frame(height: Misure.Pulsante.altezzaAqua)
            .background(RoundedRectangle(cornerRadius: Misure.Pulsante.raggioBlu).fill(Gradienti.aqua))
            .luceInterna(Colori.Rubrica.aquaLuce, raggio: Misure.Pulsante.raggioBlu)
            .overlay(RoundedRectangle(cornerRadius: Misure.Pulsante.raggioBlu).strokeBorder(Colori.Rubrica.aquaBordo, lineWidth: 1))
            .brightness(configuration.isPressed ? -0.08 : 0)
            .contentShape(Rectangle())
    }
}

/// Pulsante piccolo in cuoio chiaro ("Modifica" del dossier).
struct StileCuoioChiaro: ButtonStyle {
    /// Altezza fissa, per affiancarlo a un pulsante aqua (nil: quanto il testo più il margine).
    var altezza: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tipo.pulsanteCuoio)
            .foregroundColor(Colori.Rubrica.pulsanteTesto)
            .incisione(Colori.Rubrica.pulsanteIncisione)
            .padding(.horizontal, 9)
            .padding(.vertical, altezza == nil ? 5 : 0)
            .frame(height: altezza)
            .background(RoundedRectangle(cornerRadius: Misure.Pulsante.raggio).fill(Gradienti.pulsanteCuoio))
            .luceInterna(Colori.Rubrica.pulsanteLuce, raggio: Misure.Pulsante.raggio)
            .overlay(RoundedRectangle(cornerRadius: Misure.Pulsante.raggio).strokeBorder(Colori.Rubrica.pulsanteBordo, lineWidth: 1))
            .brightness(configuration.isPressed ? -0.08 : 0)
            .contentShape(Rectangle())
    }
}

/// Schede del dossier in cuoio (.clients-tabs).
struct SchedeRubrica<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore

    var body: some View {
        // Nelle finestre strette le schede si stringono (come il template sotto i 700 px)
        // e, se ancora non bastano, scorrono di lato: mai una parola spezzata a metà.
        ViewThatFits(in: .horizontal) {
            riga(spazio: Misure.Rubrica.spazioSchede, margine: Misure.Rubrica.schedaMargine, font: Tipo.schedaRubrica)
            riga(spazio: Misure.Rubrica.spazioSchedeStretto, margine: Misure.Rubrica.schedaMargineStretto, font: Tipo.schedaRubricaStretta)
            ScrollView(.horizontal, showsIndicators: false) {
                riga(spazio: Misure.Rubrica.spazioSchedeStretto, margine: Misure.Rubrica.schedaMargineStretto, font: Tipo.schedaRubricaStretta)
            }
        }
        .padding(.horizontal, 17)
        .frame(height: Misure.Rubrica.schedaAltezza + 1)
        .background(Gradienti.schedeRubrica)
        .luceInterna(Colori.Rubrica.schedeLuce)
        .bordoBasso(Colori.Rubrica.schedeBordo)
    }

    private func riga(spazio: CGFloat, margine: CGFloat, font: Font) -> some View {
        HStack(spacing: spazio) {
            ForEach(Array(opzioni.enumerated()), id: \.offset) { _, opzione in
                scheda(opzione, margine: margine, font: font)
            }
            Spacer(minLength: 0)
        }
    }

    private func scheda(_ opzione: (Valore, String), margine: CGFloat, font: Font) -> some View {
        let attiva = opzione.0 == selezione
        return Button {
            selezione = opzione.0
        } label: {
            Text(opzione.1)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .foregroundColor(attiva ? Colori.Rubrica.schedaAttivaTesto : Colori.Rubrica.schedaTesto)
                .incisione(attiva ? Colori.Rubrica.schedaAttivaIncisione : Color.white.opacity(0.4))
                .padding(.horizontal, margine)
                .frame(height: Misure.Rubrica.schedaAltezza)
                .background(
                    RoundedRectangle(cornerRadius: Misure.Pulsante.raggio)
                        .fill(attiva ? Gradienti.schedaRubricaAttiva : Gradienti.schedaRubrica)
                )
                .overlay(alignment: .top) {
                    if attiva {
                        LinearGradient(colors: [Colori.Rubrica.schedaAttivaOmbra, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: Misure.Pulsante.raggio))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Misure.Pulsante.raggio)
                        .strokeBorder(attiva ? Colori.Rubrica.schedaAttivaBordo : Colori.Rubrica.schedaBordo, lineWidth: 1)
                )
        }
        .buttonStyle(StileSemplice())
    }
}

/// Occhiello di sezione del dossier ("IL QUADRO D'INSIEME").
struct OcchielloSezione: View {
    let titolo: String
    var nota: String? = nil

    var body: some View {
        HStack {
            Text(titolo.uppercased())
                .font(Tipo.sezioneOcchiello)
                .tracking(0.4)
                .foregroundColor(Colori.Rubrica.occhiello)
                .incisione(Color.white.opacity(0.53))
            Spacer()
            if let nota {
                Text(nota).font(Tipo.sezioneSottile).foregroundColor(Colori.Rubrica.sottile)
            }
        }
    }
}

/// Fascia di metriche con filetti sopra e sotto (.clients-metrics).
struct FasciaMetriche: View {
    struct Metrica: Identifiable {
        let id = UUID()
        let etichetta: String
        let valore: String
        let nota: String
    }

    let metriche: [Metrica]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(metriche.enumerated()), id: \.element.id) { i, m in
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.etichetta).font(Tipo.metricaEtichetta).foregroundColor(Colori.Rubrica.metricaEtichetta)
                    Text(m.valore)
                        .font(Tipo.metricaValore)
                        .tracking(-0.8)
                        .foregroundColor(Colori.Rubrica.metricaValore)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(m.nota).font(Tipo.metricaEtichetta).foregroundColor(Colori.Rubrica.metricaNota).lineLimit(1)
                }
                .padding(.leading, i == 0 ? 0 : 18)
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    if i > 0 { Rectangle().fill(Colori.Rubrica.filo).frame(width: 1) }
                }
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                Rectangle().fill(Colori.Rubrica.filo).frame(height: 1)
                Rectangle().fill(Color.white).frame(height: 1)
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(Colori.Rubrica.filo).frame(height: 1)
                Rectangle().fill(Color.white).frame(height: 1)
            }
        }
    }
}

/// Riga etichetta/valore della scheda (anagrafica, profilo).
struct RigaCampo: View {
    let etichetta: String
    let valore: String
    var vuoto = "—"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(etichetta)
                .font(Tipo.campoEtichetta)
                .foregroundColor(Colori.Rubrica.secondario)
                .frame(width: 150, alignment: .leading)
            Text(valore.isEmpty ? vuoto : valore)
                .font(Tipo.campoValore)
                .foregroundColor(valore.isEmpty ? Colori.Rubrica.secondario : Colori.Rubrica.testo)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 9)
        .bordoBasso(Colori.Rubrica.filo)
    }
}

/// Scheda di collegamento a un'app del dossier (.clients-app-link).
struct SchedaAppCollegata: View {
    let app: AppPrisma
    let sottotitolo: String
    var conteggio: Int? = nil
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 10) {
                IconaApp(app: app, lato: Misure.Rubrica.iconaApp)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.titolo).font(Tipo.schedaAppTitolo).foregroundColor(Colori.Rubrica.testo).lineLimit(1)
                    Text(sottotitolo).font(Tipo.rubricaTema).foregroundColor(Colori.Rubrica.secondario).lineLimit(1)
                }
                Spacer(minLength: 4)
                if let conteggio {
                    Text("\(conteggio)")
                        .font(Tipo.rigaSecondario)
                        .foregroundColor(Colori.Rubrica.conteggioTesto)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(Colori.Rubrica.conteggio))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 3).fill(Gradienti.schedaApp))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Rubrica.schedaAppBordo, lineWidth: 1))
        }
        .buttonStyle(StileSemplice())
    }
}
