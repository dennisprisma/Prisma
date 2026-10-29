import SwiftUI

private typealias T = Tipo.Report
private typealias D = Misure.Documento

/// Il report della protezione della famiglia: A4 orizzontale, per il cliente. La famiglia, se ti
/// succedesse qualcosa, se non potessi lavorare, la mappa delle tutele, quanto costa, la sintesi.
enum ReportProtezione {
    /// `ipotesi`: i dati da completare del cliente; quelli con il testo per il cliente vanno nella slide
    /// «Le ipotesi da confermare insieme», subito prima della sintesi.
    static func pagine(_ t: TestiProtezione, commento: String? = nil, ipotesi: [VoceCompletezza] = []) -> [AnyView] {
        var slide: [AnyView] = [AnyView(SlideFamiglia(t: t)), AnyView(SlideMorte(t: t)), AnyView(SlideLavoro(t: t))]
        if !t.e.persone.isEmpty { slide.append(AnyView(SlidePersone(t: t))) }
        slide += [AnyView(SlideMappaTutele(t: t)), AnyView(SlideCostoTutele(t: t))]
        slide += SlideIpotesiStimate.slide(ipotesi)
        slide.append(AnyView(SlideSintesiProtezione(t: t)))
        return ImpaginaReport.pagine(copertina: AnyView(copertina(t)), interne: slide, intestazione: "\(TestiProtezione.titolo) · \(t.cliente)",
                                     lettera: commento.map { LetteraConsulente(testo: $0, ruolo: t.ruoloConsulente, data: t.data) })
    }

    private static func copertina(_ t: TestiProtezione) -> CopertinaReport {
        let e = t.e
        var cartellini: [(String, [String])] = []
        if !e.famiglia.isEmpty { cartellini.append(("La famiglia", e.famiglia.prefix(3).map(\.nome))) }
        cartellini.append(("Fabbisogno caso morte", [CifreDoc.euro(e.fabbisogno)]))
        cartellini.append(("Tutele in essere", [e.coperture.count == 1 ? "1 copertura" : "\(e.coperture.count) coperture"]))
        return CopertinaReport(occhiello: "Protezione", titolo: "Proteggere chi ami",
                               sottotitolo: "Cosa succederebbe alla famiglia se ti accadesse qualcosa, e come metterla al sicuro",
                               nomi: t.cliente, ruolo: t.ruoloConsulente, data: t.data,
                               canali: e.canali.isEmpty ? [.alleanza] : e.canali, cartellini: cartellini)
    }
}

private var larghezzaUtile: CGFloat { D.report.width - D.margineReport * 2 }

private struct CifraTutela: View {
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

// MARK: - La tua famiglia

private struct SlideFamiglia: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    var body: some View {
        let e = t.e
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "La tua famiglia", titolo: e.famiglia.isEmpty ? "Chi conta su di te" : "Chi conta su di te, ogni giorno",
                        sottotitolo: "Ogni mese la famiglia ha bisogno di circa \(CifreDoc.euro(e.ipotesi.fabbisognoMensile)) per mantenere il suo tenore di vita.")
            HStack(alignment: .top, spacing: 12) {
                persona(t.cliente, "Tu", e.eta, evidenza: true)
                ForEach(e.famiglia.prefix(4)) { f in
                    persona(f.nome, f.relazione.nome, f.eta, evidenza: false)
                }
            }
            HStack(spacing: 10) {
                CifraTutela(etichetta: "Debiti da estinguere", valore: CifreDoc.euro(e.ipotesi.debiti))
                CifraTutela(etichetta: "Fabbisogno al mese", valore: CifreDoc.euro(e.ipotesi.fabbisognoMensile))
                CifraTutela(etichetta: "Anni di sostegno", valore: "\(e.ipotesi.anniSostegno) anni",
                            nota: e.anniSuggeriti.map { "fino ai 25 anni del più giovane: \($0)" } ?? "")
                CifraTutela(etichetta: "Liquidità per la famiglia", valore: CifreDoc.euro(e.ipotesi.capitaleDisponibile))
            }
        }
    }

    private func persona(_ nome: String, _ ruolo: String, _ eta: Int?, evidenza: Bool) -> some View {
        VStack(spacing: 8) {
            Text(verbatim: String(nome.prefix(1))).font(T.numeroGrande).foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(evidenza ? C.marchio : C.premio))
            Text(verbatim: nome).font(T.titoloRiquadro).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.7)
            Text(verbatim: ruolo + (eta.map { " · \($0) anni" } ?? "")).font(T.piccolo).foregroundColor(C.tenue)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .riquadroDoc(evidenza ? C.evidenza : nil)
    }
}

