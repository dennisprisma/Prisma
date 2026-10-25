import SwiftUI

// MARK: - Controlli dell'elenco laterale

/// Controllo a segmenti ardesia delle app di analisi (.fx-seg).
struct SegmentiAnalisi<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(opzioni.enumerated()), id: \.offset) { i, o in
                let attivo = o.0 == selezione
                Button { selezione = o.0 } label: {
                    Text(o.1)
                        .font(Tipo.segAnalisi)
                        .foregroundColor(attivo ? .white : Colori.Analisi.segTesto)
                        .incisione(attivo ? Colori.Analisi.segAttivoIncisione : .white, y: attivo ? -1 : 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(attivo ? AnyShapeStyle(Gradienti.segAnalisiAttivo) : AnyShapeStyle(Color.clear))
                        .overlay(alignment: .top) {
                            if attivo {
                                LinearGradient(colors: [Colori.Analisi.segAttivoOmbra, .clear], startPoint: .top, endPoint: .bottom).frame(height: 3)
                            }
                        }
                }
                .buttonStyle(StileSemplice())
                if i < opzioni.count - 1 {
                    Rectangle().fill(Colori.Analisi.segBordo).frame(width: 1)
                }
            }
        }
        .frame(height: Misure.Analisi.segAltezza)
        .background(Gradienti.controlloLion)
        .clipShape(RoundedRectangle(cornerRadius: Misure.Analisi.raggio))
        .overlay(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).strokeBorder(Colori.Analisi.segBordo, lineWidth: 1))
        .shadow(color: .white, radius: 0, x: 0, y: 1)
    }
}

/// Voce dell'elenco laterale con selezione blu (.fx-nav).
struct VoceNavigazione: View {
    let titolo: String
    var colore: Color? = nil
    var conteggio: Int? = nil
    let attiva: Bool
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 9) {
                if let colore {
                    RoundedRectangle(cornerRadius: 2).fill(colore).frame(width: 10, height: 10)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.white.opacity(attiva ? 0.8 : 0), lineWidth: 1))
                }
                Text(titolo)
                    .font(attiva ? Tipo.navAnalisiAttiva : Tipo.navAnalisi)
                    .foregroundColor(attiva ? .white : Colori.Analisi.navTesto)
                    .incisione(attiva ? Colori.Analisi.navIncisione : Colori.Analisi.navIncisioneSpento)
                Spacer(minLength: 4)
                if let conteggio, conteggio > 0 {
                    Text("\(conteggio)")
                        .font(Tipo.chip)
                        .foregroundColor(attiva ? Colori.Analisi.navIncisione : Colori.Analisi.navConteggioTesto)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(attiva ? Color.white.opacity(0.85) : Colori.Analisi.navConteggio))
                }
            }
            .padding(.horizontal, 9)
            .frame(height: Misure.Analisi.navAltezza)
            .frame(maxWidth: .infinity)
            .background(attiva ? AnyShapeStyle(Gradienti.navAnalisi) : AnyShapeStyle(Color.clear))
            .luceInterna(attiva ? Colori.Analisi.navLuce : .clear)
            .bordoAlto(attiva ? Colori.Analisi.navBordoAlto : .clear)
            .bordoBasso(attiva ? Colori.Analisi.navBordoBasso : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }
}

struct EtichettaRail: View {
    let testo: String

    var body: some View {
        Text(testo.uppercased())
            .font(Tipo.railEtichetta)
            .foregroundColor(Colori.Analisi.railEtichetta)
            .incisione(.white)
            .padding(EdgeInsets(top: 8, leading: 3, bottom: 1, trailing: 3))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - KPI, chip e pillole

/// Fascia di indicatori (.fx-kpis).
struct FasciaKPI<Contenuto: View>: View {
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            contenuto()
        }
        .background(Gradienti.kpi)
        .luceInterna(.white)
        .overlay(Rectangle().strokeBorder(Colori.Analisi.kpiBordo, lineWidth: 1))
    }
}

