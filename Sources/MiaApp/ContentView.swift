import SwiftUI

struct ContentView: View {
    @State private var contatore = 0

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "macwindow")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Ciao dalla mia app!")
                .font(.title)

            Text("Hai cliccato \(contatore) volte")
                .foregroundStyle(.secondary)

            Button("Clicca") {
                contatore += 1
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(minWidth: 360, minHeight: 260)
    }
}
