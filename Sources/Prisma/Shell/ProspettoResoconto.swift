import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il prospetto del resoconto delle posizioni in essere: A4 verticale, per il consulente.
/// Quadro con le cifre chiave, ogni posizione finanziaria con versato, valore, risultato e rendimento,
/// tutele, liquidità e debiti, impegni dell'anno, scadenze, storico dei valori e metodo.
enum ProspettoResoconto {
    /// Righe di posizioni finanziarie nella prima pagina; le altre vanno in una pagina di seguito.
    static let righePrimaPagina = 9
    /// Posizioni con l'andamento nella prima pagina (sotto il riepilogo) e nelle successive.
    static let andamentiPrimaPagina = 3
    static let andamentiPerPagina = 4
    /// Valori di ogni posizione nella pagina dello storico.
    static let valoriStorico = 6

    static func pagine(_ t: TestiResoconto) -> [AnyView] {
        let finanziarie = t.e.finanziarie
        var pagine: [AnyView] = [AnyView(PaginaQuadro(t: t, voci: Array(finanziarie.prefix(righePrimaPagina)),
                                                      continua: finanziarie.count > righePrimaPagina))]
        var resto = Array(finanziarie.dropFirst(righePrimaPagina))
        while !resto.isEmpty {
            pagine.append(AnyView(PaginaSeguito(t: t, voci: Array(resto.prefix(26)))))
            resto = Array(resto.dropFirst(26))
        }
        if !finanziarie.isEmpty { pagine.append(AnyView(PaginaFisco(t: t))) }
        let previdenze = t.e.previdenze
        for inizio in stride(from: 0, to: previdenze.count, by: 2) {
            pagine.append(AnyView(PaginaPrevidenza(voci: Array(previdenze[inizio..<min(inizio + 2, previdenze.count)]))))
        }
        // Com'è andata rispetto all'atteso: tre posizioni nella prima pagina (sotto il riepilogo), quattro nelle altre
        let andamenti = t.andamenti
        if !andamenti.isEmpty {
            pagine.append(AnyView(PaginaAndamento(t: t, voci: Array(andamenti.prefix(andamentiPrimaPagina)), prima: true)))
            var altri = Array(andamenti.dropFirst(andamentiPrimaPagina))
            while !altri.isEmpty {
                pagine.append(AnyView(PaginaAndamento(t: t, voci: Array(altri.prefix(andamentiPerPagina)), prima: false)))
                altri = Array(altri.dropFirst(andamentiPerPagina))
            }
        }
        pagine += [AnyView(PaginaTutele(t: t)), AnyView(PaginaStorico(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiResoconto.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

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
                             testo: Text(verbatim: "Versato, valore e risultato già al netto dei costi del prodotto, prima delle imposte sul guadagno. Rendimento medio annuo e ultimi 12 mesi tengono conto delle date dei versamenti (metodo nell'ultima pagina). Imposte e netto incassabile nella pagina seguente."))
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
                    ForEach(e.aree.filter { $0.valore > 0.5 }) { a in
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
        // Gli ultimi valori: la pagina è una sola, con il metodo e le firme
        let punti = Array(v.posizione.storicoValori.sorted { $0.data < $1.data }.suffix(ProspettoResoconto.valoriStorico))
        // La variazione di ogni valore rispetto al precedente: la stessa della pagina dell'andamento
        let periodi = MotoreAndamento.calcola(v.posizione)?.periodi ?? []
        var righe: [RigaDoc] = []
        for (i, r) in punti.enumerated() {
            var variazione = "—"
            if let q = periodi.first(where: { $0.al == r.data }), let rendimento = q.rendimento {
                variazione = (q.stimati ? "≈ " : "") + CifreDoc.variazione(rendimento)
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

// MARK: - Andamento rispetto all'atteso

private struct PaginaAndamento: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto
    let voci: [(voce: VoceResoconto, andamento: AndamentoPosizione)]
    let prima: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SezioneProspetto(titolo: prima ? "Com'è andata rispetto all'atteso" : "Com'è andata rispetto all'atteso (segue)",
                             testo: prima ? Text(verbatim: "Per ogni posizione con almeno due valori rilevati: il rendimento tra un valore e il successivo, tolti i versamenti del periodo, concatenato su tutto lo storico e reso annuo da circa un anno. È già al netto dei costi del prodotto e si confronta con il rendimento atteso della posizione meno i costi annui; «in linea» vuol dire entro un punto all'anno.") : nil)
            if prima { riepilogo }
            ForEach(Array(voci.enumerated()), id: \.offset) { _, x in
                blocco(x.voce, x.andamento)
            }
        }
    }

    /// Tutte le posizioni con l'andamento, in una tabella.
    private var riepilogo: some View {
        let tutte = t.andamenti
        let righe = tutte.map { v, a -> RigaDoc in
            let p = v.posizione
            var nome = CellaDoc(p.nome, sotto: "\(p.canale.nomeBreve) · \(p.area.nome)", font: T.pTabellaForte)
            nome.coloreSotto = C.tenue
            let colore: Color? = a.giudizio == .sotto ? C.negativo : a.giudizio == .sopra ? C.positivo : nil
            return RigaDoc(celle: [
                nome,
                CellaDoc(CifreDoc.dataBreve(a.dal), sotto: "\(a.punti.count) valori", font: T.pTabella),
                CellaDoc(a.rendimentoAnnuo.map { CifreDoc.variazione($0) } ?? CifreDoc.variazione(a.rendimentoPeriodo),
                         sotto: a.rendimentoAnnuo == nil ? "in \(TestiResoconto.mesi(a.anni))" : "l'anno", font: T.pTabellaForte),
                CellaDoc(a.attesoConfrontabile.map { CifreDoc.percento($0) } ?? "—", sotto: a.attesoAnnuo == nil ? "non indicato" : "netto dei costi", font: T.pTabella),
                CellaDoc(a.scarto.map { MotoreAndamento.punti($0) } ?? "—", colore: colore, font: T.pTabella),
                CellaDoc(a.giudizio?.etichetta ?? "—", colore: colore, font: T.pTabellaForte),
            ], altezza: 20, filetto: C.filetto, spessore: 0.5)
        }
        return TabellaDoc(larghezza: larghezza, colonne: [
            ColonnaDoc(titolo: "Posizione", peso: 2.4, destra: false),
            ColonnaDoc(titolo: "Dal", sottotitolo: "storico", peso: 0.9),
            ColonnaDoc(titolo: "Rendimento", sottotitolo: "effettivo", peso: 1),
            ColonnaDoc(titolo: "Atteso", sottotitolo: "stesso periodo", peso: 1),
            ColonnaDoc(titolo: "Scarto", peso: 0.9),
            ColonnaDoc(titolo: "Giudizio", peso: 1.3),
        ], righe: righe, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 22, margine: 4)
    }

    private func blocco(_ v: VoceResoconto, _ a: AndamentoPosizione) -> some View {
        let p = v.posizione
        let grafico = (larghezza - 16) * 0.5
        let colore: Color = a.giudizio == .sotto ? C.negativo : a.giudizio == .sopra ? C.positivo : C.tenue
        var serie = [SerieDoc(nome: "Valore", colore: C.canale(p.canale), valori: a.punti.map(\.valore))]
        if a.punti.allSatisfy({ $0.atteso != nil }) {
            serie.append(SerieDoc(nome: "All'atteso", colore: C.tenue, valori: a.punti.map { $0.atteso ?? 0 }, tratteggio: true))
        }
        // Al massimo cinque date sotto il grafico
        let passo = max(1, Int((Double(a.punti.count - 1) / 4).rounded(.up)))
        let etichette = a.punti.enumerated().map { i, pt in
            i % passo == 0 || i == a.punti.count - 1 ? CifreDoc.dataBreve(pt.data) : ""
        }
        let periodi = a.periodi.suffix(4).map { q -> RigaDoc in
            let segno: Color? = q.guadagno < -0.5 ? C.negativo : nil
            return RigaDoc(celle: [
                CellaDoc("\(CifreDoc.dataBreve(q.dal)) – \(CifreDoc.dataBreve(q.al))", font: T.pTabella),
                CellaDoc((q.stimati ? "≈ " : "") + CifreDoc.euroSegno(q.versamenti), font: T.pTabella),
                CellaDoc(CifreDoc.euroSegno(q.guadagno), colore: segno, font: T.pTabella),
                CellaDoc(q.rendimento.map { CifreDoc.variazione($0) } ?? "—", colore: segno, font: T.pTabellaForte),
            ], altezza: 13, filetto: C.filetto, spessore: 0.5)
        }
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Rectangle().fill(C.canale(p.canale)).frame(width: 3, height: 10)
                Text(verbatim: p.nome).font(T.pSottosezione).foregroundColor(C.titolo).lineLimit(1)
                Text(verbatim: "· dal \(CifreDoc.dataBreve(a.dal)) al \(CifreDoc.dataBreve(a.al))").font(T.pTabella).foregroundColor(C.tenue)
                Spacer(minLength: 0)
                if let g = a.giudizio { Text(verbatim: g.etichetta).font(T.pTabellaForte).foregroundColor(colore) }
            }
            HStack(alignment: .top, spacing: 16) {
                GraficoLineeDoc(serie: serie, etichetteAsse: etichette, fontAssi: T.pAssi, fontValori: T.pAssi)
                    .frame(width: grafico, height: 112)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        CifraProspetto("Rendimento", CifreDoc.variazione(a.rendimentoAnnuo ?? a.rendimentoPeriodo),
                                       a.rendimentoAnnuo != nil ? "l'anno, netto dei costi" : "in \(TestiResoconto.mesi(a.anni)), netto dei costi")
                        CifraProspetto("Atteso", a.attesoConfrontabile.map { CifreDoc.percento($0) } ?? "—",
                                       a.scarto.map { MotoreAndamento.punti($0) } ?? "non indicato", colore: a.attesoAnnuo == nil ? C.tenue : nil)
                        CifraProspetto(a.guadagno >= 0 ? "Guadagno" : "Perdita", CifreDoc.euro(abs(a.guadagno)), "tolti i versamenti",
                                       colore: a.guadagno < -0.5 ? C.negativo : nil)
                    }
                    TabellaDoc(larghezza: larghezza - 16 - grafico, colonne: [
                        ColonnaDoc(titolo: "Periodo", peso: 1.6, destra: false), ColonnaDoc(titolo: "Versamenti"),
                        ColonnaDoc(titolo: "Guadagno"), ColonnaDoc(titolo: "Rendimento", peso: 0.8),
                    ], righe: periodi, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 3)
                }
                .frame(width: larghezza - 16 - grafico, alignment: .topLeading)
            }
        }
        .padding(.top, 4)
        .overlay(Rectangle().fill(C.filetto).frame(height: 0.6), alignment: .top)
    }
}

