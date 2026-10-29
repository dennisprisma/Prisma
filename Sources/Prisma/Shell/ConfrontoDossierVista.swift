import SwiftUI

// MARK: - Documento contro dossier: la scheda «Confronto» di Documenti (specifica 9, giro 5)

/// Il confronto «Nel documento / In Prisma» di un KID, di una polizza o di un'appendice con la posizione o la scheda
/// prodotto collegata: tabella delle voci, scelte, aggiornamento con lo storico, impatto di un nuovo KID sui clienti.
/// Senza collegamento propone la posizione o la scheda più probabile.
struct ConfrontoDossierVista: View {
    @EnvironmentObject var stato: StatoShell
    let documento: Documento

    /// nil = il bersaglio predefinito.
    @State private var bersaglio: BersaglioConfronto?
    @State private var scelte: Set<VoceDossier> = []
    /// Documento, bersaglio e righe per cui valgono le scelte: quando cambiano, si riparte dalla preselezione.
    @State private var sceltePer = ""
    @State private var ancheProposte = true
    /// La candidata scelta nel menu (`chiave(_:)` del bersaglio).
    @State private var sceltaCollegamento = ""

    var body: some View {
        let d = stato.documento(documento.id) ?? documento
        let elenco = stato.bersagli(d)
        let b = bersaglio.flatMap { elenco.contains($0) ? $0 : nil } ?? elenco.first
        if let b, let c = stato.confronto(d, b) {
            collegato(d, bersaglio: b, confronto: c, bersagli: elenco)
        } else {
            daCollegare(d)
        }
    }

    // MARK: Documento non collegato

    private func daCollegare(_ d: Documento) -> some View {
        let m = Misure.ConfrontoDossier.self
        let candidate = stato.candidateCollegamento(d)
        let suggerimento = stato.suggerimentoCollegamento(d)
        let nomeSuggerito = suggerimento.flatMap { stato.nomeBersaglio($0.0) }
        let opzioni = candidate.map { (Self.chiave($0.0), $0.1) }
        // Nel menu: la scelta, altrimenti il suggerimento, altrimenti la prima candidata
        let chiavi = Set(opzioni.map { $0.0 })
        let suggerita = suggerimento.map { Self.chiave($0.0) }
        let scelta: String
        if chiavi.contains(sceltaCollegamento) {
            scelta = sceltaCollegamento
        } else if let suggerita, chiavi.contains(suggerita) {
            scelta = suggerita
        } else {
            scelta = opzioni.first?.0 ?? ""
        }
        return VStack(alignment: .leading, spacing: m.spazioSezioni) {
            OcchielloConfronto(testo: TestiConfrontoDossier.occhiello)
            TitoloStrumento(occhiello: TestiConfrontoDossier.occhielloCollega, titolo: TestiConfrontoDossier.titoloCollega,
                            testo: TestiConfrontoDossier.introCollega)
            if let s = suggerimento, let n = nomeSuggerito {
                HStack(alignment: .center, spacing: m.spazio) {
                    Text(TestiConfrontoDossier.sembra(n.nome))
                        .font(Tipo.tabellaCellaForte)
                        .foregroundColor(Colori.ConfrontoDossier.testo)
                        .lineLimit(1)
                    EtichettaCanale(canale: n.canale, compatta: true)
                    Text(TestiConfrontoDossier.motivo(s.1))
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.ConfrontoDossier.vuoto)
                    Spacer(minLength: m.spazio)
                    Button(TestiConfrontoDossier.collegaEConfronta) { collega(d.id, s.0) }
                        .buttonStyle(StileBlu())
                        .disabled(stato.solaLettura)
                }
            }
            if candidate.isEmpty {
                NotaMetodo(testo: TestiConfrontoDossier.nessunaCandidata(kid: d.tipo == .kid))
            } else {
                HStack(spacing: m.spazio) {
                    MenuTendina(selezione: Binding(get: { scelta }, set: { sceltaCollegamento = $0 }), opzioni: opzioni,
                                larghezza: m.menu)
                    Button(TestiConfrontoDossier.collega) {
                        if let b = candidate.first(where: { Self.chiave($0.0) == scelta })?.0 { collega(d.id, b) }
                    }
                    .buttonStyle(StileVetro(margine: m.pulsante))
                    .disabled(scelta.isEmpty || stato.solaLettura)
                }
            }
        }
        .padding(m.margine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroStrumento()
    }

