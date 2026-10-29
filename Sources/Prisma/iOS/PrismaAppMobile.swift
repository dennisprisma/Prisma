#if os(iOS)
// Solo iPhone e iPad: sul Mac il punto d'ingresso è PrismaApp (PrismaApp.swift, sotto #if os(macOS)).
// Ogni piattaforma vede un solo @main.
import SwiftUI
import UIKit

@main
struct PrismaAppMobile: App {
    /// Avvio normale o istantanee per il workflow (`--istantanee-ios [scene separate da virgole]`).
    private enum Modo {
        case normale
        case istantanee(Set<String>?)
    }

    private let modo: Modo

    init() {
        let argomenti = CommandLine.arguments
        /// Il valore dopo un'opzione, se c'è e non è un'altra opzione.
        func valore(_ i: Int) -> String? {
            i + 1 < argomenti.count && !argomenti[i + 1].hasPrefix("--") ? argomenti[i + 1] : nil
        }
        // Le prove senza interfaccia girano qui ed escono prima di mostrare la finestra, come sul Mac.
        // `simctl launch` non restituisce il codice d'uscita: l'esito va in Documents/esito-<prova>.txt
        // (EsitoProva, letto da Supporto/iOS/prove.sh). I nomi sono quelli degli argomenti, senza «--».
        if argomenti.contains("--verifica-risorse") {
            EsitoProva.esci("verifica-risorse", codice: Risorse.verifica())
        }
        if argomenti.contains("--prova-backup") {
            EsitoProva.esci("prova-backup", codice: ProvaBackup.esegui())
        }
        if argomenti.contains("--prova-calcoli") {
            EsitoProva.esci("prova-calcoli", codice: ProvaCalcoli.esegui())
        }
        if argomenti.contains("--prova-eve") {
            EsitoProva.esci("prova-eve", codice: ProvaEve.esegui())
        }
        if argomenti.contains("--prova-carico") {
            EsitoProva.esci("prova-carico", codice: ProvaCarico.esegui())
        }
        if let i = argomenti.firstIndex(of: "--prova-prospetti") {
            let cartella = valore(i).map { URL(fileURLWithPath: $0, isDirectory: true) }
            EsitoProva.esci("prova-prospetti", codice: ProvaProspetti.esegui(cartella: cartella))
        }
        if argomenti.contains("--prepara-campione-backup") {
            EsitoProva.esci("prepara-campione-backup", codice: ProvaBackup.preparaCampione())
        }
        if let i = argomenti.firstIndex(of: "--prova-backup-ditto") {
            guard let zip = valore(i) else {
                EsitoProva.scrivi("prova-backup-ditto", ok: false, dettaglio: "manca il percorso dello zip")
                exit(2)
            }
            EsitoProva.esci("prova-backup-ditto", codice: ProvaBackup.provaDitto(zip: URL(fileURLWithPath: zip)))
        }
        // Le istantanee hanno bisogno della scena: partono dal .task della vista (IstantaneeMobile.swift)
        if let i = argomenti.firstIndex(of: "--istantanee-ios") {
            let solo = valore(i).map { Set($0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }) }
            modo = .istantanee(solo)
            return
        }
        modo = .normale
        // Avvio vero: l'archivio si legge in background mentre nasce la finestra (come sul Mac)
        AvvioArchivio.avvia()
    }

    var body: some Scene {
        WindowGroup {
            switch modo {
            case .normale:
                AvvioMobile()
            case .istantanee(let solo):
                VistaIstantaneeMobile(solo: solo)
            }
        }
    }
}

/// Avvio normale: lo stato nasce qui (StatoShell legge l'archivio già avviato in `init`).
private struct AvvioMobile: View {
    @StateObject private var mobile = StatoMobile.avvia()

    var body: some View {
        RadiceMobile(mobile: mobile)
    }
}

/// La radice di Prisma su iPhone e iPad: apertura del backup se l'archivio non ha ancora dati veri, poi
/// il guscio dell'iPad (larghezza regolare) o quello dell'iPhone (compatta). Aspetto chiaro, scuro o
/// automatico come in Impostazioni; l'avviso temporaneo dello stato in basso.
struct RadiceMobile: View {
    @ObservedObject var mobile: StatoMobile
    @Environment(\.horizontalSizeClass) private var larghezza
    @Environment(\.scenePhase) private var fase

    var body: some View {
        Group {
            if mobile.mostraApertura {
                AperturaBackup()
            } else if larghezza == .regular {
                GuscioiPad()
            } else {
                GuscioiPhone()
            }
        }
        .modifier(AspettoEAvvisoMobile(nascondiAvviso: mobile.mostraApertura))
        .environmentObject(mobile)
        .environmentObject(mobile.stato)
        // Le viste del Mac riusate sull'iPad (intestazione, guida, ricerca) leggono anche le finestre e il blocco:
        // senza questo oggetto nell'ambiente SwiftUI si fermerebbe alla prima che lo chiede
        .environmentObject(mobile.stato.sistema)
        .onOpenURL { url in mobile.ricevi(url) }
        .onChange(of: fase) { nuova in
            if nuova == .background { mobile.inBackground() }
        }
    }
}

/// Osserva lo StatoShell solo per l'aspetto e per l'avviso: il guscio sotto non si ricalcola per questo.
private struct AspettoEAvvisoMobile: ViewModifier {
    @EnvironmentObject var stato: StatoShell
    let nascondiAvviso: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let avviso = stato.avviso, !nascondiAvviso {
                    VistaAvviso(testo: avviso)
                        .padding(.horizontal, Tema.Misura.Mobile.margine)
                        .padding(.bottom, Tema.Misura.Mobile.rigaMinima)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .preferredColorScheme(stato.dati.impostazioni.aspetto.schema)
    }
}
#endif
