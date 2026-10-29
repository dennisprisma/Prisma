import SwiftUI

private typealias T = Tipo.Documento
private typealias R = Tipo.Report
private typealias D = Misure.Documento
private typealias DT = Misure.Documento.TFR

// «TFR in azienda o nel fondo» su carta (giro 6, specifica 11 §7.6): il prospetto per il consulente (A4 verticale,
// 2 pagine) e il report per il cliente (A4 orizzontale, con il tu). Carta bianca e colori fissi della tavolozza:
// azienda `premio`, fondo `area(.previdenza)`, fondo con i contributi `intermedio`, differenze `positivo`/`negativo`.
// Non è un `SceltaProspetto` (toccherebbe Eve): si costruisce da `StatoShell.documentoTFR(report:)`.

extension DocumentoStampabile {
    /// Il prospetto (A4 verticale, 2 pagine) o il report per il cliente (A4 orizzontale) del TFR.
    init(_ t: TestiTFR, report: Bool) {
        titolo = TestiTFR.titolo
        cliente = t.cliente
        genere = report ? "Report" : "Prospetto"
        formato = report ? Misure.Documento.report : Misure.Documento.prospetto
        pagine = report ? ReportTFR.pagine(t) : ProspettoTFR.pagine(t)
        tipo = report ? .report : .prospetto
    }
}

/// Aiuti comuni del prospetto e del report.
private enum CarteTFR {
    /// Le etichette dell'asse degli anni: «oggi», poi una ogni 5 anni e l'ultima («52 anni» se l'età è nota).
    static func etichette(_ t: TestiTFR) -> [String] {
        let n = t.e.ipotesi.anni
        return (0...max(1, n)).map { anno -> String in
            if anno == 0 { return "oggi" }
            guard anno % DT.passoAsse == 0 || anno == n else { return "" }
            return t.eta.map { "\($0 + anno) anni" } ?? "+\(anno) a"
        }
    }

    /// L'anno della tabella: «1 · 48 anni» con l'età, altrimenti «1».
    static func anno(_ a: AnnoTFR, eta: Int?) -> String {
        eta.map { "\(a.anno) · \($0 + a.anno) anni" } ?? "\(a.anno)"
    }

    /// Le righe dell'anno per anno nel prospetto: tutte fino a 25 anni, poi un anno sì e uno no più l'ultimo.
    static func anniProspetto(_ e: EsitoTFR) -> [AnnoTFR] {
        let n = e.anni.count
        guard n > DT.anniTabellaCompleta else { return e.anni }
        var scelti = e.anni.filter { $0.anno % 2 == 1 }
        if let ultimo = e.anni.last, scelti.last?.anno != ultimo.anno { scelti.append(ultimo) }
        return Array(scelti.prefix(DT.righeTabellaMassime))
    }
}

// MARK: - Prospetto (A4 verticale)

