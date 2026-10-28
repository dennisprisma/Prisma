import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il prospetto della protezione della famiglia: A4 verticale, per il consulente. Famiglia, fabbisogno
/// caso morte, invalidità e riserva, poi persona per persona, mappa dei rischi, coperture per canale,
/// costi e detrazione dei premi.
enum ProspettoProtezione {
    static func pagine(_ t: TestiProtezione) -> [AnyView] {
        var pagine: [AnyView] = [AnyView(PaginaFabbisogno(t: t))]
        // Per ogni persona che porta reddito: caso morte, invalidità e non autosufficienza
        if !t.e.persone.isEmpty { pagine.append(AnyView(PaginaPersone(t: t))) }
        pagine += [AnyView(PaginaMappa(t: t)), AnyView(PaginaCostiProtezione(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiProtezione.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

private func colore(_ s: StatoTutela, _ C: PaletteDocumento) -> Color {
    switch s {
    case .coperto: return C.positivo
    case .inProposta: return C.intermedio
    case .scoperto: return C.negativo
    }
}

// MARK: - Per ogni persona (prospetto e report)

extension FabbisognoPersona {
    /// "Luca, convivente, 38 anni" o "Giulia Rossi, 36 anni".
    var descrizioneDoc: String {
        var parti = [nome]
        if let r = relazione { parti.append(r.nome.lowercased()) }
        if let anni = eta { parti.append("\(anni) anni") }
        return parti.joined(separator: ", ")
    }

    /// Chi dipende da questa persona e per quanti anni: "Anna (9 anni, per 16 anni)".
    var dipendentiDoc: String {
        dipendenti.map { d -> String in
            let anni = d.eta.map { "\($0) anni, " } ?? ""
            let durata = d.aVita ? "per tutta la vita" : (d.anni == 1 ? "per 1 anno" : "per \(d.anni) anni")
            return "\(d.nome) (\(anni)\(durata))"
        }.joined(separator: ", ")
    }
}

// MARK: - Pagina 2: per ogni persona

private struct PaginaPersone: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    private typealias M = Misure.Documento.Motori
    private var persone: [FabbisognoPersona] { Array(t.e.persone.prefix(M.personeMassime)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Per ogni persona che porta reddito",
                             testo: Text(verbatim: "Il fabbisogno di ciascuno, confrontato con le coperture di cui è l'assicurato. Caso morte: debiti a suo carico, prime spese e sostegno alla famiglia per la sua quota di reddito, finché c'è chi dipende da questa persona. Invalidità: il reddito da sostituire fino alla pensione. Non autosufficienza: \(CifreDoc.euro(IpotesiPersona().spesaAssistenzaMensile)) al mese di assistenza per \(IpotesiPersona().anniAssistenza) anni. Stime da completare con le condizioni di polizza; il fabbisogno del nucleo a pagina 1 resta il riferimento."))
            ForEach(persone) { p in scheda(p) }
            if t.e.persone.count > persone.count {
                Text(verbatim: "…e altre \(t.e.persone.count - persone.count) persone: il dettaglio è nell'Analisi 360.").font(T.pTabellaNota).foregroundColor(C.tenue)
            }
        }
    }

    private func scheda(_ p: FabbisognoPersona) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: p.descrizioneDoc).font(T.pSottosezione).foregroundColor(C.titolo)
                Spacer()
                Text(verbatim: "reddito netto \(CifreDoc.euro(p.redditoNetto)) l'anno\(p.redditoStimato ? " (stimato)" : "") · il \(CifreDoc.percento(p.quotaReddito * 100, decimali: 0)) del nucleo")
                    .font(T.pTabellaNota).foregroundColor(C.tenue)
            }
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Se succede", peso: 2.2, destra: false), ColonnaDoc(titolo: "Fabbisogno"),
                                                       ColonnaDoc(titolo: "Coperto oggi"), ColonnaDoc(titolo: "Scoperto oggi"),
                                                       ColonnaDoc(titolo: "Con le proposte", sottotitolo: "scoperto")],
                       righe: righe(p), fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
            Text(verbatim: dettaglio(p)).font(T.pTabellaNota).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
            ForEach(Array(p.avvisi.prefix(3).enumerated()), id: \.offset) { _, a in
                Text(verbatim: "• " + a).font(T.pTabellaNota).foregroundColor(C.negativo).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 4)
    }

    private func righe(_ p: FabbisognoPersona) -> [RigaDoc] {
        func riga(_ nome: String, _ sotto: String, _ fabbisogno: Double, _ coperto: Double, _ scoperto: Double, _ conProposte: Double) -> RigaDoc {
            RigaDoc(celle: [CellaDoc(nome, sotto: sotto, font: T.pTabellaForte),
                            CellaDoc(CifreDoc.euro(fabbisogno), font: T.pTabella),
                            CellaDoc(CifreDoc.euro(coperto), font: T.pTabella),
                            CellaDoc(CifreDoc.euro(scoperto), colore: scoperto > 0.5 ? C.negativo : C.positivo, font: T.pTabellaForte),
                            CellaDoc(CifreDoc.euro(conProposte), colore: conProposte > 0.5 ? C.negativo : C.positivo, font: T.pTabella)],
                    altezza: M.rigaTabellaBassa + 4)
        }
        return [
            riga("Caso morte", "per \(TestiProtezione.anni(Double(p.anniCopertura)))", p.fabbisognoMorte, p.capitaleMorte, p.divarioMorte, p.divarioMorteConProposte),
            riga("Invalidità", "\(TestiProtezione.anni(Double(p.anniAllaPensione))) alla pensione", p.fabbisognoInvalidita, p.capitaleInvalidita,
                 p.divarioInvalidita, p.divarioInvaliditaConProposte),
            riga("Non autosufficienza", "assistenza", p.fabbisognoLTC, p.capitaleLTC, p.divarioLTC, p.divarioLTCConProposte),
        ]
    }

    private func dettaglio(_ p: FabbisognoPersona) -> String {
        var parti: [String] = []
        if !p.dipendenti.isEmpty { parti.append("Chi dipende da questa persona: \(p.dipendentiDoc).") }
        if p.debiti > 0.5 {
            let durata = p.mesiDebiti.map { " ancora per \($0) mesi" } ?? ""
            parti.append("Debiti a suo carico \(CifreDoc.euro(p.debiti))\(durata).")
        }
        parti.append("Sostegno alla famiglia \(CifreDoc.euro(p.sostegnoAnnuo)) l'anno per \(TestiProtezione.anni(Double(p.anniSostegno))).")
        if p.capitaleInfortuni > 0.5 {
            parti.append("Infortuni \(CifreDoc.euro(p.capitaleInfortuni)), solo se l'invalidità viene da un infortunio.")
        }
        let polizze = (p.coperture + p.proposte).map(\.nome)
        parti.append(polizze.isEmpty ? "Nessuna copertura su questa persona." : "Coperture: \(polizze.joined(separator: ", ")).")
        return parti.joined(separator: " ")
    }
}

