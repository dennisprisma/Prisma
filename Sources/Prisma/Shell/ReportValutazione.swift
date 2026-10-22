import SwiftUI

private typealias C = Colori.Documento
private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il report di una valutazione d'investimento: A4 orizzontale, una slide per messaggio,
/// da lasciare al cliente. Ricalca il report di Denis su Orizzonte Valore (ottobre 2026).
enum ReportValutazione {
    static func pagine(_ t: TestiValutazione) -> [AnyView] {
        var slide: [AnyView] = [AnyView(SlideCopertina(t: t)), AnyView(SlideProposta(t: t))]
        if t.fondo?.storico.isEmpty == false || t.gestione?.storico.isEmpty == false {
            slide.append(AnyView(SlidePartenza(t: t)))
        }
        slide += [AnyView(SlideIpotesi(t: t)), AnyView(SlideIncassi(t: t)), AnyView(SlideAndamento(t: t)),
                  AnyView(SlidePrimoRiscatto(t: t))]
        if !t.c.penali.isEmpty { slide.append(AnyView(SlidePenali(t: t))) }
        slide.append(AnyView(SlideCosti(t: t)))
        if !t.c.garantito.isEmpty || !t.c.nonGarantito.isEmpty { slide.append(AnyView(SlideGaranzie(t: t))) }
        if !t.c.scenariKID.isEmpty { slide.append(AnyView(SlideKID(t: t))) }
        slide += [AnyView(SlideSintesi(t: t)), AnyView(SlideAppendice(t: t))]
        return slide.enumerated().map { i, s in
            i == 0 ? s : AnyView(CorniceSlide(numero: i + 1) { s })
        }
    }
}

/// Margini e numero di pagina di una slide interna.
private struct CorniceSlide<Contenuto: View>: View {
    let numero: Int
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
        FoglioDocumento(formato: D.report) {
            VStack(alignment: .leading, spacing: 0) {
                contenuto()
                Spacer(minLength: 0)
                NumeroPaginaDoc(numero: numero)
            }
            .padding(EdgeInsets(top: 30, leading: D.margineReport, bottom: 18, trailing: D.margineReport))
        }
    }
}

private var larghezzaUtile: CGFloat { D.report.width - D.margineReport * 2 }

// MARK: - 1. Copertina

private struct SlideCopertina: View {
    let t: TestiValutazione

    var body: some View {
        FoglioDocumento(formato: D.report, sfondo: C.notte) {
            HStack(alignment: .center, spacing: 40) {
                VStack(alignment: .leading, spacing: 0) {
                    OcchielloDoc(testo: "Proposta di investimento", colore: C.notteEtichetta)
                    Text(verbatim: t.prodotto.nome).font(T.copertinaTitolo).foregroundColor(.white)
                        .lineLimit(3).minimumScaleFactor(0.7).padding(.top, 18)
                    Text(verbatim: t.sottotitoloCopertina).font(T.copertinaSottotitolo).foregroundColor(C.notteTesto).padding(.top, 18)
                    Text(verbatim: t.v.intestatari).font(T.copertinaNomi).foregroundColor(.white).padding(.top, 22)
                    HStack(spacing: 7) {
                        ForEach(TipoScenario.allCases) { s in Circle().fill(C.scenario(s)).frame(width: 10, height: 10) }
                    }
                    .padding(.top, 26)
                    Text(verbatim: TestiValutazione.consulente).font(T.copertinaConsulente).foregroundColor(.white).padding(.top, 14)
                    Text(verbatim: t.ruoloConsulente).font(T.copertinaRuolo).foregroundColor(C.notteTesto).padding(.top, 2)
                    Text(verbatim: CifreDoc.data(t.v.data)).font(T.copertinaRuolo).foregroundColor(C.notteTesto).padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 12) {
                    riquadro("Premio unico", [CifreDoc.euro(t.v.premio)])
                    if !t.c.componenti.isEmpty {
                        riquadro("Combinazione", t.c.componenti.map { "\(CifreDoc.condizione($0.quota)) \($0.tipo.nome)" })
                    }
                    riquadro("Riscatto", [t.riscattoPossibile])
                }
                .frame(width: 250)
            }
            .padding(.horizontal, 46)
            .frame(maxHeight: .infinity)
        }
    }

