import Foundation

// MARK: - Documento contro dossier: stato (specifica 9, giro 5)
// Collegamento di un documento a una posizione o a una scheda prodotto, confronto «Nel documento / In Prisma»,
// aggiornamento delle voci scelte con lo storico e il ripristino, impatto di un nuovo KID sui clienti.
// Niente cache: il confronto riguarda un solo documento (al massimo 10 righe) e l'impatto è un passaggio sulle posizioni.

extension StatoShell {
    // MARK: Bersagli

    /// I bersagli collegati che esistono ancora (posizione, scheda), il predefinito per primo.
    func bersagli(_ d: Documento) -> [BersaglioConfronto] {
        let posizioneEsiste = d.posizioneId.map { id in dati.posizioni.contains { $0.id == id } } ?? false
        let prodottoEsiste = prodotto(d.prodottoId) != nil
        var elenco: [BersaglioConfronto] = []
        if let b = MotoreConfrontoDossier.bersaglioPredefinito(d, posizioneEsiste: posizioneEsiste, prodottoEsiste: prodottoEsiste) {
            elenco.append(b)
        }
        if posizioneEsiste, let id = d.posizioneId, !elenco.contains(.posizione(id)) { elenco.append(.posizione(id)) }
        if prodottoEsiste, let id = d.prodottoId, !elenco.contains(.prodotto(id)) { elenco.append(.prodotto(id)) }
        return elenco
    }

    /// Il confronto del documento con un bersaglio; nil se il bersaglio non c'è più.
    func confronto(_ d: Documento, _ b: BersaglioConfronto) -> ConfrontoDossier? {
        switch b {
        case .posizione(let id):
            guard let p = posizioneConfronto(id) else { return nil }
            return MotoreConfrontoDossier.confronta(d, con: p)
        case .prodotto(let id):
            guard let p = prodotto(id) else { return nil }
            return MotoreConfrontoDossier.confronta(d, con: p)
        }
    }

    /// Nome e canale del bersaglio (per titoli, etichette e avvisi).
    func nomeBersaglio(_ b: BersaglioConfronto) -> (nome: String, canale: Canale)? {
        switch b {
        case .posizione(let id): return posizioneConfronto(id).map { (nome: $0.nome, canale: $0.canale) }
        case .prodotto(let id): return prodotto(id).map { (nome: $0.nome, canale: $0.canale) }
        }
    }

    /// Lo storico degli aggiornamenti del bersaglio, dal più recente.
    func variazioni(_ b: BersaglioConfronto) -> [VariazioneDossier] {
        switch b {
        case .posizione(let id): return Array((posizioneConfronto(id)?.variazioni ?? []).reversed())
        case .prodotto(let id): return Array((prodotto(id)?.variazioni ?? []).reversed())
        }
    }

    // MARK: Collegamento

