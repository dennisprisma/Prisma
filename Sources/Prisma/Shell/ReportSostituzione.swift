import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report della sostituzione (o del confronto tra due proposte): A4 orizzontale, per il cliente.
/// Le due strade, quanto costa cambiare oggi, dove si arriva, gli scenari, cosa cambia, la sintesi.
enum ReportSostituzione {
    static func pagine(_ t: TestiSostituzione, commento: String? = nil) -> [AnyView] {
        var slide: [AnyView] = [AnyView(SlideStrade(t: t))]
        if t.e.sostituzione { slide.append(AnyView(SlideUscita(t: t))) }
        slide += [AnyView(SlideArrivo(t: t)), AnyView(SlideScenari(t: t)), AnyView(SlideCambia(t: t)), AnyView(SlideSintesiSostituzione(t: t))]
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide,
                                     intestazione: "\(t.e.sostituzione ? "Restare o cambiare" : "Due proposte a confronto") · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiSostituzione) -> CopertinaReport {
        let e = t.e
        var cartellini: [(String, [String])] = []
        if e.sostituzione {
            cartellini.append(("Oggi", [t.a.nome, CifreDoc.euro(e.valoreOggi)]))
            cartellini.append(("Alternativa", [t.b.nome]))
        } else {
            cartellini.append(("Le due proposte", [t.a.nome, t.b.nome]))
            cartellini.append(("Capitale", [CifreDoc.euro(e.valoreOggi)]))
        }
        cartellini.append(("Orizzonte", [t.periodo]))
        let canali = t.a.canale == t.b.canale ? [t.a.canale] : [t.a.canale, t.b.canale]
        return CopertinaReport(occhiello: e.sostituzione ? "Sostituzione" : "Confronto",
                               titolo: e.sostituzione ? "Restare o cambiare?" : "Quale delle due?",
                               sottotitolo: e.sostituzione ? "\(t.a.nome) oppure \(t.b.nome): cosa conviene nei prossimi \(t.periodo)"
                                                           : "\(t.a.nome) e \(t.b.nome) a confronto, sugli stessi \(t.periodo)",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data, canali: canali, cartellini: cartellini)
    }
}

private var larghezzaUtile: CGFloat { D.report.width - D.margineReport * 2 }

