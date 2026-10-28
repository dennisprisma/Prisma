import AppKit
import SwiftUI

@main
struct PrismaApp: App {
    // L'App tiene lo stato senza osservarlo: i Commands e il menu non si ricostruiscono a ogni cambiamento.
    // `static let` è pigro: nelle modalità `--prova-*` e `--istantanee` (che escono in init) lo stato non nasce
    private static let condiviso = StatoShell()
    private var stato: StatoShell { Self.condiviso }

    init() {
        let argomenti = CommandLine.arguments
        if argomenti.contains("--verifica-risorse") {
            exit(Risorse.verifica())
        }
        if argomenti.contains("--prova-backup") {
            exit(ProvaBackup.esegui())
        }
        if argomenti.contains("--prova-calcoli") {
            exit(ProvaCalcoli.esegui())
        }
        if argomenti.contains("--prova-eve") {
            exit(ProvaEve.esegui())
        }
        if argomenti.contains("--prova-carico") {
            exit(ProvaCarico.esegui())
        }
        if let i = argomenti.firstIndex(of: "--prova-fluidita") {
            // Facoltativo: il file in cui scrivere la tabella (Markdown) per il riepilogo della build
            let file = i + 1 < argomenti.count && !argomenti[i + 1].hasPrefix("--") ? URL(fileURLWithPath: argomenti[i + 1]) : nil
            exit(ProvaFluidita.esegui(uscita: file))
        }
        if let i = argomenti.firstIndex(of: "--prova-prospetti") {
            let cartella = i + 1 < argomenti.count && !argomenti[i + 1].hasPrefix("--") ? URL(fileURLWithPath: argomenti[i + 1], isDirectory: true) : nil
            exit(ProvaProspetti.esegui(cartella: cartella))
        }
        if let i = argomenti.firstIndex(of: "--istantanee"), i + 1 < argomenti.count {
            func valore(_ opzione: String) -> String? {
                argomenti.firstIndex(of: opzione).flatMap { $0 + 1 < argomenti.count ? argomenti[$0 + 1] : nil }
            }
            let metodo = valore("--metodo") ?? "finestra"
            // --testo 1.2: le schermate con il testo ingrandito; --solo a,b: solo quelle scene
            if let t = valore("--testo").flatMap(Double.init) { Tipo.fattore = CGFloat(t) }
            let solo = valore("--solo").map { Set($0.split(separator: ",").map(String.init)) }
            exit(Istantanee.genera(in: URL(fileURLWithPath: argomenti[i + 1], isDirectory: true), metodo: metodo, solo: solo))
        }
        // Avvio vero: l'archivio e Metal si preparano in background mentre nasce la finestra
        if !argomenti.contains(where: { $0.hasPrefix("--") }) {
            AvvioArchivio.avvia()
            Preriscaldamento.avvia()
        }
    }

    var body: some Scene {
        Window("Prisma", id: "prisma") {
            // Aspetto scelto in Impostazioni: lo applicano StatoShell.init (prima del primo disegno) e ShellView (ai cambi)
            ShellView()
                .environmentObject(stato)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .commands { ComandiPrisma(stato: stato, menu: stato.menu) }
    }

    /// Chiaro, scuro o come il Mac: vale per tutta l'app (i PDF restano comunque chiari).
    @MainActor static func applicaAspetto(_ aspetto: AspettoInterfaccia) {
        NSApp.appearance = aspetto.aspettoMac
    }
}

/// I menu di Prisma. Le azioni passano dallo stato (non osservato); titoli e abilitazioni vengono da StatoMenu,
/// l'unico oggetto osservato: il menu si ricostruisce solo quando cambia uno di quei quattro valori.
struct ComandiPrisma: Commands {
    let stato: StatoShell
    @ObservedObject var menu: StatoMenu

    var body: some Commands {
        CommandMenu("Vai") {
            // Con la schermata di benvenuto davanti, niente si apre dietro di lei
            Group {
            Button("Cerca ovunque") { stato.cercaOvunque() }
                .keyboardShortcut("k", modifiers: .command)
            Button(menu.inModoCliente ? "Esci dalla modalità cliente" : "Modalità cliente") { stato.alternaModoCliente() }
                .keyboardShortcut("m", modifiers: [.command, .option])
            Button("Spazi di lavoro…") { stato.pannelloSpazi = true }
                .disabled(menu.inModoCliente)
            Button("Le tue app aperte…") { stato.pannelloAppAperte = true }
            Button(menu.conversazioneAVoce ? "Chiudi la conversazione con Eve" : "Parla con Eve") { stato.alternaAscolto(daMenu: true) }
                .keyboardShortcut("e", modifiers: [.command, .option])
            Divider()
            Button("Scrivania") { stato.mostraScrivania() }
                .keyboardShortcut("0", modifiers: .option)
            Divider()
            ForEach(Array(AppPrisma.allCases.prefix(9).enumerated()), id: \.element) { indice, app in
                Button(app.titolo) { stato.apri(app) }
                    .keyboardShortcut(KeyEquivalent(Character("\(indice + 1)")), modifiers: .option)
            }
            Divider()
            ForEach(Array(AppPrisma.allCases.dropFirst(9))) { app in
                Button(app.titolo) { stato.apri(app) }
            }
            }
            // Durante la presentazione nulla si muove sotto il velo: resta solo la schermata di benvenuto
            .disabled(menu.bloccato || menu.inPresentazione)
            Divider()
            Button("Schermata di benvenuto") { stato.blocca() }
                .keyboardShortcut("l", modifiers: [.command, .option])
                .disabled(menu.bloccato)
        }
        CommandGroup(replacing: .newItem) {}
        CommandGroup(after: .help) {
            Button("Misura la fluidità") { MisuratoreFluidita.condiviso.alterna() }
        }
    }
}
