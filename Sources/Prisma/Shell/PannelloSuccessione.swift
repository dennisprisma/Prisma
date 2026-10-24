import SwiftUI

/// Il passaggio generazionale nel dossier Posizioni: cosa va ai beneficiari e cosa agli eredi,
/// con quali tempi e quali imposte, e cosa sistemare (beneficiari mancanti, convivente escluso…).
struct PannelloSuccessione: View {
    @EnvironmentObject var stato: StatoShell
    let s: Successione

    var body: some View {
        PannelloAnalisi(titolo: "Passaggio generazionale", nota: "Se mancasse oggi, senza testamento: una stima per parlarne, non un parere legale o notarile") {
            HStack(spacing: 8) {
                if !s.daSistemare.isEmpty || s.conviventeEscluso != nil {
                    Pillola(testo: "Da sistemare", tono: .attenzione)
                }
                Button("Report per il cliente") { stato.apriProspetto(.successione(report: true)) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                    .help("Apre in Prospetti il report del passaggio generazionale, da stampare o salvare in PDF")
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: 12) {
                FasciaKPI {
                    KPI(titolo: "Ai beneficiari", valore: Formati.euro(s.fuoriAsse)) { Text("in poche settimane, fuori successione") }
                    KPI(titolo: "Agli eredi", valore: Formati.euro(s.asseNetto)) { Text("dopo la successione, debiti tolti") }
                    KPI(titolo: "Imposte stimate", valore: Formati.euro(s.imposte)) {
                        Text(s.impostaSuccessione > 0.5 ? "successione e ipocatastali" : (s.ipocatastali > 0.5 ? "solo ipotecaria e catastale" : "entro le franchigie"))
                    }
                    KPI(titolo: "Da sistemare", valore: "\(s.daSistemare.count + (s.conviventeEscluso == nil ? 0 : 1))", ultimo: true) {
                        Text("beneficiari e tutele")
                    }
                }
                HStack(alignment: .top, spacing: 14) {
                    tabella.frame(maxWidth: .infinity, alignment: .topLeading)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EREDI SENZA TESTAMENTO").font(Tipo.kpiTitolo).tracking(0.3).foregroundColor(Colori.Analisi.kpiTitolo)
                        if s.eredi.isEmpty && s.asseNetto <= 0 {
                            Text("Nessun erede tra i familiari registrati.").font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                        }
                        ForEach(s.eredi) { e in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(e.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                                    Text("\(e.relazione.nome)\(e.minorenne ? ", minorenne" : "") · \(MotoreSuccessione.frazione(e.quota))")
                                        .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                                }
                                Spacer(minLength: 6)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(Formati.euro(e.importo)).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                                    Text(e.imposta > 0.5 ? "imposta \(Formati.euro(e.imposta))" : "nessuna imposta").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                                }
                            }
                            Rectangle().fill(Colori.Analisi.tabellaRiga).frame(height: 1)
                        }
                        ForEach(Array(s.avvisi.enumerated()), id: \.offset) { _, a in
                            Text(a).font(Tipo.kpiNota).foregroundColor(Colori.Analisi.attenzioneTesto).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(width: Misure.Analisi.colonnaEredi, alignment: .topLeading)
                }
            }
        }
    }

    private var tabella: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Posizione").frame(maxWidth: .infinity, alignment: .leading)
                Text("Canale").frame(width: Misure.Analisi.colonnaCanale, alignment: .leading)
                Text("Va a").frame(width: Misure.Analisi.colonnaDestino, alignment: .leading)
                Text("Importo").frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
            }
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
            .padding(Misure.Analisi.testaMargine)
            .background(LinearGradient(colors: [Colori.Analisi.tabellaTestaAlto, Colori.Analisi.tabellaTestaBasso], startPoint: .top, endPoint: .bottom))
            .bordoBasso(Colori.Analisi.tabellaTestaBordo)
            ForEach(Array(s.voci.enumerated()), id: \.element.id) { i, v in
                Button { stato.posizioneInDettaglio = v.posizione.id } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(v.posizione.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                            Text(v.avviso ?? (v.destino == .beneficiari && !v.posizione.beneficiari.isEmpty ? "Beneficiari: \(v.posizione.beneficiari)" : v.motivo))
                                .font(Tipo.chip).foregroundColor(v.avviso == nil ? Colori.Analisi.kpiNota : Colori.Analisi.attenzioneTesto).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        EtichettaCanale(canale: v.posizione.canale, compatta: true)
                            .frame(width: Misure.Analisi.colonnaCanale, alignment: .leading)
                        Pillola(testo: v.destino == .beneficiari ? "Beneficiari" : "Eredi", tono: v.destino == .beneficiari ? .ok : .neutro)
                            .frame(width: Misure.Analisi.colonnaDestino, alignment: .leading)
                        Text(Formati.euro(v.importo)).font(Tipo.tabellaCellaForte)
                            .foregroundColor(v.importo < 0 ? Colori.Analisi.erroreTesto : Colori.Analisi.tabellaTesto)
                            .frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
                    }
                    .padding(Misure.Analisi.cellaMargine)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StileSemplice())
                .background(i % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
        }
        .overlay(Rectangle().strokeBorder(Colori.Analisi.tabellaBordo, lineWidth: 1))
    }
}
