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
/// Per una multiramo a due parti è la sola parte in gestione separata: le cifre in euro valgono sul suo valore.
struct PannelloGestioneSeparata: View {
    let esito: EsitoGestioneSeparata
    let posizione: Posizione
    /// «La gestione separata» o, per la parte di una multiramo, «La parte in gestione separata · 40%».
    var titolo = "La gestione separata"
    /// Per la parte di una multiramo: «sul valore della parte, 24.800 €» (nil per il Ramo I).
    var notaQuota: String? = nil

    private typealias M = Tema.Misura.MotoriPosizioni
    private typealias C = Tema.Colore.MotoriPosizioni

    /// true se il pannello mostra la parte in gestione separata di una multiramo.
    private var parte: Bool { notaQuota != nil }

    var body: some View {
        let e = esito
        let l = M.etichettaRigaLarga
        let nota = notaQuota.map { "Quanto rende davvero al cliente, ogni anno, \($0)" } ?? "Quanto rende davvero al cliente, ogni anno"
        return PannelloAnalisi(titolo: titolo, nota: nota) {
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
                    RigaDato("Trattenuto in un anno",
                             "\(Formati.euro(e.trattenutoEuro)) sul valore \(parte ? "della parte " : "")\(posizione.stato == .inEssere ? "di oggi" : "versato")",
                             larghezza: l)
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
        var parti = [parte
            ? "Sulla parte in gestione separata va al cliente il rendimento della gestione meno quanto trattiene la compagnia; i fondi seguono i mercati per conto loro."
            : "Al cliente va il rendimento della gestione meno quanto trattiene la compagnia."]
        if esito.minimoDecisivo {
            parti.append("Qui il minimo garantito alza l'accreditato sopra il \(Self.percento(esito.netto)) che resterebbe.")
        }
        if esito.reale < 0 {
            // Senza consolidamento annuo la garanzia vale solo a scadenza o al decesso
            let garanzia = esito.consolidamento == false
                ? "la garanzia vale solo a scadenza o al decesso"
                : (parte ? "il capitale della parte è garantito" : "il capitale è garantito")
            parti.append("Tolta l'inflazione ipotizzata il rendimento è negativo: \(garanzia), il potere d'acquisto no.")
        }
        parti.append("Il lordo è un'ipotesi: verificalo sul rendiconto della gestione.")
        return parti.joined(separator: " ")
    }

    /// "2,50%"
    static func percento(_ v: Double) -> String { CifreDoc.percento(v, decimali: 2) }

    /// "1,30 punti"
    static func punti(_ v: Double) -> String { "\(String(CifreDoc.percento(v, decimali: 2).dropLast())) punti" }
}

// MARK: - Composizione di una multiramo

/// Le due parti di una multiramo: la barra con quote ed euro, i dati della gestione separata e dei fondi,
/// il ribilanciamento, gli avvisi sui dati mancanti e l'SRI dei fondi rispetto a quello della combinazione.
struct PannelloComposizione: View {
    let posizione: Posizione
    /// SRI massimo del profilo del cliente: se i soli fondi lo superano ma la combinazione no, una riga lo dice.
    var sriMassimo: Int? = nil
    /// Apre il modulo della posizione («Completa i dati») per una multiramo senza i dati delle due parti.
    var completa: (() -> Void)? = nil

    private typealias M = Tema.Misura.Multiramo
    private typealias C = Tema.Colore.Multiramo

    var body: some View {
        let p = posizione
        let l = M.etichettaPannello
        return PannelloAnalisi(
            titolo: "Composizione: gestione separata e fondi",
            nota: p.multiramoDivisa ? "Due parti con rendimenti, costi e rischio propri" : "Per ora calcolata come un comparto unico"
        ) {
            if p.quotaGestioneStimata {
                Pillola(testo: "Quota stimata", tono: .attenzione)
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: 0) {
                BarraComposizione(gestione: p.parteGestione, euroGestione: euro(p.parteGestione), euroFondi: euro(p.parteFondi))
                    .padding(.bottom, M.spazioPannello)
                if p.multiramoDivisa {
                    RigaDato("Gestione separata", rigaGestione, larghezza: l)
                    RigaDato("Fondi", rigaFondi, larghezza: l)
                    RigaDato("Ribilanciamento", ribilanciamento, larghezza: l)
                }
                if p.quotaGestioneStimata {
                    nota("Quota in gestione separata non indicata: stimata al \(Formati.percentuale(Posizione.quotaGestionePredefinita)).",
                         colore: C.avviso)
                }
                if !p.multiramoDivisa {
                    VStack(alignment: .leading, spacing: M.spazioPannello) {
                        nota("Oggi Prisma calcola questa polizza come un comparto unico: indica i rendimenti della gestione separata e dei fondi per calcoli separati.",
                             colore: C.avviso)
                        if let completa {
                            Button("Completa i dati") { completa() }
                                .buttonStyle(StileVetro(margine: M.margineAzione))
                                .help("Apre il modulo della posizione: i dati delle due parti sono nella sezione «Composizione»")
                        }
                    }
                }
                if let r = rigaSRI {
                    nota(r, colore: Colori.Analisi.kpiNota)
                }
            }
        }
        .help(MotoreMultiramo.metodo)
    }