    private func collega(_ id: String, _ b: BersaglioConfronto) {
        stato.collegaDocumento(id, a: b)
        bersaglio = b
    }

    private static func scheda(_ b: BersaglioConfronto) -> Bool {
        if case .prodotto = b { return true }
        return false
    }

    /// Identificativo di un bersaglio per il menu delle candidate.
    private static func chiave(_ b: BersaglioConfronto) -> String {
        switch b {
        case .posizione(let id): return "posizione|\(id)"
        case .prodotto(let id): return "prodotto|\(id)"
        }
    }

    // MARK: Documento collegato

    @ViewBuilder
    private func collegato(_ d: Documento, bersaglio b: BersaglioConfronto, confronto c: ConfrontoDossier,
                           bersagli elenco: [BersaglioConfronto]) -> some View {
        let m = Misure.ConfrontoDossier.self
        let storico = stato.variazioni(b)
        let impatto = impattoAperto(c)
        let tenute: String = (d.vociTenute ?? []).joined(separator: ",")
        let righe: String = c.righe.map { r in "\(r.chiave)=\(r.esito)" }.joined(separator: ",")
        let chiaveScelte: String = "\(d.id)|\(Self.chiave(b))|\(storico.count)|\(tenute)|" + righe
        VStack(alignment: .leading, spacing: m.spazioSezioni) {
            testata(d, bersaglio: b, confronto: c, bersagli: elenco)
            if c.righe.isEmpty {
                NotaMetodo(testo: TestiConfrontoDossier.nessunDato)
            } else {
                tabella(d, c)
            }
            if !c.mancanti.isEmpty {
                Text(TestiConfrontoDossier.nonRiporta(c.mancanti))
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.ConfrontoDossier.vuoto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if c.righe.contains(where: { $0.aggiornabile || $0.esito == .tenuto }) {
                azioni(d, bersaglio: b, confronto: c)
            }
            if let impatto {
                ImpattoNuovoKID(esito: impatto.esito, prodotto: impatto.prodotto)
            }
            ElencoVariazioni(variazioni: storico, limite: m.storicoVisibile,
                             ripristinabile: { v in ripristinabile(v, in: b) },
                             ripristina: { v in stato.ripristina(v.id, in: b) })
        }
        .onAppear { preseleziona(c, chiave: chiaveScelte) }
        .onChange(of: chiaveScelte) { nuova in preseleziona(c, chiave: nuova) }
    }

    /// Le scelte ripartono dalla preselezione quando cambiano documento, bersaglio, storico o righe.
    private func preseleziona(_ c: ConfrontoDossier, chiave: String) {
        guard sceltePer != chiave else { return }
        sceltePer = chiave
        scelte = c.preselezione
    }

    /// L'impatto sui clienti, solo per una scheda prodotto con rischio o costi più alti.
    private func impattoAperto(_ c: ConfrontoDossier) -> (esito: EsitoImpatto, prodotto: Prodotto)? {
        guard case .prodotto(let id) = c.bersaglio, let p = stato.prodotto(id), let e = stato.impatto(c), !e.aumenti.isEmpty else {
            return nil
        }
        return (esito: e, prodotto: p)
    }

    private func ripristinabile(_ v: VariazioneDossier, in b: BersaglioConfronto) -> Bool {
        switch b {
        case .posizione(let id):
            guard let p = stato.dati.posizioni.first(where: { $0.id == id }) else { return false }
            return MotoreConfrontoDossier.ripristinabile(v, in: p)
        case .prodotto(let id):
            guard let p = stato.prodotto(id) else { return false }
            return MotoreConfrontoDossier.ripristinabile(v, in: p)
        }
    }

    // MARK: Testata

    private func testata(_ d: Documento, bersaglio b: BersaglioConfronto, confronto c: ConfrontoDossier,
                         bersagli elenco: [BersaglioConfronto]) -> some View {
        let m = Misure.ConfrontoDossier.self
        let n = stato.nomeBersaglio(b)
        let nome: String = n?.nome ?? ""
        let titolo: String
        switch b {
        case .posizione:
            titolo = d.appendice ? TestiConfrontoDossier.titoloAppendice(nome) : TestiConfrontoDossier.titoloPosizione(nome)
        case .prodotto:
            titolo = TestiConfrontoDossier.titoloProdotto(nome)
        }
        // Con scheda e posizione: prima la scheda, poi la posizione
        let schede: [(BersaglioConfronto, String)] = elenco.filter { Self.scheda($0) }
            .map { ($0, TestiConfrontoDossier.segmentoProdotto) }
        let posizioni: [(BersaglioConfronto, String)] = elenco.filter { !Self.scheda($0) }
            .map { ($0, TestiConfrontoDossier.segmentoPosizione) }
        let segmenti = schede + posizioni
        return VStack(alignment: .leading, spacing: m.spazio) {
            HStack(alignment: .top, spacing: m.spazio) {
                TitoloStrumento(occhiello: TestiConfrontoDossier.occhielloTitolo, titolo: titolo, testo: TestiConfrontoDossier.sottotitolo)
                Spacer(minLength: m.spazio)
                if let n { EtichettaCanale(canale: n.canale) }
                pillolaTestata(c)
            }
            HStack(spacing: m.spazio) {
                Button(TestiConfrontoDossier.apri) { apri(b) }
                    .buttonStyle(StileVetro(margine: m.pulsantePiccolo))
                Button {
                    stato.scollegaDocumento(d.id, da: b)
                    bersaglio = nil
                } label: {
                    Text(TestiConfrontoDossier.scollega)
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.ConfrontoDossier.collegamento)
                }
                .buttonStyle(StileSemplice())
                .disabled(stato.solaLettura)
                if segmenti.count == 2 {
                    SegmentiAnalisi(opzioni: segmenti, selezione: Binding(get: { b }, set: { bersaglio = $0 }))
                        .frame(width: m.segmenti)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func pillolaTestata(_ c: ConfrontoDossier) -> Pillola {
        if c.differenze > 0 { return Pillola(testo: TestiConfrontoDossier.pillola(differenze: c.differenze), tono: .attenzione) }
        let confermate = c.righe.contains { $0.esito != .daConfermare && $0.esito != .illeggibile }
        return confermate ? Pillola(testo: TestiConfrontoDossier.tuttoAllineato, tono: .ok)
                          : Pillola(testo: TestiConfrontoDossier.nessunDatoConfermato, tono: .neutro)
    }

    /// «Apri ↗»: la posizione in Posizioni, la scheda in Prodotti.
    private func apri(_ b: BersaglioConfronto) {
        switch b {
        case .posizione(let id):
            if let p = stato.dati.posizioni.first(where: { $0.id == id }) { stato.apriPosizione(p) }
        case .prodotto(let id):
            stato.prodottoSelezionato = id
            stato.apri(.prodotti)
        }
    }

    // MARK: Tabella

    private func tabella(_ d: Documento, _ c: ConfrontoDossier) -> some View {
        let m = Misure.ConfrontoDossier.self
        return TabellaStrumento {
            CellaTesta(testo: "", larghezza: m.colonnaScelta)
            CellaTesta(testo: TestiConfrontoDossier.colonnaDato, larghezza: m.colonnaDato)
            CellaTesta(testo: TestiConfrontoDossier.colonnaDocumento)
            CellaTesta(testo: TestiConfrontoDossier.colonnaPrisma)
            CellaTesta(testo: TestiConfrontoDossier.colonnaEsito, larghezza: m.colonnaEsito, destra: true)
        } righe: {
            ForEach(Array(c.righe.enumerated()), id: \.element.id) { i, r in
                RigaStrumento(indice: i) {
                    riga(d, r)
                }
            }
        }
    }

    private func riga(_ d: Documento, _ r: RigaDossier) -> some View {
        let m = Misure.ConfrontoDossier.self
        let colori = Colori.ConfrontoDossier.self
        let sceglibile = (r.aggiornabile || r.esito == .tenuto) && !stato.solaLettura
        let grezzo = r.esito == .daConfermare || r.esito == .illeggibile
        return HStack(alignment: .top, spacing: 0) {
            // Casella
            Button {
                if scelte.contains(r.voce) { scelte.remove(r.voce) } else { scelte.insert(r.voce) }
            } label: {
                Image(systemName: sceglibile && scelte.contains(r.voce) ? "checkmark.square.fill" : "square")
                    .foregroundColor(sceglibile ? colori.collegamento : colori.vuoto)
                    .padding(Misure.Analisi.cellaMargine)
                    .frame(width: m.colonnaScelta)
            }
            .buttonStyle(StileSemplice())
            .disabled(!sceglibile)
            // Dato e fonte
            VStack(alignment: .leading, spacing: m.spazioRiga) {
                Text(TestiConfrontoDossier.nome(r.voce))
                    .font(Tipo.tabellaCellaForte)
                    .foregroundColor(colori.testo)
                    .fixedSize(horizontal: false, vertical: true)
                if r.pagina > 0 {
                    Button { mostraFonte(d, r) } label: {
                        Text(verbatim: "p. \(r.pagina)")
                            .font(Tipo.chip)
                            .foregroundColor(colori.collegamento)
                    }
                    .buttonStyle(StileSemplice())
                    .help(r.estratto.isEmpty ? TestiConfrontoDossier.nome(r.voce) : "«\(r.estratto)»")
                }
            }
            .padding(Misure.Analisi.cellaMargine)
            .frame(width: m.colonnaDato, alignment: .leading)
            // Nel documento
            VStack(alignment: .leading, spacing: m.spazioRiga) {
                if grezzo {
                    Text(r.testoDocumento.isEmpty ? TestiConfrontoDossier.vuoto : r.testoDocumento)
                        .font(Tipo.tabellaCellaForte)
                        .italic()
                        .foregroundColor(colori.vuoto)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(TestiConfrontoDossier.valore(r.documento, r.voce))
                        .font(Tipo.tabellaCellaForte)
                        .foregroundColor(coloreDocumento(r))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let nota = r.nota {
                    Text(nota)
                        .font(Tipo.chip)
                        .foregroundColor(colori.vuoto)
                        .lineLimit(m.righeNota)
                        .help(nota)
                }
            }
            .padding(Misure.Analisi.cellaMargine)
            .frame(maxWidth: .infinity, alignment: .leading)
            // In Prisma
            Text(TestiConfrontoDossier.valore(r.prisma, r.voce))
                .font(Tipo.tabellaCella)
                .foregroundColor(r.prisma == nil ? colori.vuoto : colori.testo)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Misure.Analisi.cellaMargine)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Esito
            VStack(alignment: .trailing, spacing: m.spazioRiga) {
                pillolaEsito(r)
                if let differenza = TestiConfrontoDossier.differenza(r) {
                    Text(differenza)
                        .font(Tipo.chip)
                        .foregroundColor(r.peggiora ? colori.peggiora : colori.vuoto)
                        .lineLimit(1)
                }
            }
            .padding(Misure.Analisi.cellaMargine)
            .frame(width: m.colonnaEsito, alignment: .trailing)
        }
    }

    private func coloreDocumento(_ r: RigaDossier) -> Color {
        if r.peggiora { return Colori.ConfrontoDossier.peggiora }
        if r.esito == .diverso || r.esito == .nuovo { return Colori.ConfrontoDossier.diverso }
        return Colori.ConfrontoDossier.testo
    }

    private func pillolaEsito(_ r: RigaDossier) -> Pillola {
        let testo = TestiConfrontoDossier.esito(r)
        switch r.esito {
        case .uguale: return Pillola(testo: testo, tono: .ok)
        case .diverso: return Pillola(testo: testo, tono: r.peggiora ? .errore : .attenzione)
        case .nuovo, .tenuto, .daConfermare: return Pillola(testo: testo, tono: .neutro)
        case .illeggibile: return Pillola(testo: testo, tono: .errore)
        }
    }

    /// La fonte «p. N»: l'anteprima salta alla pagina e illumina la riga (senza anteprima il dettaglio passa a «Testo»).
    private func mostraFonte(_ d: Documento, _ r: RigaDossier) {
        // Il rendimento lordo viene dal rendimento «prima dei costi», se il KID lo scrive, altrimenti dallo scenario moderato
        var campo = r.voce.campo
        if r.voce == .rendimentoLordo, let x = d.campo(.rendimentoPrimaCosti), x.pagina == r.pagina, x.estratto == r.estratto {
            campo = .rendimentoPrimaCosti
        }
        stato.vistaDocumenti.pagina = r.pagina
        stato.vistaDocumenti.evidenzia = campo
    }

    // MARK: Azioni

    private func azioni(_ d: Documento, bersaglio b: BersaglioConfronto, confronto c: ConfrontoDossier) -> some View {
        let m = Misure.ConfrontoDossier.self
        let aggiornabili = Set(c.righe.filter(\.aggiornabile).map(\.voce))
        let daAggiornare = scelte.intersection(aggiornabili)
        let valide: Set<VoceDossier> = scelte.filter { v in
            guard let r = c.riga(v) else { return false }
            return r.aggiornabile || r.esito == .tenuto
        }
        let tutteTenute = !valide.isEmpty && valide.allSatisfy { c.riga($0)?.esito == .tenuto }
        let proposte = proposteAperte(b)
        return VStack(alignment: .leading, spacing: m.spazio) {
            HStack(spacing: m.spazio) {
                Button(TestiConfrontoDossier.aggiornaScelti(daAggiornare.count)) {
                    stato.aggiornaDalDocumento(d.id, bersaglio: b, voci: daAggiornare, ancheProposte: proposte > 0 && ancheProposte)
                }
                .buttonStyle(StileBlu())
                .disabled(daAggiornare.isEmpty || stato.solaLettura)
                Button(tutteTenute ? TestiConfrontoDossier.riportaTraLeDifferenze : TestiConfrontoDossier.lasciaComeInPrisma) {
                    stato.alternaVociTenute(d.id, bersaglio: b, voci: valide)
                }
                .buttonStyle(StileVetro(margine: m.pulsante))
                .disabled(valide.isEmpty || stato.solaLettura)
                Button {
                    scelte = aggiornabili
                } label: {
                    Text(TestiConfrontoDossier.scegliTutte)
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.ConfrontoDossier.collegamento)
                }
                .buttonStyle(StileSemplice())
                .disabled(aggiornabili.isEmpty || stato.solaLettura)
                Spacer(minLength: 0)
            }
            if proposte > 0 {
                Toggle(TestiConfrontoDossier.ancheProposte(proposte), isOn: $ancheProposte)
                    .toggleStyle(.checkbox)
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.ConfrontoDossier.testo)
                    .disabled(stato.solaLettura)
            }
            Text(TestiConfrontoDossier.notaAggiorna)
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.ConfrontoDossier.vuoto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Le proposte aperte collegate alla scheda (non quelle collegate solo per nome).
    private func proposteAperte(_ b: BersaglioConfronto) -> Int {
        guard case .prodotto(let id) = b else { return 0 }
        return MotoreCoerenza.proposteAperte(stato.dati.posizioni).filter { $0.prodottoId == id }.count
    }
}

// MARK: - Occhiello

/// L'occhiello in maiuscolo delle sezioni del confronto («DOCUMENTO CONTRO DOSSIER», «IMPATTO DEL NUOVO KID»…).
private struct OcchielloConfronto: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(Tipo.incontroOcchiello)
            .tracking(Misure.ConfrontoDossier.tracciaOcchiello)
            .foregroundColor(Colori.ConfrontoDossier.occhiello)
    }
}

// MARK: - Impatto del nuovo KID

/// Chi ha posizioni o proposte del prodotto quando un nuovo KID alza rischio o costi: costi in più all'anno,
/// «oltre il profilo», attività per ciascun cliente.
private struct ImpattoNuovoKID: View {
    @EnvironmentObject var stato: StatoShell
    let esito: EsitoImpatto
    let prodotto: Prodotto

    var body: some View {
        let m = Misure.ConfrontoDossier.self
        VStack(alignment: .leading, spacing: m.spazio) {
            OcchielloConfronto(testo: TestiConfrontoDossier.occhielloImpatto)
            FraseAumenti(aumenti: esito.aumenti)
            if esito.clienti.isEmpty {
                Text(TestiConfrontoDossier.nessunClienteToccato)
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.ConfrontoDossier.vuoto)
            } else {
                VStack(spacing: 0) {
                    ForEach(esito.clienti) { c in
                        RigaClienteImpatto(cliente: c, compatta: false)
                    }
                }
                Text(TestiConfrontoDossier.riepilogoImpatto(esito))
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.ConfrontoDossier.vuoto)
                    .fixedSize(horizontal: false, vertical: true)
                Button(TestiConfrontoDossier.creaAttivita) {
                    stato.creaAttivitaImpatto(esito, prodotto: prodotto, il: Posizione.oggiArrotondato)
                }
                .buttonStyle(StileVetro(margine: m.pulsante))
                .disabled(stato.solaLettura)
                NotaMetodo(testo: TestiConfrontoDossier.notaImpatto, titolo: TestiConfrontoDossier.titoloNotaImpatto)
            }
        }
        .padding(m.margine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riquadroStrumento()
    }
}

/// «Il nuovo KID alza il rischio da 4 a 5 su 7 …»: i valori nuovi in rosso dentro la frase.
struct FraseAumenti: View {
    let aumenti: [AumentoKID]