// MARK: - Se ti succedesse qualcosa

private struct SlideMorte: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    var body: some View {
        let e = t.e
        let totale = max(e.fabbisogno, e.capitaleVita + e.capitaleVitaProposte, 1)
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Se ti succedesse qualcosa", titolo: t.titoloMorte, sottotitolo: t.sottotitoloMorte)
            VStack(alignment: .leading, spacing: 8) {
                barra("Servirebbe", e.fabbisogno, totale: totale, colore: C.titolo)
                barra("Coperture di oggi", e.capitaleVita, totale: totale, colore: C.positivo)
                if e.capitaleVitaProposte > 0 { barra("Con la proposta", e.capitaleVita + e.capitaleVitaProposte, totale: totale, colore: C.intermedio) }
            }
            HStack(spacing: 10) {
                CifraTutela(etichetta: "Manca oggi", valore: CifreDoc.euro(e.divario), colore: e.divario > 1 ? C.negativo : C.positivo, font: T.numeroGrande)
                CifraTutela(etichetta: "Con la proposta", valore: CifreDoc.euro(e.divarioConProposte), colore: e.divarioConProposte > 1 ? C.negativo : C.positivo, font: T.numeroGrande)
                CifraTutela(etichetta: "Oggi la famiglia sarebbe sostenuta per", valore: TestiProtezione.anni(e.anniCoperti),
                            nota: "su \(e.ipotesi.anniSostegno) anni previsti", font: T.numeroGrande)
            }
        }
    }

    private func barra(_ etichetta: String, _ valore: Double, totale: Double, colore: Color) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: etichetta).font(T.piccolo).foregroundColor(C.testo).frame(width: 130, alignment: .leading)
            ZStack(alignment: .leading) {
                Rectangle().fill(C.griglia)
                Rectangle().fill(colore).frame(width: max(2, (larghezzaUtile - 250) * CGFloat(min(valore / totale, 1))))
            }
            .frame(width: larghezzaUtile - 250, height: 20)
            Text(verbatim: CifreDoc.euro(valore)).font(T.corpoForte).foregroundColor(C.titolo).frame(width: 100, alignment: .trailing)
        }
    }
}

// MARK: - Se non potessi lavorare

private struct SlideLavoro: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    var body: some View {
        let e = t.e
        let invalidita = e.tutele.filter { [.invalidita, .infortuni, .salute].contains($0.rischio) }
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Se non potessi lavorare", titolo: t.titoloInvalidita,
                        sottotitolo: "Una malattia lunga o un infortunio fermano il reddito, ma non le spese. Le entrate sostitutive stimate sono di \(CifreDoc.euro(e.ipotesi.entrateSostitutive)) al mese.")
            HStack(spacing: 10) {
                CifraTutela(etichetta: "Servono al mese", valore: CifreDoc.euro(e.ipotesi.fabbisognoMensile))
                Text(verbatim: "−").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraTutela(etichetta: "Entrate sostitutive", valore: CifreDoc.euro(e.ipotesi.entrateSostitutive))
                Text(verbatim: "=").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraTutela(etichetta: "Mancherebbero al mese", valore: CifreDoc.euro(e.ammanco), colore: e.ammanco > 1 ? C.negativo : C.positivo)
                CifraTutela(etichetta: "Riserva per \(e.ipotesi.mesiRiserva) mesi", valore: CifreDoc.euro(e.riservaNecessaria),
                            nota: e.riservaMancante > 1 ? "da costruire \(CifreDoc.euro(e.riservaMancante))" : "già disponibile")
            }
            HStack(alignment: .top, spacing: 12) {
                ForEach(invalidita) { r in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: r.rischio.nome).font(T.titoloRiquadro).foregroundColor(C.titolo)
                        Text(verbatim: r.stato.nome.uppercased()).font(T.occhiello).tracking(1.4).foregroundColor(colore(r.stato))
                        Text(verbatim: r.capitale > 0 ? "Capitale \(CifreDoc.euro(r.capitale))" : (r.capitaleProposte > 0 ? "Proposto \(CifreDoc.euro(r.capitaleProposte))" : "Nessuna copertura"))
                            .font(T.piccolo).foregroundColor(C.testo)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .riquadroDoc()
                }
            }
        }
    }

    private func colore(_ s: StatoTutela) -> Color {
        switch s {
        case .coperto: return C.positivo
        case .inProposta: return C.intermedio
        case .scoperto: return C.negativo
        }
    }
}

