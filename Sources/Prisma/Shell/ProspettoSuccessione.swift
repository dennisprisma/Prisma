import SwiftUI

private typealias T = Tipo.Documento

/// Il prospetto del passaggio generazionale: A4 verticale, per il consulente. Prima pagina le posizioni
/// e dove vanno, seconda gli eredi, le imposte, cosa sistemare, il metodo e le firme.
enum ProspettoSuccessione {
    static func pagine(_ t: TestiSuccessione) -> [AnyView] {
        let pagine: [AnyView] = [AnyView(PaginaDestini(t: t)), AnyView(PaginaEredi(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiSuccessione.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

/// Le voci divise per canale, con il destino o l'avviso sotto il nome.
private func gruppiSuccessione(_ voci: [Successione.Voce], _ C: PaletteDocumento) -> [GruppoCanale] {
    Canale.allCases.compactMap { c in
        let mie = voci.filter { $0.posizione.canale == c }
        guard !mie.isEmpty else { return nil }
        return GruppoCanale(canale: c, righe: mie.map { v in
            let chi = v.destino == .beneficiari ? (v.posizione.senzaBeneficiari ? "da indicare" : v.posizione.beneficiari) : "eredi"
            var nota = CellaDoc(v.avviso ?? v.motivo, colore: v.avviso == nil ? C.tenue : C.intermedio, font: T.pTabellaNota)
            nota.righe = 2
            return RigaDoc(celle: [CellaDoc(v.posizione.nome, sotto: v.posizione.area.nome, font: T.pTabellaForte),
                                   CellaDoc(chi, colore: v.posizione.senzaBeneficiari && v.destino == .beneficiari ? C.negativo : nil, font: T.pTabella),
                                   nota,
                                   CellaDoc(CifreDoc.euro(v.importo), colore: v.importo < 0 ? C.negativo : nil, font: T.pTabellaForte)], altezza: 26)
        }, nota: CifreDoc.euro(mie.reduce(0) { $0 + $1.importo }))
    }
}

private let colonne = [ColonnaDoc(titolo: "Posizione", sottotitolo: "area", peso: 1.9, destra: false),
                       ColonnaDoc(titolo: "A chi", peso: 1.3, destra: false),
                       ColonnaDoc(titolo: "Perché", sottotitolo: "o cosa sistemare", peso: 3, destra: false),
                       ColonnaDoc(titolo: "Importo", peso: 1)]

// MARK: - Pagina 1: dove va ogni posizione

private struct PaginaDestini: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSuccessione

    private var s: Successione { t.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Passaggio generazionale", font: T.pOcchiello)
                Text(verbatim: "Il passaggio generazionale di \(t.cliente)").font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: "Successione senza testamento, posizioni in essere · situazione al \(CifreDoc.data(t.data))")
                    .font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            FilaCifre {
                CifraProspetto("Ai beneficiari", CifreDoc.euro(s.fuoriAsse), "fuori successione", colore: C.positivo)
                CifraProspetto("Nell'asse", CifreDoc.euro(s.attivoAsse), "fondi, conti, immobili")
                CifraProspetto("Debiti", s.debiti > 0.5 ? CifreDoc.togli(s.debiti) : "—", "passano agli eredi", colore: s.debiti > 0.5 ? C.negativo : nil)
                CifraProspetto("Agli eredi", CifreDoc.euro(s.asseNetto), "dopo la successione")
                CifraProspetto("Imposte", CifreDoc.euro(s.imposte), s.impostaSuccessione > 0.5 ? "successione e ipocatastali" : "solo ipocatastali")
            }
            SezioneProspetto(titolo: "Ai beneficiari, fuori dalla successione",
                             testo: Text(verbatim: "Polizze vita, capitali caso morte e previdenza: liquidati in poche settimane alle persone indicate, senza imposta di successione."))
            if t.beneficiari.isEmpty {
                Text(verbatim: "Nessuna polizza vita, copertura caso morte o previdenza in essere.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: colonne, gruppi: gruppiSuccessione(Array(t.beneficiari.prefix(Misure.Documento.righeTabellaFissa)), C))
                Altre(numero: t.beneficiari.count - Misure.Documento.righeTabellaFissa)
            }
            SezioneProspetto(titolo: "Agli eredi, con la successione",
                             testo: Text(verbatim: "Conti, fondi e immobili, debiti tolti: bloccati fino alla dichiarazione di successione e divisi secondo la legge."))
            if t.asse.isEmpty {
                Text(verbatim: "Nessuna posizione nell'asse ereditario.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: colonne, gruppi: gruppiSuccessione(Array(t.asse.prefix(Misure.Documento.righeTabellaFissa)), C))
                Altre(numero: t.asse.count - Misure.Documento.righeTabellaFissa)
            }
        }
    }
}

// MARK: - Pagina 2: eredi, imposte, cosa sistemare

private struct PaginaEredi: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSuccessione

    private var s: Successione { t.s }
    private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Gli eredi senza testamento", testo: Text(verbatim: "Dai familiari registrati nel dossier: quota dell'asse netto e imposta di successione di ciascuno."))
            if s.eredi.isEmpty {
                Text(verbatim: "Nessun erede tra i familiari registrati: l'asse andrebbe ai parenti più vicini fino al sesto grado, o allo Stato.")
                    .font(T.pCorpo).foregroundColor(C.intermedio).fixedSize(horizontal: false, vertical: true)
            } else {
                TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Erede", sottotitolo: "relazione", peso: 2, destra: false),
                                                           ColonnaDoc(titolo: "Quota", peso: 0.9), ColonnaDoc(titolo: "Importo", peso: 1),
                                                           ColonnaDoc(titolo: "Franchigia", peso: 1), ColonnaDoc(titolo: "Aliquota", peso: 0.8),
                                                           ColonnaDoc(titolo: "Imposta", peso: 1)],
                           righe: s.eredi.map { e in
                               RigaDoc(celle: [CellaDoc(e.nome, sotto: e.relazione.nome + (e.minorenne ? ", minorenne" : ""), font: T.pTabellaForte),
                                               CellaDoc(MotoreSuccessione.frazione(e.quota), font: T.pTabella),
                                               CellaDoc(CifreDoc.euro(e.importo), font: T.pTabella),
                                               CellaDoc(e.franchigia > 0 ? CifreDoc.euro(e.franchigia) : "—", font: T.pTabella),
                                               CellaDoc(CifreDoc.condizione(e.aliquota), font: T.pTabella),
                                               CellaDoc(e.imposta > 0.5 ? CifreDoc.togli(e.imposta) : "—", colore: e.imposta > 0.5 ? C.negativo : nil, font: T.pTabellaForte)],
                                       altezza: 24)
                           }, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
            }
            FilaCifre {
                CifraProspetto("Imposta di successione", s.impostaSuccessione > 0.5 ? CifreDoc.euro(s.impostaSuccessione) : "—", "entro le franchigie se zero")
                CifraProspetto("Ipotecaria e catastale", s.ipocatastali > 0.5 ? CifreDoc.euro(s.ipocatastali) : "—", s.primaCasa ? "con l'agevolazione prima casa" : "3% sugli immobili")
                CifraProspetto("Fuori dall'eredità", CifreDoc.percento(s.quotaFuori * 100, decimali: 0), "di quanto passerebbe", colore: C.positivo)
            }
            RiquadroBarra(titolo: t.titoloSistemare) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(s.daSistemare.prefix(Misure.Documento.righeTabellaFissa)) { v in
                        PuntoElenco(testo: Text(verbatim: "\(v.posizione.nome): ").bold() + Text(verbatim: v.avviso ?? ""))
                    }
                    ForEach(Array(s.avvisi.enumerated()), id: \.offset) { _, a in PuntoElenco(testo: Text(verbatim: a)) }
                }
            }
            SezioneProspetto(titolo: "Prossimi passi")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(t.prossimiPassi.enumerated()), id: \.offset) { _, p in PuntoElenco(testo: Text(verbatim: p)) }
            }
            SezioneProspetto(titolo: "Ipotesi e metodo")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(t.metodo.enumerated()), id: \.offset) { _, n in PuntoElenco(testo: Text(verbatim: n)) }
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold()
             + Text(verbatim: "Stima semplificata senza testamento, legittima, donazioni precedenti né regime patrimoniale: per decisioni su testamento, donazioni o beneficiari serve il parere di un notaio."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }
}

/// «…e altre N posizioni»: le tabelle dei documenti a pagina fissa non vanno oltre il foglio.
struct Altre: View {
    @Environment(\.paletteDocumento) private var C
    let numero: Int
    var cosa = "posizioni"

    var body: some View {
        if numero > 0 {
            Text(verbatim: "…e altre \(numero) \(cosa): l'elenco completo è nel dossier Posizioni.")
                .font(Tipo.Documento.pTabellaNota).foregroundColor(C.tenue)
        }
    }
}
