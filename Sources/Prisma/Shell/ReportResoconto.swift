import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report del resoconto delle posizioni in essere: A4 orizzontale, da lasciare al cliente.
/// Una pagina per messaggio: il quadro, come sta andando, posizione per posizione, le tutele,
/// i prossimi 12 mesi, i costi, la sintesi. Veste di Prisma (copertina in cuoio, carta avorio).
enum ReportResoconto {
    /// Schede delle posizioni per pagina (2 × 2).
    static let schedePerPagina = 4

    static func pagine(_ t: TestiResoconto) -> [AnyView] {
        var slide: [AnyView] = [AnyView(SlideQuadro(t: t))]
        let finanziarie = t.e.finanziarie
        if !finanziarie.isEmpty {
            slide.append(AnyView(SlideAndamento(t: t)))
            let gruppi = stride(from: 0, to: finanziarie.count, by: schedePerPagina).map {
                Array(finanziarie[$0..<min($0 + schedePerPagina, finanziarie.count)])
            }
            for (i, g) in gruppi.enumerated() {
                slide.append(AnyView(SlidePosizioni(t: t, voci: g, parte: gruppi.count > 1 ? "\(i + 1) di \(gruppi.count)" : nil)))
            }
        }
        slide += [AnyView(SlideTutele(t: t)), AnyView(SlideScadenze(t: t))]
        if t.e.costoAnnuo > 0 { slide.append(AnyView(SlideCosti(t: t))) }
        slide.append(AnyView(SlideSintesi(t: t)))
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide,
                                     intestazione: "\(TestiResoconto.titolo) · \(t.cliente)")
    }

    private static func copertina(_ t: TestiResoconto) -> CopertinaReport {
        let e = t.e
        var cartellini: [(String, [String])] = [("Patrimonio netto", [CifreDoc.euro(e.riepilogo.patrimonioNetto)])]
        if e.versato > 0 {
            cartellini.append(("I tuoi risparmi oggi", [CifreDoc.euro(e.valoreFinanziario), "\(CifreDoc.euroSegno(e.risultato)) sul versato"]))
        }
        cartellini.append(("Posizioni in essere", [TestiResoconto.posizioni(e.voci.count)]))
        return CopertinaReport(occhiello: "Resoconto", titolo: "Il punto sui tuoi risparmi",
                               sottotitolo: "Cosa hai, come sta andando e cosa ci aspetta nei prossimi mesi",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: e.data, canali: e.canaliPresenti,
                               cartellini: cartellini)
    }
}

private var larghezzaUtile: CGFloat { D.report.width - D.margineReport * 2 }

/// Una cifra su carta: etichetta piccola e numero in Georgia.
private struct CifraReport: View {
    @Environment(\.paletteDocumento) private var C
    let etichetta: String
    let valore: String
    var nota = ""
    var colore: Color? = nil
    var font = T.numeroGrande

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

// MARK: - Il quadro

private struct SlideQuadro: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto

    private var e: EsitoResoconto { t.e }

