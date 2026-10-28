import SwiftUI

// MARK: - Riscatto anno per anno

/// Il riscatto anno per anno di una polizza o di un fondo: quanto incasserebbe il cliente chiudendo il
/// contratto ogni anno, con penali, costo d'uscita, mesi di blocco, imposte e bollo, e il primo anno
/// in cui riprende almeno quanto ha versato.
struct PannelloRiscatto: View {
    let esito: EsitoRiscatto
    @State private var tutti = false
    @State private var mostraMetodo = false

    private typealias M = Tema.Misura.MotoriPosizioni
    private typealias C = Tema.Colore.MotoriPosizioni

    private var proposta: Bool { esito.posizione.stato == .proposta }

    /// Le righe da mostrare: i primi anni, il primo senza perdite, il primo senza penali e l'ultimo
    /// (tutte, se richiesto).
    private var righe: [RiscattoAnno] {
        let tutte = esito.righe
        guard !tutti, tutte.count > M.righeRiscatto + 1 else { return tutte }
        let evidenza = Set([esito.primoRecupero?.anni, esito.primoSenzaPenali?.anni, tutte.last?.anni].compactMap { $0 })
        return tutte.filter { $0.anni < M.righeRiscatto || evidenza.contains($0.anni) }
    }

    var body: some View {
        PannelloAnalisi(
            titolo: "Se riscatti, anno per anno",
            nota: "Quanto incasseresti chiudendo il contratto ogni anno, al rendimento atteso: una stima, non una previsione"
        ) {
            HStack(spacing: 8) {
                pillola
                Button(mostraMetodo ? "Nascondi il metodo" : "Come si calcola?") { mostraMetodo.toggle() }
                    .buttonStyle(StileSemplice())
                    .font(Tipo.colonnaCollegamento)
                    .foregroundColor(Colori.Colonna.collegamento)
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: M.spazioSezioni) {
                FasciaKPI {
                    kpiRecupero
                    kpiPenali
                    kpiBlocco
                    kpiFine
                }
                tabella
                if esito.righe.count > M.righeRiscatto + 1 {
                    Button(titoloTutti) { tutti.toggle() }
                        .buttonStyle(StileSemplice())
                        .font(Tipo.colonnaCollegamento)
                        .foregroundColor(Colori.Colonna.collegamento)
                }
                Text(frase)
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
                if mostraMetodo {
                    NotaMetodo(testo: EsitoRiscatto.criterio + "\n" + EsitoRiscatto.metodo, titolo: "Come si calcola")
                }
            }
        }
    }

    private var titoloTutti: String {
        tutti ? "Mostra solo gli anni principali" : "Mostra tutti gli anni (\(esito.righe.count))"
    }

    @ViewBuilder private var pillola: some View {
        if let r = esito.primoRecupero {
            if r.anni == 0 {
                Pillola(testo: proposta ? "Senza perdite da subito" : "Già senza perdite", tono: .ok)
            } else {
                Pillola(testo: "Senza perdite dal \(Formati.dataBreve.string(from: r.data))", tono: .ok)
            }
        } else {
            Pillola(testo: "Non riprende il versato", tono: .attenzione)
        }
    }

    // MARK: Indicatori

    private var kpiRecupero: some View {
        let r = esito.primoRecupero
        let valore: String = r.map { $0.anni == 0 ? (proposta ? "Alla firma" : "Oggi") : Formati.dataBreve.string(from: $0.data) } ?? "—"
        return KPI(titolo: "Primo riscatto senza perdite", valore: valore) {
            if let r {
                Text("\(r.annoContratto)° anno di contratto · \(Formati.euro(r.netto)) netti")
            } else {
                Text("non nei \(esito.righe.last?.anni ?? 0) anni mostrati")
            }
        }
    }

    private var kpiPenali: some View {
        let conPenali = esito.annoSenzaPenali > 1
        let valore: String = conPenali ? (esito.senzaPenaliDal.map { Formati.dataBreve.string(from: $0) } ?? "\(esito.annoSenzaPenali)° anno") : "Nessuna"
        return KPI(titolo: conPenali ? "Senza penali dal" : "Penali di riscatto", valore: valore) {
            if esito.costoUscita > 0 {
                Text("resta il costo d'uscita del \(CifreDoc.percento(esito.costoUscita, decimali: 2))")
            } else if conPenali {
                Text("dal \(esito.annoSenzaPenali)° anno di contratto")
            } else {
                Text("il contratto non le prevede")
            }
        }
    }

    private var kpiBlocco: some View {
        let valore: String = esito.riscattabileDal.map { "dal \(Formati.dataBreve.string(from: $0))" } ?? (proposta && esito.mesiBlocco != nil ? "Dopo il blocco" : "Subito")
        return KPI(titolo: "Riscatto possibile", valore: valore) {
            if let m = esito.mesiBlocco, m > 0 {
                Text("blocco di \(m) mesi dalla \(proposta ? "firma" : "decorrenza")")
            } else {
                Text("nessun periodo di blocco")
            }
        }
    }

