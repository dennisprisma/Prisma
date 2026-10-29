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
    /// Assi dei grafici: intervalli dell'asse dei valori, distanza minima tra due etichette dell'asse
    /// orizzontale e quanto sale l'etichetta della tacca più bassa, così non tocca la prima data.
    static let taccheAsse: Double = 4
    static let distanzaEtichette: CGFloat = 48
    static let alzataPrimaTacca: CGFloat = 6
    /// Linea dell'atteso nel grafico dell'andamento: spessore e tratti (quelli della legenda tratteggiata).
    static let lineaAtteso: CGFloat = 1.6
    static let trattiAtteso: [CGFloat] = [4, 3]
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

/// Controllo a segmenti delle app di analisi: voci di larghezza uguale finché ogni voce si legge intera.
/// Se lo spazio non basta le voci prendono la larghezza del loro testo, poi la versione compatta
/// (come le schede della rubrica): mai una parola tagliata a metà finché c'è un modo di scriverla intera.
struct SegmentiAnalisi<Valore: Hashable>: View {
    let opzioni: [(Valore, String)]
    @Binding var selezione: Valore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            uguali(compatto: false)
            testo(compatto: false)
            uguali(compatto: true)
            testo(compatto: true)
            // Ultima risorsa: la versione compatta che si stringe nello spazio che c'è
            ControlloSegmenti(opzioni: opzioni, selezione: $selezione, riempi: true, compatto: true)
        }
    }

    /// Voci di larghezza uguale. La larghezza ideale è quella della voce più lunga (scritta come scelta)
    /// ripetuta per tutte: copie nascoste la misurano, così il controllo si sceglie solo se nessuna voce si taglia.
    private func uguali(compatto: Bool) -> some View {
        let quante = opzioni.count
        return ZStack {
            ForEach(Array(opzioni.enumerated()), id: \.offset) { _, opzione in
                HStack(spacing: 0) {
                    ForEach(0..<quante, id: \.self) { _ in
                        ControlloSegmenti(opzioni: [opzione], selezione: .constant(opzione.0), compatto: compatto)
                    }
                }
                .fixedSize()
                .hidden()
            }
        }
        .frame(maxWidth: .infinity)
        .overlay {
            ControlloSegmenti(opzioni: opzioni, selezione: $selezione, riempi: true, compatto: compatto)
        }
    }

    /// Voci larghe quanto il loro testo, allineate a sinistra.
    private func testo(compatto: Bool) -> some View {
        ControlloSegmenti(opzioni: opzioni, selezione: $selezione, compatto: compatto)
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Voce della barra laterale (.side-item): fondo leggero al passaggio, accento al 17% se scelta.
/// Il titolo lungo va a capo su due righe invece di troncarsi; la voce scelta porta `idScelta`,
/// così l'elenco laterale della cornice la porta in vista all'apertura.
struct VoceNavigazione: View {
    let titolo: String
    var colore: Color? = nil
    var conteggio: Int? = nil
    let attiva: Bool
    let azione: () -> Void

    /// L'id della voce scelta (sta su un fondo trasparente, non sulla voce: la voce non cambia identità).
    static let idScelta = "voce-navigazione-scelta"

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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
        .background {
            if attiva { Color.clear.id(Self.idScelta) }
        }
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
/// Tacche tonde (0, 20k, 40k…), anni diradati perché non si tocchino; senza cifre da disegnare
/// (tutte le serie a zero) al posto del grafico c'è una riga con `vuoto`.
struct GraficoProiezione: View {
    struct Serie: Identifiable {
        let id: String
        let punti: [PuntoProiezione]
        let colore: Color
        var principale = false
    }

    let serie: [Serie]
    /// La riga al posto del grafico quando non c'è nulla da disegnare.
    var vuoto: String = "Nessuna cifra da disegnare: il grafico compare con il primo versamento"

    /// Tutte le serie a zero (nessun capitale né versamento): il grafico sarebbe solo l'asse.
    private var senzaCifre: Bool {
        !serie.flatMap(\.punti).contains { abs($0.valore) >= 0.5 || abs($0.versato) >= 0.5 }
    }

    var body: some View {
        if senzaCifre {
            NotaMetodo(testo: vuoto)
        } else {
            grafico
        }
    }

    private var grafico: some View {
        GeometryReader { geo in
            let m = Tema.Misura.Componenti.self
            let sinistra = m.graficoSinistra
            let basso = m.graficoBasso
            let w = max(1, geo.size.width - sinistra - 6)
            let h = max(1, geo.size.height - basso - 6)
            let tutti = serie.flatMap(\.punti)
            // Un patrimonio negativo (debiti oltre le attività) resta dentro il grafico
            let scala = AsseGrafico.scala(minimo: tutti.map { min($0.valore, $0.versato) }.min() ?? 0,
                                          massimo: tutti.map { max($0.valore, $0.versato) }.max() ?? 0)
            let anni = max(tutti.map(\.anno).max() ?? 1, 1)
            let x: (Int) -> CGFloat = { sinistra + CGFloat($0) / CGFloat(anni) * w }
            let y: (Double) -> CGFloat = { 6 + h - CGFloat(($0 - scala.minimo) / (scala.massimo - scala.minimo)) * h }
            let etichette = AsseGrafico.diradate(etichetteAsse(anni, x: x))
            ZStack(alignment: .topLeading) {
                // Griglia orizzontale ed etichette dell'asse dei valori
                ForEach(Array(scala.tacche.enumerated()), id: \.offset) { i, v in
                    Path { p in
                        p.move(to: CGPoint(x: sinistra, y: y(v)))
                        p.addLine(to: CGPoint(x: sinistra + w, y: y(v)))
                    }
                    .stroke(Tema.Colore.separatore, lineWidth: 1)
                    AsseGrafico.etichettaValore(v)
                        .frame(width: sinistra - 6, alignment: .trailing)
                        .position(x: (sinistra - 6) / 2, y: y(v) - (i == 0 ? m.alzataPrimaTacca : 0))
                }
                // Etichette degli anni: la prima parte dal bordo sinistro, l'ultima finisce sul destro
                ForEach(Array(etichette.enumerated()), id: \.offset) { _, e in
                    AsseGrafico.etichettaData(e.testo, x: e.x, da: sinistra, a: sinistra + w)
                        .position(x: e.x, y: geo.size.height - basso / 2)
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
                            .frame(width: m.puntoGrafico, height: m.puntoGrafico)
                            .position(x: x(ultimo.anno), y: y(ultimo.valore))
                    }
                }
            }
        }
        .frame(height: Misure.Analisi.grafico)
    }

    /// Gli anni sull'asse (al più sette, l'ultimo sempre), con la loro posizione.
    private func etichetteAsse(_ anni: Int, x: (Int) -> CGFloat) -> [(testo: String, x: CGFloat)] {
        let passo = max(1, Int((Double(anni) / 6).rounded(.up)))
        var elenco = Array(stride(from: 0, through: anni, by: passo))
        if elenco.last != anni { elenco.append(anni) }
        return elenco.map { a -> (testo: String, x: CGFloat) in (testo: a == 0 ? "Oggi" : "+\(a) a", x: x(a)) }
    }
}

/// Assi dei grafici dell'app (proiezione e andamento): tacche tonde, etichette che non si toccano.
enum AsseGrafico {
    /// Scala dell'asse dei valori: dallo zero (o dal minimo, se negativo) a un massimo tondo,
    /// con un passo tondo (1, 2, 2,5 o 5 per una potenza di dieci) e al più cinque intervalli.
    struct Scala {
        let minimo: Double
        let massimo: Double
        let passo: Double
        var tacche: [Double] { Array(stride(from: minimo, through: massimo + passo / 1_000, by: passo)) }
    }

    static func scala(minimo grezzoMinimo: Double, massimo grezzoMassimo: Double) -> Scala {
        let basso = min(grezzoMinimo, 0)
        let alto = max(grezzoMassimo, 0)
        // Mai meno di un euro di passo: niente «1 € / 1 € / 1 €» sull'asse
        let passo = max(MisuraAsse.passo(alto - basso, tacche: Tema.Misura.Componenti.taccheAsse), 1)
        let minimo = (basso / passo).rounded(.down) * passo
        let massimo = max((alto / passo).rounded(.up) * passo, minimo + passo)
        return Scala(minimo: minimo, massimo: massimo, passo: passo)
    }

    /// «40k €», «2,5k €», «1,2 mln €», «500 €»: abbastanza cifre da non ripetere due tacche uguali.
    static func testoValore(_ v: Double) -> String {
        let migliaia = v / 1_000
        if abs(v) >= 1_000, abs(v) < 1_000_000, abs(migliaia - migliaia.rounded()) > 0.001 {
            return "\(Formati.numeroFormatter.string(from: NSNumber(value: migliaia)) ?? "")k €"
        }
        return Formati.euroBreve(v)
    }

    static func etichettaValore(_ v: Double) -> some View {
        Text(testoValore(v))
            .font(Tema.Testo.Componenti.asse)
            .foregroundColor(Tema.Colore.inchiostroTerziario)
            .lineLimit(1)
    }

    /// Etichetta dell'asse orizzontale: quella sul bordo sinistro del grafico parte dal suo punto, quella
    /// sul bordo destro vi finisce, le altre sono centrate (`position` mette il centro della cornice,
    /// larga zero, sul punto). Così «Oggi» non tocca la cifra dello zero e «+10 a» non esce dal bordo.
    static func etichettaData(_ testo: String, x: CGFloat, da sinistra: CGFloat, a destra: CGFloat) -> some View {
        let allineamento: Alignment = x <= sinistra + 0.5 ? .leading : (x >= destra - 0.5 ? .trailing : .center)
        return Text(testo)
            .font(Tema.Testo.Componenti.asse)
            .foregroundColor(Tema.Colore.inchiostroTerziario)
            .lineLimit(1)
            .fixedSize()
            .frame(width: 0, alignment: allineamento)
    }

    /// Dirada le etichette dell'asse orizzontale: toglie i doppioni (lo stesso «ott 26» due volte) e quelle
    /// più vicine di `distanzaEtichette` alla precedente. L'ultima resta sempre: si toglie quella prima.
    static func diradate(_ elenco: [(testo: String, x: CGFloat)]) -> [(testo: String, x: CGFloat)] {
        let distanza = Tema.Misura.Componenti.distanzaEtichette
        guard let ultima = elenco.last else { return [] }
        var tenute: [(testo: String, x: CGFloat)] = []
        for e in elenco.dropLast() {
            if let precedente = tenute.last, precedente.testo == e.testo || e.x - precedente.x < distanza { continue }
            tenute.append(e)
        }
        while let precedente = tenute.last, precedente.testo == ultima.testo || ultima.x - precedente.x < distanza {
            tenute.removeLast()
        }
        return tenute + [ultima]
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
