import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il prospetto del check-up del primo incontro: A4 verticale, per il consulente.
enum ProspettoCheckUp {
    /// `ipotesi`: i dati da completare del cliente; se ci sono, una pagina in fondo li dichiara
    /// (prima della numerazione, così «pag. x di y» la conta). `percentuale`: la completezza dei dati.
    static func pagine(_ t: TestiCheckUp, ipotesi: [VoceCompletezza] = [], percentuale: Int? = nil) -> [AnyView] {
        var pagine: [AnyView] = [AnyView(PaginaChiE(t: t)), AnyView(PaginaSemaforo(t: t))]
        if !ipotesi.isEmpty { pagine.append(AnyView(PaginaIpotesiStimate(voci: ipotesi, percentuale: percentuale))) }
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiCheckUp.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

func coloreSemaforo(_ s: Semaforo, _ C: PaletteDocumento) -> Color {
    switch s {
    case .verde: return C.positivo
    case .giallo: return C.fondoInterno
    case .rosso: return C.negativo
    case .grigio: return C.tenue
    }
}

// MARK: - Pagina 1: chi è e la fotografia

private struct PaginaChiE: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCheckUp

    private var e: EsitoCheckUp { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Check-up del primo incontro", font: T.pOcchiello)
                Text(verbatim: "Il check-up di \(t.cliente)").font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: t.chiSei).font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            FilaCifre {
                CifraProspetto("Patrimonio netto", CifreDoc.euro(e.riepilogo.patrimonioNetto), "attività − debiti")
                CifraProspetto("Liquidità", CifreDoc.euro(e.riepilogo.perArea[.liquidita] ?? 0), "conti e depositi")
                CifraProspetto("Investito", CifreDoc.euro((e.riepilogo.perArea[.investimento] ?? 0) + (e.riepilogo.perArea[.risparmio] ?? 0) + (e.riepilogo.perArea[.previdenza] ?? 0)),
                               "investimento, risparmio, previdenza")
                CifraProspetto("Debiti", CifreDoc.euro(e.riepilogo.debiti), "residui")
                CifraProspetto("Capitali assicurati", CifreDoc.euro(e.riepilogo.capitaleAssicurato), "\(e.riepilogo.coperture) coperture")
            }
            if let c = e.cliente {
                SezioneProspetto(titolo: "Chi è")
                TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Voce", peso: 1.4, destra: false), ColonnaDoc(titolo: "Cosa sappiamo", peso: 3.6, destra: false)],
                           righe: anagrafica(c), fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
                if !c.famiglia.isEmpty {
                    TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Familiare", peso: 2, destra: false), ColonnaDoc(titolo: "Relazione", peso: 1.2, destra: false),
                                                               ColonnaDoc(titolo: "Età", peso: 0.6), ColonnaDoc(titolo: "A carico", peso: 0.8)],
                               righe: c.famiglia.map { f in
                                   RigaDoc(celle: [CellaDoc(f.nome, font: T.pTabellaForte), CellaDoc(f.relazione.nome, font: T.pTabella),
                                                   CellaDoc(f.eta.map { "\($0)" } ?? "—", font: T.pTabella), CellaDoc(f.aCarico ? "sì" : "no", font: T.pTabella)], altezza: 14)
                               }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
                }
            }
            SezioneProspetto(titolo: "La fotografia per area")
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Area", peso: 2, destra: false), ColonnaDoc(titolo: "Valore"), ColonnaDoc(titolo: "Quota", peso: 0.7)],
                       righe: AreaPosizione.allCases.sorted { $0.ordine < $1.ordine }.compactMap { a in
                           guard let v = e.riepilogo.perArea[a], v > 0.5 else { return nil }
                           let quota = a.passivo || e.riepilogo.attivita <= 0 ? "—" : CifreDoc.percento(v / e.riepilogo.attivita * 100, decimali: 0)
                           return RigaDoc(celle: [CellaDoc(a.nome, font: T.pTabellaForte), CellaDoc((a.passivo ? "− " : "") + CifreDoc.euro(v), font: T.pTabella),
                                                  CellaDoc(quota, font: T.pTabella)], altezza: 14)
                       }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            HStack(spacing: 8) {
                // Il titolo sulla stessa riga: le etichette non restano isolate e la pagina non si allunga
                if Canale.allCases.contains(where: { (e.riepilogo.perCanale[$0] ?? 0) > 0.5 }) {
                    Text(verbatim: "Per canale").font(T.pSottosezione).foregroundColor(C.titolo)
                }
                ForEach(Canale.allCases) { c in
                    if let v = e.riepilogo.perCanale[c], v > 0.5 {
                        HStack(spacing: 6) {
                            EtichettaCanale(canale: c)
                            Text(verbatim: CifreDoc.euro(v)).font(T.pCorpoForte).foregroundColor(C.titolo)
                        }
                    }
                }
            }
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(t.sintesi.enumerated()), id: \.offset) { _, p in
                        PuntoElenco(testo: Text(verbatim: "\(p.0): ").bold() + Text(verbatim: p.1))
                    }
                }
            }
        }
    }

    private func anagrafica(_ c: Cliente) -> [RigaDoc] {
        func riga(_ voce: String, _ valore: String) -> RigaDoc {
            RigaDoc(celle: [CellaDoc(voce, colore: C.tenue, font: T.pTabella), CellaDoc(valore.isEmpty ? "—" : valore, font: T.pTabella)], altezza: 14)
        }
        return [
            riga("Età e professione", [c.eta.map { "\($0) anni" } ?? "", c.professione].filter { !$0.isEmpty }.joined(separator: " · ")),
            riga("Stato civile", c.statoCivile?.nome ?? ""),
            riga("Reddito lordo annuo", c.profilo.redditoLordoAnnuo.map { CifreDoc.euro($0) } ?? "da raccogliere"),
            riga("Profilo", [c.profilo.propensione.map { "propensione \($0.nome.lowercased())" }, c.profilo.orizzonteAnni.map { "orizzonte \($0) anni" },
                             c.profilo.esperienza.map { "esperienza \($0.nome.lowercased())" }].compactMap { $0 }.joined(separator: " · ")),
            riga("Obiettivi dichiarati", c.profilo.obiettivi),
            riga("Canali", c.canali.map(\.nome).joined(separator: ", ")),
        ]
    }
}

