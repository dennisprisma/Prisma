import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report del capitale in scadenza e della liquidità: A4 orizzontale, per il cliente.
enum ReportLiquidita {
    static func pagine(_ t: TestiLiquidita, commento: String? = nil) -> [AnyView] {
        let slide: [AnyView] = [AnyView(SlideArriva(t: t)), AnyView(SlideSalvadanai(t: t)), AnyView(SlideFermo(t: t)), AnyView(SlideSintesiLiquidita(t: t))]
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(TestiLiquidita.titolo) · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiLiquidita) -> CopertinaReport {
        let e = t.e
        var cartellini: [(String, [String])] = []
        if let s = e.scadenze.first { cartellini.append(("In scadenza", [s.posizione.nome, "il \(CifreDoc.dataBreve(s.data))"])) }
        cartellini.append(("Disponibile", [CifreDoc.euro(e.totale)]))
        cartellini.append(("Riserva", [CifreDoc.euro(e.riservaNecessaria)]))
        return CopertinaReport(occhiello: "Liquidità", titolo: e.scadenze.isEmpty ? "La tua liquidità" : "Il tuo capitale in scadenza",
                               sottotitolo: "Quanto tenere da parte e come far lavorare il resto, secondo quando ti servirà",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data,
                               canali: t.canali.isEmpty ? [.indipendente] : t.canali, cartellini: cartellini)
    }
}

private var larghezzaUtile: CGFloat { D.report.width - D.margineReport * 2 }

private struct CifraLiquidita: View {
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

private func coloreSalvadanaio(_ t: Salvadanaio.Tipo, _ C: PaletteDocumento) -> Color {
    switch t {
    case .riserva: return C.area(.liquidita)
    case .breve: return C.area(.risparmio)
    case .medio: return C.area(.previdenza)
    case .lungo: return C.area(.investimento)
    }
}

// MARK: - Cosa ti arriva

private struct SlideArriva: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiLiquidita

    var body: some View {
        let e = t.e
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Cosa ti arriva", titolo: t.titoloArrivo,
                        sottotitolo: "Insieme alla liquidità che hai già, fanno \(CifreDoc.euro(e.totale)) da decidere come usare.")
            HStack(alignment: .top, spacing: 12) {
                ForEach(e.scadenze.prefix(3)) { s in
                    VStack(alignment: .leading, spacing: 8) {
                        EtichettaCanale(canale: s.posizione.canale)
                        Text(verbatim: s.posizione.nome).font(T.titoloRiquadro).foregroundColor(C.titolo)
                        Text(verbatim: (s.scaduto ? "Scaduta il " : "Scade il ") + CifreDoc.dataBreve(s.data)).font(T.piccolo).foregroundColor(s.scaduto ? C.negativo : C.tenue)
                        Text(verbatim: CifreDoc.euro(s.netto)).font(T.numeroGrande).foregroundColor(C.titolo)
                        Text(verbatim: "netti: valore \(CifreDoc.euro(s.fisco.valore))" + (s.fisco.imposta > 0.5 ? ", imposte \(CifreDoc.euro(s.fisco.imposta))" : ""))
                            .font(T.minimo).foregroundColor(C.tenue)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .riquadroDoc()
                }
                CifraLiquidita(etichetta: "Liquidità che hai già", valore: CifreDoc.euro(e.liquiditaAttuale), nota: e.liquidita.map(\.nome).joined(separator: ", "), font: T.numeroGrande)
            }
        }
    }
}

// MARK: - I quattro salvadanai

private struct SlideSalvadanai: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiLiquidita

    var body: some View {
        let e = t.e
        let pieni = e.salvadanai.filter { $0.importo > 0.5 }
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Come destinarli", titolo: t.titoloSalvadanai,
                        sottotitolo: "Prima la tranquillità, poi i progetti con una data, infine ciò che può crescere con calma.")
            HStack(spacing: 2) {
                ForEach(pieni) { s in
                    ZStack {
                        Rectangle().fill(coloreSalvadanaio(s.tipo, C))
                        Text(verbatim: CifreDoc.euro(s.importo)).font(T.corpoForte).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.5).padding(.horizontal, 4)
                    }
                    .frame(width: max(40, (larghezzaUtile - CGFloat(pieni.count) * 2) * CGFloat(s.importo / max(e.totale, 1))), height: 36)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            HStack(alignment: .top, spacing: 10) {
                ForEach(e.salvadanai) { s in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 6) {
                            Circle().fill(coloreSalvadanaio(s.tipo, C)).frame(width: 9, height: 9)
                            Text(verbatim: s.orizzonte.uppercased()).font(T.occhiello).tracking(1.2).foregroundColor(C.occhiello)
                        }
                        Text(verbatim: s.titolo).font(T.titoloRiquadro).foregroundColor(C.titolo)
                        Text(verbatim: CifreDoc.euro(s.importo)).font(T.numeroMedio).foregroundColor(s.importo > 0.5 ? C.titolo : C.tenue)
                        Text(verbatim: s.obiettivi.isEmpty ? s.perche : "Per: " + s.obiettivi.map(\.titolo).joined(separator: ", "))
                            .font(T.minimo).foregroundColor(C.testo).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: s.strumenti).font(T.minimo).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                    .riquadroDoc()
                }
            }
        }
    }
}

// MARK: - Il costo di lasciarli fermi

private struct SlideFermo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiLiquidita

    var body: some View {
        let e = t.e
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Il costo dell'attesa", titolo: t.titoloFermo,
                        sottotitolo: "Sul conto i soldi sono al sicuro, ma con l'inflazione perdono valore. Ecco cosa resta dopo \(IpotesiLiquidita.anniConfronto) anni, in euro di oggi.")
            HStack(spacing: 10) {
                CifraLiquidita(etichetta: "Oggi", valore: CifreDoc.euro(e.totale), font: T.numeroGrande)
                Text(verbatim: "→").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraLiquidita(etichetta: "Tutto fermo sul conto", valore: CifreDoc.euro(e.realeFermo), nota: "\(CifreDoc.togli(e.perditaFermo)) di potere d'acquisto",
                               colore: C.negativo, font: T.numeroGrande)
                CifraLiquidita(etichetta: "Destinati nei salvadanai", valore: CifreDoc.euro(e.realeDestinato), nota: "\(CifreDoc.euroSegno(e.vantaggioDestinare)) rispetto a lasciarli fermi",
                               colore: C.positivo, font: T.numeroGrande)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "Sicurezza e crescita insieme").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                Text(verbatim: "La riserva resta sempre disponibile; i soldi dei progetti vicini non corrono rischi inutili; solo ciò che non serve per anni viene investito per crescere. Così ogni euro ha un compito.")
                    .font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .riquadroDoc(C.evidenza)
        }
    }
}

// MARK: - In sintesi

private struct SlideSintesiLiquidita: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiLiquidita

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "La tua liquidità, in poche righe")
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
             + Text(verbatim: "Rendimenti indicativi per orizzonte, non garantiti, al netto delle imposte e dell'inflazione. " + TestiLiquidita.avvertenza))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