    private func riquadro(_ titolo: String, _ righe: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            OcchielloDoc(testo: titolo, font: T.copertinaEtichetta, colore: C.notteEtichetta)
            ForEach(righe, id: \.self) { Text(verbatim: $0).font(T.copertinaValore).foregroundColor(.white) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroDoc(C.notteRiquadro)
    }
}

// MARK: - 2. La proposta

private struct SlideProposta: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaSlide(occhiello: "La proposta", titolo: t.titoloProposta, sottotitolo: t.sottotitoloProposta)
            HStack(spacing: 10) {
                cifra("Premio versato", CifreDoc.euro(t.e.premio), C.titolo)
                Text(verbatim: "→").font(T.numeroMedio).foregroundColor(C.tenue)
                cifra(t.etichettaIngresso, CifreDoc.togli(t.e.ingresso), C.negativo)
                Text(verbatim: "→").font(T.numeroMedio).foregroundColor(C.tenue)
                cifra("Capitale investito", CifreDoc.euro(t.e.capitale), C.titolo)
            }
            .padding(.top, 4)
            HStack(spacing: 0) {
                ForEach(t.c.componenti) { p in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: CifreDoc.euro(t.e.partiIniziali[p.id] ?? 0)).font(T.numeroMedio)
                        Text(verbatim: CifreDoc.condizione(p.quota)).font(T.corpoForte)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(width: larghezzaUtile * CGFloat(p.quota / max(quotaTotale, 0.01)), height: 50, alignment: .leading)
                    .background(C.parte(p.tipo))
                }
            }
            HStack(alignment: .top, spacing: 30) {
                ForEach(t.c.componenti) { p in
                    HStack(alignment: .top, spacing: 9) {
                        Circle().fill(C.parte(p.tipo)).frame(width: 10, height: 10).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: p.nomeCompleto).font(T.titoloRiquadro).foregroundColor(C.titolo)
                            Text(verbatim: p.descrizione).font(T.corpo).foregroundColor(C.testo)
                                .lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var quotaTotale: Double { t.c.componenti.reduce(0) { $0 + $1.quota } }

    private func cifra(_ etichetta: String, _ valore: String, _ colore: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: etichetta).font(T.piccolo).foregroundColor(C.tenue).lineLimit(1).minimumScaleFactor(0.8)
            Text(verbatim: valore).font(T.numeroGrande).foregroundColor(colore)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroDoc()
    }
}

// MARK: - 3. I numeri di partenza

private struct SlidePartenza: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestaSlide(occhiello: "I numeri di partenza", titolo: "Da dove partiamo: i rendimenti degli ultimi anni",
                       sottotitolo: t.sottotitoloPartenza)
            HStack(alignment: .top, spacing: 30) {
                if let f = t.fondo, !f.storico.isEmpty {
                    VStack(spacing: 12) {
                        Text(verbatim: f.nomeCompleto).font(T.titoloRiquadro).foregroundColor(C.titolo)
                        HStack(spacing: 8) {
                            if let d = t.fondoDalLancio { cifra(CifreDoc.variazione(d), "dal lancio") }
                            if let d = t.fondoDaInizioAnno { cifra(CifreDoc.variazione(d), "da inizio \(annoUltimo(f))") }
                            if let q = t.fondoUltimaQuota, let valore = q.valore {
                                cifra("€ " + quota(valore), "valore quota al \(q.etichetta)")
                            }
                        }
                        if !t.v.notaScenarioCentrale.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: t.titoloNotaCentrale).font(T.titoloRiquadro).foregroundColor(C.evidenzaTitolo)
                                Text(verbatim: t.v.notaScenarioCentrale).font(T.corpo).foregroundColor(C.testo)
                                    .lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .riquadroDoc(C.evidenza)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                if let g = t.gestione, !g.storico.isEmpty {
                    VStack(spacing: 10) {
                        Text(verbatim: "Gestione separata: rendimento lordo annuo").font(T.titoloRiquadro).foregroundColor(C.titolo)
                        GraficoBarreDoc(punti: g.storico.compactMap { p in p.valore.map { (p.etichetta, $0) } })
                            .frame(height: 260)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func annoUltimo(_ f: ComponenteContratto) -> String {
        let etichetta = f.storico.last { $0.valore != nil }?.etichetta ?? ""
        return String(etichetta.suffix(4))
    }

    private func quota(_ v: Double) -> String {
        let n = NumberFormatter()
        n.locale = Formati.localeImporti
        n.numberStyle = .decimal
        n.minimumFractionDigits = 3
        n.maximumFractionDigits = 3
        return n.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func cifra(_ valore: String, _ nota: String) -> some View {
        VStack(spacing: 6) {
            Text(verbatim: valore).font(T.numeroMedio).foregroundColor(C.titolo).lineLimit(1).minimumScaleFactor(0.7)
            Text(verbatim: nota).font(T.piccolo).foregroundColor(C.tenue).multilineTextAlignment(.center)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 84)
        .riquadroDoc()
    }
}

// MARK: - 4. Le ipotesi

private struct SlideIpotesi: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaSlide(occhiello: "Le ipotesi", titolo: "Tre possibili andamenti dei mercati",
                       sottotitolo: t.f("Si tratta di ipotesi: servono a comprendere cosa potrebbe accadere al vostro capitale se i mercati dovessero andare bene, nella media oppure male.",
                                        "Si tratta di ipotesi: servono a comprendere cosa potrebbe accadere al tuo capitale se i mercati dovessero andare bene, nella media oppure male."))
            HStack(alignment: .top, spacing: 12) {
                ForEach(TipoScenario.allCases) { s in scheda(s) }
            }
        }
    }

    private func scheda(_ s: TipoScenario) -> some View {
        let colore = C.scenario(s)
        let anno = t.anni.count > 1 ? t.anni[1] : t.anni.first ?? 2
        return VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: s.nome).font(T.scenarioTitolo).foregroundColor(colore)
            Text(verbatim: t.rendimentoTitolo(s)).font(T.scenarioRendimento).foregroundColor(colore).lineLimit(1).minimumScaleFactor(0.6)
            if t.fondo != nil {
                Text(verbatim: "Fondo Interno, al netto dei suoi costi").font(T.piccolo).foregroundColor(C.tenue)
            }
            Text(verbatim: t.v.scenario(s).racconto).font(T.corpo).foregroundColor(C.testo)
                .lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 70, alignment: .top)
            Rectangle().fill(Color.white.opacity(0.9)).frame(height: 1)
            if let g = t.gestioneScenario(s) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "Gestione separata").font(T.piccolo).foregroundColor(C.tenue)
                    Text(verbatim: g).font(T.corpoForte).foregroundColor(C.titolo)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Netto con riscatto al \(t.etichettaMese(anno))").font(T.piccolo).foregroundColor(C.tenue)
                Text(verbatim: CifreDoc.euro(t.netto(s, anno))).font(T.numeroPiccolo).foregroundColor(colore)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .riquadroDoc(C.scenarioFondo(s))
    }
}

