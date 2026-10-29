import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report del piano previdenziale: A4 orizzontale, per il cliente. Quanto servirà, cosa c'è già,
/// come colmare il resto, il vantaggio fiscale, le tasse sulla pensione, la sintesi.
enum ReportPrevidenza {
    /// `ipotesi`: i dati da completare del cliente; quelli con il testo per il cliente vanno nella slide
    /// «Le ipotesi da confermare insieme», subito prima della sintesi.
    static func pagine(_ t: TestiPrevidenza, commento: String? = nil, ipotesi: [VoceCompletezza] = []) -> [AnyView] {
        var slide: [AnyView] = [AnyView(SlideServira(t: t))]
        if let stima = t.e.stimaPensione { slide.append(AnyView(SlidePensioneStimata(t: t, s: stima))) }
        slide += [AnyView(SlideHaiGia(t: t)), AnyView(SlideColmare(t: t)),
                  AnyView(SlideVantaggio(t: t)), AnyView(SlideTassePensione(t: t))]
        slide += SlideIpotesiStimate.slide(ipotesi)
        slide.append(AnyView(SlideSintesiPrevidenza(t: t)))
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(TestiPrevidenza.titolo) · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiPrevidenza) -> CopertinaReport {
        let e = t.e
        var cartellini: [(String, [String])] = [("Alla pensione", ["a \(e.etaPensione) anni", "tra \(t.anniAllaPensione)"])]
        cartellini.append(("Il divario", [TestiPrevidenza.mese(e.divario)]))
        if !e.piani.isEmpty { cartellini.append(("I tuoi piani", e.piani.prefix(2).map(\.posizione.nome))) }
        return CopertinaReport(occhiello: "Previdenza", titolo: "La tua pensione",
                               sottotitolo: "Quanto ti servirà, cosa hai già costruito e come colmare la differenza",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data,
                               canali: t.canali.isEmpty ? [.indipendente] : t.canali, cartellini: cartellini)
    }
}

private var larghezzaUtile: CGFloat { D.report.width - D.margineReport * 2 }

/// Una cifra su carta.
private struct CifraPensione: View {
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

/// Barra orizzontale a strati: pensione pubblica, piani di oggi, proposte, ciò che manca.
private struct BarraReddito: View {
    @Environment(\.paletteDocumento) private var C
    let e: EsitoPianoPrevidenziale
    var conProposte = true

    var body: some View {
        let totale = max(e.redditoDesiderato, e.pensionePubblica + e.renditaInEssere + (conProposte ? e.renditaProposte : 0), 1)
        let strati: [(String, Double, Color)] = [
            ("Pensione pubblica", e.pensionePubblica, C.premio),
            ("Piani di oggi", min(e.renditaInEssere, max(0, totale - e.pensionePubblica)), C.area(.previdenza)),
            ("Proposte", conProposte ? e.renditaProposte : 0, C.intermedio),
            ("Manca", conProposte ? e.divarioConProposte : e.divarioResiduo, C.sfavorevoleFondo),
        ].filter { $0.1 > 0.5 }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                ForEach(Array(strati.enumerated()), id: \.offset) { _, s in
                    ZStack {
                        Rectangle().fill(s.2)
                        Text(verbatim: CifreDoc.euro(s.1)).font(T.corpoForte).foregroundColor(s.0 == "Manca" ? C.sfavorevole : .white)
                            .lineLimit(1).minimumScaleFactor(0.5).padding(.horizontal, 4)
                    }
                    .frame(width: max(30, (larghezzaUtile - CGFloat(strati.count) * 2) * CGFloat(s.1 / totale)), height: 44)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            HStack(spacing: 16) {
                ForEach(Array(strati.enumerated()), id: \.offset) { _, s in
                    HStack(spacing: 5) {
                        Rectangle().fill(s.2).frame(width: 9, height: 9)
                        Text(verbatim: s.0).font(T.minimo).foregroundColor(C.tenue)
                    }
                }
                Spacer()
                Text(verbatim: "Reddito desiderato \(TestiPrevidenza.mese(e.redditoDesiderato))").font(T.piccolo).foregroundColor(C.titolo)
            }
        }
    }
}

// MARK: - Quanto ti servirà

private struct SlideServira: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza

    var body: some View {
        let e = t.e
        return VStack(alignment: .leading, spacing: 18) {
            TestaReport(occhiello: "Quanto ti servirà", titolo: t.titoloDivario, sottotitolo: t.sottotitoloDivario)
            HStack(spacing: 10) {
                CifraPensione(etichetta: "Reddito desiderato", valore: TestiPrevidenza.mese(e.redditoDesiderato), nota: "netto, in euro di oggi", font: T.numeroGrande)
                Text(verbatim: "−").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraPensione(etichetta: "Pensione pubblica stimata", valore: TestiPrevidenza.mese(e.pensionePubblica), nota: "da verificare sull'estratto INPS", font: T.numeroGrande)
                Text(verbatim: "=").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraPensione(etichetta: "Da integrare", valore: TestiPrevidenza.mese(e.divario), nota: "per \(e.anniIntegrazione) anni di pensione",
                              colore: e.divario > 0.5 ? C.negativo : C.positivo, font: T.numeroGrande)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "Perché ci pensiamo adesso").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                Text(verbatim: "Mancano \(t.anniAllaPensione) alla pensione: più tempo c'è, meno serve versare ogni mese, e ogni versamento riduce subito le imposte di oggi. In più, l'aliquota sulla pensione integrativa scende con gli anni di partecipazione.")
                    .font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .riquadroDoc(C.evidenza)
        }
    }
}

// MARK: - La pensione pubblica stimata

private struct SlidePensioneStimata: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza
    let s: StimaPensione

    private typealias M = Misure.Documento.Motori

    var body: some View {
        let e = t.e
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "La tua pensione pubblica", titolo: "Dai tuoi contributi, circa \(TestiPrevidenza.mese(s.nettaMensile)), netti",
                        sottotitolo: "L'abbiamo stimata con il metodo contributivo: i contributi versati per te ogni anno, rivalutati, diventano pensione a \(s.etaPensione) anni. In euro di oggi, al netto delle imposte, su 13 mensilità. È una stima, da confrontare con il tuo estratto conto INPS.")
            HStack(alignment: .top, spacing: M.spazioRiquadri) {
                VStack(spacing: 8) {
                    CifraPensione(etichetta: "Pensione netta stimata", valore: TestiPrevidenza.mese(s.nettaMensile),
                                  nota: "\(TestiPrevidenza.mese(s.lordaMensile)) lordi", font: T.numeroGrande)
                    CifraPensione(etichetta: "Rispetto al tuo ultimo stipendio", valore: s.tassoSostituzione.map { CifreDoc.percento($0, decimali: 0) } ?? "—",
                                  nota: "pensione lorda sull'ultimo reddito lordo")
                    CifraPensione(etichetta: "Da integrare con questa stima", valore: e.divarioStimato.map { TestiPrevidenza.mese($0) } ?? "—",
                                  nota: "con la stima dell'analisi: \(TestiPrevidenza.mese(e.divario))",
                                  colore: (e.divarioStimato ?? 0) > 0.5 ? C.negativo : C.positivo)
                }
                .frame(width: M.colonnaLateraleReport)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "I tuoi contributi accumulati, anno per anno").font(T.titoloRiquadro).foregroundColor(C.titolo)
                    GraficoLineeDoc(serie: [SerieDoc(nome: "Contributi", colore: C.intermedio, valori: s.punti)],
                                    etichetteAsse: s.punti.indices.map { etichetta($0) }, fontAssi: T.minimo, fontValori: T.minimo)
                        .frame(height: M.graficoMontanteReport)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(verbatim: nota).font(T.minimo).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nota: String {
        var testo = "Ipotesi: rivalutazione dei contributi pari alla crescita dell'economia (prudente), coefficienti di trasformazione \(RegolePensione.validitaCoefficienti), imposte di oggi."
        if !s.requisitoRaggiunto { testo += " Attenzione: all'età indicata i requisiti per la pensione non sono ancora raggiunti." }
        if s.sistemaMisto { testo += " Hai contributi prima del 1996: una parte si calcola con regole diverse, la stima è indicativa." }
        return testo
    }

    private func etichetta(_ anno: Int) -> String {
        let n = max(s.punti.count - 1, 1)
        let passo = n <= 12 ? 2 : (n <= 30 ? 5 : 10)
        if anno == 0 { return "oggi" }
        return anno % passo == 0 || anno == n ? "\(s.eta + anno) anni" : ""
    }
}

