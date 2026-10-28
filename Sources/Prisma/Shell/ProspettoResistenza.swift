import SwiftUI

private typealias T = Tipo.Documento

/// Il prospetto della prova di resistenza: A4 verticale, per il consulente. Prima pagina i mercati
/// e il confronto con il profilo, poi le crisi vere del passato, infine inflazione, immobili, metodo e firme.
enum ProspettoResistenza {
    static func pagine(_ t: TestiResistenza) -> [AnyView] {
        var pagine: [AnyView] = [AnyView(PaginaMercati(t: t))]
        // Le crisi vere del passato, se toccano almeno una posizione
        if t.r.crisi.contains(where: { !$0.voci.isEmpty }) { pagine.append(AnyView(PaginaCrisi(t: t))) }
        pagine.append(AnyView(PaginaInflazione(t: t)))
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
                CifraProspetto("Patrimonio finanziario", CifreDoc.euro(r.patrimonioFinanziario), "senza immobili e debiti")
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
                    Rectangle().fill(C.griglia)
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

// MARK: - Pagina 2: le crisi del passato

/// "− 13.468 €" per una perdita, "+ 1.200 €" per un guadagno (i titoli di Stato nel 2008), "—" se nulla.
func cifraCrisiDoc(_ perdita: Double) -> String {
    if abs(perdita) < 0.5 { return "—" }
    return perdita > 0 ? CifreDoc.togli(perdita) : "+ " + CifreDoc.euro(-perdita)
}

/// La composizione di una posizione in poche parole: "azioni 35%, Stato 30%, societarie 15%, GS 20%".
func composizioneDoc(_ c: ComposizionePosizione) -> String {
    let parti: [(String, Double)] = [("azioni", c.azioni), ("Stato", c.governativi), ("societarie", c.societarie),
                                     ("liquidità", c.liquidita), ("GS", c.gestioneSeparata), ("immobili", c.immobili)]
    let testo = parti.filter { $0.1 >= 0.005 }.map { "\($0.0) \(CifreDoc.percento($0.1 * 100, decimali: 0))" }.joined(separator: ", ")
    return testo + (c.stimata ? " · stimata" : "")
}

private struct PaginaCrisi: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResistenza

    private var r: ProvaResistenza { t.r }
    private var crisi: [EsitoCrisi] { Array(r.crisi.prefix(Misure.Documento.Motori.crisiMassime)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Le crisi del passato sul patrimonio di oggi",
                             testo: Text(verbatim: "Le variazioni vere di tre anni difficili, classe per classe (azioni, titoli di Stato, obbligazioni societarie), applicate alla composizione di ogni posizione di oggi. Sono stime indicative, non previsioni: dicono quanto perderebbe oggi il patrimonio finanziario se tornasse un anno così. Gestioni separate e conti restano fermi."))
            HStack(spacing: 6) {
                ForEach(crisi) { k in
                    CifraProspetto("\(k.crisi.anno) · \(k.crisi.titolo)", cifraCrisiDoc(k.perdita), notaCifra(k),
                                   colore: k.perdita > 0.5 ? coloreGiudizio(k.giudizio, C) : C.positivo)
                }
            }
            TabellaCanali(colonne: colonne, gruppi: gruppi)
            Altre(numero: posizioni.count - Misure.Documento.righeTabellaFissa)
            if crisi.contains(where: { abs($0.perditaImmobili) >= 0.5 }) {
                Text(verbatim: immobili).font(T.pCorpo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
            }
            if let k = r.crisiPeggiore, k.perdita > 0.5 {
                RiquadroBarra(titolo: "La più dura per questo patrimonio: \(k.crisi.anno), \(k.crisi.titolo.lowercased())") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "Con le posizioni di oggi toglierebbe circa \(CifreDoc.euro(k.perdita)), il \(CifreDoc.percento(k.quota * 100)) del patrimonio finanziario"
                             + giudizio(k) + " " + k.crisi.recupero)
                            .font(T.pCorpo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
                        if let m = t.mercati, !m.voci.isEmpty {
                            Text(verbatim: "Per confronto, lo scenario prudente dei mercati in forte calo (pagina 1) stima \(CifreDoc.togli(m.perdita)): il giudizio sul profilo resta quello.")
                                .font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            SezioneProspetto(titolo: "Come sono calcolate")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(MotoreResistenza.metodoCrisi.enumerated()), id: \.offset) { _, n in
                    PuntoElenco(testo: Text(verbatim: n))
                }
            }
        }
    }

    private func notaCifra(_ k: EsitoCrisi) -> String {
        let quota = "il \(CifreDoc.percento(k.quota * 100)) del finanziario"
        guard let g = k.giudizio else { return quota }
        return quota + " · " + g.etichetta.lowercased()
    }

    private var immobili: String {
        let elenco = crisi.map { k in "\(k.crisi.anno) \(cifraCrisiDoc(k.perditaImmobili))" }
        return "Immobili, a parte (pesano sul patrimonio netto, non sui risparmi): " + elenco.joined(separator: " · ") + "."
    }

    private func giudizio(_ k: EsitoCrisi) -> String {
        guard let g = k.giudizio, let s = r.sopportabile else { return "." }
        return ": \(g.etichetta.lowercased()) (sopportabile il \(CifreDoc.condizione(s)))."
    }

    /// Le posizioni toccate da almeno una crisi, nell'ordine della crisi peggiore.
    private var posizioni: [EsitoCrisi.Voce] {
        var viste = Set<String>()
        var elenco: [EsitoCrisi.Voce] = []
        var ordinate: [EsitoCrisi] = []
        if let peggiore = r.crisiPeggiore { ordinate.append(peggiore) }
        ordinate += crisi
        for k in ordinate {
            for v in k.voci where !viste.contains(v.posizione.id) {
                viste.insert(v.posizione.id)
                elenco.append(v)
            }
        }
        return elenco
    }

    private var colonne: [ColonnaDoc] {
        var c = [ColonnaDoc(titolo: "Posizione", sottotitolo: "composizione", peso: 2.6, destra: false), ColonnaDoc(titolo: "Valore", peso: 0.9)]
        c += crisi.map { ColonnaDoc(titolo: "\($0.crisi.anno)", sottotitolo: $0.crisi.titolo.lowercased(), peso: 0.95) }
        return c
    }

    private var gruppi: [GruppoCanale] {
        let mostrate = Array(posizioni.prefix(Misure.Documento.righeTabellaFissa))
        return Canale.allCases.compactMap { c -> GruppoCanale? in
            let mie = mostrate.filter { $0.posizione.canale == c }
            guard !mie.isEmpty else { return nil }
            let righe = mie.map { v -> RigaDoc in
                var celle = [CellaDoc(v.posizione.nome, sotto: composizioneDoc(v.composizione), font: T.pTabellaForte),
                             CellaDoc(CifreDoc.euro(v.posizione.valore), font: T.pTabella)]
                for k in crisi {
                    let perdita = k.voci.first(where: { $0.posizione.id == v.posizione.id })?.perdita ?? 0
                    celle.append(CellaDoc(cifraCrisiDoc(perdita), colore: perdita > 0.5 ? C.negativo : (perdita < -0.5 ? C.positivo : C.tenue), font: T.pTabella))
                }
                return RigaDoc(celle: celle, altezza: Misure.Documento.Motori.rigaTabella)
            }
            return GruppoCanale(canale: c, righe: righe, nota: mie.count == 1 ? "1 posizione" : "\(mie.count) posizioni")
        }
    }
}

// MARK: - Pagina 3: inflazione, immobili, metodo

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
