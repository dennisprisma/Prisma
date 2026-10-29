import SwiftUI


// MARK: - Pagina

/// Un foglio di dimensione fissa (A4 orizzontale o verticale), identico a schermo e nel PDF.
/// Senza sfondo indicato usa il foglio della tavolozza (bianco, o carta avorio sfumata per il report).
/// Sempre chiaro, anche con l'app in scuro; le etichette dei canali sono quelle opache da stampa.
struct FoglioDocumento<Contenuto: View>: View {
    @Environment(\.paletteDocumento) private var p
    let formato: CGSize
    var sfondo: Color? = nil
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        contenuto()
            .frame(width: formato.width, height: formato.height, alignment: .topLeading)
            .background(fondo)
            .environment(\.etichetteStampa, true)
            .environment(\.colorScheme, .light)
            .clipped()
    }

    @ViewBuilder private var fondo: some View {
        if let sfondo {
            sfondo
        } else {
            RadialGradient(colors: [p.foglio, p.foglioFine], center: UnitPoint(x: 0.2, y: 0), startRadius: 0,
                           endRadius: max(formato.width, formato.height) * 1.1)
        }
    }
}

/// Occhiello in maiuscoletto spaziato ("LA PROPOSTA").
struct OcchielloDoc: View {
    @Environment(\.paletteDocumento) private var p
    let testo: String
    var font = Tipo.Documento.occhiello
    var colore: Color? = nil

    var body: some View {
        Text(verbatim: testo.uppercased()).font(font).tracking(Misure.Documento.tracciatoOcchiello).foregroundColor(colore ?? p.occhiello)
    }
}

/// Riquadro arrotondato pieno, con il bordo e la luce della tavolozza (le schede di Prisma ne hanno).
struct RiquadroDocumento: ViewModifier {
    @Environment(\.paletteDocumento) private var p
    var colore: Color?
    var raggio: CGFloat

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: raggio).fill(colore ?? p.riquadro))
            .overlay(RoundedRectangle(cornerRadius: raggio).strokeBorder(p.riquadroBordo, lineWidth: 0.8))
            .overlay(Rectangle().fill(p.riquadroLuce).frame(height: 1).padding(.horizontal, raggio).padding(.top, 1),
                     alignment: .top)
    }
}

extension View {
    func riquadroDoc(_ colore: Color? = nil, raggio: CGFloat = Misure.Documento.raggio) -> some View {
        modifier(RiquadroDocumento(colore: colore, raggio: raggio))
    }
}

// MARK: - Tabella

struct ColonnaDoc {
    var titolo: String
    var sottotitolo = ""
    var peso: CGFloat = 1
    var destra = true
}

struct CellaDoc {
    var testo: String
    var sotto = ""
    var colore: Color? = nil
    var font: Font = Tipo.Documento.corpo
    var fontSotto: Font = Tipo.Documento.minimo
    var coloreSotto: Color? = nil
    /// Righe di testo ammesse (1 per i numeri, di più per le spiegazioni).
    var righe = 1
    /// Se c'è, la cella mostra l'etichetta compatta del canale (da stampa) al posto del testo.
    var canale: Canale? = nil

    init(_ testo: String, sotto: String = "", colore: Color? = nil, font: Font = Tipo.Documento.corpo) {
        self.testo = testo
        self.sotto = sotto
        self.colore = colore
        self.font = font
    }
}

struct RigaDoc {
    var celle: [CellaDoc]
    var altezza: CGFloat
    var sfondo: Color = .clear
    /// Filetto sotto la riga.
    var filetto: Color? = nil
    var spessore: CGFloat = 0.6
    /// Con `variabile` la riga è alta quanto il suo testo (le celle su più righe), almeno `altezza`.
    var variabile = false
}

/// Tabella a colonne pesate: testate a due righe, righe di altezza fissa, filetti sottili.
struct TabellaDoc: View {
    @Environment(\.paletteDocumento) private var p
    let larghezza: CGFloat
    let colonne: [ColonnaDoc]
    let righe: [RigaDoc]
    var fontTesta: Font = Tipo.Documento.corpoForte
    var fontTestaSotto: Font = Tipo.Documento.minimo
    var altezzaTesta: CGFloat = 30
    var filettoTesta: Color? = nil
    var margine: CGFloat = 5
    /// Colonne con fondo grigio chiaro (per esempio i totali).
    var colonneEvidenziate: Set<Int> = []