/// Una cifra su carta, con etichetta e nota.
private struct CifraCarta: View {
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

// MARK: - Le due strade

private struct SlideStrade: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSostituzione

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Le due strade",
                        titolo: t.e.sostituzione ? "Da una parte ciò che hai, dall'altra l'alternativa" : "Due proposte, una accanto all'altra",
                        sottotitolo: t.e.sostituzione ? "Le confrontiamo sugli stessi \(t.periodo), con gli stessi versamenti e al netto di costi e imposte."
                                                      : "Partono dallo stesso capitale, ricevono gli stessi versamenti e le confrontiamo al netto di costi e imposte.")
            HStack(alignment: .top, spacing: 16) {
                scheda(t.e.resto, titolo: t.e.sostituzione ? "Restare" : "Prima proposta", colore: C.premio, valore: t.e.valoreOggi,
                       etichettaValore: t.e.sostituzione ? "vale oggi" : "capitale")
                Text(verbatim: "↔").font(T.numeroGrande).foregroundColor(C.tenue).padding(.top, 80)
                scheda(t.e.cambio, titolo: t.e.sostituzione ? "Cambiare" : "Seconda proposta", colore: C.intermedio, valore: t.e.investitoCambio,
                       etichettaValore: t.e.sostituzione ? "investiti, dopo l'uscita" : "investiti, dopo l'ingresso")
            }
        }
    }

    private func scheda(_ l: LatoSostituzione, titolo: String, colore: Color, valore: Double, etichettaValore: String) -> some View {
        let p = l.posizione
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: titolo.uppercased()).font(T.occhiello).tracking(1.6).foregroundColor(colore)
                Spacer()
                EtichettaCanale(canale: p.canale)
            }
            Text(verbatim: p.nome).font(T.titoloRiquadro).foregroundColor(C.titolo)
            Text(verbatim: [p.tipologia, p.emittente].filter { !$0.isEmpty }.joined(separator: " · ")).font(T.minimo).foregroundColor(C.tenue)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: CifreDoc.euro(valore)).font(T.numeroGrande).foregroundColor(colore)
                Text(verbatim: etichettaValore).font(T.piccolo).foregroundColor(C.tenue)
            }
            VStack(spacing: 5) {
                riga("Rendimento ipotizzato", "\(CifreDoc.percento(l.rendimento)) l'anno, lordo")
                riga("Costi ogni anno", CifreDoc.percento(l.costoAnnuo, decimali: 2))
                riga("Imposta sul guadagno", CifreDoc.percento(l.aliquota, decimali: 2))
                riga("Rischio", p.sri.map { "\($0) su 7" } ?? "—")
                if let s = p.scadenza { riga("Scadenza", CifreDoc.dataBreve(s)) }
            }
            if !p.garanzie.isEmpty {
                Text(verbatim: p.garanzie).font(T.minimo).foregroundColor(C.testo).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .riquadroDoc()
    }

    private func riga(_ etichetta: String, _ valore: String) -> some View {
        HStack {
            Text(verbatim: etichetta).font(T.piccolo).foregroundColor(C.tenue)
            Spacer()
            Text(verbatim: valore).font(T.piccolo).foregroundColor(C.titolo)
        }
        .padding(.vertical, 2)
        .overlay(Rectangle().fill(C.filetto).frame(height: 0.5), alignment: .bottom)
    }
}

// MARK: - Quanto costa cambiare oggi

private struct SlideUscita: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSostituzione

    private var e: EsitoSostituzione { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Quanto costa cambiare oggi",
                        titolo: e.costoUscita < 0.5 ? "Cambiare oggi non costa nulla" : "Cambiare oggi costa \(CifreDoc.euro(e.costoUscita))",
                        sottotitolo: e.trasferimento ? "È un trasferimento tra fondi pensione: nessuna imposta e gli anni di partecipazione restano."
                                                      : "Chiudendo \(t.a.nome) oggi si pagano subito alcune voci; il resto passa al nuovo prodotto.")
            HStack(spacing: 8) {
                CifraCarta(etichetta: "Vale oggi", valore: CifreDoc.euro(e.valoreOggi))
                if e.penaleUscita > 0.5 { segno("−"); CifraCarta(etichetta: "Penale", valore: CifreDoc.euro(e.penaleUscita), colore: C.negativo) }
                if e.bolloUscita > 0.5 { segno("−"); CifraCarta(etichetta: "Bollo maturato", valore: CifreDoc.euro(e.bolloUscita), colore: C.negativo) }
                if e.impostaUscita > 0.5 { segno("−"); CifraCarta(etichetta: "Imposte", valore: CifreDoc.euro(e.impostaUscita), colore: C.negativo) }
                if e.ingressoCambio > 0.5 { segno("−"); CifraCarta(etichetta: "Ingresso", valore: CifreDoc.euro(e.ingressoCambio), colore: C.negativo) }
                segno("=")
                CifraCarta(etichetta: "Investiti nel nuovo", valore: CifreDoc.euro(e.investitoCambio), colore: C.intermedio)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "Perché si pagano oggi").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                Text(verbatim: spiegazione).font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .riquadroDoc(C.evidenza)
        }
    }

    private func segno(_ s: String) -> some View {
        Text(verbatim: s).font(T.numeroMedio).foregroundColor(C.tenue)
    }

    private var spiegazione: String {
        if e.trasferimento { return "Tra forme di previdenza complementare il capitale si trasferisce intero, senza imposte: le tasse si pagheranno solo alla prestazione, con l'aliquota che nel frattempo sarà scesa." }
        var s = ""
        if e.impostaUscita > 0.5 {
            s += "Le imposte sul guadagno si pagherebbero comunque, ma più avanti: cambiando si pagano oggi e quel denaro non lavora più per te. "
        }
        if e.penaleUscita > 0.5 { s += "La penale è prevista dal contratto per chi riscatta prima di una certa data. " }
        if e.ingressoCambio > 0.5 { s += "Il costo d'ingresso è quello del nuovo prodotto. " }
        if let p = e.pareggio {
            s += p == 1 ? "Secondo le ipotesi, la differenza si recupera già nel primo anno." : "Secondo le ipotesi, la differenza si recupera in \(p) anni."
        } else {
            s += "Secondo le ipotesi, la differenza non si recupera entro \(t.periodo)."
        }
        return s
    }
}

