import AppKit
import Combine
import SwiftUI

/// Stato della finestra Prisma: dati dell'archivio, finestre interne, backup, avvisi.
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

    // MARK: - Attività

    func alternaCompletata(_ id: String) {
        guard let i = dati.attivita.firstIndex(where: { $0.id == id }) else { return }
        dati.attivita[i].completata.toggle()
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
