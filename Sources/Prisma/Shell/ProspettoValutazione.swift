import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il prospetto di una valutazione d'investimento: A4 verticale, quattro pagine fitte per il consulente,
/// da mostrare poi al cliente. Ricalca il prospetto di Denis su Orizzonte Valore (ottobre 2026).
enum ProspettoValutazione {
    static func pagine(_ t: TestiValutazione) -> [AnyView] {
        let pagine: [AnyView] = [AnyView(PaginaIncassi(t: t)), AnyView(PaginaDettaglio(t: t)),
                                 AnyView(PaginaCosti(t: t)), AnyView(PaginaBasi(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiValutazione.piedeAvvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

private func puntoElenco(_ testo: Text) -> some View { PuntoElenco(testo: testo) }

// MARK: - Pagina 1: quanto si incassa

private struct PaginaIncassi: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto illustrativo · Simulazione di riscatto", font: T.pOcchiello)
                Text(verbatim: t.prodotto.nome).font(T.pTitolo).foregroundColor(C.titolo)
                (Text(verbatim: "Premio unico di \(CifreDoc.euro(t.v.premio))")
                 + Text(verbatim: t.c.componenti.isEmpty ? "" : " · combinazione ") + Text(verbatim: t.c.composizione).bold()
                 + Text(verbatim: t.c.versione.isEmpty ? "" : " · \(t.c.versione)"))
                    .font(T.pSottotitolo).foregroundColor(C.testo).lineSpacing(1.5).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.v.intestatari)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.v.data)).frame(width: 90)
            }
            FilaCifre {
                CifraProspetto("Premio unico versato", CifreDoc.euro(t.e.premio), "versamento iniziale")
                CifraProspetto("Costo di ingresso", CifreDoc.euro(t.e.ingresso),
                      "\(CifreDoc.condizione(t.c.costoIngresso))" + (t.c.costoIngressoMassimo.map { ", massimo \(CifreDoc.euro($0))" } ?? ""))
                CifraProspetto("Capitale investito", CifreDoc.euro(t.e.capitale), "premio al netto del costo")
                ForEach(t.c.componenti) { p in
                    CifraProspetto(p.tipo == .gestioneSeparata ? "In Gestione separata" : "Nel Fondo Interno",
                          CifreDoc.euro(t.e.partiIniziali[p.id] ?? 0), "\(CifreDoc.condizione(p.quota)) del capitale")
                }
            }
            SezioneProspetto(titolo: "Quanto si incassa con un riscatto totale", testo: introduzione)
            TabellaIncassi(t: t, larghezza: larghezza, rigaScenario: 30, fontValore: T.pValoreScenario, fontNota: T.pTabellaNota,
                           fontTesta: T.pTabellaForte, fontEtichetta: T.pTabellaForte)
            GraficoScenariDoc(linee: linee, etichetteAsse: ["oggi"] + t.anni.map { "inizio \($0)° anno" }, premio: t.v.premio,
                              etichettePunti: false, etichetteFinali: true, bloccoIniziale: "1° anno:\nriscatto\nbloccato",
                              partenza: t.v.premio, fontAssi: T.pAssi, fontValori: T.pTabellaNota)
                .frame(height: 165)
                .background(C.riquadro.opacity(0.5))
            Text(verbatim: "Importo netto incassato con riscatto totale richiesto all'inizio di ciascun anno. Il primo tratto risente del costo di ingresso, della penale e delle imposte; il valore del contratto, invece, varia a ritmo quasi costante (dettaglio a pagina 2).")
                .font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(sintesi.enumerated()), id: \.offset) { _, p in puntoElenco(p) }
                }
            }
        }
    }

    private var introduzione: Text {
        let penali = t.c.penali.isEmpty ? "senza penali" : "con penale decrescente (\(t.c.penali.map { CifreDoc.penale($0) }.joined(separator: ", "))), dal \(t.c.annoSenzaPenali)° anno senza penale"
        return Text(verbatim: "Importi netti, cioè già al netto di costi, penali di riscatto, imposta sostitutiva e imposta di bollo. Il 1° anno è bloccato; dal \(t.primoAnno)° anno si può riscattare \(penali). ")
            + Text(verbatim: "Importi ipotetici e non garantiti").bold()
            + Text(verbatim: ", con richiesta di riscatto all'inizio di ciascun anno (ipotesi a pagina 4).")
    }

    private var linee: [LineaScenario] {
        TipoScenario.allCases.map { s in
            LineaScenario(tipo: s, punti: (t.e.scenario(s)?.riscatti ?? []).enumerated().map { ($0.offset + 1, $0.element.netto) })
        }
    }

    private var sintesi: [Text] {
        var punti: [Text] = []
        for a in t.anni.prefix(2) {
            let fav = t.e.scenario(.favorevole)?.riscatto(anno: a), sfav = t.e.scenario(.sfavorevole)?.riscatto(anno: a)
            let int = t.e.scenario(.intermedio)?.riscatto(anno: a)
            var testo = Text(verbatim: "Riscatto all'inizio del \(a)° anno").bold()
                + Text(verbatim: " (\(t.etichettaMese(a)), penale \(CifreDoc.penale(t.c.penale(anno: a)))): tra \(CifreDoc.euro(sfav?.netto ?? 0)) (\(CifreDoc.variazione(sfav?.variazione ?? 0))) e \(CifreDoc.euro(fav?.netto ?? 0)) (\(CifreDoc.variazione(fav?.variazione ?? 0))).")
            if a == t.anni.first {
                testo = testo + Text(verbatim: " Nello scenario intermedio \(CifreDoc.euro(int?.netto ?? 0)). \(t.consiglio)")
            } else {
                testo = testo + Text(verbatim: " Scenario intermedio \(CifreDoc.euro(int?.netto ?? 0)) (\(CifreDoc.variazione(int?.variazione ?? 0))).")
            }
            punti.append(testo)
        }
        if let primo = t.intermedio?.costi.first {
            punti.append(Text(verbatim: "Costi (scenario intermedio):").bold()
                         + Text(verbatim: " circa \(CifreDoc.euro((primo.totale / 10).rounded() * 10)) il primo anno, compreso il costo di ingresso, poi circa il \(CifreDoc.percento(t.incidenzaMedia)) del valore ogni anno (dettaglio a pagina 3). In caso di riscatto si aggiungono la penale e l'imposta sostitutiva sul guadagno."))
        }
        var orizzonte = ""
        if let rhp = t.c.periodoRaccomandato { orizzonte += "il periodo di detenzione raccomandato dal KID è di \(rhp) anni." }
        orizzonte += " Il 1° anno è bloccato" + (t.c.penali.isEmpty ? "." : " e dal \(t.c.annoSenzaPenali)° anno (\(t.etichettaMese(t.c.annoSenzaPenali))) non si pagano più penali.")
        punti.append(Text(verbatim: "Orizzonte del prodotto: ").bold() + Text(verbatim: orizzonte))
        return punti
    }
}