// MARK: - Fiscalità e netto incassabile

private struct PaginaFisco: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiResoconto

    private var e: EsitoResoconto { t.e }

    var body: some View {
        let conCosti = e.voci.filter { $0.fisco.costoTotale > 0 }
        return VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Se si chiudesse tutto oggi: imposte e netto incassabile",
                             testo: Text(verbatim: "Per ogni posizione finanziaria: penale di riscatto (se il prodotto ha le condizioni del contratto), bollo maturato, imposta sul guadagno con l'aliquota del suo regime e importo netto. Cifre al centesimo; per la previdenza la prestazione al pensionamento (le altre cause sono nella pagina seguente)."))
            HStack(spacing: 6) {
                CifraProspetto("Valore oggi", CifreDoc.euro(e.valoreFinanziario), "posizioni finanziarie")
                CifraProspetto("Penali e bollo", e.penaliFinanziarie > 0.005 ? CifreDoc.togli(e.penaliFinanziarie) : "—", "maturati al riscatto")
                CifraProspetto("Imposte stimate", e.imposteFinanziarie > 0.005 ? CifreDoc.togli(e.imposteFinanziarie) : "—", "sul guadagno",
                               colore: C.negativo)
                CifraProspetto("Netto incassabile", CifreDoc.euro(e.nettoFinanziario), "\(CifreDoc.euroSegno(e.nettoFinanziario - e.versato)) sul versato",
                               colore: C.positivo)
                CifraProspetto("Rendimento netto", e.rendimentoNettoAnnuo.map { CifreDoc.variazione($0) } ?? "—", "annuo, dopo le imposte")
            }
            TabellaCanali(colonne: [
                ColonnaDoc(titolo: "Posizione", sottotitolo: "regime fiscale", peso: 2.3, destra: false),
                ColonnaDoc(titolo: "Valore", sottotitolo: "versato", peso: 1.15),
                ColonnaDoc(titolo: "Penale e bollo", sottotitolo: "al riscatto", peso: 1),
                ColonnaDoc(titolo: "Imponibile", sottotitolo: "guadagno tassato", peso: 1.1),
                ColonnaDoc(titolo: "Aliquota", sottotitolo: "effettiva", peso: 0.75),
                ColonnaDoc(titolo: "Imposta", peso: 1),
                ColonnaDoc(titolo: "Netto oggi", sottotitolo: "rend. netto annuo", peso: 1.25),
            ], gruppi: Canale.allCases.compactMap { c in
                let mie = e.finanziarie.filter { $0.posizione.canale == c }
                guard !mie.isEmpty else { return nil }
                var righe = mie.map { v -> RigaDoc in
                    let f = v.fisco
                    let trattenute = f.penale + f.bolloMaturato
                    var netto = CellaDoc(CifreDoc.euroCentesimi(f.netto), sotto: v.rendimentoNettoAnnuo.map { "\(CifreDoc.variazione($0)) l'anno" } ?? "",
                                         font: T.pTabellaForte)
                    netto.coloreSotto = C.tenue
                    return RigaDoc(celle: [
                        CellaDoc(v.posizione.nome, sotto: f.regime.nome + (f.regime == .previdenza ? " · pensionamento" : ""), font: T.pTabellaForte),
                        CellaDoc(CifreDoc.euroCentesimi(f.valore), sotto: "versato \(CifreDoc.euro(f.versato))", font: T.pTabella),
                        CellaDoc(trattenute > 0.005 ? CifreDoc.togli(trattenute) : "—", font: T.pTabella),
                        CellaDoc(CifreDoc.euroCentesimi(f.imponibile), font: T.pTabella),
                        CellaDoc(f.imposta > 0.005 || f.regime == .previdenza ? CifreDoc.percento(f.aliquota, decimali: 2) : "—", font: T.pTabella),
                        CellaDoc(f.imposta > 0.005 ? "\(CifreDoc.meno) " + CifreDoc.euroCentesimi(f.imposta) : "—", colore: f.imposta > 0.005 ? C.negativo : nil, font: T.pTabella),
                        netto,
                    ], altezza: 22)
                }
                if mie.count > 1 {
                    let netto = mie.reduce(0) { $0 + $1.fisco.netto }, imposta = mie.reduce(0) { $0 + $1.fisco.imposta }
                    righe.append(RigaDoc(celle: [CellaDoc("Totale \(c.nomeBreve.lowercased())", font: T.pTabellaForte),
                                                 CellaDoc(CifreDoc.euroCentesimi(mie.reduce(0) { $0 + $1.fisco.valore }), font: T.pTabellaForte),
                                                 CellaDoc(""), CellaDoc(""), CellaDoc(""),
                                                 CellaDoc(imposta > 0.005 ? "\(CifreDoc.meno) " + CifreDoc.euroCentesimi(imposta) : "—", font: T.pTabellaForte),
                                                 CellaDoc(CifreDoc.euroCentesimi(netto), font: T.pTabellaForte)],
                                         altezza: 15, sfondo: C.riquadro, filetto: C.filettoForte, spessore: 0.8))
                }
                return GruppoCanale(canale: c, righe: righe, nota: TestiResoconto.posizioni(mie.count))
            })
            if !conCosti.isEmpty {
                SezioneProspetto(titolo: "I costi di un anno, voce per voce",
                                 testo: Text(verbatim: "Gestione (costo annuo del prodotto), trattenuto sul rendimento della gestione separata e imposta di bollo, sul valore di oggi. Sono già compresi nel valore: non si pagano a parte, tranne il bollo di fondi e conti."))
                TabellaDoc(larghezza: larghezza, colonne: [
                    ColonnaDoc(titolo: "Posizione", peso: 2.6, destra: false), ColonnaDoc(titolo: "Canale", peso: 0.9, destra: false),
                    ColonnaDoc(titolo: "Gestione", sottotitolo: "costo annuo"), ColonnaDoc(titolo: "Trattenuto", sottotitolo: "sul rendimento"),
                    ColonnaDoc(titolo: "Bollo", sottotitolo: "0,20% o fisso"), ColonnaDoc(titolo: "Totale", sottotitolo: "in un anno"),
                ], righe: conCosti.map { v in
                    let f = v.fisco, p = v.posizione
                    func cella(_ x: Double, _ sotto: String) -> CellaDoc { CellaDoc(x > 0.005 ? CifreDoc.euroCentesimi(x) : "—", sotto: x > 0.005 ? sotto : "", font: T.pTabella) }
                    return RigaDoc(celle: [CellaDoc(p.nome, font: T.pTabellaForte),
                                           CellaDoc(p.canale.nomeBreve, colore: C.canale(p.canale), font: T.pTabellaForte),
                                           cella(f.costoGestione, p.costoAnnuo.map { CifreDoc.condizione($0) } ?? ""),
                                           cella(f.costoTrattenuto, p.trattenuto.map { "\(CifreDoc.condizione($0)) punti" } ?? ""),
                                           cella(f.costoBollo, ""),
                                           CellaDoc(CifreDoc.euroCentesimi(f.costoTotale), font: T.pTabellaForte)], altezza: 20)
                } + [RigaDoc(celle: [CellaDoc("Totale", font: T.pTabellaForte), CellaDoc(""),
                                     CellaDoc(CifreDoc.euroCentesimi(e.costoGestione), font: T.pTabellaForte),
                                     CellaDoc(CifreDoc.euroCentesimi(e.costoTrattenuto), font: T.pTabellaForte),
                                     CellaDoc(CifreDoc.euroCentesimi(e.costoBollo), font: T.pTabellaForte),
                                     CellaDoc(CifreDoc.euroCentesimi(e.costoAnnuo), font: T.pTabellaForte)],
                             altezza: 15, sfondo: C.riquadro, filetto: C.filettoForte, spessore: 0.8)],
                           fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 12, margine: 4)
            }
            let note = e.finanziarie.flatMap { v in v.fisco.note.map { "\(v.posizione.nome): \($0)" } }
            if !note.isEmpty {
                SezioneProspetto(titolo: "Come sono calcolate le imposte")
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(note.prefix(12).enumerated()), id: \.offset) { _, n in
                        Text(verbatim: "• " + n).font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Previdenza: quanto si incassa per ogni causa

private struct PaginaPrevidenza: View {
    @Environment(\.paletteDocumento) private var C
    let voci: [VoceResoconto]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SezioneProspetto(titolo: "Previdenza complementare: quanto si incassa e con quale aliquota",
                             testo: Text(verbatim: "I rendimenti sono già tassati ogni anno dentro il fondo (20%, 12,5% sui titoli di Stato): alla richiesta si tassano solo i contributi dedotti. Pensionamento, riscatti per invalidità, inoccupazione oltre 48 mesi o decesso e anticipazioni per spese sanitarie: 15% fino al 15° anno di partecipazione, poi 0,30 punti in meno ogni anno fino al 9% dal 35° anno. Anticipazioni per la prima casa o per ulteriori esigenze e riscatti per altre cause: 23%."))
            ForEach(voci) { v in scheda(v) }
        }
    }

    private func scheda(_ v: VoceResoconto) -> some View {
        let f = v.fisco, p = v.posizione
        let inizio = p.primaAdesione ?? p.decorrenza
        let anni = f.anniPartecipazione ?? 0
        let righe = f.uscite.map { u -> RigaDoc in
            let quando = u.causa.anniRichiesti.flatMap { n in inizio.flatMap { Calendar.current.date(byAdding: .year, value: n, to: $0) } }
            var causa = CellaDoc(u.causa.nome, sotto: u.causa.requisito, font: T.pTabellaForte)
            causa.coloreSotto = C.tenue
            if !u.possibile {
                return RigaDoc(celle: [causa, CellaDoc("non ancora: dal \(TestiResoconto.quando(quando))", colore: C.tenue, font: T.pTabella)], altezza: 21)
            }
            return RigaDoc(celle: [causa,
                                   CellaDoc(CifreDoc.euroCentesimi(u.importo), sotto: u.causa.quotaMassima < 1 ? "fino al \(Int(u.causa.quotaMassima * 100))%" : "intera posizione", font: T.pTabella),
                                   CellaDoc(CifreDoc.euroCentesimi(u.imponibile), font: T.pTabella),
                                   CellaDoc(CifreDoc.percento(u.aliquota, decimali: 2), font: T.pTabellaForte),
                                   CellaDoc("\(CifreDoc.meno) " + CifreDoc.euroCentesimi(u.imposta), colore: C.negativo, font: T.pTabella),
                                   CellaDoc(CifreDoc.euroCentesimi(u.netto), font: T.pTabellaForte)], altezza: 21)
        }
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                EtichettaCanale(canale: p.canale)
                Text(verbatim: p.nome).font(T.pSottosezione).foregroundColor(C.titolo)
                Spacer()
                Text(verbatim: "\(anni) \(anni == 1 ? "anno" : "anni") di partecipazione" + (inizio.map { " (dal \(CifreDoc.dataBreve($0)))" } ?? ""))
                    .font(T.pTabellaNota).foregroundColor(C.tenue)
            }
            Text(verbatim: "Valore \(CifreDoc.euroCentesimi(f.valore)) · versato \(CifreDoc.euro(f.versato))"
                 + " · non dedotti \(CifreDoc.euro(p.contributiNonDedotti ?? 0)) · parte tassabile \(CifreDoc.percento(f.valore > 0 ? (f.uscite.first?.imponibile ?? 0) / f.valore * 100 : 0)) del valore")
                .font(T.pTabellaNota).foregroundColor(C.tenue)
            TabellaDoc(larghezza: larghezza, colonne: [
                ColonnaDoc(titolo: "Causa della richiesta", sottotitolo: "requisito", peso: 2.9, destra: false),
                ColonnaDoc(titolo: "Disponibile", sottotitolo: "importo lordo", peso: 1.15),
                ColonnaDoc(titolo: "Imponibile", sottotitolo: "contributi dedotti", peso: 1.1),
                ColonnaDoc(titolo: "Aliquota", sottotitolo: "oggi", peso: 0.75),
                ColonnaDoc(titolo: "Imposta", peso: 1),
                ColonnaDoc(titolo: "Netto", peso: 1.1),
            ], righe: righe, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 12, margine: 4)
            Text(verbatim: gradini(f, anni: anni)).font(T.pTabellaNota).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "Aliquota agevolata oggi 15,00%; dal 12/03/2027 (16 anni compiuti) 14,70%; … ; dal … (35 anni compiuti) 9,00%."
    private func gradini(_ f: EsitoFiscale, anni: Int) -> String {
        var s = "Aliquota agevolata oggi \(CifreDoc.percento(RegoleFiscali.aliquotaPrevidenza(anni: anni), decimali: 2))"
        guard !f.gradini.isEmpty else { return s + ": è già la minima." }
        let mostrati = f.gradini.count > 6 ? Array(f.gradini.prefix(5)) + [f.gradini[f.gradini.count - 1]] : f.gradini
        for (i, g) in mostrati.enumerated() {
            if f.gradini.count > 6 && i == 5 { s += "; …" }
            s += "; dal \(CifreDoc.dataBreve(g.dal)) (\(g.anni) anni compiuti) \(CifreDoc.percento(g.aliquota, decimali: 2))"
        }
        return s + "."
    }
}