/// Un indicatore: titolo maiuscolo, valore grande, nota sotto.
struct KPI<Nota: View>: View {
    let titolo: String
    let valore: String
    var ultimo = false
    @ViewBuilder let nota: () -> Nota

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(titolo.uppercased())
                .font(Tipo.kpiTitolo)
                .tracking(0.3)
                .foregroundColor(Colori.Analisi.kpiTitolo)
            Text(valore)
                .font(Tipo.kpiValore)
                .tracking(-0.5)
                .foregroundColor(Colori.Analisi.kpiValore)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 5) { nota() }
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.kpiNota)
                .lineLimit(1)
        }
        .incisione(.white)
        .padding(Misure.Analisi.kpiMargine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) {
            if !ultimo { Rectangle().fill(Colori.Analisi.kpiBordo).frame(width: 1) }
        }
    }
}

struct Chip: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(Tipo.chip)
            .foregroundColor(Colori.Analisi.chipTesto)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3).fill(Colori.Analisi.chip))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Colori.Analisi.chipBordo, lineWidth: 1))
            .fixedSize()
    }
}

/// Pillola di stato (.fx-pill): regolare, in scadenza, scaduta, proposta…
struct Pillola: View {
    enum Tono { case ok, attenzione, errore, neutro }

    let testo: String
    let tono: Tono

    /// Fondo, bordo e testo del tono.
    private var colori: (fondo: Color, bordo: Color, testo: Color) {
        switch tono {
        case .ok: return (Colori.Analisi.okFondo, Colori.Analisi.okBordo, Colori.Analisi.okTesto)
        case .attenzione: return (Colori.Analisi.attenzioneFondo, Colori.Analisi.attenzioneBordo, Colori.Analisi.attenzioneTesto)
        case .errore: return (Colori.Analisi.erroreFondo, Colori.Analisi.erroreBordo, Colori.Analisi.erroreTesto)
        case .neutro: return (Colori.Analisi.neutroFondo, Colori.Analisi.neutroBordo, Colori.Analisi.neutroTesto)
        }
    }

    var body: some View {
        Text(testo)
            .font(Tipo.pill)
            .foregroundColor(colori.testo)
            .incisione(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 3).fill(colori.fondo))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(colori.bordo, lineWidth: 1))
            .fixedSize()
    }
}

/// Riquadro con titolo e nota (pannelli dell'analisi).
struct PannelloAnalisi<Destra: View, Contenuto: View>: View {
    let titolo: String
    var nota: String? = nil
    @ViewBuilder let destra: () -> Destra
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titolo).font(Tipo.pannelloAnalisi).foregroundColor(Colori.Analisi.pannelloTitolo)
                    if let nota {
                        Text(nota).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.pannelloNota)
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
            Circle().stroke(Colori.Analisi.tracciaAnello, lineWidth: Misure.Analisi.spessoreAnello)
            ForEach(Array(fette.enumerated()), id: \.element.id) { i, f in
                Circle()
                    .trim(from: inizi[i], to: inizi[i] + f.valore / totale)
                    .stroke(f.colore, style: StrokeStyle(lineWidth: Misure.Analisi.spessoreAnello, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 1) {
                Text(etichettaCentro.uppercased()).font(Tipo.chip).tracking(0.5).foregroundColor(Colori.Analisi.kpiTitolo)
                Text(valoreCentro).font(Tipo.pannelloAnalisi).foregroundColor(Colori.Analisi.kpiValore)
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
            let sinistra: CGFloat = 52
            let basso: CGFloat = 18
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
                    .stroke(Colori.Analisi.griglia, lineWidth: 1)
                    Text(Formati.euroBreve(v))
                        .font(Tipo.assi)
                        .foregroundColor(Colori.Analisi.assi)
                        .frame(width: sinistra - 6, alignment: .trailing)
                        .position(x: (sinistra - 6) / 2, y: y(v))
                }
                // Etichette degli anni
                ForEach(etichetteAnni(anni), id: \.self) { a in
                    Text(a == 0 ? "Oggi" : "+\(a) a")
                        .font(Tipo.assi)
                        .foregroundColor(Colori.Analisi.assi)
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
                            .fill(Color.white)
                            .overlay(Circle().stroke(s.colore, lineWidth: 2))
                            .frame(width: 9, height: 9)
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

/// Barra orizzontale della ripartizione tra i due canali.
struct BarraCanali: View {
    let quotaAlleanza: Double

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(Colori.Analisi.canaleAlleanza)
                    .frame(width: geo.size.width * CGFloat(min(max(quotaAlleanza, 0), 1)))
                Rectangle().fill(Colori.Analisi.canaleIndipendente)
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
    }
}
