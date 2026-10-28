import SwiftUI

/// La prova di resistenza nel dossier Posizioni: tre scenari avversi, le posizioni più esposte
/// ai mercati e il confronto con la perdita che il profilo del cliente sopporta.
struct PannelloResistenza: View {
    @EnvironmentObject var stato: StatoShell
    let prova: ProvaResistenza

    private typealias M = Tema.Misura.MotoriPosizioni
    private typealias C = Tema.Colore.MotoriPosizioni

    var body: some View {
        PannelloAnalisi(titolo: "Prova di resistenza", nota: "Stime prudenti sulle posizioni in essere: non previsioni, ma un modo per parlarne") {
            HStack(spacing: 8) {
                if let g = prova.giudizio { Pillola(testo: g.etichetta, tono: tono(g)) }
                Button("Report per il cliente") { stato.apriProspetto(.resistenza(report: true)) }
                    .buttonStyle(StileVetro(margine: EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)))
                    .help("Apre in Prospetti il report della prova di resistenza, da stampare o salvare in PDF")
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: 12) {
                FasciaKPI {
                    ForEach(Array(prova.scenari.enumerated()), id: \.element.id) { i, s in
                        KPI(titolo: s.tipo.titolo, valore: s.voci.isEmpty ? "—" : Formati.euro(-s.perdita), ultimo: i == prova.scenari.count - 1) {
                            Text(nota(s))
                        }
                        .help(s.tipo.ipotesi)
                    }
                }
                if let m = prova.scenario(.mercati), m.base > 0 { profilo(m) }
                if let m = prova.scenario(.mercati), !m.voci.isEmpty { esposte(m) }
                if prova.crisi.contains(where: { !$0.voci.isEmpty }) { crisiDelPassato }
                Text(prova.scenari.map { "\($0.tipo.titolo): \($0.tipo.ipotesi.prefix(1).lowercased() + $0.tipo.ipotesi.dropFirst())" }.joined(separator: " "))
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func nota(_ s: ProvaResistenza.Scenario) -> String {
        guard !s.voci.isEmpty else { return s.tipo == .immobili ? "nessun immobile" : "nessuna perdita" }
        return "il \(CifreDoc.percento(s.quota * 100)) \(s.tipo == .immobili ? "del netto" : "del finanziario")"
    }

    private func tono(_ g: ProvaResistenza.Giudizio) -> Pillola.Tono {
        switch g {
        case .dentro: return .ok
        case .alLimite: return .attenzione
        case .oltre: return .errore
        }
    }

    /// La perdita sui mercati sulla barra del patrimonio finanziario, con il segno della soglia del profilo.
    private func profilo(_ m: ProvaResistenza.Scenario) -> some View {
        let scala = max(m.quota, (prova.sopportabile ?? 0) / 100, 0.01) * 1.25
        return VStack(alignment: .leading, spacing: 9) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Colori.Analisi.tracciaAnello)
                    Capsule().fill(prova.giudizio.map(coloreBarra) ?? Colori.Analisi.barre)
                        .frame(width: max(g.size.width * m.quota / scala, Misure.Analisi.barraResistenza))
                    if let s = prova.sopportabile {
                        Rectangle().fill(Colori.Analisi.assi)
                            .frame(width: 2, height: Misure.Analisi.barraResistenza + 6)
                            .offset(x: g.size.width * s / 100 / scala - 1)
                    }
                }
            }
            .frame(height: Misure.Analisi.barraResistenza)
            Text(testoProfilo(m))
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.tabellaTesto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func coloreBarra(_ g: ProvaResistenza.Giudizio) -> Color {
        switch g {
        case .dentro: return Colori.Analisi.okTesto
        case .alLimite: return Colori.Analisi.attenzioneTesto
        case .oltre: return Colori.Analisi.erroreTesto
        }
    }

    private func testoProfilo(_ m: ProvaResistenza.Scenario) -> String {
        let protetto = "Il \(CifreDoc.percento(prova.quotaProtetta * 100, decimali: 0)) del patrimonio finanziario è garantito o senza rischio di mercato."
        guard let s = prova.sopportabile, let p = prova.propensione else {
            return "Sui mercati la perdita stimata è il \(CifreDoc.percento(m.quota * 100)) del patrimonio finanziario. Indica la propensione al rischio nel profilo del cliente per confrontarla con quella che sopporta. " + protetto
        }
        return "Sui mercati la perdita stimata è il \(CifreDoc.percento(m.quota * 100)) del patrimonio finanziario; una propensione \(p.nome.lowercased()) ne sopporta fino al \(CifreDoc.condizione(s)) (il segno sulla barra). " + protetto
    }

    // MARK: - Crisi del passato

