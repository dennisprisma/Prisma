import AppKit
import SwiftUI

/// Stato della finestra Prisma: finestre interne aperte, cliente attivo, avvisi.
final class StatoShell: ObservableObject {
    struct Finestra: Identifiable, Equatable {
        let app: AppPrisma
        var id: AppPrisma { app }
        /// Cornice quando non è ingrandita, nelle coordinate dell'area delle finestre.
        var cornice: CGRect
        var ingrandita = true
        var ridotta = false
    }

    /// Finestre aperte; l'ultima è quella in primo piano.
    @Published private(set) var finestre: [Finestra] = []
    @Published var clienteAttivoId: String
    @Published private(set) var avviso: String?
    @Published var schermoIntero = false

    @Published var clienti: [Cliente]
    @Published var appuntamenti: [Appuntamento]
    @Published var attivita: [Attivita]

    /// Nome dell'utente mostrato nel saluto della scrivania.
    let nomeUtente = "Dennis"
    let inizialiUtente = "DV"

    /// Area disponibile per le finestre (sotto la barra, sopra il dock), aggiornata dalla vista.
    var area: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 700)

    private var lavoroAvviso: DispatchWorkItem?

    init() {
        clienti = DatiDemo.clienti()
        appuntamenti = DatiDemo.appuntamenti()
        attivita = DatiDemo.attivita()
        clienteAttivoId = "giulia"
    }

    // MARK: - Lettura

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

    func apri(_ app: AppPrisma) {
        withAnimation(Animazioni.apertura) {
            if let i = finestre.firstIndex(where: { $0.app == app }) {
                var f = finestre.remove(at: i)
                f.ridotta = false
                finestre.append(f)
            } else {
                finestre.append(Finestra(app: app, cornice: corniceIniziale()))
            }
        }
    }

    func primoPiano(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), i != finestre.count - 1 else { return }
        let f = finestre.remove(at: i)
        finestre.append(f)
    }

    func chiudi(_ app: AppPrisma) {
        withAnimation(Animazioni.apertura) {
            finestre.removeAll { $0.app == app }
        }
    }

    func riduci(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }) else { return }
        withAnimation(Animazioni.apertura) {
            finestre[i].ridotta = true
        }
    }

    func alternaIngrandimento(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }) else { return }
        withAnimation(Animazioni.apertura) {
            finestre[i].ingrandita.toggle()
            if !finestre[i].ingrandita {
                finestre[i].cornice = limita(finestre[i].cornice)
            }
        }
        primoPiano(app)
    }

    /// Riduce tutte le finestre e mostra la scrivania.
    func mostraScrivania() {
        withAnimation(Animazioni.apertura) {
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
        guard let i = attivita.firstIndex(where: { $0.id == id }) else { return }
        attivita[i].completata.toggle()
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