    var body: some View {
        let attive = e.aree.filter { !$0.area.passivo }
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Il quadro", titolo: t.titoloQuadro, sottotitolo: t.sottotitoloQuadro)
            // La barra del patrimonio: ogni area in proporzione
            HStack(spacing: 2) {
                ForEach(attive) { a in
                    Rectangle().fill(C.area(a.area))
                        .frame(width: max(2, (larghezzaUtile - CGFloat(attive.count) * 2) * CGFloat(a.quota)))
                }
            }
            .frame(width: larghezzaUtile, height: 26, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            HStack(alignment: .top, spacing: 10) {
                ForEach(attive) { a in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(C.area(a.area)).frame(width: 8, height: 8)
                            Text(verbatim: a.area.nome).font(T.corpoForte).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Text(verbatim: CifreDoc.euro(a.valore)).font(T.numeroPiccolo).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.7)
                        Text(verbatim: "\(CifreDoc.percento(a.quota * 100, decimali: 0)) · \(TestiResoconto.posizioni(a.posizioni))")
                            .font(T.minimo).foregroundColor(C.tenue).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                ForEach(e.canali.filter { $0.posizioni > 0 }) { c in
                    VStack(alignment: .leading, spacing: 8) {
                        EtichettaCanale(canale: c.canale)
                        Text(verbatim: CifreDoc.euro(c.valore)).font(T.numeroMedio).foregroundColor(C.titolo)
                        Text(verbatim: TestiResoconto.posizioni(c.posizioni)
                             + (c.premiAnnui > 0 ? " · \(CifreDoc.euro(c.premiAnnui)) di versamenti e premi l'anno" : ""))
                            .font(T.piccolo).foregroundColor(C.tenue)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .riquadroDoc()
                }
                if e.riepilogo.debiti > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "Debiti residui").font(T.titoloRiquadro).foregroundColor(C.titolo)
                        Text(verbatim: CifreDoc.togli(e.riepilogo.debiti)).font(T.numeroMedio).foregroundColor(C.negativo)
                        Text(verbatim: e.debiti.map(\.posizione.nome).joined(separator: ", ")
                             + (e.rateAnnue > 0 ? " · rate \(CifreDoc.euro(e.rateAnnue / 12)) al mese" : ""))
                            .font(T.piccolo).foregroundColor(C.tenue).lineLimit(2)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .riquadroDoc()
                }
            }
        }
    }
}

// MARK: - Come sta andando

private struct SlideAndamento: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto

    private var e: EsitoResoconto { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Come sta andando", titolo: t.titoloAndamento, sottotitolo: t.sottotitoloAndamento)
            HStack(spacing: 10) {
                CifraReport(etichetta: "Hai versato", valore: CifreDoc.euro(e.versato))
                Text(verbatim: "→").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraReport(etichetta: "Oggi vale", valore: CifreDoc.euro(e.valoreFinanziario))
                Text(verbatim: "=").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraReport(etichetta: e.risultato >= 0 ? "Guadagno" : "Perdita", valore: CifreDoc.euroSegno(e.risultato),
                            nota: "\(CifreDoc.variazione(e.risultatoPercento)) su quanto versato",
                            colore: e.risultato < -0.5 ? C.negativo : C.positivo)
                CifraReport(etichetta: "Rendimento medio", valore: e.rendimentoAnnuo.map { CifreDoc.variazione($0) } ?? "—",
                            nota: "all'anno, dalle date dei versamenti", font: T.numeroMedio)
                CifraReport(etichetta: "Ultimi 12 mesi", valore: e.variazione12.map { CifreDoc.euroSegno($0) } ?? "—",
                            nota: e.variazione12Percento.map { "\(CifreDoc.variazione($0)), tolti i nuovi versamenti" } ?? "",
                            colore: (e.variazione12 ?? 0) < -0.5 ? C.negativo : nil, font: T.numeroMedio)
            }
            Text(verbatim: "Versato e valore di ogni posizione").font(T.titoloRiquadro).foregroundColor(C.titolo)
            GraficoVersatoValore(voci: e.finanziarie)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Coppie di barre per posizione: versato (grigio) e valore di oggi (colore dell'area).
private struct GraficoVersatoValore: View {
    @Environment(\.paletteDocumento) private var C
    let voci: [VoceResoconto]

    var body: some View {
        GeometryReader { geo in
            let basso: CGFloat = 34
            let alto: CGFloat = 18
            let h = max(1, geo.size.height - basso - alto)
            let massimo = max(voci.map { max($0.valore, $0.versato ?? 0) }.max() ?? 1, 1)
            let colonna = geo.size.width / CGFloat(max(voci.count, 1))
            let barra = min(46, colonna * 0.3)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(voci) { v in
                    VStack(spacing: 4) {
                        HStack(alignment: .bottom, spacing: 4) {
                            colonnina(v.versato ?? 0, massimo: massimo, h: h, larghezza: barra, colore: C.premio, forte: false)
                            colonnina(v.valore, massimo: massimo, h: h, larghezza: barra, colore: C.area(v.posizione.area), forte: true)
                        }
                        VStack(spacing: 1) {
                            Text(verbatim: v.posizione.nome).font(T.piccolo).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.7)
                            Text(verbatim: TestiResoconto.risultato(v.risultato, v.risultatoPercento)).font(T.minimo)
                                .foregroundColor((v.risultato ?? 0) < -0.5 ? C.negativo : C.tenue).lineLimit(1)
                        }
                        .frame(height: basso - 4)
                    }
                    .frame(width: colonna)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .overlay(Rectangle().fill(C.filetto).frame(height: 0.8).padding(.bottom, basso), alignment: .bottom)
            .overlay(legenda, alignment: .topTrailing)
        }
    }

    private func colonnina(_ valore: Double, massimo: Double, h: CGFloat, larghezza: CGFloat, colore: Color, forte: Bool) -> some View {
        VStack(spacing: 3) {
            Text(verbatim: CifreDoc.euro(valore)).font(forte ? T.piccolo.bold() : T.minimo).foregroundColor(forte ? C.titolo : C.tenue).fixedSize()
            Rectangle().fill(colore).frame(width: larghezza, height: max(1, h * CGFloat(valore / massimo)))
        }
    }

    private var legenda: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) { Rectangle().fill(C.premio).frame(width: 9, height: 9); Text(verbatim: "versato") }
            HStack(spacing: 4) { Rectangle().fill(C.titolo).frame(width: 9, height: 9); Text(verbatim: "valore di oggi, nel colore dell'area") }
        }
        .font(T.minimo).foregroundColor(C.tenue)
    }
}