// MARK: - Pagina 1: famiglia e fabbisogno

private struct PaginaFabbisogno: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    private var e: EsitoProtezioneFamiglia { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Protezione della famiglia", font: T.pOcchiello)
                Text(verbatim: "La protezione della famiglia di \(t.cliente)").font(T.pTitolo).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.7)
                Text(verbatim: (e.eta.map { "\($0) anni" } ?? "Età non indicata") + (e.famiglia.isEmpty ? " · nessun familiare nel dossier" : " · " + t.chiEFamiglia))
                    .font(T.pSottotitolo).foregroundColor(C.testo).lineLimit(2)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            HStack(spacing: 6) {
                CifraProspetto("Fabbisogno caso morte", CifreDoc.euro(e.fabbisogno), "oltre al disponibile")
                CifraProspetto("Coperture in essere", CifreDoc.euro(e.capitaleVita), "capitali caso morte")
                CifraProspetto("Divario", CifreDoc.euro(e.divario), "oggi", colore: e.divario > 1 ? C.negativo : C.positivo)
                CifraProspetto("Con le proposte", CifreDoc.euro(e.divarioConProposte), e.capitaleVitaProposte > 0 ? "+ \(CifreDoc.euro(e.capitaleVitaProposte)) proposti" : "nessuna proposta caso morte",
                               colore: e.divarioConProposte > 1 ? C.negativo : C.positivo)
                CifraProspetto("Sostegno coperto oggi", TestiProtezione.anni(e.anniCoperti), "di \(e.ipotesi.anniSostegno) anni previsti")
            }
            if !e.famiglia.isEmpty {
                SezioneProspetto(titolo: "Chi dipende dal cliente")
                TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Familiare", peso: 2, destra: false), ColonnaDoc(titolo: "Relazione", peso: 1.2, destra: false),
                                                           ColonnaDoc(titolo: "Età", peso: 0.6), ColonnaDoc(titolo: "A carico", peso: 0.8),
                                                           ColonnaDoc(titolo: "Note", peso: 2.4, destra: false)],
                           righe: e.famiglia.map { f in
                               let figlio = [.figlio, .figlia].contains(f.relazione)
                               let carico = f.aCarico || (figlio && (f.eta ?? 99) < 25)
                               return RigaDoc(celle: [CellaDoc(f.nome, font: T.pTabellaForte), CellaDoc(f.relazione.nome, font: T.pTabella),
                                                      CellaDoc(f.eta.map { "\($0)" } ?? "—", font: T.pTabella), CellaDoc(carico ? "sì" : "no", font: T.pTabella),
                                                      CellaDoc(f.nota.isEmpty ? (figlio && carico ? "fino a 25 anni: ancora \(max(0, 25 - (f.eta ?? 25))) anni" : "") : f.nota, colore: C.tenue, font: T.pTabella)],
                                              altezza: 14)
                           }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            }
            SezioneProspetto(titolo: "Caso morte: quanto servirebbe alla famiglia",
                             testo: Text(verbatim: "Ipotesi dell'Analisi 360 (area Protezione)." + (e.anniSuggeriti.map { " Anni di sostegno suggeriti dal figlio più giovane a carico: \($0)." } ?? "")))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Voce", peso: 3, destra: false), ColonnaDoc(titolo: "Importo", peso: 1.2),
                                                       ColonnaDoc(titolo: "Come si calcola", peso: 2.8, destra: false)],
                       righe: righeFabbisogno, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            SezioneProspetto(titolo: "Invalidità e malattia lunga: il reddito che mancherebbe")
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Voce", peso: 3, destra: false), ColonnaDoc(titolo: "Importo", peso: 1.2),
                                                       ColonnaDoc(titolo: "Nota", peso: 2.8, destra: false)],
                       righe: righeInvalidita, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(t.sintesi.enumerated()), id: \.offset) { _, p in
                        PuntoElenco(testo: Text(verbatim: "\(p.0): ").bold() + Text(verbatim: p.1))
                    }
                }
            }
        }
    }

    private func riga(_ voce: String, _ importo: String, _ nota: String, forte: Bool = false, colore: Color? = nil) -> RigaDoc {
        let font = forte ? T.pTabellaForte : T.pTabella
        return RigaDoc(celle: [CellaDoc(voce, font: font), CellaDoc(importo, colore: colore, font: font), CellaDoc(nota, colore: C.tenue, font: T.pTabellaNota)],
                       altezza: 14, sfondo: forte ? C.riquadro : .clear, filetto: forte ? C.filettoForte : nil, spessore: forte ? 0.8 : 0.5)
    }

    private var righeFabbisogno: [RigaDoc] {
        let i = e.ipotesi
        return [
            riga("Debiti da estinguere", CifreDoc.euro(i.debiti), "mutui e prestiti dalle Posizioni"),
            riga("Spese immediate", CifreDoc.euro(i.speseImmediate), "successione, spese urgenti"),
            riga("Sostegno al tenore di vita", CifreDoc.euro(e.sostegno), "\(CifreDoc.euro(i.fabbisognoMensile)) al mese × 12 × \(i.anniSostegno) anni"),
            riga("Capitale già disponibile", CifreDoc.togli(i.capitaleDisponibile), "liquidità destinata alla famiglia", colore: C.positivo),
            riga("Fabbisogno", CifreDoc.euro(e.fabbisogno), "quanto servirebbe oltre al disponibile", forte: true),
            riga("Coperture caso morte in essere", CifreDoc.togli(e.capitaleVita), "capitali assicurati non scaduti", colore: C.positivo),
            riga("Divario", CifreDoc.euro(e.divario), "da coprire", forte: true, colore: e.divario > 1 ? C.negativo : nil),
            riga("Con le proposte", CifreDoc.euro(e.divarioConProposte), "proposte caso morte \(CifreDoc.euro(e.capitaleVitaProposte))"),
        ]
    }

    private var righeInvalidita: [RigaDoc] {
        let i = e.ipotesi
        return [
            riga("Fabbisogno mensile della famiglia", CifreDoc.euro(i.fabbisognoMensile), "netto"),
            riga("Entrate sostitutive", CifreDoc.togli(i.entrateSostitutive), "INPS, indennità, altri redditi"),
            riga("Ammanco mensile", CifreDoc.euro(e.ammanco), "da coprire con riserva o polizze", forte: true, colore: e.ammanco > 1 ? C.negativo : nil),
            riga("Riserva necessaria", CifreDoc.euro(e.riservaNecessaria), "ammanco × \(i.mesiRiserva) mesi"),
            riga("Riserva disponibile", CifreDoc.togli(i.riserva), "liquidità di emergenza", colore: C.positivo),
            riga("Riserva da costruire", CifreDoc.euro(e.riservaMancante), "", forte: true, colore: e.riservaMancante > 1 ? C.negativo : nil),
        ]
    }
}

