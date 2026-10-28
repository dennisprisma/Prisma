import SwiftUI

// MARK: - Gettoni e pezzi dei documenti per le cifre dei motori nuovi
// Prospetti (A4 verticale, per il consulente) e report (A4 orizzontale, per il cliente): incidenza dei costi
// come nel KID, crisi del passato, scenari con le probabilità, pensione pubblica stimata, protezione per persona.
// Sempre su carta: colori fissi dalla tavolozza del documento, niente vetro.

extension Misure.Documento {
    /// Misure dei documenti per le analisi dei motori nuovi.
    enum Motori {
        /// Grafico a ventaglio degli scenari con le probabilità, nel prospetto e nel report.
        static let graficoVentaglio: CGFloat = 160
        static let graficoVentaglioReport: CGFloat = 290
        /// Righe dell'anno per anno degli scenari con le probabilità: oltre, una riga ogni 5 anni.
        static let anniTabellaProbabilita = 11
        /// Montante contributivo fino alla pensione, nel prospetto e nel report.
        static let graficoMontante: CGFloat = 130
        static let graficoMontanteReport: CGFloat = 250
        /// Margini interni dei grafici: asse dei valori a sinistra, etichette finali a destra.
        static let graficoSinistra: CGFloat = 54
        static let graficoDestra: CGFloat = 92
        static let graficoBasso: CGFloat = 18
        static let graficoAlto: CGFloat = 12
        /// Distanza minima tra le etichette finali del ventaglio.
        static let distanzaEtichette: CGFloat = 18
        /// Spessore delle linee: mediana e bordi della fascia, traguardo tratteggiato.
        static let lineaMediana: CGFloat = 2.2
        static let lineaBordo: CGFloat = 0.8
        static let lineaTraguardo: CGFloat = 1
        static let trattoTraguardo: [CGFloat] = [5, 3]
        /// Incidenza dei costi anno per anno (barre) nel prospetto dei costi, e anni mostrati al massimo.
        static let graficoIncidenza: CGFloat = 120
        static let anniIncidenza = 20
        /// Righe con la barra orizzontale nei report: etichetta del canale, nome, barra, cifra, nota.
        static let barraReport: CGFloat = 12
        static let barraMinima: CGFloat = 3
        static let colonnaCanaleReport: CGFloat = 84
        static let colonnaNomeReport: CGFloat = 220
        static let colonnaCifraReport: CGFloat = 96
        static let colonnaNotaReport: CGFloat = 150
        static let spazioRigaReport: CGFloat = 10
        /// Righe delle tabelle a pagina fissa dei prospetti nuovi (con il sottotitolo, a una riga).
        static let rigaTabella: CGFloat = 22
        static let rigaTabellaBassa: CGFloat = 15
        /// Riquadri dei report: margine interno e spazio tra i riquadri.
        static let margineRiquadro: CGFloat = 16
        static let spazioRiquadri: CGFloat = 12
        /// Altezza minima delle schede affiancate nei report (crisi, persone).
        static let schedaReport: CGFloat = 190
        /// Larghezza della colonna laterale dei report (cifre in evidenza, prossimi passi).
        static let colonnaLateraleReport: CGFloat = 250
        /// Persone mostrate al massimo nelle pagine a dimensione fissa (le altre restano nell'app).
        static let personeMassime = 3
        static let crisiMassime = 3
    }
}

extension Colori.Documento {
    /// Trasparenza della fascia tra lo scenario sfavorevole e quello favorevole nel grafico a ventaglio.
    static let opacitaVentaglio: Double = 0.16
    /// Trasparenza dei bordi della fascia.
    static let opacitaBordoVentaglio: Double = 0.55
}

// MARK: - Grafico a ventaglio

/// Gli scenari con le probabilità nel tempo: la fascia tra lo scenario sfavorevole (1 caso su 10 va peggio) e
/// quello favorevole (1 su 10 va meglio), la linea mediana e il traguardo tratteggiato. Valori di fine anno.
struct GraficoVentaglioDoc: View {
    @Environment(\.paletteDocumento) private var p
    let anni: [EsitoMonteCarlo.Anno]
    let traguardo: Double
    var fontAssi: Font = Tipo.Documento.piccolo
    var fontValori: Font = Tipo.Documento.minimo

    private typealias M = Misure.Documento.Motori

