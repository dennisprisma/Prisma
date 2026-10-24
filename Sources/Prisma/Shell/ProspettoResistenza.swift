import SwiftUI

private typealias T = Tipo.Documento

/// Il prospetto della prova di resistenza: A4 verticale, per il consulente. Prima pagina i mercati
/// e il confronto con il profilo, seconda inflazione, immobili, metodo e firme.
enum ProspettoResistenza {
    static func pagine(_ t: TestiResistenza) -> [AnyView] {
        let pagine: [AnyView] = [AnyView(PaginaMercati(t: t)), AnyView(PaginaInflazione(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiResistenza.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

/// Il colore del giudizio rispetto al profilo, nei documenti.
func coloreGiudizio(_ g: ProvaResistenza.Giudizio?, _ C: PaletteDocumento) -> Color {
    switch g {
    case .dentro?: return C.positivo
    case .alLimite?: return C.intermedio
    case .oltre?: return C.negativo
    case nil: return C.tenue
    }
}

/// Le voci di uno scenario divise per canale (blu Alleanza, cuoio indipendente).
private func gruppi(_ s: ProvaResistenza.Scenario?, riga: (ProvaResistenza.Voce) -> RigaDoc) -> [GruppoCanale] {
    guard let s else { return [] }
    return Canale.allCases.compactMap { c in
        let mie = s.voci.filter { $0.posizione.canale == c }
        guard !mie.isEmpty else { return nil }
        let totale = mie.reduce(0) { $0 + $1.perdita }
        return GruppoCanale(canale: c, righe: mie.map(riga), nota: "\(mie.count == 1 ? "1 posizione" : "\(mie.count) posizioni") · \(CifreDoc.togli(totale))")
    }
}

// MARK: - Pagina 1: i mercati e il profilo

private struct PaginaMercati: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResistenza

    private var r: ProvaResistenza { t.r }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Prova di resistenza", font: T.pOcchiello)
                Text(verbatim: "Il patrimonio di \(t.cliente) alla prova").font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: "Tre scenari avversi sulle posizioni in essere · situazione al \(CifreDoc.data(t.data))")
                    .font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            HStack(spacing: 6) {
                CifraProspetto("Patrimonio finanziario", CifreDoc.euro(r.patrimonioFinanziario), "investimenti, risparmio, previdenza, conti")
                CifraProspetto("Mercati in forte calo", t.mercati.map { CifreDoc.togli($0.perdita) } ?? "—",
                               t.mercati.map { "il \(CifreDoc.percento($0.quota * 100)) del finanziario" } ?? "", colore: C.negativo)
                CifraProspetto("Inflazione alta", t.inflazione.map { CifreDoc.togli($0.perdita) } ?? "—",
                               t.inflazione.map { "il \(CifreDoc.percento($0.quota * 100)) del finanziario" } ?? "", colore: C.negativo)
                CifraProspetto("Immobili in calo", (t.immobili?.voci.isEmpty ?? true) ? "—" : CifreDoc.togli(t.immobili?.perdita ?? 0),
                               t.immobili.map { $0.voci.isEmpty ? "nessun immobile" : "il \(CifreDoc.percento($0.quota * 100)) del netto" } ?? "")
                CifraProspetto("Al riparo", CifreDoc.percento(r.quotaProtetta * 100, decimali: 0), "garantito o senza mercato", colore: C.positivo)
            }
            SezioneProspetto(titolo: "Mercati in forte calo",
                             testo: Text(verbatim: ProvaResistenza.Tipo.mercati.ipotesi))
            if t.mercati?.voci.isEmpty ?? true {
                Text(verbatim: "Nessuna posizione esposta ai mercati: conti e capitale garantito.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Posizione", sottotitolo: "tipologia", peso: 2.4, destra: false), ColonnaDoc(titolo: "Valore", peso: 1),
                    ColonnaDoc(titolo: "Rischio", sottotitolo: "SRI su 7", peso: 0.8), ColonnaDoc(titolo: "Esposta", sottotitolo: "ai mercati", peso: 0.8),
                    ColonnaDoc(titolo: "Calo", peso: 0.7), ColonnaDoc(titolo: "Perdita", peso: 1),
                ], gruppi: gruppi(t.mercati) { v in
                    let p = v.posizione
                    let sri = p.sri.map { "\($0)" } ?? "\(MotoreResistenza.sriProbabile(p.area)) stimato"
                    return RigaDoc(celle: [CellaDoc(p.nome, sotto: p.tipologia, font: T.pTabellaForte),
                                           CellaDoc(CifreDoc.euro(p.valore), font: T.pTabella),
                                           CellaDoc(sri, colore: p.sri == nil ? C.tenue : nil, font: T.pTabella),
                                           CellaDoc(CifreDoc.percento(MotoreResistenza.quotaARischio(p) * 100, decimali: 0), font: T.pTabella),
                                           CellaDoc(CifreDoc.percento(v.quota * 100, decimali: 0), font: T.pTabella),
                                           CellaDoc(CifreDoc.togli(v.perdita), colore: C.negativo, font: T.pTabellaForte)], altezza: 22)
                })
            }
            SezioneProspetto(titolo: "Il confronto con il profilo")
            if let m = t.mercati, m.base > 0 { BarraProfilo(prova: r, quota: m.quota) }
            RiquadroBarra(titolo: t.titoloProfilo) {
                Text(verbatim: t.spiegazioneProfilo).font(T.pCorpo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// La perdita sui mercati sulla barra del patrimonio finanziario, con il segno della soglia del profilo.
struct BarraProfilo: View {
    @Environment(\.paletteDocumento) private var C
    let prova: ProvaResistenza
    let quota: Double
    var altezza: CGFloat = Misure.Documento.barraResistenza
    var font: Font = Tipo.Documento.pTabellaNota

    var body: some View {
        let soglia = (prova.sopportabile ?? 0) / 100
        let scala = max(quota, soglia, 0.01) * 1.3
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(C.fondoInterno)
                    Rectangle().fill(coloreGiudizio(prova.giudizio, C)).frame(width: max(g.size.width * quota / scala, 2))
                    if prova.sopportabile != nil {
                        Rectangle().fill(C.titolo).frame(width: 2).offset(x: g.size.width * soglia / scala - 1)
                    }
                }
            }
            .frame(height: altezza)
            .overlay(Rectangle().strokeBorder(C.filetto, lineWidth: 0.6))
            HStack {
                Text(verbatim: "Perdita stimata \(CifreDoc.percento(quota * 100))").foregroundColor(coloreGiudizio(prova.giudizio, C))
                Spacer()
                if let s = prova.sopportabile, let p = prova.propensione {
                    Text(verbatim: "▏ sopportabile con propensione \(p.nome.lowercased()): \(CifreDoc.condizione(s))").foregroundColor(C.titolo)
                }
            }
            .font(font)
        }
    }
}

// MARK: - Pagina 2: inflazione, immobili, metodo

private struct PaginaInflazione: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResistenza

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Inflazione alta", testo: Text(verbatim: ProvaResistenza.Tipo.inflazione.ipotesi))
            if t.inflazione?.voci.isEmpty ?? true {
                Text(verbatim: "Tutte le posizioni rendono più dell'inflazione ipotizzata.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Posizione", sottotitolo: "tipologia", peso: 2.4, destra: false), ColonnaDoc(titolo: "Valore", peso: 1),
                    ColonnaDoc(titolo: "Rende", sottotitolo: "netto costi", peso: 0.9), ColonnaDoc(titolo: "Potere d'acquisto", sottotitolo: "perso in \(MotoreResistenza.anniInflazione) anni", peso: 1.3),
                ], gruppi: gruppi(t.inflazione) { v in
                    let p = v.posizione
                    let netto = (p.rendimentoAtteso ?? 0) - (p.costoComplessivo ?? 0)
                    return RigaDoc(celle: [CellaDoc(p.nome, sotto: p.tipologia, font: T.pTabellaForte),
                                           CellaDoc(CifreDoc.euro(p.valore), font: T.pTabella),
                                           CellaDoc(CifreDoc.percento(netto), font: T.pTabella),
                                           CellaDoc(CifreDoc.togli(v.perdita), colore: C.negativo, font: T.pTabellaForte)], altezza: 22)
                })
            }
            SezioneProspetto(titolo: "Immobili in calo", testo: Text(verbatim: ProvaResistenza.Tipo.immobili.ipotesi))
            if t.immobili?.voci.isEmpty ?? true {
                Text(verbatim: "Nessun immobile registrato nelle Posizioni.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Immobile", peso: 2.4, destra: false), ColonnaDoc(titolo: "Valore", peso: 1), ColonnaDoc(titolo: "Calo", peso: 1),
                ], gruppi: gruppi(t.immobili) { v in
                    RigaDoc(celle: [CellaDoc(v.posizione.nome, font: T.pTabellaForte), CellaDoc(CifreDoc.euro(v.posizione.valore), font: T.pTabella),
                                    CellaDoc(CifreDoc.togli(v.perdita), colore: C.negativo, font: T.pTabellaForte)], altezza: 20)
                })
            }
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(t.sintesi.enumerated()), id: \.offset) { _, p in
                        PuntoElenco(testo: Text(verbatim: "\(p.0): ").bold() + Text(verbatim: p.1))
                    }
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
             + Text(verbatim: "Gli scenari sono ipotetici e semplificati: non sono previsioni né il caso peggiore possibile. Le perdite sui mercati possono essere recuperate nel tempo da chi resta investito; il capitale garantito vale alle condizioni del contratto."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }
}