// MARK: - Pagina 2: semafori, bisogni, passi

private struct PaginaSemaforo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCheckUp

    private var e: EsitoCheckUp { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Il semaforo delle aree", testo: Text(verbatim: t.titoloSemaforo + "."))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Area", peso: 1.5, destra: false), ColonnaDoc(titolo: "Stato", peso: 1, destra: false),
                                                       ColonnaDoc(titolo: "Cifra", peso: 1.1), ColonnaDoc(titolo: "Lettura e azione", peso: 3.6, destra: false)],
                       righe: e.indicatori.map { i in
                           var lettura = CellaDoc(i.lettura, sotto: "→ " + i.azione, font: T.pTabellaNota)
                           lettura.righe = 2
                           lettura.coloreSotto = C.evidenzaTitolo
                           return RigaDoc(celle: [CellaDoc(i.titolo, font: T.pTabellaForte),
                                                  CellaDoc("● " + i.semaforo.nome, colore: coloreSemaforo(i.semaforo, C), font: T.pTabellaForte),
                                                  CellaDoc(i.valore, font: T.pTabella), lettura], altezza: 32)
                       }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            if !e.bisogni.isEmpty {
                SezioneProspetto(titolo: "I bisogni rilevati dai dati",
                                 testo: Text(verbatim: e.priorita.isEmpty ? "Da confermare con il cliente nel profilo dei bisogni." : "Priorità: " + e.priorita.prefix(3).map(\.nome).joined(separator: ", ") + "."))
                TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Bisogno", peso: 2, destra: false), ColonnaDoc(titolo: "Area", peso: 1.2, destra: false),
                                                           ColonnaDoc(titolo: "Importanza", peso: 0.8, destra: false), ColonnaDoc(titolo: "Perché", peso: 3, destra: false)],
                           righe: e.bisogni.sorted { $0.importanza > $1.importanza }.prefix(8).map { b in
                               RigaDoc(celle: [CellaDoc(b.titolo, font: T.pTabellaForte), CellaDoc(b.area.nome, font: T.pTabella),
                                               CellaDoc(b.importanza.nome, font: T.pTabella), CellaDoc(b.motivo, colore: C.tenue, font: T.pTabellaNota)], altezza: 15)
                           }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            }
            if !e.proposte.isEmpty {
                SezioneProspetto(titolo: "Proposte già impostate")
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(e.proposte) { p in
                        PuntoElenco(testo: Text(verbatim: p.nome).bold() + Text(verbatim: " · \(p.canale.nome) · \(p.area.nome.lowercased())" + (p.premioAnnuo > 0 ? " · \(CifreDoc.euro(p.premioAnnuo)) l'anno" : "")))
                    }
                }
            }
            SezioneProspetto(titolo: "I prossimi passi")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(t.prossimiPassi.enumerated()), id: \.offset) { i, p in PuntoElenco(testo: Text(verbatim: "\(i + 1). ").bold() + Text(verbatim: p)) }
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(e.note.enumerated()), id: \.offset) { _, n in
                    Text(verbatim: n).font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
                }
            }
            FirmeProspetto()
        }
    }
}