// MARK: - Per ogni persona

private struct SlidePersone: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    private typealias M = Misure.Documento.Motori

    var body: some View {
        let persone = Array(t.e.persone.prefix(M.personeMassime))
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "Persona per persona", titolo: titolo,
                        sottotitolo: "Ognuno porta in famiglia una parte del reddito: se venisse a mancare o non potesse più lavorare, servirebbe un capitale diverso. Qui lo confrontiamo con le coperture intestate a ciascuno. Sono stime, da rivedere insieme.")
            HStack(alignment: .top, spacing: M.spazioRiquadri) {
                ForEach(persone) { p in scheda(p) }
            }
            if t.e.persone.count > persone.count {
                Text(verbatim: "…e altre \(t.e.persone.count - persone.count) persone: le vediamo insieme.").font(T.minimo).foregroundColor(C.tenue)
            }
        }
    }

    private var titolo: String {
        let scoperte = t.e.persone.filter { $0.divarioMorte > 0.5 || $0.divarioInvalidita > 0.5 }
        guard let prima = scoperte.first else { return "Persona per persona, le coperture bastano" }
        if scoperte.count > 1 { return "Per \(scoperte.count) persone le coperture non bastano ancora" }
        let nome = prima.nome.split(separator: " ").first.map(String.init) ?? prima.nome
        return "\(nome): le coperture non bastano ancora"
    }

    private func scheda(_ p: FabbisognoPersona) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: p.descrizioneDoc).font(T.titoloRiquadro).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.7)
            Text(verbatim: "porta il \(CifreDoc.percento(p.quotaReddito * 100, decimali: 0)) del reddito di famiglia").font(T.piccolo).foregroundColor(C.tenue)
            Rectangle().fill(C.filetto).frame(height: 0.6)
            voce("Se venisse a mancare", p.fabbisognoMorte, p.capitaleMorte, p.divarioMorte)
            voce("Se non potesse lavorare", p.fabbisognoInvalidita, p.capitaleInvalidita, p.divarioInvalidita)
            voce("Se non fosse autosufficiente", p.fabbisognoLTC, p.capitaleLTC, p.divarioLTC)
            if !p.dipendenti.isEmpty {
                Text(verbatim: "Dipendono da questa persona: \(p.dipendentiDoc).").font(T.minimo).foregroundColor(C.testo)
                    .lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(M.margineRiquadro)
        .frame(maxWidth: .infinity, minHeight: M.schedaReport, alignment: .topLeading)
        .riquadroDoc()
    }

    private func voce(_ titolo: String, _ serve: Double, _ coperto: Double, _ manca: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: titolo).font(T.corpoForte).foregroundColor(C.titolo)
            Text(verbatim: "servirebbero \(CifreDoc.euro(serve)), coperti \(CifreDoc.euro(coperto))").font(T.minimo).foregroundColor(C.testo)
            Text(verbatim: manca > 0.5 ? "mancano \(CifreDoc.euro(manca))" : "coperto").font(T.piccolo.weight(.bold))
                .foregroundColor(manca > 0.5 ? C.negativo : C.positivo)
        }
    }
}

// MARK: - La mappa delle tutele

