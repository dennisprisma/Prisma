#if os(macOS)
import AppKit
import Combine
import Foundation

/// La mini finestra di Eve vista dallo stato di Prisma: apre, ascolta, manda la domanda nella stessa conversazione
/// dell'app Eve (il cliente del contesto o il portafoglio), segue lo streaming e porta nelle app.
/// Le risposte le scrive Qwen come nell'app Eve; le cifre sotto la risposta le calcola Prisma (`CifreMiniEve`).
extension StatoShell {
    /// Il gettone del contesto: il cliente attivo e l'app in primo piano.
    func contestoMiniEve() -> ContestoMiniEve? {
        guard let c = clienteAttivo else { return nil }
        let app = appAttiva.flatMap { $0 == .eve || $0 == .impostazioni ? nil : $0.titolo }
        return ContestoMiniEve(clienteId: c.id, nome: c.nome, iniziali: c.iniziali, tinta: c.tinta, app: app)
    }

    /// Si può chiamare Eve? Non durante la presentazione al cliente (sotto c'è solo il documento).
    var miniEveConsentita: Bool { presentazione == nil }

    /// Apre la mini finestra in uno stato (dalla sfera nella barra, da ⌥ Spazio, dalle prove).
    func apriMiniEve(_ fase: FaseMiniEve) {
        guard miniEveConsentita else { return }
        let mini = miniEve
        if fase == .ascolta {
            mini.apri(.ascolta, contesto: contestoMiniEve())
            ascoltaMiniEve()
        } else {
            mini.apri(fase, contesto: contestoMiniEve())
        }
    }

    /// La sfera nella barra: apre (pronta per scrivere) o chiude.
    func alternaMiniEve() {
        if miniEve.visibile { chiudiMiniEve() } else { apriMiniEve(.scrivi) }
    }

    /// Esc, la ✕, un pulsante che porta in un'app.
    func chiudiMiniEve() {
        let mini = miniEve
        guard mini.visibile else { return }
        if mini.ascoltoMio, let a = ascoltoEveSeNato, a.ascolta { a.ferma(invia: false) }
        mini.chiudi()
        guard persistente else { return mini.riposa() }
        DispatchQueue.main.asyncAfter(deadline: .now() + Tema.Moto.MiniEve.durataUscita) {
            if !mini.visibile { mini.riposa() }
        }
    }

    /// Toglie il gettone del contesto: Eve parla di tutto il portafoglio (mai in modalità cliente).
    func togliContestoMiniEve() {
        guard !inModoCliente else { return }
        miniEve.contesto = nil
    }

    // MARK: - Ascolto

    /// Eve ascolta nella mini finestra (⌥ Spazio tenuto premuto, il microfono del campo).
    func ascoltaMiniEve() {
        let mini = miniEve
        mini.vai(.ascolta)
        mini.domanda = ""
        guard persistente else { return }
        guard !eveInCorso else {
            mini.vai(.scrivi)
            mini.nota = "Sto ancora rispondendo nell'app Eve: un attimo e ci sono."
            return
        }
        let eve = dati.impostazioni.eve
        // La dettatura di macOS scrive solo nel campo dell'app Eve: qui si scrive
        if eve.riconoscimento == .dettatura || (eve.riconoscimento == .automatico && usaDettatura) {
            mini.vai(.scrivi)
            mini.nota = "Con la dettatura del Mac scrivi qui sotto, oppure parla con Eve nella sua app (⌥⌘E)."
            return
        }
        voceEve.zitta()
        let scelta = eve.riconoscimento == .automatico
            ? (ripiegoAscolto ?? SceltaRiconoscimento.catenaAutomatica.first ?? .classico) : eve.riconoscimento
        let a = ascoltoEve
        a.azzera()
        mini.ascoltoMio = true
        a.concluso = { [weak self] frase in
            guard let self else { return }
            self.miniEve.ascoltoMio = false
            self.fraseDettaMiniEve(frase)
        }
        a.problema = { [weak self] motivo in
            guard let self else { return }
            self.miniEve.ascoltoMio = false
            guard self.miniEve.visibile else { return }
            self.miniEve.vai(.scrivi)
            self.miniEve.nota = motivo
        }
        a.avvia(scelta)
    }

    /// ⌥ Spazio lasciato (o il microfono premuto di nuovo): Eve chiude la frase e risponde.
    func fineAscoltoMiniEve() {
        let mini = miniEve
        guard persistente, mini.ascoltoMio, let a = ascoltoEveSeNato else { return }
        if a.siPrepara {
            // Il microfono non si era ancora acceso: niente da mandare, si scrive
            a.ferma(invia: false)
            mini.ascoltoMio = false
            mini.vai(.scrivi)
            mini.nota = "Non ho fatto in tempo ad ascoltarti: tieni premuto ⌥ Spazio mentre parli, oppure scrivi."
        } else if a.ascolta {
            a.ferma(invia: true)
        }
    }