// MARK: - 5. Quanto si incassa

private struct SlideIncassi: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaSlide(occhiello: t.f("Quanto potreste incassare", "Quanto potresti incassare"),
                       titolo: t.f("Quanto potreste incassare, anno per anno", "Quanto potresti incassare, anno per anno"),
                       sottotitolo: t.sottotitoloIncassi)
            TabellaIncassi(t: t, larghezza: larghezzaUtile, rigaScenario: 44, fontValore: T.numeroMedio, fontNota: T.piccolo,
                           fontTesta: T.corpoForte, fontEtichetta: T.titoloRiquadro)
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(t.anni.prefix(2)), id: \.self) { a in
                    nota(Text("Al \(t.etichettaMese(a)): ").bold() + Text(verbatim: t.forbice(a)))
                }
                if !t.c.penali.isEmpty {
                    nota(Text("Dal \(t.etichettaMese(t.c.annoSenzaPenali)): ").bold() + Text(verbatim: t.fraseSenzaPenali))
                }
            }
        }
    }

    private func nota(_ testo: Text) -> some View {
        testo.font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .riquadroDoc()
    }
}

/// La tabella degli incassi netti per anno di riscatto, usata dal report e dal prospetto.
struct TabellaIncassi: View {
    let t: TestiValutazione
    let larghezza: CGFloat
    var rigaScenario: CGFloat
    var fontValore: Font
    var fontNota: Font
    var fontTesta: Font
    var fontEtichetta: Font

