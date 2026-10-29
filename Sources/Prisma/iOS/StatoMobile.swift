#if os(iOS)
import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Le schede dell'iPhone (GuscioiPhone).
enum SchedaTelefono: String, Hashable, CaseIterable {
    case clienti, posizioni, agenda, notifiche, altro

    var titolo: String {
        switch self {
        case .clienti: return "Clienti"
        case .posizioni: return "Posizioni"
        case .agenda: return "Agenda"
        case .notifiche: return "Notifiche"
        case .altro: return "Altro"
        }
    }

    var simbolo: String {
        switch self {
        case .clienti: return "person.2"
        case .posizioni: return "chart.pie"
        case .agenda: return "calendar"
        case .notifiche: return "bell"
        case .altro: return "ellipsis.circle"
        }
    }
}

/// Dove porta un tocco negli elenchi dell'iPhone (NavigationStack di ogni scheda).
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
/// la scheda o l'app scelta e il salvataggio prima che il dispositivo si blocchi.
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

    /// L'app mostrata nella colonna di dettaglio dell'iPad (la cambiano la barra laterale con `mostra(_:)`
    /// e le app stesse con `stato.apri(_:)`, che sul Mac porta davanti una finestra).
    @Published var appiPad: AppPrisma = .clienti
    /// Il backup per il Mac: in preparazione, poi pronto da salvare con `.fileExporter`.
    @Published private(set) var preparazioneBackup = false
    @Published var backupDaInviare: DocumentoBackupMobile?
    /// La scheda scelta sull'iPhone e il percorso aperto in ciascuna (le istantanee lo impostano).
    @Published var schedaiPhone: SchedaTelefono = .clienti
    @Published var percorsoClienti: [DestinazioneTelefono] = []
    @Published var percorsoPosizioni: [DestinazioneTelefono] = []
    @Published var percorsoAgenda: [DestinazioneTelefono] = []

    /// Dopo la fine del ripristino, quanto aspettare prima di leggerne l'esito (gli ultimi passi di StatoShell).
    nonisolated static let ritardoEsito: UInt64 = 800_000_000
    /// Dopo la scelta di un file da importare, quanto aspettare che il selettore finisca di chiudersi.
    nonisolated static let ritardoDopoSelettore: UInt64 = 500_000_000

    private var abbonamenti = Set<AnyCancellable>()
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
        // Le app aprono le altre con `stato.apri(_:)` (risultati della Ricerca, importazioni, rimandi): sul Mac
        // la finestra viene davanti, sull'iPad cambia la colonna di dettaglio
        stato.sistema.$elenco
            .map { elenco in elenco.last(where: { !$0.ridotta })?.app }
            .removeDuplicates()
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                guard let self, self.appiPad != app else { return }
                self.appiPad = app
            }
            .store(in: &abbonamenti)
    }

    // MARK: - App dell'iPad

    /// Una voce della barra laterale: l'app va nel dettaglio e, come sul Mac, davanti alle altre in StatoShell
    /// (così le app che chiedono `stato.apri` di quella già davanti non restano senza effetto). In modo cliente
    /// le app riservate non si aprono: lo dice `stato.apri` con il suo avviso.
    func mostra(_ app: AppPrisma) {
        guard stato.appConsentita(app) else {
            stato.apri(app)
            return
        }
        appiPad = app
        if stato.sistema.appAttiva != app { stato.apri(app) }
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

    /// Riapre la schermata dell'apertura (da «Altro» sull'iPhone o dalla barra dell'iPad).
    func apriBackup() {
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
#endif
