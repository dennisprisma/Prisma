import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

// La scheda di adeguatezza su carta (giro 4, specifica 1): A4 verticale, due pagine, carta bianca e colori
// fissi. Pagina 1: i controlli con il pallino colorato e i riferimenti. Pagina 2: a cosa risponde, esperienza
// del cliente, documenti consegnati con le caselle, dichiarazioni, avvertenze e le tre righe per le firme.
// Non è un `SceltaProspetto` (toccherebbe Eve): si costruisce dal dettaglio della proposta.

extension DocumentoStampabile {
    /// La scheda di adeguatezza di una proposta: A4 verticale, due pagine, da firmare.
    init(_ t: PaginaDatiAdeguatezza) {
        titolo = t.proposta.nome
        cliente = t.cliente
        genere = TestiAdeguatezza.genere
        formato = Misure.Documento.prospetto
        pagine = ProspettoAdeguatezza.pagine(t)
        tipo = .prospetto
    }
}

enum ProspettoAdeguatezza {
    static func pagine(_ t: PaginaDatiAdeguatezza) -> [AnyView] {
        let avvertenza = TestiAdeguatezza.avvertenzaBreve
        return [
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: avvertenza, numero: 1, totale: 2) { PaginaControlliAdeguatezza(t: t) }),
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: avvertenza, numero: 2, totale: 2) { PaginaDocumentiAdeguatezza(t: t) }),
        ]
    }

    static var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

    /// Il margine orizzontale delle celle delle tabelle della scheda (come le altre tabelle del prospetto).
    static let margineCella: CGFloat = 4
}

// MARK: - Pagina 1: i controlli

private struct PaginaControlliAdeguatezza: View {
    @Environment(\.paletteDocumento) private var C
    let t: PaginaDatiAdeguatezza

