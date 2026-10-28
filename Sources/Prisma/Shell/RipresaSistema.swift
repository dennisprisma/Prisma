import AppKit
import Combine

// Proprietario: G2 (ciclo di vita).

extension StatoShell {
    /// Stop del Mac e schermo spento: prima di dormire i lavori a tempo si fermano (notifiche, promemoria,
    /// backup automatico) e i dati cambiati partono per il disco; al risveglio l'interfaccia c'è già, ferma
    /// com'era, e i controlli ripartono dopo `attesaDopoRisveglio`, così il risveglio resta libero.
    /// Niente animazioni e niente blocco automatico; l'acqua la ferma e la fa ripartire lo sfondo da sé.
    /// La chiama `init` solo con l'archivio sul disco (mai nelle istantanee e nelle prove).
    func avviaRipresa() {
        let centro = NSWorkspace.shared.notificationCenter
        for nome in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            centro.publisher(for: nome)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sospendiLavoriATempo() }
                .store(in: &abbonamenti)
        }
        for nome in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            centro.publisher(for: nome)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.riprendiLavoriATempo(dopo: StatoShell.attesaDopoRisveglio) }
                .store(in: &abbonamenti)
        }
    }
}
