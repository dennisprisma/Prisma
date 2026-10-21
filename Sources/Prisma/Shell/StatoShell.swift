import AppKit
import Combine
import SwiftUI

/// Stato della finestra Prisma: dati dell'archivio, finestre interne, backup, avvisi.
enum VistaAgenda: Hashable { case settimana, mese }

enum FiltroAttivita: Hashable { case aperte, completate, tutte }

enum SchedaSimulazioni: Hashable { case simulatore, scenari }

/// Ciò che si può mettere a confronto: una posizione (in essere o proposta) o uno scenario salvato.
enum VoceConfronto: Hashable {
    case posizione(String)
    case simulazione(String)
}

final class StatoShell: ObservableObject {
    struct Finestra: Identifiable, Equatable {
        let app: AppPrisma
        var id: AppPrisma { app }
        /// Cornice quando non è ingrandita, nelle coordinate dell'area delle finestre.
        var cornice: CGRect
        var ingrandita = true
        var ridotta = false
    }

    /// Dati dell'archivio locale: ogni modifica viene salvata da sola.
    @Published var dati: DatiPrisma

    /// Finestre aperte; l'ultima è quella in primo piano.
    @Published private(set) var finestre: [Finestra] = []
    @Published private(set) var avviso: String?
    @Published var schermoIntero = false
    @Published var schedaImpostazioni: SchedaImpostazioni = .esperienza
    @Published var schedaCliente: SchedaCliente = .panoramica
    /// Posizione aperta nel dettaglio (usata anche dalle istantanee).
    @Published var posizioneInDettaglio: String?
    /// Il pulsante dell'intestazione di Posizioni chiede di aprire il modulo (nuova posizione o proposta).
    @Published var richiestaNuovaPosizione: StatoPosizione?
    /// Il pulsante "Nuovo cliente" dell'intestazione chiede alla rubrica di aprire il modulo.
    @Published var richiestaNuovoCliente = false

    // Agenda e Attività (stato delle viste, non salvato)
    /// Giornata aperta in agenda.
    @Published var giornoAgenda = Calendar.current.startOfDay(for: Date())
    @Published var vistaAgenda: VistaAgenda = .settimana
    @Published var appuntamentoSelezionato: String?
    /// nil = tutti i clienti.
    @Published var filtroClienteAgenda: String?
    @Published var attivitaSelezionata: String?
    @Published var filtroStatoAttivita: FiltroAttivita = .aperte
    @Published var filtroClienteAttivita: String?
    @Published var filtroPrioritaAttivita: Attivita.Priorita?
    /// Il pulsante dell'intestazione di Attività chiede di aprire il modulo.
    @Published var richiestaNuovaAttivita = false

    // Strumenti di analisi (stato delle viste, non salvato)
    /// Area aperta in Analisi 360 (nil = panoramica).
    @Published var areaAnalisi: AreaAnalisi?
    /// Ipotesi sul tavolo del simulatore.
    @Published var bozzaSimulazione: Simulazione?
    @Published var schedaSimulazioni: SchedaSimulazioni = .simulatore
    /// Scenari scelti per il confronto nella scheda Scenari.
    @Published var scenariConfrontati: Set<String> = []
    @Published var confrontoA: VoceConfronto?
    @Published var confrontoB: VoceConfronto?
    /// Orizzonte comune del confronto (nil = ognuno il suo).
    @Published var orizzonteConfronto: Int?

    // Backup
    @Published private(set) var elencoBackup: [VoceBackup] = []
    @Published private(set) var backupInCorso = false

