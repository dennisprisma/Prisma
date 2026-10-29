import SwiftUI

private typealias T = Tipo.Documento

/// Il prospetto dei costi: A4 verticale, per il consulente. Prima pagina posizione per posizione, poi
/// l'incidenza annua dei costi come nel KID, infine il peso nel tempo, le alternative, il metodo e le firme.
enum ProspettoCosti {
    /// `prodotti`: le schede del catalogo, se chi prepara il documento le passa (periodo raccomandato, penali
    /// e RIY dichiarato della scheda); senza, valgono i dati della posizione.
    static func pagine(_ t: TestiCosti, prodotti: [Prodotto] = []) -> [AnyView] {
        let incidenze = Self.incidenze(t, prodotti: prodotti)
        var pagine: [AnyView] = [AnyView(PaginaCostiOggi(t: t))]
        if !incidenze.isEmpty { pagine.append(AnyView(PaginaIncidenzaKID(t: t, incidenze: incidenze))) }
        pagine.append(AnyView(PaginaCostiTempo(t: t)))
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiCosti.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }

    /// L'incidenza annua dei costi come nel KID (RIY) di ogni posizione con i costi, nello stesso ordine
    /// dell'analisi. Si calcola qui, per il documento: non dentro `MotoreCosti.calcola`, che usa anche Eve.
    static func incidenze(_ t: TestiCosti, prodotti: [Prodotto] = []) -> [IncidenzaCostiKID] {
        t.a.voci.compactMap { v -> IncidenzaCostiKID? in
            let prodotto = v.posizione.prodottoId.flatMap { id in prodotti.first { $0.id == id } }
            return MotoreCosti.incidenzaKID(v.posizione, prodotto: prodotto, data: t.data)
        }
    }
}

// MARK: - Pagina 1: quanto costano oggi

