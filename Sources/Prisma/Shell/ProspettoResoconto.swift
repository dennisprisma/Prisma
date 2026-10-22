import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il prospetto del resoconto delle posizioni in essere: A4 verticale, per il consulente.
/// Quadro con le cifre chiave, ogni posizione finanziaria con versato, valore, risultato e rendimento,
/// tutele, liquidità e debiti, impegni dell'anno, scadenze, storico dei valori e metodo.
enum ProspettoResoconto {
    /// Righe di posizioni finanziarie nella prima pagina; le altre vanno in una pagina di seguito.
    static let righePrimaPagina = 9

    static func pagine(_ t: TestiResoconto) -> [AnyView] {
        let finanziarie = t.e.finanziarie
        var pagine: [AnyView] = [AnyView(PaginaQuadro(t: t, voci: Array(finanziarie.prefix(righePrimaPagina)),
                                                      continua: finanziarie.count > righePrimaPagina))]
        var resto = Array(finanziarie.dropFirst(righePrimaPagina))
        while !resto.isEmpty {
            pagine.append(AnyView(PaginaSeguito(t: t, voci: Array(resto.prefix(26)))))
            resto = Array(resto.dropFirst(26))
        }
        pagine += [AnyView(PaginaTutele(t: t)), AnyView(PaginaStorico(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiResoconto.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

/// Le righe di un canale, sotto la sua etichetta (blu Alleanza, cuoio indipendente).
private struct GruppoCanale {
    let canale: Canale
    let righe: [RigaDoc]
    var nota = ""
}

/// Una tabella divisa per canale: l'etichetta del canale, poi le sue righe.
private struct TabellaCanali: View {
    @Environment(\.paletteDocumento) private var C
    let colonne: [ColonnaDoc]
    let gruppi: [GruppoCanale]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(gruppi.enumerated()), id: \.offset) { _, g in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center) {
                        EtichettaCanale(canale: g.canale)
                        Spacer()
                        Text(verbatim: g.nota).font(T.pTabellaNota).foregroundColor(C.tenue)
                    }
                    TabellaDoc(larghezza: larghezza, colonne: colonne, righe: g.righe, fontTesta: T.pTabellaTesta,
                               fontTestaSotto: T.pTabellaNota, altezzaTesta: 12, margine: 4)
                }
            }
        }
    }
}