    /// Gli euro di una parte (nil senza valore).
    private func euro(_ quota: Double) -> Double? {
        posizione.valore > 0 ? posizione.valore * quota : nil
    }

    private func nota(_ testo: String, colore: Color) -> some View {
        Text(testo)
            .font(Tipo.kpiNota)
            .foregroundColor(colore)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, M.spazioPannello)
    }

    /// «lordo 3,00% · trattenuto 1,30 · accreditato 1,70% · capitale garantito, consolidamento annuo».
    private var rigaGestione: String {
        let p = posizione
        var parti = ["lordo \(Self.percento(p.lordoGestione()))" + (origine(p.rendimentoGestione, altro: p.rendimentoFondi, quota: p.parteGestione).map { " (\($0))" } ?? "")]
        if let r = p.retrocessione {
            parti.append("retrocessione \(CifreDoc.percento(r, decimali: 0))" + (p.trattenuto.map { ", trattenuto minimo \(Self.punti($0))" } ?? ""))
        } else {
            parti.append(p.trattenuto.map { "trattenuto \(Self.punti($0))" } ?? "trattenuto non indicato")
        }
        parti.append("accreditato \(Self.percento(p.accreditatoGestione()))")
        let minimo = p.minimoGarantito ?? 0
        if minimo > 0 { parti.append("minimo \(Self.percento(minimo))") }
        switch p.consolidamento {
        case .some(true):
            parti.append("\(minimo > 0 ? "minimo garantito" : "capitale garantito"), consolidamento annuo")
        case .some(false):
            parti.append("rivalutazione anche negativa, garanzia solo a scadenza o al decesso")
        case .none:
            parti.append("consolidamento non indicato, ipotizzato annuo")
        }
        return parti.joined(separator: " · ")
    }

    /// «lordo 5,50% · costi 2,30% · netto 3,20% · SRI 4 · volatilità 14% · azioni 58%», più il bollo.
    private var rigaFondi: String {
        let p = posizione
        var parti = ["lordo \(Self.percento(p.lordoFondi()))" + (origine(p.rendimentoFondi, altro: p.rendimentoGestione, quota: p.parteFondi).map { " (\($0))" } ?? "")]
        if let c = p.costoFondi {
            parti.append("costi \(Self.percento(c))")
        } else if let c = p.costoAnnuo {
            parti.append("costi \(Self.percento(c)) (dal costo annuo)")
        } else {
            parti.append("costi non indicati")
        }
        parti.append("netto \(Self.percento(p.nettoFondi))")
        parti.append("SRI \(p.sriParteFondi)" + (p.sriFondi == nil ? " (stimato)" : ""))
        parti.append("volatilità \(Formati.percentuale((p.volatilitaParteFondi * 10).rounded() / 10))" + (p.volatilitaFondi == nil ? " (stimata)" : ""))
        if let a = p.quotaAzionariaFondi { parti.append("azioni \(Formati.percentuale(a))") }
        if p.bolloFondi > 0 { parti.append("bollo \(CifreDoc.percento(p.bolloFondi, decimali: 2))") }
        return parti.joined(separator: " · ")
    }

    private var ribilanciamento: String {
        posizione.ribilanciamento == true
            ? "annuo al \(Formati.percentuale(posizione.parteGestione * 100)) in gestione separata"
            : "nessuno (le quote cambiano con i mercati)"
    }

    /// Da dove viene il rendimento lordo di una parte, se non è indicato: ricavato dal complessivo (se c'è
    /// quello dell'altra parte), uguale al complessivo o l'ipotesi predefinita.
    private func origine(_ indicato: Double?, altro: Double?, quota: Double) -> String? {
        guard indicato == nil else { return nil }
        guard posizione.rendimentoAtteso != nil else { return "ipotesi predefinita" }
        return altro != nil && quota >= 0.1 ? "ricavato dal complessivo" : "come il complessivo"
    }

    /// La parte in fondi oltre il profilo del cliente con la combinazione dentro: non è un'incoerenza,
    /// perché per il profilo conta l'SRI della combinazione (quello del KID scelto).
    private var rigaSRI: String? {
        let p = posizione
        guard p.multiramoDivisa, let massimo = sriMassimo, p.sriParteFondi > massimo, p.sriComposto <= massimo else { return nil }
        return "La parte in fondi ha SRI \(p.sriParteFondi): la combinazione resta SRI \(p.sriComposto)\(p.sri == nil ? " (stimato)" : ""), dentro il profilo del cliente (fino a \(massimo))."
    }

    /// "3,00%"
    static func percento(_ v: Double) -> String { CifreDoc.percento(v, decimali: 2) }

    /// "1,30" (punti percentuali, senza il segno %)
    static func punti(_ v: Double) -> String { String(CifreDoc.percento(v, decimali: 2).dropLast()) }
}