    private var kpiFine: some View {
        let ultima = esito.righe.last
        let anni = ultima?.anni ?? 0
        return KPI(titolo: "Dopo \(anni) \(anni == 1 ? "anno" : "anni")", valore: ultima.map { Formati.euro($0.netto) } ?? "—", ultimo: true) {
            if let u = ultima {
                Text("netti · guadagno \(CifreDoc.euroSegno(u.guadagno))")
            } else {
                Text("netti")
            }
        }
    }

    // MARK: Tabella

    private var tabella: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                testa("Quando", nil)
                testa("Contratto", M.colonnaContratto)
                testa("Versato", M.colonnaImporto)
                testa("Valore", M.colonnaImporto)
                testa("Penale", M.colonnaPenale)
                testa("Imposte e bollo", M.colonnaImporto)
                testa("Netto", M.colonnaNetto)
                testa("Guadagno", M.colonnaImporto)
            }
            .background(Colori.Analisi.tabellaTestaAlto)
            .bordoBasso(Colori.Analisi.tabellaTestaBordo)
            ForEach(Array(righe.enumerated()), id: \.element.id) { i, r in
                riga(r)
                    .background(sfondo(r, alternata: i % 2 == 1))
                    .bordoBasso(Colori.Analisi.tabellaRiga)
            }
        }
        .contornoTabella()
    }

    private func sfondo(_ r: RiscattoAnno, alternata: Bool) -> Color {
        if r.anni == esito.primoRecupero?.anni { return C.rigaEvidenza }
        return alternata ? Colori.Analisi.tabellaAlternata : Colori.Analisi.principale
    }

    private func riga(_ r: RiscattoAnno) -> some View {
        let colore = r.possibile ? Colori.Analisi.tabellaTesto : C.rigaSpenta
        let quando: String = r.anni == 0 ? (proposta ? "Alla firma" : "Oggi") : "Tra \(r.anni) \(r.anni == 1 ? "anno" : "anni")"
        let tasse = r.imposta + r.bollo
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(quando).font(Tipo.tabellaCellaForte).foregroundColor(colore)
                Text(Formati.dataBreve.string(from: r.data)).font(Tipo.chip).foregroundColor(Colori.Analisi.kpiNota)
            }
            .lineLimit(1)
            .padding(Misure.Analisi.cellaMargine)
            .frame(maxWidth: .infinity, alignment: .leading)
            cella("\(r.annoContratto)° anno", M.colonnaContratto, colore: colore)
            cella(Formati.euro(r.versato), M.colonnaImporto, colore: colore)
            cella(Formati.euro(r.valore), M.colonnaImporto, colore: colore)
            cella(r.penalePercento > 0 ? CifreDoc.percento(r.penalePercento) : "—", M.colonnaPenale, colore: colore)
            cella(tasse > 0.5 ? CifreDoc.togli(tasse) : "—", M.colonnaImporto, colore: colore)
            if r.possibile {
                cella(Formati.euro(r.netto), M.colonnaNetto, colore: colore, forte: true)
                cella(CifreDoc.euroSegno(r.guadagno), M.colonnaImporto,
                      colore: r.guadagno.rounded() < 0 ? C.negativo : colore)
            } else {
                cella("non riscattabile", M.colonnaNetto, colore: C.rigaSpenta)
                cella("—", M.colonnaImporto, colore: C.rigaSpenta)
            }
        }
    }

    private func testa(_ t: String, _ larghezza: CGFloat?) -> some View {
        Text(t)
            .font(Tipo.tabellaTesta)
            .foregroundColor(Colori.Analisi.tabellaTesta)
            .lineLimit(1)
            .padding(Misure.Analisi.testaMargine)
            .frame(maxWidth: larghezza ?? .infinity, alignment: larghezza == nil ? .leading : .trailing)
            .frame(width: larghezza)
    }

    private func cella(_ t: String, _ larghezza: CGFloat, colore: Color, forte: Bool = false) -> some View {
        Text(t)
            .font(forte ? Tipo.tabellaCellaForte : Tipo.numeroTabella)
            .foregroundColor(colore)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(Misure.Analisi.cellaMargine)
            .frame(width: larghezza, alignment: .trailing)
    }

    // MARK: Frase

    private var frase: String {
        var parti: [String] = []
        if let d = esito.riscattabileDal {
            parti.append("Fino al \(Formati.dataBreve.string(from: d)) il riscatto non si può chiedere (blocco di \(esito.mesiBlocco ?? 0) mesi): le cifre di quegli anni sono in grigio.")
        }
        if let r = esito.primoRecupero {
            if r.anni == 0 {
                parti.append(proposta
                    ? "Già alla firma il netto non scende sotto quanto versato."
                    : "Chiudendo oggi si riprende già almeno quanto versato: \(Formati.euro(r.netto)) netti su \(Formati.euro(r.versato)).")
            } else {
                parti.append("Dal \(Formati.dataBreve.string(from: r.data)) (\(r.annoContratto)° anno di contratto) il netto restituisce almeno quanto versato fino a quel momento; prima, tra costi e penali, resta sotto.")
            }
        } else {
            parti.append("Negli anni mostrati il netto non torna a quanto versato: conviene tenerlo fino alla fine o rivederlo.")
        }
        if esito.annoSenzaPenali > 1, let d = esito.senzaPenaliDal {
            parti.append("Le penali finiscono il \(Formati.dataBreve.string(from: d)).")
        }
        return parti.joined(separator: " ")
    }
}

