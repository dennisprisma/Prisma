#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import Combine

// Proprietario: G2 (ciclo di vita).

#if os(macOS)
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
                .sink { [weak self] _ in
                    // Gli effetti delle finestre (Core Animation) finiscono di colpo: al risveglio tutto è fermo
                    self?.annullaEffetti()
                    self?.sospendiLavoriATempo()
                }
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
#elseif os(iOS)
extension StatoShell {
    /// Su iPhone e iPad il sonno del Mac non c'è: Prisma va in background. Lì i lavori a tempo si fermano e i dati
    /// cambiati partono per il disco; tornando in primo piano i controlli ripartono poco dopo.
    func avviaRipresa() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.annullaEffetti()
                self?.sospendiLavoriATempo()
            }
            .store(in: &abbonamenti)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.riprendiLavoriATempo(dopo: StatoShell.attesaRitornoPrimoPiano) }
            .store(in: &abbonamenti)
    }

    /// Tornando in primo piano su iPhone e iPad i controlli ripartono dopo un secondo (non c'è un risveglio da lasciare libero).
    static let attesaRitornoPrimoPiano: Double = 1
}
#endif