// MARK: - Pagina 2: dettaglio anno per anno

private struct PaginaDettaglio: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SezioneProspetto(titolo: "Dettaglio anno per anno", testo: Text(verbatim: introduzione))
            ForEach(TipoScenario.allCases) { s in scenario(s) }
        }
    }

    private var introduzione: String {
        let anni = t.anni.map { "\($0)°" }.joined(separator: ", ")
        var s = "Il 1° anno è bloccato. Per ogni scenario: valore del contratto e importo netto con riscatto richiesto all'inizio del \(anni) anno."
        var note: [String] = []
        if t.fondo != nil { note.append("i costi del Fondo Interno sono già nel valore delle quote") }
        if t.gestione != nil { note.append("il trattenuto della Gestione separata è già tolto dalla rivalutazione") }
        if let prima = note.first {
            let resto = note.dropFirst().map { "; " + $0 }.joined()
            let maiuscola = prima.prefix(1).uppercased() + String(prima.dropFirst())
            s += " \(maiuscola)\(resto)."
        }
        return s + recupero
    }

    /// Dal motore: il primo anno in cui, nello scenario intermedio, il riscatto restituisce almeno il premio.
    private var recupero: String {
        guard let i = t.intermedio else { return "" }
        guard let a = i.primoRecuperoPremio else {
            return " Nello scenario intermedio il riscatto non restituisce il premio entro il \(t.ultimoAnno)° anno."
        }
        return " Nello scenario intermedio il riscatto restituisce almeno il premio dal \(a.anno)° anno (\(a.mese)° mese)."
    }

    private func scenario(_ s: TipoScenario) -> some View {
        let colore = C.scenario(s)
        let sv = t.v.scenario(s)
        var descrizione = Text("")
        if let f = t.fondo {
            descrizione = descrizione + Text(verbatim: "Fondo Interno ") + Text(verbatim: "\(CifreDoc.variazione(sv.rendimento(f))) ogni anno").bold()
                + Text(verbatim: ", al netto dei suoi costi. ")
        }
        if let g = t.gestione {
            // Rivalutazione netta dal motore: trattenuto o retrocessione, con il minimo garantito se consolidato
            let lordo = sv.rendimento(g)
            descrizione = descrizione + Text(verbatim: "Gestione separata al \(CifreDoc.percento(lordo, decimali: 2)) lordo, rivalutazione netta \(CifreDoc.percento(MotoreGestioneSeparata.accreditato(g, lordo: lordo), decimali: 2)).")
        }
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Rectangle().fill(colore).frame(width: 8, height: 8)
                Text(verbatim: "Scenario \(s.nome.lowercased())").font(T.pCorpoForte).foregroundColor(C.titolo)
            }
            descrizione.font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
            TabellaDettaglio(t: t, scenario: s)
        }
    }
}

