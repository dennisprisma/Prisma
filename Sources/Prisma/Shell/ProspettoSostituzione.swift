import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il prospetto della sostituzione (o del confronto tra due proposte): A4 verticale, per il consulente.
/// Le due strade, l'uscita di oggi, il netto anno per anno, gli scenari, i costi e le caratteristiche.
enum ProspettoSostituzione {
    static func pagine(_ t: TestiSostituzione) -> [AnyView] {
        let pagine: [AnyView] = [AnyView(PaginaDueStrade(t: t)), AnyView(PaginaAnni(t: t)), AnyView(PaginaCaratteristiche(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiSostituzione.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

/// Le etichette dei due canali sopra due colonne della tabella (blu Alleanza, cuoio indipendente).
private struct TestataCanali: View {
    let resto: Posizione
    let cambio: Posizione
    /// Pesi delle colonne prima, sotto la prima strada e sotto la seconda.
    let pesi: (CGFloat, CGFloat, CGFloat)

    var body: some View {
        let somma = pesi.0 + pesi.1 + pesi.2
        HStack(spacing: 0) {
            Color.clear.frame(width: larghezza * pesi.0 / somma, height: 1)
            EtichettaCanale(canale: resto.canale).frame(width: larghezza * pesi.1 / somma, alignment: .leading)
            EtichettaCanale(canale: cambio.canale).frame(width: larghezza * pesi.2 / somma, alignment: .leading)
        }
    }
}

// MARK: - Pagina 1: le due strade

private struct PaginaDueStrade: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSostituzione

    private var e: EsitoSostituzione { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: e.sostituzione ? "Prospetto di dettaglio · Sostituzione di una posizione" : "Prospetto di dettaglio · Confronto tra due proposte",
                             font: T.pOcchiello)
                Text(verbatim: e.sostituzione ? "\(t.a.nome) → \(t.b.nome)" : "\(t.a.nome) e \(t.b.nome)")
                    .font(T.pTitolo).foregroundColor(C.titolo).lineLimit(2).minimumScaleFactor(0.7)
                Text(verbatim: sottotitolo).font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            HStack(alignment: .top, spacing: 8) {
                scheda(e.resto, titolo: e.sostituzione ? "Oggi · se resta" : "Proposta A")
                scheda(e.cambio, titolo: e.sostituzione ? "Alternativa · se cambia" : "Proposta B")
            }
            if let f = e.finale {
                HStack(spacing: 6) {
                    CifraProspetto("\(t.nomeResto) · netto", CifreDoc.euro(f.nettoResto), "dopo \(t.periodo)", colore: C.premio)
                    CifraProspetto("\(t.nomeCambio) · netto", CifreDoc.euro(f.nettoCambio), "dopo \(t.periodo)", colore: C.intermedio)
                    CifraProspetto("Differenza", CifreDoc.euroSegno(f.differenza), "a favore di \(f.differenza >= 0 ? t.nomeCambio.lowercased() : t.nomeResto.lowercased())",
                                   colore: f.differenza >= 0 ? C.positivo : C.negativo)
                    if e.sostituzione {
                        CifraProspetto("Costo dell'uscita", CifreDoc.euro(e.costoUscita), "penale, bollo, imposte, ingresso")
                    }
                    CifraProspetto("Pareggio", e.pareggio.map { $0 == 1 ? "1° anno" : "\($0)° anno" } ?? "oltre \(e.anni) anni", "netto del cambio ≥ restare")
                }
            }
            if e.sostituzione {
                SezioneProspetto(titolo: "L'uscita di oggi",
                                 testo: Text(verbatim: e.trasferimento ? "Trasferimento tra forme pensionistiche: nessuna imposta, si trasferisce l'intero valore."
                                             : "Cosa resta del valore di oggi dopo penale, bollo maturato e imposte; poi il costo d'ingresso del nuovo prodotto."))
                TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Voce", peso: 3, destra: false), ColonnaDoc(titolo: "Importo", peso: 1.2),
                                                           ColonnaDoc(titolo: "Come si calcola", peso: 3.4, destra: false)],
                           righe: righeUscita, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            }
            SezioneProspetto(titolo: "Il netto incassabile anno per anno",
                             testo: Text(verbatim: "Quanto si incasserebbe chiudendo alla fine di ogni anno, dopo penali, bollo e imposte, nello scenario atteso."))
            GraficoLineeDoc(serie: [SerieDoc(nome: t.nomeResto, colore: C.premio, valori: e.serie.map(\.nettoResto), tratteggio: true),
                                    SerieDoc(nome: t.nomeCambio, colore: C.intermedio, valori: e.serie.map(\.nettoCambio))],
                            etichetteAsse: e.serie.map { $0.anno == 0 ? "oggi" : etichettaAnno($0.anno) },
                            pareggio: e.sostituzione ? e.pareggio : nil, fontAssi: T.pAssi, fontValori: T.pTabellaNota)
                .frame(height: 150)
                .background(C.riquadro.opacity(0.5))
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: 4) {
                    PuntoElenco(testo: Text(verbatim: t.titoloVerdetto + ". ").bold() + Text(verbatim: t.sottotitoloVerdetto))
                    PuntoElenco(testo: Text(verbatim: t.tenuta))
                }
            }
        }
    }

    private var sottotitolo: String {
        var parti = ["Orizzonte di \(t.periodo)"]
        parti.append(e.versamento > 0 ? "versamenti futuri \(CifreDoc.euro(e.versamento)) \(e.frequenza.nome.lowercased()), uguali per le due strade" : "nessun versamento futuro")
        parti.append("situazione al \(CifreDoc.data(t.data))")
        return parti.joined(separator: " · ")
    }

    /// Con molti anni l'asse mostra un anno ogni tanto.
    private func etichettaAnno(_ anno: Int) -> String {
        let passo = e.anni <= 12 ? 1 : (e.anni <= 25 ? 5 : 10)
        return anno % passo == 0 || anno == e.anni ? "\(anno)° anno" : ""
    }

    private var righeUscita: [RigaDoc] {
        var righe: [RigaDoc] = []
        func riga(_ voce: String, _ importo: String, _ come: String, forte: Bool = false, colore: Color? = nil) {
            let font = forte ? T.pTabellaForte : T.pTabella
            var c = CellaDoc(come, font: T.pTabellaNota)
            c.righe = 2
            righe.append(RigaDoc(celle: [CellaDoc(voce, font: font), CellaDoc(importo, colore: colore, font: font), c],
                                 altezza: 17, sfondo: forte ? C.riquadro : .clear, filetto: forte ? C.filettoForte : nil, spessore: forte ? 0.8 : 0.5))
        }
        let f = e.uscita
        riga("Valore di \(t.a.nome) oggi", CifreDoc.euroCentesimi(e.valoreOggi), "controvalore dichiarato" + (t.a.dataValore.map { " al \(CifreDoc.dataBreve($0))" } ?? ""))
        if e.penaleUscita > 0.005 { riga("Penale di riscatto", CifreDoc.togli(e.penaleUscita), "dalle condizioni del contratto", colore: C.negativo) }
        if e.bolloUscita > 0.005 { riga("Bollo maturato", CifreDoc.togli(e.bolloUscita), "0,20% l'anno, si paga al riscatto", colore: C.negativo) }
        if let r = e.riscattoPrevidenza {
            riga("Imposta sul riscatto", "\(CifreDoc.meno) " + CifreDoc.euroCentesimi(r.imposta), "23% su \(CifreDoc.euroCentesimi(r.imponibile)) di contributi dedotti", colore: C.negativo)
        } else if e.impostaUscita > 0.005, let f {
            riga("Imposta sul guadagno", "\(CifreDoc.meno) " + CifreDoc.euroCentesimi(e.impostaUscita),
                 "\(CifreDoc.percento(f.aliquota, decimali: 2)) su \(CifreDoc.euroCentesimi(f.imponibile)) (valore − penale − versato \(CifreDoc.euro(f.versato)))", colore: C.negativo)
        }
        riga("Netto reinvestito", CifreDoc.euroCentesimi(e.reinvestito), "quanto passa al nuovo prodotto", forte: true)
        if e.ingressoCambio > 0.005 {
            riga("Costo d'ingresso di \(t.b.nome)", CifreDoc.togli(e.ingressoCambio), "\(CifreDoc.condizione(e.cambio.costoIngresso)) del capitale", colore: C.negativo)
            riga("Investito nel nuovo prodotto", CifreDoc.euroCentesimi(e.investitoCambio), "capitale che lavora dal primo giorno", forte: true)
        }
        return righe
    }

    private func scheda(_ l: LatoSostituzione, titolo: String) -> some View {
        let p = l.posizione
        return VStack(alignment: .leading, spacing: 5) {
            OcchielloDoc(testo: titolo, font: T.pOcchiello)
            EtichettaCanale(canale: p.canale)
            Text(verbatim: p.nome).font(T.pSottosezione).foregroundColor(C.titolo).lineLimit(1)
            Text(verbatim: [p.tipologia, p.emittente].filter { !$0.isEmpty }.joined(separator: " · ")).font(T.pTabellaNota).foregroundColor(C.tenue).lineLimit(1)
            VStack(alignment: .leading, spacing: 2) {
                dato("Rendimento ipotizzato", "\(CifreDoc.percento(l.rendimento)) lordo")
                dato("Costi annui", "\(CifreDoc.percento(l.costoAnnuo, decimali: 2))" + (l.costoIngresso > 0 ? " · ingresso \(CifreDoc.condizione(l.costoIngresso))" : ""))
                dato("Imposta sul guadagno", "\(CifreDoc.percento(l.aliquota, decimali: 2)) · \(p.regime.nome.lowercased())")
                dato("Rischio", p.sri.map { "\($0) su 7" } ?? "—")
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroDoc(C.riquadro, raggio: D.raggioPiccolo)
    }

    private func dato(_ etichetta: String, _ valore: String) -> some View {
        HStack {
            Text(verbatim: etichetta).font(T.pTabellaNota).foregroundColor(C.tenue)
            Spacer()
            Text(verbatim: valore).font(T.pTabella).foregroundColor(C.testo).lineLimit(1)
        }
    }
}

// MARK: - Pagina 2: anno per anno, scenari, costi

private struct PaginaAnni: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSostituzione

    private var e: EsitoSostituzione { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Anno per anno, scenario atteso",
                             testo: Text(verbatim: "Valore a fine anno e netto incassabile chiudendo in quell'anno. Le due strade ricevono gli stessi versamenti futuri."))
            TestataCanali(resto: t.a, cambio: t.b, pesi: (0.9, 2.3, 2.3))
            TabellaDoc(larghezza: larghezza, colonne: [
                ColonnaDoc(titolo: "Anno", peso: 0.9, destra: false),
                ColonnaDoc(titolo: t.nomeResto, sottotitolo: "valore"), ColonnaDoc(titolo: "", sottotitolo: "netto", peso: 1.1),
                ColonnaDoc(titolo: t.nomeCambio, sottotitolo: "valore"), ColonnaDoc(titolo: "", sottotitolo: "netto", peso: 1.1),
                ColonnaDoc(titolo: "Differenza", sottotitolo: "netti", peso: 1.1),
            ], righe: righeAnni, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
            SezioneProspetto(titolo: "Se i mercati vanno diversamente",
                             testo: Text(verbatim: "Netto dopo \(t.periodo) con \(Formati.numeroFormatter.string(from: NSNumber(value: IpotesiCalcolo.ampiezzaScenari)) ?? "2") punti di rendimento in meno o in più per entrambe le strade. \(t.tenuta)"))
            TabellaDoc(larghezza: larghezza, colonne: [
                ColonnaDoc(titolo: "Scenario", peso: 1.2, destra: false), ColonnaDoc(titolo: "Rendimenti", sottotitolo: "\(t.nomeResto.lowercased()) · \(t.nomeCambio.lowercased())", peso: 1.6),
                ColonnaDoc(titolo: t.nomeResto, sottotitolo: "netto"), ColonnaDoc(titolo: t.nomeCambio, sottotitolo: "netto"),
                ColonnaDoc(titolo: "Differenza", peso: 1.1),
            ], righe: e.scenari.map { s in
                let colore = s.scarto < 0 ? C.sfavorevole : (s.scarto > 0 ? C.favorevole : C.intermedio)
                return RigaDoc(celle: [CellaDoc("■ \(s.nome)", colore: colore, font: T.pTabellaForte),
                                       CellaDoc("\(CifreDoc.percento(e.resto.rendimento + s.scarto)) · \(CifreDoc.percento(e.cambio.rendimento + s.scarto))", font: T.pTabella),
                                       CellaDoc(CifreDoc.euro(s.nettoResto), font: T.pTabella), CellaDoc(CifreDoc.euro(s.nettoCambio), font: T.pTabella),
                                       CellaDoc(CifreDoc.euroSegno(s.differenza), colore: s.differenza >= 0 ? C.positivo : C.negativo, font: T.pTabellaForte)],
                               altezza: 15)
            }, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
            SezioneProspetto(titolo: "I costi delle due strade",
                             testo: Text(verbatim: "Costo annuo complessivo: gestione, trattenuto sul rendimento e bollo, già tolti dal valore ogni anno."))
            TestataCanali(resto: t.a, cambio: t.b, pesi: (2.6, 1.5, 1.5))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Voce", peso: 2.6, destra: false),
                                                       ColonnaDoc(titolo: t.nomeResto, peso: 1.5), ColonnaDoc(titolo: t.nomeCambio, peso: 1.5)],
                       righe: righeCosti, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
        }
    }

    private var righeAnni: [RigaDoc] {
        // Con molti anni si mostra un anno ogni tanto: sempre il primo, il pareggio e l'ultimo
        let passo = e.anni <= 20 ? 1 : 5
        let mostrati = e.serie.filter { $0.anno <= 1 || $0.anno % passo == 0 || $0.anno == e.anni || $0.anno == e.pareggio }
        return mostrati.map { a in
            let pareggio = a.anno == e.pareggio
            return RigaDoc(celle: [CellaDoc(a.anno == 0 ? "oggi" : "\(a.anno)° anno" + (pareggio ? " ◆" : ""), font: pareggio ? T.pTabellaForte : T.pTabella),
                                   CellaDoc(CifreDoc.euro(a.lordoResto), colore: C.tenue, font: T.pTabella),
                                   CellaDoc(CifreDoc.euro(a.nettoResto), font: T.pTabellaForte),
                                   CellaDoc(CifreDoc.euro(a.lordoCambio), colore: C.tenue, font: T.pTabella),
                                   CellaDoc(CifreDoc.euro(a.nettoCambio), font: T.pTabellaForte),
                                   CellaDoc(CifreDoc.euroSegno(a.differenza), colore: a.differenza >= 0 ? C.positivo : C.negativo, font: T.pTabella)],
                           altezza: 13, sfondo: pareggio ? C.evidenza : .clear)
        }
    }

    private var righeCosti: [RigaDoc] {
        func riga(_ voce: String, _ a: String, _ b: String) -> RigaDoc {
            RigaDoc(celle: [CellaDoc(voce, font: T.pTabella), CellaDoc(a, font: T.pTabella), CellaDoc(b, font: T.pTabella)], altezza: 14)
        }
        let r = e.resto, c = e.cambio
        return [
            riga("Costo d'ingresso", e.sostituzione ? "già pagato" : CifreDoc.condizione(r.costoIngresso), CifreDoc.condizione(c.costoIngresso)),
            riga("Costo annuo di gestione", r.posizione.costoAnnuo.map { CifreDoc.condizione($0) } ?? "—", c.posizione.costoAnnuo.map { CifreDoc.condizione($0) } ?? "—"),
            riga("Trattenuto sul rendimento", r.posizione.trattenuto.map { CifreDoc.condizione($0) } ?? "—", c.posizione.trattenuto.map { CifreDoc.condizione($0) } ?? "—"),
            riga("Bollo 0,20%", r.bollo ? "sì" : "no", c.bollo ? "sì" : "no"),
            riga("Costo annuo complessivo", CifreDoc.percento(r.costoAnnuo, decimali: 2), CifreDoc.percento(c.costoAnnuo, decimali: 2)),
            riga("Costi del primo anno", CifreDoc.euro(r.costiPrimoAnno), CifreDoc.euro(c.costiPrimoAnno)),
            riga("Costi in \(t.periodo)", CifreDoc.euro(r.costiPeriodo), CifreDoc.euro(c.costiPeriodo)),
        ]
    }
}

