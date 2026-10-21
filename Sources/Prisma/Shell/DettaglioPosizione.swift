import SwiftUI

/// Dettaglio di una posizione: dati del contratto, costi e rischio, proiezione con scenari
/// o, per le coperture, il quadro della protezione. Si apre dentro la finestra, come su iOS 5.
struct DettaglioPosizione: View {
    @EnvironmentObject var stato: StatoShell
    let posizione: Posizione
    let modifica: () -> Void
    @State var confermaEliminazione = false
    @State var mostraMetodo = false

    private var orizzonteCliente: Int? { stato.cliente(posizione.clienteId)?.profilo.orizzonteAnni }

    var body: some View {
        VStack(spacing: 0) {
            barraNavigazione
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intestazione
                    HStack(alignment: .top, spacing: 28) {
                        contratto.frame(maxWidth: .infinity, alignment: .leading)
                        if posizione.area.proiettabile {
                            costiERischio.frame(width: 320, alignment: .leading)
                        }
                    }
                    if posizione.area.proiettabile {
                        proiezione
                    } else if posizione.area == .protezione {
                        protezione
                    }
                    HStack {
                        Spacer()
                        Button {
                            confermaEliminazione = true
                        } label: {
                            Text("Elimina la posizione…").foregroundColor(Colori.Analisi.erroreTesto)
                        }
                        .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
                    }
                }
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 18, trailing: 16))
            }
        }
        .alert("Eliminare \(posizione.nome)?", isPresented: $confermaEliminazione) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                stato.posizioneInDettaglio = nil
                stato.eliminaPosizione(posizione.id)
            }
        } message: {
            Text("La posizione verrà tolta dal dossier del cliente. Se serve, potrai recuperarla da un backup.")
        }
    }

    // MARK: - Barra

    private var barraNavigazione: some View {
        HStack(spacing: 10) {
            Button { stato.posizioneInDettaglio = nil } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                    Text("Posizioni")
                }
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 10)))
            Spacer()
            if posizione.stato == .proposta {
                Button("Segna come in essere") { stato.attivaProposta(posizione.id) }
                    .buttonStyle(StileBlu())
                    .help("La proposta è stata accettata: diventa una posizione in essere")
            }
            Button("Modifica", action: modifica)
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)))
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Gradienti.kpi)
        .bordoBasso(Colori.Analisi.kpiBordo)
    }

    private var intestazione: some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Colori.Analisi.area(posizione.area))
                .frame(width: 8, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(posizione.nome.isEmpty ? "Senza nome" : posizione.nome)
                    .font(Tipo.profiloNome)
                    .tracking(-0.4)
                    .foregroundColor(Colori.Analisi.kpiValore)
                Text([posizione.area.nome, posizione.tipologia, posizione.emittente].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
            }
            .incisione(.white)
            Spacer()
            EtichettaCanale(canale: posizione.canale)
            PillolaStato(posizione: posizione)
        }
    }

    // MARK: - Contratto

    private var contratto: some View {
        let p = posizione
        return PannelloAnalisi(titolo: "Dati del contratto") { EmptyView() } contenuto: {
            VStack(spacing: 0) {
                RigaDato("Numero", p.numeroContratto)
                RigaDato("Contraente", p.contraente)
                RigaDato("Assicurato", p.assicurato)
                RigaDato("Beneficiari", p.beneficiari)
                RigaDato("Decorrenza", p.decorrenza.map { Formati.dataEstesa.string(from: $0) } ?? "")
                RigaDato("Scadenza", p.scadenza.map { Formati.dataEstesa.string(from: $0) } ?? "")
                if p.versamentoIniziale > 0 {
                    RigaDato(p.area == .protezione ? "Premio unico" : "Versamento iniziale", Formati.euro(p.versamentoIniziale))
                }
                if p.frequenza != .unica {
                    RigaDato(p.area == .debiti ? "Rata" : "Premio / versamento",
                             "\(Formati.euro(p.premio)) · \(p.frequenza.nome.lowercased()) (\(Formati.euro(p.premioAnnuo)) all'anno)")
                }
                if let v = p.totaleVersato { RigaDato("Totale versato", Formati.euro(v)) }
                if let v = p.controvalore, p.area != .protezione {
                    RigaDato(p.area == .debiti ? "Debito residuo" : "Controvalore",
                             Formati.euro(v) + (p.dataValore.map { " al \(Formati.dataBreve.string(from: $0))" } ?? ""))
                }
                if let c = p.capitaleAssicurato {
                    RigaDato("Capitale assicurato", Formati.euro(c) + (p.rischio.map { " · \($0.nome)" } ?? ""))
                }
                if p.stato == .proposta { RigaDato("Esito della proposta", p.esito?.nome ?? "Bozza") }
                RigaDato("Garanzie", p.garanzie)
                RigaDato("Note", p.note)
            }
        }
    }

    private var costiERischio: some View {
        let p = posizione
        return PannelloAnalisi(titolo: "Costi, ipotesi e rischio") { EmptyView() } contenuto: {
            VStack(spacing: 0) {
                RigaDato("Rendimento atteso", p.rendimentoAtteso.map { Formati.percentuale($0) + " annuo" } ?? "", larghezza: 118)
                RigaDato("Costo d'ingresso", p.costoIngresso.map { Formati.percentuale($0) + " dei versamenti" } ?? "", larghezza: 118)
                RigaDato("Costo annuo", p.costoAnnuo.map { Formati.percentuale($0) + " all'anno" } ?? "", larghezza: 118)
                RigaDato("Fiscalità", p.aliquotaFiscale.map { Formati.percentuale($0) + " sul rendimento" } ?? "", larghezza: 118)
                HStack(alignment: .center, spacing: 12) {
                    Text("Rischio (SRI)")
                        .font(Tipo.campoEtichetta)
                        .foregroundColor(Colori.Analisi.kpiNota)
                        .frame(width: 118, alignment: .leading)
                    ScalaRischio(valore: p.sri)
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Proiezione

    private var proiezione: some View {
        let parametri = ParametriProiezione(posizione: posizione, orizzonteCliente: orizzonteCliente)
        let scenari = MotoreProiezione.scenari(parametri)
        let atteso = scenari[1].esito
        let impatto = MotoreProiezione.impattoCosti(parametri)
        return PannelloAnalisi(
            titolo: "Proiezione a \(parametri.anni) \(parametri.anni == 1 ? "anno" : "anni")",
            nota: "Ipotesi dimostrativa al \(Formati.percentuale(parametri.rendimento)) annuo lordo. Non è una previsione."
        ) {
            Button(mostraMetodo ? "Nascondi il metodo" : "Come viene calcolato?") { mostraMetodo.toggle() }
                .buttonStyle(StileSemplice())
                .font(Tipo.colonnaCollegamento)
                .foregroundColor(Colori.Colonna.collegamento)
        } contenuto: {
            VStack(alignment: .leading, spacing: 14) {
                GraficoProiezione(serie: [
                    .init(id: "prudente", punti: scenari[0].esito.punti, colore: Colori.Analisi.prudente),
                    .init(id: "favorevole", punti: scenari[2].esito.punti, colore: Colori.Analisi.favorevole),
                    .init(id: "atteso", punti: atteso.punti, colore: Colori.Analisi.linea, principale: true),
                ])
                HStack(spacing: 16) {
                    legenda(Colori.Analisi.linea, "Atteso \(Formati.percentuale(scenari[1].rendimento))")
                    legenda(Colori.Analisi.prudente, "Prudente \(Formati.percentuale(scenari[0].rendimento))")
                    legenda(Colori.Analisi.favorevole, "Favorevole \(Formati.percentuale(scenari[2].rendimento))")
                    legenda(Colori.Analisi.lineaTratteggiata, "Versato cumulato", tratteggio: true)
                }
                FasciaKPI {
                    KPI(titolo: "Versato", valore: Formati.euro(atteso.versato)) {
                        Text(parametri.versamento > 0 ? "\(Formati.euro(parametri.versamento)) \(parametri.frequenza.nome.lowercased())" : "solo capitale iniziale")
                    }
                    KPI(titolo: "Valore finale netto", valore: Formati.euro(atteso.netto)) {
                        Chip(testo: "lordo \(Formati.euroBreve(atteso.lordo))")
                        Chip(testo: "imposte \(Formati.euroBreve(atteso.imposte))")
                    }
                    KPI(titolo: "In euro di oggi", valore: Formati.euro(atteso.reale)) {
                        Text("inflazione \(Formati.percentuale(parametri.inflazione))")
                    }
                    KPI(titolo: "Costi nel periodo", valore: Formati.euro(atteso.costi), ultimo: true) {
                        Text("tolgono \(Formati.euro(impatto)) al netto")
                    }
                }
                scenariTabella(scenari)
                if mostraMetodo { metodo(parametri) }
            }
        }
    }

    private func scenariTabella(_ scenari: [(nome: String, rendimento: Double, esito: EsitoProiezione)]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                testa("Scenario", nil)
                testa("Rendimento", 110)
                testa("Valore netto", 130)
                testa("Guadagno netto", 130)
                testa("In euro di oggi", 130)
            }
            .background(Gradienti.testaTabella)
            .bordoBasso(Colori.Analisi.tabellaTestaBordo)
            ForEach(Array(scenari.enumerated()), id: \.offset) { i, s in
                HStack(spacing: 0) {
                    Text(s.nome).font(Tipo.tabellaCellaForte).padding(Misure.Analisi.cellaMargine)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    cellaNumero(Formati.percentuale(s.rendimento), 110)
                    cellaNumero(Formati.euro(s.esito.netto), 130)
                    cellaNumero(Formati.euro(s.esito.guadagnoNetto), 130,
                                colore: s.esito.guadagnoNetto < 0 ? Colori.Analisi.erroreTesto : Colori.Analisi.tabellaTesto)
                    cellaNumero(Formati.euro(s.esito.reale), 130)
                }
                .foregroundColor(Colori.Analisi.tabellaTesto)
                .background(i % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
        }
        .overlay(Rectangle().strokeBorder(Colori.Analisi.tabellaBordo, lineWidth: 1))
    }

    private func metodo(_ p: ParametriProiezione) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Come viene calcolato").font(Tipo.pannelloAnalisi).foregroundColor(Colori.Analisi.pannelloTitolo)
            Group {
                Text("• Si parte da \(Formati.euro(p.capitaleIniziale))\(posizione.stato == .inEssere ? " (valore attuale)" : " (versamento iniziale)")\(p.ingressoSulCapitale && p.costoIngresso > 0 ? ", tolto il costo d'ingresso del \(Formati.percentuale(p.costoIngresso))" : "").")
                if p.versamento > 0 {
                    Text("• Ogni versamento di \(Formati.euro(p.versamento)) (\(p.frequenza.nome.lowercased())) entra al netto del costo d'ingresso.")
                }
                Text("• Ogni mese il capitale cresce del rendimento mensile equivalente al \(Formati.percentuale(p.rendimento)) annuo e paga la quota mensile del costo annuo (\(Formati.percentuale(p.costoAnnuo))).")
                Text("• Alla fine, sulla parte che supera il versato si applicano le imposte al \(Formati.percentuale(p.aliquotaFiscale)).")
                Text("• Il valore in euro di oggi divide il netto per l'inflazione cumulata al \(Formati.percentuale(p.inflazione)) annuo.")
                Text("• Gli scenari spostano il rendimento di \(Formati.percentuale(IpotesiCalcolo.ampiezzaScenari)) punti in meno e in più. Rendimenti e costi sono quelli indicati nella posizione: verificali sul KID o sul prospetto.")
            }
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Analisi.tabellaTesto)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 4).fill(Gradienti.kpi))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Colori.Analisi.kpiBordo, lineWidth: 1))
    }

    // MARK: - Protezione

    private var protezione: some View {
        let p = posizione
        let capitale = p.capitaleAssicurato ?? 0
        let premioAnnuo = p.premioAnnuo > 0 ? p.premioAnnuo : p.versamentoIniziale
        return PannelloAnalisi(titolo: "La copertura", nota: p.rischio?.nome) { EmptyView() } contenuto: {
            FasciaKPI {
                KPI(titolo: "Capitale assicurato", valore: Formati.euro(capitale)) { Text(p.rischio?.nome ?? "Rischio non indicato") }
                KPI(titolo: "Premio annuo", valore: Formati.euro(premioAnnuo)) { Text(p.frequenza.nome.lowercased()) }
                KPI(titolo: "Costo per 1.000 € assicurati", valore: capitale > 0 ? Formati.euroDecimali(premioAnnuo / capitale * 1000) : "—", ultimo: true) {
                    Text("all'anno")
                }
            }
        }
    }

    // MARK: - Piccoli elementi

    private func legenda(_ colore: Color, _ testo: String, tratteggio: Bool = false) -> some View {
        HStack(spacing: 6) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 4))
                p.addLine(to: CGPoint(x: 18, y: 4))
            }
            .stroke(colore, style: StrokeStyle(lineWidth: 2, dash: tratteggio ? [4, 3] : []))
            .frame(width: 18, height: 8)
            Text(testo).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
        }
    }

    private func testa(_ t: String, _ larghezza: CGFloat?) -> some View {
        Text(t)
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
            .incisione(.white)
            .padding(Misure.Analisi.testaMargine)
            .frame(maxWidth: larghezza ?? .infinity, alignment: larghezza == nil ? .leading : .trailing)
            .frame(width: larghezza)
    }

    private func cellaNumero(_ t: String, _ larghezza: CGFloat, colore: Color = Colori.Analisi.tabellaTesto) -> some View {
        Text(t)
            .font(Tipo.numeroTabella)
            .foregroundColor(colore)
            .padding(Misure.Analisi.cellaMargine)
            .frame(width: larghezza, alignment: .trailing)
    }
}

