import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report del piano obiettivo: A4 orizzontale, per il cliente. Il traguardo, dove sei oggi,
/// dove arrivi così, le strade per arrivarci, gli scenari, la sintesi.
enum ReportObiettivo {
    static func pagine(_ t: TestiObiettivo, commento: String? = nil) -> [AnyView] {
        var slide: [AnyView] = [AnyView(SlideTraguardo(t: t)), AnyView(SlideArrivoObiettivo(t: t))]
        if !t.e.strade.isEmpty { slide.append(AnyView(SlideStradeObiettivo(t: t))) }
        slide.append(AnyView(SlideScenariObiettivo(t: t)))
        if let mc = ProspettoObiettivo.probabilita(t) { slide.append(AnyView(SlideProbabilitaObiettivo(t: t, mc: mc))) }
        slide.append(AnyView(SlideSintesiObiettivo(t: t)))
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(t.o.titolo) · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiObiettivo) -> CopertinaReport {
        let e = t.e
        let cartellini: [(String, [String])] = [("Il traguardo", [CifreDoc.euro(t.o.importo), "entro il \(CifreDoc.dataBreve(t.o.scadenza))"]),
                                                ("Da parte oggi", [CifreDoc.euro(e.disponibileOggi)]),
                                                ("Si arriva al", [CifreDoc.percento(e.copertura * 100, decimali: 0)])]
        return CopertinaReport(occhiello: "Piano obiettivo · \(t.o.area.nome)", titolo: t.o.titolo,
                               sottotitolo: "Dove sei oggi, dove arrivi e come raggiungere il traguardo in tempo",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data,
                               canali: t.canali.isEmpty ? [.indipendente] : t.canali, cartellini: cartellini)
    }
}

private struct CifraObiettivo: View {
    @Environment(\.paletteDocumento) private var C
    let etichetta: String
    let valore: String
    var nota = ""
    var colore: Color? = nil
    var font = Tipo.Report.numeroMedio

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: etichetta).font(T.piccolo).foregroundColor(C.tenue).lineLimit(1).minimumScaleFactor(0.8)
            Text(verbatim: valore).font(font).foregroundColor(colore ?? C.titolo).lineLimit(1).minimumScaleFactor(0.6)
            if !nota.isEmpty {
                Text(verbatim: nota).font(T.minimo).foregroundColor(C.tenue).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroDoc()
    }
}

// MARK: - Il traguardo e dove sei oggi