private struct SlideMappaTutele: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    var body: some View {
        let tutele = t.e.tutele.filter { $0.rischio != .altro }
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "La mappa delle tutele", titolo: t.titoloMappa,
                        sottotitolo: "Verde: coperto. Blu: c'è una proposta. Rosso: scoperto. Le tutele importanti per la tua famiglia sono in evidenza.")
            VStack(spacing: 10) {
                ForEach(Array(stride(from: 0, to: tutele.count, by: 4)), id: \.self) { i in
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(i..<min(i + 4, tutele.count), id: \.self) { j in scheda(tutele[j]) }
                        ForEach(0..<max(0, 4 - (tutele.count - i)), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                    }
                }
            }
        }
    }

    private func scheda(_ r: TutelaRischio) -> some View {
        let colore: Color = r.stato == .coperto ? C.positivo : (r.stato == .inProposta ? C.intermedio : (r.importante ? C.negativo : C.tenue))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(colore).frame(width: 10, height: 10)
                Text(verbatim: r.stato.nome.uppercased()).font(T.occhiello).tracking(1.3).foregroundColor(colore)
            }
            Text(verbatim: r.rischio.nome).font(T.titoloRiquadro).foregroundColor(C.titolo).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            if r.capitale > 0 {
                Text(verbatim: CifreDoc.euro(r.capitale)).font(T.numeroPiccolo).foregroundColor(C.titolo)
            }
            Text(verbatim: r.perche.isEmpty ? "Da valutare insieme." : r.perche).font(T.minimo).foregroundColor(C.testo)
                .lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .riquadroDoc(r.importante ? nil : C.riquadro)
        .opacity(r.importante || r.stato != .scoperto ? 1 : 0.75)
    }
}

// MARK: - Quanto costa

private struct SlideCostoTutele: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    var body: some View {
        let e = t.e
        let tot = e.premiAnnui + e.premiProposte
        return VStack(alignment: .leading, spacing: 16) {
            TestaReport(occhiello: "Quanto costa proteggersi", titolo: t.titoloCosti,
                        sottotitolo: "Parte dei premi torna indietro: lo Stato riconosce una detrazione IRPEF del 19% sui premi caso morte, invalidità, infortuni e non autosufficienza.")
            HStack(spacing: 10) {
                CifraTutela(etichetta: "Premi in un anno", valore: CifreDoc.euro(e.premiAnnui), nota: e.premiProposte > 0.5 ? "con le proposte \(CifreDoc.euro(tot))" : "")
                Text(verbatim: "−").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraTutela(etichetta: "Detrazione IRPEF", valore: CifreDoc.euro(e.detrazione), nota: e.premiProposte > 0.5 ? "con le proposte \(CifreDoc.euro(e.detrazioneConProposte))" : "",
                            colore: C.positivo)
                Text(verbatim: "=").font(T.numeroMedio).foregroundColor(C.tenue)
                CifraTutela(etichetta: "Costo netto al mese", valore: CifreDoc.euro((e.premiAnnui - e.detrazione) / 12),
                            nota: e.premiProposte > 0.5 ? "con le proposte \(CifreDoc.euro((tot - e.detrazioneConProposte) / 12))" : "")
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(e.coperture + e.proposte) { p in
                    HStack(spacing: 10) {
                        Text(verbatim: p.nome).font(T.corpoForte).foregroundColor(C.titolo).frame(width: 240, alignment: .leading).lineLimit(1)
                        Text(verbatim: (p.rischio?.nome ?? "") + (p.stato == .proposta ? " · proposta" : "")).font(T.piccolo).foregroundColor(C.tenue)
                        Spacer()
                        EtichettaCanale(canale: p.canale)
                        Text(verbatim: "\(CifreDoc.euro(p.premioAnnuo)) l'anno").font(T.corpoForte).foregroundColor(C.titolo).frame(width: 110, alignment: .trailing)
                    }
                    .padding(.vertical, 3)
                    .overlay(Rectangle().fill(C.filetto).frame(height: 0.6), alignment: .bottom)
                }
            }
        }
    }
}

// MARK: - In sintesi

private struct SlideSintesiProtezione: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 14) {
            TestaReport(occhiello: "In sintesi", titolo: "La protezione della tua famiglia, in poche righe")
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
            (Text(verbatim: "Come leggere i numeri. ").bold()
             + Text(verbatim: "Stime basate sulle ipotesi che abbiamo raccolto insieme. Esclusioni, carenze e limiti sono nelle condizioni delle singole polizze. " + TestiProtezione.avvertenza))
                .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}