    var body: some View {
        let anni = t.anni
        var colonne = [ColonnaDoc(titolo: "", peso: 1.7, destra: false),
                       ColonnaDoc(titolo: "1° anno", sottotitolo: "mesi 1–\(t.c.mesiBloccoRiscatto)", peso: 0.95)]
        colonne += anni.map { ColonnaDoc(titolo: "\($0)° anno", sottotitolo: "dal \(($0 - 1) * 12 + 1)° mese", peso: 1.05) }
        var righe = [RigaDoc(celle: [CellaDoc("Penale di riscatto", colore: C.tenue, font: fontNota), CellaDoc("—", colore: C.tenue, font: fontNota)]
                                + anni.map { a in
                                    let p = t.c.penale(anno: a)
                                    return CellaDoc(p > 0 ? CifreDoc.penale(p) : "nessuna", colore: C.tenue, font: fontNota)
                                },
                             altezza: rigaScenario * 0.5, sfondo: C.riquadro)]
        for s in TipoScenario.allCases {
            let colore = C.scenario(s)
            var cellaNome = CellaDoc("■ \(s.nome)", sotto: t.fondo.map { "Fondo \(CifreDoc.variazione(t.v.scenario(s).rendimento($0), decimali: 0)) l'anno" } ?? "",
                                     colore: colore, font: fontEtichetta)
            cellaNome.fontSotto = fontNota
            var celle = [cellaNome, CellaDoc(s == .intermedio ? "riscatto bloccato" : "", colore: C.tenue, font: fontNota)]
            for a in anni {
                let r = t.e.scenario(s)?.riscatto(anno: a)
                var cella = CellaDoc(CifreDoc.euro(r?.netto ?? 0), sotto: CifreDoc.variazione(r?.variazione ?? 0), colore: colore, font: fontValore)
                cella.fontSotto = fontNota
                celle.append(cella)
            }
            righe.append(RigaDoc(celle: celle, altezza: rigaScenario))
        }
        return TabellaDoc(larghezza: larghezza, colonne: colonne, righe: righe, fontTesta: fontTesta, fontTestaSotto: fontNota,
                          altezzaTesta: rigaScenario * 0.62, colonneEvidenziate: [1])
    }
}

// MARK: - 6. Andamento

private struct SlideAndamento: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TestaSlide(occhiello: "Come evolve nel tempo", titolo: t.titoloAndamento)
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 8) {
                    GraficoScenariDoc(linee: linee, etichetteAsse: t.anni.map { "inizio \($0)° anno" }, premio: t.v.premio)
                        .frame(height: 380)
                    HStack(spacing: 40) {
                        ForEach(TipoScenario.allCases) { s in
                            HStack(spacing: 6) {
                                Circle().fill(C.scenario(s)).frame(width: 9, height: 9)
                                Text(verbatim: s.nome).font(T.piccolo).foregroundColor(C.testo)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 10) {
                    ForEach(TipoScenario.allCases) { s in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(verbatim: s.nome).font(T.titoloRiquadro).foregroundColor(C.scenario(s))
                            Text(verbatim: t.raccontoAndamento(s)).font(T.piccolo).foregroundColor(C.testo)
                                .lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                        .riquadroDoc(C.scenarioFondo(s))
                    }
                }
                .frame(width: 210)
            }
        }
    }

    private var linee: [LineaScenario] {
        TipoScenario.allCases.map { s in
            LineaScenario(tipo: s, punti: (t.e.scenario(s)?.riscatti ?? []).enumerated().map { ($0.offset, $0.element.netto) })
        }
    }
}

// MARK: - 7. Il primo riscatto

private struct SlidePrimoRiscatto: View {
    let t: TestiValutazione