// MARK: - Posizione per posizione

private struct SlidePosizioni: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto
    let voci: [VoceResoconto]
    let parte: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Posizione per posizione",
                        titolo: "Le tue posizioni, una per una" + (parte.map { " (\($0))" } ?? ""),
                        sottotitolo: "Valori al netto dei costi dei prodotti, prima delle imposte sul guadagno.")
            VStack(spacing: 12) {
                ForEach(Array(stride(from: 0, to: voci.count, by: 2)), id: \.self) { i in
                    HStack(alignment: .top, spacing: 12) {
                        scheda(voci[i])
                        if i + 1 < voci.count { scheda(voci[i + 1]) } else { Color.clear.frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }

    private func scheda(_ v: VoceResoconto) -> some View {
        let p = v.posizione
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Circle().fill(C.area(p.area)).frame(width: 8, height: 8)
                Text(verbatim: p.area.nome.uppercased()).font(T.occhiello).tracking(1.4).foregroundColor(C.occhiello)
                Spacer(minLength: 0)
                EtichettaCanale(canale: p.canale)
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: p.nome).font(T.titoloRiquadro).foregroundColor(C.titolo).lineLimit(1)
                    Text(verbatim: [p.tipologia, p.emittente].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(T.minimo).foregroundColor(C.tenue).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(verbatim: CifreDoc.euro(v.valore)).font(T.numeroMedio).foregroundColor(C.titolo)
            }
            HStack(spacing: 8) {
                dato("Versato", v.versato.map { CifreDoc.euro($0) } ?? "—")
                dato("Risultato", TestiResoconto.risultato(v.risultato, v.risultatoPercento), colore: (v.risultato ?? 0) < -0.5 ? C.negativo : C.positivo)
                dato("Rendimento medio", v.rendimentoAnnuo.map { "\(CifreDoc.variazione($0)) l'anno" } ?? "—")
            }
            Text(verbatim: righe(v).joined(separator: "  ·  ")).font(T.minimo).foregroundColor(C.testo).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroDoc()
    }

    private func righe(_ v: VoceResoconto) -> [String] {
        let p = v.posizione
        var r: [String] = []
        if let d = v.variazione12, let q = v.variazione12Percento { r.append("Ultimi 12 mesi \(CifreDoc.euroSegno(d)) (\(CifreDoc.variazione(q)))") }
        if p.premioAnnuo > 0 { r.append("Versi \(CifreDoc.euro(p.premio)) \(p.frequenza == .mensile ? "al mese" : p.frequenza.nome.lowercased())") }
        if let c = v.costoAnnuo { r.append("Costi circa \(CifreDoc.euro(c)) l'anno") }
        if let s = p.scadenza { r.append("Scadenza \(CifreDoc.dataBreve(s))") } else if let d = p.decorrenza { r.append("Dal \(CifreDoc.dataBreve(d))") }
        return r
    }

    private func dato(_ etichetta: String, _ valore: String, colore: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: etichetta).font(T.minimo).foregroundColor(C.tenue)
            Text(verbatim: valore).font(T.corpoForte).foregroundColor(colore ?? C.titolo).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: D.raggioPiccolo).fill(C.evidenza))
    }
}