/// Le righe delle posizioni finanziarie, per canale, con il totale del canale.
private func gruppiFinanziari(_ voci: [VoceResoconto], C: PaletteDocumento, totali: Bool) -> [GruppoCanale] {
    Canale.allCases.compactMap { canale in
        let mie = voci.filter { $0.posizione.canale == canale }
        guard !mie.isEmpty else { return nil }
        var righe = mie.map { v -> RigaDoc in
            let p = v.posizione
            var nome = CellaDoc(p.nome, sotto: [p.area.nome, p.tipologia].filter { !$0.isEmpty }.joined(separator: " · "), font: T.pTabellaForte)
            nome.coloreSotto = C.tenue
            let segno: (Double?) -> Color? = { x in x.map { $0 < -0.5 ? C.negativo : C.testo } }
            var risultato = CellaDoc(v.risultato.map { CifreDoc.euroSegno($0) } ?? "—", sotto: v.risultatoPercento.map { CifreDoc.variazione($0) } ?? "",
                                     colore: segno(v.risultato), font: T.pTabella)
            risultato.coloreSotto = segno(v.risultato)
            var dodici = CellaDoc(v.variazione12.map { CifreDoc.euroSegno($0) } ?? "—", sotto: v.variazione12Percento.map { CifreDoc.variazione($0) } ?? "",
                                  colore: segno(v.variazione12), font: T.pTabella)
            dodici.coloreSotto = segno(v.variazione12)
            return RigaDoc(celle: [
                nome,
                CellaDoc(TestiResoconto.quando(p.decorrenza), sotto: v.anni.map { String(format: "%.1f anni", $0).replacingOccurrences(of: ".", with: ",") } ?? "", font: T.pTabella),
                CellaDoc(v.versato.map { CifreDoc.euro($0) } ?? "—", sotto: p.premioAnnuo > 0 ? "\(CifreDoc.euro(p.premioAnnuo))/anno" : "", font: T.pTabella),
                CellaDoc(CifreDoc.euro(v.valore), sotto: "al \(TestiResoconto.quando(p.dataValore))", font: T.pTabellaForte),
                risultato,
                CellaDoc(v.rendimentoAnnuo.map { CifreDoc.variazione($0) } ?? "—", sotto: v.rendimentoAnnuo == nil ? "" : "l'anno", font: T.pTabella),
                dodici,
                CellaDoc(v.costoAnnuo.map { CifreDoc.euro($0) } ?? "—", sotto: p.costoAnnuo.map { "\(CifreDoc.condizione($0)) annuo" } ?? "", font: T.pTabella),
            ], altezza: 22)
        }
        if totali && mie.count > 1 {
            let versato = mie.reduce(0) { $0 + ($1.versato ?? 0) }
            let valore = mie.reduce(0) { $0 + $1.valore }
            let costo = mie.reduce(0) { $0 + ($1.costoAnnuo ?? 0) }
            righe.append(RigaDoc(celle: [CellaDoc("Totale \(canale.nomeBreve.lowercased())", font: T.pTabellaForte), CellaDoc(""),
                                         CellaDoc(CifreDoc.euro(versato), font: T.pTabellaForte), CellaDoc(CifreDoc.euro(valore), font: T.pTabellaForte),
                                         CellaDoc(CifreDoc.euroSegno(valore - versato), font: T.pTabellaForte), CellaDoc(""), CellaDoc(""),
                                         CellaDoc(costo > 0 ? CifreDoc.euro(costo) : "—", font: T.pTabellaForte)],
                                 altezza: 15, sfondo: C.riquadro, filetto: C.filettoForte, spessore: 0.8))
        }
        return GruppoCanale(canale: canale, righe: righe, nota: TestiResoconto.posizioni(mie.count))
    }
}

private let colonneFinanziarie = [
    ColonnaDoc(titolo: "Posizione", sottotitolo: "area · tipologia", peso: 2.6, destra: false),
    ColonnaDoc(titolo: "Decorrenza", sottotitolo: "durata", peso: 0.95),
    ColonnaDoc(titolo: "Versato", sottotitolo: "versamenti", peso: 1),
    ColonnaDoc(titolo: "Valore", sottotitolo: "data", peso: 1.05),
    ColonnaDoc(titolo: "Risultato", sottotitolo: "sul versato", peso: 1.1),
    ColonnaDoc(titolo: "Rend. medio", sottotitolo: "annuo", peso: 0.8),
    ColonnaDoc(titolo: "Ultimi 12 mesi", sottotitolo: "netto versamenti", peso: 1.05),
    ColonnaDoc(titolo: "Costi stimati", sottotitolo: "in un anno", peso: 0.95),
]

// MARK: - Pagina 1: il quadro

