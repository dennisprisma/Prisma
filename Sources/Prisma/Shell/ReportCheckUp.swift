import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report del check-up del primo incontro: A4 orizzontale, per il cliente.
enum ReportCheckUp {
    /// `ipotesi`: i dati da completare del cliente; quelli con il testo per il cliente vanno nella slide
    /// «Le ipotesi da confermare insieme», subito prima della sintesi.
    static func pagine(_ t: TestiCheckUp, commento: String? = nil, ipotesi: [VoceCompletezza] = []) -> [AnyView] {
        var slide: [AnyView] = [AnyView(SlideChiSei(t: t)), AnyView(SlideFotografia(t: t)), AnyView(SlideSemaforo(t: t)),
                                AnyView(SlidePartire(t: t))]
        slide += SlideIpotesiStimate.slide(ipotesi)
        slide.append(AnyView(SlideSintesiCheckUp(t: t)))
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(TestiCheckUp.titolo) · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiCheckUp) -> CopertinaReport {
        let e = t.e
        let cartellini: [(String, [String])] = [("Patrimonio netto", [CifreDoc.euro(e.riepilogo.patrimonioNetto)]),
                                                ("Il semaforo", ["\(e.verdi.count) in ordine", "\(e.gialli.count) da migliorare",
                                                                  "\(e.rossi.count) da affrontare"]),
                                                ("Da dove partire", [e.daAffrontare.first?.titolo ?? "Tutto in ordine"])]
        return CopertinaReport(occhiello: "Primo incontro", titolo: "Il tuo check-up",
                               sottotitolo: "Una prima fotografia: cosa hai, cosa è in ordine e da dove partire insieme",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data, canali: t.canali, cartellini: cartellini)
    }
}

private struct CifraCheck: View {
    @Environment(\.paletteDocumento) private var C
    let etichetta: String
    let valore: String
    var nota = ""
    var colore: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: etichetta).font(T.piccolo).foregroundColor(C.tenue).lineLimit(1).minimumScaleFactor(0.8)
            Text(verbatim: valore).font(T.numeroMedio).foregroundColor(colore ?? C.titolo).lineLimit(1).minimumScaleFactor(0.6)
            if !nota.isEmpty { Text(verbatim: nota).font(T.minimo).foregroundColor(C.tenue).lineLimit(2) }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroDoc()
    }
}

// MARK: - Chi sei

private struct SlideChiSei: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCheckUp

    var body: some View {
        let c = t.e.cliente
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Chi sei e cosa conta per te", titolo: "Partiamo da te", sottotitolo: t.chiSei)
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "Cosa desideri").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                    Text(verbatim: (c?.profilo.obiettivi.isEmpty ?? true) ? "Lo definiamo insieme al prossimo incontro." : (c?.profilo.obiettivi ?? ""))
                        .font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                    if let p = c?.profilo.propensione {
                        Text(verbatim: "Propensione al rischio \(p.nome.lowercased())" + (c?.profilo.orizzonteAnni.map { ", orizzonte di \($0) anni" } ?? "") + ".")
                            .font(T.piccolo).foregroundColor(C.tenue)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .riquadroDoc(C.evidenza)
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "La tua famiglia").font(T.titoloRiquadro).foregroundColor(C.titolo)
                    if c?.famiglia.isEmpty ?? true {
                        Text(verbatim: "Nessun familiare indicato.").font(T.corpo).foregroundColor(C.tenue)
                    }
                    ForEach(c?.famiglia ?? []) { f in
                        HStack {
                            Text(verbatim: f.nome).font(T.corpoForte).foregroundColor(C.titolo)
                            Spacer()
                            Text(verbatim: f.relazione.nome + (f.eta.map { " · \($0) anni" } ?? "")).font(T.piccolo).foregroundColor(C.tenue)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .riquadroDoc()
            }
            if !t.e.obiettivi.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(t.e.obiettivi.prefix(3).enumerated()), id: \.offset) { _, x in
                        CifraCheck(etichetta: x.0.titolo, valore: CifreDoc.euro(x.0.importo), nota: "entro il \(CifreDoc.dataBreve(x.0.scadenza)) · al \(CifreDoc.percento(x.1.quota * 100, decimali: 0))")
                    }
                }
            }
        }
    }
}

// MARK: - La fotografia

