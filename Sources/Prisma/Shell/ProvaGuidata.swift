import AppKit
import SwiftUI

/// Prova guidata della fluidità (menu Aiuto › «Prova la fluidità…»), sul Mac dell'utente e con l'app vera.
/// In mezzo minuto Prisma fa da solo: apre tre o quattro app dal dock, passa dall'una all'altra, ne riduce una
/// nel dock e la ripristina, ingrandisce e rimpicciolisce, apre e chiude il centro notifiche, blocca e sblocca;
/// alla fine l'utente passa il puntatore sul dock. Ogni azione è un tratto di MisuratoreFluidita (fotogrammi
/// persi, passo peggiore, blocchi del thread principale, ritmo dell'acqua). Usa solo app che non sono aperte e
/// alla fine rimette tutto com'era: app aperte, pannelli, cliente attivo. Esc o «Interrompi» la fermano.
/// I risultati non contengono dati dei clienti (solo nomi delle app e conteggi).
@MainActor
final class ProvaGuidata {
    static let condivisa = ProvaGuidata()

    /// Un'azione della prova.
    private struct Passo {
        let nome: String
        var durata: Double = Misure.Fluidita.tratto
        /// Un'istruzione per l'utente, mostrata prima della misura.
        var preavviso: String? = nil
        let azione: @MainActor (StatoShell) -> Void
    }

    /// Lo stato dell'utente da rimettere alla fine.
    private struct Inizio {
        let clienteAttivoId: String
        let notifiche: Bool
        let spazi: Bool
        let appAperte: Bool
        let finestre: Int
        let memoria: Double
    }

    private typealias M = Misure.Fluidita

    private var compito: Task<Void, Never>?
    private var interrotta = false
    private var monitorTasti: Any?
    private var pannello: NSPanel?
    private var finestraRisultati: NSWindow?
    private let avanzamento = AvanzamentoProvaGuidata()

    /// Le app che la prova può aprire, in ordine di preferenza (né Eve né Impostazioni, che avviano lavori propri;
    /// né la Ricerca, che dal dock apre il pannello ⌘K e non una finestra).
    private static let candidate: [AppPrisma] = [
        .clienti, .posizioni, .agenda, .attivita, .analisi360, .note, .prodotti,
        .documenti, .obiettivi, .incontri, .simulazioni, .confronti,
    ]

    // MARK: Avvio e arresto

    /// Dal menu: avvia la prova (con un avviso) o, se è in corso, la interrompe.
    func avvia(stato: StatoShell) {
        if compito != nil {
            interrompi()
            return
        }
        chiudiRisultati()
        if let motivo = impedimento(stato) {
            avvisa("La prova della fluidità non può partire", motivo)
            return
        }
        let app = Self.appDiProva(stato)
        guard app.count >= 3 else {
            avvisa("La prova della fluidità non può partire",
                   "Servono almeno tre app chiuse da aprire e chiudere: chiudi qualche app e riprova.")
            return
        }
        let passi = Self.passi(app)
        let secondi = passi.reduce(M.attesaIniziale) { $0 + $1.durata + ($1.preavviso == nil ? 0 : M.preavviso) }
        let conferma = NSAlert()
        conferma.messageText = "Prova della fluidità"
        conferma.informativeText = "Per circa \(Int(secondi.rounded(.up))) secondi Prisma lavora da solo: apre e chiude "
            + "alcune app (\(app.map(\.titolo).joined(separator: ", "))), passa dall'una all'altra, riduce una finestra "
            + "nel dock e la ripristina, ingrandisce, apre il centro notifiche, blocca e sblocca. Alla fine ti chiede di "
            + "passare il puntatore sul dock per qualche secondo.\n\n"
            + "Nel frattempo non toccare mouse e tastiera; Esc interrompe. Poi Prisma torna com'era e mostra i risultati, "
            + "senza dati dei clienti."
        conferma.addButton(withTitle: "Avvia la prova")
        conferma.addButton(withTitle: "Annulla")
        guard conferma.runModal() == .alertFirstButtonReturn else { return }
        let finestra = finestraPrisma()
        finestra?.makeKeyAndOrderFront(nil)
        guard MisuratoreFluidita.condiviso.avvia(schermo: Self.numeroSchermo(finestra)) else {
            avvisa("La prova della fluidità non è disponibile", "Il Mac non ha dato l'orologio dello schermo (CVDisplayLink).")
            return
        }
        interrotta = false
        compito = Task { await self.corri(stato: stato, app: app, passi: passi, finestra: finestra) }
    }

