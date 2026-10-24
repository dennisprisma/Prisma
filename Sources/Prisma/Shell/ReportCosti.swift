import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report dei costi: A4 orizzontale, per il cliente.
enum ReportCosti {
    static func pagine(_ t: TestiCosti, commento: String? = nil) -> [AnyView] {
        let slide: [AnyView] = [AnyView(SlideCostiOggi(t: t)), AnyView(SlideCostiTempo(t: t)), AnyView(SlideCostiCambio(t: t)), AnyView(SlideSintesiCosti(t: t))]
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(TestiCosti.titolo) · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiCosti) -> CopertinaReport {
        var cartellini: [(String, [String])] = [("Quest'anno", [CifreDoc.euro(t.a.euroAnno)]), ("In 20 anni", [CifreDoc.euro(t.a.perso20)])]
        if t.a.risparmioPossibile > 0 { cartellini.append(("Puoi risparmiare", [CifreDoc.euro(t.a.risparmioPossibile)])) }
        return CopertinaReport(occhiello: "Costi", titolo: "Il costo dei tuoi investimenti",
                               sottotitolo: "Quanto paghi, quanto pesa nel tempo e cosa ricevi in cambio",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data,
                               canali: t.canali.isEmpty ? [.indipendente] : t.canali, cartellini: cartellini)
    }
}

private struct CifraCosti: View {
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

// MARK: - Quanto paghi oggi

private struct SlideCostiOggi: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCosti

    var body: some View {
        let a = t.a
        let massimo = max(a.voci.map(\.annuo).max() ?? 1, MotoreCosti.sogliaAlto)
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Quanto paghi", titolo: t.titoloOggi,
                        sottotitolo: "Ogni investimento ha un costo annuo, che si paga senza vederlo: è tolto dal valore o dal rendimento.")
            VStack(spacing: 7) {
                ForEach(a.voci.prefix(6)) { v in
                    HStack(spacing: 10) {
                        EtichettaCanale(canale: v.posizione.canale, compatta: true).frame(width: 84, alignment: .leading)
                        Text(verbatim: v.posizione.nome).font(T.corpo).foregroundColor(C.titolo).lineLimit(1).frame(width: 220, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(C.griglia)
                                Rectangle().fill(v.livello == .alto ? C.negativo : (v.livello == .medio ? C.intermedio : C.favorevole))
                                    .frame(width: max(3, g.size.width * v.annuo / massimo))
                            }
                        }
                        .frame(height: 12)
                        Text(verbatim: CifreDoc.percento(v.annuo, decimali: 2)).font(T.corpoForte).foregroundColor(C.titolo).frame(width: 64, alignment: .trailing)
                        Text(verbatim: "\(CifreDoc.euro(v.euroAnno)) l'anno").font(T.piccolo).foregroundColor(C.tenue).frame(width: 104, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .riquadroDoc()
            Text(verbatim: "Più lunga la barra, più alto il costo. Sotto il \(CifreDoc.condizione(MotoreCosti.sogliaBasso)) l'anno è contenuto, oltre il \(CifreDoc.condizione(MotoreCosti.sogliaAlto)) è alto e la barra diventa rossa.")
                .font(T.minimo).foregroundColor(C.tenue)
        }
    }
}

// MARK: - Quanto pesa nel tempo

private struct SlideCostiTempo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCosti

    var body: some View {
        let a = t.a
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Il peso nel tempo", titolo: t.titoloTempo,
                        sottotitolo: "Il costo pesa due volte: quello che paghi e il rendimento che quei soldi non producono più, anno dopo anno.")
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    CifraCosti(etichetta: "In 10 anni", valore: CifreDoc.euro(a.perso10), nota: "in meno di quello che ti resta", colore: C.negativo)
                    CifraCosti(etichetta: "In 20 anni", valore: CifreDoc.euro(a.perso20), nota: "o fino alla scadenza delle posizioni", colore: C.negativo)
                }
                .frame(width: 210)
                GraficoLineeDoc(serie: [SerieDoc(nome: "Senza costi", colore: C.favorevole, valori: t.serie.senza, tratteggio: true),
                                        SerieDoc(nome: "Con i costi", colore: C.intermedio, valori: t.serie.con)],
                                etichetteAsse: t.etichetteAsse, fontAssi: T.minimo, fontValori: T.minimo)
                    .frame(maxWidth: .infinity)
                    .frame(height: D.graficoCostiReport)
            }
            Text(verbatim: "Valore complessivo con i rendimenti ipotizzati, prima delle imposte finali. Rendimenti non garantiti.")
                .font(T.minimo).foregroundColor(C.tenue)
        }
    }
}

// MARK: - Cosa ricevi in cambio e dove risparmiare

private struct SlideCostiCambio: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCosti

    var body: some View {
        let a = t.a
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Cosa ricevi in cambio", titolo: t.titoloAlternative,
                        sottotitolo: "Un costo più alto può pagare garanzie, coperture o vantaggi fiscali: conta quello che ricevi, non solo quello che paghi.")
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "I tuoi investimenti").font(T.titoloRiquadro).foregroundColor(C.titolo)
                    ForEach(a.voci.prefix(4)) { v in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                EtichettaCanale(canale: v.posizione.canale, compatta: true)
                                Text(verbatim: "\(v.posizione.nome) · \(CifreDoc.percento(v.annuo, decimali: 2))").font(T.corpoForte).foregroundColor(C.titolo).lineLimit(1)
                            }
                            Text(verbatim: TestiCosti.inCambio(v.posizione)).font(T.minimo).foregroundColor(C.testo).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                        Rectangle().fill(C.filetto).frame(height: 0.6)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .riquadroDoc()
                VStack(alignment: .leading, spacing: 9) {
                    Text(verbatim: "Dove risparmiare").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                    if a.conAlternativa.isEmpty {
                        Text(verbatim: "Con lo stesso rischio non c'è un'alternativa che lasci abbastanza di più da giustificare il cambio: i tuoi costi sono in linea.")
                            .font(T.piccolo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(a.conAlternativa.prefix(3)) { v in
                        if let x = v.alternativa {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: "Invece di \(v.posizione.nome)").font(T.minimo).foregroundColor(C.tenue)
                                HStack(spacing: 6) {
                                    EtichettaCanale(canale: x.prodotto.canale, compatta: true)
                                    Text(verbatim: x.prodotto.nome).font(T.corpoForte).foregroundColor(C.titolo).lineLimit(1)
                                }
                                Text(verbatim: "+ \(CifreDoc.euro(x.guadagno)) in \(x.anni) anni, uscita compresa").font(T.piccolo).foregroundColor(C.positivo)
                            }
                        }
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

private struct SlideSintesiCosti: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCosti

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "I tuoi costi, in poche righe")
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
            (Text(verbatim: "Come leggere i numeri. ").bold() + Text(verbatim: TestiCosti.avvertenza
                + " Le alternative hanno lo stesso indicatore di rischio; la scelta di un prodotto si fa con il suo KID e con il confronto completo."))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