private struct PaginaQuadro: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto
    let voci: [VoceResoconto]
    let continua: Bool

    private var e: EsitoResoconto { t.e }

    private var sottotitolo: String {
        var parti = ["Situazione al \(CifreDoc.data(e.data))", "\(TestiResoconto.posizioni(e.voci.count)) in essere"]
        if !e.proposte.isEmpty { parti.append(e.proposte.count == 1 ? "1 proposta aperta" : "\(e.proposte.count) proposte aperte") }
        parti.append("valori dichiarati nelle Posizioni")
        return parti.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Resoconto delle posizioni in essere", font: T.pOcchiello)
                Text(verbatim: "Le posizioni di \(t.cliente)").font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: sottotitolo).font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(e.data)).frame(width: 90)
            }
            HStack(spacing: 6) {
                CifraProspetto("Patrimonio netto", CifreDoc.euro(e.riepilogo.patrimonioNetto),
                               e.riepilogo.debiti > 0 ? "attività \(CifreDoc.euro(e.riepilogo.attivita)) − debiti" : "nessun debito")
                CifraProspetto("Posizioni finanziarie", CifreDoc.euro(e.valoreFinanziario), "investimento, risparmio, previdenza")
                CifraProspetto("Totale versato", CifreDoc.euro(e.versato), "nelle posizioni finanziarie")
                CifraProspetto("Risultato", CifreDoc.euroSegno(e.risultato), "\(CifreDoc.variazione(e.risultatoPercento)) sul versato",
                               colore: e.risultato < -0.5 ? C.negativo : C.positivo)
                CifraProspetto("Rendimento medio", e.rendimentoAnnuo.map { CifreDoc.variazione($0) } ?? "—", "annuo, dei versamenti")
            }
            HStack(spacing: 6) {
                CifraProspetto("Ultimi 12 mesi", e.variazione12.map { CifreDoc.euroSegno($0) } ?? "—",
                               e.variazione12Percento.map { "\(CifreDoc.variazione($0)) netto versamenti" } ?? "serve lo storico dei valori",
                               colore: (e.variazione12 ?? 0) < -0.5 ? C.negativo : nil)
                CifraProspetto("Costi stimati", CifreDoc.euro(e.costoAnnuo), e.incidenzaCosti.map { "in un anno · \(CifreDoc.percento($0)) del valore" } ?? "in un anno")
                CifraProspetto("Capitali assicurati", CifreDoc.euro(e.riepilogo.capitaleAssicurato),
                               "\(e.coperture.count) \(e.coperture.count == 1 ? "copertura" : "coperture") · \(CifreDoc.euro(e.premiCoperture))/anno")
                CifraProspetto("Liquidità", CifreDoc.euro(e.liquidita), "conti e depositi")
                CifraProspetto("Debiti residui", CifreDoc.euro(e.riepilogo.debiti), e.rateAnnue > 0 ? "rate \(CifreDoc.euro(e.rateAnnue / 12))/mese" : "—")
            }
            SezioneProspetto(titolo: "Le posizioni finanziarie, una per una",
                             testo: Text(verbatim: "Versato, valore e risultato già al netto dei costi del prodotto, prima delle imposte sul guadagno. Rendimento medio annuo e ultimi 12 mesi tengono conto delle date dei versamenti (metodo nell'ultima pagina)."))
            if voci.isEmpty {
                Text(verbatim: "Nessuna posizione di investimento, risparmio o previdenza in essere.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: colonneFinanziarie, gruppi: gruppiFinanziari(voci, C: C, totali: !continua))
                if continua {
                    Text(verbatim: "Le altre posizioni finanziarie continuano nella pagina seguente.").font(T.pTabellaNota).foregroundColor(C.tenue)
                }
            }
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: "Per area").font(T.pSottosezione).foregroundColor(C.titolo)
                    ForEach(e.aree) { a in
                        BarraQuota(etichetta: a.area.nome, nota: TestiResoconto.posizioni(a.posizioni), valore: a.valore,
                                   quota: a.quota, colore: C.area(a.area), passivo: a.area.passivo)
                    }
                }
                .frame(width: (larghezza - 18) * 0.56, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: "Per canale").font(T.pSottosezione).foregroundColor(C.titolo)
                    ForEach(e.canali.filter { $0.posizioni > 0 }) { c in
                        VStack(alignment: .leading, spacing: 3) {
                            EtichettaCanale(canale: c.canale)
                            BarraQuota(etichetta: TestiResoconto.posizioni(c.posizioni), nota: c.versato > 0 ? "risultato \(CifreDoc.euroSegno(c.risultato))" : "",
                                       valore: c.valore, quota: e.riepilogo.attivita > 0 ? c.valore / e.riepilogo.attivita : 0,
                                       colore: C.canale(c.canale), passivo: false)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

/// Barra orizzontale con etichetta, valore e quota.
private struct BarraQuota: View {
    @Environment(\.paletteDocumento) private var C
    let etichetta: String
    let nota: String
    let valore: Double
    let quota: Double
    let colore: Color
    let passivo: Bool

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: etichetta).font(T.pTabellaForte).foregroundColor(C.testo).lineLimit(1)
                if !nota.isEmpty { Text(verbatim: nota).font(T.pTabellaNota).foregroundColor(C.tenue).lineLimit(1) }
            }
            .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(C.griglia)
                    Rectangle().fill(colore).frame(width: max(1, geo.size.width * CGFloat(min(max(quota, 0), 1))))
                }
            }
            .frame(height: 7)
            Text(verbatim: (passivo ? "− " : "") + CifreDoc.euro(valore)).font(T.pTabellaForte).foregroundColor(C.titolo)
                .frame(width: 58, alignment: .trailing)
            Text(verbatim: CifreDoc.percento(quota * 100, decimali: 0)).font(T.pTabella).foregroundColor(C.tenue)
                .frame(width: 26, alignment: .trailing)
        }
        .frame(height: 18)
    }
}

