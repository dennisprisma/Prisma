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

    func entraModoCliente() {
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
        mostraAvviso("Modalità cliente: si vede solo il dossier di \(c.nome).")
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

/// Il contrassegno nella barra superiore: chi stai mostrando e come uscire.
struct ContrassegnoModoCliente: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        Button { stato.esciModoCliente() } label: {
            HStack(spacing: 6) {
                Text("MODALITÀ CLIENTE").font(Tipo.barraTasto).tracking(0.6)
                Text(stato.clienteAttivo?.nome ?? "").font(Tipo.barraApp)
                Text("Esci  ⌥⌘M").font(Tipo.barraTasto).opacity(0.8)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(Colori.Barra.modoCliente))
            .overlay(Capsule().strokeBorder(Colori.Barra.modoClienteBordo, lineWidth: 1))
        }
        .buttonStyle(StileSemplice())
        .help("Esci dalla modalità cliente e torna a vedere tutti i clienti")
    }
}
