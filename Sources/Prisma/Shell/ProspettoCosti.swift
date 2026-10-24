import SwiftUI

private typealias T = Tipo.Documento

/// Il prospetto dei costi: A4 verticale, per il consulente. Prima pagina posizione per posizione,
/// seconda il peso nel tempo, le alternative, il metodo e le firme.
enum ProspettoCosti {
    static func pagine(_ t: TestiCosti) -> [AnyView] {
        let pagine: [AnyView] = [AnyView(PaginaCostiOggi(t: t)), AnyView(PaginaCostiTempo(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiCosti.avvertenza, numero: i + 1, totale: pagine.count) { p })
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
            HStack(spacing: 6) {
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

// MARK: - Pagina 2: nel tempo, alternative, metodo

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
