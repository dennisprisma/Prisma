#if os(iOS)
import SwiftUI
import UIKit

/// Istantanee di iPhone e iPad (`--istantanee-ios [scene]`), scattate dal workflow con `simctl io screenshot`
/// (fedele: vetro, ombre, barre di sistema). Sincronizzazione a file con Supporto/iOS/istantanee.sh:
/// 1. l'app mostra la scena e aspetta che il disegno si fermi;
/// 2. scrive in modo atomico Documents/scena-pronta.txt con il nome della scena (lo script lo cancella e scatta);
/// 3. aspetta Documents/scatto-fatto.txt, lo cancella e passa alla scena successiva;
/// 4. alla fine scrive Documents/esito-istantanee-ios.txt (EsitoProva) ed esce.
/// Chiaro e scuro li sceglie lo script (`simctl ui appearance`): Prisma resta sull'aspetto «automatico».
/// Ogni scena ha uno stato nuovo con i dati di prova (StatoShell non persistente: niente disco).
@MainActor
enum IstantaneeMobile {
    struct Scena {
        let nome: String
        /// Sul thread principale, come lo stato che prepara.
        let prepara: @MainActor (StatoMobile) -> Void
    }

    /// Le scene dell'iPad e dell'iPhone (le dimensioni vengono dal dispositivo: ognuno scatta le sue).
    static func scene(iPad: Bool) -> [Scena] {
        var elenco: [Scena] = [
            Scena(nome: "1-apertura-backup") { m in m.apriBackup() },
            Scena(nome: "2-apertura-password") { m in
                m.simulaScelta(nome: "Prisma 2026-10-29 09.12.04.zip.cifrato", protetto: true,
                               fase: .errore("La password non è corretta: riprova."))
            },
            Scena(nome: "3-clienti") { m in
                m.appiPad = .clienti
                m.schedaiPhone = .clienti
            },
            Scena(nome: "4-clienti-scheda") { m in
                m.stato.clienteAttivoId = "marco"
                m.appiPad = .clienti
                m.schedaiPhone = .clienti
                m.percorsoClienti = [.cliente("marco")]
            },
            Scena(nome: "5-posizioni") { m in
                m.appiPad = .posizioni
                m.schedaiPhone = .posizioni
            },
            Scena(nome: "6-posizioni-dettaglio") { m in
                m.stato.posizioneInDettaglio = "pos-giulia-etf-azionario-globale"
                m.appiPad = .posizioni
                m.schedaiPhone = .posizioni
                m.percorsoPosizioni = [.posizione("pos-giulia-etf-azionario-globale")]
            },
            Scena(nome: "7-agenda") { m in
                m.stato.appuntamentoSelezionato = "event-marco"
                m.appiPad = .agenda
                m.schedaiPhone = .agenda
            },
        ]
        if iPad {
            elenco += [
                Scena(nome: "8-in-arrivo") { m in m.appiPad = .simulazioni },
                Scena(nome: "9-eve") { m in m.appiPad = .eve },
            ]
        } else {
            elenco += [
                Scena(nome: "8-agenda-dettaglio") { m in
                    m.schedaiPhone = .agenda
                    m.percorsoAgenda = [.appuntamento("event-marco")]
                },
                Scena(nome: "9-notifiche") { m in m.schedaiPhone = .notifiche },
                Scena(nome: "10-altro") { m in m.schedaiPhone = .altro },
            ]
        }
        return elenco
    }

    /// Attese: la prima scena (primo avvio, caratteri e icone da preparare) e le altre; lo scatto dello script.
    static let attesaPrima: UInt64 = 3_000_000_000
    static let attesaScena: UInt64 = 1_500_000_000
    static let limiteScatto: TimeInterval = 120
    static let intervalloControllo: UInt64 = 200_000_000

    static var documenti: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var scenaPronta: URL { documenti.appendingPathComponent("scena-pronta.txt") }
    static var scattoFatto: URL { documenti.appendingPathComponent("scatto-fatto.txt") }
}

/// La vista delle istantanee: mostra una scena alla volta e parla con lo script attraverso i file.
struct VistaIstantaneeMobile: View {
    let solo: Set<String>?

    @State private var mobile: StatoMobile?
    @State private var indice = 0

    var body: some View {
        Group {
            if let mobile {
                RadiceMobile(mobile: mobile)
                    .id(indice)
            } else {
                Color.clear
            }
        }
        // Niente `modoIstantanea`: lo scatto è dello schermo vero, con il vetro e i materiali di iOS come li vede
        // l'utente (sul Mac serve solo perché le PNG si disegnano fuori schermo)
        .task { await esegui() }
    }

    private func esegui() async {
        let fm = FileManager.default
        let iPad = UIDevice.current.userInterfaceIdiom == .pad
        let scene = IstantaneeMobile.scene(iPad: iPad).filter { solo?.contains($0.nome) ?? true }
        guard !scene.isEmpty else {
            EsitoProva.scrivi("istantanee-ios", ok: false, dettaglio: "nessuna scena con questi nomi: \(solo?.sorted().joined(separator: ",") ?? "")")
            exit(1)
        }
        try? fm.createDirectory(at: IstantaneeMobile.documenti, withIntermediateDirectories: true)
        try? fm.removeItem(at: IstantaneeMobile.scattoFatto)
        for (i, scena) in scene.enumerated() {
            // Stato nuovo per ogni scena, con i dati di prova e senza disco
            let stato = StatoShell(persistente: false)
            let nuovo = StatoMobile(stato: stato, persistente: false)
            scena.prepara(nuovo)
            indice = i
            mobile = nuovo
            // Il disegno si ferma (vetro, elenchi pigri, notifiche ricalcolate)
            try? await Task.sleep(nanoseconds: i == 0 ? IstantaneeMobile.attesaPrima : IstantaneeMobile.attesaScena)
            do {
                try Data((scena.nome + "\n").utf8).write(to: IstantaneeMobile.scenaPronta, options: .atomic)
            } catch {
                EsitoProva.scrivi("istantanee-ios", ok: false, dettaglio: "\(scena.nome): scena-pronta.txt non scritto (\(error.localizedDescription))")
                exit(1)
            }
            print("Istantanea pronta: \(scena.nome)")
            guard await aspettaScatto() else {
                EsitoProva.scrivi("istantanee-ios", ok: false, dettaglio: "\(scena.nome): lo scatto non è arrivato entro \(Int(IstantaneeMobile.limiteScatto)) s")
                exit(1)
            }
            try? fm.removeItem(at: IstantaneeMobile.scattoFatto)
        }
        EsitoProva.scrivi("istantanee-ios", ok: true, dettaglio: "\(scene.count) scene")
        exit(0)
    }

    /// Aspetta il file dello script (controllato cinque volte al secondo), entro il tempo massimo.
    private func aspettaScatto() async -> Bool {
        let inizio = Date()
        while Date().timeIntervalSince(inizio) < IstantaneeMobile.limiteScatto {
            if FileManager.default.fileExists(atPath: IstantaneeMobile.scattoFatto.path) { return true }
            try? await Task.sleep(nanoseconds: IstantaneeMobile.intervalloControllo)
        }
        return false
    }
}
#endif