    var body: some View {
        let anno = t.anni.first ?? 2
        return VStack(alignment: .leading, spacing: 12) {
            TestaSlide(occhiello: "Riscatto all'inizio del \(anno)° anno", titolo: t.titoloPrimoRiscatto, sottotitolo: t.sottotitoloPrimoRiscatto)
            HStack(alignment: .top, spacing: 36) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(voci.enumerated()), id: \.offset) { i, v in
                        HStack {
                            Text(verbatim: v.0).font(i == voci.count - 1 || v.2 ? T.corpoForte : T.corpo)
                            Spacer()
                            Text(verbatim: v.1).font(i == voci.count - 1 || v.2 ? T.corpoForte : T.corpo)
                                .foregroundColor(v.3)
                        }
                        .foregroundColor(i == voci.count - 1 ? C.intermedio : C.titolo)
                        .padding(.horizontal, 4)
                        .frame(height: 24)
                        .background(i == voci.count - 1 ? C.evidenza : Color.clear)
                        .overlay(Rectangle().fill(i == voci.count - 1 ? C.filettoForte : C.filetto).frame(height: i == voci.count - 1 ? 0.9 : 0.6), alignment: .bottom)
                    }
                    Text(verbatim: "Scenario intermedio. Rendimento dei mercati e costi di gestione sono stime.")
                        .font(T.piccolo).foregroundColor(C.tenue).padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 9) {
                    OcchielloDoc(testo: "Importo netto al \(t.etichettaMese(anno))")
                    ForEach(TipoScenario.allCases) { s in
                        let r = t.e.scenario(s)?.riscatto(anno: anno)
                        HStack {
                            Text(verbatim: s.nome).font(T.corpoForte).foregroundColor(C.titolo)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(verbatim: CifreDoc.euro(r?.netto ?? 0)).font(T.numeroMedio).foregroundColor(C.scenario(s))
                                Text(verbatim: "\(CifreDoc.variazione(r?.variazione ?? 0)) sul versato").font(T.piccolo).foregroundColor(C.tenue)
                            }
                        }
                        .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                        .riquadroDoc(C.scenarioFondo(s))
                    }
                    if !t.consiglio.isEmpty {
                        (Text("Il consiglio: ").bold() + Text(verbatim: t.consiglio))
                            .font(T.corpo).foregroundColor(C.titolo).lineSpacing(1.5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .riquadroDoc()
                    }
                }
                .frame(width: 300)
            }
        }
    }

    /// Etichetta, importo, in grassetto, colore dell'importo.
    private var voci: [(String, String, Bool, Color)] {
        guard let i = t.intermedio else { return [] }
        return MotoreValutazione.cascata(t.e, i).map { v in
            switch v.genere {
            case .partenza: return (v.etichetta, CifreDoc.euro(v.importo), false, C.titolo)
            case .subtotale: return (v.etichetta, CifreDoc.euro(v.importo), true, C.titolo)
            case .arrivo: return ("Importo netto incassato", CifreDoc.euro(v.importo), true, C.intermedio)
            case .piu: return (v.etichetta == "Rendimento dei mercati" ? "Rendimento dei mercati (stima)" : v.etichetta, CifreDoc.euroSegno(v.importo), false, C.positivo)
            case .meno:
                let nome = v.etichetta == "Costi di gestione" ? "Costi di gestione (stima)"
                    : v.etichetta.hasPrefix("Penale") ? "Penale di riscatto \(v.etichetta.replacingOccurrences(of: "Penale ", with: ""))" : v.etichetta
                return (nome, CifreDoc.togli(v.importo), false, C.negativo)
            }
        }
    }
}

// MARK: - 8. Le penali

private struct SlidePenali: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestaSlide(occhiello: "Le penali di riscatto", titolo: "Penali di riscatto e flessibilità", sottotitolo: t.sottotitoloPenali)
            HStack(spacing: 4) {
                fascia("1° anno", "riscatto bloccato", "mesi 1–\(t.c.mesiBloccoRiscatto)", C.bloccato, C.titolo)
                ForEach(Array(t.c.penali.enumerated()), id: \.offset) { i, p in
                    fascia("\(i + 2)° anno", "penale \(CifreDoc.penale(p))", "mesi \((i + 1) * 12 + 1)–\((i + 2) * 12)",
                           tono(i), i < 2 ? Color.white : C.titolo)
                }
                fascia("dal \(t.c.annoSenzaPenali)° anno", "nessuna penale", "dal \((t.c.annoSenzaPenali - 1) * 12 + 1)° mese", C.favorevole, .white)
            }
            HStack(alignment: .top, spacing: 12) {
                scheda("Aspettare conviene", t.aspettareConviene)
                scheda(t.f("Se serve solo una parte", "Se serve solo una parte"), t.c.riscattoParziale)
                scheda(t.f("Se cambiate idea subito", "Se cambi idea subito"), t.c.recesso)
            }
        }
    }

    private func tono(_ i: Int) -> Color {
        [C.penaleForte, C.penaleMedia, C.penaleLieve][min(i, 2)]
    }

    private func fascia(_ titolo: String, _ testo: String, _ mesi: String, _ fondo: Color, _ inchiostro: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: titolo).font(T.titoloRiquadro)
                Text(verbatim: testo).font(T.corpo)
            }
            .foregroundColor(inchiostro)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .background(fondo)
            Text(verbatim: mesi).font(T.piccolo).foregroundColor(C.tenue).padding(.leading, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private func scheda(_ titolo: String, _ testo: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: titolo).font(T.titoloRiquadro).foregroundColor(C.titolo)
            Text(verbatim: testo).font(T.corpo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .riquadroDoc()
    }
}

// MARK: - 9. Costi

private struct SlideCosti: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaSlide(occhiello: "Costi e trattenute", titolo: t.titoloCosti,
                       sottotitolo: t.f("Scenario intermedio. I costi sono già compresi negli importi che avete visto: non vanno sottratti di nuovo.",
                                        "Scenario intermedio. I costi sono già compresi negli importi che hai visto: non vanno sottratti di nuovo."))
            TabellaCosti(t: t, larghezza: larghezzaUtile, riga: 26, font: T.corpo, fontForte: T.corpoForte, fontNota: T.minimo)
            Text(verbatim: t.notaCosti).font(T.piccolo).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Costi e trattenute anno per anno (scenario intermedio), per il report e il prospetto.