private struct SlideTraguardo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo

    var body: some View {
        let e = t.e
        let quota = e.importoOggi > 0 ? min(1, e.disponibileOggi / e.importoOggi) : 1
        return VStack(alignment: .leading, spacing: 18) {
            TestaReport(occhiello: "Il traguardo", titolo: t.titoloOggi,
                        sottotitolo: "L'obiettivo: \(CifreDoc.euro(t.o.importo)) entro il \(CifreDoc.data(t.o.scadenza)), \(t.quando)." + (t.o.note.isEmpty ? "" : " \(t.o.note)"))
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(C.griglia)
                        RoundedRectangle(cornerRadius: 4).fill(C.area(.risparmio)).frame(width: max(4, geo.size.width * CGFloat(quota)))
                        Text(verbatim: CifreDoc.percento(quota * 100, decimali: 0)).font(T.numeroPiccolo).foregroundColor(.white).padding(.leading, 12)
                    }
                }
                .frame(height: 38)
                HStack {
                    Text(verbatim: "Da parte oggi \(CifreDoc.euro(e.disponibileOggi))").font(T.piccolo).foregroundColor(C.testo)
                    Spacer()
                    Text(verbatim: "Obiettivo \(CifreDoc.euro(e.importoOggi))").font(T.piccolo).foregroundColor(C.testo)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                CifraObiettivo(etichetta: "Obiettivo in euro di oggi", valore: CifreDoc.euro(e.importoOggi))
                CifraObiettivo(etichetta: "Quanto varrà alla scadenza", valore: CifreDoc.euro(e.importoScadenza),
                               nota: "con un'inflazione del \(CifreDoc.condizione(IpotesiCalcolo.inflazione)) l'anno")
                CifraObiettivo(etichetta: "Versi già ogni mese", valore: CifreDoc.euro(e.versamentiAttivi), nota: "sulle posizioni collegate")
            }
            if !e.contributi.isEmpty {
                HStack(spacing: 8) {
                    ForEach(e.contributi.prefix(3)) { c in
                        HStack(spacing: 8) {
                            EtichettaCanale(canale: c.posizione.canale)
                            Text(verbatim: "\(c.posizione.nome) · \(CifreDoc.euro(c.valoreOggi))").font(T.piccolo).foregroundColor(C.testo).lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Dove arrivi così

private struct SlideArrivoObiettivo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo

    var body: some View {
        let e = t.e
        var serie = [SerieDoc(nome: "Obiettivo", colore: C.titolo, valori: e.serieObiettivo, tratteggio: true),
                     SerieDoc(nome: "Così", colore: C.premio, valori: e.serieAttuale)]
        if e.versamentoNecessario != nil { serie.append(SerieDoc(nome: "Con il versamento", colore: C.intermedio, valori: e.serieConVersamento)) }
        return VStack(alignment: .leading, spacing: 12) {
            TestaReport(occhiello: "Dove arrivi così", titolo: t.titoloArrivo, sottotitolo: t.sottotitoloArrivo)
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    CifraObiettivo(etichetta: "Alla scadenza", valore: CifreDoc.euro(e.proiezione), font: T.numeroGrande)
                    CifraObiettivo(etichetta: "Obiettivo rivalutato", valore: CifreDoc.euro(e.importoScadenza))
                    CifraObiettivo(etichetta: e.mancante > 0.5 ? "Mancano" : "Margine", valore: CifreDoc.euro(abs(e.importoScadenza - e.proiezione)),
                                   colore: e.mancante > 0.5 ? C.negativo : C.positivo)
                }
                .frame(width: 210)
                GraficoLineeDoc(serie: serie, etichetteAsse: (0..<e.serieAttuale.count).map { $0 == 0 ? "oggi" : "\($0)° anno" },
                                fontAssi: T.minimo, fontValori: T.minimo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Le strade per arrivarci

private struct SlideStradeObiettivo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Le strade per arrivarci", titolo: "Quattro modi per colmare \(CifreDoc.euro(t.e.mancante))",
                        sottotitolo: "Si possono anche combinare: per esempio un piccolo versamento ogni mese e qualche mese in più.")
            HStack(alignment: .top, spacing: 12) {
                ForEach(t.e.strade) { s in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verbatim: s.titolo.uppercased()).font(T.occhiello).tracking(1.4).foregroundColor(C.occhiello)
                        Text(verbatim: s.valore).font(T.numeroMedio).foregroundColor(C.intermedio).lineLimit(1).minimumScaleFactor(0.6)
                        Text(verbatim: s.spiegazione).font(T.piccolo).foregroundColor(C.testo).lineSpacing(1.3).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .riquadroDoc(s.tipo == .mensile ? C.evidenza : nil)
                }
            }
        }
    }
}

// MARK: - Scenari

private struct SlideScenariObiettivo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Se i mercati vanno diversamente", titolo: t.tenuta,
                        sottotitolo: "Con ciò che hai oggi, con 2 punti di rendimento in meno o in più.")
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(t.e.scenari.enumerated()), id: \.offset) { _, s in
                    let colore = s.scarto < 0 ? C.sfavorevole : (s.scarto > 0 ? C.favorevole : C.intermedio)
                    let tipo: TipoScenario = s.scarto < 0 ? .sfavorevole : (s.scarto > 0 ? .favorevole : .intermedio)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verbatim: s.nome).font(T.scenarioTitolo).foregroundColor(colore)
                        Text(verbatim: CifreDoc.euro(s.proiezione)).font(T.scenarioRendimento).foregroundColor(colore)
                        Text(verbatim: "il \(CifreDoc.percento(min(100, s.proiezione / max(t.e.importoScadenza, 1) * 100), decimali: 0)) dell'obiettivo")
                            .font(T.piccolo).foregroundColor(C.testo)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: D.raggio).fill(C.scenarioFondo(tipo)))
                    .riquadroDoc(.clear)
                }
            }
        }
    }
}