// MARK: - Pagina 3: mappa dei rischi e coperture

private struct PaginaMappa: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    private var e: EsitoProtezioneFamiglia { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "La mappa dei rischi",
                             testo: Text(verbatim: "Per ogni rischio: coperture in essere, proposte e perché conta per questa famiglia. In grassetto le tutele importanti."))
            TabellaDoc(larghezza: larghezza, colonne: [
                ColonnaDoc(titolo: "Rischio", peso: 1.6, destra: false), ColonnaDoc(titolo: "Stato", peso: 0.9, destra: false),
                ColonnaDoc(titolo: "Capitale", sottotitolo: "in essere", peso: 1), ColonnaDoc(titolo: "Premio", sottotitolo: "l'anno", peso: 0.8),
                ColonnaDoc(titolo: "Perché conta", peso: 3.2, destra: false),
            ], righe: e.tutele.map { r in
                var perche = CellaDoc(r.perche.isEmpty ? "da valutare con il cliente" : r.perche, colore: C.tenue, font: T.pTabellaNota)
                perche.righe = 2
                return RigaDoc(celle: [CellaDoc(r.rischio.nome, font: r.importante ? T.pTabellaForte : T.pTabella),
                                       CellaDoc(r.stato.nome, colore: colore(r.stato, C), font: T.pTabellaForte),
                                       CellaDoc(r.capitale > 0 ? CifreDoc.euro(r.capitale) : (r.capitaleProposte > 0 ? "(\(CifreDoc.euro(r.capitaleProposte)))" : "—"), font: T.pTabella),
                                       CellaDoc(r.premioAnnuo > 0 ? CifreDoc.euro(r.premioAnnuo) : "—", font: T.pTabella),
                                       perche], altezza: 20)
            }, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
            SezioneProspetto(titolo: "Le coperture, per canale",
                             testo: Text(verbatim: "In essere e proposte; costo per 1.000 € assicurati = premio annuo diviso per il capitale, per mille."))
            if e.coperture.isEmpty && e.proposte.isEmpty {
                Text(verbatim: "Nessuna copertura in essere né proposta.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Copertura", sottotitolo: "tipologia", peso: 2.4, destra: false),
                    ColonnaDoc(titolo: "Rischio", sottotitolo: "stato", peso: 1.4, destra: false),
                    ColonnaDoc(titolo: "Capitale", peso: 1), ColonnaDoc(titolo: "Premio", sottotitolo: "l'anno", peso: 0.85),
                    ColonnaDoc(titolo: "Per 1.000 €", peso: 0.8), ColonnaDoc(titolo: "Scadenza", sottotitolo: "beneficiari", peso: 1.3),
                ], gruppi: Canale.allCases.compactMap { c in
                    let mie = (e.coperture + e.proposte).filter { $0.canale == c }
                    guard !mie.isEmpty else { return nil }
                    return GruppoCanale(canale: c, righe: mie.map { p in
                        let mille = (p.capitaleAssicurato ?? 0) > 0 ? p.premioAnnuo / (p.capitaleAssicurato ?? 1) * 1000 : nil
                        return RigaDoc(celle: [CellaDoc(p.nome, sotto: p.tipologia, font: T.pTabellaForte),
                                               CellaDoc(p.rischio?.nome ?? "—", sotto: p.stato == .proposta ? "proposta" : "in essere", font: T.pTabella),
                                               CellaDoc(CifreDoc.euro(p.capitaleAssicurato ?? 0), font: T.pTabella),
                                               CellaDoc(CifreDoc.euro(p.premioAnnuo), font: T.pTabella),
                                               CellaDoc(mille.map { Formati.euroDecimali($0) } ?? "—", font: T.pTabella),
                                               CellaDoc(TestiResoconto.quando(p.scadenza), sotto: p.beneficiari, font: T.pTabella)],
                                       altezza: 21, sfondo: p.stato == .proposta ? C.evidenza : .clear)
                    }, nota: mie.count == 1 ? "1 copertura" : "\(mie.count) coperture")
                })
            }
            if !e.avvisi.isEmpty {
                RiquadroBarra(titolo: "Da verificare") {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(e.avvisi) { a in PuntoElenco(testo: Text(verbatim: a.testo)) }
                    }
                }
            }
        }
    }
}