    var body: some View {
        let p = t.proposta
        let righe = t.righe
        VStack(alignment: .leading, spacing: D.spazioScheda) {
            VStack(alignment: .leading, spacing: D.spazioSchedaPiccolo) {
                OcchielloDoc(testo: TestiAdeguatezza.occhiello, font: T.pOcchiello)
                Text(verbatim: p.nome).font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: sottotitolo(p)).font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .center) {
                EtichettaCanale(canale: p.canale)
                Spacer(minLength: 0)
                Text(verbatim: "Esito della proposta: \(esitoProposta(p))").font(T.pTabellaNota).foregroundColor(C.tenue)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiAdeguatezza.consulente(p.canale))
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: D.colonnaData)
            }
            cifre(p)
            RiquadroBarra(titolo: "Esito: \(TestiAdeguatezza.complessivo(t.complessivo))") {
                VStack(alignment: .leading, spacing: D.spazioSchedaPiccolo) {
                    PuntoElenco(testo: Text(verbatim: t.conteggio))
                    if t.firmata, let d = t.scheda?.firmataIl {
                        PuntoElenco(testo: Text(verbatim: "Situazione registrata alla firma del \(CifreDoc.data(d))."))
                    }
                }
            }
            SezioneProspetto(titolo: "I controlli")
            TabellaDoc(larghezza: ProspettoAdeguatezza.larghezza, colonne: colonne, righe: righeControlli(righe),
                       fontTesta: T.pTabellaTesta, altezzaTesta: D.testaScheda, margine: ProspettoAdeguatezza.margineCella)
            if !t.esito.esclusi.isEmpty {
                Text(verbatim: nonPertinenti)
                    .font(T.pTabellaNota).foregroundColor(C.tenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SezioneProspetto(titolo: "Riferimenti")
            VStack(alignment: .leading, spacing: D.spazioSchedaPiccolo) {
                Text(verbatim: TestiAdeguatezza.premessaRiferimenti)
                    .font(T.pTabellaNota).foregroundColor(C.tenue)
                ForEach(Array(riferimenti(righe).enumerated()), id: \.offset) { _, r in
                    Text(verbatim: r)
                        .font(T.pTabellaNota).foregroundColor(C.tenue)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var colonne: [ColonnaDoc] {
        [ColonnaDoc(titolo: "Controllo", peso: 1.3, destra: false),
         ColonnaDoc(titolo: "Esito", peso: 0.9, destra: false),
         ColonnaDoc(titolo: "Cosa risulta", peso: 4.0, destra: false)]
    }

    private func righeControlli(_ righe: [PaginaDatiAdeguatezza.Riga]) -> [RigaDoc] {
        righe.map { r -> RigaDoc in
            var titolo = CellaDoc(r.titolo, font: T.pTabellaForte)
            titolo.righe = 2
            let esito = CellaDoc("● \(TestiAdeguatezza.etichetta(r.semaforo))", colore: coloreSemaforo(r.semaforo, C), font: T.pTabellaForte)
            let testo: [String] = [r.esito] + Array(r.dettagli.prefix(2))
            var cosa = CellaDoc(testo.joined(separator: " "), font: T.pTabella)
            cosa.righe = D.righeCosaRisulta
            return RigaDoc(celle: [titolo, esito, cosa], altezza: D.rigaControllo)
        }
    }

    /// Una riga per controllo: le fonti comuni (rischio, orizzonte ed esperienza hanno lo stesso ambito) si
    /// scrivono una volta sola, poi solo ciò che aggiunge ciascun controllo.
    private func riferimenti(_ righe: [PaginaDatiAdeguatezza.Riga]) -> [String] {
        var scritte: [String] = []
        var elenco: [String] = []
        for r in righe {
            var fonte = r.fonte
            if let comune = scritte.first(where: { fonte.hasPrefix($0) }) {
                fonte = String(fonte.dropFirst(comune.count)).trimmingCharacters(in: .whitespaces)
                if fonte.isEmpty { continue }
            } else if let ambito = t.esito.tipoProdotto?.ambito {
                let base = TestiEsperienza.fonte(ambito)
                if fonte.hasPrefix(base) { scritte.append(base) }
            }
            elenco.append("\(r.titolo): \(fonte)")
        }
        return elenco
    }

    private var nonPertinenti: String {
        let parti = t.esito.esclusi.map { "\(TestiAdeguatezza.titolo($0.tipo)): \($0.motivo)" }
        return "Non pertinenti: " + parti.joined(separator: "; ")
    }

    private func sottotitolo(_ p: Posizione) -> String {
        [p.area.nome, p.tipologia, p.emittente].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func esitoProposta(_ p: Posizione) -> String {
        switch p.stato {
        case .proposta: return (p.esito ?? .bozza).nome
        case .inEssere, .chiusa: return p.stato.nome
        }
    }

    /// Quattro cifre in evidenza: per le coperture capitale, premio, rischio e scadenza.
    private func cifre(_ p: Posizione) -> some View {
        let elenco = valoriCifre(p)
        return HStack(spacing: 6) {
            ForEach(Array(elenco.enumerated()), id: \.offset) { _, c in
                CifraProspetto(c.etichetta, c.valore, c.nota)
            }
        }
    }

    /// Le quattro cifre (etichetta, valore, nota), calcolate a parte: espressioni corte per il controllo dei tipi.
    private func valoriCifre(_ p: Posizione) -> [(etichetta: String, valore: String, nota: String)] {
        let premio: Double = p.premioAnnuo
        let versamento: Double = p.versamentoIniziale
        if p.area == .protezione {
            let capitale: String = p.capitaleAssicurato.map { CifreDoc.euro($0) } ?? "—"
            let rischioCoperto: String = p.rischio?.nome ?? "—"
            var valorePremio = "—"
            if premio > 0 {
                valorePremio = CifreDoc.euro(premio)
            } else if versamento > 0 {
                valorePremio = CifreDoc.euro(versamento)
            }
            let notaPremio: String = premio > 0 ? p.frequenza.nome.lowercased() : "premio unico"
            let scadenza: String = p.scadenza.map { CifreDoc.dataBreve($0) } ?? "—"
            return [("Capitale assicurato", capitale, p.rischio?.nome ?? "copertura"),
                    ("Premio annuo", valorePremio, notaPremio),
                    ("Rischio", rischioCoperto, "coperto"),
                    ("Scadenza", scadenza, "del contratto")]
        }
        let rischio = t.esito.controllo(.rischio)
        let valoreVersamento: String = versamento > 0 ? CifreDoc.euro(versamento) : "—"
        let notaVersamento: String = versamento > 0 ? "capitale iniziale" : "nessuno"
        let valorePremio: String = premio > 0 ? CifreDoc.euro(premio) : "—"
        let notaPremio: String = premio > 0 ? "all'anno" : "nessuno"
        var sri = "—"
        if let v = rischio?.valore { sri = "\(Int(v)) su 7" }
        let notaSri: String = rischio?.stimato == true ? "stimato" : "dal KID"
        let periodo: String = t.periodo.map { TestiAdeguatezza.anni($0) } ?? "—"
        return [("Versamento iniziale", valoreVersamento, notaVersamento),
                ("Versamenti", valorePremio, notaPremio),
                ("SRI", sri, notaSri),
                ("Periodo raccomandato", periodo, "di detenzione")]
    }
}

// MARK: - Pagina 2: esperienza, documenti, firme

private struct PaginaDocumentiAdeguatezza: View {
    @Environment(\.paletteDocumento) private var C
    let t: PaginaDatiAdeguatezza

    var body: some View {
        let p = t.proposta
        VStack(alignment: .leading, spacing: D.spazioScheda) {
            SezioneProspetto(titolo: "A cosa risponde e perché")
            VStack(alignment: .leading, spacing: D.spazioSchedaPiccolo) {
                Text(verbatim: t.collegamento).font(T.pCorpoForte).foregroundColor(C.testo)
                    .fixedSize(horizontal: false, vertical: true)
                let motivazione = t.scheda?.motivazione.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                Text(verbatim: motivazione.isEmpty ? "Motivazione non scritta." : motivazione)
                    .font(T.pCorpo).foregroundColor(motivazione.isEmpty ? C.tenue : C.testo)
                    .lineSpacing(1.6).fixedSize(horizontal: false, vertical: true)
                if let s = t.esito.sostituita {
                    HStack(spacing: 6) {
                        Text(verbatim: "Sostituisce \(s.nome)").font(T.pCorpoForte).foregroundColor(C.titolo)
                        EtichettaCanale(canale: s.canale, compatta: true)
                    }
                    if let u = t.esito.uscita {
                        Text(verbatim: uscita(u)).font(T.pTabellaNota).foregroundColor(C.tenue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            SezioneProspetto(titolo: "Conoscenza ed esperienza del cliente")
            VStack(alignment: .leading, spacing: D.spazioSchedaPiccolo) {
                TabellaDoc(larghezza: ProspettoAdeguatezza.larghezza, colonne: colonneEsperienza, righe: righeEsperienza,
                           fontTesta: T.pTabellaTesta, altezzaTesta: D.testaScheda, margine: ProspettoAdeguatezza.margineCella)
                Text(verbatim: capacita).font(T.pTabellaNota).foregroundColor(C.tenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SezioneProspetto(titolo: "Documenti consegnati prima della firma")
            documenti
            SezioneProspetto(titolo: "Dichiarazioni")
            VStack(alignment: .leading, spacing: D.spazioSchedaPiccolo) {
                ForEach(Array(TestiAdeguatezza.dichiarazioni.enumerated()), id: \.offset) { _, d in
                    PuntoElenco(testo: Text(verbatim: d))
                }
            }
            VStack(alignment: .leading, spacing: D.spazioSchedaPiccolo) {
                Rectangle().fill(C.filetto).frame(height: 0.6)
                (Text(verbatim: "Avvertenze. ").bold() + Text(verbatim: TestiAdeguatezza.avvertenza))
                    .font(T.pTabellaNota).foregroundColor(C.tenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FirmeScheda(cliente: t.cliente, consulente: TestiAdeguatezza.consulente(p.canale), firmataIl: t.scheda?.firmataIl)
        }
    }

    private func uscita(_ u: UscitaSostituzione) -> String {
        var parti: [String] = []
        parti.append("Costi dell'uscita \(CifreDoc.euro(u.costi)) (\(CifreDoc.percento(u.percentuale, decimali: 1)) del valore)")
        if u.imposteAnticipate > MotoreAdeguatezza.impostaMinima { parti.append("imposte anticipate \(CifreDoc.euro(u.imposteAnticipate))") }
        if !u.garanziePerse.isEmpty { parti.append("si perdono \(u.garanziePerse.joined(separator: ", "))") }
        if let g = u.pareggio {
            parti.append("il cambio recupera dal \(g)° anno")
        } else {
            parti.append("nei \(TestiAdeguatezza.anni(u.anni)) del confronto il cambio non recupera i costi")
        }
        return parti.joined(separator: "; ") + "."
    }

    // Esperienza

    private var colonneEsperienza: [ColonnaDoc] {
        [ColonnaDoc(titolo: "Tipo di prodotto", peso: 2.4, destra: false),
         ColonnaDoc(titolo: "Conosce", peso: 0.8, destra: false),
         ColonnaDoc(titolo: "Ha avuto", peso: 0.8, destra: false),
         ColonnaDoc(titolo: "Ha capito", peso: 0.8, destra: false),
         ColonnaDoc(titolo: "Livello", peso: 1.4, destra: false)]
    }

    private var righeEsperienza: [RigaDoc] {
        let rilevata = t.esperienzaRilevata
        let tipo = t.esito.tipoProdotto
        return t.esperienza.map { r -> RigaDoc in
            func risposta(_ b: Bool?) -> CellaDoc {
                var testo = "—"
                if rilevata, let si = b { testo = si ? "Sì" : "No" }
                return CellaDoc(testo, font: T.pTabella)
            }
            // Il tipo della proposta in grassetto
            let nome = CellaDoc(r.tipo.nome, font: r.tipo == tipo ? T.pTabellaForte : T.pTabella)
            let livello = CellaDoc(rilevata ? r.livello.nome : "—", font: r.tipo == tipo ? T.pTabellaForte : T.pTabella)
            return RigaDoc(celle: [nome, risposta(r.voce.conosce), risposta(r.voce.haAvuto), risposta(r.voce.haCapito), livello],
                           altezza: D.rigaEsperienza)
        }
    }

    private var capacita: String {
        guard t.esperienzaRilevata else {
            return "Conoscenza ed esperienza non rilevate in Prisma: fa fede il questionario ufficiale."
        }
        guard let c = t.capacita else { return "Capacità di sostenere perdite non rilevata." }
        return "Capacità di sostenere perdite: \(c.nome) — il cliente \(c.frase)."
    }

    // Documenti

    @ViewBuilder
    private var documenti: some View {
        let elenco = t.esito.documenti
        if elenco.isEmpty {
            Text(verbatim: "Nessun documento per questo canale e questo tipo di prodotto.")
                .font(T.pTabellaNota).foregroundColor(C.tenue)
        } else {
            let altezza = elenco.count > D.documentiPieni ? D.rigaDocumento - D.rigaDocumentoStretta : D.rigaDocumento
            let mostrati = Array(elenco.prefix(D.documentiMassimi))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(mostrati) { d in
                    rigaDocumento(d).frame(height: altezza)
                }
                if elenco.count > mostrati.count {
                    Text(verbatim: "e altri \(elenco.count - mostrati.count) documenti (vedi la scheda in Prisma)")
                        .font(T.pTabellaNota).foregroundColor(C.tenue)
                }
            }
        }
    }

    private func rigaDocumento(_ d: DocumentoDaConsegnare) -> some View {
        HStack(alignment: .center, spacing: 6) {
            SpuntaCarta(segnata: d.consegnatoIl != nil, nonPertinente: d.nonPertinente)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: d.voce.titolo).font(T.pTabella).foregroundColor(C.testo).lineLimit(1).minimumScaleFactor(0.8)
                if !d.voce.dettaglio.isEmpty {
                    Text(verbatim: d.voce.dettaglio).font(T.pTabellaNota).foregroundColor(C.tenue).lineLimit(1).truncationMode(.tail)
                }
            }
            Spacer(minLength: 6)
            Text(verbatim: statoDocumento(d)).font(T.pTabellaNota).foregroundColor(C.tenue).lineLimit(1).fixedSize()
        }
        .frame(width: ProspettoAdeguatezza.larghezza, alignment: .leading)
        .overlay(Rectangle().fill(C.filetto).frame(height: 0.5), alignment: .bottom)
    }

    private func statoDocumento(_ d: DocumentoDaConsegnare) -> String {
        if let data = d.consegnatoIl { return "consegnato il \(CifreDoc.dataBreve(data))" }
        return d.nonPertinente ? "non pertinente" : ""
    }
}