struct TabellaCosti: View {
    let t: TestiValutazione
    let larghezza: CGFloat
    let riga: CGFloat
    let font: Font
    let fontForte: Font
    let fontNota: Font

    var body: some View {
        let costi = t.intermedio?.costi ?? []
        let n = costi.count
        var colonne = [ColonnaDoc(titolo: "Costi correnti", peso: 3.4, destra: false)]
        colonne += costi.map { ColonnaDoc(titolo: "\($0.anno)° anno") }
        colonne.append(ColonnaDoc(titolo: "Totale \(n) anni", peso: 1.2))
        var righe: [RigaDoc] = []
        func voce(_ nome: String, _ nota: String, _ valori: [Double], unaVolta: Bool = false) {
            var nomeCella = CellaDoc(nome, sotto: nota, colore: C.testo, font: font)
            nomeCella.fontSotto = fontNota
            var celle = [nomeCella]
            celle += valori.map { CellaDoc($0 > 0.5 ? CifreDoc.euro($0) : "—", colore: C.testo, font: font) }
            celle.append(CellaDoc(CifreDoc.euro(valori.reduce(0, +)), colore: C.titolo, font: fontForte))
            righe.append(RigaDoc(celle: celle, altezza: riga))
        }
        let c = t.c
        voce("Costo di ingresso", "\(CifreDoc.condizione(c.costoIngresso)) del premio" + (c.costoIngressoMassimo.map { ", massimo \(CifreDoc.euro($0))" } ?? "") + ", una sola volta",
             costi.map(\.ingresso))
        if let f = t.fondo {
            voce("Commissione di gestione del Fondo Interno", "\(CifreDoc.percento(f.commissione, decimali: 2)) l'anno, già nel valore delle quote", costi.map(\.commissione))
            if f.costiSottostanti > 0 {
                voce("Costi dei fondi sottostanti (stima)", "circa \(CifreDoc.percento(f.costiSottostanti)) l'anno, già nel valore delle quote", costi.map(\.sottostanti))
            }
        }
        if let g = t.gestione {
            voce("Trattenuto sulla Gestione separata", "\(CifreDoc.percento(g.trattenuto, decimali: 2)) l'anno, tolto dalla rivalutazione", costi.map(\.trattenuto))
        }
        if c.componenti.contains(where: \.bollo) {
            voce("Imposta di bollo", "\(CifreDoc.percento(c.bollo, decimali: 2)) l'anno sulle quote, trattenuta al pagamento", costi.map(\.bollo))
        }
        var totale = [CellaDoc("Totale dell'anno", colore: C.titolo, font: fontForte)]
        totale += costi.map { CellaDoc(CifreDoc.euro($0.totale), colore: C.titolo, font: fontForte) }
        totale.append(CellaDoc(CifreDoc.euro(costi.reduce(0) { $0 + $1.totale }), colore: C.titolo, font: fontForte))
        righe.append(RigaDoc(celle: totale, altezza: riga * 0.8, sfondo: C.riquadro))
        var incidenza = [CellaDoc("Incidenza sul valore medio del contratto", colore: C.tenue, font: font)]
        incidenza += costi.map { CellaDoc(CifreDoc.percento($0.incidenza, decimali: 2), colore: C.tenue, font: font) }
        incidenza.append(CellaDoc(""))
        righe.append(RigaDoc(celle: incidenza, altezza: riga * 0.8, filetto: C.filettoForte, spessore: 0.8))
        return TabellaDoc(larghezza: larghezza, colonne: colonne, righe: righe, fontTesta: fontForte, altezzaTesta: riga * 0.7,
                          colonneEvidenziate: [colonne.count - 1])
    }
}

// MARK: - 10. Garanzie e fiscalità