// MARK: - Cosa hai già

private struct SlideHaiGia: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza

    var body: some View {
        let e = t.e
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Cosa hai già", titolo: t.titoloCopertura,
                        sottotitolo: e.inEssere.isEmpty ? "Non hai ancora un fondo pensione o un PIP: si può iniziare anche con poco."
                                                        : "Ogni piano portato fino alla pensione con i suoi versamenti, al netto delle imposte, in euro di oggi.")
            BarraReddito(e: e, conProposte: false)
            HStack(alignment: .top, spacing: 12) {
                ForEach(e.inEssere.prefix(3)) { p in scheda(p) }
                if e.inEssere.isEmpty {
                    Text(verbatim: "Nessun piano in essere.").font(T.corpo).foregroundColor(C.tenue)
                }
            }
        }
    }

    private func scheda(_ p: PianoPrevidenza) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EtichettaCanale(canale: p.posizione.canale)
            Text(verbatim: p.posizione.nome).font(T.titoloRiquadro).foregroundColor(C.titolo)
            Text(verbatim: "Oggi \(CifreDoc.euro(p.valoreOggi)) · \(p.anniOggi) anni di partecipazione").font(T.minimo).foregroundColor(C.tenue)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: CifreDoc.euro(p.renditaMensile)).font(T.numeroGrande).foregroundColor(C.area(.previdenza))
                Text(verbatim: "al mese").font(T.piccolo).foregroundColor(C.tenue)
            }
            Text(verbatim: "Alla pensione circa \(CifreDoc.euro(p.nettoReale)) netti in euro di oggi, con imposta al \(CifreDoc.percento(p.aliquota, decimali: 2)).")
                .font(T.piccolo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .riquadroDoc()
    }
}

// MARK: - Come colmare il resto

private struct SlideColmare: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza

    var body: some View {
        let e = t.e
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Come colmare il resto", titolo: t.titoloColmare,
                        sottotitolo: e.proposte.isEmpty ? "Il versamento che servirebbe, da oggi alla pensione, per coprire ciò che manca."
                                                        : "Con la proposta che ti abbiamo preparato, ecco come cambia la tua pensione.")
            BarraReddito(e: e, conProposte: true)
            HStack(alignment: .top, spacing: 12) {
                ForEach(e.proposte.prefix(2)) { p in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(verbatim: "PROPOSTA").font(T.occhiello).tracking(1.4).foregroundColor(C.intermedio)
                            Spacer()
                            EtichettaCanale(canale: p.posizione.canale)
                        }
                        Text(verbatim: p.posizione.nome).font(T.titoloRiquadro).foregroundColor(C.titolo)
                        Text(verbatim: "\(CifreDoc.euro(p.posizione.premio)) \(p.posizione.frequenza == .mensile ? "al mese" : p.posizione.frequenza.nome.lowercased())")
                            .font(T.piccolo).foregroundColor(C.testo)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(verbatim: "+ \(CifreDoc.euro(p.renditaMensile))").font(T.numeroGrande).foregroundColor(C.intermedio)
                            Text(verbatim: "al mese di pensione").font(T.piccolo).foregroundColor(C.tenue)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .riquadroDoc()
                }
                CifraPensione(etichetta: e.divarioConProposte > 0.5 ? "Resta da coprire" : "Divario coperto",
                              valore: TestiPrevidenza.mese(e.divarioConProposte),
                              nota: e.versamentoMancante.map { "servirebbero circa \(CifreDoc.euro($0)) al mese in più" } ?? "",
                              colore: e.divarioConProposte > 0.5 ? C.negativo : C.positivo, font: T.numeroGrande)
            }
        }
    }
}

