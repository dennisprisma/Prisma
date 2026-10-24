import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report della prova di resistenza: A4 orizzontale, per il cliente.
enum ReportResistenza {
    static func pagine(_ t: TestiResistenza, commento: String? = nil) -> [AnyView] {
        let slide: [AnyView] = [AnyView(SlideScenari(t: t)), AnyView(SlideProfilo(t: t)), AnyView(SlideSintesiResistenza(t: t))]
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(TestiResistenza.titolo) · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiResistenza) -> CopertinaReport {
        var cartellini: [(String, [String])] = [("I tuoi risparmi", [CifreDoc.euro(t.r.patrimonioFinanziario)])]
        if let m = t.mercati, !m.voci.isEmpty { cartellini.append(("Se i mercati crollano", [CifreDoc.togli(m.perdita)])) }
        if let g = t.r.giudizio { cartellini.append(("Il tuo profilo", [g.etichetta])) }
        return CopertinaReport(occhiello: "Prova di resistenza", titolo: "I tuoi risparmi alla prova",
                               sottotitolo: "Cosa può succedere negli anni difficili, e se è una perdita che puoi sopportare",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data,
                               canali: t.canali.isEmpty ? [.indipendente] : t.canali, cartellini: cartellini)
    }
}

// MARK: - I tre scenari

private struct SlideScenari: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResistenza

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Tre anni difficili", titolo: t.titoloScenari,
                        sottotitolo: "Abbiamo messo alla prova i tuoi risparmi in tre situazioni sfavorevoli, una alla volta. Sono stime prudenti, non previsioni.")
            HStack(alignment: .top, spacing: 12) {
                ForEach(t.r.scenari) { s in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: s.tipo.titolo.uppercased()).font(T.occhiello).tracking(1.2).foregroundColor(C.occhiello)
                        Text(verbatim: s.voci.isEmpty ? "Nessuna perdita" : CifreDoc.togli(s.perdita))
                            .font(T.numeroGrande).foregroundColor(s.voci.isEmpty ? C.tenue : C.negativo).lineLimit(1).minimumScaleFactor(0.6)
                        if !s.voci.isEmpty {
                            Text(verbatim: "il \(CifreDoc.percento(s.quota * 100)) \(s.tipo == .immobili ? "del tuo patrimonio" : "dei tuoi risparmi")")
                                .font(T.piccolo).foregroundColor(C.testo)
                        }
                        Text(verbatim: s.tipo.ipotesi).font(T.minimo).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
                        if let v = s.voci.first {
                            Rectangle().fill(C.filetto).frame(height: 0.6)
                            HStack(spacing: 6) {
                                EtichettaCanale(canale: v.posizione.canale, compatta: true)
                                Text(verbatim: "La più colpita: \(v.posizione.nome)").font(T.minimo).foregroundColor(C.testo).lineLimit(2)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
                    .riquadroDoc()
                }
            }
        }
    }
}

// MARK: - Il confronto con il profilo

private struct SlideProfilo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResistenza

    var body: some View {
        let r = t.r
        let esposte = t.mercati?.voci.prefix(4) ?? []
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Il tuo profilo", titolo: t.titoloProfilo, sottotitolo: t.spiegazioneProfilo)
            if let m = t.mercati, m.base > 0 {
                BarraProfilo(prova: r, quota: m.quota, altezza: D.barraResistenzaReport, font: T.piccolo)
            }
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "Le più esposte ai mercati").font(T.titoloRiquadro).foregroundColor(C.titolo)
                    if esposte.isEmpty {
                        Text(verbatim: "Nessuna: i tuoi risparmi sono su conti o con il capitale garantito.").font(T.piccolo).foregroundColor(C.tenue)
                    }
                    ForEach(Array(esposte)) { v in
                        HStack(spacing: 8) {
                            EtichettaCanale(canale: v.posizione.canale, compatta: true)
                            Text(verbatim: v.posizione.nome).font(T.corpo).foregroundColor(C.titolo).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(verbatim: CifreDoc.togli(v.perdita)).font(T.corpoForte).foregroundColor(C.negativo)
                        }
                        Rectangle().fill(C.filetto).frame(height: 0.6)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .riquadroDoc()
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "Al riparo").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                    Text(verbatim: CifreDoc.percento(r.quotaProtetta * 100, decimali: 0)).font(T.numeroGrande).foregroundColor(C.positivo)
                    Text(verbatim: "dei tuoi risparmi ha il capitale garantito o non dipende dai mercati: è la parte che resta ferma anche negli anni difficili.")
                        .font(T.piccolo).foregroundColor(C.testo).lineSpacing(1.3).fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(width: 260, alignment: .topLeading)
                .riquadroDoc(C.evidenza)
            }
        }
    }
}

// MARK: - In sintesi

private struct SlideSintesiResistenza: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResistenza

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "La prova di resistenza, in poche righe")
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 8) {
                    ForEach(Array(punti.enumerated()), id: \.offset) { i, p in
                        HStack(alignment: .center, spacing: 16) {
                            Text(verbatim: "\(i + 1)").font(T.sintesiNumero).foregroundColor(C.titolo).frame(width: 28)
                            (Text(verbatim: "\(p.0). ").bold() + Text(verbatim: p.1))
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
            (Text(verbatim: "Come leggere i numeri. ").bold() + Text(verbatim: TestiResistenza.avvertenza
                + " Chi resta investito può recuperare nel tempo le perdite di un anno difficile; il capitale garantito vale alle condizioni del contratto."))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
