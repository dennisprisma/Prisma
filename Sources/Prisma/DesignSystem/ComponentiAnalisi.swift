import SwiftUI

// MARK: - Gettoni delle app di analisi

extension Tema.Misura.Componenti {
    /// Voce della barra laterale (.side-item): margini e altezza minima.
    static let voceLaterale = EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)
    static let voceLateraleMinima: CGFloat = 30
    static let quadratinoVoce: CGFloat = 10
    /// Intestazione di sezione della barra laterale (.side-sec).
    static let sezioneLaterale = EdgeInsets(top: 12, leading: 8, bottom: 4, trailing: 8)
    /// Tessere degli indicatori (.tiles): spazio tra le tessere e margini interni.
    static let spazioTessere: CGFloat = 10
    static let tessera = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
    /// Chip neutro (pozzetto) e contatore delle voci.
    static let chipNeutro: CGFloat = 18
    static let margineChipNeutro: CGFloat = 7
    static let margineContatore: CGFloat = 6
    /// Barra divisa per canale (.split): altezza, stacco tra i due colori, larghezza minima di un tratto.
    static let barraCanali: CGFloat = 10
    static let spazioBarraCanali: CGFloat = 2
    static let minimoBarraCanali: CGFloat = 6
    /// Margine sinistro (etichette dei valori) e basso (anni o date) dei grafici.
    static let graficoSinistra: CGFloat = 52
    static let graficoBasso: CGFloat = 18
    /// Punto finale della linea principale dei grafici.
    static let puntoGrafico: CGFloat = 9
    static let puntoGraficoPiccolo: CGFloat = 6
}

extension Tema.Testo.Componenti {
    /// Titolo delle voci della barra laterale e delle righe delle impostazioni (13/500).
    static let voce = Tema.Testo.sf(13, .medium)
    /// Valore delle tessere degli indicatori (18/600) con la sua spaziatura.
    static let spaziaturaValore = Tema.Testo.spaziatura(-0.01, 18)
    /// Titolo dei pannelli di analisi.
    static let titoloPannello = Tema.Testo.sf(15, .semibold)
    /// Etichette degli assi dei grafici.
    static let asse = Tema.Testo.sf(10.5).monospacedDigit()
}

// MARK: - Controlli dell'elenco laterale

/// Controllo a segmenti delle app di analisi: voci di larghezza uguale.
struct SegmentiAnalisi<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore

    var body: some View {
        ControlloSegmenti(opzioni: opzioni, selezione: $selezione, riempi: true)
    }
}

/// Voce della barra laterale (.side-item): fondo leggero al passaggio, accento al 17% se scelta.
struct VoceNavigazione: View {
    let titolo: String
    var colore: Color? = nil
    var conteggio: Int? = nil
    let attiva: Bool
    let azione: () -> Void

    var body: some View {
        let m = Tema.Misura.Componenti.self
        Button(action: azione) {
            HStack(spacing: 10) {
                if let colore {
                    RoundedRectangle(cornerRadius: Tema.Raggio.quadratinoCanale, style: .continuous)
                        .fill(colore)
                        .frame(width: m.quadratinoVoce, height: m.quadratinoVoce)
                }
                Text(titolo)
                    .font(Tema.Testo.Componenti.voce)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let conteggio, conteggio > 0 {
                    Text("\(conteggio)")
                        .font(Tema.Testo.chipPiccolo)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .padding(.horizontal, m.margineContatore)
                        .frame(minHeight: m.chipNeutro)
                        .background { FormaVetro.capsula.fill(Tema.Colore.pozzetto) }
                }
            }
            .padding(m.voceLaterale)
            .frame(minHeight: m.voceLateraleMinima)
            .frame(maxWidth: .infinity)
            .fondoPassaggio(.arrotondata(Tema.Raggio.voceLaterale), selezionata: attiva)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }
}

/// Intestazione di sezione della barra laterale (.side-sec: 11,5/600, inchiostro terziario).
struct EtichettaRail: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(Tema.Testo.occhiello)
            .foregroundColor(Tema.Colore.inchiostroTerziario)
            .padding(Tema.Misura.Componenti.sezioneLaterale)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - KPI, chip e pillole

/// Fila di indicatori: tessere del tema (.tiles) affiancate, tutte alte uguali.
struct FasciaKPI<Contenuto: View>: View {
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        HStack(alignment: .top, spacing: Tema.Misura.Componenti.spazioTessere) {
            contenuto()
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Un indicatore in una tessera (.tile): etichetta, valore 18/600, nota sotto.
/// `ultimo` resta per compatibilità: le tessere sono staccate e non hanno filetti.
struct KPI<Nota: View>: View {
    let titolo: String
    let valore: String
    var ultimo = false
    @ViewBuilder let nota: () -> Nota

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titolo)
                .font(Tema.Testo.secondario)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(valore)
                .font(Tema.Testo.valoreTessera)
                .tracking(Tema.Testo.Componenti.spaziaturaValore)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 5) { nota() }
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
        }
        .padding(Tema.Misura.Componenti.tessera)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.tessera))
    }
}