    /// Candidate per collegare un documento: KID → posizioni del cliente e tutte le schede; polizze, estratti e altri
    /// documenti → posizioni del cliente. Niente per i documenti del cliente (identità, questionari) né per quelli di
    /// Prisma. Etichetta «nome · Alleanza» (« · proposta» per le proposte).
    func candidateCollegamento(_ d: Documento) -> [(BersaglioConfronto, String)] {
        guard collegabile(d) else { return [] }
        let posizioni = MotoreConfrontoDossier.candidatePosizioni(d, tra: dati.posizioni)
            .sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending }
        var elenco: [(BersaglioConfronto, String)] = posizioni.map { p -> (BersaglioConfronto, String) in
            let etichetta = TestiConfrontoDossier.etichettaCandidata(nome: p.nome, canale: p.canale)
            return (BersaglioConfronto.posizione(p.id), p.stato == .proposta ? etichetta + " · proposta" : etichetta)
        }
        if d.tipo == .kid {
            elenco += prodotti.map { p -> (BersaglioConfronto, String) in
                (BersaglioConfronto.prodotto(p.id), TestiConfrontoDossier.etichettaCandidata(nome: p.nome, canale: p.canale))
            }
        }
        return elenco
    }

    /// Il collegamento suggerito: per un KID la scheda più probabile, altrimenti (o se nessuna scheda torna) la
    /// posizione più probabile del cliente. Con il motivo, «già collegato» compreso.
    func suggerimentoCollegamento(_ d: Documento) -> (BersaglioConfronto, MotoreConfrontoDossier.MotivoCollegamento)? {
        guard collegabile(d) else { return nil }
        if d.tipo == .kid, let s = MotoreConfrontoDossier.prodottoProbabile(d, tra: dati.prodotti) {
            return (.prodotto(s.0.id), s.1)
        }
        if let s = MotoreConfrontoDossier.posizioneProbabile(d, tra: dati.posizioni) {
            return (.posizione(s.0.id), s.1)
        }
        return nil
    }

    /// Collega il documento alla posizione o alla scheda (l'altro collegamento resta).
    func collegaDocumento(_ id: String, a b: BersaglioConfronto) {
        guard !solaLettura, documento(id) != nil, let n = nomeBersaglio(b) else { return }
        aggiornaDocumento(id) { d in
            switch b {
            case .posizione(let pid): d.posizioneId = pid
            case .prodotto(let pid): d.prodottoId = pid
            }
        }
        mostraAvviso(TestiConfrontoDossier.avvisoCollegato(n.nome))
    }

    /// Toglie il collegamento con quel bersaglio (l'id torna nil); lo storico resta nel bersaglio.
    func scollegaDocumento(_ id: String, da b: BersaglioConfronto) {
        guard !solaLettura else { return }
        aggiornaDocumento(id) { d in
            switch b {
            case .posizione(let pid): if d.posizioneId == pid { d.posizioneId = nil }
            case .prodotto(let pid): if d.prodottoId == pid { d.prodottoId = nil }
            }
        }
    }

    /// Le chiavi delle righe di quelle voci nel confronto con `b` (differenze o righe già tenute): se ci sono già tutte
    /// le toglie («Riporta tra le differenze»), altrimenti le aggiunge («Lascia come in Prisma»).
    func alternaVociTenute(_ id: String, bersaglio b: BersaglioConfronto, voci: Set<VoceDossier>) {
        guard !solaLettura, let d = documento(id), let c = confronto(d, b) else { return }
        let chiavi = c.righe.filter { voci.contains($0.voce) && ($0.aggiornabile || $0.esito == .tenuto) }.map(\.chiave)
        guard !chiavi.isEmpty else { return }
        var tenute = d.vociTenute ?? []
        if chiavi.allSatisfy({ tenute.contains($0) }) {
            tenute.removeAll { chiavi.contains($0) }
        } else {
            for k in chiavi where !tenute.contains(k) { tenute.append(k) }
        }
        aggiornaDocumento(id) { $0.vociTenute = tenute.isEmpty ? nil : tenute }
    }

    // MARK: Aggiornamento e ripristino

    /// Aggiorna il bersaglio con le voci scelte (e, per una scheda, se richiesto, le proposte aperte del prodotto).
    /// La posizione passa da `salvaPosizione`; la scheda si scrive per assegnazione (`salvaProdotto` cambierebbe la
    /// scheda scelta in Prodotti); le proposte con una sola assegnazione (un salvataggio, un ricalcolo).
    func aggiornaDalDocumento(_ id: String, bersaglio b: BersaglioConfronto, voci: Set<VoceDossier>, ancheProposte: Bool) {
        guard !solaLettura, !voci.isEmpty, let d = documento(id), let c = confronto(d, b) else { return }
        let il = Posizione.oggiArrotondato
        let applicate: [VariazioneDossier]
        let nome: String
        var proposte = 0
        switch b {
        case .posizione(let pid):
            guard var p = dati.posizioni.first(where: { $0.id == pid }) else { return }
            applicate = MotoreConfrontoDossier.applica(voci, da: c, documento: d, a: &p, il: il)
            guard !applicate.isEmpty else { return }
            salvaPosizione(p)
            nome = p.nome
        case .prodotto(let pid):
            guard let i = dati.prodotti.firstIndex(where: { $0.id == pid }) else { return }
            var p = dati.prodotti[i]
            applicate = MotoreConfrontoDossier.applica(voci, da: c, documento: d, a: &p, il: il)
            guard !applicate.isEmpty else { return }
            dati.prodotti[i] = p
            nome = p.nome
            if ancheProposte {
                var elenco = dati.posizioni
                proposte = MotoreConfrontoDossier.applicaAProposte(voci, documento: d, prodottoId: pid, posizioni: &elenco, il: il)
                if proposte > 0 { dati.posizioni = elenco }
            }
        }
        // «Lascia come in Prisma» non vale più per le voci appena aggiornate
        let fatte = Set(applicate.map(\.voce))
        if let tenute = d.vociTenute {
            let resto = tenute.filter { k in !fatte.contains { k.hasPrefix("\($0)|") } }
            if resto.count != tenute.count { aggiornaDocumento(id) { $0.vociTenute = resto.isEmpty ? nil : resto } }
        }
        mostraAvviso(TestiConfrontoDossier.avvisoAggiornati(applicate, nome: nome, proposte: proposte))
    }

    /// Rimette il valore di prima di una variazione (se è ancora l'ultima della voce e il dato non è cambiato).
    func ripristina(_ variazioneId: String, in b: BersaglioConfronto) {
        guard !solaLettura else { return }
        let il = Posizione.oggiArrotondato
        switch b {
        case .posizione(let pid):
            guard let i = dati.posizioni.firstIndex(where: { $0.id == pid }),
                  let v = dati.posizioni[i].variazioni?.first(where: { $0.id == variazioneId }) else { return }
            var p = dati.posizioni[i]
            guard MotoreConfrontoDossier.ripristina(v, in: &p, il: il) != nil else { return }
            salvaPosizione(p)
            mostraAvviso(TestiConfrontoDossier.avvisoRipristinato(v, nome: p.nome))
        case .prodotto(let pid):
            guard let i = dati.prodotti.firstIndex(where: { $0.id == pid }),
                  let v = dati.prodotti[i].variazioni?.first(where: { $0.id == variazioneId }) else { return }
            var p = dati.prodotti[i]
            guard MotoreConfrontoDossier.ripristina(v, in: &p, il: il) != nil else { return }
            dati.prodotti[i] = p
            mostraAvviso(TestiConfrontoDossier.avvisoRipristinato(v, nome: p.nome))
        }
    }

    // MARK: Impatto del nuovo KID

    /// L'impatto per il confronto aperto (prima di aggiornare): solo con una scheda prodotto e aumenti di rischio o costo.
    func impatto(_ c: ConfrontoDossier) -> EsitoImpatto? {
        guard case .prodotto(let pid) = c.bersaglio, let p = prodotto(pid) else { return nil }
        let aumenti = MotoreConfrontoDossier.aumenti(c)
        guard !aumenti.isEmpty else { return nil }
        return MotoreConfrontoDossier.impatto(aumenti, prodotto: p, posizioni: dati.posizioni, clienti: clientiImpatto)
    }

    /// L'impatto dell'ultimo aggiornamento della scheda da un KID, per l'avviso in Prodotti: entro `giorniAvvisoKID`
    /// giorni. Le posizioni sono di tutti i clienti (il prodotto è del catalogo).
    func impattoProdotto(_ p: Prodotto) -> (esito: EsitoImpatto, il: Date, documentoId: String)? {
        guard let ultimo = MotoreConfrontoDossier.aumenti(ultimo: p.variazioni ?? []) else { return nil }
        let cal = Calendar.current
        guard let limite = cal.date(byAdding: .day, value: -MotoreConfrontoDossier.giorniAvvisoKID, to: cal.startOfDay(for: Date())),
              ultimo.il >= limite else { return nil }
        let esito = MotoreConfrontoDossier.impatto(ultimo.aumenti, prodotto: p, posizioni: dati.posizioni, clienti: clientiImpatto)
        return (esito: esito, il: ultimo.il, documentoId: ultimo.documentoId)
    }

    /// Un'attività per ciascun cliente dell'impatto, con scadenza a `giorniAttivita` giorni. Idempotente: l'id dice
    /// prodotto, cliente e giorno, e un'attività che c'è già non si ricrea. Restituisce quante ne ha create.
    @discardableResult
    func creaAttivitaImpatto(_ e: EsitoImpatto, prodotto: Prodotto, il: Date) -> Int {
        guard !solaLettura else { return 0 }
        let cal = Calendar.current
        let g = cal.dateComponents([.year, .month, .day], from: il)
        let giorno = String(format: "%04d%02d%02d", g.year ?? 0, g.month ?? 0, g.day ?? 0)
        let scadenza = cal.startOfDay(for: cal.date(byAdding: .day, value: MotoreConfrontoDossier.giorniAttivita, to: il) ?? il)
        var create = 0
        for c in e.clienti {
            let id = "task-kid-\(prodotto.id)-\(c.clienteId)-\(giorno)"
            guard !dati.attivita.contains(where: { $0.id == id }) else { continue }
            let a = Attivita(id: id, clienteId: c.clienteId,
                             titolo: TestiConfrontoDossier.titoloAttivita(prodotto: prodotto.nome, cliente: c.nome),
                             scadenza: scadenza, priorita: c.oltreProfilo || c.proposteAperte > 0 ? .alta : .normale,
                             completata: false,
                             note: TestiConfrontoDossier.noteAttivita(il: il, aumenti: e.aumenti, posizioni: c.posizioni))
            salvaAttivita(a)
            create += 1
        }
        mostraAvviso(TestiConfrontoDossier.avvisoAttivita(create))
        return create
    }

    /// Apre Documenti sul confronto di un documento (dall'avviso di Prodotti).
    func apriConfronto(_ documentoId: String) {
        guard let d = documento(documentoId) else { return }
        clienteAttivoId = d.clienteId
        documentoSelezionato = d.id
        vistaDocumenti.scheda = .confronto
        apri(.documenti)
    }

    // MARK: Aiuti

    /// La posizione di un bersaglio (anche di un altro cliente: il collegamento è del documento).
    private func posizioneConfronto(_ id: String) -> Posizione? {
        dati.posizioni.first { $0.id == id }
    }

    /// Identità, questionari e documenti creati da Prisma non si collegano a posizioni o schede.
    private func collegabile(_ d: Documento) -> Bool {
        d.genere != .prisma && !MotoreDocumenti.delCliente(d)
    }

    /// I clienti che l'impatto può nominare: tutti, ma in modalità cliente solo quello davanti allo schermo.
    private var clientiImpatto: [Cliente] { clienti }
}
