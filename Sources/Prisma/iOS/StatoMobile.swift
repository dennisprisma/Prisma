#if os(iOS)
import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Il pannello sopra la scrivania di iPhone e iPad (uno alla volta, come i pannelli della shell del Mac).
/// La Ricerca resta `stato.pannelloRicerca` e le notifiche `stato.pannelloNotifiche` (quelli del Mac).
enum PannelloMobile: Equatable {
    /// Il centro di controllo (.cc del tema).
    case controllo
    /// Solo iPhone: tutte le app in griglia (il dock ne tiene quattro).
    case tutteLeApp
    /// Solo iPad: le app aperte (lo switcher del tema).
    case appAperte
}

/// Dove porta un tocco negli elenchi dell'iPhone (NavigationStack di ogni app nella finestra).
enum DestinazioneTelefono: Hashable {
    case cliente(String)
    case posizione(String)
    case appuntamento(String)
}

/// Il file che l'iPad chiede di scegliere con `.fileImporter` (`StatoShell.sceltaFileMobile`): sul Mac sono
/// i pannelli di apertura di `importaClientiDaFile`, `importaPosizioniDaFile` e `scegliFileValori`.
enum SceltaFileMobile: String, Identifiable {
    case clienti, posizioni, valori

    var id: String { rawValue }

    /// vCard solo per i clienti; per tutti CSV, testo a tabulazioni ed Excel (.xlsx), come sul Mac.
    var tipi: [UTType] {
        switch self {
        case .clienti: return [.vCard] + StatoShell.tipiTabelle
        case .posizioni, .valori: return StatoShell.tipiTabelle
        }
    }
}

/// Un backup pronto da rimandare al Mac con `.fileExporter`: il file resta in tmp/ e si legge solo al salvataggio
/// (niente copia in memoria: il backup comprende i documenti).
struct DocumentoBackupMobile: FileDocument {
    static var readableContentTypes: [UTType] { [.backupPrisma, .zip] }
    static var writableContentTypes: [UTType] { [.backupPrisma, .zip] }

    let url: URL

    init(url: URL) { self.url = url }

    init(configuration: ReadConfiguration) throws {
        // Prisma non apre backup da qui (lo fa AperturaBackup): il tipo serve solo all'esportazione
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url, options: [])
    }
}

/// Un testo da salvare con `.fileExporter` (la copia di una nota del taccuino): resta in memoria, è piccolo.
struct DocumentoTestoMobile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    let testo: String
    /// Il nome proposto nel selettore, con l'estensione.
    let nome: String

    init(testo: String, nome: String) {
        self.testo = testo
        self.nome = nome
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(testo.utf8))
    }
}

extension UTType {
    /// Il backup protetto di Prisma (`.zip.cifrato`), dichiarato in Supporto/iOS/Info.plist.
    static let backupPrisma = UTType(exportedAs: "local.prisma.backup")
}

/// Lo stato di Prisma su iPhone e iPad: un sottile involucro attorno allo `StatoShell` condiviso (lo stesso
/// `@EnvironmentObject` delle viste `App*` del Mac), con ciò che serve solo qui: l'apertura del backup del Mac,
/// l'app nella finestra di vetro sopra la scrivania, i pannelli e il salvataggio prima che il dispositivo si blocchi.
@MainActor
final class StatoMobile: ObservableObject {
    /// A che punto è l'apertura del backup.
    enum FaseApertura: Equatable {
        case attesa
        case copia
        case ripristino
        case errore(String)
        case riuscita
    }

    let stato: StatoShell
    /// false nelle istantanee: niente disco, niente pulizie, niente lavori in background.
    let persistente: Bool

    /// L'apertura del backup copre tutto (archivio ancora con i soli dati di prova, o scelta dall'utente).
    @Published var mostraApertura: Bool
    @Published var fase: FaseApertura = .attesa
    /// La copia di lavoro del backup scelto (in tmp/), e il nome da mostrare.
    @Published private(set) var fileScelto: URL?
    @Published private(set) var nomeFile: String?
    /// true se il file scelto è un backup protetto da password (`.zip.cifrato`).
    @Published private(set) var protetto = false

