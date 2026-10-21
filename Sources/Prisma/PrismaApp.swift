import SwiftUI

@main
struct PrismaApp: App {
    init() {
        if CommandLine.arguments.contains("--verifica-risorse") {
            exit(Risorse.verifica())
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
