import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report del patrimonio nel tempo: A4 orizzontale, per il cliente.
enum ReportPatrimonio {
    static func pagine(_ t: TestiPatrimonio, commento: String? = nil) -> [AnyView] {
        let slide: [AnyView] = [AnyView(SlidePercorso(t: t)), AnyView(SlideAree(t: t)), AnyView(SlideProposte(t: t)), AnyView(SlideSintesiPatrimonio(t: t))]
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(TestiPatrimonio.titolo) · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiPatrimonio) -> CopertinaReport {
        var cartellini: [(String, [String])] = [("Oggi", [CifreDoc.euro(t.p.nettoOggi)]), ("Tra \(t.p.anni) anni", [CifreDoc.euro(t.p.valore(t.p.anni))])]
        if t.p.conProposte != nil { cartellini.append(("Con le proposte", [CifreDoc.euro(t.p.valore(t.p.anni, conProposte: true))])) }
        return CopertinaReport(occhiello: "Il tuo patrimonio", titolo: "I prossimi \(t.p.anni) anni",
                               sottotitolo: "Dove ti porta la strada di oggi, e dove potresti arrivare",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data,
                               canali: t.canali.isEmpty ? [.indipendente] : t.canali, cartellini: cartellini)
    }
}

private struct CifraPatrimonio: View {
    @Environment(\.paletteDocumento) private var C
    let etichetta: String
    let valore: String
    var nota = ""
    var colore: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: etichetta).font(T.piccolo).foregroundColor(C.tenue).lineLimit(1).minimumScaleFactor(0.8)
            Text(verbatim: valore).font(T.numeroGrande).foregroundColor(colore ?? C.titolo).lineLimit(1).minimumScaleFactor(0.6)
            if !nota.isEmpty {
                Text(verbatim: nota).font(T.minimo).foregroundColor(C.tenue).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroDoc()
    }
}

// MARK: - Il percorso

private struct SlidePercorso: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPatrimonio

    var body: some View {
        let p = t.p
        var serie = [SerieDoc(nome: "Com'è oggi", colore: C.premio, valori: p.oggi.map(\.valore), tratteggio: p.conProposte != nil)]
        if let c = p.conProposte { serie.append(SerieDoc(nome: "Con le proposte", colore: C.intermedio, valori: c.map(\.valore))) }
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Il percorso", titolo: t.titoloPercorso,
                        sottotitolo: "Tutto quello che hai, insieme: investimenti, risparmi, previdenza, conti e casa, debiti tolti.")
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    CifraPatrimonio(etichetta: "Oggi", valore: CifreDoc.euro(p.nettoOggi))
                    CifraPatrimonio(etichetta: "Tra 10 anni", valore: CifreDoc.euro(p.valore(10)))
                    CifraPatrimonio(etichetta: "Tra \(p.anni) anni", valore: CifreDoc.euro(p.valore(p.anni)),
                                    nota: "\(CifreDoc.euro(p.reale(p.valore(p.anni), anno: p.anni))) in euro di oggi")
                }
                .frame(width: 200)
                GraficoLineeDoc(serie: serie, etichetteAsse: t.etichetteAsse, fontAssi: T.piccolo, fontValori: T.minimo)
                    .frame(maxWidth: .infinity)
                    .frame(height: D.graficoPatrimonioReport)
            }
            Text(verbatim: "Rendimenti ipotizzati, non garantiti, prima delle imposte; la casa resta al valore di oggi e il mutuo si estingue.")
                .font(T.minimo).foregroundColor(C.tenue)
        }
    }
}

// MARK: - Di cosa è fatto

