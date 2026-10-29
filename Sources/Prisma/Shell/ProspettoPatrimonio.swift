import SwiftUI

private typealias T = Tipo.Documento

/// Il prospetto del patrimonio nel tempo: A4 verticale, per il consulente. Prima pagina il percorso anno per
/// anno, seconda la composizione per area, le proposte, gli obiettivi, il metodo e le firme.
enum ProspettoPatrimonio {
    static func pagine(_ t: TestiPatrimonio) -> [AnyView] {
        let pagine: [AnyView] = [AnyView(PaginaPercorso(t: t)), AnyView(PaginaComposizione(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiPatrimonio.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

// MARK: - Pagina 1: il percorso

private struct PaginaPercorso: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPatrimonio

    private var p: PatrimonioNelTempo { t.p }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Patrimonio nel tempo", font: T.pOcchiello)
                Text(verbatim: "Il patrimonio di \(t.cliente) nei prossimi \(p.anni) anni").font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: "Tutte le posizioni insieme, in essere e con le proposte · situazione al \(CifreDoc.data(t.data))")
                    .font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            FilaCifre {
                CifraProspetto("Oggi", CifreDoc.euro(p.nettoOggi), "patrimonio netto")
                CifraProspetto("Tra 10 anni", CifreDoc.euro(p.valore(10)), "versando \(CifreDoc.euro(p.versamentiAnnui)) l'anno")
                CifraProspetto("Tra \(p.anni) anni", CifreDoc.euro(p.valore(p.anni)), "\(CifreDoc.euro(p.reale(p.valore(p.anni), anno: p.anni))) in euro di oggi")
                CifraProspetto("Con le proposte", p.conProposte == nil ? "—" : CifreDoc.euro(p.valore(p.anni, conProposte: true)),
                               p.differenzaProposte.map { CifreDoc.euroSegno($0) } ?? "nessuna proposta aperta",
                               colore: (p.differenzaProposte ?? 0) > 0.5 ? C.positivo : nil)
            }
            SezioneProspetto(titolo: "Il percorso", testo: Text(verbatim: "Patrimonio netto anno per anno, prima delle imposte finali."))
            GraficoLineeDoc(serie: serie(C), etichetteAsse: t.etichetteAsse, fontAssi: T.pTabellaNota, fontValori: T.pTabellaNota)
                .frame(height: Misure.Documento.graficoCosti)
            SezioneProspetto(titolo: "Anno per anno")
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Anno", peso: 0.7, destra: false),
                                                       ColonnaDoc(titolo: "Com'è oggi", peso: 1.2), ColonnaDoc(titolo: "Con le proposte", peso: 1.2),
                                                       ColonnaDoc(titolo: "Differenza", peso: 1), ColonnaDoc(titolo: "In euro di oggi", sottotitolo: "com'è oggi", peso: 1.2)],
                       righe: t.anniTabella.map { a in
                           let oggi = p.valore(a)
                           let con = p.conProposte == nil ? nil : p.valore(a, conProposte: true)
                           return RigaDoc(celle: [CellaDoc(a == 0 ? "Oggi" : "\(a)° anno", font: T.pTabellaForte),
                                                  CellaDoc(CifreDoc.euro(oggi), font: T.pTabella),
                                                  CellaDoc(con.map(CifreDoc.euro) ?? "—", font: T.pTabella),
                                                  CellaDoc(con.map { CifreDoc.euroSegno($0 - oggi) } ?? "—", font: T.pTabella),
                                                  CellaDoc(CifreDoc.euro(p.reale(oggi, anno: a)), colore: C.tenue, font: T.pTabella)], altezza: 18)
                       }, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
        }
    }

    private func serie(_ C: PaletteDocumento) -> [SerieDoc] {
        var s = [SerieDoc(nome: "Com'è oggi", colore: C.premio, valori: p.oggi.map(\.valore), tratteggio: p.conProposte != nil)]
        if let c = p.conProposte { s.append(SerieDoc(nome: "Con le proposte", colore: C.intermedio, valori: c.map(\.valore))) }
        return s
    }
}

// MARK: - Pagina 2: composizione, proposte, obiettivi, metodo

