import SwiftUI

/// La coerenza delle posizioni con il profilo del cliente nel dossier Posizioni: rischio medio e quota
/// azionaria contro i limiti della propensione, la crisi del passato peggiore, la concentrazione per
/// emittente e per canale, e l'elenco dei punti da rivedere (anche quelli che nascono dalle proposte).
struct PannelloCoerenza: View {
    let esito: EsitoCoerenza
    @State private var mostraMetodo = false

    private typealias M = Tema.Misura.MotoriPosizioni

    private var profilo: String {
        esito.propensione.map { "un profilo \($0.nome.lowercased())" } ?? "il profilo"
    }

    var body: some View {
        let m = esito.oggi
        PannelloAnalisi(
            titolo: "Coerenza con il profilo",
            nota: "Rischio e concentrazione delle posizioni in essere rispetto al profilo del cliente, e cosa cambia con le proposte aperte"
        ) {
            HStack(spacing: 8) {
                pillola
                Button(mostraMetodo ? "Nascondi il metodo" : "Come si giudica?") { mostraMetodo.toggle() }
                    .buttonStyle(StileSemplice())
                    .font(Tipo.colonnaCollegamento)
                    .foregroundColor(Colori.Colonna.collegamento)
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: M.spazioSezioni) {
                FasciaKPI {
                    kpiRischio(m)
                    kpiAzioni(m)
                    kpiCrisi(m)
                    kpiEmittente(m)
                }
                if let cp = esito.conProposte {
                    Text(fraseProposte(cp))
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.Analisi.kpiNota)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .top, spacing: M.spazioColonne) {
                    emittenti(m).frame(maxWidth: .infinity, alignment: .leading)
                    canali(m).frame(maxWidth: .infinity, alignment: .leading)
                }
                elenco
                if esito.propensione == nil {
                    Text("Indica la propensione al rischio nel profilo del cliente: senza, Prisma controlla solo la concentrazione.")
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.Analisi.attenzioneTesto)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if mostraMetodo {
                    NotaMetodo(testo: MotoreCoerenza.metodo.joined(separator: "\n"), titolo: "Come si giudica")
                }
            }
        }
    }

    @ViewBuilder private var pillola: some View {
        if esito.coerente {
            if esito.propensione == nil {
                Pillola(testo: "Profilo da completare", tono: .neutro)
            } else {
                Pillola(testo: "Coerente con il profilo", tono: .ok)
            }
        } else {
            let n = esito.incoerenze.count
            Pillola(testo: n == 1 ? "Un punto da rivedere" : "\(n) punti da rivedere", tono: .attenzione)
        }
    }

    // MARK: Indicatori

    private func kpiRischio(_ m: MisureCoerenza) -> some View {
        KPI(titolo: "Rischio medio (SRI)", valore: m.sriMedio.map { "\(MotoreCoerenza.numero($0)) su 7" } ?? "—") {
            if let p = esito.propensione {
                Text("massimo \(MotoreCoerenza.sriMassimo(p)) per \(profilo)")
            } else {
                Text("ponderato sul valore")
            }
        }
    }

    private func kpiAzioni(_ m: MisureCoerenza) -> some View {
        KPI(titolo: "Quota in azioni", valore: m.quotaAzionaria.map { CifreDoc.percento($0 * 100, decimali: 0) } ?? "—") {
            if let p = esito.propensione {
                Text("limite \(CifreDoc.percento(MotoreCoerenza.azioniMassime(p), decimali: 0)) del finanziario")
            } else {
                Text("del patrimonio finanziario")
            }
        }
    }

    private func kpiCrisi(_ m: MisureCoerenza) -> some View {
        let k = m.crisiPeggiore
        return KPI(titolo: "Crisi del passato peggiore", valore: k.map { Formati.euro(-$0.perdita) } ?? "—") {
            if let k {
                Text("\(String(k.crisi.anno)) · \(CifreDoc.variazione(-k.quota * 100)) del finanziario")
            } else {
                Text("nessuna perdita stimata")
            }
        }
    }

    private func kpiEmittente(_ m: MisureCoerenza) -> some View {
        let e = m.emittenti.first
        return KPI(titolo: "Primo emittente", valore: e.map { CifreDoc.percento($0.quota * 100, decimali: 0) } ?? "—", ultimo: true) {
            if let e {
                Text("\(e.nome) · soglia \(CifreDoc.percento(MotoreCoerenza.sogliaEmittente, decimali: 0))")
            } else {
                Text("nessun investimento")
            }
        }
    }

    // MARK: Concentrazione

    private func emittenti(_ m: MisureCoerenza) -> some View {
        VStack(alignment: .leading, spacing: M.spazioElenco) {
            Text("Per emittente")
                .font(Tema.Testo.MotoriPosizioni.sottotitolo)
                .foregroundColor(Colori.Analisi.tabellaTesto)
            if m.emittenti.isEmpty {
                Text("Nessun investimento con l'emittente indicato.")
                    .font(Tipo.kpiNota).foregroundColor(Colori.Analisi.kpiNota)
            }
            ForEach(m.emittenti.prefix(M.righeEmittenti)) { e in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: M.spazioElenco) {
                        Text(e.nome).font(Tipo.tabellaCella).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                        if let c = e.canale { EtichettaCanale(canale: c, compatta: true) }
                        Spacer(minLength: 0)
                        Text(Formati.euro(e.valore))
                            .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                            .frame(width: M.colonnaValore, alignment: .trailing)
                        Text(CifreDoc.percento(e.quota * 100, decimali: 0))
                            .font(Tipo.chip)
                            .foregroundColor(e.quota * 100 > MotoreCoerenza.sogliaEmittente ? Colori.Analisi.attenzioneTesto : Colori.Analisi.kpiNota)
                            .frame(width: M.colonnaQuota, alignment: .trailing)
                    }
                    BarraQuotaPortafoglio(quota: e.quota, colore: Colori.Analisi.canale(e.canale))
                }
            }
            Text("Quota del patrimonio finanziario (conti esclusi dal conteggio): oltre il \(CifreDoc.percento(MotoreCoerenza.sogliaEmittente, decimali: 0)) presso un solo emittente conviene valutare se diversificare.")
                .font(Tipo.chip)
                .foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func canali(_ m: MisureCoerenza) -> some View {
        return VStack(alignment: .leading, spacing: M.spazioElenco) {
            Text("Per canale")
                .font(Tema.Testo.MotoriPosizioni.sottotitolo)
                .foregroundColor(Colori.Analisi.tabellaTesto)
            ForEach(Canale.allCases) { c in
                let q = m.perCanale[c] ?? 0
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: M.spazioElenco) {
                        EtichettaCanale(canale: c, compatta: true)
                        Spacer(minLength: 0)
                        Text(Formati.euro(q * m.patrimonioFinanziario))
                            .font(Tipo.numeroTabella).foregroundColor(Colori.Analisi.tabellaTesto)
                            .frame(width: M.colonnaValore, alignment: .trailing)
                        Text(CifreDoc.percento(q * 100, decimali: 0))
                            .font(Tipo.chip)
                            .foregroundColor(c == .alleanza && q * 100 > MotoreCoerenza.sogliaCanale ? Colori.Analisi.attenzioneTesto : Colori.Analisi.kpiNota)
                            .frame(width: M.colonnaQuota, alignment: .trailing)
                    }
                    BarraQuotaPortafoglio(quota: q, colore: Colori.Analisi.canale(c))
                }
            }
            Text(notaCanali(m))
                .font(Tipo.chip)
                .foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Punti da rivedere

    @ViewBuilder private var elenco: some View {
        if esito.incoerenze.isEmpty {
            Text(esito.propensione == nil
                 ? "Nessuna concentrazione eccessiva su un emittente o sul canale Alleanza."
                 : "Nessun punto da rivedere: rischio, crisi del passato e concentrazione sono in linea con \(profilo).")
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.okTesto)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(esito.incoerenze.enumerated()), id: \.element.id) { i, x in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        HStack(spacing: 0) {
                            Pillola(testo: x.tipo.nome, tono: x.tipo.concentrazione ? .neutro : .attenzione)
                        }
                        .frame(width: M.colonnaTipoCoerenza, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x.titolo).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto)
                            Text(x.dettaglio)
                                .font(Tipo.chip)
                                .foregroundColor(Colori.Analisi.kpiNota)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let p = x.posizione {
                            EtichettaCanale(canale: p.canale, compatta: true)
                        }
                    }
                    .padding(Misure.Analisi.cellaMargine)
                    .background(i % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
                    .bordoBasso(Colori.Analisi.tabellaRiga)
                }
            }
            .contornoTabella()
        }
    }

    private func notaCanali(_ m: MisureCoerenza) -> String {
        let investito: Double = Canale.allCases.reduce(0.0) { $0 + (m.perCanale[$1] ?? 0) }
        var testo = "Investito per canale sul patrimonio finanziario"
        if investito < 0.995 && m.patrimonioFinanziario > 0 {
            testo += "; il resto, \(CifreDoc.percento((1 - investito) * 100, decimali: 0)), è sui conti."
        } else {
            testo += "."
        }
        return testo + " Alleanza colloca i prodotti di una sola compagnia: oltre l'\(CifreDoc.percento(MotoreCoerenza.sogliaCanale, decimali: 0)) lì è concentrazione."
    }

    private func fraseProposte(_ cp: MisureCoerenza) -> String {
        var parti: [String] = []
        if let s = cp.sriMedio { parti.append("rischio medio \(MotoreCoerenza.numero(s)) su 7") }
        if let a = cp.quotaAzionaria { parti.append("azioni al \(CifreDoc.percento(a * 100, decimali: 0))") }
        if let k = cp.crisiPeggiore { parti.append("crisi peggiore \(Formati.euro(-k.perdita))") }
        if let e = cp.emittenti.first { parti.append("\(e.nome) al \(CifreDoc.percento(e.quota * 100, decimali: 0))") }
        guard !parti.isEmpty else { return "Le proposte aperte non cambiano rischio e concentrazione." }
        return "Con le proposte aperte (contate per il primo versamento più un anno di premi): " + parti.joined(separator: ", ") + "."
    }
}