// MARK: - Pagina 3: caratteristiche, cosa cambia, metodo

private struct PaginaCaratteristiche: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiSostituzione

    private var e: EsitoSostituzione { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Le caratteristiche a confronto")
            TestataCanali(resto: t.a, cambio: t.b, pesi: (1.3, 2.2, 2.2))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "", peso: 1.3, destra: false),
                                                       ColonnaDoc(titolo: t.a.nome, peso: 2.2, destra: false),
                                                       ColonnaDoc(titolo: t.b.nome, peso: 2.2, destra: false)],
                       righe: caratteristiche, fontTesta: T.pTabellaForte, altezzaTesta: 12, margine: 4)
            HStack(alignment: .top, spacing: 14) {
                elenco(e.sostituzione ? "Cosa si lascia o si paga cambiando" : "A favore di \(t.a.nome)", t.siPerde, colore: C.negativo)
                elenco(e.sostituzione ? "Cosa si guadagna cambiando" : "A favore di \(t.b.nome)", t.siGuadagna, colore: C.positivo)
            }
            SezioneProspetto(titolo: "Ipotesi e metodo")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array((e.note + metodo).enumerated()), id: \.offset) { _, n in PuntoElenco(testo: Text(verbatim: n)) }
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold()
             + Text(verbatim: "Simulazione illustrativa: i rendimenti sono ipotesi e non sono garantiti; le imposte seguono le regole in vigore alla data del prospetto. Prima di riscattare verificare con la compagnia il valore di riscatto effettivo, le penali e i tempi di liquidazione. Fanno fede il KID e la documentazione contrattuale dei prodotti."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }

    private var metodo: [String] {
        ["Calcolo mese per mese: ogni mese il capitale cresce del rendimento ipotizzato e paga il costo annuo pro quota; i versamenti entrano al netto del costo d'ingresso.",
         "Netto incassabile: valore − penale di riscatto (se il prodotto ha le condizioni del contratto) − imposta sul guadagno (valore − penale − versato) con l'aliquota del regime; per la previdenza l'aliquota della prestazione sui contributi dedotti.",
         "Per chi resta il guadagno si misura sul versato di sempre; per chi cambia sul capitale reinvestito, perché le imposte sul guadagno passato sono già pagate all'uscita."]
    }

    private var caratteristiche: [RigaDoc] {
        func riga(_ voce: String, _ a: String, _ b: String, righe: Int = 1) -> RigaDoc {
            var ca = CellaDoc(a.isEmpty ? "—" : a, font: T.pTabella), cb = CellaDoc(b.isEmpty ? "—" : b, font: T.pTabella)
            ca.righe = righe
            cb.righe = righe
            return RigaDoc(celle: [CellaDoc(voce, colore: C.tenue, font: T.pTabella), ca, cb], altezza: righe > 1 ? 24 : 14)
        }
        let a = t.a, b = t.b
        func liquidita(_ p: Posizione, _ l: LatoSostituzione) -> String {
            guard let c = l.prodotto?.condizioni else { return p.regime == .previdenza ? "anticipazioni e riscatti secondo la legge" : "non indicata" }
            return c.penali.isEmpty ? "riscatto dopo \(c.mesiBloccoRiscatto) mesi, senza penali"
                : "riscatto dopo \(c.mesiBloccoRiscatto) mesi; penali \(c.penali.map { CifreDoc.penale($0) }.joined(separator: ", ")), poi nessuna"
        }
        return [
            riga("Tipologia", a.tipologia, b.tipologia, righe: 2),
            riga("Emittente", a.emittente, b.emittente),
            riga("Stato", a.stato.nome, b.stato == .proposta ? "Proposta · \(b.esito?.nome.lowercased() ?? "bozza")" : b.stato.nome),
            riga("Rendimento ipotizzato", CifreDoc.percento(e.resto.rendimento) + " lordo", CifreDoc.percento(e.cambio.rendimento) + " lordo"),
            riga("Rischio (SRI)", a.sri.map { "\($0) su 7" } ?? "", b.sri.map { "\($0) su 7" } ?? ""),
            riga("Regime fiscale", "\(a.regime.nome) · \(CifreDoc.percento(e.resto.aliquota, decimali: 2))", "\(b.regime.nome) · \(CifreDoc.percento(e.cambio.aliquota, decimali: 2))"),
            riga("Garanzie", a.garanzie, b.garanzie, righe: 2),
            riga("Liquidabilità", liquidita(a, e.resto), liquidita(b, e.cambio), righe: 2),
            riga("Scadenza", TestiResoconto.quando(a.scadenza), TestiResoconto.quando(b.scadenza)),
        ]
    }

    private func elenco(_ titolo: String, _ punti: [String], colore: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: titolo).font(T.pSottosezione).foregroundColor(colore)
            if punti.isEmpty {
                Text(verbatim: "Nessuna differenza rilevante.").font(T.pCorpo).foregroundColor(C.tenue)
            }
            ForEach(Array(punti.enumerated()), id: \.offset) { _, p in PuntoElenco(testo: Text(verbatim: p)) }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .riquadroDoc(C.riquadro, raggio: D.raggioPiccolo)
    }
}
