import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il prospetto del piano obiettivo: A4 verticale, per il consulente. Traguardo rivalutato,
/// posizioni collegate alla scadenza, strade per arrivarci, scenari, anno per anno, scenari con le probabilità
/// (Monte Carlo), quadro degli obiettivi.
enum ProspettoObiettivo {
    static func pagine(_ t: TestiObiettivo) -> [AnyView] {
        var pagine: [AnyView] = [AnyView(PaginaTraguardo(t: t)), AnyView(PaginaStrade(t: t))]
        if let mc = probabilita(t) { pagine.append(AnyView(PaginaProbabilita(t: t, mc: mc))) }
        pagine.append(AnyView(PaginaQuadroObiettivi(t: t)))
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiObiettivo.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }

    /// Gli scenari con le probabilità (Monte Carlo con seme fisso: stesso risultato a ogni stampa), con le stesse
    /// ipotesi del piano. Si calcolano qui, per il documento, mai negli spunti di Eve, e passano dalla cache di
    /// Obiettivi: prospetto e report non rifanno i 1.000 percorsi. nil con meno di un anno alla scadenza o senza
    /// niente da parte né posizioni collegate.
    static func probabilita(_ t: TestiObiettivo) -> EsitoMonteCarlo? {
        guard t.e.mesi >= 12, !t.e.contributi.isEmpty || t.o.accantonato != 0 else { return nil }
        let mc = CacheMotoriAnalisi.scenari(t.o, posizioni: t.e.contributi.map(\.posizione), data: t.data)
        return mc.anni.count >= 2 ? mc : nil
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

// MARK: - Pagina 1: il traguardo

private struct PaginaTraguardo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo

    private var e: EsitoObiettivo { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Piano obiettivo · \(t.o.area.nome)", font: T.pOcchiello)
                Text(verbatim: t.o.titolo).font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: "\(CifreDoc.euro(t.o.importo)) in euro di oggi entro il \(CifreDoc.data(t.o.scadenza)), \(t.quando) · priorità \(t.o.priorita.nome.lowercased())"
                     + (t.o.note.isEmpty ? "" : " · \(t.o.note)"))
                    .font(T.pSottotitolo).foregroundColor(C.testo).lineLimit(2)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            FilaCifre {
                CifraProspetto("Obiettivo alla scadenza", CifreDoc.euro(e.importoScadenza), "\(CifreDoc.euro(e.importoOggi)) di oggi + inflazione")
                CifraProspetto("Da parte oggi", CifreDoc.euro(e.disponibileOggi), "accantonato e posizioni collegate")
                CifraProspetto("Si arriva a", CifreDoc.euro(e.proiezione), "netto, alla scadenza")
                CifraProspetto("Copertura", CifreDoc.percento(e.copertura * 100, decimali: 0), e.mancante > 0.5 ? "mancano \(CifreDoc.euro(e.mancante))" : "obiettivo raggiunto",
                               colore: e.mancante > 0.5 ? C.negativo : C.positivo)
                CifraProspetto("Versamento che serve", e.versamentoNecessario.map { "\(CifreDoc.euro($0))/mese" } ?? "—", "in più di quelli attivi")
            }
            SezioneProspetto(titolo: "Le posizioni che lavorano per l'obiettivo",
                             testo: Text(verbatim: "Ogni posizione collegata portata alla scadenza con le sue ipotesi, i suoi costi e l'imposta sul guadagno." + (t.o.accantonato > 0 ? " Accantonato non investito: \(CifreDoc.euro(t.o.accantonato)), al \(CifreDoc.condizione(t.o.rendimento)) annuo, diventa \(CifreDoc.euro(e.accantonatoScadenza))." : "")))
            if e.contributi.isEmpty {
                Text(verbatim: "Nessuna posizione collegata all'obiettivo: si collegano dall'app Obiettivi.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Posizione", sottotitolo: "area", peso: 2.4, destra: false),
                    ColonnaDoc(titolo: "Oggi", peso: 1), ColonnaDoc(titolo: "Versamenti", sottotitolo: "al mese", peso: 0.9),
                    ColonnaDoc(titolo: "Rendimento", sottotitolo: "costi", peso: 0.9), ColonnaDoc(titolo: "Alla scadenza", sottotitolo: "netto", peso: 1.1),
                ], gruppi: Canale.allCases.compactMap { c in
                    let mie = e.contributi.filter { $0.posizione.canale == c }
                    guard !mie.isEmpty else { return nil }
                    return GruppoCanale(canale: c, righe: mie.map { x in
                        RigaDoc(celle: [CellaDoc(x.posizione.nome, sotto: x.posizione.area.nome, font: T.pTabellaForte),
                                        CellaDoc(CifreDoc.euro(x.valoreOggi), font: T.pTabella),
                                        CellaDoc(x.versamentoMensile > 0 ? CifreDoc.euro(x.versamentoMensile) : "—", font: T.pTabella),
                                        CellaDoc(CifreDoc.percento(x.rendimento), sotto: CifreDoc.percento(x.costoAnnuo, decimali: 2), font: T.pTabella),
                                        CellaDoc(CifreDoc.euro(x.nettoScadenza), font: T.pTabellaForte)], altezza: 21)
                    }, nota: mie.count == 1 ? "1 posizione" : "\(mie.count) posizioni")
                })
            }
            SezioneProspetto(titolo: "Il percorso, anno per anno",
                             testo: Text(verbatim: "Valore accumulato (prima delle imposte finali) con ciò che c'è e con il versamento suggerito, contro l'obiettivo rivalutato."))
            GraficoLineeDoc(serie: serie, etichetteAsse: (0..<e.serieAttuale.count).map { $0 == 0 ? "oggi" : "\($0)° anno" },
                            fontAssi: T.pAssi, fontValori: T.pTabellaNota)
                .frame(height: 160)
                .background(C.riquadro.opacity(0.5))
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(t.sintesi.enumerated()), id: \.offset) { _, p in
                        PuntoElenco(testo: Text(verbatim: "\(p.0): ").bold() + Text(verbatim: p.1))
                    }
                }
            }
        }
    }

    private var serie: [SerieDoc] {
        var s = [SerieDoc(nome: "Obiettivo", colore: C.titolo, valori: e.serieObiettivo, tratteggio: true),
                 SerieDoc(nome: "Con ciò che c'è", colore: C.premio, valori: e.serieAttuale)]
        if e.versamentoNecessario != nil { s.append(SerieDoc(nome: "Con il versamento", colore: C.intermedio, valori: e.serieConVersamento)) }
        return s
    }
}