enum ProspettoTFR {
    static func pagine(_ t: TestiTFR) -> [AnyView] {
        let pagine: [AnyView] = [AnyView(PaginaStradeTFR(t: t)), AnyView(PaginaAnniTFR(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiTFR.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }

    static var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }
}

/// Pagina 1: le due strade, le cifre, la tabella del confronto, il grafico dei montanti, la sintesi.
private struct PaginaStradeTFR: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiTFR

    private var e: EsitoTFR { t.e }
    private var i: IpotesiTFR { t.e.ipotesi }

    var body: some View {
        VStack(alignment: .leading, spacing: DT.spazioPagina) {
            VStack(alignment: .leading, spacing: DT.spazioTesta) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Previdenza", font: T.pOcchiello)
                Text(verbatim: "Il TFR di \(t.cliente): in azienda o nel fondo pensione").font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: sottotitolo).font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: DT.spazioCampi) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: DT.colonnaData)
                HStack(alignment: .bottom, spacing: DT.spazioTesta) {
                    Text(verbatim: "Canale").font(T.pTabellaNota).foregroundColor(C.tenue)
                    EtichettaCanale(canale: i.canale, compatta: true)
                }
                .fixedSize()
                CampoProspetto(etichetta: "Fondo", valore: t.nomeFondo)
            }
            FilaCifre(spazio: DT.spazioCifre) {
                CifraProspetto("TFR in azienda", CifreDoc.euro(e.azienda.netto), "in euro di oggi \(CifreDoc.euro(e.azienda.reale))")
                CifraProspetto("Nel fondo, solo TFR", CifreDoc.euro(e.fondo.netto), "in euro di oggi \(CifreDoc.euro(e.fondo.reale))")
                CifraProspetto("Differenza", CifreDoc.euroSegno(e.differenza), "fondo meno azienda, al netto", colore: coloreDifferenza(e.differenza))
                CifraProspetto("Pareggio", valorePareggio, notaPareggio)
                if let c = e.fondoContributi {
                    CifraProspetto("Con i contributi", CifreDoc.euro(c.netto), "netto alla pensione")
                } else {
                    CifraProspetto("Con i contributi", "—", "nessun contributo")
                }
            }
            SezioneProspetto(titolo: "Le due strade a confronto",
                             testo: Text(verbatim: "Il TFR futuro di \(t.anniAllaPensione) di lavoro, lasciato in azienda o versato in \(destinazione); importi alla pensione, in euro nominali salvo l'ultima riga."))
            TabellaDoc(larghezza: ProspettoTFR.larghezza, colonne: colonne, righe: righe, fontTesta: T.pTabellaTesta,
                       altezzaTesta: DT.testaTabella, margine: DT.margineCella)
            SezioneProspetto(titolo: "Come crescono i montanti",
                             testo: Text(verbatim: "Anno per anno, prima delle imposte all'uscita."))
            GraficoLineeDoc(serie: serie, etichetteAsse: CarteTFR.etichette(t), fontAssi: T.pAssi, fontValori: T.pTabellaNota)
                .frame(height: DT.graficoProspetto)
                .background(C.riquadro.opacity(DT.opacitaFondoGrafico))
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: DT.spazioElenco) {
                    ForEach(Array(t.sintesi.enumerated()), id: \.offset) { _, p in
                        PuntoElenco(testo: Text(verbatim: "\(p.0): ").bold() + Text(verbatim: p.1))
                    }
                }
            }
        }
    }

    /// «un fondo pensione» o «Fondo negoziale di categoria» tra virgolette.
    private var destinazione: String {
        i.nomeFondo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "un fondo pensione" : "«" + t.nomeFondo + "»"
    }

    private var sottotitolo: String {
        "\(t.anniAllaPensione) alla pensione · retribuzione lorda \(CifreDoc.euro(i.retribuzione)) · crescita \(CifreDoc.percento(e.crescitaNominale, decimali: 2)) l'anno · inflazione \(Formati.percentuale(i.inflazione))"
    }

    private func coloreDifferenza(_ v: Double) -> Color? {
        if v > TestiTFR.sogliaEquivalenza { return C.positivo }
        if v < -TestiTFR.sogliaEquivalenza { return C.negativo }
        return nil
    }

    private var valorePareggio: String {
        switch e.pareggio {
        case .a(let lordo, _): return CifreDoc.percento(lordo, decimali: 2)
        case .sempre: return "sempre"
        case .mai: return "mai"
        }
    }

    private var notaPareggio: String {
        switch e.pareggio {
        case .a(_, let netto): return "lordo l'anno · netto \(CifreDoc.percento(netto, decimali: 2))"
        case .sempre: return "anche al \(CifreDoc.percento(RegoleTFR.pareggioMinimo, decimali: 0)) l'anno"
        case .mai: return "nemmeno al \(CifreDoc.percento(RegoleTFR.pareggioMassimo, decimali: 0)) l'anno"
        }
    }

    private var serie: [SerieDoc] {
        var s = [SerieDoc(nome: "In azienda", colore: C.premio, valori: e.puntiAzienda.map(\.valore)),
                 SerieDoc(nome: "Nel fondo", colore: C.area(.previdenza), valori: e.puntiFondo.map(\.valore))]
        if let c = e.puntiFondoContributi {
            s.append(SerieDoc(nome: "Con i contributi", colore: C.intermedio, valori: c.map(\.valore)))
        }
        return s
    }

    private var colonne: [ColonnaDoc] {
        var c = [ColonnaDoc(titolo: "Voce", peso: 2.4, destra: false),
                 ColonnaDoc(titolo: "In azienda"),
                 ColonnaDoc(titolo: "Nel fondo", sottotitolo: "solo TFR")]
        if e.conContributi { c.append(ColonnaDoc(titolo: "Nel fondo", sottotitolo: "con i contributi")) }
        return c
    }

    private var righe: [RigaDoc] {
        let con = e.fondoContributi
        func riga(_ voce: String, _ a: String, _ b: String, _ c: String? = nil, colore: Color? = nil, forte: Bool = false) -> RigaDoc {
            let font = forte ? T.pTabellaForte : T.pTabella
            var celle = [CellaDoc(voce, font: font), CellaDoc(a, colore: colore, font: font), CellaDoc(b, colore: colore, font: font)]
            if con != nil { celle.append(CellaDoc(c ?? "—", colore: colore, font: font)) }
            return RigaDoc(celle: celle, altezza: DT.rigaTabella, sfondo: forte ? C.riquadro : .clear,
                           filetto: forte ? C.filettoForte : nil)
        }
        let quote = CifreDoc.euro(e.quote)
        var r = [riga("Quote di TFR accantonate", quote, quote, quote)]
        if con != nil {
            r.append(riga("I tuoi contributi", "—", "—", CifreDoc.euro(e.versatoLavoratore)))
            r.append(riga("Contributi del datore", "—", "—", CifreDoc.euro(e.versatoDatore)))
        }
        let rendimento = CifreDoc.percento(e.rendimentoNettoFondo, decimali: 2)
        r.append(riga("Rivalutazione o rendimento netto l'anno", CifreDoc.percento(e.rivalutazioneNetta, decimali: 2), rendimento, rendimento))
        r.append(riga("Montante alla pensione", CifreDoc.euro(e.azienda.montante), CifreDoc.euro(e.fondo.montante),
                      con.map { CifreDoc.euro($0.montante) }))
        r.append(riga("Imponibile all'uscita", CifreDoc.euro(e.azienda.imponibile), CifreDoc.euro(e.fondo.imponibile),
                      con.map { CifreDoc.euro($0.imponibile) }))
        r.append(riga("Aliquota", CifreDoc.percento(e.azienda.aliquota, decimali: 2), CifreDoc.percento(e.fondo.aliquota, decimali: 2),
                      con.map { CifreDoc.percento($0.aliquota, decimali: 2) }))
        r.append(riga("Imposta", CifreDoc.togli(e.azienda.imposta), CifreDoc.togli(e.fondo.imposta),
                      con.map { CifreDoc.togli($0.imposta) }, colore: C.negativo))
        r.append(riga("Netto alla pensione", CifreDoc.euro(e.azienda.netto), CifreDoc.euro(e.fondo.netto),
                      con.map { CifreDoc.euro($0.netto) }, forte: true))
        r.append(riga("In euro di oggi", CifreDoc.euro(e.azienda.reale), CifreDoc.euro(e.fondo.reale), con.map { CifreDoc.euro($0.reale) }))
        if con != nil {
            r.append(riga("Costo dei tuoi contributi (IRPEF risparmiata compresa, portato alla pensione)", "—", "—",
                          CifreDoc.togli(e.costoContributi), colore: C.negativo))
        }
        return r
    }
}