    /// Con le testate a due righe (titolo e sottotitolo) serve almeno lo spazio per entrambe:
    /// altrimenti la prima riga si rimpicciolisce.
    private var altezzaTestaEffettiva: CGFloat {
        colonne.contains(where: { !$0.sottotitolo.isEmpty }) ? max(altezzaTesta, Misure.Documento.altezzaTestaDoppia) : altezzaTesta
    }

    private var larghezze: [CGFloat] {
        let somma = colonne.reduce(0) { $0 + $1.peso }
        return colonne.map { larghezza * $0.peso / max(somma, 0.01) }
    }

    var body: some View {
        let w = larghezze
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(colonne.enumerated()), id: \.offset) { i, c in
                    VStack(alignment: c.destra ? .trailing : .leading, spacing: 1) {
                        Text(verbatim: c.titolo).font(fontTesta).foregroundColor(p.tenue).lineLimit(1).minimumScaleFactor(0.7)
                        if !c.sottotitolo.isEmpty {
                            Text(verbatim: c.sottotitolo).font(fontTestaSotto).foregroundColor(p.tenue).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    .padding(.horizontal, margine)
                    .frame(width: w[i], alignment: c.destra ? .bottomTrailing : .bottomLeading)
                }
            }
            .frame(height: altezzaTestaEffettiva, alignment: .bottom)
            .padding(.bottom, 4)
            .overlay(Rectangle().fill(filettoTesta ?? p.filettoForte).frame(height: 0.8), alignment: .bottom)
            ForEach(Array(righe.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 0) {
                    ForEach(Array(colonne.enumerated()), id: \.offset) { i, c in
                        let cella = i < r.celle.count ? r.celle[i] : CellaDoc("")
                        // Riga variabile: le celle prendono l'altezza della più alta, almeno quella indicata
                        let alta: CGFloat? = r.variabile ? nil : r.altezza
                        let minima: CGFloat? = r.variabile ? r.altezza : nil
                        let massima: CGFloat? = r.variabile ? CGFloat.infinity : nil
                        let allineamento: Alignment = c.destra ? .trailing : .leading
                        VStack(alignment: c.destra ? .trailing : .leading, spacing: 1) {
                            if let canale = cella.canale {
                                EtichettaCanale(canale: canale, compatta: true)
                            } else {
                                Text(verbatim: cella.testo).font(cella.font).foregroundColor(cella.colore ?? p.testo)
                                    .lineLimit(cella.righe).minimumScaleFactor(cella.righe > 1 ? 0.9 : 0.65)
                                    .fixedSize(horizontal: false, vertical: cella.righe > 1)
                            }
                            if !cella.sotto.isEmpty {
                                Text(verbatim: cella.sotto).font(cella.fontSotto).foregroundColor(cella.coloreSotto ?? p.tenue).lineLimit(1).truncationMode(.tail)
                            }
                        }
                        .padding(.horizontal, margine)
                        .frame(width: w[i], height: alta, alignment: allineamento)
                        .frame(minHeight: minima, maxHeight: massima, alignment: allineamento)
                        .background(colonneEvidenziate.contains(i) ? p.riquadro : Color.clear)
                    }
                }
                .fixedSize(horizontal: false, vertical: r.variabile)
                .background(r.sfondo)
                .overlay(Rectangle().fill(r.filetto ?? p.filetto).frame(height: r.spessore), alignment: .bottom)
            }
        }
        .frame(width: larghezza)
    }
}

// MARK: - Grafici

/// Una linea di scenario per i grafici.
struct LineaScenario: Identifiable {
    let tipo: TipoScenario
    /// Punti (indice sull'asse, valore).
    let punti: [(Int, Double)]
    var id: TipoScenario { tipo }
}

