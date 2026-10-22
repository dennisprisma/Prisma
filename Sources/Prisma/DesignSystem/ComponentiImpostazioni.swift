import SwiftUI

/// Fondo a righe verticali di iOS 5 (--ios5-stripes delle Impostazioni).
struct FondoRighe: View {
    var body: some View {
        Materiale.Trama(nome: "Righe_ios5")
    }
}

/// Interruttore iOS 5 (.os-switch): blu con "I" quando acceso, grigio con "O" quando spento.
struct StileInterruttore: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let m = Misure.Impostazioni.interruttore
        let r = Misure.Impostazioni.raggioInterruttore
        let acceso = configuration.isOn
        return Button {
            withAnimation(Animazioni.passaggio) { configuration.isOn.toggle() }
        } label: {
            ZStack(alignment: acceso ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: r)
                    .fill(acceso ? AnyShapeStyle(Gradienti.interruttoreAcceso) : AnyShapeStyle(Gradienti.interruttoreSpento))
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [acceso ? Colori.Impostazioni.interruttoreAccesoOmbra : Colori.Impostazioni.interruttoreOmbra, .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: r))
                    }
                Text(acceso ? "I" : "O")
                    .font(Tipo.interruttore)
                    .foregroundColor(acceso ? .white : Colori.Impostazioni.interruttoreTestoSpento)
                    .incisione(acceso ? Colori.Pulsante.bluIncisione : .white, y: acceso ? -1 : 1)
                    .frame(width: m.width - m.height, height: m.height)
                    .frame(maxWidth: .infinity, alignment: acceso ? .leading : .trailing)
                // Cursore di vetro
                RoundedRectangle(cornerRadius: r)
                    .fill(Gradienti.vetro)
                    .overlay(RoundedRectangle(cornerRadius: r).strokeBorder(Colori.Impostazioni.interruttoreSpentoBordo, lineWidth: 1))
                    .frame(width: m.height + 2, height: m.height)
                    .ombraCSS(Colori.Impostazioni.interruttoreOmbra, y: 1, sfocatura: 2)
            }
            .frame(width: m.width, height: m.height)
            .clipShape(RoundedRectangle(cornerRadius: r))
            .overlay(
                RoundedRectangle(cornerRadius: r)
                    .strokeBorder(acceso ? Colori.Impostazioni.interruttoreAccesoBordo : Colori.Impostazioni.interruttoreSpentoBordo, lineWidth: 1)
            )
            .shadow(color: .white, radius: 0, x: 0, y: 1)
        }
        .buttonStyle(StileSemplice())
    }
}

/// Gruppo arrotondato bianco di righe (.os-settings-group).
struct GruppoImpostazioni<Contenuto: View>: View {
    var titolo: String? = nil
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let titolo {
                Text(titolo.uppercased())
                    .font(Tipo.intestazioneGruppo)
                    .foregroundColor(Colori.Impostazioni.intestazioneGruppo)
                    .incisione(.white)
                    .padding(.leading, 12)
            }
            VStack(spacing: 0) {
                contenuto()
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Misure.Impostazioni.raggioGruppo))
            .overlay(RoundedRectangle(cornerRadius: Misure.Impostazioni.raggioGruppo).strokeBorder(Colori.Impostazioni.gruppoBordo, lineWidth: 1))
            .shadow(color: Colori.Impostazioni.gruppoRiflesso, radius: 0, x: 0, y: 1)
        }
    }
}

/// Riga di un gruppo: titolo in grassetto, sottotitolo grigio, accessorio a destra.
struct RigaImpostazione<Accessorio: View>: View {
    let titolo: String
    var sottotitolo: String? = nil
    var avvertenza: String? = nil
    var ultima = false
    @ViewBuilder let accessorio: () -> Accessorio

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titolo)
                    .font(Tipo.rigaTitolo)
                    .foregroundColor(Colori.Impostazioni.rigaTitolo)
                if let sottotitolo {
                    Text(sottotitolo)
                        .font(Tipo.rigaSottotitolo)
                        .foregroundColor(Colori.Impostazioni.rigaSottotitolo)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let avvertenza {
                    Text(avvertenza)
                        .font(Tipo.rigaSottotitolo)
                        .foregroundColor(Colori.Impostazioni.avvertenza)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            accessorio()
        }
        .padding(Misure.Impostazioni.margineRiga)
        .frame(minHeight: Misure.Impostazioni.altezzaRiga)
        .overlay(alignment: .bottom) {
            if !ultima {
                Rectangle().fill(Colori.Impostazioni.rigaBordo).frame(height: 1)
            }
        }
    }
}

/// Valore azzurro con freccia a destra di una riga ("Denis ›").
struct ValoreRiga: View {
    let testo: String
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            Text("\(testo) ›")
                .font(Tipo.rigaValore)
                .foregroundColor(Colori.Impostazioni.rigaValore)
        }
        .buttonStyle(StileSemplice())
    }
}

/// Schede di un'app (.os-workspace-tabs): segmenti grafite a larghezza del testo.
struct SchedeApp<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(opzioni.enumerated()), id: \.offset) { indice, opzione in
                let attivo = opzione.0 == selezione
                Button {
                    selezione = opzione.0
                } label: {
                    Text(opzione.1)
                        .font(Tipo.schedaApp)
                        .foregroundColor(attivo ? .white : Colori.Impostazioni.segmentoTesto)
                        .incisione(attivo ? Colori.Impostazioni.segmentoAttivoIncisione : Colori.Barra.incisione, y: attivo ? -1 : 1)
                        .padding(.horizontal, Misure.Impostazioni.schedeMargine)
                        .frame(height: Misure.Impostazioni.schedeAltezza)
                        .background(attivo ? AnyShapeStyle(Gradienti.segmentoImpostazioni) : AnyShapeStyle(Gradienti.vetro))
                        .overlay(alignment: .top) {
                            if attivo {
                                LinearGradient(colors: [Color.black.opacity(0.33), .clear], startPoint: .top, endPoint: .bottom).frame(height: 3)
                            } else {
                                Rectangle().fill(Color.white).frame(height: 1)
                            }
                        }
                }
                .buttonStyle(StileSemplice())
                if indice < opzioni.count - 1 {
                    Rectangle().fill(Colori.Impostazioni.segmentoBordo).frame(width: 1, height: Misure.Impostazioni.schedeAltezza)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Misure.Colonna.schedeRaggio))
        .overlay(RoundedRectangle(cornerRadius: Misure.Colonna.schedeRaggio).strokeBorder(Colori.Impostazioni.segmentoBordo, lineWidth: 1))
        .fixedSize()
    }
}
