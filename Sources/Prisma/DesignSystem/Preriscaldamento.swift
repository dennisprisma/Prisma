#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import Foundation

extension Misure {
    /// Preparazione all'avvio.
    enum Preparazione {
        /// Le icone si preparano poco dopo il primo fotogramma, quando la finestra è già a schermo (s).
        static let attesaIcone: Double = 0.3
    }
}

/// Prepara prima del primo disegno ciò che costa: la chiama `PrismaApp.init` solo all'avvio vero (senza argomenti `--`).
/// - Metal dell'acqua: device, shader e tabelle J1 fuori dal thread principale, così il primo `body` li trova pronti.
/// - Icone del dock, delle finestre e di «Le tue app aperte»: ridotte fuori dal thread principale, dopo il primo fotogramma.
enum Preriscaldamento {
    @MainActor static func avvia() {
        DispatchQueue.global(qos: .userInitiated).async {
            // La prima lettura crea il device Metal (MTLCreateSystemDefaultDevice) qui e non nel primo body
            let programma = ProgrammaAcqua.condiviso
            DispatchQueue.main.async { programma.richiedi { _ in } }
        }
        #if os(macOS)
        let scala = NSScreen.main?.backingScaleFactor ?? 2
        #elseif os(iOS)
        let scala = UIScreen.main.scale
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + Misure.Preparazione.attesaIcone) {
            Risorse.preparaNitide(Preriscaldamento.icone(scala: scala))
        }
    }

    /// Le icone con le misure con cui le disegnano il dock, le finestre e «app aperte».
    private static func icone(scala: CGFloat) -> [(percorso: String, misura: CGSize, scala: CGFloat)] {
        func quadrato(_ lato: CGFloat) -> CGSize { CGSize(width: lato, height: lato) }
        let dock = quadrato(Tema.Misura.dockIcona)
        var elenco: [(percorso: String, misura: CGSize, scala: CGFloat)] = [
            (percorso: "Icone/Prisma.png", misura: dock, scala: scala),
        ]
        let misure: [(misura: CGSize, scala: CGFloat)] = [
            (misura: dock, scala: scala),
            (misura: quadrato(Tema.Misura.iconaFinestra), scala: scala),
            (misura: quadrato(Tema.Misura.iconaAppAperte), scala: scala),
        ]
        for m in misure {
            for app in AppPrisma.allCases {
                // L'Agenda si disegna con la piastrella senza data e il riflesso (IconaAgenda)
                let percorsi = app == .agenda ? ["Icone/Agenda_base.png", "Icone/Agenda_vetro.png"] : ["Icone/\(app.icona).png"]
                for p in percorsi { elenco.append((percorso: p, misura: m.misura, scala: m.scala)) }
            }
        }
        return elenco
    }
}