/// Grafico dei tre scenari: linee con i punti, il premio versato tratteggiato, etichette.
struct GraficoScenariDoc: View {
    @Environment(\.paletteDocumento) private var p
    let linee: [LineaScenario]
    let etichetteAsse: [String]
    let premio: Double
    var etichettePunti = true
    var etichetteFinali = false
    /// Prima posizione dell'asse ombreggiata (il primo anno bloccato), con la sua scritta.
    var bloccoIniziale: String? = nil
    /// Punto di partenza "oggi" collegato con un tratto punteggiato.
    var partenza: Double? = nil
    var fontAssi: Font = Tipo.Documento.piccolo
    var fontValori: Font = Tipo.Documento.minimo
    var formatoAsse: (Double) -> String = { CifreDoc.euro($0) }

    var body: some View {
        GeometryReader { geo in
            let sinistra: CGFloat = 54
            let destra: CGFloat = etichetteFinali ? 74 : 16
            let basso: CGFloat = 18
            let alto: CGFloat = 12
            let w = max(1, geo.size.width - sinistra - destra)
            let h = max(1, geo.size.height - basso - alto)
            let valori = linee.flatMap { l in l.punti.map { $0.1 } } + [premio] + (partenza.map { [$0] } ?? [])
            let passo = MisuraAsse.passo((valori.max() ?? 1) - (valori.min() ?? 0))
            let minimo = ((valori.min() ?? 0) / passo).rounded(.down) * passo
            let massimo = ((valori.max() ?? 1) / passo).rounded(.up) * passo
            let n = max(etichetteAsse.count - 1, 1)
            let x: (Int) -> CGFloat = { sinistra + CGFloat($0) / CGFloat(n) * w }
            let y: (Double) -> CGFloat = { alto + h - CGFloat(($0 - minimo) / max(massimo - minimo, 1)) * h }
            let tacche = Array(stride(from: minimo, through: massimo + 0.5, by: passo))
            ZStack(alignment: .topLeading) {
                if let blocco = bloccoIniziale {
                    Rectangle().fill(p.bloccato)
                        .frame(width: w / CGFloat(n), height: h)
                        .position(x: sinistra + w / CGFloat(n) / 2, y: alto + h / 2)
                    Text(verbatim: blocco).font(fontValori).foregroundColor(p.tenue).multilineTextAlignment(.center)
                        .frame(width: w / CGFloat(n) - 6)
                        .position(x: sinistra + w / CGFloat(n) / 2, y: alto + 18)
                }
                ForEach(Array(tacche.enumerated()), id: \.offset) { _, v in
                    Path { p in
                        p.move(to: CGPoint(x: sinistra, y: y(v)))
                        p.addLine(to: CGPoint(x: sinistra + w, y: y(v)))
                    }
                    .stroke(p.griglia, lineWidth: 0.7)
                    Text(verbatim: formatoAsse(v)).font(fontAssi).foregroundColor(p.tenue)
                        .frame(width: sinistra - 6, alignment: .trailing)
                        .position(x: (sinistra - 6) / 2, y: y(v))
                }
                ForEach(Array(etichetteAsse.enumerated()), id: \.offset) { i, s in
                    Text(verbatim: s).font(fontAssi).foregroundColor(p.tenue).lineLimit(1).fixedSize()
                        .position(x: x(i), y: geo.size.height - basso / 2 + 2)
                }
                Path { p in
                    p.move(to: CGPoint(x: sinistra, y: y(premio)))
                    p.addLine(to: CGPoint(x: sinistra + w, y: y(premio)))
                }
                .stroke(p.premio, style: StrokeStyle(lineWidth: 0.9, dash: [4, 3]))
                Text(verbatim: "premio versato \(CifreDoc.euro(premio))").font(fontValori).foregroundColor(p.tenue)
                    .fixedSize()
                    .position(x: sinistra + w - 50, y: y(premio) - 8)
                ForEach(linee) { l in
                    let colore = p.scenario(l.tipo)
                    if let partenza, let primo = l.punti.first {
                        Path { p in
                            p.move(to: CGPoint(x: x(0), y: y(partenza)))
                            p.addLine(to: CGPoint(x: x(primo.0), y: y(primo.1)))
                        }
                        .stroke(colore, style: StrokeStyle(lineWidth: 1.2, dash: [1.5, 2.5]))
                    }
                    Path { p in
                        for (i, pt) in l.punti.enumerated() {
                            let q = CGPoint(x: x(pt.0), y: y(pt.1))
                            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
                        }
                    }
                    .stroke(colore, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
                    ForEach(Array(l.punti.enumerated()), id: \.offset) { _, pt in
                        Circle().fill(colore).overlay(Circle().stroke(Color.white, lineWidth: 1))
                            .frame(width: 7, height: 7)
                            .position(x: x(pt.0), y: y(pt.1))
                        if etichettePunti {
                            Text(verbatim: Formati.numeroFormatter.string(from: NSNumber(value: pt.1.rounded())) ?? "")
                                .font(fontValori.weight(.bold)).foregroundColor(colore).fixedSize()
                                .position(x: x(pt.0), y: y(pt.1) + (l.tipo == .sfavorevole ? 11 : -11))
                        }
                    }
                    if etichetteFinali, let ultimo = l.punti.last {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: l.tipo.nome).font(fontValori.weight(.bold))
                            Text(verbatim: CifreDoc.euro(ultimo.1)).font(fontValori.weight(.bold))
                        }
                        .foregroundColor(colore).fixedSize()
                        .position(x: x(ultimo.0) + 36, y: y(ultimo.1))
                    }
                }
            }
        }
    }
}