// MARK: - Le tutele

private struct SlideTutele: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto

    var body: some View {
        let coperture = t.e.coperture
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Le tue tutele", titolo: t.titoloTutele, sottotitolo: t.sottotitoloTutele)
            if coperture.isEmpty {
                Text(verbatim: "Una copertura caso morte, una per gli infortuni o la non autosufficienza costano spesso meno di quanto si pensa: è il primo punto da valutare insieme.")
                    .font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5)
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading).riquadroDoc(C.evidenza)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(stride(from: 0, to: coperture.count, by: 3)), id: \.self) { i in
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(i..<min(i + 3, coperture.count), id: \.self) { j in scheda(coperture[j]) }
                            ForEach(0..<max(0, 3 - (coperture.count - i)), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                        }
                    }
                }
            }
        }
    }

    private func scheda(_ v: VoceResoconto) -> some View {
        let p = v.posizione
        return VStack(alignment: .leading, spacing: 7) {
            EtichettaCanale(canale: p.canale)
            Text(verbatim: (p.rischio?.nome ?? "Copertura").uppercased()).font(T.occhiello).tracking(1.4).foregroundColor(C.occhiello)
                .padding(.top, 4)
            Text(verbatim: CifreDoc.euro(p.capitaleAssicurato ?? 0)).font(T.numeroGrande).foregroundColor(C.titolo)
            Text(verbatim: p.nome).font(T.titoloRiquadro).foregroundColor(C.titolo)
            VStack(alignment: .leading, spacing: 3) {
                riga("Premio", "\(CifreDoc.euro(p.premioAnnuo)) l'anno")
                if !p.assicurato.isEmpty { riga("Assicurato", p.assicurato) }
                if !p.beneficiari.isEmpty { riga("Beneficiari", p.beneficiari) }
                riga("Fino al", TestiResoconto.quando(p.scadenza))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroDoc()
    }

    private func riga(_ etichetta: String, _ valore: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: etichetta).font(T.piccolo).foregroundColor(C.tenue)
            Spacer(minLength: 6)
            Text(verbatim: valore).font(T.piccolo).foregroundColor(C.testo).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

// MARK: - I prossimi 12 mesi

private struct SlideScadenze: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto

    private var e: EsitoResoconto { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "I prossimi 12 mesi", titolo: t.titoloScadenze,
                        sottotitolo: "Le scadenze da preparare per tempo e quanto ti chiedono ogni mese i tuoi contratti.")
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    if e.scadenze.isEmpty {
                        Text(verbatim: "Nessun contratto scade nei prossimi 12 mesi: il prossimo controllo è il resoconto di metà anno.")
                            .font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading).riquadroDoc(C.evidenza)
                    }
                    ForEach(e.scadenze.prefix(5)) { s in
                        HStack(alignment: .center, spacing: 14) {
                            VStack(spacing: 0) {
                                Text(verbatim: Formati.meseBreve.string(from: s.data).uppercased()).font(T.occhiello).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 2).background(s.scaduta ? C.negativo : C.marchio)
                                Text(verbatim: "\(Calendar.current.component(.day, from: s.data))").font(T.numeroMedio).foregroundColor(C.titolo)
                                    .frame(maxWidth: .infinity).padding(.vertical, 2)
                            }
                            .frame(width: 46)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(C.riquadroBordo, lineWidth: 0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: s.posizione.nome).font(T.titoloRiquadro).foregroundColor(C.titolo)
                                Text(verbatim: (s.scaduta ? "Già passata: " : "") + s.cosa.prefix(1).uppercased() + s.cosa.dropFirst()
                                     + (s.posizione.area == .protezione ? " · premio \(CifreDoc.euro(s.posizione.premioAnnuo)) l'anno" : " · \(CifreDoc.euro(s.posizione.valore))"))
                                    .font(T.piccolo).foregroundColor(C.testo)
                            }
                            Spacer(minLength: 6)
                            EtichettaCanale(canale: s.posizione.canale)
                        }
                        .padding(10)
                        .riquadroDoc()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: "Ogni mese").font(T.titoloRiquadro).foregroundColor(C.titolo)
                    Text(verbatim: CifreDoc.euro(t.impegnoAnnuo / 12)).font(T.sintesiNumero).foregroundColor(C.titolo)
                    Rectangle().fill(C.filetto).frame(height: 0.8)
                    voce("Versamenti nei risparmi", e.versamentiAnnui)
                    voce("Premi delle tutele", e.premiCoperture)
                    voce("Rate dei finanziamenti", e.rateAnnue)
                    Text(verbatim: "Importi medi: i premi annuali sono divisi per dodici.").font(T.minimo).foregroundColor(C.tenue)
                }
                .padding(18)
                .frame(width: 250, alignment: .topLeading)
                .riquadroDoc(C.evidenza)
            }
        }
    }

    private func voce(_ etichetta: String, _ anno: Double) -> some View {
        HStack {
            Text(verbatim: etichetta).font(T.piccolo).foregroundColor(C.testo)
            Spacer()
            Text(verbatim: CifreDoc.euro(anno / 12)).font(T.corpoForte).foregroundColor(C.titolo)
        }
    }
}