/// Chip neutro: capsula in pozzetto con testo secondario.
struct Chip: View {
    let testo: String

    var body: some View {
        let m = Tema.Misura.Componenti.self
        Text(testo)
            .font(Tema.Testo.chipPiccolo)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .lineLimit(1)
            .padding(.horizontal, m.margineChipNeutro)
            .frame(minHeight: m.chipNeutro)
            .background { FormaVetro.capsula.fill(Tema.Colore.pozzetto) }
            .fixedSize()
    }
}

/// Pillola di stato (.pill): in essere (verde), proposta o in scadenza (arancio), errore (rosso), neutra.
struct Pillola: View {
    enum Tono { case ok, attenzione, errore, neutro }

    let testo: String
    let tono: Tono

    /// Fondo e testo del tono.
    private var colori: (fondo: Color, testo: Color) {
        switch tono {
        case .ok: return (Tema.Colore.fondoInEssere, Tema.Colore.testoInEssere)
        case .attenzione: return (Tema.Colore.fondoProposta, Tema.Colore.testoProposta)
        case .errore: return (Tema.Colore.Componenti.fondoErrore, Tema.Colore.scadenzaOra)
        case .neutro: return (Tema.Colore.pozzetto, Tema.Colore.inchiostroSecondario)
        }
    }

    var body: some View {
        Text(testo)
            .font(Tema.Testo.pill)
            .foregroundColor(colori.testo)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: Tema.Misura.pill)
            .background { FormaVetro.capsula.fill(colori.fondo) }
            .fixedSize()
    }
}

/// Riquadro con titolo e nota (pannelli dell'analisi), senza fondo proprio.
struct PannelloAnalisi<Destra: View, Contenuto: View>: View {
    let titolo: String
    var nota: String? = nil
    @ViewBuilder let destra: () -> Destra
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titolo).font(Tema.Testo.Componenti.titoloPannello).foregroundColor(Tema.Colore.inchiostro)
                    if let nota {
                        Text(nota).font(Tema.Testo.secondario).foregroundColor(Tema.Colore.inchiostroSecondario)
                    }
                }
                Spacer()
                destra()
            }
            contenuto()
        }
    }
}

// MARK: - Grafici

/// Anello di ripartizione (allocazione), con il totale al centro.
struct GraficoAnello: View {
    struct Fetta: Identifiable {
        let id: String
        let valore: Double
        let colore: Color
    }

    let fette: [Fetta]
    let etichettaCentro: String
    let valoreCentro: String