    /// Il microfono del campo: ascolta, o chiude la frase se sta già ascoltando.
    func alternaAscoltoMiniEve() {
        if miniEve.ascoltoMio, ascoltoEveSeNato?.ascolta == true { fineAscoltoMiniEve() } else { ascoltaMiniEve() }
    }

    private func fraseDettaMiniEve(_ frase: String) {
        guard miniEve.visibile else { return }
        if CongedoEve.e(frase) { return chiudiMiniEve() }
        inviaMiniEve(DomandaMiniEve(testo: frase, aVoce: true))
    }

    // MARK: - Domanda e risposta

    /// Qwen può rispondere (o la domanda è un comando, che fa Prisma da sola)?
    private func prontaPer(_ testo: String) -> Bool {
        if rispostePreparate || generativo != nil || appuntamentoInSospeso != nil { return true }
        let noti = dati.clienti.map { ClienteNoto(id: $0.id, nome: $0.nome) }
        return InterpreteComandi.interpreta(testo, clienti: noti, attivo: evePortafoglio ? nil : clienteAttivoId) != nil
    }

    /// Manda una domanda: pensa, poi risponde nella scheda. Se Qwen non è pronto la mette da parte e lo sveglia.
    func inviaMiniEve(_ d: DomandaMiniEve) {
        let mini = miniEve
        let testo = d.testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testo.isEmpty else { return }
        guard !eveInCorso else {
            mini.vai(.scrivi)
            mini.nota = "Sto ancora rispondendo nell'app Eve: un attimo e ci sono."
            return
        }
        mini.testo = ""
        mini.nota = nil
        // Senza gettone (o con uno spunto del portafoglio) Eve parla del portafoglio; in modalità cliente mai
        let suPortafoglio = !inModoCliente && (d.portafoglio != nil || mini.contesto == nil)
        if !suPortafoglio, let c = mini.contesto, clienteAttivoId != c.clienteId { clienteAttivoId = c.clienteId }
        // La stessa conversazione dell'app Eve: la freccia la apre lì
        if evePortafoglio != suPortafoglio { evePortafoglio = suPortafoglio }
        mini.domanda = testo
        guard prontaPer(testo) else {
            mini.pendente = DomandaMiniEve(testo: testo, spunto: d.spunto, portafoglio: d.portafoglio, aVoce: d.aVoce)
            mini.nonPronta(motivo: nil)
            preparaQwenMiniEve()
            return
        }
        mini.pendente = nil
        let id = chiaveConversazione
        let fonte = suPortafoglio ? nil : fonteEve(id)
        let modalita = suPortafoglio ? ModalitaEve.lavoro
            : NucleoEve.modalita(domanda: testo, spunto: d.spunto, cliente: fonte?.cliente, storia: conversazione(id))
        mini.chiave = id
        mini.messaggiPrima = conversazione(id).count
        mini.pensa(testo, passi: StatoMiniEve.passi(domanda: testo, fonte: fonte, modalita: modalita))
        let cifre = CifreMiniEve.calcola(domanda: testo, fonte: fonte, modalita: modalita, app: mini.contesto?.app)
        if d.aVoce { rispostaAVoce = dati.impostazioni.eve.risposteAVoce != .mai }
        // Nella mini finestra la risposta è breve: le cifre le mostra la scheda (linea del tempo, righe, fonte)
        let partita = suPortafoglio ? chiediEvePortafoglio(testo, spunto: d.portafoglio, breve: true)
                                    : chiediEve(testo, spunto: d.spunto, breve: true)
        guard partita else {
            rispostaAVoce = false
            mini.vai(.scrivi)
            mini.nota = "La domanda non è partita: riprova tra un attimo."
            return
        }
        seguiRispostaMiniEve(cifre)
    }