// MARK: - Pagina 2: strade, scenari, anno per anno

private struct PaginaStrade: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo

    private var e: EsitoObiettivo { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Le strade per arrivarci",
                             testo: Text(verbatim: e.strade.isEmpty ? "L'obiettivo è già raggiunto con ciò che c'è: nessun intervento necessario."
                                                                    : "Quattro modi alternativi per colmare i \(CifreDoc.euro(e.mancante)) che mancano alla scadenza."))
            if !e.strade.isEmpty {
                TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Strada", peso: 1.6, destra: false), ColonnaDoc(titolo: "Quanto", peso: 1.2),
                                                           ColonnaDoc(titolo: "Come", peso: 3.4, destra: false)],
                           righe: e.strade.map { s in
                               RigaDoc(celle: [CellaDoc(s.titolo, font: T.pTabellaForte), CellaDoc(s.valore, colore: C.intermedio, font: T.pTabellaForte),
                                               CellaDoc(s.spiegazione, colore: C.tenue, font: T.pTabella)], altezza: 16)
                           }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            }
            SezioneProspetto(titolo: "Se i mercati vanno diversamente",
                             testo: Text(verbatim: "Proiezione alla scadenza con 2 punti di rendimento in meno o in più. \(t.tenuta)"))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Scenario", peso: 1.3, destra: false), ColonnaDoc(titolo: "Si arriva a"),
                                                       ColonnaDoc(titolo: "Obiettivo"), ColonnaDoc(titolo: "Differenza"), ColonnaDoc(titolo: "Copertura", peso: 0.8)],
                       righe: e.scenari.map { s in
                           let colore = s.scarto < 0 ? C.sfavorevole : (s.scarto > 0 ? C.favorevole : C.intermedio)
                           let d = s.proiezione - e.importoScadenza
                           return RigaDoc(celle: [CellaDoc("■ \(s.nome)", colore: colore, font: T.pTabellaForte), CellaDoc(CifreDoc.euro(s.proiezione), font: T.pTabella),
                                                  CellaDoc(CifreDoc.euro(e.importoScadenza), font: T.pTabella),
                                                  CellaDoc(CifreDoc.euroSegno(d), colore: d >= 0 ? C.positivo : C.negativo, font: T.pTabellaForte),
                                                  CellaDoc(CifreDoc.percento(min(100, s.proiezione / max(e.importoScadenza, 1) * 100), decimali: 0), font: T.pTabella)],
                                          altezza: 15)
                       }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            SezioneProspetto(titolo: "Anno per anno")
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Anno", peso: 0.9, destra: false), ColonnaDoc(titolo: "Obiettivo", sottotitolo: "rivalutato"),
                                                       ColonnaDoc(titolo: "Con ciò che c'è", sottotitolo: "lordo"),
                                                       ColonnaDoc(titolo: "Con il versamento", sottotitolo: e.versamentoNecessario.map { "\(CifreDoc.euro($0))/mese" } ?? "—"),
                                                       ColonnaDoc(titolo: "Copertura", sottotitolo: "con ciò che c'è", peso: 0.9)],
                       righe: righeAnni, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
        }
    }

    private var righeAnni: [RigaDoc] {
        let n = e.serieAttuale.count
        let passo = n <= 22 ? 1 : 5
        return (0..<n).filter { $0 % passo == 0 || $0 == n - 1 }.map { y in
            RigaDoc(celle: [CellaDoc(y == 0 ? "oggi" : "\(y)° anno", font: T.pTabella), CellaDoc(CifreDoc.euro(e.serieObiettivo[y]), font: T.pTabella),
                            CellaDoc(CifreDoc.euro(e.serieAttuale[y]), font: T.pTabellaForte),
                            CellaDoc(e.versamentoNecessario == nil ? "—" : CifreDoc.euro(e.serieConVersamento[y]), font: T.pTabella),
                            CellaDoc(CifreDoc.percento(min(100, e.serieAttuale[y] / max(e.serieObiettivo[y], 1) * 100), decimali: 0), font: T.pTabella)],
                    altezza: 13)
        }
    }
}