/// Una serie del grafico a linee libere: nome, colore e valori per ogni posizione dell'asse.
struct SerieDoc: Identifiable {
    let nome: String
    let colore: Color
    let valori: [Double]
    var tratteggio = false
    var id: String { nome }
}

/// Grafico a linee per due (o più) strade: assi, griglia, punti, nome e valore finale a destra.
/// Una linea verticale punteggiata segna, se c'è, l'anno di pareggio.
struct GraficoLineeDoc: View {
    @Environment(\.paletteDocumento) private var p
    @Environment(\.documentoInSala) private var inSala
    let serie: [SerieDoc]
    let etichetteAsse: [String]
    var pareggio: Int? = nil
    var fontAssi: Font = Tipo.Documento.piccolo
    var fontValori: Font = Tipo.Documento.minimo

    var body: some View {
        GeometryReader { geo in
            let sinistra: CGFloat = 54
            let destra: CGFloat = 86
            let basso: CGFloat = 18
            // Con l'anno di pareggio serve spazio sopra il grafico per la sua scritta
            let alto: CGFloat = pareggio == nil ? 12 : 18
            let w = max(1, geo.size.width - sinistra - destra)
            let h = max(1, geo.size.height - basso - alto)
            let valori = serie.flatMap(\.valori)
            let passo = MisuraAsse.passo((valori.max() ?? 1) - (valori.min() ?? 0))
            let minimo = ((valori.min() ?? 0) / passo).rounded(.down) * passo
            let massimo = ((valori.max() ?? 1) / passo).rounded(.up) * passo
            let n = max(etichetteAsse.count - 1, 1)
            let x: (Int) -> CGFloat = { sinistra + CGFloat($0) / CGFloat(n) * w }
            let y: (Double) -> CGFloat = { alto + h - CGFloat(($0 - minimo) / max(massimo - minimo, 1)) * h }
            let tacche = Array(stride(from: minimo, through: massimo + 0.5, by: passo))
            let etichette = GraficoLineeDoc.altezzeEtichette(serie.map { y($0.valori.last ?? 0) }, distanza: 20)
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
                ForEach(Array(etichetteAsse.enumerated()), id: \.offset) { i, s in
                    Text(verbatim: s).font(fontAssi).foregroundColor(p.tenue).lineLimit(1).fixedSize()
                        .position(x: x(i), y: geo.size.height - basso / 2 + 2)
                }
                if let pareggio, pareggio <= n {
                    Path { q in
                        q.move(to: CGPoint(x: x(pareggio), y: alto))
                        q.addLine(to: CGPoint(x: x(pareggio), y: alto + h))
                    }
                    .stroke(p.tenue, style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                    Text(verbatim: "pareggio").font(fontValori).foregroundColor(p.tenue).fixedSize()
                        .position(x: x(pareggio), y: alto - 7)
                }
                ForEach(Array(serie.enumerated()), id: \.offset) { indice, s in
                    Path { q in
                        for (i, v) in s.valori.enumerated() {
                            let pt = CGPoint(x: x(i), y: y(v))
                            if i == 0 { q.move(to: pt) } else { q.addLine(to: pt) }
                        }
                    }
                    .stroke(s.colore, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round, dash: s.tratteggio ? [5, 3] : []))
                    ForEach(Array(s.valori.enumerated()), id: \.offset) { i, v in
                        Circle().fill(s.colore).overlay(Circle().stroke(Color.white, lineWidth: 1))
                            .frame(width: 6, height: 6)
                            .position(x: x(i), y: y(v))
                    }
                    if let ultimo = s.valori.last {
                        // In sala: corpo più grande e il nome nell'inchiostro del testo (la cifra resta nel colore della linea)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: s.nome).font(inSala ? Tipo.Report.etichettaFinaleSala : fontValori.weight(.bold)).lineLimit(1)
                                .minimumScaleFactor(inSala ? 0.8 : 1)
                                .foregroundColor(inSala ? p.testo : s.colore)
                            Text(verbatim: CifreDoc.euro(ultimo)).font(inSala ? Tipo.Report.etichettaFinaleSala : fontValori.weight(.bold))
                                .foregroundColor(s.colore)
                        }
                        .frame(width: destra - 8, alignment: .leading)
                        .position(x: x(s.valori.count - 1) + 6 + (destra - 8) / 2, y: etichette[indice])
                    }
                }
            }
        }
    }

    /// Le altezze delle etichette finali, allontanate quando le linee finiscono vicine.
    static func altezzeEtichette(_ altezze: [CGFloat], distanza: CGFloat) -> [CGFloat] {
        let ordine = altezze.indices.sorted { altezze[$0] < altezze[$1] }
        var risultato = altezze
        for k in 1..<max(ordine.count, 1) where risultato[ordine[k]] - risultato[ordine[k - 1]] < distanza {
            risultato[ordine[k]] = risultato[ordine[k - 1]] + distanza
        }
        return risultato
    }
}

