import SwiftUI

/// Il patrimonio nel tempo nel dossier Posizioni: tutte le posizioni insieme, com'è oggi e con le proposte,
/// con gli obiettivi lungo la strada.
struct PannelloPatrimonio: View {
    let p: PatrimonioNelTempo

    var body: some View {
        PannelloAnalisi(titolo: "Il patrimonio nel tempo",
                        nota: "Tutte le posizioni insieme, con i rendimenti ipotizzati: immobili al valore di oggi, debiti che si estinguono, prima delle imposte finali") {
            if let d = p.differenzaProposte {
                Pillola(testo: "Con le proposte \(d >= 0 ? "+" : "")\(Formati.euroBreve(d))", tono: d >= 0 ? .ok : .attenzione)
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: 12) {
                FasciaKPI {
                    KPI(titolo: "Oggi", valore: Formati.euro(p.nettoOggi)) { Text("patrimonio netto") }
                    KPI(titolo: "Tra 10 anni", valore: Formati.euro(p.valore(10))) { Text("versando \(Formati.euroBreve(p.versamentiAnnui)) l'anno") }
                    KPI(titolo: "Tra \(p.anni) anni", valore: Formati.euro(p.valore(p.anni))) {
                        Text("\(Formati.euroBreve(p.reale(p.valore(p.anni), anno: p.anni))) in euro di oggi")
                    }
                    KPI(titolo: "Con le proposte", valore: p.conProposte == nil ? "—" : Formati.euro(p.valore(p.anni, conProposte: true)), ultimo: true) {
                        Text(p.conProposte == nil ? "nessuna proposta aperta" : "tra \(p.anni) anni, +\(Formati.euroBreve(p.versamentiAnnuiProposte)) l'anno")
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        GraficoProiezione(serie: serie)
                            .frame(height: Misure.Analisi.grafico)
                        HStack(spacing: 14) {
                            legenda("Com'è oggi", Colori.Analisi.lineaAtteso)
                            if p.conProposte != nil { legenda("Con le proposte", Colori.Analisi.linea) }
                            legenda("Patrimonio di oggi più i versamenti", Colori.Analisi.lineaTratteggiata)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OBIETTIVI LUNGO LA STRADA").font(Tipo.kpiTitolo).tracking(0.3).foregroundColor(Colori.Analisi.kpiTitolo)
                        if p.traguardi.isEmpty {
                            Text("Nessun obiettivo con una data nei prossimi \(p.anni) anni: si aggiungono in Obiettivi.")
                                .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota).fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(p.traguardi.prefix(Misure.Analisi.righeResistenza)) { t in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(t.obiettivo.titolo).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                                    Text(t.anno == 0 ? "quest'anno" : "tra \(t.anno) \(t.anno == 1 ? "anno" : "anni") · \(Formati.euro(t.obiettivo.importo))")
                                        .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                                }
                                Spacer(minLength: 6)
                                Text(Formati.euroBreve(p.valore(t.anno, conProposte: p.conProposte != nil)))
                                    .font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto)
                                    .help("Patrimonio netto stimato in quell'anno")
                            }
                            Rectangle().fill(Colori.Analisi.tabellaRiga).frame(height: 1)
                        }
                    }
                    .frame(width: Misure.Analisi.colonnaEredi, alignment: .topLeading)
                }
            }
        }
    }

    private var serie: [GraficoProiezione.Serie] {
        var s = [GraficoProiezione.Serie(id: "oggi", punti: p.oggi, colore: Colori.Analisi.lineaAtteso, principale: p.conProposte == nil)]
        if let c = p.conProposte { s.append(.init(id: "proposte", punti: c, colore: Colori.Analisi.linea, principale: true)) }
        return s
    }

    private func legenda(_ testo: String, _ colore: Color) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(colore).frame(width: 14, height: 3)
            Text(testo).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
        }
    }
}