private struct TabellaDettaglio: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiValutazione
    let scenario: TipoScenario

    var body: some View {
        let anni = t.anni
        let e = t.e.scenario(scenario)
        let r = anni.map { e?.riscatto(anno: $0) }
        let colore = C.scenario(scenario)
        let h = D.rigaTabellaProspetto
        var colonne = [ColonnaDoc(titolo: "Riscatto all'inizio del…", sottotitolo: "mese · penale", peso: 2.3, destra: false)]
        colonne += anni.map { ColonnaDoc(titolo: "\($0)° anno", sottotitolo: "\(($0 - 1) * 12 + 1)° mese · \(CifreDoc.penale(t.c.penale(anno: $0)))") }
        var righe: [RigaDoc] = []
        let testo = C.testo
        func riga(_ nome: String, _ valori: [String], colore: Color? = nil, forte: Bool = false, sfondo: Color = .clear,
                  filetto: Color? = nil, spessore: CGFloat = 0.5) {
            let inchiostro = colore ?? testo
            let font = forte ? T.pTabellaForte : T.pTabella
            righe.append(RigaDoc(celle: [CellaDoc(nome, colore: inchiostro, font: font)] + valori.map { CellaDoc($0, colore: inchiostro, font: font) },
                                 altezza: h, sfondo: sfondo, filetto: filetto, spessore: spessore))
        }
        riga("Crescita del valore del contratto nell'anno", r.map { CifreDoc.variazione($0?.crescita ?? 0) }, colore: C.tenue)
        for p in t.c.componenti {
            riga("Valore in \(p.tipo.nome)", r.map { CifreDoc.euro($0?.parti[p.id] ?? 0) })
        }
        riga("Valore del contratto", r.map { CifreDoc.euro($0?.valore ?? 0) }, colore: C.titolo, forte: true, filetto: C.filettoForte, spessore: 0.8)
        riga("Penale di riscatto", r.map { ($0?.penale ?? 0) > 0.5 ? CifreDoc.togli($0?.penale ?? 0) : "—" })
        riga("Imposta sostitutiva sul guadagno", r.map { ($0?.imposta ?? 0) > 0.5 ? CifreDoc.togli($0?.imposta ?? 0) : "—" })
        if t.c.componenti.contains(where: \.bollo) {
            riga("Imposta di bollo maturata", r.map { CifreDoc.togli($0?.bollo ?? 0) })
        }
        // Nei mesi di blocco il riscatto non si può chiedere: al posto del netto, in grigio, «non riscattabile»
        let netti: [CellaDoc] = r.map { x in
            guard let a = x else { return CellaDoc("—", colore: C.tenue, font: T.pTabella) }
            guard a.possibile else { return CellaDoc("non riscattabile", colore: C.tenue, font: T.pTabella) }
            return CellaDoc(CifreDoc.euro(a.netto), colore: colore, font: T.pTabellaForte)
        }
        righe.append(RigaDoc(celle: [CellaDoc("Importo netto incassato", colore: colore, font: T.pTabellaForte)] + netti,
                             altezza: h, sfondo: C.scenarioFondo(scenario), filetto: nil, spessore: 0.5))
        riga("Guadagno o perdita netta sui \(CifreDoc.euro(t.v.premio))", r.map { CifreDoc.euroSegno($0?.guadagno ?? 0) })
        riga("Variazione sul premio versato", r.map { CifreDoc.variazione($0?.variazione ?? 0) })
        // Incidenza annua dei costi come nel KID (RIY): rendimento senza costi meno rendimento con costi e penale
        let incidenze = r.map { $0?.incidenzaCosti }
        if incidenze.contains(where: { $0 != nil }) {
            riga("Rendimento netto medio annuo", r.map { CifreDoc.variazione($0?.rendimentoMedio ?? 0, decimali: 2) }, colore: C.tenue)
            riga("Incidenza annua dei costi (RIY, come nel KID)", incidenze.map { i in i.map { CifreDoc.percento($0, decimali: 2) } ?? "—" },
                 colore: C.tenue, filetto: C.filettoForte, spessore: 0.8)
        } else {
            riga("Rendimento netto medio annuo", r.map { CifreDoc.variazione($0?.rendimentoMedio ?? 0, decimali: 2) }, colore: C.tenue,
                 filetto: C.filettoForte, spessore: 0.8)
        }
        return TabellaDoc(larghezza: larghezza, colonne: colonne, righe: righe, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota,
                          altezzaTesta: 18, margine: 4)
    }
}