// MARK: - Quanto costa

private struct SlideCosti: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto

    var body: some View {
        let voci = t.e.voci.filter { ($0.costoAnnuo ?? 0) > 0 }.sorted { ($0.costoAnnuo ?? 0) > ($1.costoAnnuo ?? 0) }
        let massimo = max(voci.compactMap(\.costoAnnuo).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Quanto costa", titolo: t.titoloCosti, sottotitolo: t.sottotitoloCosti)
            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(voci) { v in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: v.posizione.nome).font(T.corpoForte).foregroundColor(C.titolo).lineLimit(1)
                                Text(verbatim: "\(v.posizione.canale.nome) · \(CifreDoc.condizione(v.posizione.costoAnnuo ?? 0)) l'anno sul valore")
                                    .font(T.minimo).foregroundColor(C.tenue).lineLimit(1)
                            }
                            .frame(width: 230, alignment: .leading)
                            GeometryReader { geo in
                                Rectangle().fill(C.canale(v.posizione.canale))
                                    .frame(width: max(2, geo.size.width * CGFloat((v.costoAnnuo ?? 0) / massimo)), height: 14)
                                    .frame(maxHeight: .infinity)
                            }
                            .frame(height: 30)
                            Text(verbatim: CifreDoc.euro(v.costoAnnuo ?? 0)).font(T.corpoForte).foregroundColor(C.titolo)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: "Cosa comprendono").font(T.titoloRiquadro).foregroundColor(C.titolo)
                    Text(verbatim: "Gestione del prodotto, commissioni e costi dei fondi sottostanti. Sono già tolti dal valore che ti mostriamo: il risultato che vedi è al netto. Non comprendono le imposte sul guadagno, che si pagano solo al riscatto o alla vendita.")
                        .font(T.piccolo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(width: 250, alignment: .topLeading)
                .riquadroDoc(C.evidenza)
            }
        }
    }
}

// MARK: - In sintesi

private struct SlideSintesi: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "Il punto, in poche righe")
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    ForEach(Array(punti.enumerated()), id: \.offset) { i, p in
                        HStack(alignment: .center, spacing: 16) {
                            Text(verbatim: "\(i + 1)").font(T.sintesiNumero).foregroundColor(C.titolo).frame(width: 28)
                            (Text(verbatim: "\(p.0). ").bold() + Text(verbatim: p.1))
                                .font(T.corpo).foregroundColor(C.titolo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(13)
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
             + Text(verbatim: "Valori indicati nelle tue posizioni alla data di ciascuna, al netto dei costi dei prodotti e prima delle imposte sul guadagno. Il rendimento medio annuo tiene conto di quando hai fatto ogni versamento. I risultati passati non sono indicativi di quelli futuri. " + TestiResoconto.avvertenza))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