// MARK: - Il vantaggio fiscale

private struct SlideVantaggio: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza

    var body: some View {
        let e = t.e
        let conProposte = !e.proposte.isEmpty
        let versati = e.contributiInEssere + (conProposte ? e.contributiProposte : 0)
        let risparmio = conProposte ? e.risparmioConProposte : e.risparmioOggi
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Il vantaggio fiscale", titolo: t.titoloFisco, sottotitolo: t.sottotitoloFisco)
            HStack(spacing: 10) {
                CifraPensione(etichetta: "Versi in un anno", valore: CifreDoc.euro(versati))
                Text(verbatim: "−").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraPensione(etichetta: "IRPEF che risparmi", valore: e.aliquotaMarginale == nil ? "—" : CifreDoc.euro(risparmio), colore: C.positivo)
                Text(verbatim: "=").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraPensione(etichetta: "Ti costa davvero", valore: e.aliquotaMarginale == nil ? "—" : CifreDoc.euro(versati - risparmio),
                              nota: e.aliquotaMarginale == nil ? "" : "circa \(CifreDoc.euro((versati - risparmio) / 12)) al mese")
            }
            if e.aliquotaMarginale != nil && e.spazioResiduo > 100 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "Lo spazio che resta").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                    Text(verbatim: "Potresti dedurre ancora \(CifreDoc.euro(e.spazioResiduo)) l'anno: versandoli risparmieresti altri \(CifreDoc.euro(e.risparmioPossibile)) di IRPEF.")
                        .font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .riquadroDoc(C.evidenza)
            }
        }
    }
}

// MARK: - Le tasse sulla pensione

private struct SlideTassePensione: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza

    var body: some View {
        let e = t.e
        let anniOggi = e.piani.map(\.anniOggi).max() ?? 0
        let tappe = [0, 5, 10, 15, 20].map { anniOggi + $0 }.filter { $0 <= anniOggi + max(e.anniAccumulo, 1) } + [anniOggi + e.anniAccumulo]
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Le tasse sulla pensione",
                        titolo: "Più anni nel piano, meno tasse: dal 15% fino al 9%",
                        sottotitolo: "Sulla pensione integrativa si pagano tasse solo sui contributi dedotti. Dopo 15 anni di partecipazione l'aliquota scende ogni anno.")
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(Set(tappe)).sorted(), id: \.self) { anni in
                    let aliquota = RegoleFiscali.aliquotaPrevidenza(anni: anni)
                    VStack(spacing: 5) {
                        Text(verbatim: CifreDoc.percento(aliquota, decimali: anni > 15 ? 1 : 0)).font(T.numeroPiccolo).foregroundColor(C.titolo)
                        Rectangle().fill(anni == anniOggi + e.anniAccumulo ? C.area(.previdenza) : C.premio)
                            .frame(height: CGFloat(aliquota) * 9)
                        Text(verbatim: anni == anniOggi ? "oggi" : (anni == anniOggi + e.anniAccumulo ? "alla pensione" : "tra \(anni - anniOggi) anni"))
                            .font(T.minimo).foregroundColor(C.tenue)
                        Text(verbatim: "\(anni) anni nel piano").font(T.minimo).foregroundColor(C.tenue)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 190)
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "E se servissero prima?").font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                Text(verbatim: "Per spese sanitarie si può avere fino al 75% in qualsiasi momento, con la stessa aliquota agevolata. Per la prima casa (fino al 75%) e per altre esigenze (fino al 30%) dopo 8 anni di iscrizione, con un'imposta del 23%.")
                    .font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .riquadroDoc(C.evidenza)
        }
    }
}

// MARK: - In sintesi

private struct SlideSintesiPrevidenza: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "La tua pensione, in poche righe")
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
             + Text(verbatim: "Importi mensili netti in euro di oggi. La rendita è indicativa: il netto alla pensione diviso per \(t.e.anniIntegrazione) anni. I rendimenti non sono garantiti. " + TestiPrevidenza.avvertenza))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