private struct PaginaCostiOggi: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCosti

    private var a: AnalisiCosti { t.a }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Costi", font: T.pOcchiello)
                Text(verbatim: "Il costo degli investimenti di \(t.cliente)").font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: "Posizioni finanziarie in essere: costi, peso nel tempo, alternative · situazione al \(CifreDoc.data(t.data))")
                    .font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            FilaCifre {
                CifraProspetto("Valore", CifreDoc.euro(a.valore), "\(a.voci.count) \(a.voci.count == 1 ? "posizione" : "posizioni") con i costi")
                CifraProspetto("Quest'anno", CifreDoc.euro(a.euroAnno), a.costoMedio.map { "media \(CifreDoc.percento($0, decimali: 2)) l'anno" } ?? "")
                CifraProspetto("In 10 anni", CifreDoc.togli(a.perso10), "rendimenti persi compresi", colore: C.negativo)
                CifraProspetto("In 20 anni", CifreDoc.togli(a.perso20), "o fino alla scadenza", colore: C.negativo)
                CifraProspetto("Risparmio possibile", a.risparmioPossibile > 0 ? CifreDoc.euro(a.risparmioPossibile) : "—", "a parità di rischio, 10 anni",
                               colore: a.risparmioPossibile > 0 ? C.positivo : nil)
            }
            SezioneProspetto(titolo: "Posizione per posizione",
                             testo: Text(verbatim: "Costo annuo complessivo (gestione e trattenuto) e d'ingresso; quanto tolgono al netto finale, imposte e bollo esclusi."))
            TabellaCanali(colonne: [
                ColonnaDoc(titolo: "Posizione", sottotitolo: "tipologia", peso: 2.3, destra: false), ColonnaDoc(titolo: "Valore", peso: 0.9),
                ColonnaDoc(titolo: "Ingresso", peso: 0.7), ColonnaDoc(titolo: "Annuo", sottotitolo: "giudizio", peso: 0.9),
                ColonnaDoc(titolo: "Quest'anno", peso: 0.9), ColonnaDoc(titolo: "10 anni", peso: 0.9), ColonnaDoc(titolo: "20 anni", sottotitolo: "o scadenza", peso: 0.9),
            ], gruppi: Canale.allCases.compactMap { c in
                let mie = a.voci.prefix(Misure.Documento.righeTabellaFissa).filter { $0.posizione.canale == c }
                guard !mie.isEmpty else { return nil }
                return GruppoCanale(canale: c, righe: mie.map { v in
                    RigaDoc(celle: [CellaDoc(v.posizione.nome, sotto: v.posizione.tipologia, font: T.pTabellaForte),
                                    CellaDoc(CifreDoc.euro(v.posizione.valore), font: T.pTabella),
                                    CellaDoc(v.ingresso > 0 ? CifreDoc.condizione(v.ingresso) : "—", font: T.pTabella),
                                    CellaDoc(CifreDoc.percento(v.annuo, decimali: 2), sotto: v.livello.nome, colore: v.livello == .alto ? C.negativo : nil, font: T.pTabellaForte),
                                    CellaDoc(CifreDoc.euro(v.euroAnno), font: T.pTabella),
                                    CellaDoc(CifreDoc.togli(v.perso10), font: T.pTabella),
                                    CellaDoc(CifreDoc.togli(v.perso20), sotto: v.anni20 < MotoreCosti.orizzonti.1 ? "\(v.anni20) anni" : "", colore: C.negativo, font: T.pTabellaForte)],
                            altezza: 22)
                }, nota: "\(CifreDoc.euro(mie.reduce(0) { $0 + $1.euroAnno })) quest'anno")
            })
            Altre(numero: a.voci.count - Misure.Documento.righeTabellaFissa)
            if !a.senzaDati.isEmpty {
                Text(verbatim: "Senza costi indicati (da completare con il KID): \(a.senzaDati.map(\.nome).joined(separator: ", ")).")
                    .font(T.pCorpo).foregroundColor(C.intermedio).fixedSize(horizontal: false, vertical: true)
            }
            SezioneProspetto(titolo: "Cosa offrono in cambio")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(a.voci.prefix(6)) { v in
                    PuntoElenco(testo: Text(verbatim: "\(v.posizione.nome) (\(CifreDoc.percento(v.annuo, decimali: 2))): ").bold() + Text(verbatim: TestiCosti.inCambio(v.posizione)))
                }
            }
        }
    }
}

// MARK: - Pagina 2: incidenza annua dei costi come nel KID

