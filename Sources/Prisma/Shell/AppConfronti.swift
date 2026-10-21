import SwiftUI

/// Ciò che entra in un confronto, già tradotto in ipotesi di calcolo.
struct ElementoConfronto: Identifiable {
    let voce: VoceConfronto
    let titolo: String
    let sottotitolo: String
    let canale: Canale?
    let parametri: ParametriProiezione

    var id: VoceConfronto { voce }
}

/// App Confronti (.os-app-comparisons): due voci del dossier fianco a fianco, per esempio
/// la posizione in essere e la proposta, Alleanza e indipendente, con lo stesso orizzonte.
struct AppConfronti: View {
    @EnvironmentObject var stato: StatoShell

    private var cliente: String { stato.clienteAttivoId }

    /// Tutte le voci confrontabili del cliente.
    private var voci: [ElementoConfronto] {
        let orizzonte = stato.cliente(cliente)?.profilo.orizzonteAnni
        let posizioni = stato.posizioniCliente(cliente)
            .filter { $0.area.proiettabile && $0.stato != .chiusa }
            .sorted { ($0.stato == .inEssere ? 0 : 1, $0.nome) < ($1.stato == .inEssere ? 0 : 1, $1.nome) }
            .map { p in
                ElementoConfronto(voce: .posizione(p.id), titolo: p.nome,
                                  sottotitolo: "\(p.stato == .proposta ? "Proposta" : "In essere") · \(p.area.nome)",
                                  canale: p.canale, parametri: ParametriProiezione(posizione: p, orizzonteCliente: orizzonte))
            }
        let scenari = stato.simulazioniCliente(cliente).map { s in
            ElementoConfronto(voce: .simulazione(s.id), titolo: s.titolo, sottotitolo: "Scenario del simulatore",
                              canale: s.canale, parametri: s.parametri)
        }
        return posizioni + scenari
    }

    /// Le due voci scelte, con una scelta predefinita sensata: una proposta contro la posizione in essere più vicina.
    private var coppia: (ElementoConfronto?, ElementoConfronto?) {
        let tutte = voci
        func trova(_ v: VoceConfronto?) -> ElementoConfronto? { v.flatMap { x in tutte.first { $0.voce == x } } }
        var a = trova(stato.confrontoA)
        var b = trova(stato.confrontoB)
        if a == nil && b == nil {
            let proposta = stato.posizioniCliente(cliente).first { $0.stato == .proposta && $0.area.proiettabile }
            if let proposta {
                let inEssere = stato.posizioniCliente(cliente).filter { $0.stato == .inEssere && $0.area.proiettabile }
                a = trova((inEssere.first { $0.area == proposta.area } ?? inEssere.first).map { .posizione($0.id) })
                b = trova(.posizione(proposta.id))
            }
            if a == nil { a = tutte.first }
            if b == nil { b = tutte.first { $0.voce != a?.voce } }
        }
        return (a, b)
    }

    var body: some View {
        let scelta = coppia
        let a = scelta.0
        let b = scelta.1
        return CorniceStrumento(
            notaStato: "Calcoli eseguiti in locale · stesso motore delle Posizioni · le ipotesi non sono previsioni",
            notaDestra: "\(voci.count) voci confrontabili"
        ) {
            rail(a, b)
        } contenuto: {
            if let a, let b {
                confronto(a, b)
            } else {
                vuoto
            }
        }
    }

    // MARK: - Elenco laterale

