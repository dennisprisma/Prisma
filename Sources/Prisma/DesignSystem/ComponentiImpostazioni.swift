import SwiftUI

extension Tema.Misura.Componenti {
    /// Riga di un gruppo delle impostazioni (.g-row): margini e altezza minima.
    static let margineRiga = EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14)
    static let altezzaRiga: CGFloat = 46
    /// Rientro del titolo di un gruppo (.g-title).
    static let rientroTitoloGruppo: CGFloat = 6
}

extension Tema.Testo.Componenti {
    /// Titolo di un gruppo delle impostazioni (.g-title: 12/600).
    static let titoloGruppo = Tema.Testo.sf(12, .semibold)
    /// Freccia a destra del valore di una riga.
    static let frecciaRiga = Tema.Testo.sf(11, .semibold)
}

/// Fondo delle Impostazioni: nessuna trama, si vede il vetro della finestra.
struct FondoRighe: View {
    var body: some View {
        Color.clear
    }
}

/// Interruttore del tema (.tg): capsula 44 × 26, verde se acceso, pomello bianco che scorre a molla.
/// Si anima solo l'interruttore, non ciò che compare o sparisce con lui.
struct StileInterruttore: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let m = Tema.Misura.interruttore
        let p = Tema.Misura.pomello
        let acceso = configuration.isOn
        return Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: acceso ? .trailing : .leading) {
                FormaVetro.capsula.fill(acceso ? Tema.Colore.verde : Tema.Colore.pozzettoScuro)
                Circle()
                    .fill(Tema.Colore.pomello)
                    .overlay { Circle().strokeBorder(Tema.Colore.Componenti.bordoPomello, lineWidth: Tema.Misura.filo) }
                    .frame(width: p, height: p)
                    .ombraTema(Tema.Ombra.pomello)
                    .padding((m.height - p) / 2)
            }
            .animation(Movimenti.curva(Tema.Moto.Controlli.interruttore), value: acceso)
            .frame(width: m.width, height: m.height)
            .contentShape(FormaVetro.capsula)
        }
        .buttonStyle(StileSemplice())
    }
}

/// Gruppo di righe delle impostazioni (.group): scheda arrotondata del tema, titolo sopra.
struct GruppoImpostazioni<Contenuto: View>: View {
    var titolo: String? = nil
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        let forma = FormaVetro.arrotondata(Tema.Raggio.gruppo)
        VStack(alignment: .leading, spacing: 6) {
            if let titolo {
                Text(titolo)
                    .font(Tema.Testo.Componenti.titoloGruppo)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .padding(.leading, Tema.Misura.Componenti.rientroTitoloGruppo)
            }
            VStack(spacing: 0) {
                contenuto()
            }
            .clipShape(forma)
            .vetro(.sottile, forma: forma)
        }
    }
}

/// Riga di un gruppo: titolo, sottotitolo secondario, accessorio a destra, separatore sottile.
struct RigaImpostazione<Accessorio: View>: View {
    let titolo: String
    var sottotitolo: String? = nil
    var avvertenza: String? = nil
    var ultima = false
    @ViewBuilder let accessorio: () -> Accessorio

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(Tema.Testo.Componenti.voce)
                    .foregroundColor(Tema.Colore.inchiostro)
                if let sottotitolo {
                    Text(sottotitolo)
                        .font(Tema.Testo.secondario)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let avvertenza {
                    Text(avvertenza)
                        .font(Tema.Testo.secondario)
                        .foregroundColor(Tema.Colore.scadenzaOra)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            accessorio()
        }
        .padding(Tema.Misura.Componenti.margineRiga)
        .frame(minHeight: Tema.Misura.Componenti.altezzaRiga)
        .overlay(alignment: .bottom) {
            if !ultima {
                Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
            }
        }
    }
}

/// Valore a destra di una riga, con la freccia ("Denis ›").
struct ValoreRiga: View {
    let testo: String
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 5) {
                Text(testo)
                    .font(Tema.Testo.corpo)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                Image(systemName: "chevron.right")
                    .font(Tema.Testo.Componenti.frecciaRiga)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }
}

/// Schede di un'app: controllo a segmenti del tema, largo quanto i testi. Se lo spazio non basta, la
/// versione compatta: mai una parola tagliata.
struct SchedeApp<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ControlloSegmenti(opzioni: opzioni, selezione: $selezione)
                .fixedSize()
            ControlloSegmenti(opzioni: opzioni, selezione: $selezione, compatto: true)
                .fixedSize()
        }
    }
}