// MARK: - Pagina 3: costi e penali

private struct PaginaCosti: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SezioneProspetto(titolo: "Costi e trattenute anno per anno", testo: Text(verbatim: introduzione))
            TabellaCosti(t: t, larghezza: larghezza, riga: 22, font: T.pTabella, fontForte: T.pTabellaForte, fontNota: T.pTabellaNota)
            if !t.c.penali.isEmpty { riscatto }
            Text(verbatim: t.notaCosti).font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
            if let i = t.intermedio, let primo = i.riscatti.first {
                SezioneProspetto(titolo: "Dove va il denaro con un riscatto all'inizio del \(primo.anno)° anno (\(primo.mese)° mese, scenario intermedio)")
                GraficoCascataDoc(voci: MotoreValutazione.cascata(t.e, i)).frame(height: 150)
                Text(verbatim: "Rendimento dei mercati e costi di gestione sono stime: nel contratto i costi del Fondo Interno sono già compresi nel valore delle quote e il trattenuto della Gestione separata nella rivalutazione. L'asse verticale non parte da zero.")
                    .font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
            }
            SezioneProspetto(titolo: "Quando si può riscattare e quanto costa")
            TabellaDoc(larghezza: larghezza,
                       colonne: [ColonnaDoc(titolo: "Periodo dalla decorrenza", peso: 2, destra: false), ColonnaDoc(titolo: "Riscatto", peso: 1.6, destra: false),
                                 ColonnaDoc(titolo: "Penale sul valore del contratto", peso: 1.6)],
                       righe: periodi, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            if !t.c.recesso.isEmpty {
                Text(verbatim: t.c.recesso).font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
            }
            RiquadroBarra(titolo: "Se il bisogno di liquidità è probabile") {
                (Text(verbatim: "Aspettare il \(t.etichettaMese((t.anni.first ?? 2) + 1))").bold()
                 + Text(verbatim: " invece del \(t.etichettaMese(t.anni.first ?? 2)): " + t.aspettareConviene.replacingOccurrences(of: "Nello scenario intermedio, ", with: "nello scenario intermedio "))
                 + Text(verbatim: t.c.riscattoParziale.isEmpty ? "" : " Se serve solo una parte del capitale, ").bold()
                 + Text(verbatim: t.c.riscattoParziale.isEmpty ? "" : t.c.riscattoParziale.prefix(1).lowercased() + t.c.riscattoParziale.dropFirst()))
                    .font(T.pCorpo).foregroundColor(C.testo).lineSpacing(1.6).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var introduzione: String {
        var s = "Scenario intermedio."
        if let fav = t.e.scenario(.favorevole)?.costi, let sfav = t.e.scenario(.sfavorevole)?.costi, fav.count > 1, sfav.count > 1 {
            let tondo: (Double) -> String = { CifreDoc.euro(($0 / 10).rounded() * 10) }
            s += " Negli altri scenari i costi correnti cambiano in proporzione al valore investito: dal 2° al \(fav.count)° anno vanno da circa \(tondo(fav[1].totale)) a \(tondo(fav[fav.count - 1].totale)) l'anno nel favorevole e da circa \(tondo(sfav[1].totale)) a \(tondo(sfav[sfav.count - 1].totale)) nello sfavorevole."
        }
        return s
    }

    private var riscatto: some View {
        let anni = t.anni
        let r = anni.map { t.intermedio?.riscatto(anno: $0) }
        let costi = t.intermedio?.costi.count ?? 0
        var colonne = [ColonnaDoc(titolo: "In caso di riscatto all'inizio del…", peso: 3.4, destra: false)]
        colonne += anni.prefix(costi).map { ColonnaDoc(titolo: "\($0)° anno", sottotitolo: "dal \(($0 - 1) * 12 + 1)° mese") }
        colonne.append(ColonnaDoc(titolo: "", peso: 1.2))
        let penale = RigaDoc(celle: [CellaDoc("Penale di riscatto", sotto: "\(t.elencoPenali) \(t.anniPenali), poi nessuna", font: T.pTabella)]
                                + r.prefix(costi).map { CellaDoc(($0?.penale ?? 0) > 0.5 ? CifreDoc.togli($0?.penale ?? 0) : "—", font: T.pTabella) },
                             altezza: 20)
        let imposta = RigaDoc(celle: [CellaDoc("Imposta sostitutiva", sotto: "circa \(CifreDoc.percento(t.aliquotaMedia.rounded(), decimali: 0)) sul guadagno rispetto ai premi versati", font: T.pTabella)]
                                 + r.prefix(costi).map { CellaDoc(($0?.imposta ?? 0) > 0.5 ? CifreDoc.togli($0?.imposta ?? 0) : "—", font: T.pTabella) },
                              altezza: 20, filetto: C.filettoForte, spessore: 0.8)
        return TabellaDoc(larghezza: larghezza, colonne: colonne, righe: [penale, imposta], fontTesta: T.pTabellaTesta,
                          fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
    }

    private var periodi: [RigaDoc] {
        var righe = [RigaDoc(celle: [CellaDoc("Primi \(t.c.mesiBloccoRiscatto) mesi", font: T.pTabella), CellaDoc("non consentito", font: T.pTabella),
                                     CellaDoc("—", font: T.pTabella)], altezza: 14)]
        for (i, p) in t.c.penali.enumerated() {
            righe.append(RigaDoc(celle: [CellaDoc("Dal \((i + 1) * 12 + 1)° al \((i + 2) * 12)° mese (\(i + 2)ª annualità)", font: T.pTabella),
                                         CellaDoc("consentito", font: T.pTabella), CellaDoc(CifreDoc.penale(p), font: T.pTabella)], altezza: 14))
        }
        righe.append(RigaDoc(celle: [CellaDoc("Dal \((t.c.annoSenzaPenali - 1) * 12 + 1)° mese in poi", font: T.pTabella),
                                     CellaDoc("consentito", font: T.pTabella), CellaDoc("nessuna", font: T.pTabella)],
                             altezza: 14, filetto: C.filettoForte, spessore: 0.8))
        return righe
    }
}

// MARK: - Pagina 4: su cosa si basano gli scenari

private struct PaginaBasi: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiValutazione

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SezioneProspetto(titolo: "Su cosa si basano gli scenari")
            HStack(alignment: .top, spacing: 18) {
                if let f = t.fondo, !f.storico.isEmpty { storicoFondo(f) }
                if let g = t.gestione, !g.storico.isEmpty { storicoGestione(g) }
            }
            SezioneProspetto(titolo: "Ipotesi dei tre scenari")
            TabellaDoc(larghezza: larghezza, colonne: colonneIpotesi, righe: righeIpotesi, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            if !t.c.scenariKID.isEmpty {
                SezioneProspetto(titolo: "Confronto con gli scenari ufficiali del KID",
                                 testo: Text(verbatim: "Rendimento medio annuo al lordo delle imposte. " + t.c.esempioKID))
                TabellaKID(t: t, larghezza: larghezza, riga: 14, font: T.pTabella, fontTesta: T.pTabellaTesta, fontNota: T.pTabellaNota)
                Text(verbatim: t.commentoKID).font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
            }
            if let frase = t.fraseIncidenzaCosti {
                Text(verbatim: frase).font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
            }
            SezioneProspetto(titolo: "Garanzie e fiscalità")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array((t.c.garantito + t.c.nonGarantito).enumerated()), id: \.offset) { _, g in puntoElenco(Text(verbatim: g)) }
                if let frase = t.fraseGaranziaGestione {
                    puntoElenco(Text(verbatim: "Gestione separata: ").bold() + Text(verbatim: frase))
                }
                puntoElenco(Text(verbatim: "Imposta sostitutiva: ").bold() + Text(verbatim: t.testoImposta))
                if t.c.componenti.contains(where: \.bollo) {
                    puntoElenco(Text(verbatim: "Imposta di bollo: ").bold() + Text(verbatim: "\(CifreDoc.percento(t.c.bollo, decimali: 2)) " + t.testoBollo))
                }
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold() + Text(verbatim: t.avvertenze))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            if !t.c.fonti.isEmpty {
                (Text(verbatim: "Fonti. ").bold() + Text(verbatim: t.c.fonti))
                    .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            }
            FirmeProspetto()
        }
    }

    private func storicoFondo(_ f: ComponenteContratto) -> some View {
        var righe: [RigaDoc] = []
        var precedente: Double?
        let anno = String(f.storico.last { $0.valore != nil }?.etichetta.suffix(4) ?? "")
        for (i, p) in f.storico.enumerated() {
            var variazione = "—"
            if let v = p.valore, let prima = precedente, prima > 0 {
                let d = CifreDoc.variazione((v / prima - 1) * 100)
                variazione = i == f.storico.count - 1 ? "\(d) da inizio anno" : "\(d) fino a fine \(p.etichetta.suffix(4))"
            }
            righe.append(RigaDoc(celle: [CellaDoc(p.etichetta, font: T.pTabella), CellaDoc(p.valore.map { quota($0) + " €" } ?? "n.d.", font: T.pTabella),
                                         CellaDoc(variazione, font: T.pTabella)], altezza: 13))
            if let v = p.valore { precedente = v }
        }
        if let d = t.fondoDalLancio {
            righe.append(RigaDoc(celle: [CellaDoc("Dal lancio", font: T.pTabellaForte), CellaDoc(CifreDoc.variazione(d), font: T.pTabellaForte),
                                         CellaDoc(anno.isEmpty ? "" : "al \(f.storico.last?.etichetta ?? "")", font: T.pTabella)],
                                 altezza: 13, filetto: C.filettoForte, spessore: 0.8))
        }
        let w = (larghezza - 18) / 2
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: f.nomeCompleto).font(T.pSottosezione).foregroundColor(C.titolo)
            TabellaDoc(larghezza: w, colonne: [ColonnaDoc(titolo: "Data", peso: 1.2, destra: false), ColonnaDoc(titolo: "Valore quota"),
                                               ColonnaDoc(titolo: "Variazione", peso: 1.4)],
                       righe: righe, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 3)
            Text(verbatim: f.caratteristiche).font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: w, alignment: .topLeading)
    }

    private func storicoGestione(_ g: ComponenteContratto) -> some View {
        let w = (larghezza - 18) / 2
        let note = g.storico.filter { !$0.nota.isEmpty }.map { "*\($0.nota)" }
        let righe = g.storico.map { p in
            RigaDoc(celle: [CellaDoc(p.etichetta, font: T.pTabella),
                            CellaDoc(p.valore.map { CifreDoc.percento($0, decimali: 2) } ?? "n.d.\(p.nota.isEmpty ? "" : "*")", font: T.pTabella)],
                    altezza: 13)
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: g.nomeCompleto).font(T.pSottosezione).foregroundColor(C.titolo)
            TabellaDoc(larghezza: w, colonne: [ColonnaDoc(titolo: "Anno", destra: false), ColonnaDoc(titolo: "Rendimento lordo")],
                       righe: righe, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 3)
            Text(verbatim: ([g.caratteristiche] + note).filter { !$0.isEmpty }.joined(separator: " "))
                .font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: w, alignment: .topLeading)
    }

    private func quota(_ v: Double) -> String {
        let n = NumberFormatter()
        n.locale = Formati.localeImporti
        n.numberStyle = .decimal
        n.minimumFractionDigits = 3
        n.maximumFractionDigits = 3
        return n.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private var colonneIpotesi: [ColonnaDoc] {
        var c = [ColonnaDoc(titolo: "Scenario", peso: 1.1, destra: false)]
        if t.fondo != nil { c.append(ColonnaDoc(titolo: "Fondo Interno, netto", peso: 1.1, destra: false)) }
        if t.gestione != nil { c.append(ColonnaDoc(titolo: "Gestione separata", peso: 1, destra: false)) }
        c.append(ColonnaDoc(titolo: "Perché", peso: 3.6, destra: false))
        return c
    }

    private var righeIpotesi: [RigaDoc] {
        TipoScenario.allCases.map { s in
            let sv = t.v.scenario(s)
            var celle = [CellaDoc("■ \(s.nome)", colore: C.scenario(s), font: T.pTabellaForte)]
            if let f = t.fondo { celle.append(CellaDoc("\(CifreDoc.variazione(sv.rendimento(f))) ogni anno", font: T.pTabella)) }
            if let g = t.gestione {
                let lordo = sv.rendimento(g)
                celle.append(CellaDoc("\(CifreDoc.percento(lordo, decimali: 2)) → \(CifreDoc.percento(MotoreGestioneSeparata.accreditato(g, lordo: lordo), decimali: 2))", font: T.pTabella))
            }
            var perche = CellaDoc(sv.perche, font: T.pTabellaNota)
            perche.righe = 3
            celle.append(perche)
            return RigaDoc(celle: celle, altezza: 24)
        }
    }
}