    /// Esc o «Interrompi»: la prova si ferma al tratto in corso e rimette tutto com'era.
    func interrompi() {
        guard compito != nil else { return }
        interrotta = true
        compito?.cancel()
    }

    func chiudiRisultati() {
        finestraRisultati?.close()
        finestraRisultati = nil
    }

    /// Ciò che impedisce la prova (nil se può partire).
    private func impedimento(_ stato: StatoShell) -> String? {
        if !stato.persistente { return "La prova gira solo nell'app vera." }
        if stato.bloccato { return "Togli prima la schermata di benvenuto, poi riprova." }
        if stato.modoCliente != nil { return "Esci prima dalla modalità cliente: la prova apre app che lì restano chiuse." }
        if stato.presentazione != nil { return "Chiudi prima la presentazione, poi riprova." }
        if stato.menu.conversazioneAVoce {
            return "Chiudi prima la conversazione con Eve: la schermata di benvenuto la fermerebbe."
        }
        return nil
    }

    /// Fino a quattro app non aperte, consentite.
    private static func appDiProva(_ stato: StatoShell) -> [AppPrisma] {
        Array(candidate.filter { !stato.aperta($0) && stato.appConsentita($0) }.prefix(4))
    }

    /// Le azioni, con tre app (A, B, C) e una quarta facoltativa (D). Le finestre nuove nascono ingrandite.
    private static func passi(_ app: [AppPrisma]) -> [Passo] {
        let a = app[0], b = app[1], c = app[2]
        var elenco: [Passo] = [
            Passo(nome: "Riposo, nessuna azione", durata: M.riposo) { _ in },
            Passo(nome: "Apri \(a.titolo) dal dock") { $0.apri(a) },
            Passo(nome: "\(a.titolo): esci dall'ingrandimento") { $0.alternaIngrandimento(a) },
            Passo(nome: "Apri \(b.titolo) dal dock") { $0.apri(b) },
            Passo(nome: "\(b.titolo): esci dall'ingrandimento") { $0.alternaIngrandimento(b) },
            Passo(nome: "Apri \(c.titolo) dal dock") { $0.apri(c) },
            Passo(nome: "\(c.titolo): esci dall'ingrandimento") { $0.alternaIngrandimento(c) },
            Passo(nome: "Passa a \(a.titolo)") { $0.apri(a) },
            Passo(nome: "Passa a \(b.titolo)") { $0.apri(b) },
            Passo(nome: "Riduci \(b.titolo) nel dock") { $0.riduci(b) },
            Passo(nome: "Ripristina \(b.titolo) dal dock") { $0.apri(b) },
            Passo(nome: "Ingrandisci \(c.titolo)") { $0.alternaIngrandimento(c) },
            Passo(nome: "\(c.titolo): esci dall'ingrandimento") { $0.alternaIngrandimento(c) },
            Passo(nome: "Apri il centro notifiche") { s in if !s.pannelloNotifiche { s.alternaNotifiche() } },
            Passo(nome: "Chiudi il centro notifiche") { s in if s.pannelloNotifiche { s.alternaNotifiche() } },
            Passo(nome: "Blocca (schermata di benvenuto)") { $0.blocca() },
            Passo(nome: "Sblocca") { $0.sblocca() },
        ]
        if app.count > 3 {
            let d = app[3]
            elenco.append(Passo(nome: "Apri \(d.titolo) dal dock") { $0.apri(d) })
            elenco.append(Passo(nome: "Chiudi \(d.titolo)") { $0.chiudi(d) })
        }
        elenco.append(Passo(nome: "Chiudi \(c.titolo)") { $0.chiudi(c) })
        elenco.append(Passo(nome: "Chiudi \(b.titolo)") { $0.chiudi(b) })
        elenco.append(Passo(nome: "Chiudi \(a.titolo)") { $0.chiudi(a) })
        elenco.append(Passo(nome: "Dock: passaggio del puntatore (lo fai tu)", durata: M.dock,
                            preavviso: "Ora passa il puntatore avanti e indietro sul dock, in basso, senza cliccare, "
                                + "finché la prova finisce.") { _ in })
        return elenco
    }

    // MARK: La prova

