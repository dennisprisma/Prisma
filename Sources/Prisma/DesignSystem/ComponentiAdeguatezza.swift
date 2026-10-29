import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

// I pezzi su carta della scheda di adeguatezza (giro 4, specifica 1): la casella dei documenti, il pallino
// dei controlli e le tre righe per le firme. Colori fissi di `paletteDocumento`: il PDF resta sempre chiaro.
// Le caselle e i segni sono disegnati (non caratteri speciali, che non tutti i font hanno).

/// La casella di un documento: vuota, spuntata o, se non serve per questa proposta, con un trattino.
struct SpuntaCarta: View {
    @Environment(\.paletteDocumento) private var C
    let segnata: Bool
    var nonPertinente = false

    var body: some View {
        let l = D.spuntaCarta
        ZStack {
            Rectangle().strokeBorder(C.testo, lineWidth: D.trattoSpunta)
            if segnata {
                Path { p in
                    p.move(to: CGPoint(x: 0.22 * l, y: 0.52 * l))
                    p.addLine(to: CGPoint(x: 0.42 * l, y: 0.74 * l))
                    p.addLine(to: CGPoint(x: 0.8 * l, y: 0.26 * l))
                }
                .stroke(C.titolo, style: StrokeStyle(lineWidth: D.segnoSpunta, lineCap: .round, lineJoin: .round))
            } else if nonPertinente {
                Path { p in
                    p.move(to: CGPoint(x: 0.25 * l, y: 0.5 * l))
                    p.addLine(to: CGPoint(x: 0.75 * l, y: 0.5 * l))
                }
                .stroke(C.tenue, style: StrokeStyle(lineWidth: D.segnoSpunta, lineCap: .round))
            }
        }
        .frame(width: l, height: l)
    }
}

/// Il pallino colorato di un controllo, con i colori del check-up su carta.
struct PallinoCarta: View {
    @Environment(\.paletteDocumento) private var C
    let semaforo: Semaforo

    var body: some View {
        Circle()
            .fill(coloreSemaforo(semaforo, C))
            .frame(width: D.pallinoCarta, height: D.pallinoCarta)
    }
}

/// Le tre righe per le firme in fondo alla scheda: cliente, consulente, luogo e data.
struct FirmeScheda: View {
    @Environment(\.paletteDocumento) private var C
    let cliente: String
    let consulente: String
    let firmataIl: Date?

    var body: some View {
        let larghezza = (FoglioProspetto<EmptyView>.larghezza - 2 * D.spazioFirme) / 3
        VStack(alignment: .leading, spacing: D.spazioSchedaPiccolo) {
            if let d = firmataIl {
                Text(verbatim: "Segnata come firmata in Prisma il \(CifreDoc.data(d)).")
                    .font(T.pTabellaNota).foregroundColor(C.tenue)
            }
            HStack(alignment: .bottom, spacing: D.spazioFirme) {
                firma("Firma del cliente · \(cliente)", larghezza)
                firma("Firma del consulente · \(consulente)", larghezza)
                firma("Luogo e data", larghezza)
            }
        }
        .frame(width: FoglioProspetto<EmptyView>.larghezza, alignment: .leading)
    }

    private func firma(_ etichetta: String, _ larghezza: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: D.spazioEtichettaFirma) {
            Spacer(minLength: 0)
            Rectangle().fill(C.tenue).frame(height: D.lineaFirma)
            Text(verbatim: etichetta)
                .font(T.pTabellaNota).foregroundColor(C.tenue)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: larghezza, height: D.altezzaFirma, alignment: .bottomLeading)
    }
}