    /// L'app nella finestra di vetro sopra la scrivania; nil = la scrivania. La scrive solo StatoMobile: le icone
    /// (`apri`), la scrivania (`mostraHome`) e i rimandi delle app (`stato.apri`, dal sink su `sistema.$elenco`).
    @Published private(set) var appAperta: AppPrisma?
    /// Il pannello aperto sopra la scrivania (centro di controllo, tutte le app, app aperte).
    @Published var pannello: PannelloMobile?
    /// Da dove si è aperta l'app (spazio `ShellView.spazioShell`): l'ancora del movimento d'apertura del Mac.
    private(set) var origineApertura: CGPoint?
    /// Il backup per il Mac: in preparazione, poi pronto da salvare con `.fileExporter`.
    @Published private(set) var preparazioneBackup = false
    @Published var backupDaInviare: DocumentoBackupMobile?
    /// Il percorso aperto nelle app dell'iPhone (Clienti, Posizioni, Agenda; le istantanee lo impostano).
    @Published var percorsoClienti: [DestinazioneTelefono] = []
    @Published var percorsoPosizioni: [DestinazioneTelefono] = []
    @Published var percorsoAgenda: [DestinazioneTelefono] = []
    /// Solo istantanee: la scrivania dell'iPhone parte scorsa fino al piede.
    var scrivaniaInFondo = false

    /// Dopo la fine del ripristino, quanto aspettare prima di leggerne l'esito (gli ultimi passi di StatoShell).
    nonisolated static let ritardoEsito: UInt64 = 800_000_000
    /// Dopo la scelta di un file da importare, quanto aspettare che il selettore finisca di chiudersi.
    nonisolated static let ritardoDopoSelettore: UInt64 = 500_000_000

    private var abbonamenti = Set<AnyCancellable>()
    /// L'ultima app davanti vista dal sink: una finestra si apre solo quando cambia (come `removeDuplicates`).
    private var ultimaDavanti: AppPrisma?
    private var attesaEsito: AnyCancellable?
    private var compitoSalvataggio: UIBackgroundTaskIdentifier = .invalid