// MARK: - Scenari con le probabilità

private struct SlideProbabilitaObiettivo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo
    let mc: EsitoMonteCarlo

    private typealias M = Misure.Documento.Motori

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Le probabilità", titolo: titolo,
                        sottotitolo: "Abbiamo provato \(Formati.numeroFormatter.string(from: NSNumber(value: mc.traiettorie)) ?? "") percorsi possibili dei mercati, con alti e bassi come in passato. È una stima, non una promessa: serve a capire quanto margine hai.")
            HStack(alignment: .top, spacing: M.spazioRiquadri) {
                VStack(spacing: 8) {
                    CifraObiettivo(etichetta: "Probabilità di arrivarci", valore: "\(mc.suDieci) su 10",
                                   nota: "il traguardo vale \(CifreDoc.euro(mc.traguardo)) alla scadenza", colore: coloreProbabilita, font: T.numeroGrande)
                    CifraObiettivo(etichetta: "Se va male (1 caso su 10)", valore: CifreDoc.euro(mc.p10), colore: C.sfavorevole)
                    CifraObiettivo(etichetta: "Nel caso di mezzo", valore: CifreDoc.euro(mc.p50), colore: C.intermedio)
                    CifraObiettivo(etichetta: "Se va bene (1 caso su 10)", valore: CifreDoc.euro(mc.p90), colore: C.favorevole)
                }
                .frame(width: M.colonnaLateraleReport)
                GraficoVentaglioDoc(anni: mc.anni, traguardo: mc.traguardo, fontAssi: T.minimo, fontValori: T.minimo)
                    .frame(maxWidth: .infinity)
                    .frame(height: M.graficoVentaglioReport)
            }
            Text(verbatim: "La fascia colorata contiene 8 percorsi su 10; la linea è quello di mezzo. Importi al netto delle imposte alla scadenza; nel grafico, valori prima delle imposte. Rendimenti non garantiti.")
                .font(T.minimo).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var titolo: String {
        switch mc.suDieci {
        case 10: return "In quasi tutti i percorsi possibili arrivi al traguardo"
        case 0: return "Così, in quasi nessun percorso arrivi al traguardo"
        default: return "In \(mc.suDieci) percorsi su 10 arrivi al traguardo"
        }
    }

    private var coloreProbabilita: Color {
        mc.suDieci >= 7 ? C.positivo : (mc.suDieci >= 4 ? C.intermedio : C.negativo)
    }
}

// MARK: - In sintesi

private struct SlideSintesiObiettivo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "\(t.o.titolo), in poche righe")
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    ForEach(Array(punti.enumerated()), id: \.offset) { i, p in
                        HStack(alignment: .center, spacing: 16) {
                            Text(verbatim: "\(i + 1)").font(T.sintesiNumero).foregroundColor(C.titolo).frame(width: 28)
                            (Text(verbatim: "\(p.0). ").bold() + Text(verbatim: p.1))
                                .font(T.corpo).foregroundColor(C.titolo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .riquadroDoc()
                    }
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 9) {
                    Text(verbatim: "Prossimi passi").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                    ForEach(Array(t.prossimiPassi.enumerated()), id: \.offset) { _, passo in
                        HStack(alignment: .top, spacing: 7) {
                            Text(verbatim: "→").font(T.corpoForte).foregroundColor(C.evidenzaTitolo)
                            Text(verbatim: passo).font(T.piccolo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(18)
                .frame(width: 250, alignment: .topLeading)
                .riquadroDoc(C.evidenza)
            }
            Spacer(minLength: 0)
            (Text(verbatim: "Come leggere i numeri. ").bold()
             + Text(verbatim: "Importi al netto di costi e imposte sul guadagno; l'obiettivo è rivalutato all'inflazione ipotizzata. " + TestiObiettivo.avvertenza))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