    var body: some View {
        let totale = max(fette.reduce(0) { $0 + $1.valore }, 0.000_1)
        let inizi = fette.indices.map { i in fette[..<i].reduce(0) { $0 + $1.valore } / totale }
        ZStack {
            Circle().stroke(Tema.Colore.pozzetto, lineWidth: Misure.Analisi.spessoreAnello)
            ForEach(Array(fette.enumerated()), id: \.element.id) { i, f in
                Circle()
                    .trim(from: inizi[i], to: inizi[i] + f.valore / totale)
                    .stroke(f.colore, style: StrokeStyle(lineWidth: Misure.Analisi.spessoreAnello, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 1) {
                Text(etichettaCentro).font(Tema.Testo.didascalia).foregroundColor(Tema.Colore.inchiostroSecondario)
                Text(valoreCentro).font(Tema.Testo.valoreKpi).foregroundColor(Tema.Colore.inchiostro)
            }
        }
        .padding(Misure.Analisi.spessoreAnello / 2)
        .frame(width: Misure.Analisi.anello, height: Misure.Analisi.anello)
    }
}

/// Grafico di una proiezione: area del valore, linea tratteggiata del versato, griglia e assi.
struct GraficoProiezione: View {
    struct Serie: Identifiable {
        let id: String
        let punti: [PuntoProiezione]
        let colore: Color
        var principale = false
    }

    let serie: [Serie]

    var body: some View {
        GeometryReader { geo in
            let sinistra = Tema.Misura.Componenti.graficoSinistra
            let basso = Tema.Misura.Componenti.graficoBasso
            let w = max(1, geo.size.width - sinistra - 6)
            let h = max(1, geo.size.height - basso - 6)
            let tutti = serie.flatMap(\.punti)
            let massimo = max(tutti.map { max($0.valore, $0.versato) }.max() ?? 1, 1) * 1.08
            // Un patrimonio negativo (debiti oltre le attività) resta dentro il grafico
            let minimo = min(tutti.map { min($0.valore, $0.versato) }.min() ?? 0, 0) * 1.08
            let anni = max(tutti.map(\.anno).max() ?? 1, 1)
            let x: (Int) -> CGFloat = { sinistra + CGFloat($0) / CGFloat(anni) * w }
            let y: (Double) -> CGFloat = { 6 + h - CGFloat(($0 - minimo) / (massimo - minimo)) * h }
            let divisioni = 4
            ZStack(alignment: .topLeading) {
                // Griglia orizzontale ed etichette dell'asse dei valori
                ForEach(0...divisioni, id: \.self) { i in
                    let v = minimo + (massimo - minimo) * Double(i) / Double(divisioni)
                    Path { p in
                        p.move(to: CGPoint(x: sinistra, y: y(v)))
                        p.addLine(to: CGPoint(x: sinistra + w, y: y(v)))
                    }
                    .stroke(Tema.Colore.separatore, lineWidth: 1)
                    Text(Formati.euroBreve(v))
                        .font(Tema.Testo.Componenti.asse)
                        .foregroundColor(Tema.Colore.inchiostroTerziario)
                        .frame(width: sinistra - 6, alignment: .trailing)
                        .position(x: (sinistra - 6) / 2, y: y(v))
                }
                // Etichette degli anni
                ForEach(etichetteAnni(anni), id: \.self) { a in
                    Text(a == 0 ? "Oggi" : "+\(a) a")
                        .font(Tema.Testo.Componenti.asse)
                        .foregroundColor(Tema.Colore.inchiostroTerziario)
                        .position(x: x(a), y: geo.size.height - basso / 2)
                }
                if let principale = serie.first(where: \.principale) ?? serie.first {
                    // Versato cumulato (tratteggiato)
                    Path { p in
                        for (i, pt) in principale.punti.enumerated() {
                            let q = CGPoint(x: x(pt.anno), y: y(pt.versato))
                            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                        }
                    }
                    .stroke(Colori.Analisi.lineaTratteggiata, style: StrokeStyle(lineWidth: 1.8, dash: [5, 4]))
                    // Area sotto il valore
                    Path { p in
                        guard let primo = principale.punti.first, let ultimo = principale.punti.last else { return }
                        p.move(to: CGPoint(x: x(primo.anno), y: y(0)))
                        for pt in principale.punti { p.addLine(to: CGPoint(x: x(pt.anno), y: y(pt.valore))) }
                        p.addLine(to: CGPoint(x: x(ultimo.anno), y: y(0)))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [principale.colore.opacity(0.22), principale.colore.opacity(0.03)],
                                         startPoint: .top, endPoint: .bottom))
                }
                ForEach(serie) { s in
                    Path { p in
                        for (i, pt) in s.punti.enumerated() {
                            let q = CGPoint(x: x(pt.anno), y: y(pt.valore))
                            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                        }
                    }
                    .stroke(s.colore, style: StrokeStyle(lineWidth: s.principale ? 2.2 : 1.4, lineJoin: .round))
                    if let ultimo = s.punti.last, s.principale {
                        Circle()
                            .fill(Tema.Colore.Componenti.puntoGrafico)
                            .overlay { Circle().stroke(s.colore, lineWidth: 2) }
                            .frame(width: Tema.Misura.Componenti.puntoGrafico, height: Tema.Misura.Componenti.puntoGrafico)
                            .position(x: x(ultimo.anno), y: y(ultimo.valore))
                    }
                }
            }
        }
        .frame(height: Misure.Analisi.grafico)
    }

    private func etichetteAnni(_ anni: Int) -> [Int] {
        let passo = max(1, Int((Double(anni) / 6).rounded(.up)))
        var elenco = Array(stride(from: 0, through: anni, by: passo))
        if elenco.last != anni { elenco.append(anni) }
        return elenco
    }
}

/// Barra divisa per canale (.split): blu Alleanza e cuoio indipendente, staccati e arrotondati.
struct BarraCanali: View {
    let quotaAlleanza: Double

    var body: some View {
        let m = Tema.Misura.Componenti.self
        GeometryReader { geo in
            let q = min(max(quotaAlleanza, 0), 1)
            let stacco: CGFloat = (q > 0 && q < 1) ? m.spazioBarraCanali : 0
            let utile = max(0, geo.size.width - stacco)
            let alleanza = q > 0 ? min(utile, max(m.minimoBarraCanali, utile * CGFloat(q))) : 0
            HStack(spacing: stacco) {
                if q > 0 {
                    RoundedRectangle(cornerRadius: Tema.Raggio.barraCanali, style: .continuous)
                        .fill(Tema.Colore.canaleAlleanza)
                        .frame(width: alleanza)
                }
                if q < 1 {
                    RoundedRectangle(cornerRadius: Tema.Raggio.barraCanali, style: .continuous)
                        .fill(Tema.Colore.canaleIndipendente)
                }
            }
        }
        .frame(height: m.barraCanali)
    }
}