    var body: some View {
        let frase: Text = TestiConfrontoDossier.frammentiAumenti(aumenti).reduce(Text(verbatim: "")) {
            (finora: Text, pezzo: (testo: String, cifra: Bool)) -> Text in
            let colore: Color = pezzo.cifra ? Colori.ConfrontoDossier.peggiora : Colori.ConfrontoDossier.testo
            let parte: Text = Text(verbatim: pezzo.testo).foregroundColor(colore)
            return finora + parte
        }
        frase
            .font(Tipo.strumentoTesto)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Un cliente toccato dal nuovo KID: nome, posizioni, canale, «oltre il profilo», costi in più. Un clic apre la prima
/// posizione. `compatta` (avviso di Prodotti): nome, «oltre il profilo» e costo annuo.
struct RigaClienteImpatto: View {
    @EnvironmentObject var stato: StatoShell
    let cliente: ImpattoCliente
    let compatta: Bool

    var body: some View {
        let m = Misure.ConfrontoDossier.self
        let colori = Colori.ConfrontoDossier.self
        Button {
            if let id = cliente.posizioni.first?.id, let p = stato.dati.posizioni.first(where: { $0.id == id }) {
                stato.apriPosizione(p)
            }
        } label: {
            HStack(alignment: .center, spacing: m.spazio) {
                VStack(alignment: .leading, spacing: m.spazioRiga) {
                    Text(cliente.nome)
                        .font(Tipo.tabellaCellaForte)
                        .foregroundColor(colori.testo)
                        .lineLimit(1)
                    if !compatta {
                        HStack(spacing: m.spazio) {
                            ForEach(cliente.posizioni) { p in
                                Chip(testo: TestiConfrontoDossier.chip(p))
                                if p.perNome { Chip(testo: TestiConfrontoDossier.perNome) }
                            }
                        }
                    }
                }
                if !compatta, let canale = cliente.posizioni.first?.canale {
                    EtichettaCanale(canale: canale, compatta: true)
                }
                if cliente.oltreProfilo, let massimo = cliente.sriMassimo {
                    Pillola(testo: TestiConfrontoDossier.oltreProfilo(max: massimo), tono: .errore)
                }
                Spacer(minLength: m.spazio)
                VStack(alignment: .trailing, spacing: m.spazioRiga) {
                    if cliente.costoAnnuoInPiu >= MotoreConfrontoDossier.tolleranzaEuro {
                        Text(TestiConfrontoDossier.costoInPiu(cliente.costoAnnuoInPiu))
                            .font(Tipo.tabellaCellaForte)
                            .foregroundColor(colori.peggiora)
                            .lineLimit(1)
                    }
                    if !compatta, cliente.ingressoInPiu >= MotoreConfrontoDossier.tolleranzaEuro {
                        Text(TestiConfrontoDossier.ingressoInPiu(cliente.ingressoInPiu))
                            .font(Tipo.chip)
                            .foregroundColor(colori.vuoto)
                            .lineLimit(1)
                    }
                }
            }
            .padding(m.margineRigaCliente)
            .bordoBasso(colori.riga)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }
}

// MARK: - Storico

/// Lo storico degli aggiornamenti dai documenti di una posizione o di una scheda, dal più recente, con «Ripristina»
/// dove si può. Lo usano la scheda «Confronto», la scheda «Dati» di Documenti e Prodotti.
struct ElencoVariazioni: View {
    @EnvironmentObject var stato: StatoShell
    let variazioni: [VariazioneDossier]
    /// Quante se ne vedono prima di «Mostra tutti» (nil = tutte).
    var limite: Int? = nil
    let ripristinabile: (VariazioneDossier) -> Bool
    let ripristina: (VariazioneDossier) -> Void

    @State private var tutte = false

    var body: some View {
        let m = Misure.ConfrontoDossier.self
        let colori = Colori.ConfrontoDossier.self
        let mostrate = tutte ? variazioni : Array(variazioni.prefix(limite ?? variazioni.count))
        VStack(alignment: .leading, spacing: m.spazio) {
            OcchielloConfronto(testo: TestiConfrontoDossier.occhielloStorico)
            if variazioni.isEmpty {
                Text(TestiConfrontoDossier.nessunaVariazione)
                    .font(Tipo.kpiNota)
                    .foregroundColor(colori.vuoto)
            } else {
                ForEach(mostrate) { v in
                    HStack(alignment: .top, spacing: m.spazio) {
                        VStack(alignment: .leading, spacing: m.spazioRiga) {
                            Text(TestiConfrontoDossier.rigaVariazione(v))
                                .font(Tipo.tabellaCella)
                                .foregroundColor(colori.testo)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(TestiConfrontoDossier.dettaglioVariazione(v))
                                .font(Tipo.chip)
                                .foregroundColor(colori.vuoto)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: m.spazio)
                        if ripristinabile(v) {
                            Button { ripristina(v) } label: {
                                Text(TestiConfrontoDossier.ripristina)
                                    .font(Tipo.kpiNota)
                                    .foregroundColor(colori.collegamento)
                            }
                            .buttonStyle(StileSemplice())
                            .disabled(stato.solaLettura)
                        }
                    }
                }
                if !tutte, mostrate.count < variazioni.count {
                    Button { tutte = true } label: {
                        Text(TestiConfrontoDossier.mostraTutti(variazioni.count))
                            .font(Tipo.kpiNota)
                            .foregroundColor(colori.collegamento)
                    }
                    .buttonStyle(StileSemplice())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
