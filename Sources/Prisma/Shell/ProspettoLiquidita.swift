import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il prospetto del capitale in scadenza e della liquidità: A4 verticale, per il consulente.
enum ProspettoLiquidita {
    static func pagine(_ t: TestiLiquidita) -> [AnyView] {
        let pagine: [AnyView] = [AnyView(PaginaCapitali(t: t)), AnyView(PaginaSalvadanai(t: t))]
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiLiquidita.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

// MARK: - Pagina 1: cosa arriva e cosa c'è

private struct PaginaCapitali: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiLiquidita

    private var e: EsitoLiquidita { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Capitale in scadenza e liquidità", font: T.pOcchiello)
                Text(verbatim: "La liquidità di \(t.cliente)").font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: "Capitali in scadenza nei prossimi \(IpotesiLiquidita.finestraMesi) mesi e conti · situazione al \(CifreDoc.data(t.data))")
                    .font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            FilaCifre {
                CifraProspetto("In scadenza", CifreDoc.euro(e.nettoInScadenza), e.scadenze.isEmpty ? "nessuna posizione" : "netto, \(e.scadenze.count) \(e.scadenze.count == 1 ? "posizione" : "posizioni")")
                CifraProspetto("Liquidità oggi", CifreDoc.euro(e.liquiditaAttuale), "conti e depositi")
                CifraProspetto("Totale disponibile", CifreDoc.euro(e.totale), "da destinare")
                CifraProspetto("Riserva", CifreDoc.euro(e.riservaNecessaria), "\(e.mesiRiserva) mesi × \(CifreDoc.euro(e.fabbisognoMensile))")
                CifraProspetto("Eccedenza", CifreDoc.euro(e.eccedenza), "oltre la riserva", colore: e.eccedenza > 0.5 ? C.intermedio : nil)
            }
            SezioneProspetto(titolo: "I capitali in scadenza",
                             testo: Text(verbatim: "Valore di oggi, imposta sul guadagno e bollo maturato: il netto che arriva alla scadenza (la cifra definitiva la comunica la compagnia)."))
            if e.scadenze.isEmpty {
                Text(verbatim: "Nessuna posizione scade nei prossimi \(IpotesiLiquidita.finestraMesi) mesi.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Posizione", sottotitolo: "tipologia", peso: 2.4, destra: false), ColonnaDoc(titolo: "Scadenza", peso: 0.9),
                    ColonnaDoc(titolo: "Valore", sottotitolo: "versato", peso: 1.1), ColonnaDoc(titolo: "Imposta", sottotitolo: "aliquota", peso: 1),
                    ColonnaDoc(titolo: "Bollo", peso: 0.8), ColonnaDoc(titolo: "Netto", peso: 1.1),
                ], gruppi: Canale.allCases.compactMap { c in
                    let mie = e.scadenze.filter { $0.posizione.canale == c }
                    guard !mie.isEmpty else { return nil }
                    return GruppoCanale(canale: c, righe: mie.map { s in
                        let f = s.fisco
                        return RigaDoc(celle: [CellaDoc(s.posizione.nome, sotto: s.posizione.tipologia, font: T.pTabellaForte),
                                               CellaDoc(CifreDoc.dataBreve(s.data), colore: s.scaduto ? C.negativo : nil, font: T.pTabella),
                                               CellaDoc(CifreDoc.euroCentesimi(f.valore), sotto: "versato \(CifreDoc.euro(f.versato))", font: T.pTabella),
                                               CellaDoc(f.imposta > 0.005 ? CifreDoc.togliCentesimi(f.imposta) : "—", sotto: f.imposta > 0.005 ? CifreDoc.percento(f.aliquota, decimali: 2) : "",
                                                        colore: C.negativo, font: T.pTabella),
                                               CellaDoc(f.bolloMaturato > 0.005 ? CifreDoc.togliCentesimi(f.bolloMaturato) : "—", font: T.pTabella),
                                               CellaDoc(CifreDoc.euroCentesimi(f.netto), font: T.pTabellaForte)], altezza: 22)
                    }, nota: mie.count == 1 ? "1 posizione" : "\(mie.count) posizioni")
                })
            }
            SezioneProspetto(titolo: "La liquidità di oggi")
            if e.liquidita.isEmpty {
                Text(verbatim: "Nessun conto indicato nelle Posizioni.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [ColonnaDoc(titolo: "Conto", sottotitolo: "emittente", peso: 3, destra: false), ColonnaDoc(titolo: "Saldo", peso: 1.2),
                                        ColonnaDoc(titolo: "Bollo", sottotitolo: "in un anno", peso: 1)],
                              gruppi: Canale.allCases.compactMap { c in
                                  let mie = e.liquidita.filter { $0.canale == c }
                                  guard !mie.isEmpty else { return nil }
                                  return GruppoCanale(canale: c, righe: mie.map { p in
                                      let bollo = MotoreFiscale.bolloAnnuo(p, valore: p.valore)
                                      return RigaDoc(celle: [CellaDoc(p.nome, sotto: p.emittente, font: T.pTabellaForte), CellaDoc(CifreDoc.euroCentesimi(p.valore), font: T.pTabella),
                                                             CellaDoc(bollo > 0.005 ? CifreDoc.euroCentesimi(bollo) : "—", font: T.pTabella)], altezza: 20)
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
        }
    }
}

// MARK: - Pagina 2: i salvadanai, il costo dell'attesa, metodo

private struct PaginaSalvadanai: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiLiquidita

    private var e: EsitoLiquidita { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Come destinarli: quattro salvadanai per orizzonte",
                             testo: Text(verbatim: "Prima la riserva di emergenza, poi gli obiettivi vicini e di medio periodo (quanto manca a ciascuno), il resto alla crescita."))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Salvadanaio", sottotitolo: "orizzonte", peso: 1.6, destra: false),
                                                       ColonnaDoc(titolo: "Importo", peso: 0.9), ColonnaDoc(titolo: "Quota", peso: 0.6),
                                                       ColonnaDoc(titolo: "Strumenti indicativi", sottotitolo: "rendimento lordo", peso: 2.4, destra: false),
                                                       ColonnaDoc(titolo: "Per", peso: 2.2, destra: false)],
                       righe: e.salvadanai.map { s in
                           var per = CellaDoc(s.obiettivi.isEmpty ? s.perche : s.obiettivi.map(\.titolo).joined(separator: ", "), colore: C.tenue, font: T.pTabellaNota)
                           per.righe = 2
                           var strumenti = CellaDoc(s.strumenti, sotto: "circa \(CifreDoc.condizione(s.rendimento)) l'anno", font: T.pTabella)
                           strumenti.righe = 2
                           return RigaDoc(celle: [CellaDoc(s.titolo, sotto: s.orizzonte, font: T.pTabellaForte), CellaDoc(CifreDoc.euro(s.importo), font: T.pTabellaForte),
                                                  CellaDoc(CifreDoc.percento(e.totale > 0 ? s.importo / e.totale * 100 : 0, decimali: 0), font: T.pTabella),
                                                  strumenti, per], altezza: 30)
                       }, fontTesta: T.pTabellaTesta, fontTestaSotto: T.pTabellaNota, altezzaTesta: 18, margine: 4)
            SezioneProspetto(titolo: "Fermi sul conto o destinati: dopo \(IpotesiLiquidita.anniConfronto) anni, in euro di oggi",
                             testo: Text(verbatim: "Rendimenti netti del 26%, tolta l'inflazione del \(CifreDoc.condizione(IpotesiCalcolo.inflazione)) annuo."))
            FilaCifre {
                CifraProspetto("Oggi", CifreDoc.euro(e.totale), "totale disponibile")
                CifraProspetto("Tutto fermo sul conto", CifreDoc.euro(e.realeFermo), "al \(CifreDoc.condizione(IpotesiLiquidita.conto)) lordo", colore: C.negativo)
                CifraProspetto("Destinati", CifreDoc.euro(e.realeDestinato), "nei quattro salvadanai", colore: C.positivo)
                CifraProspetto("Differenza", CifreDoc.euroSegno(e.vantaggioDestinare), "potere d'acquisto")
            }
            if !e.proposte.isEmpty {
                SezioneProspetto(titolo: "Proposte aperte che possono accogliere il capitale")
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(e.proposte) { p in
                        PuntoElenco(testo: Text(verbatim: p.nome).bold()
                                    + Text(verbatim: " · \(p.canale.nome) · \(p.area.nome.lowercased())" + (p.rendimentoAtteso.map { " · rendimento ipotizzato \(CifreDoc.condizione($0))" } ?? "")))
                    }
                }
            }
            SezioneProspetto(titolo: "Ipotesi e metodo")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(e.note.enumerated()), id: \.offset) { _, n in PuntoElenco(testo: Text(verbatim: n)) }
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold()
             + Text(verbatim: "La ripartizione è un'indicazione per orizzonte temporale e non una raccomandazione su prodotti specifici. I rendimenti indicati sono ipotesi e non sono garantiti."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }
}
