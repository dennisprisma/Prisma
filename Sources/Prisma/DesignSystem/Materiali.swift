import SwiftUI

/// Superfici di fondo. Nel tema «Liquid Glass» le vecchie trame (grana, lino, righe, pelle) non si
/// disegnano più: i nomi restano per i chiamanti, e lo sfondo della scrivania è l'acqua.
enum Materiale {
    /// Ex trama ripetuta (grana, lino, righe): sotto resta il vetro della finestra.
    struct Trama: View {
        let nome: String

        var body: some View {
            Color.clear
        }
    }

    /// Ex pelle: niente superficie propria. Sullo schermo resta il vetro del widget;
    /// nella copertina del report (PDF) si vede il colore pieno della carta, che è fisso.
    struct Pelle: View {
        var body: some View {
            Color.clear
        }
    }

    /// Ex lino grafite: il riempimento dei pannelli di vetro del tema (senza materiali di sistema).
    struct Lino: View {
        var body: some View {
            LinearGradient.verticale(Colori.Lino.alto, Colori.Lino.basso)
        }
    }

    /// Sfondo della scrivania e del benvenuto: l'acqua con la pioggia (SfondoAcqua).
    /// Intensità della pioggia e «Sfondo animato» vengono dalle impostazioni, chiaro o scuro dall'aspetto.
    /// `animato` dice se in questo punto lo sfondo può muoversi (false = fermo, per esempio quando è coperto);
    /// finestra nascosta, basso consumo e «Riduci movimento» li gestisce già SfondoAcqua.
    /// Nelle istantanee SfondoAcqua mostra da sé il fermo-immagine.
    struct SfondoScrivania: View {
        var animato: Bool
        @EnvironmentObject private var stato: StatoShell
        @Environment(\.colorScheme) private var schema

        init(animato: Bool = false) {
            self.animato = animato
        }

        var body: some View {
            SfondoAcqua(animato: animato && stato.dati.impostazioni.sfondoAnimato,
                        intensita: stato.dati.impostazioni.pioggia.forza,
                        scuro: schema == .dark)
                .ignoresSafeArea()
        }
    }

    /// `box-shadow: inset 0 0 170px colore` reso con quattro sfumature sui bordi.
    struct Vignettatura: View {
        let colore: Color
        let ampiezza: CGFloat

        var body: some View {
            ZStack {
                VStack(spacing: 0) {
                    LinearGradient(colors: [colore, .clear], startPoint: .top, endPoint: .bottom).frame(height: ampiezza)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [.clear, colore], startPoint: .top, endPoint: .bottom).frame(height: ampiezza)
                }
                HStack(spacing: 0) {
                    LinearGradient(colors: [colore, .clear], startPoint: .leading, endPoint: .trailing).frame(width: ampiezza)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [.clear, colore], startPoint: .leading, endPoint: .trailing).frame(width: ampiezza)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
