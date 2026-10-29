import SwiftUI

/// Il grafico dell'andamento di una posizione: il valore rilevato (linea piena con l'area), il
/// versato (tratteggiato) e dove sarebbe all'atteso netto (linea sottile), su un asse delle date.
/// Stesse scale, griglia e colori del grafico della proiezione (griglia e assi dal tema, linee dai colori dell'analisi).
/// La linea dell'atteso si disegna sopra quella del valore, tratteggiata: dove coincidono si leggono tutte e due.
struct GraficoAndamento: View {
    let punti: [AndamentoPosizione.Punto]
    /// Colore della linea sottile (`atteso`): l'atteso netto o, nel pannello del riferimento, il ritmo del metro.
    var coloreAtteso: Color = Colori.Analisi.lineaAtteso
    /// Tratti della linea dell'atteso (gli stessi della legenda tratteggiata); vuoto per una linea piena.
    var trattiAtteso: [CGFloat] = Tema.Misura.Componenti.trattiAtteso

    var body: some View {
        GeometryReader { geo in
            let sinistra = Tema.Misura.Componenti.graficoSinistra
            let basso = Tema.Misura.Componenti.graficoBasso
            let w = max(1, geo.size.width - sinistra - 10)
            let h = max(1, geo.size.height - basso - 6)
            let valori: [Double] = punti.flatMap { pt -> [Double] in [pt.valore, pt.versato ?? 0, pt.atteso ?? 0] }
            let scala = AsseGrafico.scala(minimo: 0, massimo: valori.max() ?? 0)
            let inizio = punti.first?.data ?? Date()
            let durata = max(1, (punti.last?.data ?? inizio).timeIntervalSince(inizio))
            let x: (Date) -> CGFloat = { sinistra + CGFloat($0.timeIntervalSince(inizio) / durata) * w }
            let y: (Double) -> CGFloat = { 6 + h - CGFloat(($0 - scala.minimo) / (scala.massimo - scala.minimo)) * h }
            let etichette = AsseGrafico.diradate(punti.map { pt -> (testo: String, x: CGFloat) in
                (testo: Formati.meseAnnoBreve.string(from: pt.data), x: x(pt.data))
            })
            ZStack(alignment: .topLeading) {
                ForEach(Array(scala.tacche.enumerated()), id: \.offset) { i, v in
                    Path { p in
                        p.move(to: CGPoint(x: sinistra, y: y(v)))
                        p.addLine(to: CGPoint(x: sinistra + w, y: y(v)))
                    }
                    .stroke(Tema.Colore.separatore, lineWidth: 1)
                    AsseGrafico.etichettaValore(v)
                        .frame(width: sinistra - 6, alignment: .trailing)
                        .position(x: (sinistra - 6) / 2, y: y(v) - (i == 0 ? Tema.Misura.Componenti.alzataPrimaTacca : 0))
                }
                // Le date: una per mese al più, mai più vicine di `distanzaEtichette`; l'ultima resta sempre
                ForEach(Array(etichette.enumerated()), id: \.offset) { _, e in
                    AsseGrafico.etichettaData(e.testo, x: e.x, da: sinistra, a: sinistra + w)
                        .position(x: e.x, y: geo.size.height - basso / 2)
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
                // Valore rilevato, con un punto a ogni rilevazione
                Path { p in
                    for (i, pt) in punti.enumerated() {
                        let q = CGPoint(x: x(pt.data), y: y(pt.valore))
                        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                    }
                }
                .stroke(Colori.Analisi.linea, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
                // All'atteso netto, sopra il valore e tratteggiato: non resta nascosto sotto la linea blu
                Path { p in
                    let attesi = punti.filter { $0.atteso != nil }
                    for (i, pt) in attesi.enumerated() {
                        let q = CGPoint(x: x(pt.data), y: y(pt.atteso ?? 0))
                        if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                    }
                }
                .stroke(coloreAtteso, style: StrokeStyle(lineWidth: Tema.Misura.Componenti.lineaAtteso, lineCap: .round,
                                                         lineJoin: .round, dash: trattiAtteso))
                ForEach(punti) { pt in
                    let ultimo = pt.id == punti.last?.id
                    let lato = ultimo ? Tema.Misura.Componenti.puntoGrafico : Tema.Misura.Componenti.puntoGraficoPiccolo
                    Circle()
                        .fill(Tema.Colore.Componenti.puntoGrafico)
                        .overlay { Circle().stroke(Colori.Analisi.linea, lineWidth: ultimo ? 2 : 1.5) }
                        .frame(width: lato, height: lato)
                        .position(x: x(pt.data), y: y(pt.valore))
                }
            }
        }
        .frame(height: Misure.Analisi.grafico)
    }
}
