import SwiftUI

/// Modalità cliente: quando giri lo schermo verso il cliente, Prisma mostra solo il suo dossier.
/// Gli altri clienti spariscono da rubrica, agenda, attività, posizioni, scrivania e portafoglio;
/// Note, Ricerca e Impostazioni (che parlano di tutti) non si aprono; notifiche nascoste.
extension StatoShell {
    /// Le app che in modalità cliente non si aprono: leggono i dati di tutti i clienti.
    static let appRiservate: Set<AppPrisma> = [.note, .ricerca, .impostazioni]

    func appConsentita(_ app: AppPrisma) -> Bool {
        modoCliente == nil || !Self.appRiservate.contains(app)
    }

    var inModoCliente: Bool { modoCliente != nil }

    /// `avviso`: falso quando la accende la presentazione, per non coprire la pagina davanti al cliente.
    func entraModoCliente(avviso: Bool = true) {
        guard let c = dati.clienti.first(where: { $0.id == clienteAttivoId }) else {
            mostraAvviso("Scegli prima il cliente in Clienti: la modalità cliente mostra solo il suo dossier.")
            return
        }
        modoCliente = c.id
        Self.appRiservate.forEach(chiudi)
        // Il prospetto del portafoglio parla di tutti i clienti
        if case .portafoglio? = prospetto { prospetto = nil }
        pannelloNotifiche = false
        pannelloSpazi = false
        pannelloAppAperte = false
        portafoglio = false
        evePortafoglio = false
        filtroClienteAgenda = nil
        filtroClienteAttivita = nil
        if avviso { mostraAvviso("Modalità cliente: si vede solo il dossier di \(c.nome).") }
    }

    func esciModoCliente() {
        guard modoCliente != nil else { return }
        modoCliente = nil
        mostraAvviso("Modalità cliente terminata.")
    }

    func alternaModoCliente() {
        if modoCliente == nil { entraModoCliente() } else { esciModoCliente() }
    }
}

/// Il contrassegno nella barra superiore: chi stai mostrando e come uscire. Una capsula piena
/// dell'accento (come il pulsante principale del tema), alta quanto i pulsanti della barra.
struct ContrassegnoModoCliente: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let m = Tema.Misura.PannelliShell.self
        Button { stato.esciModoCliente() } label: {
            HStack(spacing: m.modoClienteSpazio) {
                Text("MODALITÀ CLIENTE")
                    .font(Tema.Testo.PannelliShell.occhielloModoCliente)
                    .tracking(Tema.Testo.PannelliShell.spaziaturaModoCliente)
                Text(stato.clienteAttivo?.nome ?? "")
                    .font(Tema.Testo.PannelliShell.nomeModoCliente)
                Text("Esci  ⌥⌘M")
                    .font(Tema.Testo.PannelliShell.tastoModoCliente)
                    .opacity(0.8)
            }
            .lineLimit(1)
            .foregroundColor(Tema.Colore.Componenti.testoSuColore)
            .padding(.horizontal, m.modoClienteMargine)
            .frame(height: Tema.Misura.pulsanteBarra)
            .background {
                FormaVetro.capsula
                    .fill(Colori.Barra.modoCliente)
                    .overlay {
                        FiloInterno(forma: .capsula)
                            .fill(Tema.Colore.Componenti.luceSuColore, style: FillStyle(eoFill: true))
                            .clipShape(FormaVetro.capsula)
                    }
            }
        }
        .buttonStyle(StileSemplice())
        .help("Esci dalla modalità cliente e torna a vedere tutti i clienti")
    }
}