/// Scelta del passo dell'asse dei valori (1, 2, 2,5 o 5 per potenze di 10).
enum MisuraAsse {
    static func passo(_ intervallo: Double, tacche: Double = 5) -> Double {
        let grezzo = max(intervallo, 1) / tacche
        let potenza = pow(10, (log10(grezzo)).rounded(.down))
        for m in [1.0, 2.0, 2.5, 5.0, 10.0] where grezzo <= m * potenza { return m * potenza }
        return 10 * potenza
    }
}

/// Barre verticali con il valore sopra (rendimenti storici).
struct GraficoBarreDoc: View {
    @Environment(\.paletteDocumento) private var p
    let punti: [(String, Double)]
    var colore: Color? = nil
    var fontValori: Font = Tipo.Documento.corpoForte
    var fontAssi: Font = Tipo.Documento.piccolo
    var formato: (Double) -> String = { CifreDoc.percento($0, decimali: 2) }

    var body: some View {
        GeometryReader { geo in
            let basso: CGFloat = 20
            let alto: CGFloat = 22
            let h = geo.size.height - basso - alto
            let massimo = max(punti.map { $0.1 }.max() ?? 1, 0.01)
            let larghezza = geo.size.width / CGFloat(max(punti.count, 1))
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(punti.enumerated()), id: \.offset) { _, punto in
                    VStack(spacing: 4) {
                        Text(verbatim: formato(punto.1)).font(fontValori).foregroundColor(p.titolo).fixedSize()
                        Rectangle().fill(colore ?? p.gestioneSeparata)
                            .frame(width: larghezza * 0.62, height: max(1, h * CGFloat(punto.1 / massimo)))
                        Text(verbatim: punto.0).font(fontAssi).foregroundColor(p.tenue).frame(height: basso - 4)
                    }
                    .frame(width: larghezza)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .overlay(Rectangle().fill(p.filetto).frame(height: 0.8).padding(.bottom, basso), alignment: .bottom)
        }
    }
}

/// Grafico a cascata "dove va il denaro".
struct GraficoCascataDoc: View {
    @Environment(\.paletteDocumento) private var p
    let voci: [VoceCascata]
    var fontValori: Font = Tipo.Documento.pTabellaForte
    var fontAssi: Font = Tipo.Documento.pAssi