    init(stato: StatoShell, persistente: Bool = true) {
        self.stato = stato
        self.persistente = persistente
        // Sul Mac Prisma si apre sulla schermata di benvenuto; su iPhone e iPad non c'è: si entra subito
        stato.bloccato = false
        stato.sistema.bloccatoStabile = false
        mostraApertura = persistente && Self.soloDatiDiProva(stato.dati)
        // Una password sbagliata arriva da StatoShell.ripristina come richiesta di password (sul Mac apre
        // un avviso in Impostazioni): qui diventa il messaggio sotto il campo
        stato.$ripristinoDaSbloccare
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] richiesta in self?.passwordRifiutata(richiesta) }
            .store(in: &abbonamenti)
        // Le app e i widget aprono le altre con `stato.apri(_:)` (risultati della Ricerca, importazioni, rimandi):
        // sul Mac la finestra viene davanti, su iPhone e iPad l'app va nella finestra di vetro
        stato.sistema.$elenco
            .receive(on: DispatchQueue.main)
            // Si legge l'elenco di adesso, non quello pubblicato: fra la pubblicazione e la consegna (al giro dopo)
            // le icone possono averlo già cambiato di nuovo
            .sink { [weak self] _ in
                guard let self else { return }
                self.elencoCambiato(self.stato.sistema.elenco)
            }
            .store(in: &abbonamenti)
    }

    // MARK: - App aperta (iPhone e iPad)

    /// Un'icona (dock, «Tutte le app», un pulsante della barra): l'app va subito nella finestra, poi passa da
    /// StatoShell, così modo cliente, Impostazioni ed Eve restano quelli del Mac. Sull'iPhone i percorsi ripartono
    /// dalla radice. In modo cliente le app riservate non si aprono: lo dice `stato.apri` con il suo avviso.
    func apri(_ app: AppPrisma, da origine: CGPoint? = nil) {
        guard stato.appConsentita(app) else {
            stato.apri(app)
            return
        }
        pannello = nil
        if stato.pannelloNotifiche { stato.pannelloNotifiche = false }
        // La Ricerca è il pannello come Spotlight, non una finestra
        guard app != .ricerca else {
            stato.cercaOvunque()
            return
        }
        percorsoClienti = []
        percorsoPosizioni = []
        percorsoAgenda = []
        origineApertura = origine
        appAperta = app
        ultimaDavanti = app
        stato.apriApp(app, da: origine)
    }

    /// Torna alla scrivania: la finestra se ne va subito, poi le finestre di StatoShell si riducono di colpo
    /// (mai `stato.mostraScrivania()`, che le riduce una alla volta: il sink vedrebbe passare le altre app).
    func mostraHome() {
        pannello = nil
        if stato.pannelloNotifiche { stato.pannelloNotifiche = false }
        appAperta = nil
        ultimaDavanti = nil
        stato.riduciTutteSuiOS()
    }

    /// iPad, dalle app aperte: un'altra app nella finestra, con il suo stato (come `apri`, senza azzerare nulla).
    func passaA(_ app: AppPrisma) {
        guard stato.appConsentita(app), app != .ricerca else {
            apri(app)
            return
        }
        pannello = nil
        origineApertura = nil
        appAperta = app
        ultimaDavanti = app
        stato.apri(app)
    }

    /// Le finestre di StatoShell sono cambiate: se davanti c'è un'altra app (un rimando, un widget) va nella
    /// finestra; se l'app della finestra è stata chiusa resta quella dietro, o la scrivania.
    private func elencoCambiato(_ elenco: [StatoShell.Finestra]) {
        let davanti = elenco.last(where: { !$0.ridotta })?.app
        defer { ultimaDavanti = davanti }
        if let davanti, davanti != ultimaDavanti, davanti != appAperta {
            apriDaRimando(davanti)
        } else if let aperta = appAperta, !elenco.contains(where: { $0.app == aperta }) {
            appAperta = davanti
        }
    }

    /// Un'app aperta da un'altra o da un widget: l'origine è quella misurata dal widget (`misuraOrigine`).
    /// Sull'iPhone le app sono le viste da telefono: il rimando apre il dettaglio che il Mac mostrerebbe.
    private func apriDaRimando(_ app: AppPrisma) {
        pannello = nil
        origineApertura = stato.sistema.origini[app]
        if UIDevice.current.userInterfaceIdiom == .phone {
            switch app {
            case .posizioni:
                percorsoPosizioni = stato.posizioneInDettaglio.map { [DestinazioneTelefono.posizione($0)] } ?? []
            case .agenda:
                percorsoAgenda = stato.appuntamentoSelezionato.map { [DestinazioneTelefono.appuntamento($0)] } ?? []
            case .clienti:
                let id = stato.clienteAttivoId
                percorsoClienti = stato.clienti.contains(where: { $0.id == id }) ? [DestinazioneTelefono.cliente(id)] : []
            default:
                break
            }
        }
        appAperta = app
    }

    // MARK: - Importazioni da file

    /// Il file scelto con `.fileImporter` per un'importazione: si legge da una copia in tmp/ (scaricata da
    /// iCloud Drive se serve), che si cancella subito dopo la lettura. Il nome resta quello del file scelto.
    func importa(_ esito: Result<URL, Error>, per scelta: SceltaFileMobile) {
        let url: URL
        switch esito {
        case .success(let scelto): url = scelto
        case .failure(let errore):
            stato.mostraAvviso("Non riesco ad aprire il file scelto: \(errore.localizedDescription)")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let copia = Result { try Self.copiaDiLavoro(url) }
            Task { @MainActor [weak self] in
                // Il foglio dell'anteprima (Clienti, Posizioni) si apre a selettore dei file chiuso del tutto
                try? await Task.sleep(nanoseconds: StatoMobile.ritardoDopoSelettore)
                guard let self else {
                    if case .success(let file) = copia { StatoMobile.cancellaCopia(file) }
                    return
                }
                switch copia {
                case .success(let file):
                    switch scelta {
                    case .clienti: self.stato.importaClienti(da: file)
                    case .posizioni: self.stato.importaPosizioni(da: file)
                    case .valori: self.stato.valoriDaFile(file)
                    }
                    Self.cancellaCopia(file)
                case .failure(let errore):
                    self.stato.mostraAvviso("Non riesco a leggere «\(url.lastPathComponent)»: \(errore.localizedDescription). Se è su iCloud Drive, aspetta che sia scaricato e riprova.")
                }
            }
        }
    }

    // MARK: - Backup da rimandare al Mac

    /// Crea un backup protetto dell'archivio del dispositivo in tmp/ (mai nella cartella dei backup arrivata dal
    /// Mac, che qui non esiste), poi lo offre a `.fileExporter`: si salva in File o iCloud Drive e sul Mac si apre
    /// con Impostazioni › Archivio › «Ripristina da file…». Sempre con password: i dati dei clienti escono dal
    /// dispositivo solo cifrati.
    func preparaBackupPerMac(password: String) {
        guard persistente, !preparazioneBackup, !stato.backupInCorso else { return }
        guard password.count >= ImpostazioniBackup.lunghezzaMinimaPassword else {
            stato.mostraAvviso("La password deve avere almeno \(ImpostazioniBackup.lunghezzaMinimaPassword) caratteri.")
            return
        }
        scartaBackupDaInviare()
        stato.salvaOra()
        preparazioneBackup = true
        // UIDevice si legge sul thread principale
        let nota = Self.notaBackupDispositivo
        DispatchQueue.global(qos: .userInitiated).async {
            let cartella = FileManager.default.temporaryDirectory.appendingPathComponent("backup-invio-\(UUID().uuidString)", isDirectory: true)
            let esito = Result {
                try GestoreBackup.crea(sorgente: Archivio.cartella, destinazione: cartella,
                                       nota: nota, password: password)
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.preparazioneBackup = false
                switch esito {
                case .success(let file):
                    self.backupDaInviare = DocumentoBackupMobile(url: file)
                case .failure(let errore):
                    try? FileManager.default.removeItem(at: cartella)
                    self.stato.mostraAvviso("Backup non riuscito: \(errore.localizedDescription)")
                }
            }
        }
    }

    /// Il salvataggio con `.fileExporter` è finito (o annullato): la copia in tmp/ si cancella.
    func backupInviato(_ esito: Result<URL, Error>) {
        switch esito {
        case .success(let url):
            stato.mostraAvviso("Backup salvato: «\(url.lastPathComponent)». Sul Mac aprilo da Impostazioni › Archivio.")
        case .failure(let errore):
            if (errore as? CocoaError)?.code != .userCancelled {
                stato.mostraAvviso("Backup non salvato: \(errore.localizedDescription)")
            }
        }
        scartaBackupDaInviare()
    }

    func scartaBackupDaInviare() {
        if let file = backupDaInviare?.url { Self.cancellaCopia(file) }
        backupDaInviare = nil
    }

    /// La nota nel nome del backup fatto sul dispositivo («Prisma backup … (da iPad).zip.cifrato»).
    static var notaBackupDispositivo: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "da iPad" : "da iPhone"
    }

    /// Lo stato vero dell'app, con l'archivio sul disco. Le cartelle d'arrivo si svuotano prima.
    static func avvia() -> StatoMobile {
        pulisciArrivi()
        return StatoMobile(stato: StatoShell())
    }

    /// L'archivio non ha ancora dati veri: vuoto, o con i soli clienti di prova scritti al primo avvio.
    static func soloDatiDiProva(_ dati: DatiPrisma) -> Bool {
        dati.clienti.allSatisfy { StatoShell.clientiDiProva.contains($0.id) }
    }

    // MARK: - File in arrivo

    /// Un file dal selettore (`fileImporter`) o da «Apri con Prisma» (`onOpenURL`, AirDrop, File, iCloud Drive).
    /// Si lavora sempre su una copia in tmp/: l'originale non si tocca (tranne quello in Documents/Inbox,
    /// che il sistema ha copiato per noi e che si cancella subito, perché contiene i dati dei clienti).
    func ricevi(_ url: URL) {
        mostraApertura = true
        guard fase != .ripristino else { return }
        scartaFileScelto()
        fase = .copia
        nomeFile = url.lastPathComponent
        DispatchQueue.global(qos: .userInitiated).async {
            let esito: Result<(URL, Bool), Error>
            do {
                let copia = try Self.copiaDiLavoro(url)
                esito = .success((copia, CifraturaBackup.cifrato(copia)))
            } catch {
                esito = .failure(error)
            }
            Task { @MainActor [weak self] in self?.ricevuto(esito) }
        }
    }

    /// Il selettore non ha dato un file (annullato o non leggibile).
    func selezioneFallita(_ errore: Error) {
        fase = .errore("Non riesco ad aprire il file scelto: \(errore.localizedDescription)")
    }

    private func ricevuto(_ esito: Result<(URL, Bool), Error>) {
        switch esito {
        case .success(let (copia, cifrato)):
            guard cifrato || Self.sembraZip(copia) else {
                Self.cancellaCopia(copia)
                fase = .errore(ErroreBackup.archivioMancante.localizedDescription
                               + " Sul Mac: Impostazioni › Archivio › «Crea backup», poi mandalo qui con AirDrop o File.")
                return
            }
            fileScelto = copia
            protetto = cifrato
            fase = .attesa
        case .failure(let errore):
            fase = .errore("Non riesco a leggere il file: \(errore.localizedDescription). Se è su iCloud Drive, aspetta che sia scaricato e riprova.")
        }
    }

    /// Copia il file in tmp/ con l'accesso del sistema (può non servire: `false` non è un errore) e il
    /// coordinamento dei file, che scarica da iCloud Drive un file non ancora sul dispositivo.
    nonisolated static func copiaDiLavoro(_ url: URL) throws -> URL {
        let fm = FileManager.default
        let accesso = url.startAccessingSecurityScopedResource()
        defer { if accesso { url.stopAccessingSecurityScopedResource() } }
        let cartella = fm.temporaryDirectory.appendingPathComponent("backup-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: cartella, withIntermediateDirectories: true)
        let copia = cartella.appendingPathComponent(url.lastPathComponent.isEmpty ? "backup" : url.lastPathComponent)
        var erroreCoordinamento: NSError?
        var erroreCopia: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [.withoutChanges],
                                                         error: &erroreCoordinamento) { letto in
            do { try fm.copyItem(at: letto, to: copia) } catch { erroreCopia = error }
        }
        if let errore = (erroreCoordinamento as Error?) ?? erroreCopia {
            try? fm.removeItem(at: cartella)
            throw errore
        }
        if inArrivo(url) { try? fm.removeItem(at: url) }
        return copia
    }

    /// Uno zip in chiaro (backup non protetto): comincia con «PK\u{3}\u{4}».
    nonisolated private static func sembraZip(_ url: URL) -> Bool {
        guard let lettura = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? lettura.close() }
        let inizio = (try? lettura.read(upToCount: 4)) ?? Data()
        return inizio == Data([0x50, 0x4B, 0x03, 0x04])
    }

    // MARK: - Ripristino

    /// Apre il backup scelto con la password e sostituisce l'archivio del dispositivo. Usa lo stesso
    /// `StatoShell.ripristina` del Mac: copia di sicurezza dell'archivio di prima, decifratura con
    /// CifraturaBackup, estrazione con LettoreZip, sostituzione e dati ricaricati in memoria.
    func ripristina(password: String) {
        guard let file = fileScelto else {
            fase = .errore("Scegli prima il backup da aprire.")
            return
        }
        guard fase != .ripristino, !stato.backupInCorso else { return }
        if protetto && password.isEmpty {
            fase = .errore("Questo backup è protetto: scrivi la password con cui l'hai creato sul Mac.")
            return
        }
        stato.ripristinoDaSbloccare = nil
        let prima = stato.versioneDati
        fase = .ripristino
        stato.ripristina(file, password: protetto ? password : nil)
        // Se non è partito (archivio in sola lettura, prove) StatoShell l'ha già detto con un avviso
        guard stato.backupInCorso else {
            if fase == .ripristino {
                fase = .errore(stato.avviso ?? "Il ripristino non è partito: riprova.")
            }
            return
        }
        attesaEsito = stato.$backupInCorso
            .dropFirst()
            .filter { !$0 }
            .first()
            .sink { [weak self] _ in
                // backupInCorso cambia prima degli ultimi passi: l'esito si legge poco dopo
                // (`self` si cattura di nuovo, debole, nel compito: una variabile catturata non può attraversarlo)
                guard self != nil else { return }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: StatoMobile.ritardoEsito)
                    self?.concludi(versionePrima: prima)
                }
            }
    }

    private func concludi(versionePrima: Int) {
        attesaEsito = nil
        guard fase == .ripristino else { return }
        if stato.versioneDati != versionePrima, stato.ripristinoDaSbloccare == nil,
           stato.avviso?.hasPrefix("Ripristino non riuscito") != true {
            fase = .riuscita
            scartaFileScelto()
        } else if let avviso = stato.avviso, !avviso.isEmpty {
            fase = .errore(avviso)
        } else if stato.ripristinoDaSbloccare == nil {
            fase = .errore("Il ripristino non è riuscito: riprova, oppure crea un nuovo backup sul Mac.")
        }
    }

    private func passwordRifiutata(_ richiesta: RichiestaPasswordBackup) {
        guard fileScelto != nil else { return }
        attesaEsito = nil
        fase = .errore(richiesta.messaggio.isEmpty ? ErroreBackup.passwordErrata.localizedDescription : richiesta.messaggio)
        // La richiesta del Mac non serve qui: niente avvisi che restano aperti
        Task { @MainActor [weak self] in self?.stato.ripristinoDaSbloccare = nil }
    }

    /// Chiude l'apertura del backup (dopo un ripristino, o per guardare i dati di prova).
    func chiudiApertura() {
        guard fase != .ripristino else { return }
        mostraApertura = false
        if fase != .riuscita { scartaFileScelto() }
        fase = .attesa
    }

    /// Riapre la schermata dell'apertura (dal centro di controllo o da Impostazioni › Archivio).
    func apriBackup() {
        pannello = nil
        fase = .attesa
        mostraApertura = true
    }

    private func scartaFileScelto() {
        if let fileScelto { Self.cancellaCopia(fileScelto) }
        fileScelto = nil
        nomeFile = nil
        protetto = false
    }

    nonisolated static func cancellaCopia(_ copia: URL) {
        try? FileManager.default.removeItem(at: copia.deletingLastPathComponent())
    }

    // MARK: - Istantanee

    /// Per le istantanee: un file finto già scelto (nessun disco toccato) e la fase da mostrare.
    func simulaScelta(nome: String, protetto: Bool, fase: FaseApertura) {
        nomeFile = nome
        self.protetto = protetto
        fileScelto = FileManager.default.temporaryDirectory.appendingPathComponent("istantanea").appendingPathComponent(nome)
        self.fase = fase
        mostraApertura = true
    }

    // MARK: - Ciclo di vita

    /// Prisma va in background: i dati si scrivono subito, dentro un compito in background, perché con la
    /// protezione completa dei file a dispositivo bloccato l'archivio non è più scrivibile.
    func inBackground() {
        guard persistente else { return }
        let app = UIApplication.shared
        if compitoSalvataggio == .invalid {
            compitoSalvataggio = app.beginBackgroundTask(withName: "Salvataggio di Prisma") { [weak self] in
                self?.fineCompito()
            }
        }
        stato.salvaOra()
        fineCompito()
    }

    private func fineCompito() {
        guard compitoSalvataggio != .invalid else { return }
        UIApplication.shared.endBackgroundTask(compitoSalvataggio)
        compitoSalvataggio = .invalid
    }

    /// Documents/Inbox (copie di «Apri con» e AirDrop) e tmp/ (copie di lavoro dei backup, PDF condivisi,
    /// documenti in arrivo) si svuotano a ogni avvio: contengono dati dei clienti. Documents/ resta fuori dal
    /// backup iCloud del dispositivo.
    static func pulisciArrivi() {
        let fm = FileManager.default
        if let inbox = cartellaInArrivo {
            try? fm.removeItem(at: inbox)
        }
        if let voci = try? fm.contentsOfDirectory(at: fm.temporaryDirectory, includingPropertiesForKeys: nil) {
            for voce in voci where Self.daSvuotare(voce.lastPathComponent) { try? fm.removeItem(at: voce) }
        }
        if var documenti = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            var valori = URLResourceValues()
            valori.isExcludedFromBackup = true
            try? documenti.setResourceValues(valori)
        }
    }

    /// Le voci di tmp/ con dati dei clienti: copie dei backup («backup-…», anche «backup-invio-…» per il Mac),
    /// PDF da condividere (StampaCarta.cartellaCondivisi) e documenti importati (ImportaDocumentiMobile).
    nonisolated private static func daSvuotare(_ nome: String) -> Bool {
        nome.hasPrefix("backup-") || nome == "pdf-condivisi" || nome == "documenti-in-arrivo"
    }

    nonisolated private static var cartellaInArrivo: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    /// true se il file sta in Documents/Inbox (copiato dal sistema per «Apri con» o AirDrop).
    nonisolated private static func inArrivo(_ url: URL) -> Bool {
        guard let inbox = cartellaInArrivo else { return false }
        let percorso = url.resolvingSymlinksInPath().standardizedFileURL.path
        let cartella = inbox.resolvingSymlinksInPath().standardizedFileURL.path
        return percorso.hasPrefix(cartella + "/")
    }
}

extension StatoShell {
    /// Solo iPhone e iPad: tutte le finestre ridotte in un colpo solo, senza il genio del Mac né lo sfalsamento di
    /// `mostraScrivania` (lo stato delle app resta in StatoShell). Così il prossimo `apri` di un'app qualsiasi
    /// cambia l'elenco e arriva al sink di StatoMobile.
    func riduciTutteSuiOS() {
        guard finestre.contains(where: { !$0.ridotta }) else { return }
        sistema.giroScrivania &+= 1
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            var elenco = finestre
            for i in elenco.indices { elenco[i].ridotta = true }
            finestre = elenco
            sistema.spente.formUnion(elenco.map(\.app))
        }
    }
}
#endif