private struct SlideAree: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPatrimonio

    var body: some View {
        let aree = t.perArea
        let massimo = max(aree.map { max(abs($0.oggi), abs($0.finale)) }.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Di cosa è fatto", titolo: "Come cambia, area per area",
                        sottotitolo: "La barra chiara è oggi, quella piena tra \(t.p.anni) anni.")
            VStack(spacing: 9) {
                ForEach(aree) { a in
                    HStack(spacing: 12) {
                        Text(verbatim: a.area.nome).font(T.corpo).foregroundColor(C.titolo).frame(width: 120, alignment: .leading)
                        GeometryReader { g in
                            VStack(alignment: .leading, spacing: 3) {
                                Rectangle().fill(C.area(a.area).opacity(0.35)).frame(width: max(3, g.size.width * abs(a.oggi) / massimo), height: 9)
                                Rectangle().fill(C.area(a.area)).frame(width: max(3, g.size.width * abs(a.finale) / massimo), height: 9)
                            }
                        }
                        .frame(height: 21)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(verbatim: CifreDoc.euro(a.oggi)).font(T.minimo).foregroundColor(C.tenue)
                            Text(verbatim: CifreDoc.euro(a.finale)).font(T.corpoForte).foregroundColor(a.finale < 0 ? C.negativo : C.titolo)
                        }
                        .frame(width: 110, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .riquadroDoc()
        }
    }
}

// MARK: - Proposte e obiettivi

private struct SlideProposte: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPatrimonio

    var body: some View {
        let p = t.p
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Dove potresti arrivare", titolo: t.titoloProposte,
                        sottotitolo: "Le proposte che abbiamo preparato e i traguardi che hai indicato, sulla stessa strada.")
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "Le proposte").font(T.titoloRiquadro).foregroundColor(C.titolo)
                    if p.proposte.isEmpty {
                        Text(verbatim: "Nessuna proposta aperta per ora.").font(T.piccolo).foregroundColor(C.tenue)
                    }
                    ForEach(p.proposte.prefix(D.puntiReport)) { x in
                        Rectangle().fill(C.filetto).frame(height: 0.6)
                        HStack(spacing: 6) {
                            EtichettaCanale(canale: x.canale, compatta: true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: x.nome).font(T.corpoForte).foregroundColor(C.titolo).lineLimit(1)
                                Text(verbatim: [x.versamentoIniziale > 0.5 ? "\(CifreDoc.euro(x.versamentoIniziale)) iniziali" : "",
                                                x.premioAnnuo > 0.5 ? "\(CifreDoc.euro(x.premioAnnuo)) l'anno" : ""].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(T.minimo).foregroundColor(C.tenue)
                            }
                        }
                    }
                    if p.proposte.count > D.puntiReport {
                        Text(verbatim: "…e altre \(p.proposte.count - D.puntiReport)").font(T.minimo).foregroundColor(C.tenue)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .riquadroDoc()
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "I tuoi traguardi").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                    if p.traguardi.isEmpty {
                        Text(verbatim: "Fissiamo insieme gli obiettivi con una data: casa, studi dei figli, pensione.").font(T.piccolo).foregroundColor(C.testo)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(p.traguardi.prefix(D.puntiReport)) { o in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: o.obiettivo.titolo).font(T.corpoForte).foregroundColor(C.titolo).lineLimit(1)
                            Text(verbatim: "\(o.anno == 0 ? "quest'anno" : "tra \(o.anno) \(o.anno == 1 ? "anno" : "anni")") · \(CifreDoc.euro(o.obiettivo.importo))")
                                .font(T.minimo).foregroundColor(C.testo)
                            Text(verbatim: "patrimonio stimato allora \(CifreDoc.euro(p.valore(o.anno, conProposte: p.conProposte != nil)))")
                                .font(T.minimo).foregroundColor(C.tenue)
                        }
                    }
                    if p.traguardi.count > D.puntiReport {
                        Text(verbatim: "…e altri \(p.traguardi.count - D.puntiReport)").font(T.minimo).foregroundColor(C.tenue)
                    }
                }
                .padding(18)
                .frame(width: 290, alignment: .topLeading)
                .riquadroDoc(C.evidenza)
            }
        }
    }
}

// MARK: - In sintesi

private struct SlideSintesiPatrimonio: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPatrimonio

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "Il tuo patrimonio, in poche righe")
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 8) {
                    ForEach(Array(punti.enumerated()), id: \.offset) { i, s in
                        HStack(alignment: .center, spacing: 16) {
                            Text(verbatim: "\(i + 1)").font(T.sintesiNumero).foregroundColor(C.titolo).frame(width: 28)
                            (Text(verbatim: "\(s.0). ").bold() + Text(verbatim: s.1))
                                .font(T.corpo).foregroundColor(C.titolo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
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
            (Text(verbatim: "Come leggere i numeri. ").bold() + Text(verbatim: TestiPatrimonio.avvertenza + " Una proiezione non è una previsione: la rivediamo ogni anno."))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