private struct SlideFotografia: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCheckUp

    var body: some View {
        let r = t.e.riepilogo
        let aree = AreaPosizione.allCases.sorted { $0.ordine < $1.ordine }.filter { !$0.passivo && (r.perArea[$0] ?? 0) > 0.5 }
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "La tua fotografia", titolo: "Un patrimonio netto di \(CifreDoc.euro(r.patrimonioNetto))",
                        sottotitolo: "Quello che hai, diviso per area: i numeri vengono da quanto ci siamo detti al primo incontro.")
            HStack(spacing: 2) {
                ForEach(aree) { a in
                    ZStack {
                        Rectangle().fill(C.area(a))
                        Text(verbatim: a.nome).font(T.minimo).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.5).padding(.horizontal, 3)
                    }
                    .frame(width: max(40, (Misure.Documento.report.width - Misure.Documento.margineReport * 2 - CGFloat(aree.count) * 2) * CGFloat((r.perArea[a] ?? 0) / max(r.attivita, 1))), height: 30)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            HStack(spacing: 10) {
                CifraCheck(etichetta: "Quello che hai", valore: CifreDoc.euro(r.attivita))
                CifraCheck(etichetta: "Debiti", valore: CifreDoc.euro(r.debiti), colore: r.debiti > 0 ? C.negativo : nil)
                CifraCheck(etichetta: "Liquidità", valore: CifreDoc.euro(r.perArea[.liquidita] ?? 0))
                CifraCheck(etichetta: "Coperture", valore: CifreDoc.euro(r.capitaleAssicurato), nota: "capitali assicurati")
            }
        }
    }
}

// MARK: - Il semaforo

private struct SlideSemaforo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCheckUp

    var body: some View {
        let ind = t.e.indicatori
        return VStack(alignment: .leading, spacing: 12) {
            TestaReport(occhiello: "Il semaforo", titolo: t.titoloSemaforo,
                        sottotitolo: "Verde: in ordine. Giallo: da migliorare. Rosso: da affrontare per prima. Grigio: ci servono ancora dei dati.")
            VStack(spacing: 10) {
                ForEach(Array(stride(from: 0, to: ind.count, by: 4)), id: \.self) { i in
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(i..<min(i + 4, ind.count), id: \.self) { j in scheda(ind[j]) }
                        ForEach(0..<max(0, 4 - (ind.count - i)), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                    }
                }
            }
        }
    }

    private func scheda(_ i: IndicatoreCheckUp) -> some View {
        let colore = coloreSemaforo(i.semaforo, C)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(colore).frame(width: 12, height: 12)
                Text(verbatim: i.semaforo.nome.uppercased()).font(T.occhiello).tracking(1.2).foregroundColor(colore)
            }
            Text(verbatim: i.titolo).font(T.titoloRiquadro).foregroundColor(C.titolo)
            Text(verbatim: i.valore).font(T.numeroPiccolo).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.6)
            Text(verbatim: i.lettura).font(T.minimo).foregroundColor(C.testo).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .riquadroDoc()
    }
}

// MARK: - Da dove partire

private struct SlidePartire: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCheckUp

    var body: some View {
        let primi = Array(t.e.daAffrontare.prefix(3))
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Da dove partire", titolo: primi.isEmpty ? "Partiamo dal mantenere ciò che funziona" : "Le prime \(primi.count == 1 ? "cosa" : "\(primi.count) cose") da fare insieme",
                        sottotitolo: "In ordine di urgenza: per ciascuna ti preparo un'analisi dedicata.")
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(primi.enumerated()), id: \.offset) { n, i in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verbatim: "\(n + 1)").font(T.sintesiNumero).foregroundColor(coloreSemaforo(i.semaforo, C))
                        Text(verbatim: i.titolo).font(T.titoloRiquadro).foregroundColor(C.titolo)
                        Text(verbatim: i.azione).font(T.corpo).foregroundColor(C.testo).lineSpacing(1.4).fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: i.lettura).font(T.minimo).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
                    .riquadroDoc()
                }
                if primi.isEmpty {
                    Text(verbatim: "Tutte le aree principali sono in ordine: le rivediamo ogni anno.").font(T.corpo).foregroundColor(C.testo)
                }
            }
        }
    }
}

// MARK: - In sintesi

private struct SlideSintesiCheckUp: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCheckUp

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "Il tuo check-up, in poche righe")
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
                .frame(width: 260, alignment: .topLeading)
                .riquadroDoc(C.evidenza)
            }
            Spacer(minLength: 0)
            Text(verbatim: TestiCheckUp.avvertenza).font(T.minimo).foregroundColor(C.tenue)
        }
    }
}
