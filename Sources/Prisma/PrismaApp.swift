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
            let metodo = argomenti.firstIndex(of: "--metodo").flatMap { $0 + 1 < argomenti.count ? argomenti[$0 + 1] : nil } ?? "finestra"
            exit(Istantanee.genera(in: URL(fileURLWithPath: argomenti[i + 1], isDirectory: true), metodo: metodo))
        }
    }

    var body: some Scene {
        Window("Prisma", id: "prisma") {
            ShellView()
                .environmentObject(stato)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandMenu("Vai") {
                // Con la schermata di benvenuto davanti, niente si apre dietro di lei
                Group {
                Button("Cerca ovunque") { stato.cercaOvunque() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Spazi di lavoro…") { stato.pannelloSpazi = true }
                Button("Le tue app aperte…") { stato.pannelloAppAperte = true }
                Button("Schermata di benvenuto") { stato.blocca() }
                    .keyboardShortcut("l", modifiers: [.command, .option])
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
                .disabled(stato.bloccato)
            }
            CommandGroup(replacing: .newItem) {}
        }
    }
}
