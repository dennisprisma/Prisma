import SwiftUI

/// Materiali skeuomorfici del template, ricavati dal CSS e salvati come PNG in Risorse/Materiali.
enum Materiale {
    /// Trama ripetuta (PNG a doppia risoluzione).
    struct Trama: View {
        let nome: String

        var body: some View {
            if let img = Risorse.immagine("Materiali/\(nome).png", scala: 2) {
                Image(nsImage: img).resizable(resizingMode: .tile)
            } else {
                Color.clear
            }
        }
    }

    /// Pelle (--prisma-leather): la ricetta del template a livelli, senza foto stirate.
    /// Gradiente caldo, puntinatura fine (tile da 3 pt), riflesso in alto a sinistra e grana.
    struct Pelle: View {
        var body: some View {
            ZStack {
                Gradienti.pelle
                Trama(nome: "Pelle_punti")
                Gradienti.pelleRiflesso
                Trama(nome: "Grana").opacity(0.5)
            }
        }
    }

    /// Lino grafite (--prisma-linen): riquadro di Eve, pannelli scuri.
    struct Lino: View {
        var body: some View {
            ZStack {
                Gradienti.lino
                Trama(nome: "Lino_trama")
            }
        }
    }

    /// Sfondo della scrivania "Gocce" con velo e vignettatura.
    struct SfondoScrivania: View {
        var body: some View {
            GeometryReader { geo in
                ZStack {
                    Colori.Sfondo.base
                    ImmagineRisorsa(percorso: "Sfondi/Gocce.jpg")
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    Gradienti.veloSfondo
                    Vignettatura(colore: Colori.Sfondo.vignettatura, ampiezza: 170)
                }
            }
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