// MARK: - Dove si arriva

private struct SlideArrivo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSostituzione

    private var e: EsitoSostituzione { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TestaReport(occhiello: "Dove arrivi tra \(t.periodo)", titolo: t.titoloVerdetto, sottotitolo: t.sottotitoloVerdetto)
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    if let f = e.finale {
                        CifraCarta(etichetta: "\(t.nomeResto) · netto", valore: CifreDoc.euro(f.nettoResto), colore: C.premio, font: T.numeroGrande)
                        CifraCarta(etichetta: "\(t.nomeCambio) · netto", valore: CifreDoc.euro(f.nettoCambio), colore: C.intermedio, font: T.numeroGrande)
                        CifraCarta(etichetta: "Differenza", valore: CifreDoc.euroSegno(f.differenza),
                                   nota: e.pareggio.map { e.sostituzione ? "pareggio nel \($0)° anno" : "dal \($0)° anno" } ?? "",
                                   colore: f.differenza >= 0 ? C.positivo : C.negativo)
                    }
                }
                .frame(width: 210)
                GraficoLineeDoc(serie: [SerieDoc(nome: t.nomeResto, colore: C.premio, valori: e.serie.map(\.nettoResto), tratteggio: true),
                                        SerieDoc(nome: t.nomeCambio, colore: C.intermedio, valori: e.serie.map(\.nettoCambio))],
                                etichetteAsse: e.serie.map { a in
                                    let passo = e.anni <= 12 ? 1 : (e.anni <= 25 ? 5 : 10)
                                    return a.anno == 0 ? "oggi" : (a.anno % passo == 0 || a.anno == e.anni ? "\(a.anno)° anno" : "")
                                },
                                pareggio: e.sostituzione ? e.pareggio : nil, fontAssi: T.minimo, fontValori: T.minimo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text(verbatim: "Netto incassabile chiudendo alla fine di ogni anno, dopo penali, bollo e imposte. Rendimenti ipotizzati: \(CifreDoc.percento(e.resto.rendimento)) e \(CifreDoc.percento(e.cambio.rendimento)) l'anno lordi, non garantiti.")
                .font(T.minimo).foregroundColor(C.tenue)
        }
    }
}

// MARK: - Se i mercati vanno diversamente