// MARK: - Gestione separata

/// La gestione separata di una polizza rivalutabile di Ramo I: lordo, trattenuto o retrocessione,
/// accreditato con il minimo garantito, consolidamento, rendimento reale e garantito a scadenza.
struct PannelloGestioneSeparata: View {
    let esito: EsitoGestioneSeparata
    let posizione: Posizione

    private typealias M = Tema.Misura.MotoriPosizioni
    private typealias C = Tema.Colore.MotoriPosizioni

    var body: some View {
        let e = esito
        let l = M.etichettaRigaLarga
        return PannelloAnalisi(titolo: "La gestione separata", nota: "Quanto rende davvero al cliente, ogni anno") {
            if e.reale < 0 {
                Pillola(testo: "Perde potere d'acquisto", tono: .errore)
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: 0) {
                RigaDato("Rendimento lordo ipotizzato", "\(Self.percento(e.lordo)) l'anno", larghezza: l)
                if let r = e.retrocessione {
                    RigaDato("Retrocessione al cliente",
                             "\(CifreDoc.percento(r, decimali: 0)) del lordo" + (e.trattenutoIndicato.map { " · trattiene almeno \(Self.punti($0))" } ?? ""),
                             larghezza: l)
                } else {
                    RigaDato("Trattenuto dalla compagnia", e.trattenutoIndicato.map { "\(Self.punti($0)) l'anno" } ?? "non indicato", larghezza: l)
                }
                RigaDato("Rendimento accreditato", "\(Self.percento(e.accreditato)) l'anno", larghezza: l,
                         pillola: e.minimoDecisivo ? Pillola(testo: "decide il minimo", tono: .attenzione) : nil)
                RigaDato("Minimo garantito", minimo, larghezza: l)
                RigaDato("Consolidamento", consolidamento, larghezza: l)
                RigaDato("Rendimento reale",
                         "\(CifreDoc.variazione(e.reale, decimali: 2)) l'anno, tolta l'inflazione del \(CifreDoc.condizione(e.inflazione))",
                         larghezza: l, colore: e.reale < 0 ? C.negativo : nil)
                if let g = e.garantitoAScadenza {
                    RigaDato("Garantito a scadenza", "\(Formati.euro(g)) prima delle imposte", larghezza: l)
                }
                if e.trattenutoEuro >= 0.5 {
                    RigaDato("Trattenuto in un anno", "\(Formati.euro(e.trattenutoEuro)) sul valore \(posizione.stato == .inEssere ? "di oggi" : "versato")", larghezza: l)
                }
                Text(frase)
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .help(MotoreGestioneSeparata.metodo)
    }

    private var minimo: String {
        guard let m = esito.minimoGarantito else { return "non indicato (si considera garantito il capitale)" }
        return m <= 0 ? "0%: è garantito il capitale" : "\(Self.percento(m)) l'anno"
    }

    private var consolidamento: String {
        switch esito.consolidamento {
        case .some(true): return "annuo: ogni anno l'accreditato resta acquisito"
        case .some(false): return "solo a scadenza o al decesso: prima il valore può scendere"
        case .none: return "non indicato (si considera annuo)"
        }
    }

    private var frase: String {
        var parti = ["Al cliente va il rendimento della gestione meno quanto trattiene la compagnia."]
        if esito.minimoDecisivo {
            parti.append("Qui il minimo garantito alza l'accreditato sopra il \(Self.percento(esito.netto)) che resterebbe.")
        }
        if esito.reale < 0 {
            parti.append("Tolta l'inflazione ipotizzata il rendimento è negativo: il capitale è garantito, il potere d'acquisto no.")
        }
        parti.append("Il lordo è un'ipotesi: verificalo sul rendiconto della gestione.")
        return parti.joined(separator: " ")
    }

    /// "2,50%"
    static func percento(_ v: Double) -> String { CifreDoc.percento(v, decimali: 2) }

    /// "1,30 punti"
    static func punti(_ v: Double) -> String { "\(String(CifreDoc.percento(v, decimali: 2).dropLast())) punti" }
}
