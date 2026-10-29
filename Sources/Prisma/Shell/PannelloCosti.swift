import SwiftUI

/// Il peso dei costi nel dossier Posizioni: quanto costano quest'anno le posizioni del cliente,
/// quanto tolgono in 10 e 20 anni e dove un'alternativa a parità di rischio lascerebbe di più.
struct PannelloCosti: View {
    @EnvironmentObject var stato: StatoShell
    let analisi: AnalisiCosti

    var body: some View {
        PannelloAnalisi(titolo: "Peso dei costi", nota: "Gestione, caricamenti e trattenute delle posizioni finanziarie in essere; imposte e bollo a parte") {
            HStack(spacing: 8) {
                if analisi.risparmioPossibile > 0 {
                    Pillola(testo: "Si può risparmiare", tono: .attenzione)
                }
                Button { stato.apriProspetto(.costi(report: true)) } label: { Label("Report per il cliente", systemImage: "doc.richtext") }
                    .buttonStyle(StileVetro())
                    .help("Apre in Prospetti il report dei costi, da stampare o salvare in PDF")
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: 12) {
                if !analisi.voci.isEmpty {
                    FasciaKPI {
                        KPI(titolo: "Costi di quest'anno", valore: Formati.euro(analisi.euroAnno)) {
                            Text(analisi.costoMedio.map { "in media \(CifreDoc.percento($0, decimali: 2)) l'anno" } ?? "")
                        }
                        KPI(titolo: "In 10 anni tolgono", valore: Formati.euro(analisi.perso10)) { Text("rendimenti persi compresi") }
                        KPI(titolo: "In 20 anni tolgono", valore: Formati.euro(analisi.perso20)) { Text("o fino alla scadenza") }
                        KPI(titolo: "Risparmio possibile", valore: analisi.risparmioPossibile > 0 ? Formati.euro(analisi.risparmioPossibile) : "—", ultimo: true) {
                            Text(analisi.conAlternativa.isEmpty ? "nessuna alternativa migliore" : "a parità di rischio, in 10 anni")
                        }
                    }
                    tabella
                }
                if !analisi.senzaDati.isEmpty {
                    Text("Senza costi indicati: \(analisi.senzaDati.map(\.nome).joined(separator: ", ")). Completali dal KID nella scheda della posizione (o da Documenti).")
                        .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.attenzioneTesto)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Il costo pesa due volte: quello che paghi e il rendimento che quei soldi non producono più. «Come nel KID» è l'incidenza annua dei costi (RIY) che Prisma calcola sugli anni raccomandati, prima delle imposte, con sotto quella dichiarata nel KID quando c'è: una stima da confrontare con il documento. Le alternative sono prodotti del catalogo con la stessa area e lo stesso indicatore di rischio, calcolate con lo stesso rendimento lordo e con penali, imposte d'uscita e costo d'ingresso.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var tabella: some View {
        // L'incidenza dei costi come nel KID (RIY), calcolata una volta finché posizioni e catalogo non cambiano
        let incidenze = CacheMotoriPosizioni.incidenze(analisi.voci.map(\.posizione), prodotti: stato.dati.prodotti)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Posizione").frame(maxWidth: .infinity, alignment: .leading)
                Text("Canale").frame(width: Misure.Analisi.colonnaCanale, alignment: .leading)
                Text("Costo annuo").frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
                Text("Come nel KID").frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
                Text("Quest'anno").frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
                Text("In 20 anni").frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
                Text("Alternativa").frame(width: Misure.Analisi.colonnaAlternativa, alignment: .leading)
                    .help("Alternativa a parità di rischio: stessa area e stesso indicatore di rischio, dal catalogo")
            }
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
            .padding(Misure.Analisi.testaMargine)
            .background(LinearGradient(colors: [Colori.Analisi.tabellaTestaAlto, Colori.Analisi.tabellaTestaBasso], startPoint: .top, endPoint: .bottom))
            .bordoBasso(Colori.Analisi.tabellaTestaBordo)
            ForEach(Array(analisi.voci.enumerated()), id: \.element.id) { i, v in
                Button { stato.posizioneInDettaglio = v.posizione.id } label: { riga(v, incidenza: incidenze[v.posizione.id]) }
                    .buttonStyle(StileSemplice())
                    .background(i % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
                    .bordoBasso(Colori.Analisi.tabellaRiga)
            }
        }
        .contornoTabella()
        // iPad stretto: la tabella scorre in orizzontale (sul Mac non cambia niente)
        .scorreSeStretto()
    }

    private func riga(_ v: CostiPosizione, incidenza: IncidenzaCostiKID?) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(v.posizione.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                Text(v.ingresso > 0 ? "ingresso \(CifreDoc.condizione(v.ingresso)) sui versamenti" : "senza costo d'ingresso")
                    .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            EtichettaCanale(canale: v.posizione.canale, compatta: true)
                .frame(width: Misure.Analisi.colonnaCanale, alignment: .leading)
            VStack(alignment: .trailing, spacing: 1) {
                Text(CifreDoc.percento(v.annuo, decimali: 2)).font(Tipo.tabellaCellaForte)
                    .foregroundColor(v.livello == .alto ? Colori.Analisi.erroreTesto : Colori.Analisi.tabellaTesto)
                Text(v.livello.nome).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
            }
            .frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
            colonnaKID(incidenza)
                .frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
            Text(Formati.euro(v.euroAnno)).font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto)
                .frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
            VStack(alignment: .trailing, spacing: 1) {
                Text(Formati.euro(v.perso20)).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                // Su due righe: nella colonna stretta «a scadenza · 11 anni» si troncherebbe
                if v.anni20 < MotoreCosti.orizzonti.1 {
                    Text("a scadenza").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
                    Text("\(v.anni20) \(v.anni20 == 1 ? "anno" : "anni")").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
                }
            }
            .frame(width: Misure.Analisi.colonnaCosto, alignment: .trailing)
            Group {
                if let x = v.alternativa {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            EtichettaCanale(canale: x.prodotto.canale, compatta: true)
                            Text(x.prodotto.nome).font(Tipo.chip).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                        }
                        Text("+\(Formati.euro(x.guadagno)) in \(x.anni) anni · \(CifreDoc.percento(x.costoAnnuo, decimali: 2)) l'anno")
                            .font(Tipo.chip).foregroundColor(Colori.Analisi.okTesto).lineLimit(1)
                    }
                } else {
                    Text("—").font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.kpiNota)
                }
            }
            .frame(width: Misure.Analisi.colonnaAlternativa, alignment: .leading)
        }
        .padding(Misure.Analisi.cellaMargine)
        .contentShape(Rectangle())
    }

    /// RIY calcolato al periodo raccomandato e, sotto, quello dichiarato nel KID (arancio se Prisma trova
    /// costi più alti di quanto dice il documento).
    @ViewBuilder private func colonnaKID(_ k: IncidenzaCostiKID?) -> some View {
        if let k, let c = k.calcolato {
            VStack(alignment: .trailing, spacing: 1) {
                Text(CifreDoc.percento(c, decimali: 2)).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                if let d = k.dichiarato {
                    Text("KID \(CifreDoc.percento(d, decimali: 2))")
                        .font(Tipo.chip)
                        .foregroundColor((k.scarto ?? 0) > MotoreCosti.scartoMinimo ? Colori.Analisi.attenzioneTesto : Colori.Analisi.kpiNota)
                        .lineLimit(1)
                } else {
                    Text("a \(k.periodoRaccomandato) \(k.periodoRaccomandato == 1 ? "anno" : "anni")")
                        .font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
                }
            }
            .help(IncidenzaCostiKID.metodo)
        } else {
            Text("—").font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.kpiNota)
        }
    }
}