private struct SlideScenari: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSostituzione

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Se i mercati vanno diversamente", titolo: t.tenuta,
                        sottotitolo: "Stessi \(t.periodo), con rendimenti di \(Formati.numeroFormatter.string(from: NSNumber(value: IpotesiCalcolo.ampiezzaScenari)) ?? "2") punti più bassi o più alti per entrambe le strade.")
            HStack(alignment: .top, spacing: 12) {
                ForEach(t.e.scenari) { s in scheda(s) }
            }
        }
    }

    private func scheda(_ s: ScenarioSostituzione) -> some View {
        let colore = s.scarto < 0 ? C.sfavorevole : (s.scarto > 0 ? C.favorevole : C.intermedio)
        return VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: s.nome).font(T.scenarioTitolo).foregroundColor(colore)
            Text(verbatim: "rendimenti \(CifreDoc.percento(t.e.resto.rendimento + s.scarto)) e \(CifreDoc.percento(t.e.cambio.rendimento + s.scarto))")
                .font(T.minimo).foregroundColor(C.tenue)
            riga(t.nomeResto, CifreDoc.euro(s.nettoResto))
            riga(t.nomeCambio, CifreDoc.euro(s.nettoCambio))
            Rectangle().fill(C.filetto).frame(height: 0.8)
            Text(verbatim: CifreDoc.euroSegno(s.differenza)).font(T.scenarioRendimento).foregroundColor(s.differenza >= 0 ? C.positivo : C.negativo)
            Text(verbatim: s.differenza >= 0 ? "a favore di \(t.nomeCambio.lowercased())" : "a favore di \(t.nomeResto.lowercased())")
                .font(T.piccolo).foregroundColor(C.tenue)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: D.raggio).fill(C.scenarioFondo(s.scarto < 0 ? .sfavorevole : (s.scarto > 0 ? .favorevole : .intermedio))))
        .riquadroDoc(.clear)
    }

    private func riga(_ etichetta: String, _ valore: String) -> some View {
        HStack {
            Text(verbatim: etichetta).font(T.piccolo).foregroundColor(C.testo)
            Spacer()
            Text(verbatim: valore).font(T.corpoForte).foregroundColor(C.titolo)
        }
    }
}

// MARK: - Cosa cambia per te

private struct SlideCambia: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSostituzione

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Cosa cambia per te", titolo: t.e.sostituzione ? "Cosa lasci e cosa guadagni cambiando" : "I punti a favore di ciascuna",
                        sottotitolo: "Oltre ai numeri: garanzie, costi, rischio e imposte.")
            HStack(alignment: .top, spacing: 14) {
                colonna(t.e.sostituzione ? "Cosa lasci o paghi" : "A favore di \(t.a.nome)", t.siPerde, colore: C.negativo, segno: "−")
                colonna(t.e.sostituzione ? "Cosa guadagni" : "A favore di \(t.b.nome)", t.siGuadagna, colore: C.positivo, segno: "+")
            }
        }
    }

    private func colonna(_ titolo: String, _ punti: [String], colore: Color, segno: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: titolo).font(T.titoloRiquadro).foregroundColor(colore)
            if punti.isEmpty {
                Text(verbatim: "Nessuna differenza rilevante.").font(T.corpo).foregroundColor(C.tenue)
            }
            ForEach(Array(punti.prefix(6).enumerated()), id: \.offset) { _, p in
                HStack(alignment: .top, spacing: 9) {
                    Text(verbatim: segno).font(T.corpoForte).foregroundColor(colore)
                    Text(verbatim: p).font(T.corpo).foregroundColor(C.testo).lineSpacing(1.4).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .riquadroDoc()
    }
}

// MARK: - In sintesi

private struct SlideSintesiSostituzione: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSostituzione

    private var punti: [(String, String)] {
        var elenco: [(String, String)] = [("Il risultato", t.titoloVerdetto + "."), ("Quanto è solido", t.tenuta)]
        if t.e.sostituzione && t.e.costoUscita > 0.5 {
            var testo = "\(CifreDoc.euro(t.e.costoUscita)) oggi"
            if let p = t.e.pareggio { testo += ", recuperati in " + (p == 1 ? "un anno" : "\(p) anni") } else { testo += ", non recuperati nel periodo" }
            elenco.append(("Il costo dell'uscita", testo + "."))
        }
        return elenco
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "La decisione, in poche righe")
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
             + Text(verbatim: "Simulazione con rendimenti ipotetici e non garantiti, al netto di costi, penali e imposte secondo le regole in vigore oggi. Prima di decidere verifichiamo insieme il valore di riscatto effettivo e il KID dei prodotti. " + TestiSostituzione.avvertenza))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