    /// Area disponibile per le finestre (sotto la barra, sopra il dock), aggiornata dalla vista.
    var area: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 700)

    /// false nelle istantanee: niente disco, niente animazioni.
    let persistente: Bool

    private var lavoroAvviso: DispatchWorkItem?
    private var abbonamenti = Set<AnyCancellable>()
    private var timerBackup: Timer?
    private var salvataggioSospeso = false

    init(persistente: Bool = true) {
        self.persistente = persistente
        if persistente {
            let caricati = Archivio.carica()
            dati = caricati.dati
            if let a = caricati.avviso {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.mostraAvviso(a) }
            }
            avviaSalvataggio()
            avviaBackupAutomatico()
            aggiornaElencoBackup()
        } else {
            dati = DatiPrisma.demo()
        }
    }

    // MARK: - Lettura

    var clienti: [Cliente] { dati.clienti }
    var appuntamenti: [Appuntamento] { dati.appuntamenti }
    var attivita: [Attivita] { dati.attivita }
    var nomeUtente: String { dati.impostazioni.nomeUtente }
    var inizialiUtente: String { dati.impostazioni.inizialiUtente }

    var clienteAttivoId: String {
        get { dati.clienteAttivoId }
        set { dati.clienteAttivoId = newValue }
    }

    var clienteAttivo: Cliente? { clienti.first { $0.id == clienteAttivoId } }

    var finestreVisibili: [Finestra] { finestre.filter { !$0.ridotta } }

    /// App in primo piano (nil = scrivania).
    var appAttiva: AppPrisma? { finestreVisibili.last?.app }

    func aperta(_ app: AppPrisma) -> Bool { finestre.contains { $0.app == app } }

    func cliente(_ id: String) -> Cliente? { clienti.first { $0.id == id } }

    var prossimiAppuntamenti: [Appuntamento] {
        let inizio = Calendar.current.startOfDay(for: Date())
        return appuntamenti
            .filter { $0.inizio >= inizio && $0.stato == .pianificato }
            .sorted { $0.inizio < $1.inizio }
    }

    var appuntamentiDiOggi: [Appuntamento] {
        appuntamenti.filter { Calendar.current.isDateInToday($0.inizio) && $0.stato == .pianificato }
    }

    var attivitaAperte: [Attivita] {
        attivita.filter { !$0.completata }.sorted { $0.scadenza < $1.scadenza }
    }

    // MARK: - Finestre

    private func anima(_ cambia: () -> Void) {
        if persistente { withAnimation(Animazioni.apertura, cambia) } else { cambia() }
    }

    func apri(_ app: AppPrisma) {
        anima {
            if let i = finestre.firstIndex(where: { $0.app == app }) {
                var f = finestre.remove(at: i)
                f.ridotta = false
                finestre.append(f)
            } else {
                finestre.append(Finestra(app: app, cornice: corniceIniziale()))
            }
        }
        if app == .impostazioni { aggiornaElencoBackup() }
    }

    func primoPiano(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), i != finestre.count - 1 else { return }
        let f = finestre.remove(at: i)
        finestre.append(f)
    }

    func chiudi(_ app: AppPrisma) {
        anima { finestre.removeAll { $0.app == app } }
    }

    func riduci(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }) else { return }
        anima { finestre[i].ridotta = true }
    }

    func alternaIngrandimento(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }) else { return }
        anima {
            finestre[i].ingrandita.toggle()
            if !finestre[i].ingrandita {
                finestre[i].cornice = limita(finestre[i].cornice)
            }
        }
        primoPiano(app)
    }

    /// Riduce tutte le finestre e mostra la scrivania.
    func mostraScrivania() {
        anima {
            for i in finestre.indices { finestre[i].ridotta = true }
        }
    }

    func sposta(_ app: AppPrisma, origine: CGPoint) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), !finestre[i].ingrandita else { return }
        var c = finestre[i].cornice
        c.origin = origine
        finestre[i].cornice = limita(c)
    }

    func ridimensiona(_ app: AppPrisma, dimensione: CGSize) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), !finestre[i].ingrandita else { return }
        var c = finestre[i].cornice
        c.size = CGSize(width: max(Misure.Finestra.minima.width, dimensione.width),
                        height: max(Misure.Finestra.minima.height, dimensione.height))
        finestre[i].cornice = limita(c)
    }

    /// Cornice effettiva da disegnare.
    func cornice(di f: Finestra) -> CGRect {
        f.ingrandita ? CGRect(origin: .zero, size: area.size) : limita(f.cornice)
    }

    private func corniceIniziale() -> CGRect {
        let l = max(Misure.Finestra.minima.width, area.width * 0.72)
        let a = max(Misure.Finestra.minima.height, area.height * 0.8)
        let passo = CGFloat(finestre.count % 6) * 24
        return CGRect(x: (area.width - l) / 2 + passo, y: (area.height - a) / 3 + passo, width: l, height: a)
    }

    /// Tiene la finestra dentro l'area (la barra del titolo resta sempre raggiungibile).
    private func limita(_ c: CGRect) -> CGRect {
        var r = c
        r.size.width = min(r.width, area.width)
        r.size.height = min(r.height, area.height)
        r.origin.x = min(max(r.minX, 0), area.width - r.width)
        r.origin.y = min(max(r.minY, 0), area.height - r.height)
        return r
    }

    // MARK: - Clienti

    /// Aggiunge o aggiorna un cliente e lo mette in primo piano.
    func salvaCliente(_ cliente: Cliente) {
        var c = cliente
        c.nome = c.nome.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.iniziali.trimmingCharacters(in: .whitespaces).isEmpty { c.iniziali = Cliente.iniziali(di: c.nome) }
        if let i = dati.clienti.firstIndex(where: { $0.id == c.id }) {
            dati.clienti[i] = c
        } else {
            dati.clienti.append(c)
        }
        dati.clienteAttivoId = c.id
    }

    /// Elimina un cliente con i suoi appuntamenti e attività.
    func eliminaCliente(_ id: String) {
        dati.clienti.removeAll { $0.id == id }
        dati.appuntamenti.removeAll { $0.clienteId == id }
        dati.attivita.removeAll { $0.clienteId == id }
        dati.posizioni.removeAll { $0.clienteId == id }
        dati.simulazioni.removeAll { $0.clienteId == id }
        dati.analisi[id] = nil
        if dati.clienteAttivoId == id {
            dati.clienteAttivoId = dati.clienti.first?.id ?? ""
        }
    }

    func alternaPreferito(_ id: String) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == id }) else { return }
        dati.clienti[i].preferito.toggle()
    }

    func aggiornaNota(_ id: String, _ testo: String) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == id }), dati.clienti[i].nota != testo else { return }
        dati.clienti[i].nota = testo
    }

    /// Tinta per un nuovo cliente, a rotazione.
    var prossimaTinta: TintaAvatar {
        let tinte: [TintaAvatar] = [.blu, .rosa, .verde, .viola, .oro]
        return tinte[dati.clienti.count % tinte.count]
    }

    func appuntamentiCliente(_ id: String) -> [Appuntamento] {
        appuntamenti.filter { $0.clienteId == id }.sorted { $0.inizio < $1.inizio }
    }

    func attivitaCliente(_ id: String) -> [Attivita] {
        attivita.filter { $0.clienteId == id }.sorted { $0.scadenza < $1.scadenza }
    }

    // MARK: - Posizioni

    var posizioni: [Posizione] { dati.posizioni }

    func posizioniCliente(_ id: String) -> [Posizione] {
        dati.posizioni.filter { $0.clienteId == id }
    }

    func salvaPosizione(_ posizione: Posizione) {
        if let i = dati.posizioni.firstIndex(where: { $0.id == posizione.id }) {
            dati.posizioni[i] = posizione
        } else {
            dati.posizioni.append(posizione)
        }
    }

    func eliminaPosizione(_ id: String) {
        dati.posizioni.removeAll { $0.id == id }
    }

    /// Una proposta accettata diventa una posizione in essere.
    func attivaProposta(_ id: String) {
        guard let i = dati.posizioni.firstIndex(where: { $0.id == id }) else { return }
        dati.posizioni[i].stato = .inEssere
        dati.posizioni[i].esito = .accettata
        if dati.posizioni[i].decorrenza == nil { dati.posizioni[i].decorrenza = Date() }
        if dati.posizioni[i].totaleVersato == nil { dati.posizioni[i].totaleVersato = dati.posizioni[i].versamentoIniziale }
        if dati.posizioni[i].controvalore == nil { dati.posizioni[i].controvalore = dati.posizioni[i].versamentoIniziale }
    }

    /// Apre una posizione nel dettaglio di Posizioni.
    func apriPosizione(_ p: Posizione) {
        clienteAttivoId = p.clienteId
        apri(.posizioni)
        // Dopo il cambio di cliente, che in Posizioni chiude il dettaglio aperto
        DispatchQueue.main.async { self.posizioneInDettaglio = p.id }
    }

    func apriCliente(_ id: String) {
        clienteAttivoId = id
        schedaCliente = .panoramica
        apri(.clienti)
    }

    /// Posizioni in essere che scadono nel giorno indicato (lo scadenzario dell'agenda).
    func scadenzeDelGiorno(_ giorno: Date) -> [Posizione] {
        let cal = Calendar.current
        return dati.posizioni.filter { p in
            guard p.stato == .inEssere, let s = p.scadenza else { return false }
            return cal.isDate(s, inSameDayAs: giorno) && (filtroClienteAgenda == nil || p.clienteId == filtroClienteAgenda)
        }
    }

    // MARK: - Strumenti di analisi

    func simulazioniCliente(_ id: String) -> [Simulazione] {
        dati.simulazioni.filter { $0.clienteId == id }.sorted { $0.creataIl > $1.creataIl }
    }

    func salvaSimulazione(_ s: Simulazione) {
        if let i = dati.simulazioni.firstIndex(where: { $0.id == s.id }) {
            dati.simulazioni[i] = s
        } else {
            dati.simulazioni.append(s)
        }
    }

    func eliminaSimulazione(_ id: String) {
        dati.simulazioni.removeAll { $0.id == id }
        scenariConfrontati.remove(id)
        if confrontoA == .simulazione(id) { confrontoA = nil }
        if confrontoB == .simulazione(id) { confrontoB = nil }
    }

    /// Apre il simulatore con le ipotesi di una posizione.
    func simula(_ p: Posizione) {
        clienteAttivoId = p.clienteId
        bozzaSimulazione = Simulazione(posizione: p, orizzonteCliente: cliente(p.clienteId)?.profilo.orizzonteAnni)
        schedaSimulazioni = .simulatore
        apri(.simulazioni)
    }

    /// Apre Confronti con una posizione da una parte; dall'altra la proposta (o la posizione) più vicina.
    func confronta(_ p: Posizione) {
        clienteAttivoId = p.clienteId
        let altre = posizioniCliente(p.clienteId).filter { $0.id != p.id && $0.area.proiettabile && $0.stato != .chiusa }
        let opposte = altre.filter { $0.stato != p.stato }
        let altra = opposte.first { $0.area == p.area } ?? altre.first { $0.area == p.area } ?? opposte.first ?? altre.first
        confrontoA = .posizione(p.id)
        confrontoB = altra.map { .posizione($0.id) }
        orizzonteConfronto = nil
        apri(.confronti)
    }

    /// Analisi 360 del cliente: quella salvata o, se manca, una prima stesura dalle posizioni.
    func analisi360(_ id: String) -> Analisi360 {
        dati.analisi[id] ?? Analisi360(cliente: cliente(id), posizioni: posizioniCliente(id))
    }

    func analisiSalvata(_ id: String) -> Bool { dati.analisi[id] != nil }

    func salvaAnalisi(_ id: String, _ a: Analisi360) {
        var x = a
        x.aggiornataIl = Appuntamento.alMinuto(Date())
        dati.analisi[id] = x
    }

    /// Riparte dai dati delle posizioni (l'analisi salvata viene tolta).
    func ricalcolaAnalisi(_ id: String) {
        dati.analisi[id] = nil
    }

    // MARK: - Agenda

    /// Appuntamenti del giorno, filtrati per cliente, in ordine d'orario.
    func appuntamentiDelGiorno(_ giorno: Date) -> [Appuntamento] {
        let cal = Calendar.current
        return appuntamenti
            .filter { cal.isDate($0.inizio, inSameDayAs: giorno) && (filtroClienteAgenda == nil || $0.clienteId == filtroClienteAgenda) }
            .sorted { $0.inizio < $1.inizio }
    }

    func appuntamento(_ id: String?) -> Appuntamento? {
        guard let id else { return nil }
        return appuntamenti.first { $0.id == id }
    }

    /// Mostra in agenda il giorno di un appuntamento e lo seleziona.
    func mostraInAgenda(_ a: Appuntamento) {
        giornoAgenda = Calendar.current.startOfDay(for: a.inizio)
        appuntamentoSelezionato = a.id
        if filtroClienteAgenda != nil && filtroClienteAgenda != a.clienteId { filtroClienteAgenda = nil }
        apri(.agenda)
    }

    func salvaAppuntamento(_ a: Appuntamento) {
        var x = a
        x.titolo = x.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        x.luogo = x.luogo.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = dati.appuntamenti.firstIndex(where: { $0.id == x.id }) {
            dati.appuntamenti[i] = x
        } else {
            dati.appuntamenti.append(x)
        }
        giornoAgenda = Calendar.current.startOfDay(for: x.inizio)
        appuntamentoSelezionato = x.id
        if filtroClienteAgenda != nil && filtroClienteAgenda != x.clienteId { filtroClienteAgenda = x.clienteId }
    }

    /// Elimina un appuntamento; le attività collegate restano, senza collegamento.
    func eliminaAppuntamento(_ id: String) {
        dati.appuntamenti.removeAll { $0.id == id }
        for i in dati.attivita.indices where dati.attivita[i].appuntamentoId == id {
            dati.attivita[i].appuntamentoId = nil
        }
        if appuntamentoSelezionato == id { appuntamentoSelezionato = nil }
    }

    func alternaConcluso(_ id: String) {
        guard let i = dati.appuntamenti.firstIndex(where: { $0.id == id }) else { return }
        dati.appuntamenti[i].stato = dati.appuntamenti[i].stato == .concluso ? .pianificato : .concluso
    }

    // MARK: - Attività

    func alternaCompletata(_ id: String) {
        guard let i = dati.attivita.firstIndex(where: { $0.id == id }) else { return }
        dati.attivita[i].completata.toggle()
    }

    func salvaAttivita(_ a: Attivita) {
        var x = a
        x.titolo = x.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = dati.attivita.firstIndex(where: { $0.id == x.id }) {
            dati.attivita[i] = x
        } else {
            dati.attivita.append(x)
        }
        attivitaSelezionata = x.id
        if filtroClienteAttivita != nil && filtroClienteAttivita != x.clienteId { filtroClienteAttivita = x.clienteId }
        if filtroPrioritaAttivita != nil && filtroPrioritaAttivita != x.priorita { filtroPrioritaAttivita = nil }
        if filtroStatoAttivita == .completate && !x.completata { filtroStatoAttivita = .aperte }
    }

    func eliminaAttivita(_ id: String) {
        dati.attivita.removeAll { $0.id == id }
        if attivitaSelezionata == id { attivitaSelezionata = nil }
    }

    func attivitaCollegate(_ appuntamentoId: String) -> [Attivita] {
        attivita.filter { $0.appuntamentoId == appuntamentoId }.sorted { $0.scadenza < $1.scadenza }
    }

    // MARK: - Salvataggio

    /// Salva l'archivio 0,8 s dopo l'ultima modifica e alla chiusura dell'app.
    private func avviaSalvataggio() {
        $dati
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(800), scheduler: DispatchQueue.main)
            .sink { [weak self] d in
                guard let self, !self.salvataggioSospeso else { return }
                self.scrivi(d)
            }
            .store(in: &abbonamenti)
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.salvaOra() }
            .store(in: &abbonamenti)
    }

    func salvaOra() {
        guard persistente, !salvataggioSospeso else { return }
        scrivi(dati)
    }

    private func scrivi(_ d: DatiPrisma) {
        do {
            try Archivio.salva(d)
        } catch {
            mostraAvviso("Salvataggio non riuscito: \(error.localizedDescription)")
        }
    }

    // MARK: - Backup

    var cartellaBackup: URL {
        dati.impostazioni.backup.cartella.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Archivio.cartellaBackupPredefinita
    }

    /// true se i backup stanno ancora sullo stesso Mac dell'archivio.
    var cartellaBackupPredefinita: Bool { dati.impostazioni.backup.cartella == nil }

    func scegliCartellaBackup(_ url: URL) {
        dati.impostazioni.backup.cartella = url.path
        aggiornaElencoBackup()
    }

    func aggiornaElencoBackup() {
        guard persistente else { return }
        let cartella = cartellaBackup
        DispatchQueue.global(qos: .utility).async {
            let elenco = GestoreBackup.elenca(cartella)
            DispatchQueue.main.async { self.elencoBackup = elenco }
        }
    }

    /// Crea un backup completo della cartella dell'archivio.
    func creaBackup(automatico: Bool = false) {
        guard persistente, !backupInCorso else { return }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        DispatchQueue.global(qos: .utility).async {
            do {
                let url = try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione,
                                                 nota: automatico ? "automatico" : nil)
                DispatchQueue.main.async {
                    self.backupInCorso = false
                    self.dati.impostazioni.backup.ultimo = Date()
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("Backup creato: \(url.lastPathComponent)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.backupInCorso = false
                    self.mostraAvviso("Backup non riuscito: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Ripristina un backup. Prima salva una copia di sicurezza dello stato attuale.
    func ripristina(_ zip: URL) {
        guard persistente, !backupInCorso else { return }
        salvaOra()
        salvataggioSospeso = true
        backupInCorso = true
        let destinazione = cartellaBackup
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let estratto = try GestoreBackup.estrai(zip)
                try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima del ripristino")
                try GestoreBackup.sostituisci(cartellaDati: Archivio.cartella, con: estratto.cartella)
                DispatchQueue.main.async {
                    self.dati = estratto.dati
                    self.salvataggioSospeso = false
                    self.backupInCorso = false
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("Ripristino completato. Lo stato precedente è salvato in un backup.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.salvataggioSospeso = false
                    self.backupInCorso = false
                    self.mostraAvviso("Ripristino non riuscito: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Torna ai 5 clienti di prova (con backup di sicurezza dello stato attuale).
    func ripristinaDatiDiProva() {
        guard persistente, !backupInCorso else { return }
        salvaOra()
        backupInCorso = true
        let destinazione = cartellaBackup
        DispatchQueue.global(qos: .userInitiated).async {
            let esito = Result { try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: destinazione, nota: "prima dei dati di prova") }
            DispatchQueue.main.async {
                self.backupInCorso = false
                switch esito {
                case .success:
                    var demo = DatiPrisma.demo()
                    demo.impostazioni = self.dati.impostazioni
                    self.dati = demo
                    self.aggiornaElencoBackup()
                    self.mostraAvviso("Dati di prova ripristinati. Lo stato precedente è salvato in un backup.")
                case .failure(let e):
                    self.mostraAvviso("Operazione annullata, backup non riuscito: \(e.localizedDescription)")
                }
            }
        }
    }

    /// Backup automatico settimanale: controllo all'avvio e poi ogni ora.
    private func avviaBackupAutomatico() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.controllaBackupAutomatico() }
        timerBackup = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.controllaBackupAutomatico()
        }
    }

    private func controllaBackupAutomatico() {
        let b = dati.impostazioni.backup
        guard b.automatico, let prossimo = b.prossimo, prossimo <= Date() else { return }
        creaBackup(automatico: true)
    }

    // MARK: - Avvisi

    func mostraAvviso(_ testo: String) {
        lavoroAvviso?.cancel()
        withAnimation(Animazioni.avviso) { avviso = testo }
        let lavoro = DispatchWorkItem { [weak self] in
            withAnimation(Animazioni.avviso) { self?.avviso = nil }
        }
        lavoroAvviso = lavoro
        DispatchQueue.main.asyncAfter(deadline: .now() + Animazioni.durataAvviso, execute: lavoro)
    }

    func alternaSchermoIntero() {
        (NSApp.keyWindow ?? NSApp.windows.first)?.toggleFullScreen(nil)
    }
}

enum SchedaImpostazioni: Hashable {
    case esperienza, archivio, scorciatoie
}

enum SchedaCliente: String, CaseIterable, Hashable {
    case panoramica, anagrafica, famiglia, profilo, note

    var titolo: String {
        switch self {
        case .panoramica: return "Panoramica"
        case .anagrafica: return "Anagrafica"
        case .famiglia: return "Famiglia"
        case .profilo: return "Profilo"
        case .note: return "Note"
        }
    }
}