    private func corri(stato: StatoShell, app: [AppPrisma], passi: [Passo], finestra: NSWindow?) async {
        let inizio = Inizio(clienteAttivoId: stato.clienteAttivoId, notifiche: stato.pannelloNotifiche,
                            spazi: stato.pannelloSpazi, appAperte: stato.pannelloAppAperte,
                            finestre: stato.finestre.count, memoria: MisuratoreFluidita.improntaMB())
        let calmo = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // Con il risparmio energetico l'acqua resta in moto (a ritmo ridotto): il giudizio confronta i ritmi in proporzione
        let acquaInMoto = stato.dati.impostazioni.sfondoAnimato && !calmo
        let misuratore = MisuratoreFluidita.condiviso
        avanzamento.indice = 0
        avanzamento.totale = passi.count
        avanzamento.voce = "Si comincia…"
        avanzamento.istruzione = nil
        mostraPannello(sopra: finestra)
        installaTasti()
        // I pannelli aperti si chiudono prima della misura (e alla fine si riaprono)
        if stato.pannelloNotifiche { stato.alternaNotifiche() }
        if stato.pannelloSpazi { stato.pannelloSpazi = false }
        if stato.pannelloAppAperte { stato.pannelloAppAperte = false }
        await pausa(M.attesaIniziale)

        var righe: [RigaProvaGuidata] = []
        for (i, passo) in passi.enumerated() {
            if interrotta { break }
            avanzamento.indice = i
            avanzamento.voce = passo.nome
            avanzamento.istruzione = passo.preavviso
            if passo.preavviso != nil {
                await pausa(M.preavviso)
                if interrotta { break }
            }
            let copertaPrima = stato.scrivaniaCoperta
            misuratore.iniziaTratto()
            passo.azione(stato)
            await pausa(passo.durata)
            let tratto = misuratore.chiudiTratto()
            if interrotta { break }
            righe.append(RigaProvaGuidata(azione: passo.nome, tratto: tratto,
                                          acquaAttesa: acquaInMoto && !copertaPrima && !stato.scrivaniaCoperta))
        }
        avanzamento.indice = passi.count
        let hertz = misuratore.hertz
        misuratore.ferma()
        togliTasti()
        chiudiPannello()
        rimetti(stato, inizio: inizio, app: app)
        compito = nil
        guard !righe.isEmpty else { return }
        let contesto = Self.contesto(stato: stato, finestra: finestra, app: app, inizio: inizio, hertz: hertz, calmo: calmo)
        let resoconto = ResocontoProvaGuidata(quando: Date(), contesto: contesto, righe: Self.giudica(righe),
                                              interrotta: interrotta, totaleAzioni: passi.count, calmo: calmo,
                                              acquaInMoto: acquaInMoto)
        misuratore.registra(resoconto.testo)
        mostraRisultati(resoconto, sopra: finestra)
    }

    /// Attende senza bloccare il thread principale (si sveglia subito se la prova è interrotta).
    private func pausa(_ secondi: Double) async {
        guard secondi > 0, !interrotta else { return }
        try? await Task.sleep(nanoseconds: UInt64(secondi * 1_000_000_000))
    }

    /// Rimette lo stato dell'utente: chiude le app della prova, toglie il blocco, riapre i pannelli.
    private func rimetti(_ stato: StatoShell, inizio: Inizio, app: [AppPrisma]) {
        for a in app where stato.aperta(a) { stato.chiudi(a) }
        if stato.bloccato { stato.sblocca() }
        if stato.pannelloNotifiche != inizio.notifiche { stato.alternaNotifiche() }
        if inizio.spazi && !stato.pannelloSpazi { stato.pannelloSpazi = true }
        if inizio.appAperte && !stato.pannelloAppAperte { stato.pannelloAppAperte = true }
        if stato.clienteAttivoId != inizio.clienteAttivoId { stato.clienteAttivoId = inizio.clienteAttivoId }
    }

