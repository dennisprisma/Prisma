import SwiftUI

private typealias T = Tipo.Report

/// Il report del passaggio generazionale: A4 orizzontale, per il cliente.
enum ReportSuccessione {
    static func pagine(_ t: TestiSuccessione, commento: String? = nil) -> [AnyView] {
        let slide: [AnyView] = [AnyView(SlideQuadro(t: t)), AnyView(SlideEredi(t: t)), AnyView(SlideSistemare(t: t)), AnyView(SlideSintesiSuccessione(t: t))]
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(TestiSuccessione.titolo) · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiSuccessione) -> CopertinaReport {
        CopertinaReport(occhiello: "Passaggio generazionale", titolo: "Proteggere chi ami",
                        sottotitolo: "Cosa riceverebbe la tua famiglia, quando e come, e cosa conviene sistemare oggi",
                        nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data,
                        canali: t.canali.isEmpty ? [.indipendente] : t.canali,
                        cartellini: [("Subito, ai beneficiari", [CifreDoc.euro(t.s.fuoriAsse)]), ("Dopo la successione", [CifreDoc.euro(t.s.asseNetto)])])
    }
}

/// Un elenco di posizioni in un riquadro: nome, a chi va, importo.
private struct ElencoDestino: View {
    @Environment(\.paletteDocumento) private var C
    let titolo: String
    let tempo: String
    let totale: Double
    let voci: [Successione.Voce]
    let colore: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: tempo.uppercased()).font(T.occhiello).tracking(1.2).foregroundColor(C.occhiello)
            Text(verbatim: titolo).font(T.titoloRiquadro).foregroundColor(C.titolo)
            Text(verbatim: CifreDoc.euro(totale)).font(T.numeroGrande).foregroundColor(colore)
            ForEach(voci.prefix(5)) { v in
                Rectangle().fill(C.filetto).frame(height: 0.6)
                HStack(spacing: 6) {
                    EtichettaCanale(canale: v.posizione.canale, compatta: true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: v.posizione.nome).font(T.piccolo).foregroundColor(C.titolo).lineLimit(1)
                        if v.destino == .beneficiari {
                            Text(verbatim: v.posizione.beneficiari.isEmpty ? "beneficiari da indicare" : "a \(v.posizione.beneficiari)")
                                .font(T.minimo).foregroundColor(v.posizione.beneficiari.isEmpty ? C.negativo : C.tenue).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    Text(verbatim: CifreDoc.euro(v.importo)).font(T.piccolo).foregroundColor(v.importo < 0 ? C.negativo : C.titolo)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .riquadroDoc()
    }
}

// MARK: - Il quadro

private struct SlideQuadro: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSuccessione

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Cosa passerebbe", titolo: t.titoloQuadro,
                        sottotitolo: "Due strade diverse: quello che hai affidato a una polizza arriva subito a chi hai scelto; il resto segue la successione.")
            HStack(alignment: .top, spacing: 12) {
                ElencoDestino(titolo: "Ai beneficiari che hai indicato", tempo: "In poche settimane", totale: t.s.fuoriAsse, voci: t.beneficiari, colore: C.positivo)
                ElencoDestino(titolo: "Agli eredi, con la successione", tempo: "Dopo alcuni mesi", totale: t.s.asseNetto, voci: t.asse, colore: C.titolo)
            }
        }
    }
}

// MARK: - Gli eredi

private struct SlideEredi: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSuccessione

    var body: some View {
        let s = t.s
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Chi eredita", titolo: t.titoloEredi,
                        sottotitolo: s.eredi.isEmpty ? "Senza testamento l'eredità andrebbe ai parenti più vicini, o allo Stato. Un testamento o i beneficiari di una polizza decidono al posto della legge."
                                                     : "È quello che prevede il codice civile quando non c'è un testamento. Le imposte dipendono dal grado di parentela.")
            HStack(alignment: .top, spacing: 12) {
                ForEach(s.eredi) { e in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: (e.relazione.nome + (e.minorenne ? " · minorenne" : "")).uppercased()).font(T.occhiello).tracking(1.2).foregroundColor(C.occhiello)
                        Text(verbatim: e.nome).font(T.titoloRiquadro).foregroundColor(C.titolo)
                        Text(verbatim: MotoreSuccessione.frazione(e.quota).capitalized).font(T.piccolo).foregroundColor(C.testo)
                        Text(verbatim: CifreDoc.euro(e.importo)).font(T.numeroMedio).foregroundColor(C.titolo)
                        Text(verbatim: e.imposta > 0.5 ? "imposta \(CifreDoc.euro(e.imposta))" : "nessuna imposta di successione").font(T.minimo).foregroundColor(C.tenue)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .riquadroDoc()
                }
                if s.eredi.isEmpty {
                    Text(verbatim: "Nessun familiare registrato erediterebbe.").font(T.corpo).foregroundColor(C.tenue)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading).riquadroDoc()
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "Perché una polizza è diversa").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                Text(verbatim: TestiSuccessione.perchePolizza).font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .riquadroDoc(C.evidenza)
        }
    }
}

// MARK: - Cosa sistemare

private struct SlideSistemare: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSuccessione

    var body: some View {
        let s = t.s
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Da sistemare", titolo: t.titoloSistemare,
                        sottotitolo: "Piccole scelte di oggi che evitano sorprese e tempi lunghi a chi resta.")
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    if let cv = s.conviventeEscluso {
                        punto("\(cv), convivente", "Senza testamento non eredita: lo tutelano una polizza con lui come beneficiario o un testamento, nei limiti della legittima.")
                    }
                    ForEach(s.daSistemare) { v in punto(v.posizione.nome, v.avviso ?? "") }
                    if s.daSistemare.isEmpty && s.conviventeEscluso == nil {
                        punto("Beneficiari", "Tutte le polizze hanno i beneficiari indicati: ricordati di rivederli a ogni cambiamento di famiglia.")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .riquadroDoc()
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "Le imposte").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                    Text(verbatim: s.imposte > 0.5 ? CifreDoc.euro(s.imposte) : "Nessuna").font(T.numeroGrande).foregroundColor(C.titolo)
                    Text(verbatim: s.impostaSuccessione > 0.5 ? "di cui \(CifreDoc.euro(s.impostaSuccessione)) di successione e \(CifreDoc.euro(s.ipocatastali)) ipotecaria e catastale."
                                                               : (s.ipocatastali > 0.5 ? "Solo ipotecaria e catastale sugli immobili: la successione resta entro le franchigie." : "La successione resta entro le franchigie."))
                        .font(T.piccolo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(width: 260, alignment: .topLeading)
                .riquadroDoc(C.evidenza)
            }
        }
    }

    private func punto(_ titolo: String, _ testo: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(verbatim: "!").font(T.corpoForte).foregroundColor(C.intermedio).frame(width: 12)
            (Text(verbatim: "\(titolo). ").bold() + Text(verbatim: testo))
                .font(T.piccolo).foregroundColor(C.testo).lineSpacing(1.3).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - In sintesi

private struct SlideSintesiSuccessione: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSuccessione

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "Il passaggio generazionale, in poche righe")
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
            (Text(verbatim: "Come leggere i numeri. ").bold() + Text(verbatim: TestiSuccessione.avvertenza
                + " Non considera testamento, legittima, donazioni né regime patrimoniale; gli immobili si tassano sul valore catastale, di solito più basso."))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