/// Riga etichetta/valore nei pannelli dell'analisi.
struct RigaDato: View {
    let etichetta: String
    let valore: String
    var larghezza: CGFloat = 150

    init(_ etichetta: String, _ valore: String, larghezza: CGFloat = 150) {
        self.etichetta = etichetta
        self.valore = valore
        self.larghezza = larghezza
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(etichetta)
                .font(Tipo.campoEtichetta)
                .foregroundColor(Colori.Analisi.kpiNota)
                .frame(width: larghezza, alignment: .leading)
            Text(valore.isEmpty ? "—" : valore)
                .font(Tipo.tabellaCella)
                .foregroundColor(valore.isEmpty ? Colori.Analisi.kpiNota : Colori.Analisi.tabellaTesto)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
        .bordoBasso(Colori.Analisi.tabellaRiga)
    }
}

/// Scala di rischio SRI da 1 a 7, come nel KID.
struct ScalaRischio: View {
    let valore: Int?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...7, id: \.self) { i in
                Text("\(i)")
                    .font(Tipo.chip)
                    .foregroundColor(i == valore ? .white : Colori.Analisi.chipTesto)
                    .frame(width: 19, height: 18)
                    .background(RoundedRectangle(cornerRadius: 2)
                        .fill(i == valore ? AnyShapeStyle(Gradienti.navAnalisi) : AnyShapeStyle(Colori.Analisi.chip)))
                    .overlay(RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(i == valore ? Colori.Analisi.navBordoBasso : Colori.Analisi.chipBordo, lineWidth: 1))
            }
            if valore == nil {
                Text("non indicato").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).padding(.leading, 4)
            }
        }
    }
}