// MARK: - Pagina di seguito

private struct PaginaSeguito: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto
    let voci: [VoceResoconto]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Le posizioni finanziarie (seguito)")
            TabellaCanali(colonne: colonneFinanziarie, gruppi: gruppiFinanziari(voci, C: C, totali: false))
        }
    }
}

// MARK: - Pagina 2: tutele, liquidità, debiti, impegni, scadenze

private struct PaginaTutele: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto

    private var e: EsitoResoconto { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Le tutele in essere",
                             testo: Text(verbatim: e.coperture.isEmpty ? "Nessuna copertura in essere." : "Capitale assicurato, premio e costo per ogni 1.000 € assicurati (premio annuo diviso per il capitale, per mille)."))
            if !e.coperture.isEmpty {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Copertura", sottotitolo: "tipologia", peso: 2.5, destra: false),
                    ColonnaDoc(titolo: "Rischio", sottotitolo: "assicurato", peso: 1.5, destra: false),
                    ColonnaDoc(titolo: "Capitale", peso: 1),
                    ColonnaDoc(titolo: "Premio", sottotitolo: "in un anno", peso: 0.9),
                    ColonnaDoc(titolo: "Per 1.000 €", sottotitolo: "assicurati", peso: 0.8),
                    ColonnaDoc(titolo: "Scadenza", sottotitolo: "beneficiari", peso: 1.3),
                ], gruppi: gruppi(e.coperture) { v in
                    let p = v.posizione
                    let mille = (p.capitaleAssicurato ?? 0) > 0 ? p.premioAnnuo / (p.capitaleAssicurato ?? 1) * 1000 : nil
                    return [CellaDoc(p.nome, sotto: p.tipologia, font: T.pTabellaForte),
                            CellaDoc(p.rischio?.nome ?? "—", sotto: p.assicurato, font: T.pTabella),
                            CellaDoc(CifreDoc.euro(p.capitaleAssicurato ?? 0), font: T.pTabellaForte),
                            CellaDoc(CifreDoc.euro(p.premioAnnuo), sotto: p.frequenza == .unica ? "" : p.frequenza.nome.lowercased(), font: T.pTabella),
                            CellaDoc(mille.map { Formati.euroDecimali($0) } ?? "—", font: T.pTabella),
                            CellaDoc(TestiResoconto.quando(p.scadenza), sotto: p.beneficiari, font: T.pTabella)]
                })
            }
            SezioneProspetto(titolo: "Liquidità, immobili e debiti")
            let altre = e.voci.filter { [.liquidita, .immobili, .debiti].contains($0.posizione.area) }
            if altre.isEmpty {
                Text(verbatim: "Nessuna voce indicata.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Voce", sottotitolo: "tipologia", peso: 2.5, destra: false),
                    ColonnaDoc(titolo: "Area", peso: 1, destra: false),
                    ColonnaDoc(titolo: "Valore", sottotitolo: "o debito residuo", peso: 1.1),
                    ColonnaDoc(titolo: "Rata", sottotitolo: "al mese", peso: 0.9),
                    ColonnaDoc(titolo: "Scadenza", peso: 1),
                ], gruppi: gruppi(altre) { v in
                    let p = v.posizione
                    return [CellaDoc(p.nome, sotto: [p.tipologia, p.emittente].filter { !$0.isEmpty }.joined(separator: " · "), font: T.pTabellaForte),
                            CellaDoc(p.area.nome, font: T.pTabella),
                            CellaDoc((p.area.passivo ? "− " : "") + CifreDoc.euro(v.valore), colore: p.area.passivo ? C.negativo : nil, font: T.pTabellaForte),
                            CellaDoc(p.area.passivo && p.premioAnnuo > 0 ? CifreDoc.euro(p.premioAnnuo / 12) : "—", font: T.pTabella),
                            CellaDoc(TestiResoconto.quando(p.scadenza), font: T.pTabella)]
                })
            }
            SezioneProspetto(titolo: "Gli impegni di un anno")
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Voce", peso: 3, destra: false), ColonnaDoc(titolo: "In un anno"),
                                                       ColonnaDoc(titolo: "Al mese")],
                       righe: impegni, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            SezioneProspetto(titolo: "Scadenze dei prossimi \(MotoreResoconto.mesiScadenze) mesi",
                             testo: e.scadenze.isEmpty ? Text(verbatim: "Nessuna scadenza nei prossimi \(MotoreResoconto.mesiScadenze) mesi.") : nil)
            if !e.scadenze.isEmpty {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Data", peso: 0.9, destra: false), ColonnaDoc(titolo: "Posizione", peso: 2.4, destra: false),
                    ColonnaDoc(titolo: "Che cosa", peso: 2, destra: false), ColonnaDoc(titolo: "Valore o premio", peso: 1.1),
                ], gruppi: Canale.allCases.compactMap { c in
                    let mie = e.scadenze.filter { $0.posizione.canale == c }
                    guard !mie.isEmpty else { return nil }
                    return GruppoCanale(canale: c, righe: mie.map { s in
                        let p = s.posizione
                        let importo = p.area == .protezione ? "\(CifreDoc.euro(p.premioAnnuo))/anno" : CifreDoc.euro(p.valore)
                        return RigaDoc(celle: [CellaDoc(CifreDoc.dataBreve(s.data), colore: s.scaduta ? C.negativo : nil, font: T.pTabellaForte),
                                               CellaDoc(p.nome, font: T.pTabella),
                                               CellaDoc(s.scaduta ? "\(s.cosa) (già passata)" : s.cosa, font: T.pTabella),
                                               CellaDoc(importo, font: T.pTabella)], altezza: 14)
                    }, nota: mie.count == 1 ? "1 scadenza" : "\(mie.count) scadenze")
                })
            }
            if !e.proposte.isEmpty {
                SezioneProspetto(titolo: "Proposte ancora aperte")
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(e.proposte) { p in
                        PuntoElenco(testo: Text(verbatim: p.nome).bold() + Text(verbatim: dettaglioProposta(p)))
                    }
                }
            }
        }
    }

    private func dettaglioProposta(_ p: Posizione) -> String {
        var parti = [p.canale.nome, p.area.nome.lowercased(), p.esito?.nome.lowercased() ?? "bozza"]
        if p.premioAnnuo > 0 { parti.append("\(CifreDoc.euro(p.premioAnnuo))/anno") }
        if p.versamentoIniziale > 0 { parti.append("iniziale \(CifreDoc.euro(p.versamentoIniziale))") }
        return " · " + parti.joined(separator: " · ")
    }

    private func gruppi(_ voci: [VoceResoconto], _ celle: (VoceResoconto) -> [CellaDoc]) -> [GruppoCanale] {
        Canale.allCases.compactMap { c in
            let mie = voci.filter { $0.posizione.canale == c }
            guard !mie.isEmpty else { return nil }
            return GruppoCanale(canale: c, righe: mie.map { RigaDoc(celle: celle($0), altezza: 21) }, nota: TestiResoconto.posizioni(mie.count))
        }
    }

    private var impegni: [RigaDoc] {
        var righe: [RigaDoc] = []
        func riga(_ nome: String, _ anno: Double, forte: Bool = false) {
            let font = forte ? T.pTabellaForte : T.pTabella
            righe.append(RigaDoc(celle: [CellaDoc(nome, font: font), CellaDoc(CifreDoc.euro(anno), font: font), CellaDoc(CifreDoc.euro(anno / 12), font: font)],
                                 altezza: 14, sfondo: forte ? C.riquadro : .clear, filetto: forte ? C.filettoForte : nil, spessore: forte ? 0.8 : 0.5))
        }
        riga("Versamenti periodici in investimento, risparmio e previdenza", e.versamentiAnnui)
        riga("Premi delle coperture", e.premiCoperture)
        riga("Rate dei finanziamenti", e.rateAnnue)
        riga("Totale", t.impegnoAnnuo, forte: true)
        return righe
    }
}

