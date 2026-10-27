import AppKit
import SwiftUI

@main
struct PrismaApp: App {
    @StateObject var stato = StatoShell()

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
    }

    var body: some Scene {
        Window("Prisma", id: "prisma") {
            ShellView()
                .environmentObject(stato)
                // Aspetto scelto in Impostazioni (Automatico = segue il Mac). Si cambia l'aspetto dell'app
                // e non preferredColorScheme, che su macOS non torna bene ad «Automatico»
                .onAppear { PrismaApp.applicaAspetto(stato.dati.impostazioni.aspetto) }
                .onChange(of: stato.dati.impostazioni.aspetto) { PrismaApp.applicaAspetto($0) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandMenu("Vai") {
                // Con la schermata di benvenuto davanti, niente si apre dietro di lei
                Group {
                Button("Cerca ovunque") { stato.cercaOvunque() }
                    .keyboardShortcut("k", modifiers: .command)
                Button(stato.inModoCliente ? "Esci dalla modalità cliente" : "Modalità cliente") { stato.alternaModoCliente() }
                    .keyboardShortcut("m", modifiers: [.command, .option])
                Button("Spazi di lavoro…") { stato.pannelloSpazi = true }
                    .disabled(stato.inModoCliente)
                Button("Le tue app aperte…") { stato.pannelloAppAperte = true }
                Button(stato.conversazioneAVoce ? "Chiudi la conversazione con Eve" : "Parla con Eve") { stato.alternaAscolto(daMenu: true) }
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
                .disabled(stato.bloccato || stato.presentazione != nil)
                Divider()
                Button("Schermata di benvenuto") { stato.blocca() }
                    .keyboardShortcut("l", modifiers: [.command, .option])
                    .disabled(stato.bloccato)
            }
            CommandGroup(replacing: .newItem) {}
        }
    }

    /// Chiaro, scuro o come il Mac: vale per tutta l'app (i PDF restano comunque chiari).
    @MainActor static func applicaAspetto(_ aspetto: AspettoInterfaccia) {
        NSApp.appearance = aspetto.aspettoMac
    }
}