private struct SlideGaranzie: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TestaSlide(occhiello: "Garanzie e fiscalità", titolo: "Garanzie e imposte: cosa sapere")
            HStack(alignment: .top, spacing: 14) {
                elenco("Cosa è garantito", t.c.garantito, C.favorevole, C.favorevoleFondo)
                elenco("Cosa non è garantito", t.c.nonGarantito, C.sfavorevole, C.sfavorevoleFondo)
            }
            OcchielloDoc(testo: "Le imposte").padding(.top, 4)
            HStack(alignment: .top, spacing: 12) {
                imposta("≈ \(CifreDoc.percento(t.aliquotaMedia.rounded(), decimali: 0))", "Imposta sostitutiva", t.testoImposta)
                imposta(CifreDoc.percento(t.c.bollo, decimali: 2), "Imposta di bollo", t.testoBollo)
                imposta("netto", "Già nei nostri numeri", "tutti gli importi mostrati tengono conto di entrambe; la situazione fiscale personale può modificarli.")
            }
        }
    }

    private func elenco(_ titolo: String, _ punti: [String], _ colore: Color, _ fondo: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(verbatim: titolo).font(T.titoloRiquadro).foregroundColor(colore)
            ForEach(punti, id: \.self) { p in
                HStack(alignment: .top, spacing: 10) {
                    Text(verbatim: "•")
                    Text(verbatim: p).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
                }
                .font(T.corpo).foregroundColor(C.testo)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .riquadroDoc(fondo)
    }

    private func imposta(_ cifra: String, _ titolo: String, _ testo: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(verbatim: cifra).font(T.numeroMedio).foregroundColor(C.titolo)
                Text(verbatim: titolo).font(T.corpoForte).foregroundColor(C.titolo)
            }
            Text(verbatim: testo).font(T.piccolo).foregroundColor(C.testo).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .riquadroDoc()
    }
}

// MARK: - 11. Il KID

private struct SlideKID: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TestaSlide(occhiello: "Il confronto ufficiale", titolo: "Il confronto con il KID ufficiale",
                       sottotitolo: "Il KID è il documento ufficiale della Compagnia" + (t.c.dataDocumenti.map { " (\(CifreDoc.dataBreve($0)))" } ?? "")
                        + ". Rendimento medio annuo al lordo delle imposte. " + t.c.esempioKID)
            TabellaKID(t: t, larghezza: larghezzaUtile, riga: 23, font: T.corpo, fontTesta: T.corpoForte, fontNota: T.piccolo)
            Text(verbatim: t.commentoKID).font(T.corpo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
            (Text("Avvertenze. ").bold() + Text(verbatim: t.avvertenze))
                .font(T.piccolo).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .riquadroDoc()
        }
    }
}

/// Scenari del KID affiancati alla simulazione.
struct TabellaKID: View {
    let t: TestiValutazione
    let larghezza: CGFloat
    let riga: CGFloat
    let font: Font
    let fontTesta: Font
    let fontNota: Font

    var body: some View {
        let primo = t.anni.first ?? 2
        let lungo = t.annoKID
        let colonne = [ColonnaDoc(titolo: "Scenario", peso: 1.6, destra: false),
                       ColonnaDoc(titolo: "KID", sottotitolo: "uscita dopo 1 anno"),
                       ColonnaDoc(titolo: "Simulazione", sottotitolo: "inizio \(primo)° anno"),
                       ColonnaDoc(titolo: "KID", sottotitolo: "uscita dopo \(t.c.anniKID) anni"),
                       ColonnaDoc(titolo: "Simulazione", sottotitolo: "inizio \(lungo)° anno")]
        let righe = t.c.scenariKID.map { k -> RigaDoc in
            let nome = k.nome.lowercased().hasPrefix("moder") ? "\(k.nome) / Intermedio" : k.nome
            let celle = [CellaDoc(nome, font: font),
                         CellaDoc(k.unAnno.map { CifreDoc.variazione($0, decimali: 2) } ?? "—", font: font),
                         CellaDoc(t.simulazioneKID(k.nome, anno: primo).map { CifreDoc.variazione($0, decimali: 2) } ?? "—", font: font),
                         CellaDoc(k.periodo.map { CifreDoc.variazione($0, decimali: 2) } ?? "—", font: font),
                         CellaDoc(t.simulazioneKID(k.nome, anno: lungo).map { CifreDoc.variazione($0, decimali: 2) } ?? "—", font: font)]
            return RigaDoc(celle: celle, altezza: riga)
        }
        return TabellaDoc(larghezza: larghezza, colonne: colonne, righe: righe, fontTesta: fontTesta, fontTestaSotto: fontNota,
                          altezzaTesta: riga * 1.4, colonneEvidenziate: [2, 4])
            .overlay(Rectangle().fill(C.filettoForte).frame(height: 0.8), alignment: .bottom)
    }
}

// MARK: - 12. In sintesi

private struct SlideSintesi: View {
    let t: TestiValutazione