    /// Il giudizio di ogni azione. Il ritmo dell'acqua si confronta con quello a riposo (o il migliore misurato),
    /// solo nei tratti in cui l'acqua doveva muoversi dall'inizio alla fine.
    private static func giudica(_ righe: [RigaProvaGuidata]) -> [RigaProvaGuidata] {
        let inMoto = righe.filter { $0.acquaAttesa && $0.tratto.acqua > 0 }
        let riferimento: Double
        if let primo = righe.first, primo.acquaAttesa, primo.tratto.acqua > 0 {
            riferimento = primo.tratto.acquaAlSecondo
        } else {
            riferimento = inMoto.map(\.tratto.acquaAlSecondo).max() ?? 0
        }
        return righe.map { (r: RigaProvaGuidata) -> RigaProvaGuidata in
            var riga = r
            let t = r.tratto
            var g: GiudizioFluidita
            if t.quotaPersi <= M.fluidaQuota && t.peggiore <= M.fluidaPeggiore && t.blocchi == 0 {
                g = .fluida
            } else if t.quotaPersi <= M.scattiQuota && t.peggiore <= M.scattiPeggiore {
                g = .scatti
            } else {
                g = .lenta
            }
            if r.acquaAttesa && riferimento > 0 {
                let quota = t.acquaAlSecondo / riferimento
                if quota < M.acquaLenta {
                    g = max(g, .lenta)
                } else if quota < M.acquaScatti {
                    g = max(g, .scatti)
                }
            }
            riga.giudizio = g
            return riga
        }
    }

    // MARK: Il Mac

    /// Il Mac, lo schermo e le condizioni della prova (niente dati dei clienti: solo conteggi e nomi delle app).
    private static func contesto(stato: StatoShell, finestra: NSWindow?, app: [AppPrisma], inizio: Inizio,
                                 hertz: Int, calmo: Bool) -> [VoceContesto] {
        let info = ProcessInfo.processInfo
        let memoria = Int((Double(info.physicalMemory) / 1_073_741_824).rounded())
        let mac = [MisuratoreFluidita.valoreDiSistema("hw.model"),
                   MisuratoreFluidita.valoreDiSistema("machdep.cpu.brand_string"),
                   "\(memoria) GB di memoria"].compactMap { $0 }.joined(separator: " · ")
        let v = info.operatingSystemVersion
        var sistema = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        if let build = MisuratoreFluidita.valoreDiSistema("kern.osversion") { sistema += " (\(build))" }
        var schermo = "\(hertz) Hz"
        if let s = finestra?.screen ?? NSScreen.main {
            let massimo = s.maximumFramesPerSecond
            if massimo > 0 && massimo != hertz { schermo += " (fino a \(massimo) Hz)" }
            schermo += " · \(Int(s.frame.width))×\(Int(s.frame.height)) punti · Retina "
                + String(format: "%g", Double(s.backingScaleFactor)) + "×"
        }
        var cornice = "non trovata"
        if let f = finestra {
            cornice = "\(Int(f.frame.width))×\(Int(f.frame.height)) punti"
            if f.styleMask.contains(.fullScreen) { cornice += " · a tutto schermo" }
        }
        let aspetto = (finestra?.effectiveAppearance ?? NSApp.effectiveAppearance).bestMatch(from: [.aqua, .darkAqua])
        let temperatura: String
        switch info.thermalState {
        case .nominal: temperatura = "normale"
        case .fair: temperatura = "tiepido"
        case .serious: temperatura = "caldo (il Mac rallenta)"
        case .critical: temperatura = "molto caldo (il Mac rallenta)"
        @unknown default: temperatura = "sconosciuta"
        }
        return [
            VoceContesto(etichetta: "Mac", valore: mac),
            VoceContesto(etichetta: "macOS", valore: sistema),
            VoceContesto(etichetta: "Schermo", valore: schermo),
            VoceContesto(etichetta: "Finestra di Prisma", valore: cornice),
            VoceContesto(etichetta: "Aspetto", valore: aspetto == NSAppearance.Name.darkAqua ? "scuro" : "chiaro"),
            VoceContesto(etichetta: "Riduci movimento", valore: calmo ? "acceso" : "spento"),
            VoceContesto(etichetta: "Risparmio energetico", valore: info.isLowPowerModeEnabled ? "acceso" : "spento"),
            VoceContesto(etichetta: "Sfondo d'acqua", valore: stato.dati.impostazioni.sfondoAnimato ? "in movimento" : "fermo"),
            VoceContesto(etichetta: "Temperatura del Mac", valore: temperatura),
            VoceContesto(etichetta: "Memoria di Prisma",
                         valore: "\(Int(inizio.memoria.rounded())) MB all'inizio, \(Int(MisuratoreFluidita.improntaMB().rounded())) MB alla fine"),
            VoceContesto(etichetta: "Archivio", valore: "\(stato.dati.clienti.count) clienti, \(stato.dati.posizioni.count) posizioni"),
            VoceContesto(etichetta: "App della prova", valore: app.map(\.titolo).joined(separator: ", ")),
            VoceContesto(etichetta: "Finestre già aperte", valore: inizio.finestre == 0 ? "nessuna" : "\(inizio.finestre)"),
        ]
    }