private struct PaginaIncidenzaKID: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCosti
    let incidenze: [IncidenzaCostiKID]

    private typealias M = Misure.Documento.Motori

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Incidenza annua dei costi, come nel KID",
                             testo: Text(verbatim: "Di quanto i costi di ogni prodotto abbassano il rendimento medio annuo (RIY, «reduction in yield»): rendimento senza costi meno rendimento con i costi, uscendo dopo 1 anno, a metà e alla fine del periodo raccomandato. Accanto, il dato dichiarato nel KID, da confrontare con il calcolo di Prisma."))
            TabellaCanali(colonne: [
                ColonnaDoc(titolo: "Posizione", sottotitolo: "periodo raccomandato", peso: 2.4, destra: false),
                ColonnaDoc(titolo: "Dopo 1 anno", peso: 0.9),
                ColonnaDoc(titolo: "A metà", sottotitolo: "del periodo", peso: 0.9),
                ColonnaDoc(titolo: "Alla fine", sottotitolo: "del periodo", peso: 0.9),
                ColonnaDoc(titolo: "Nel KID", sottotitolo: "dichiarato", peso: 0.9),
                ColonnaDoc(titolo: "Differenza", sottotitolo: "calcolo − KID", peso: 0.95),
            ], gruppi: Canale.allCases.compactMap { c -> GruppoCanale? in
                let mie = incidenze.prefix(Misure.Documento.righeTabellaFissa).filter { $0.posizione.canale == c }
                guard !mie.isEmpty else { return nil }
                return GruppoCanale(canale: c, righe: mie.map { riga($0) }, nota: mie.count == 1 ? "1 posizione" : "\(mie.count) posizioni")
            })
            Altre(numero: incidenze.count - Misure.Documento.righeTabellaFissa)
            if let k = piuCara, k.annoPerAnno.count > 1 {
                SezioneProspetto(titolo: "Come cambia con gli anni: \(k.posizione.nome)",
                                 testo: Text(verbatim: "Incidenza annua dei costi uscendo alla fine di ciascun anno, fino al periodo raccomandato (al massimo \(M.anniIncidenza) anni). Nei primi anni pesano di più il costo d'ingresso e le penali; poi si distribuiscono su più anni."))
                GraficoBarreDoc(punti: k.annoPerAnno.prefix(M.anniIncidenza).map { ("\($0.anni)", $0.riy) }, colore: C.intermedio,
                                fontValori: T.pTabellaNota, fontAssi: T.pAssi)
                    .frame(height: M.graficoIncidenza)
            }
            RiquadroBarra(titolo: "Come leggerla") {
                VStack(alignment: .leading, spacing: 4) {
                    PuntoElenco(testo: Text(verbatim: "Punti di rendimento all'anno: ").bold()
                                + Text(verbatim: "un RIY dell'1% vuol dire che, con i costi, il prodotto rende ogni anno circa un punto in meno di quanto renderebbe senza."))
                    PuntoElenco(testo: Text(verbatim: "Uscire presto costa di più: ").bold()
                                + Text(verbatim: "il costo d'ingresso e le penali si dividono su pochi anni."))
                    PuntoElenco(testo: Text(verbatim: "Calcolo e KID: ").bold()
                                + Text(verbatim: "se il calcolo supera il dato del KID di oltre \(sogliaScarto) punti, conviene rileggere il KID: costi o periodo registrati possono essere diversi."))
                }
            }
            Text(verbatim: IncidenzaCostiKID.metodo + " Stime con i rendimenti ipotizzati, non garantiti.")
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "0,3": la soglia oltre cui il calcolo pesa più del KID.
    private var sogliaScarto: String {
        Formati.numeroFormatter.string(from: NSNumber(value: CompositoreProspetti.sogliaScartoKID)) ?? "0,3"
    }

    /// La posizione con l'incidenza più alta al periodo raccomandato.
    private var piuCara: IncidenzaCostiKID? {
        incidenze.max { ($0.calcolato ?? 0) < ($1.calcolato ?? 0) }
    }

    private func riga(_ k: IncidenzaCostiKID) -> RigaDoc {
        let periodi = k.periodi
        let unAnno = periodi.first { $0.anni == 1 }
        let meta: IncidenzaCostiKID.Periodo? = periodi.count >= 3 ? periodi[1] : nil
        let fine = periodi.last
        func cella(_ q: IncidenzaCostiKID.Periodo?, forte: Bool) -> CellaDoc {
            guard let q else { return CellaDoc("—", colore: C.tenue, font: T.pTabella) }
            return CellaDoc(CifreDoc.percento(q.riy, decimali: 2), sotto: q.anni == 1 ? "" : "\(q.anni) anni", font: forte ? T.pTabellaForte : T.pTabella)
        }
        let scarto: CellaDoc
        if let s = k.scarto {
            let alto = s > CompositoreProspetti.sogliaScartoKID
            scarto = CellaDoc(CifreDoc.variazione(s, decimali: 2), sotto: alto ? "pesano di più" : "in linea", colore: alto ? C.negativo : nil, font: T.pTabella)
        } else {
            scarto = CellaDoc("—", colore: C.tenue, font: T.pTabella)
        }
        let anni = k.periodoRaccomandato == 1 ? "1 anno" : "\(k.periodoRaccomandato) anni"
        return RigaDoc(celle: [
            CellaDoc(k.posizione.nome, sotto: anni + (k.posizione.periodoRaccomandato != nil ? " · dal KID" : ""), font: T.pTabellaForte),
            cella(unAnno, forte: false), cella(meta, forte: false), cella(fine, forte: true),
            CellaDoc(k.dichiarato.map { CifreDoc.percento($0, decimali: 2) } ?? "non indicato", colore: k.dichiarato == nil ? C.tenue : nil, font: T.pTabella),
            scarto,
        ], altezza: M.rigaTabella)
    }
}