/// Pagina 2: anno per anno, metodo, semplificazioni, da sapere.
private struct PaginaAnniTFR: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiTFR

    private var e: EsitoTFR { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: DT.spazioPagina) {
            SezioneProspetto(titolo: "Anno per anno",
                             testo: Text(verbatim: e.anni.count > DT.anniTabellaCompleta
                                         ? "Valori a fine anno, un anno sì e uno no più l'ultimo; montanti prima delle imposte all'uscita."
                                         : "Valori a fine anno; montanti prima delle imposte all'uscita."))
            TabellaDoc(larghezza: ProspettoTFR.larghezza, colonne: colonne, righe: righe, fontTesta: T.pTabellaTesta,
                       altezzaTesta: DT.testaTabella, margine: DT.margineCella)
            SezioneProspetto(titolo: "Come si calcola")
            elenco(TestiTFR.metodo)
            SezioneProspetto(titolo: "Semplificazioni")
            elenco(TestiTFR.semplificazioni)
            RiquadroBarra(titolo: "Da sapere") {
                VStack(alignment: .leading, spacing: DT.spazioElenco) {
                    ForEach(Array(TestiTFR.daSapere.enumerated()), id: \.offset) { _, d in PuntoElenco(testo: Text(verbatim: d)) }
                }
            }
        }
    }

    /// Un elenco fitto in corpo piccolo: la tabella degli anni occupa gran parte della pagina.
    private func elenco(_ voci: [String]) -> some View {
        VStack(alignment: .leading, spacing: DT.spazioElenco) {
            ForEach(Array(voci.enumerated()), id: \.offset) { _, v in
                Text(verbatim: "• " + v).font(T.pTabellaNota).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var colonne: [ColonnaDoc] {
        var c = [ColonnaDoc(titolo: "Anno", peso: 1.1, destra: false), ColonnaDoc(titolo: "Retribuzione"), ColonnaDoc(titolo: "Quota TFR"),
                 ColonnaDoc(titolo: "In azienda"), ColonnaDoc(titolo: "Nel fondo")]
        if e.conContributi { c.append(ColonnaDoc(titolo: "Con i contributi")) }
        return c
    }

    private var righe: [RigaDoc] {
        CarteTFR.anniProspetto(e).map { a in
            var celle = [CellaDoc(CarteTFR.anno(a, eta: t.eta), font: T.pTabellaForte), CellaDoc(CifreDoc.euro(a.retribuzione), font: T.pTabella),
                         CellaDoc(CifreDoc.euro(a.quota), font: T.pTabella), CellaDoc(CifreDoc.euro(a.azienda), font: T.pTabella),
                         CellaDoc(CifreDoc.euro(a.fondo), font: T.pTabella)]
            if e.conContributi { celle.append(CellaDoc(CifreDoc.euro(a.fondoContributi), font: T.pTabella)) }
            return RigaDoc(celle: celle, altezza: DT.rigaAnno)
        }
    }
}

// MARK: - Report (A4 orizzontale, per il cliente)

enum ReportTFR {
    static func pagine(_ t: TestiTFR) -> [AnyView] {
        var slide: [AnyView] = [AnyView(SlideStradeTFR(t: t)), AnyView(SlidePareggioTFR(t: t))]
        if t.e.conContributi { slide.append(AnyView(SlideContributiTFR(t: t))) }
        slide.append(AnyView(SlidePrimaDiScegliere(t: t)))
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(TestiTFR.titolo) · \(t.cliente)")
    }

    private static func copertina(_ t: TestiTFR) -> CopertinaReport {
        CopertinaReport(occhiello: "Previdenza", titolo: "Il tuo TFR",
                        sottotitolo: "In azienda o nel fondo pensione: cosa ti resta alla pensione",
                        nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data, canali: t.canali,
                        cartellini: [("Alla pensione", ["tra \(t.anniAllaPensione)"]), ("Il confronto", ["TFR in azienda", t.nomeFondo])])
    }
}

/// Una cifra in un riquadro del report.
private struct CifraReportTFR: View {
    @Environment(\.paletteDocumento) private var C
    let etichetta: String
    let valore: String
    var nota = ""
    var colore: Color? = nil
    var font = Tipo.Report.numeroMedio

    var body: some View {
        VStack(alignment: .leading, spacing: DT.spazioRiquadro) {
            Text(verbatim: etichetta).font(R.piccolo).foregroundColor(C.tenue).lineLimit(1).minimumScaleFactor(0.8)
            Text(verbatim: valore).font(font).foregroundColor(colore ?? C.titolo).lineLimit(1).minimumScaleFactor(0.6)
            if !nota.isEmpty {
                Text(verbatim: nota).font(R.minimo).foregroundColor(C.tenue).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DT.margineRiquadro)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroDoc()
    }
}

/// Larghezza utile del report.
private var larghezzaReport: CGFloat { D.report.width - D.margineReport * 2 }

/// Slide 1: due strade per lo stesso TFR.
private struct SlideStradeTFR: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiTFR

    private var e: EsitoTFR { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: DT.spazioSlide) {
            TestaReport(occhiello: "Le due strade", titolo: t.titoloConfronto, sottotitolo: t.sottotitoloConfronto)
            HStack(alignment: .top, spacing: DT.spazioRiquadri) {
                strada("Lasciato in azienda", e.azienda, colore: C.premio)
                strada("Nel fondo pensione", e.fondo, colore: C.area(.previdenza))
            }
            VStack(alignment: .leading, spacing: DT.spazioBarre) {
                Text(verbatim: "Quanto ti resta, netto, alla pensione").font(R.titoloRiquadro).foregroundColor(C.titolo)
                barra("TFR in azienda", e.azienda.netto, colore: C.premio)
                barra(t.nomeFondo, e.fondo.netto, colore: C.area(.previdenza))
            }
        }
    }

    private var massimo: Double { max(e.azienda.netto, e.fondo.netto, 1) }

    private func strada(_ titolo: String, _ s: StradaTFR, colore: Color) -> some View {
        VStack(alignment: .leading, spacing: DT.spazioRiquadro) {
            HStack(spacing: DT.spazioRiquadro) {
                Rectangle().fill(colore).frame(width: DT.spazioRiquadro, height: DT.spazioRiquadro * 2)
                Text(verbatim: titolo).font(R.titoloRiquadro).foregroundColor(C.titolo)
            }
            HStack(alignment: .top, spacing: DT.spazioRiquadri) {
                CifraReportTFR(etichetta: "Netto alla pensione", valore: CifreDoc.euro(s.netto), font: R.numeroGrande)
                CifraReportTFR(etichetta: "In euro di oggi", valore: CifreDoc.euro(s.reale), nota: "tolta l'inflazione")
                CifraReportTFR(etichetta: "Imposta all'uscita", valore: CifreDoc.percento(s.aliquota, decimali: 1),
                               nota: CifreDoc.togli(s.imposta))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barra(_ etichetta: String, _ v: Double, colore: Color) -> some View {
        let cifra = Misure.Documento.Motori.colonnaCifraReport
        let utile = max(DT.barraMinima, larghezzaReport - DT.colonnaEtichettaBarra - cifra - DT.spazioBarre * 2)
        let lunghezza = max(DT.barraMinima, utile * CGFloat(max(0, v) / massimo))
        return HStack(spacing: DT.spazioBarre) {
            Text(verbatim: etichetta).font(R.piccolo).foregroundColor(C.testo).lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: DT.colonnaEtichettaBarra, alignment: .leading)
            RoundedRectangle(cornerRadius: DT.raggioBarra).fill(colore).frame(width: lunghezza, height: DT.barra)
            Text(verbatim: CifreDoc.euro(v)).font(R.corpoForte).foregroundColor(C.titolo).lineLimit(1)
                .frame(width: cifra, alignment: .leading)
            Spacer(minLength: 0)
        }
    }
}

/// Slide 2: quanto deve rendere il fondo.
private struct SlidePareggioTFR: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiTFR

    private var e: EsitoTFR { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: DT.spazioSlide) {
            TestaReport(occhiello: "Quanto deve rendere il fondo", titolo: t.titoloPareggio)
            Text(verbatim: t.testoPareggio)
                .font(R.numeroPiccolo).foregroundColor(C.testo)
                .lineSpacing(DT.interlinea).fixedSize(horizontal: false, vertical: true)
            GraficoLineeDoc(serie: serie, etichetteAsse: CarteTFR.etichette(t), fontAssi: R.minimo, fontValori: R.minimo)
                .frame(height: DT.graficoReportBreve)
            Text(verbatim: "Il TFR in azienda non scende mai; il fondo oscilla con i mercati secondo il comparto. Le linee mostrano i montanti prima delle imposte all'uscita.")
                .font(R.minimo).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var serie: [SerieDoc] {
        var s = [SerieDoc(nome: "In azienda", colore: C.premio, valori: e.puntiAzienda.map(\.valore)),
                 SerieDoc(nome: "Nel fondo", colore: C.area(.previdenza), valori: e.puntiFondo.map(\.valore))]
        if let c = e.puntiFondoContributi {
            s.append(SerieDoc(nome: "Con i contributi", colore: C.intermedio, valori: c.map(\.valore)))
        }
        return s
    }
}

/// Slide 3 (solo con i contributi): se aggiungi il tuo contributo.
private struct SlideContributiTFR: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiTFR

    private var e: EsitoTFR { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: DT.spazioSlide) {
            TestaReport(occhiello: "Se aggiungi il tuo contributo",
                        titolo: "Con i contributi: \(CifreDoc.euro(e.fondoContributi?.netto ?? 0)) netti alla pensione",
                        sottotitolo: t.testoContributi)
            HStack(alignment: .top, spacing: DT.spazioRiquadri) {
                CifraReportTFR(etichetta: "Netto con i contributi", valore: CifreDoc.euro(e.fondoContributi?.netto ?? 0),
                               nota: "in euro di oggi \(CifreDoc.euro(e.fondoContributi?.reale ?? 0))", colore: C.intermedio, font: R.numeroGrande)
                CifraReportTFR(etichetta: "Quanto versi tu", valore: CifreDoc.euro(e.versatoLavoratore),
                               nota: "in \(t.anniAllaPensione)")
                CifraReportTFR(etichetta: "Quanto ti restituisce l'IRPEF", valore: CifreDoc.euro(e.risparmioIrpef),
                               nota: "deducendo i tuoi versamenti", colore: C.positivo)
                CifraReportTFR(etichetta: "Il contributo del datore", valore: CifreDoc.euro(e.versatoDatore),
                               nota: e.versatoDatore > 0.5 ? "se aderisci al fondo di categoria" : "nessuno")
            }
            if let d = e.differenzaContributi {
                VStack(alignment: .leading, spacing: DT.spazioRiquadro) {
                    Text(verbatim: "Rispetto al TFR lasciato in azienda").font(R.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                    Text(verbatim: testoDifferenza(d))
                        .font(R.corpo).foregroundColor(C.testo).lineSpacing(DT.interlinea).fixedSize(horizontal: false, vertical: true)
                }
                .padding(DT.margineRiquadro)
                .frame(maxWidth: .infinity, alignment: .leading)
                .riquadroDoc(C.evidenza)
            }
        }
    }

    /// La frase sotto «Rispetto al TFR lasciato in azienda» (spezzata per il controllo dei tipi).
    private func testoDifferenza(_ d: Double) -> String {
        let costo = CifreDoc.euro(e.costoContributi)
        let frase = "\(CifreDoc.euroSegno(d)) alla pensione, contando quanto ti costano i tuoi contributi (\(costo), IRPEF risparmiata compresa)."
        guard let pareggio = t.pareggioContributiBreve else { return frase }
        return frase + " " + pareggio
    }
}

/// Ultima slide: prima di scegliere.
private struct SlidePrimaDiScegliere: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiTFR

    var body: some View {
        VStack(alignment: .leading, spacing: DT.spazioSlide) {
            TestaReport(occhiello: "Prima di scegliere", titolo: "Quello che conta sapere",
                        sottotitolo: "Il confronto usa le regole di oggi e ipotesi costanti: serve a capire l'ordine di grandezza, non a prevedere.")
            VStack(alignment: .leading, spacing: DT.spazioPunti) {
                ForEach(Array(TestiTFR.daSapere.enumerated()), id: \.offset) { _, d in
                    punto(d, forte: true)
                }
            }
            .padding(DT.margineRiquadro)
            .frame(maxWidth: .infinity, alignment: .leading)
            .riquadroDoc(C.evidenza)
            VStack(alignment: .leading, spacing: DT.spazioPunti) {
                Text(verbatim: "Le semplificazioni principali").font(R.titoloRiquadro).foregroundColor(C.titolo)
                ForEach(Array(TestiTFR.semplificazioni.prefix(4).enumerated()), id: \.offset) { _, s in
                    punto(s, forte: false)
                }
            }
            Text(verbatim: TestiTFR.avvertenza).font(R.minimo).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func punto(_ testo: String, forte: Bool) -> some View {
        HStack(alignment: .top, spacing: DT.spazioPunti) {
            Text(verbatim: "•").font(R.corpoForte)
            Text(verbatim: testo).font(forte ? R.corpo : R.piccolo).lineSpacing(DT.interlinea).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(C.testo)
    }
}