    private static func numeroSchermo(_ finestra: NSWindow?) -> CGDirectDisplayID? {
        let schermo = finestra?.screen ?? NSScreen.main
        guard let numero = schermo?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return CGDirectDisplayID(numero.uint32Value)
    }

    /// La finestra di Prisma (non i riquadri della prova).
    private func finestraPrisma() -> NSWindow? {
        let mie: [NSWindow?] = [finestraRisultati, pannello]
        func valida(_ f: NSWindow) -> Bool { f.isVisible && !(f is NSPanel) && !mie.contains { $0 === f } }
        if let f = NSApp.mainWindow, valida(f) { return f }
        return NSApp.windows.first(where: valida)
    }

    // MARK: Riquadri

    private func avvisa(_ titolo: String, _ testo: String) {
        let avviso = NSAlert()
        avviso.messageText = titolo
        avviso.informativeText = testo
        _ = avviso.runModal()
    }

    /// Esc ferma la prova (il tasto non arriva alle app).
    private func installaTasti() {
        guard monitorTasti == nil else { return }
        monitorTasti = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { evento in
            guard evento.keyCode == Misure.Fluidita.tastoEsc else { return evento }
            Task { @MainActor in ProvaGuidata.condivisa.interrompi() }
            return nil
        }
    }

    private func togliTasti() {
        if let m = monitorTasti { NSEvent.removeMonitor(m) }
        monitorTasti = nil
    }