// MARK: - Pagina 3: nel tempo, alternative, metodo

private struct PaginaCostiTempo: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiCosti

    private var a: AnalisiCosti { t.a }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Con e senza costi, anno per anno",
                             testo: Text(verbatim: "Valore complessivo delle posizioni con i rendimenti ipotizzati, prima delle imposte finali; le posizioni che scadono restano ferme al valore della scadenza."))
            GraficoLineeDoc(serie: [SerieDoc(nome: "Senza costi", colore: C.favorevole, valori: t.serie.senza, tratteggio: true),
                                    SerieDoc(nome: "Con i costi", colore: C.intermedio, valori: t.serie.con)],
                            etichetteAsse: t.etichetteAsse, fontAssi: T.pTabellaNota, fontValori: T.pTabellaNota)
                .frame(height: Misure.Documento.graficoCosti)
            SezioneProspetto(titolo: "Alternative a parità di rischio")
            if a.conAlternativa.isEmpty {
                Text(verbatim: "Nel catalogo non c'è un prodotto con la stessa area e lo stesso indicatore di rischio che, dopo l'uscita, lasci almeno \(CifreDoc.euro(MotoreCosti.guadagnoMinimo)) in più in 10 anni.")
                    .font(T.pCorpo).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
            } else {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Oggi", sottotitolo: "costo annuo", peso: 2, destra: false), ColonnaDoc(titolo: "Alternativa", sottotitolo: "canale · costo", peso: 2.2, destra: false),
                    ColonnaDoc(titolo: "Uscita oggi", sottotitolo: "penali, imposte, ingresso", peso: 1.1), ColonnaDoc(titolo: "In più", sottotitolo: "netto, uscita compresa", peso: 1.1),
                ], gruppi: Canale.allCases.compactMap { c in
                    let mie = a.conAlternativa.prefix(Misure.Documento.puntiReport).filter { $0.posizione.canale == c }
                    guard !mie.isEmpty else { return nil }
                    return GruppoCanale(canale: c, righe: mie.compactMap { v in
                        guard let x = v.alternativa else { return nil }
                        return RigaDoc(celle: [CellaDoc(v.posizione.nome, sotto: CifreDoc.percento(v.annuo, decimali: 2), font: T.pTabellaForte),
                                               CellaDoc(x.prodotto.nome, sotto: "\(x.prodotto.canale.nomeBreve) · \(CifreDoc.percento(x.costoAnnuo, decimali: 2))", font: T.pTabellaForte),
                                               CellaDoc(x.costoUscita >= 0.5 ? CifreDoc.togli(x.costoUscita) : "—", font: T.pTabella),
                                               CellaDoc("+ \(CifreDoc.euro(x.guadagno))", sotto: "in \(x.anni) anni", colore: C.positivo, font: T.pTabellaForte)], altezza: 22)
                    }, nota: "")
                })
            }
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(t.sintesi.enumerated()), id: \.offset) { _, p in
                        PuntoElenco(testo: Text(verbatim: "\(p.0): ").bold() + Text(verbatim: p.1))
                    }
                }
            }
            SezioneProspetto(titolo: "Prossimi passi")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(t.prossimiPassi.enumerated()), id: \.offset) { _, p in PuntoElenco(testo: Text(verbatim: p)) }
            }
            SezioneProspetto(titolo: "Ipotesi e metodo")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(t.metodo.enumerated()), id: \.offset) { _, n in PuntoElenco(testo: Text(verbatim: n)) }
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold()
             + Text(verbatim: "Un costo più alto può remunerare garanzie, coperture o servizi: il confronto riguarda i costi a parità di rischio, non la scelta del prodotto, che si fa con il KID e il confronto completo."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }
}