    var body: some View {
        let punti = t.sintesi
        return VStack(alignment: .leading, spacing: 16) {
            TestaSlide(occhiello: "In sintesi", titolo: "In sintesi")
            VStack(spacing: 14) {
                ForEach(Array(stride(from: 0, to: punti.count, by: 2)), id: \.self) { inizio in
                    HStack(spacing: 14) {
                        ForEach(inizio..<min(inizio + 2, punti.count), id: \.self) { i in punto(i + 1, punti[i]) }
                        if inizio + 1 >= punti.count { Color.clear.frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }
}

extension SlideSintesi {
    fileprivate func punto(_ n: Int, _ p: (String, String)) -> some View {
        HStack(alignment: .center, spacing: 18) {
            Text(verbatim: "\(n)").font(T.sintesiNumero).foregroundColor(C.titolo).frame(width: 30)
            (Text(verbatim: p.0).bold() + Text(verbatim: p.1))
                .font(T.corpo).foregroundColor(C.titolo).lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .riquadroDoc()
    }
}

// MARK: - 13. Appendice

private struct SlideAppendice: View {
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TestaSlide(occhiello: "Appendice", titolo: "Appendice: il dettaglio anno per anno")
            TabellaDettaglioBreve(t: t, larghezza: larghezzaUtile)
            Group {
                (Text("Come leggere la simulazione. ").bold() + Text(verbatim: t.comeLeggere)
                    + Text(t.c.fonti.isEmpty ? "" : " Fonti: ").bold() + Text(verbatim: t.c.fonti))
                Text("Simulazione illustrativa: ").bold() + Text("importi ipotetici e non garantiti. In caso di riscatto il capitale investito non è garantito.")
            }
            .font(T.minimo).foregroundColor(C.tenue).lineSpacing(1).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Valore, penale, imposte e netto per scenario e anno di riscatto (appendice del report).
private struct TabellaDettaglioBreve: View {
    let t: TestiValutazione
    let larghezza: CGFloat

    var body: some View {
        let anni = t.anni
        var colonne = [ColonnaDoc(titolo: "Riscatto all'inizio del…", sottotitolo: "mese · penale", peso: 2.2, destra: false)]
        colonne += anni.map { ColonnaDoc(titolo: "\($0)° anno", sottotitolo: "\(($0 - 1) * 12 + 1)° mese · \(CifreDoc.penale(t.c.penale(anno: $0)))") }
        var righe: [RigaDoc] = []
        for s in TipoScenario.allCases {
            let colore = C.scenario(s)
            let e = t.e.scenario(s)
            let intestazione = "\(s.nome)  ·  " + [t.fondo.map { "fondo \(CifreDoc.variazione(t.v.scenario(s).rendimento($0))) l'anno" },
                                                     t.gestione.map { "Gestione separata \(CifreDoc.percento(t.v.scenario(s).rendimento($0) - $0.trattenuto, decimali: 2)) netto" }]
                .compactMap { $0 }.joined(separator: ", ")
            righe.append(RigaDoc(celle: [CellaDoc(intestazione, colore: colore, font: T.piccolo.weight(.bold))], altezza: 17,
                                 sfondo: C.scenarioFondo(s), filetto: .clear))
            func riga(_ nome: String, _ valori: [String], forte: Bool = false) {
                righe.append(RigaDoc(celle: [CellaDoc(nome, colore: forte ? colore : C.testo, font: forte ? T.piccolo.weight(.bold) : T.piccolo)]
                                        + valori.map { CellaDoc($0, colore: forte ? colore : C.testo, font: forte ? T.piccolo.weight(.bold) : T.piccolo) },
                                     altezza: 16))
            }
            let r = anni.map { e?.riscatto(anno: $0) }
            riga("Valore del contratto", r.map { CifreDoc.euro($0?.valore ?? 0) })
            riga("Penale di riscatto", r.map { ($0?.penale ?? 0) > 0.5 ? CifreDoc.togli($0?.penale ?? 0) : "—" })
            riga("Imposta sostitutiva e bollo", r.map { CifreDoc.togli(($0?.imposta ?? 0) + ($0?.bollo ?? 0)) })
            riga("Importo netto incassato", r.map { CifreDoc.euro($0?.netto ?? 0) }, forte: true)
        }
        return TabellaDoc(larghezza: larghezza, colonne: colonne, righe: righe, fontTesta: T.piccolo.weight(.bold), fontTestaSotto: T.minimo,
                          altezzaTesta: 24, margine: 4)
            .overlay(Rectangle().fill(C.filettoForte).frame(height: 0.8), alignment: .bottom)
    }
}
