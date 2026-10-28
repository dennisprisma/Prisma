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
    /// I valori arrivano da chi la disegna (ShellView, dalle impostazioni), chiaro o scuro dall'aspetto:
    /// niente StatoShell osservato, così l'acqua non si riconfigura a ogni cambiamento dello stato.
    /// `animato` dice se in questo punto lo sfondo può muoversi («Sfondo animato» acceso e scrivania visibile;
    /// false = fermo); `intensita` è la forza della pioggia (gocce al secondo).
    /// Con finestre aperte davanti (scrivania sbloccata) l'acqua va più piano: lo legge da StatoFinestre,
    /// che ShellView mette a disposizione (questa vista si disegna solo lì).
    /// Finestra nascosta, basso consumo, «Riduci movimento», transizioni, riposo del Mac e Prisma in secondo piano
    /// li gestisce già SfondoAcqua. Nelle istantanee SfondoAcqua mostra da sé il fermo-immagine.
    struct SfondoScrivania: View {
        var animato: Bool
        var intensita: Double
        @EnvironmentObject private var sistema: StatoFinestre
        @Environment(\.colorScheme) private var schema

        init(animato: Bool = false, intensita: Double) {
            self.animato = animato
            self.intensita = intensita
        }

        var body: some View {
            SfondoAcqua(animato: animato, intensita: intensita, scuro: schema == .dark,
                        lento: !sistema.bloccato && !sistema.visibili.isEmpty)
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