// MARK: - Pagina 3: storico, metodo, firme

private struct PaginaStorico: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto

    var body: some View {
        let conStorico = t.e.finanziarie.filter { $0.posizione.storicoValori.count > 1 }
        return VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Lo storico dei valori",
                             testo: Text(verbatim: conStorico.isEmpty
                                         ? "Nessuna posizione ha ancora valori rilevati in date diverse: lo storico si forma da solo ogni volta che aggiorni il controvalore in Posizioni."
                                         : "I valori rilevati nel tempo. La variazione è al netto dei versamenti fatti tra una rilevazione e l'altra; lo storico si arricchisce ogni volta che aggiorni il controvalore in Posizioni."))
            ForEach(Canale.allCases) { c in
                let mie = conStorico.filter { $0.posizione.canale == c }
                if !mie.isEmpty {
                    EtichettaCanale(canale: c)
                    ForEach(Array(stride(from: 0, to: mie.count, by: 2)), id: \.self) { i in
                        HStack(alignment: .top, spacing: 18) {
                            storico(mie[i])
                            if i + 1 < mie.count { storico(mie[i + 1]) } else { Spacer(minLength: 0) }
                        }
                    }
                }
            }
            SezioneProspetto(titolo: "Come sono calcolate le cifre")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(TestiResoconto.metodo.enumerated()), id: \.offset) { _, m in
                    PuntoElenco(testo: Text(verbatim: "\(m.0): ").bold() + Text(verbatim: m.1))
                }
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold()
             + Text(verbatim: "I valori sono quelli indicati nelle Posizioni alla data riportata accanto a ciascuno e possono differire da quelli ufficiali delle compagnie e degli intermediari. I risultati passati non sono indicativi di quelli futuri. Il risultato è al lordo delle imposte che si pagheranno sul guadagno al momento del riscatto o della vendita."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }

    private func storico(_ v: VoceResoconto) -> some View {
        let w = (larghezza - 18) / 2
        let punti = v.posizione.storicoValori
        var righe: [RigaDoc] = []
        for (i, r) in punti.enumerated() {
            var variazione = "—"
            if i > 0 {
                let prima = punti[i - 1]
                let versamenti = max(0, (r.versato ?? 0) - (prima.versato ?? r.versato ?? 0))
                let base = prima.controvalore + versamenti / 2
                if base > 0 { variazione = CifreDoc.variazione((r.controvalore - prima.controvalore - versamenti) / base * 100) }
            }
            let ultima = i == punti.count - 1
            let font = ultima ? T.pTabellaForte : T.pTabella
            righe.append(RigaDoc(celle: [CellaDoc(CifreDoc.dataBreve(r.data), font: font), CellaDoc(CifreDoc.euro(r.controvalore), font: font),
                                         CellaDoc(r.versato.map { CifreDoc.euro($0) } ?? "—", font: font), CellaDoc(variazione, font: font)],
                                 altezza: 13, filetto: ultima ? C.filettoForte : nil, spessore: ultima ? 0.8 : 0.5))
        }
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Rectangle().fill(C.canale(v.posizione.canale)).frame(width: 3, height: 10)
                Text(verbatim: v.posizione.nome).font(T.pSottosezione).foregroundColor(C.titolo).lineLimit(1)
            }
            TabellaDoc(larghezza: w, colonne: [ColonnaDoc(titolo: "Data", destra: false), ColonnaDoc(titolo: "Valore"),
                                               ColonnaDoc(titolo: "Versato"), ColonnaDoc(titolo: "Variazione")],
                       righe: righe, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 3)
        }
        .frame(width: w, alignment: .topLeading)
    }
}