// MARK: - Pagina 3: scenari con le probabilità

private struct PaginaProbabilita: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo
    let mc: EsitoMonteCarlo

    private typealias M = Misure.Documento.Motori

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Scenari con le probabilità",
                             testo: Text(verbatim: "\(Formati.numeroFormatter.string(from: NSNumber(value: mc.traiettorie)) ?? "") percorsi possibili dei mercati, anno per anno, con la volatilità di ogni posizione: in quanti casi il capitale finale, al netto delle imposte, raggiunge l'obiettivo rivalutato di \(CifreDoc.euro(mc.traguardo)). È una stima statistica sulle ipotesi del piano, non una previsione."))
            FilaCifre {
                CifraProspetto("Probabilità di arrivarci", "\(mc.suDieci) su 10", "\(CifreDoc.percento(mc.probabilita * 100, decimali: 0)) dei percorsi",
                               colore: coloreProbabilita)
                CifraProspetto("Sfavorevole", CifreDoc.euro(mc.p10), "1 caso su 10 va peggio", colore: C.sfavorevole)
                CifraProspetto("Mediano", CifreDoc.euro(mc.p50), "metà dei casi sopra, metà sotto", colore: C.intermedio)
                CifraProspetto("Favorevole", CifreDoc.euro(mc.p90), "1 caso su 10 va meglio", colore: C.favorevole)
                CifraProspetto("Obiettivo", CifreDoc.euro(mc.traguardo), "alla scadenza, con l'inflazione")
            }
            GraficoVentaglioDoc(anni: mc.anni, traguardo: mc.traguardo, fontAssi: T.pAssi, fontValori: T.pTabellaNota)
                .frame(height: M.graficoVentaglio)
                .background(C.riquadro.opacity(0.5))
            Text(verbatim: "Fascia: tra lo scenario sfavorevole e quello favorevole (8 casi su 10 stanno dentro); linea: il valore mediano. Valori di fine anno prima delle imposte finali; le cifre sopra sono al netto. La proiezione del piano (\(CifreDoc.euro(t.e.proiezione))) usa un rendimento costante: con le oscillazioni il valore mediano è di solito più basso.")
                .font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
            SezioneProspetto(titolo: "Anno per anno")
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Anno", peso: 0.9, destra: false),
                                                       ColonnaDoc(titolo: "Sfavorevole", sottotitolo: "1 su 10 va peggio"),
                                                       ColonnaDoc(titolo: "Mediano", sottotitolo: "metà sopra, metà sotto"),
                                                       ColonnaDoc(titolo: "Favorevole", sottotitolo: "1 su 10 va meglio"),
                                                       ColonnaDoc(titolo: "Obiettivo", sottotitolo: "rivalutato")],
                       righe: righe, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
            SezioneProspetto(titolo: "Come sono calcolati")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(MotoreMonteCarlo.metodo.enumerated()), id: \.offset) { _, n in PuntoElenco(testo: Text(verbatim: n)) }
            }
        }
    }

    /// Verde da 7 su 10 in su, blu da 4, rosso sotto.
    private var coloreProbabilita: Color {
        mc.suDieci >= 7 ? C.positivo : (mc.suDieci >= 4 ? C.intermedio : C.negativo)
    }

    private var righe: [RigaDoc] {
        let n = mc.anni.count
        let passo = n <= M.anniTabellaProbabilita ? 1 : 5
        let obiettivo = t.e.serieObiettivo
        return mc.anni.indices.filter { $0 % passo == 0 || $0 == n - 1 }.map { i -> RigaDoc in
            let a = mc.anni[i]
            let traguardo = i == n - 1 ? mc.traguardo : (i < obiettivo.count ? obiettivo[i] : mc.traguardo)
            return RigaDoc(celle: [CellaDoc(i == 0 ? "oggi" : "\(a.anno)° anno", font: T.pTabella),
                                   CellaDoc(CifreDoc.euro(a.p10), colore: C.sfavorevole, font: T.pTabella),
                                   CellaDoc(CifreDoc.euro(a.p50), font: T.pTabellaForte),
                                   CellaDoc(CifreDoc.euro(a.p90), colore: C.favorevole, font: T.pTabella),
                                   CellaDoc(CifreDoc.euro(traguardo), colore: C.tenue, font: T.pTabella)],
                           altezza: D.rigaTabellaProspetto)
        }
    }
}