    /// Il riquadro dell'avanzamento, in basso a sinistra sulla finestra di Prisma, senza rubarle la tastiera.
    private func mostraPannello(sopra finestra: NSWindow?) {
        chiudiPannello()
        let host = NSHostingView(rootView: VistaAvanzamento(avanzamento: avanzamento))
        let misura = host.fittingSize
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: misura),
                        styleMask: [.titled, .utilityWindow, .nonactivatingPanel], backing: .buffered, defer: false)
        p.title = "Prova della fluidità"
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = true
        p.hidesOnDeactivate = true
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        p.contentView = host
        if let f = finestra?.frame {
            p.setFrameOrigin(NSPoint(x: f.minX + M.staccoAvanzamento, y: f.minY + M.staccoAvanzamento))
        } else {
            p.center()
        }
        p.orderFront(nil)
        pannello = p
    }

    private func chiudiPannello() {
        pannello?.orderOut(nil)
        pannello = nil
    }

    private func mostraRisultati(_ resoconto: ResocontoProvaGuidata, sopra finestra: NSWindow?) {
        chiudiRisultati()
        let host = NSHostingView(rootView: RisultatiProvaGuidata(resoconto: resoconto))
        let misura = NSSize(width: M.larghezzaRisultati, height: M.altezzaRisultati)
        let f = NSWindow(contentRect: NSRect(origin: .zero, size: misura),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        f.title = "Fluidità di Prisma"
        f.isReleasedWhenClosed = false
        f.contentView = host
        if let p = finestra?.frame {
            f.setFrameOrigin(NSPoint(x: p.midX - f.frame.width / 2, y: p.midY - f.frame.height / 2))
        } else {
            f.center()
        }
        finestraRisultati = f
        f.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Risultati

/// Giudizio di un'azione della prova guidata.
enum GiudizioFluidita: Int, Comparable {
    case fluida, scatti, lenta

    static func < (a: GiudizioFluidita, b: GiudizioFluidita) -> Bool { a.rawValue < b.rawValue }

    var testo: String {
        switch self {
        case .fluida: return "fluida"
        case .scatti: return "qualche scatto"
        case .lenta: return "lenta"
        }
    }

    var colore: Color {
        switch self {
        case .fluida: return Colori.Analisi.okTesto
        case .scatti: return Colori.Analisi.attenzioneTesto
        case .lenta: return Colori.Analisi.erroreTesto
        }
    }
}

struct RigaProvaGuidata {
    let azione: String
    let tratto: MisuratoreFluidita.Tratto
    /// L'acqua doveva muoversi per tutto il tratto (sfondo animato, scrivania scoperta prima e dopo).
    let acquaAttesa: Bool
    var giudizio: GiudizioFluidita = .fluida
}

struct VoceContesto {
    let etichetta: String
    let valore: String
}

struct ResocontoProvaGuidata {
    let quando: Date
    let contesto: [VoceContesto]
    let righe: [RigaProvaGuidata]
    let interrotta: Bool
    let totaleAzioni: Int
    let calmo: Bool
    let acquaInMoto: Bool

    static let legenda = "Persi: fotogrammi in cui il thread principale di Prisma era occupato, su quelli attesi. "
        + "Peggiore: la pausa più lunga tra due fotogrammi (a 60 Hz uno ogni 17 ms). Blocchi: pause oltre 50 ms. "
        + "Acqua: fotogrammi al secondo dello sfondo («ferma» se la scrivania era coperta)."

    /// L'esito complessivo: quello dell'azione peggiore.
    var giudizio: GiudizioFluidita { righe.map(\.giudizio).max() ?? .fluida }

    /// L'acqua ha segnato almeno un fotogramma (altrimenti il suo ritmo non si è potuto misurare).
    var acquaMisurata: Bool { righe.contains { $0.tratto.acqua > 0 } }

    var sintesi: String {
        func conta(_ g: GiudizioFluidita) -> Int { righe.filter { $0.giudizio == g }.count }
        let f = conta(.fluida), s = conta(.scatti), l = conta(.lenta)
        return "Su \(righe.count) azioni: \(f) \(f == 1 ? "fluida" : "fluide"), \(s) con qualche scatto, "
            + "\(l) \(l == 1 ? "lenta" : "lente")."
    }

    var avvertenze: [String] {
        var elenco: [String] = []
        if interrotta { elenco.append("Prova interrotta: misurate \(righe.count) azioni su \(totaleAzioni).") }
        if calmo { elenco.append("Riduci movimento è acceso: le animazioni sono dissolvenze brevi e la prova misura quelle.") }
        if !acquaInMoto {
            elenco.append("L'acqua era ferma per scelta o per il Mac (sfondo fermo, Riduci movimento o Risparmio energetico).")
        } else if !acquaMisurata {
            elenco.append("Il ritmo dell'acqua non si è potuto misurare (scrivania sempre coperta o contatore non disponibile).")
        }
        return elenco
    }

    func ms(_ secondi: Double) -> Int { Int((secondi * 1000).rounded()) }

    func persi(_ r: RigaProvaGuidata) -> String { "\(r.tratto.persi) su \(r.tratto.attesi)" }

    func peggiore(_ r: RigaProvaGuidata) -> String { "\(ms(r.tratto.peggiore)) ms" }

    func acqua(_ r: RigaProvaGuidata) -> String {
        guard acquaMisurata else { return "—" }
        return r.tratto.acqua > 0 ? "\(Int(r.tratto.acquaAlSecondo.rounded()))/s" : "ferma"
    }

    /// Il testo semplice per «Copia i risultati».
    var testo: String {
        let data = DateFormatter()
        data.locale = Locale(identifier: "it_IT")
        data.dateFormat = "dd/MM/yyyy HH:mm"
        var righeTesto = ["Prova della fluidità di Prisma · \(data.string(from: quando))",
                          "Esito: \(giudizio.testo). \(sintesi)"]
        righeTesto += avvertenze
        righeTesto.append("")
        righeTesto += contesto.map { "\($0.etichetta): \($0.valore)" }
        righeTesto.append("")
        righeTesto.append("Azioni (persi su attesi · peggiore · blocchi oltre 50 ms · acqua · giudizio):")
        righeTesto += righe.map { r in
            "- \(r.azione): \(persi(r)) · \(peggiore(r)) · \(r.tratto.blocchi) · \(acqua(r)) · \(r.giudizio.testo)"
        }
        return righeTesto.joined(separator: "\n")
    }
}

/// Lo stato del riquadro dell'avanzamento.
final class AvanzamentoProvaGuidata: ObservableObject {
    @Published var indice = 0
    @Published var totale = 1
    @Published var voce = ""
    @Published var istruzione: String?
}

private struct VistaAvanzamento: View {
    @ObservedObject var avanzamento: AvanzamentoProvaGuidata

    var body: some View {
        VStack(alignment: .leading, spacing: Misure.Fluidita.spaziatura) {
            Text("Azione \(min(avanzamento.indice + 1, avanzamento.totale)) di \(avanzamento.totale)")
                .font(Tipo.provaTesta)
            Text(avanzamento.istruzione ?? avanzamento.voce)
                .font(Tipo.provaTesto)
                .fixedSize(horizontal: false, vertical: true)
            ProgressView(value: Double(min(avanzamento.indice, avanzamento.totale)), total: Double(max(avanzamento.totale, 1)))
            HStack {
                Text("Esc interrompe")
                    .font(Tipo.provaPiccolo)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Interrompi") { ProvaGuidata.condivisa.interrompi() }
            }
        }
        .padding(Misure.Fluidita.margine)
        .frame(width: Misure.Fluidita.larghezzaAvanzamento, alignment: .leading)
    }
}

private struct RisultatiProvaGuidata: View {
    let resoconto: ResocontoProvaGuidata
    @State private var copiati = false

    private typealias M = Misure.Fluidita

    var body: some View {
        VStack(alignment: .leading, spacing: M.spaziatura) {
            Text("Fluidità di Prisma")
                .font(Tipo.provaTitolo)
            HStack(spacing: M.spaziaturaRighe) {
                Text("Esito:")
                    .font(Tipo.provaTesto)
                Text(resoconto.giudizio.testo)
                    .font(Tipo.provaGiudizio)
                    .foregroundStyle(resoconto.giudizio.colore)
                Text(resoconto.sintesi)
                    .font(Tipo.provaTesto)
            }
            ForEach(resoconto.avvertenze, id: \.self) { avvertenza in
                Text(avvertenza)
                    .font(Tipo.provaPiccolo)
                    .foregroundStyle(Colori.Analisi.attenzioneTesto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            contesto
            Divider()
            ScrollView {
                tabella
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(ResocontoProvaGuidata.legenda)
                .font(Tipo.provaPiccolo)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if copiati {
                    Text("Copiati: incollali nella chat.")
                        .font(Tipo.provaPiccolo)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Chiudi") { ProvaGuidata.condivisa.chiudiRisultati() }
                    .keyboardShortcut(.cancelAction)
                Button("Copia i risultati") { copia() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(M.margine)
        .frame(width: M.larghezzaRisultati, height: M.altezzaRisultati, alignment: .topLeading)
    }

    private var contesto: some View {
        Grid(alignment: .leading, horizontalSpacing: M.spaziaturaColonne, verticalSpacing: M.spaziaturaContesto) {
            ForEach(Array(resoconto.contesto.enumerated()), id: \.offset) { _, voce in
                GridRow {
                    Text(voce.etichetta)
                        .font(Tipo.provaPiccolo)
                        .foregroundStyle(Colori.Analisi.tabellaTesta)
                    Text(voce.valore)
                        .font(Tipo.provaPiccolo)
                }
            }
        }
    }

    private var tabella: some View {
        Grid(alignment: .leading, horizontalSpacing: M.spaziaturaColonne, verticalSpacing: M.spaziaturaRighe) {
            GridRow {
                testa("Azione")
                testa("Persi").gridColumnAlignment(.trailing)
                testa("Peggiore").gridColumnAlignment(.trailing)
                testa("Blocchi").gridColumnAlignment(.trailing)
                testa("Acqua").gridColumnAlignment(.trailing)
                testa("Giudizio")
            }
            Divider()
            ForEach(Array(resoconto.righe.enumerated()), id: \.offset) { _, riga in
                GridRow {
                    cella(riga.azione)
                    cella(resoconto.persi(riga))
                    cella(resoconto.peggiore(riga))
                    cella("\(riga.tratto.blocchi)")
                    cella(resoconto.acqua(riga))
                    Text(riga.giudizio.testo)
                        .font(Tipo.provaGiudizio)
                        .foregroundStyle(riga.giudizio.colore)
                }
            }
        }
    }

    private func testa(_ testo: String) -> some View {
        Text(testo)
            .font(Tipo.provaTesta)
            .foregroundStyle(Colori.Analisi.tabellaTesta)
    }

    private func cella(_ testo: String) -> some View {
        Text(testo)
            .font(Tipo.provaTabella)
    }

    private func copia() {
        let appunti = NSPasteboard.general
        appunti.clearContents()
        appunti.setString(resoconto.testo, forType: .string)
        copiati = true
    }
}
