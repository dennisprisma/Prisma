import SwiftUI

/// Il grafico dell'andamento di una posizione: il valore rilevato (linea piena con l'area), il
/// versato (tratteggiato) e dove sarebbe all'atteso netto (linea sottile), su un asse delle date.
/// Stesse scale, griglia e colori del grafico della proiezione.
struct GraficoAndamento: View {
    let punti: [AndamentoPosizione.Punto]

    var body: some View {
        GeometryReader { geo in
            let sinistra: CGFloat = 52
            let basso: CGFloat = 18
            let w = max(1, geo.size.width - sinistra - 10)
            let h = max(1, geo.size.height - basso - 6)
            let valori: [Double] = punti.flatMap { pt -> [Double] in [pt.valore, pt.versato ?? 0, pt.atteso ?? 0] }
            let massimo = max(valori.max() ?? 1, 1) * 1.08
            let inizio = punti.first?.data ?? Date()
            let durata = max(1, (punti.last?.data ?? inizio).timeIntervalSince(inizio))
            let x: (Date) -> CGFloat = { sinistra + CGFloat($0.timeIntervalSince(inizio) / durata) * w }
            let y: (Double) -> CGFloat = { 6 + h - CGFloat($0 / massimo) * h }
            let divisioni = 4
            ZStack(alignment: .topLeading) {
                ForEach(0...divisioni, id: \.self) { i in
                    let v = massimo * Double(i) / Double(divisioni)
                    Path { p in
                        p.move(to: CGPoint(x: sinistra, y: y(v)))
                        p.addLine(to: CGPoint(x: sinistra + w, y: y(v)))
                    }
                    .stroke(Colori.Analisi.griglia, lineWidth: 1)
                    Text(Formati.euroBreve(v))
                        .font(Tipo.assi)
                        .foregroundColor(Colori.Analisi.assi)
                        .frame(width: sinistra - 6, alignment: .trailing)
                        .position(x: (sinistra - 6) / 2, y: y(v))
                }
                ForEach(etichette, id: \.self) { d in
                    Text(Formati.meseAnnoBreve.string(from: d))
                        .font(Tipo.assi)
                        .foregroundColor(Colori.Analisi.assi)
                        .position(x: x(d), y: geo.size.height - basso / 2)
                }
                // Versato (tratteggiato), dove noto
                Path { p in
                    let noti = punti.filter { $0.versato != nil }
                    for (i, pt) in noti.enumerated() {
                        let q = CGPoint(x: x(pt.data), y: y(pt.versato ?? 0))
                        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                    }
                }
                .stroke(Colori.Analisi.lineaTratteggiata, style: StrokeStyle(lineWidth: 1.8, dash: [5, 4]))
                // Area sotto il valore
                Path { p in
                    guard let primo = punti.first, let ultimo = punti.last else { return }
                    p.move(to: CGPoint(x: x(primo.data), y: y(0)))
                    for pt in punti { p.addLine(to: CGPoint(x: x(pt.data), y: y(pt.valore))) }
                    p.addLine(to: CGPoint(x: x(ultimo.data), y: y(0)))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Colori.Analisi.linea.opacity(0.22), Colori.Analisi.linea.opacity(0.03)],
                                     startPoint: .top, endPoint: .bottom))
                // All'atteso netto
                Path { p in
                    let attesi = punti.filter { $0.atteso != nil }
                    for (i, pt) in attesi.enumerated() {
                        let q = CGPoint(x: x(pt.data), y: y(pt.atteso ?? 0))
                        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                    }
                }
                .stroke(Colori.Analisi.lineaAtteso, style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                // Valore rilevato, con un punto a ogni rilevazione
                Path { p in
                    for (i, pt) in punti.enumerated() {
                        let q = CGPoint(x: x(pt.data), y: y(pt.valore))
                        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                    }
                }
                .stroke(Colori.Analisi.linea, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
                ForEach(punti) { pt in
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Colori.Analisi.linea, lineWidth: pt.id == punti.last?.id ? 2 : 1.5))
                        .frame(width: pt.id == punti.last?.id ? 9 : 6, height: pt.id == punti.last?.id ? 9 : 6)
                        .position(x: x(pt.data), y: y(pt.valore))
                }
            }
        }
        .frame(height: Misure.Analisi.grafico)
    }

    /// Al massimo sei date sull'asse: la prima, l'ultima e qualcuna in mezzo.
    private var etichette: [Date] {
        guard punti.count > 2 else { return punti.map(\.data) }
        let passo = max(1, Int((Double(punti.count - 1) / 5).rounded(.up)))
        var elenco = stride(from: 0, to: punti.count - 1, by: passo).map { punti[$0].data }
        elenco.append(punti[punti.count - 1].data)
        return elenco
    }
}