    var body: some View {
        GeometryReader { geo in
            let sinistra = M.graficoSinistra
            let destra = M.graficoDestra
            let basso = M.graficoBasso
            let alto = M.graficoAlto
            let w = max(1, geo.size.width - sinistra - destra)
            let h = max(1, geo.size.height - basso - alto)
            let massimoDato = max(anni.map(\.p90).max() ?? 0, traguardo, 1)
            let passo = MisuraAsse.passo(massimoDato)
            let massimo = (massimoDato / passo).rounded(.up) * passo
            let n = max(anni.count - 1, 1)
            let x: (Int) -> CGFloat = { sinistra + CGFloat($0) / CGFloat(n) * w }
            let y: (Double) -> CGFloat = { alto + h - CGFloat(max(0, $0) / max(massimo, 1)) * h }
            let tacche = Array(stride(from: 0.0, through: massimo + 0.5, by: passo))
            let ultimo = anni.last
            let finali: [CGFloat] = [y(ultimo?.p90 ?? 0), y(ultimo?.p50 ?? 0), y(ultimo?.p10 ?? 0), y(traguardo)]
            let etichette = GraficoLineeDoc.altezzeEtichette(finali, distanza: M.distanzaEtichette)
            ZStack(alignment: .topLeading) {
                ForEach(Array(tacche.enumerated()), id: \.offset) { _, v in
                    Path { q in
                        q.move(to: CGPoint(x: sinistra, y: y(v)))
                        q.addLine(to: CGPoint(x: sinistra + w, y: y(v)))
                    }
                    .stroke(p.griglia, lineWidth: 0.7)
                    Text(verbatim: CifreDoc.euro(v)).font(fontAssi).foregroundColor(p.tenue)
                        .frame(width: sinistra - 6, alignment: .trailing)
                        .position(x: (sinistra - 6) / 2, y: y(v))
                }
                ForEach(Array(anni.enumerated()), id: \.offset) { i, a in
                    let testo = etichettaAsse(i, a.anno)
                    if !testo.isEmpty {
                        Text(verbatim: testo).font(fontAssi).foregroundColor(p.tenue).lineLimit(1).fixedSize()
                            .position(x: x(i), y: geo.size.height - basso / 2 + 2)
                    }
                }
                // La fascia tra sfavorevole e favorevole
                Path { q in
                    for i in anni.indices {
                        let punto = CGPoint(x: x(i), y: y(anni[i].p90))
                        if i == anni.startIndex { q.move(to: punto) } else { q.addLine(to: punto) }
                    }
                    for i in anni.indices.reversed() {
                        q.addLine(to: CGPoint(x: x(i), y: y(anni[i].p10)))
                    }
                    q.closeSubpath()
                }
                .fill(p.intermedio.opacity(Colori.Documento.opacitaVentaglio))
                linea(\.p90, x: x, y: y).stroke(p.favorevole.opacity(Colori.Documento.opacitaBordoVentaglio), lineWidth: M.lineaBordo)
                linea(\.p10, x: x, y: y).stroke(p.sfavorevole.opacity(Colori.Documento.opacitaBordoVentaglio), lineWidth: M.lineaBordo)
                linea(\.p50, x: x, y: y).stroke(p.intermedio, style: StrokeStyle(lineWidth: M.lineaMediana, lineJoin: .round))
                // Il traguardo alla scadenza
                Path { q in
                    q.move(to: CGPoint(x: sinistra, y: y(traguardo)))
                    q.addLine(to: CGPoint(x: sinistra + w, y: y(traguardo)))
                }
                .stroke(p.titolo, style: StrokeStyle(lineWidth: M.lineaTraguardo, dash: M.trattoTraguardo))
                if let ultimo {
                    etichetta("Favorevole", ultimo.p90, p.favorevole).position(x: sinistra + w + destra / 2 + 2, y: etichette[0])
                    etichetta("Mediano", ultimo.p50, p.intermedio).position(x: sinistra + w + destra / 2 + 2, y: etichette[1])
                    etichetta("Sfavorevole", ultimo.p10, p.sfavorevole).position(x: sinistra + w + destra / 2 + 2, y: etichette[2])
                }
                etichetta("Obiettivo", traguardo, p.titolo).position(x: sinistra + w + destra / 2 + 2, y: etichette[3])
            }
        }
    }

    private func linea(_ chiave: KeyPath<EsitoMonteCarlo.Anno, Double>, x: (Int) -> CGFloat, y: (Double) -> CGFloat) -> Path {
        Path { q in
            for i in anni.indices {
                let punto = CGPoint(x: x(i), y: y(anni[i][keyPath: chiave]))
                if i == anni.startIndex { q.move(to: punto) } else { q.addLine(to: punto) }
            }
        }
    }

    private func etichetta(_ nome: String, _ valore: Double, _ colore: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: nome).font(fontValori.weight(.bold)).lineLimit(1)
            Text(verbatim: CifreDoc.euro(valore)).font(fontValori.weight(.bold)).lineLimit(1)
        }
        .foregroundColor(colore)
        .frame(width: M.graficoDestra - 8, alignment: .leading)
    }

    /// "oggi", poi un anno ogni 2, 5 o 10 a seconda della durata, e l'ultimo.
    private func etichettaAsse(_ indice: Int, _ anno: Int) -> String {
        if indice == 0 { return "oggi" }
        let passo = anni.count <= 12 ? 2 : (anni.count <= 30 ? 5 : 10)
        return anno % passo == 0 || indice == anni.count - 1 ? "\(anno)° anno" : ""
    }
}

// MARK: - Riga con la barra orizzontale (report)

/// Una riga dei report: etichetta del canale, nome, barra proporzionale, cifra e nota.
struct RigaBarraDoc: View {
    @Environment(\.paletteDocumento) private var p
    let canale: Canale?
    let nome: String
    /// Lunghezza della barra, da 0 a 1.
    let quota: Double
    let colore: Color
    let valore: String
    var nota = ""
    var fontNome: Font = Tipo.Report.corpo
    var fontValore: Font = Tipo.Report.corpoForte
    var fontNota: Font = Tipo.Report.piccolo

    private typealias M = Misure.Documento.Motori

    var body: some View {
        HStack(spacing: M.spazioRigaReport) {
            if let canale = canale {
                EtichettaCanale(canale: canale, compatta: true).frame(width: M.colonnaCanaleReport, alignment: .leading)
            }
            Text(verbatim: nome).font(fontNome).foregroundColor(p.titolo).lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: M.colonnaNomeReport, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(p.griglia)
                    Rectangle().fill(colore).frame(width: max(M.barraMinima, g.size.width * CGFloat(min(max(quota, 0), 1))))
                }
            }
            .frame(height: M.barraReport)
            Text(verbatim: valore).font(fontValore).foregroundColor(colore).lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: M.colonnaCifraReport, alignment: .trailing)
            if !nota.isEmpty {
                Text(verbatim: nota).font(fontNota).foregroundColor(p.tenue).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(width: M.colonnaNotaReport, alignment: .trailing)
            }
        }
    }
}