private struct PaginaComposizione: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPatrimonio

    private var p: PatrimonioNelTempo { t.p }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Per area", testo: Text(verbatim: "Le posizioni in essere: oggi, tra 10 anni e tra \(p.anni) anni."))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Area", peso: 1.6, destra: false), ColonnaDoc(titolo: "Oggi", peso: 1),
                                                       ColonnaDoc(titolo: "Tra 10 anni", peso: 1), ColonnaDoc(titolo: "Tra \(p.anni) anni", peso: 1)],
                       righe: t.perArea.map { a in
                           RigaDoc(celle: [CellaDoc(a.area.nome, font: T.pTabellaForte), CellaDoc(CifreDoc.euro(a.oggi), font: T.pTabella),
                                           CellaDoc(CifreDoc.euro(a.dieci), font: T.pTabella), CellaDoc(CifreDoc.euro(a.finale), font: T.pTabellaForte)], altezza: 18)
                       }, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
            SezioneProspetto(titolo: "Le proposte aperte")
            if p.proposte.isEmpty {
                Text(verbatim: "Nessuna proposta aperta: il percorso è quello delle posizioni in essere.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [ColonnaDoc(titolo: "Proposta", sottotitolo: "area", peso: 2.2, destra: false),
                                        ColonnaDoc(titolo: "Versamento iniziale", peso: 1.1), ColonnaDoc(titolo: "Versamenti", sottotitolo: "all'anno", peso: 1),
                                        ColonnaDoc(titolo: "Tra \(p.anni) anni", sottotitolo: "valore stimato", peso: 1.1)],
                              gruppi: Canale.allCases.compactMap { c in
                                  let mie = p.proposte.prefix(Misure.Documento.schedeReport).filter { $0.canale == c }
                                  guard !mie.isEmpty else { return nil }
                                  return GruppoCanale(canale: c, righe: mie.map { x in
                                      let fine = MotorePatrimonio.andamento(x, anni: p.anni).last?.valore ?? 0
                                      return RigaDoc(celle: [CellaDoc(x.nome, sotto: x.area.nome, font: T.pTabellaForte),
                                                             CellaDoc(x.versamentoIniziale > 0.5 ? CifreDoc.euro(x.versamentoIniziale) : "—", font: T.pTabella),
                                                             CellaDoc(x.premioAnnuo > 0.5 ? CifreDoc.euro(x.premioAnnuo) : "—", font: T.pTabella),
                                                             CellaDoc(CifreDoc.euro(fine), font: T.pTabellaForte)], altezza: 22)
                                  }, nota: "")
                              })
                Altre(numero: p.proposte.count - Misure.Documento.schedeReport, cosa: "proposte")
            }
            SezioneProspetto(titolo: "Gli obiettivi lungo la strada")
            if p.traguardi.isEmpty {
                Text(verbatim: "Nessun obiettivo con una data nei prossimi \(p.anni) anni.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Obiettivo", peso: 2.2, destra: false), ColonnaDoc(titolo: "Quando", peso: 0.8),
                                                           ColonnaDoc(titolo: "Importo", peso: 1), ColonnaDoc(titolo: "Patrimonio allora", peso: 1.2)],
                           righe: p.traguardi.prefix(Misure.Documento.schedeReport).map { o in
                               RigaDoc(celle: [CellaDoc(o.obiettivo.titolo, font: T.pTabellaForte),
                                               CellaDoc(o.anno == 0 ? "quest'anno" : "\(o.anno)° anno", font: T.pTabella),
                                               CellaDoc(CifreDoc.euro(o.obiettivo.importo), font: T.pTabella),
                                               CellaDoc(CifreDoc.euro(p.valore(o.anno, conProposte: p.conProposte != nil)), font: T.pTabellaForte)], altezza: 18)
                           }, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
                Altre(numero: p.traguardi.count - Misure.Documento.schedeReport, cosa: "obiettivi")
            }
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(t.sintesi.enumerated()), id: \.offset) { _, s in
                        PuntoElenco(testo: Text(verbatim: "\(s.0): ").bold() + Text(verbatim: s.1))
                    }
                }
            }
            SezioneProspetto(titolo: "Ipotesi e metodo")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(t.metodo.enumerated()), id: \.offset) { _, n in PuntoElenco(testo: Text(verbatim: n)) }
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold()
             + Text(verbatim: "Una proiezione non è una previsione: i rendimenti ipotizzati non sono garantiti e le imposte alla chiusura delle posizioni non sono sottratte."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }
}