    /// Segue la risposta: le parole che arrivano (FlussoEve) e il messaggio finale nella conversazione.
    private func seguiRispostaMiniEve(_ cifre: CifreMiniEve) {
        let mini = miniEve
        mini.abbonamenti.removeAll()
        if concludiMiniEve(cifre) { return }
        flussoEve.$testo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] t in
                guard let self, self.eveInCorso, !t.isEmpty, mini.fase == .pensa || mini.fase == .risponde else { return }
                mini.rispondi(testo: t.trimmingCharacters(in: .whitespacesAndNewlines), titolo: nil, cifre: cifre, inArrivo: true)
            }
            .store(in: &mini.abbonamenti)
        // Al giro dopo: conQwen spegne e riaccende `eveInCorso` nello stesso momento
        $eveInCorso
            .removeDuplicates()
            .filter { !$0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in _ = self?.concludiMiniEve(cifre) }
            .store(in: &mini.abbonamenti)
    }

    /// La risposta è nella conversazione: la scheda mostra il testo finale. false se non è ancora arrivata.
    @discardableResult
    func concludiMiniEve(_ cifre: CifreMiniEve) -> Bool {
        let mini = miniEve
        let elenco = conversazione(mini.chiave)
        guard !eveInCorso, elenco.count > mini.messaggiPrima, let m = elenco.last, m.autore == .eve else { return false }
        mini.abbonamenti.removeAll()
        if m.titolo == "Qwen non è pronto" {
            mini.pendente = DomandaMiniEve(testo: mini.domanda)
            mini.nonPronta(motivo: disponibilitaLocale.motivo)
            return true
        }
        var c = cifre
        if let a = m.azione {
            // Eve ha fatto qualcosa (un appuntamento, un promemoria): il pulsante lo apre
            c = CifreMiniEve()
            c.azioni = [AzioneMiniEve(titolo: Self.titoloAzione(a), simbolo: "arrow.up.forward", tipo: .azioneEve(a), primaria: true)]
        } else if m.titolo == "Eve non ha potuto rispondere" || m.motore == StatoShell.motoreAzioni {
            c = CifreMiniEve()
        }
        mini.rispondi(testo: NucleoEve.pulisci(m.testo), titolo: m.titolo, cifre: c, inArrivo: false)
        return true
    }

    private static func titoloAzione(_ a: AzioneEve) -> String {
        switch a.tipo {
        case .appuntamento: return "Apri in Agenda"
        case .attivita: return "Apri in Attività"
        case .nota: return "Apri la nota"
        }
    }

    // MARK: - Qwen non pronto

    /// «Mi sto svegliando…»: apre Ollama se serve e carica il modello; poi manda la domanda rimasta da parte.
    func preparaQwenMiniEve() {
        let mini = miniEve
        guard persistente, !mini.preparazioneInCorso else { return }
        mini.preparazioneInCorso = true
        mini.motivoNonPronta = nil
        let eve = dati.impostazioni.eve
        Task.detached(priority: .userInitiated) {
            let d = await AvvioModello.prepara(eve)
            await MainActor.run {
                if self.disponibilitaLocale != d { self.disponibilitaLocale = d }
                mini.preparazioneInCorso = false
                guard mini.visibile, mini.fase == .nonPronta else { return }
                if d.pronto {
                    if let p = mini.pendente { self.inviaMiniEve(p) } else { mini.vai(.scrivi) }
                } else {
                    mini.motivoNonPronta = d.motivo
                }
            }
        }
    }

    /// «Riprova» nello stato non pronta.
    func riprovaMiniEve() {
        if let p = miniEve.pendente, prontaPer(p.testo) { return inviaMiniEve(p) }
        preparaQwenMiniEve()
    }

    // MARK: - Verso le app

    /// Un pulsante della risposta: porta Prisma davanti, apre l'app e chiude la mini finestra.
    func eseguiMiniEve(_ a: AzioneMiniEve) {
        let id = miniEve.contesto?.clienteId
        let nome = id.flatMap { cliente($0)?.nome }
        portaDavantiPrisma()
        if let id, clienteAttivoId != id { clienteAttivoId = id }
        let commiato: String
        switch a.tipo {
        case .posizioni:
            apri(.posizioni)
            commiato = "Ti porto in Posizioni" + (nome.map { " · \($0)" } ?? "")
        case .agenda:
            if let id { filtroClienteAgenda = id }
            apri(.agenda)
            commiato = "Ti porto in Agenda" + (nome.map { " · \($0)" } ?? "")
        case .prospetto(let s):
            apriProspetto(s)
            commiato = "Il prospetto è pronto in Prospetti e report"
        case .azioneEve(let e):
            apriAzioneEve(e)
            commiato = a.titolo
        }
        chiudiMiniEve()
        // Il commiato (.toast del template): Eve si ritira verso la sua sfera e dice dove ti ha portato
        mostraAvviso(commiato, daEve: true)
    }

    /// La freccia: la stessa conversazione nell'app Eve completa.
    func apriInEveDaMiniEve() {
        let mini = miniEve
        portaDavantiPrisma()
        if !inModoCliente { evePortafoglio = mini.contesto == nil && mini.chiave == EvePortafoglio.chiave }
        if let c = mini.contesto, clienteAttivoId != c.clienteId { clienteAttivoId = c.clienteId }
        apri(.eve)
        chiudiMiniEve()
    }

    /// Prisma in primo piano (la mini finestra non la attiva), senza la schermata di benvenuto davanti.
    private func portaDavantiPrisma() {
        guard persistente else { return }
        NSApp.activate(ignoringOtherApps: true)
        if let f = PannelloMiniEve.finestraPrisma() {
            if f.isMiniaturized { f.deminiaturize(nil) }
            f.makeKeyAndOrderFront(nil)
        }
        if bloccato { sblocca() }
    }

    /// Le ultime domande fatte a Eve (da tutte le conversazioni), le più recenti prima.
    func recentiMiniEve(_ quante: Int = 2) -> [MessaggioEve] {
        guard !inModoCliente else { return [] }
        let tutte = dati.impostazioni.eve.conservaConversazioni ? dati.conversazioni : conversazioniTemporanee
        var visti = Set<String>()
        return tutte.values.joined()
            .filter { $0.autore == .utente }
            .sorted { $0.data > $1.data }
            .filter { visti.insert($0.testo).inserted }
            .prefix(quante)
            .map { $0 }
    }
}
#endif