// MARK: - Pagina 4: tutti gli obiettivi, metodo, firme

private struct PaginaQuadroObiettivi: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiObiettivo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Tutti gli obiettivi del cliente",
                             testo: Text(verbatim: "Per decidere insieme le priorità: importo, scadenza, quota raggiunta e versamento mensile che servirebbe a ciascuno."))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Obiettivo", peso: 2.4, destra: false), ColonnaDoc(titolo: "Priorità", peso: 0.8, destra: false),
                                                       ColonnaDoc(titolo: "Importo"), ColonnaDoc(titolo: "Scadenza"), ColonnaDoc(titolo: "Raggiunto", peso: 0.8),
                                                       ColonnaDoc(titolo: "Versamento", sottotitolo: "al mese")],
                       righe: t.altri.map { o, a in
                           RigaDoc(celle: [CellaDoc(o.titolo, sotto: o.area.nome, font: o.id == t.o.id ? T.pTabellaForte : T.pTabella),
                                           CellaDoc(o.priorita.nome, font: T.pTabella), CellaDoc(CifreDoc.euro(o.importo), font: T.pTabella),
                                           CellaDoc(CifreDoc.dataBreve(o.scadenza), font: T.pTabella),
                                           CellaDoc(CifreDoc.percento(a.quota * 100, decimali: 0), font: T.pTabella),
                                           CellaDoc(a.versamentoNecessario.map { CifreDoc.euro($0) } ?? "—", font: T.pTabella)],
                                   altezza: 21, sfondo: o.id == t.o.id ? C.evidenza : .clear)
                       }, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
            Text(verbatim: "Nel quadro la quota raggiunta e il versamento usano l'importo di oggi, senza inflazione, come nell'app Obiettivi.")
                .font(T.pTabellaNota).foregroundColor(C.tenue)
            SezioneProspetto(titolo: "Ipotesi e metodo")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(t.e.note.enumerated()), id: \.offset) { _, n in PuntoElenco(testo: Text(verbatim: n)) }
                PuntoElenco(testo: Text(verbatim: "Versamento unico e mensile: calcolati per bisezione, mese per mese, sul mancante alla scadenza; spostare la data lascia crescere ciò che c'è finché raggiunge l'obiettivo rivalutato."))
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold()
             + Text(verbatim: "Proiezione illustrativa: i rendimenti sono ipotesi e non sono garantiti, l'inflazione può essere diversa da quella ipotizzata. Fanno fede il KID e la documentazione dei prodotti."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }
}