    var body: some View {
        GeometryReader { geo in
            let sinistra: CGFloat = 44
            let basso: CGFloat = 26
            let alto: CGFloat = 14
            let w = geo.size.width - sinistra
            let h = geo.size.height - basso - alto
            let livelli = progressione()
            let tutti = livelli.flatMap { [$0.0, $0.1] }
            let passo = MisuraAsse.passo((tutti.max() ?? 1) - (tutti.min() ?? 0), tacche: 3)
            let minimo = ((tutti.min() ?? 0) / passo).rounded(.down) * passo - passo / 2
            let massimo = ((tutti.max() ?? 1) / passo).rounded(.up) * passo
            let y: (Double) -> CGFloat = { alto + h - CGFloat(($0 - minimo) / max(massimo - minimo, 1)) * h }
            let colonna = w / CGFloat(max(voci.count, 1))
            ZStack(alignment: .topLeading) {
                ForEach(Array(stride(from: (minimo / passo).rounded(.up) * passo, through: massimo, by: passo).enumerated()), id: \.offset) { _, v in
                    Path { p in
                        p.move(to: CGPoint(x: sinistra, y: y(v)))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y(v)))
                    }
                    .stroke(p.griglia, lineWidth: 0.6)
                    Text(verbatim: CifreDoc.euro(v)).font(fontAssi).foregroundColor(p.tenue)
                        .frame(width: sinistra - 4, alignment: .trailing)
                        .position(x: (sinistra - 4) / 2, y: y(v))
                }
                ForEach(Array(voci.enumerated()), id: \.offset) { i, voce in
                    let livello = livelli[i]
                    let cx = sinistra + colonna * (CGFloat(i) + 0.5)
                    let top = y(max(livello.0, livello.1))
                    let bottom = y(min(livello.0, livello.1))
                    Rectangle().fill(colore(voce.genere))
                        .frame(width: colonna * 0.6, height: max(1.2, bottom - top))
                        .position(x: cx, y: (top + bottom) / 2)
                    Text(verbatim: etichettaValore(voce)).font(fontValori)
                        .foregroundColor(voce.genere == .partenza || voce.genere == .arrivo || voce.genere == .subtotale ? p.titolo : p.tenue)
                        .fixedSize()
                        .position(x: cx, y: top - 7)
                    Text(verbatim: voce.etichetta).font(fontAssi).foregroundColor(p.tenue).multilineTextAlignment(.center)
                        .frame(width: colonna - 4)
                        .position(x: cx, y: geo.size.height - basso / 2)
                }
            }
        }
    }

    /// Per ogni voce, il livello di partenza e di arrivo della barra.
    private func progressione() -> [(Double, Double)] {
        var livello = 0.0
        return voci.map { v -> (Double, Double) in
            switch v.genere {
            case .partenza, .subtotale, .arrivo:
                livello = v.importo
                return (baseAsse, v.importo)
            case .piu, .meno:
                let da = livello
                livello += v.importo
                return (da, livello)
            }
        }
    }

    /// Le barre dei totali partono poco sotto il minimo, come nel prospetto (l'asse non parte da zero).
    private var baseAsse: Double {
        var livello = 0.0
        var minimo = Double.greatestFiniteMagnitude
        for v in voci {
            switch v.genere {
            case .partenza, .subtotale, .arrivo: livello = v.importo
            case .piu, .meno: livello += v.importo
            }
            minimo = min(minimo, livello)
        }
        return minimo - max(1_000, minimo * 0.03)
    }

    private func colore(_ g: VoceCascata.Genere) -> Color {
        switch g {
        case .partenza, .subtotale: return p.cascataTotale
        case .arrivo: return p.intermedio
        case .piu: return p.cascataPiu
        case .meno: return p.cascataMeno
        }
    }

    private func etichettaValore(_ v: VoceCascata) -> String {
        switch v.genere {
        case .partenza, .subtotale, .arrivo: return CifreDoc.euro(v.importo)
        case .piu, .meno: return CifreDoc.euroSegno(v.importo)
        }
    }
}