// MARK: - Pagina 4: costi, detrazione, metodo

private struct PaginaCostiProtezione: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiProtezione

    private var e: EsitoProtezioneFamiglia { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Quanto costa la protezione e quanto si recupera",
                             testo: Text(verbatim: "Premi annui delle coperture e detrazione IRPEF del 19% sui premi caso morte, invalidità, infortuni e non autosufficienza."))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Voce", peso: 3, destra: false), ColonnaDoc(titolo: "Oggi", peso: 1.2),
                                                       ColonnaDoc(titolo: "Con le proposte", peso: 1.2)],
                       righe: righeCosti, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            SezioneProspetto(titolo: "Ipotesi e metodo")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(e.note.enumerated()), id: \.offset) { _, n in PuntoElenco(testo: Text(verbatim: n)) }
                PuntoElenco(testo: Text(verbatim: "Anni di sostegno coperti oggi: (capitali caso morte + disponibile − debiti − spese immediate) diviso il fabbisogno di un anno."))
                PuntoElenco(testo: Text(verbatim: "Riserva per invalidità o malattia: ammanco mensile per i mesi di riserva indicati, meno la liquidità di emergenza."))
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold()
             + Text(verbatim: "Le cifre sono stime basate sulle ipotesi raccolte con il cliente. Esclusioni, carenze, franchigie e limiti di indennizzo sono nelle condizioni di assicurazione delle singole polizze, che fanno fede. La detrazione dei premi spetta nei limiti di legge e se c'è capienza d'imposta."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }

    private var righeCosti: [RigaDoc] {
        func riga(_ voce: String, _ oggi: String, _ con: String, forte: Bool = false) -> RigaDoc {
            let font = forte ? T.pTabellaForte : T.pTabella
            return RigaDoc(celle: [CellaDoc(voce, font: font), CellaDoc(oggi, font: font), CellaDoc(con, font: font)], altezza: 14,
                           sfondo: forte ? C.riquadro : .clear, filetto: forte ? C.filettoForte : nil, spessore: forte ? 0.8 : 0.5)
        }
        let tot = e.premiAnnui + e.premiProposte
        var righe = [
            riga("Premi in un anno", CifreDoc.euroCentesimi(e.premiAnnui), CifreDoc.euroCentesimi(tot)),
            riga("Al mese", CifreDoc.euroCentesimi(e.premiAnnui / 12), CifreDoc.euroCentesimi(tot / 12)),
            riga("Premi detraibili (nei limiti)", CifreDoc.euroCentesimi(e.detraibili), CifreDoc.euroCentesimi(e.detraibiliConProposte)),
            riga("Detrazione IRPEF del 19%", CifreDoc.euroCentesimi(e.detrazione), CifreDoc.euroCentesimi(e.detrazioneConProposte), forte: true),
            riga("Costo netto in un anno", CifreDoc.euroCentesimi(e.premiAnnui - e.detrazione), CifreDoc.euroCentesimi(tot - e.detrazioneConProposte)),
        ]
        if let r = e.reddito, r > 0 {
            righe.append(riga("Sul reddito lordo di \(CifreDoc.euro(r))", CifreDoc.percento(e.premiAnnui / r * 100, decimali: 2), CifreDoc.percento(tot / r * 100, decimali: 2)))
        }
        return righe
    }
}