    /// Le crisi vere del 2008, 2020 e 2022 applicate alle posizioni di oggi, accanto agli scenari:
    /// una riga per crisi con la perdita in euro e in quota del patrimonio finanziario e il giudizio sul profilo.
    private var crisiDelPassato: some View {
        let peggiore = prova.crisiPeggiore
        return VStack(alignment: .leading, spacing: M.spazioElenco) {
            HStack(alignment: .firstTextBaseline) {
                Text("Se tornassero le crisi del passato")
                    .font(Tema.Testo.MotoriPosizioni.sottotitolo)
                    .foregroundColor(Colori.Analisi.tabellaTesto)
                Spacer()
                Text("stime indicative sul patrimonio di oggi")
                    .font(Tipo.chip)
                    .foregroundColor(Colori.Analisi.kpiNota)
            }
            VStack(spacing: 0) {
                ForEach(Array(prova.crisi.enumerated()), id: \.element.id) { i, k in
                    rigaCrisi(k, peggiore: k.id == peggiore?.id, alternata: i % 2 == 1)
                }
            }
            .contornoTabella()
            Text(fraseCrisi(peggiore))
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
        }
        .help(MotoreResistenza.metodoCrisi.joined(separator: " "))
    }

    private func rigaCrisi(_ k: EsitoCrisi, peggiore: Bool, alternata: Bool) -> some View {
        let tocca = !k.voci.isEmpty
        let perde = k.perdita.rounded() > 0
        let colore = !tocca ? Colori.Analisi.kpiNota : (perde ? C.negativo : C.positivo)
        let euro: String = !tocca ? "—" : (perde ? Formati.euro(-k.perdita) : "+" + Formati.euro(abs(k.perdita)))
        return HStack(spacing: 10) {
            Text(String(k.crisi.anno))
                .font(Tipo.tabellaCellaForte)
                .foregroundColor(Colori.Analisi.tabellaTesto)
                .frame(width: M.colonnaAnnoCrisi, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: M.spazioElenco) {
                    Text(k.crisi.titolo).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                    if peggiore { Chip(testo: "la peggiore") }
                }
                Text(k.crisi.periodo).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                if let g = k.giudizio, tocca { Pillola(testo: g.etichetta, tono: tono(g)) }
            }
            .frame(width: M.colonnaGiudizioCrisi, alignment: .trailing)
            Text(euro)
                .font(Tipo.tabellaCellaForte)
                .foregroundColor(colore)
                .frame(width: M.colonnaPerditaCrisi, alignment: .trailing)
            Text(tocca ? CifreDoc.variazione(-k.quota * 100) : "—")
                .font(Tipo.numeroTabella)
                .foregroundColor(colore)
                .frame(width: M.colonnaQuotaCrisi, alignment: .trailing)
        }
        .padding(Misure.Analisi.cellaMargine)
        .background(peggiore ? C.rigaPeggiore : (alternata ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale))
        .bordoBasso(Colori.Analisi.tabellaRiga)
    }

    private func fraseCrisi(_ peggiore: EsitoCrisi?) -> String {
        guard let w = peggiore, w.perdita > 0 else {
            return "Nessuna delle tre crisi farebbe perdere qualcosa al patrimonio finanziario di oggi. Il giudizio sul profilo resta quello dello scenario sui mercati."
        }
        var testo = "La peggiore per il patrimonio di oggi: \(w.crisi.titolo.lowercased()) del \(w.crisi.anno), circa \(Formati.euro(w.perdita)) in meno, il \(CifreDoc.percento(w.quota * 100)) del patrimonio finanziario. \(w.crisi.recupero)"
        if w.perditaImmobili >= 0.5 {
            testo += " Sugli immobili, a parte, circa \(Formati.euro(w.perditaImmobili)) in meno."
        }
        return testo + " Il giudizio sul profilo resta quello dello scenario sui mercati."
    }

    /// Le posizioni che perdono di più se i mercati crollano, con il canale ben visibile.
    private func esposte(_ m: ProvaResistenza.Scenario) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Le più esposte ai mercati").frame(maxWidth: .infinity, alignment: .leading)
                Text("Canale").frame(width: Misure.Analisi.colonnaCanale, alignment: .leading)
                Text("Perdita stimata").frame(width: Misure.Analisi.colonnaPerdita, alignment: .trailing)
            }
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
            .padding(Misure.Analisi.testaMargine)
            .background(LinearGradient(colors: [Colori.Analisi.tabellaTestaAlto, Colori.Analisi.tabellaTestaBasso], startPoint: .top, endPoint: .bottom))
            .bordoBasso(Colori.Analisi.tabellaTestaBordo)
            ForEach(Array(m.voci.prefix(Misure.Analisi.righeResistenza).enumerated()), id: \.element.id) { i, v in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(v.posizione.nome).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.tabellaTesto).lineLimit(1)
                        // Il motivo di una multiramo a due parti è più lungo: va a capo invece di tagliarsi
                        Text(v.motivo).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    EtichettaCanale(canale: v.posizione.canale, compatta: true)
                        .frame(width: Misure.Analisi.colonnaCanale, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Formati.euro(-v.perdita)).font(Tipo.tabellaCellaForte).foregroundColor(Colori.Analisi.erroreTesto)
                        Text("su \(Formati.euro(v.posizione.valore))").font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
                    }
                    .frame(width: Misure.Analisi.colonnaPerdita, alignment: .trailing)
                }
                .padding(Misure.Analisi.cellaMargine)
                .background(i % 2 == 1 ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale)
                .bordoBasso(Colori.Analisi.tabellaRiga)
            }
        }
        .contornoTabella()
    }
}