    @ViewBuilder private func rail(_ a: ElementoConfronto?, _ b: ElementoConfronto?) -> some View {
        DossierRail()
        EtichettaRail(testo: "Orizzonte")
        SegmentiAnalisi(opzioni: [(false, "Ognuno il suo"), (true, "Comune")],
                        selezione: Binding(get: { stato.orizzonteConfronto != nil },
                                           set: { stato.orizzonteConfronto = $0 ? orizzonteComune(a, b) : nil }))
        if let anni = stato.orizzonteConfronto {
            Stepper(value: Binding(get: { anni }, set: { stato.orizzonteConfronto = min(max($0, 1), 50) }), in: 1...50) {
                Text("\(anni) \(anni == 1 ? "anno" : "anni")").font(Tipo.navAnalisi).foregroundColor(Colori.Analisi.navTesto)
            }
            .padding(.horizontal, 3)
        }
        Text("Con l'orizzonte comune le due voci si leggono sullo stesso numero di anni: il confronto è più equo.")
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Analisi.kpiNota)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3)
        EtichettaRail(testo: "Scambia")
        VoceNavigazione(titolo: "⇄ Inverti A e B", attiva: false) {
            stato.confrontoA = b?.voce
            stato.confrontoB = a?.voce
        }
        CollegatiRail(app: [.posizioni, .simulazioni, .analisi360])
    }

    private func orizzonteComune(_ a: ElementoConfronto?, _ b: ElementoConfronto?) -> Int {
        max(a?.parametri.anni ?? IpotesiCalcolo.orizzontePredefinito, b?.parametri.anni ?? IpotesiCalcolo.orizzontePredefinito)
    }

    private var vuoto: some View {
        VStack(spacing: 10) {
            Text("⇄").font(Tipo.risultatoGrande).foregroundColor(Colori.Analisi.lineaTratteggiata)
            Text("Servono almeno due voci da confrontare").font(Tipo.strumentoTitolo).foregroundColor(Colori.Strumenti.titolo)
            Text("Aggiungi una posizione o una proposta di investimento, risparmio o previdenza, oppure salva uno scenario nel simulatore.")
                .font(Tipo.strumentoTesto)
                .foregroundColor(Colori.Analisi.kpiNota)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            HStack {
                Button("Apri Posizioni") { stato.apri(.posizioni) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                Button("Apri il simulatore") { stato.apri(.simulazioni) }
                    .buttonStyle(StileBlu())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Confronto

    private func parametri(_ e: ElementoConfronto) -> ParametriProiezione {
        var p = e.parametri
        if let anni = stato.orizzonteConfronto { p.anni = anni }
        return p
    }

    private func confronto(_ a: ElementoConfronto, _ b: ElementoConfronto) -> some View {
        let pa = parametri(a)
        let pb = parametri(b)
        let ea = MotoreProiezione.calcola(pa)
        let eb = MotoreProiezione.calcola(pb)
        let ia = MotoreProiezione.impattoCosti(pa)
        let ib = MotoreProiezione.impattoCosti(pb)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TitoloStrumento(occhiello: "Due ipotesi, le stesse regole", titolo: "A confronto",
                                testo: "Scegli le due voci: posizioni in essere, proposte o scenari del simulatore. I calcoli usano rendimenti e costi indicati in ciascuna.")
                HStack(alignment: .top, spacing: 14) {
                    schedaVoce("A", a, colore: Colori.Strumenti.serie[0]) { stato.confrontoA = $0 }
                    schedaVoce("B", b, colore: Colori.Strumenti.serie[1]) { stato.confrontoB = $0 }
                }
                verdetto(a, b, ea, eb, ia, ib, pa, pb)
                PannelloAnalisi(titolo: "L'andamento nel tempo", nota: "Valore prima delle imposte; tratteggiato il versato di A") {
                    EmptyView()
                } contenuto: {
                    VStack(alignment: .leading, spacing: 10) {
                        GraficoProiezione(serie: [
                            .init(id: "b", punti: eb.punti, colore: Colori.Strumenti.serie[1]),
                            .init(id: "a", punti: ea.punti, colore: Colori.Strumenti.serie[0], principale: true),
                        ])
                        HStack(spacing: 16) {
                            LegendaLinea(colore: Colori.Strumenti.serie[0], testo: "A · \(a.titolo)")
                            LegendaLinea(colore: Colori.Strumenti.serie[1], testo: "B · \(b.titolo)")
                            LegendaLinea(colore: Colori.Analisi.lineaTratteggiata, testo: "Versato di A", tratteggio: true)
                        }
                    }
                }
                tabella(pa, pb, ea, eb, ia, ib)
                NotaMetodo(testo: "Il confronto mette sullo stesso piano numeri dichiarati: rendimenti attesi, costi e fiscalità vanno verificati sui documenti (KID, set informativo, prospetto). Garanzie, rischio, liquidabilità e coperture assicurative non entrano nel calcolo ma contano nella scelta: leggili nel dettaglio delle posizioni.",
                           titolo: "Prima di trarre conclusioni")
            }
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18))
        }
    }

    private func schedaVoce(_ lettera: String, _ e: ElementoConfronto, colore: Color, scegli: @escaping (VoceConfronto) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(lettera)
                    .font(Tipo.ipotesiTitolo)
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(colore))
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.titolo).font(Tipo.pannelloAnalisi).foregroundColor(Colori.Analisi.pannelloTitolo).lineLimit(1)
                    Text(e.sottotitolo).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
                }
                Spacer(minLength: 4)
                if let c = e.canale { EtichettaCanale(canale: c, compatta: true) }
            }
            Picker("", selection: Binding(get: { e.voce }, set: { scegli($0) })) {
                ForEach(voci) { v in
                    Text("\(v.titolo) — \(v.sottotitolo)").tag(v.voce)
                }
            }
            .labelsHidden()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).fill(Gradienti.kpi))
        .overlay(alignment: .leading) {
            Rectangle().fill(colore).frame(width: 3).padding(.vertical, 1)
        }
        .overlay(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).strokeBorder(Colori.Analisi.kpiBordo, lineWidth: 1))
    }

    private func verdetto(_ a: ElementoConfronto, _ b: ElementoConfronto, _ ea: EsitoProiezione, _ eb: EsitoProiezione,
                          _ ia: Double, _ ib: Double, _ pa: ParametriProiezione, _ pb: ParametriProiezione) -> some View {
        let differenza = eb.netto - ea.netto
        let stessoOrizzonte = pa.anni == pb.anni
        let testo: String
        if abs(differenza) < 1 {
            testo = "Con queste ipotesi A e B arrivano allo stesso valore netto."
        } else {
            let migliore = differenza > 0 ? "B" : "A"
            testo = "Con queste ipotesi \(migliore) arriva a \(Formati.euro(abs(differenza))) netti in più"
                + (stessoOrizzonte ? " in \(pa.anni) \(pa.anni == 1 ? "anno" : "anni")." : ", ma su orizzonti diversi (\(pa.anni) e \(pb.anni) anni): scegli l'orizzonte comune per un confronto equo.")
        }
        let costi = "I costi tolgono \(Formati.euro(ia)) ad A e \(Formati.euro(ib)) a B."
        let versato = abs(ea.versato - eb.versato) >= 1 ? " Attenzione: il versato è diverso (\(Formati.euro(ea.versato)) e \(Formati.euro(eb.versato)))." : ""
        return HStack(alignment: .top, spacing: 10) {
            Text("✦").font(Tipo.verdetto).foregroundColor(Colori.Analisi.navBasso)
            Text(testo + " " + costi + versato)
                .font(Tipo.verdetto)
                .foregroundColor(Colori.Analisi.tabellaTesto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).fill(Colori.Analisi.tabellaAlternata))
        .overlay(RoundedRectangle(cornerRadius: Misure.Analisi.raggio).strokeBorder(Colori.Analisi.chipBordo, lineWidth: 1))
    }

    /// Riga della tabella: B rispetto ad A, con il verso "meno è meglio" per costi e imposte.
    struct RigaConfronto {
        let etichetta: String
        let a: String
        let b: String
        var scarto: Double? = nil
        var menoEMeglio = false
        var forte = false
    }

    private func tabella(_ pa: ParametriProiezione, _ pb: ParametriProiezione, _ ea: EsitoProiezione, _ eb: EsitoProiezione,
                         _ ia: Double, _ ib: Double) -> some View {
        let w = Misure.Strumenti.colonnaConfronto
        let versamento: (ParametriProiezione) -> String = { p in
            p.versamento > 0 && p.frequenza != .unica ? "\(Formati.euro(p.versamento)) \(p.frequenza.nome.lowercased())" : "—"
        }
        let righe: [RigaConfronto] = [
            .init(etichetta: "Capitale iniziale", a: Formati.euro(pa.capitaleIniziale), b: Formati.euro(pb.capitaleIniziale)),
            .init(etichetta: "Versamenti periodici", a: versamento(pa), b: versamento(pb)),
            .init(etichetta: "Orizzonte", a: "\(pa.anni) anni", b: "\(pb.anni) anni"),
            .init(etichetta: "Rendimento atteso", a: Formati.percentuale(pa.rendimento), b: Formati.percentuale(pb.rendimento)),
            .init(etichetta: "Costo d'ingresso", a: Formati.percentuale(pa.costoIngresso), b: Formati.percentuale(pb.costoIngresso)),
            .init(etichetta: "Costo annuo", a: Formati.percentuale(pa.costoAnnuo), b: Formati.percentuale(pb.costoAnnuo)),
            .init(etichetta: "Fiscalità sul guadagno", a: Formati.percentuale(pa.aliquotaFiscale), b: Formati.percentuale(pb.aliquotaFiscale)),
            .init(etichetta: "Totale versato", a: Formati.euro(ea.versato), b: Formati.euro(eb.versato), scarto: eb.versato - ea.versato),
            .init(etichetta: "Costi nel periodo", a: Formati.euro(ea.costi), b: Formati.euro(eb.costi),
                  scarto: eb.costi - ea.costi, menoEMeglio: true),
            .init(etichetta: "Quanto tolgono i costi", a: Formati.euro(ia), b: Formati.euro(ib), scarto: ib - ia, menoEMeglio: true),
            .init(etichetta: "Imposte", a: Formati.euro(ea.imposte), b: Formati.euro(eb.imposte),
                  scarto: eb.imposte - ea.imposte, menoEMeglio: true),
            .init(etichetta: "Valore finale netto", a: Formati.euro(ea.netto), b: Formati.euro(eb.netto),
                  scarto: eb.netto - ea.netto, forte: true),
            .init(etichetta: "Guadagno netto", a: Formati.euro(ea.guadagnoNetto), b: Formati.euro(eb.guadagnoNetto),
                  scarto: eb.guadagnoNetto - ea.guadagnoNetto),
            .init(etichetta: "In euro di oggi", a: Formati.euro(ea.reale), b: Formati.euro(eb.reale), scarto: eb.reale - ea.reale),
        ]
        return TabellaStrumento {
            CellaTesta(testo: "")
            CellaTesta(testo: "A", larghezza: w, destra: true)
            CellaTesta(testo: "B", larghezza: w, destra: true)
            CellaTesta(testo: "B rispetto ad A", larghezza: w, destra: true)
        } righe: {
            ForEach(Array(righe.enumerated()), id: \.offset) { i, r in
                RigaStrumento(indice: i) {
                    CellaTabella(testo: r.etichetta, forte: r.forte)
                    CellaTabella(testo: r.a, larghezza: w, destra: true, forte: r.forte)
                    CellaTabella(testo: r.b, larghezza: w, destra: true, forte: r.forte)
                    CellaTabella(testo: testoScarto(r.scarto), larghezza: w, destra: true, forte: r.forte,
                                 colore: coloreScarto(r))
                }
            }
        }
    }

    private func testoScarto(_ v: Double?) -> String {
        guard let v else { return "" }
        guard abs(v) >= 1 else { return "=" }
        return "\(v > 0 ? "+" : "−")\(Formati.euro(abs(v)))"
    }

    private func coloreScarto(_ r: RigaConfronto) -> Color {
        guard let v = r.scarto, abs(v) >= 1 else { return Colori.Analisi.kpiNota }
        return (v > 0) != r.menoEMeglio ? Colori.Strumenti.positivo : Colori.Strumenti.negativo
    }
}
