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
        /// Solo iPad: la scena si scatta in orizzontale (le altre in verticale, come parte il simulatore).
        var orizzontale = false
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
                Scena(nome: "8-simulazioni") { m in m.appiPad = .simulazioni },
                Scena(nome: "9-eve") { m in m.appiPad = .eve },
                Scena(nome: "10-impostazioni-archivio") { m in
                    m.stato.schedaImpostazioni = .archivio
                    m.appiPad = .impostazioni
                },
                Scena(nome: "11-ricerca") { m in
                    m.stato.testoRicerca = "Marco"
                    m.appiPad = .clienti
                    m.stato.cercaOvunque()
                },
                // Giro 2: tutte le app dell'iPad, in verticale (la colonna di dettaglio più stretta del 13")
                Scena(nome: "12-analisi360") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.appiPad = .analisi360
                },
                Scena(nome: "13-incontri") { m in
                    m.stato.clienteAttivoId = "marco"
                    m.appiPad = .incontri
                },
                Scena(nome: "14-obiettivi") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.obiettivoSelezionato = "obiettivo-giulia-casa"
                    m.appiPad = .obiettivi
                },
                Scena(nome: "15-confronti") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.appiPad = .confronti
                },
                Scena(nome: "16-prodotti") { m in m.appiPad = .prodotti },
                Scena(nome: "17-attivita") { m in m.appiPad = .attivita },
                Scena(nome: "18-note") { m in m.appiPad = .note },
                // Documenti: il KID di Giulia (nelle istantanee senza il file PDF: c'è la scheda dei dati)
                Scena(nome: "19-documenti") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.documentoSelezionato = "doc-giulia-kid"
                    m.appiPad = .documenti
                },
                // Prospetti: le pagine del PDF in anteprima, come a schermo sul Mac
                Scena(nome: "20-prospetti-resoconto") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.apriProspetto(.resoconto(report: false))
                    m.appiPad = .presentazioni
                },
                Scena(nome: "21-prospetto-proposta") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.apriProspetto(.posizione("pos-giulia-piano-previdenziale-integrativo"))
                    m.appiPad = .presentazioni
                },
                Scena(nome: "22-impostazioni") { m in
                    m.stato.schedaImpostazioni = .esperienza
                    m.appiPad = .impostazioni
                },
                Scena(nome: "23-ricerca-app") { m in
                    m.stato.testoRicerca = "Giulia"
                    m.appiPad = .ricerca
                },
                // Le stesse app con l'iPad in orizzontale: le colonne del Mac tornano affiancate
                Scena(nome: "30-clienti-orizzontale", orizzontale: true) { m in
                    m.stato.clienteAttivoId = "marco"
                    m.appiPad = .clienti
                },
                Scena(nome: "31-posizioni-orizzontale", orizzontale: true) { m in m.appiPad = .posizioni },
                Scena(nome: "32-posizioni-dettaglio-orizzontale", orizzontale: true) { m in
                    m.stato.posizioneInDettaglio = "pos-giulia-etf-azionario-globale"
                    m.appiPad = .posizioni
                },
                Scena(nome: "33-documenti-orizzontale", orizzontale: true) { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.documentoSelezionato = "doc-giulia-kid"
                    m.appiPad = .documenti
                },
                Scena(nome: "34-prospetti-orizzontale", orizzontale: true) { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.apriProspetto(.resoconto(report: false))
                    m.appiPad = .presentazioni
                },
                Scena(nome: "35-impostazioni-orizzontale", orizzontale: true) { m in
                    m.stato.schedaImpostazioni = .archivio
                    m.appiPad = .impostazioni
                },
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

    /// Il tempo per la rotazione dell'iPad prima della scena (si aggiunge all'attesa della scena).
    static let attesaRotazione: UInt64 = 1_500_000_000

    /// Ruota l'iPad (verticale o orizzontale) con la preferenza di geometria della scena (iOS 16+). Nell'iPhone non
    /// fa niente: l'app è solo in verticale. Sul thread principale (UIApplication, UIWindowScene).
    @MainActor
    static func orienta(orizzontale: Bool) {
        guard UIDevice.current.userInterfaceIdiom == .pad,
              let scena = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let maschera: UIInterfaceOrientationMask = orizzontale ? .landscapeRight : .portrait
        scena.requestGeometryUpdate(.iOS(interfaceOrientations: maschera)) { errore in
            print("Istantanee: rotazione non riuscita (\(errore.localizedDescription))")
        }
    }

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
        // Si parte in verticale (il simulatore può essere rimasto in orizzontale dall'aspetto precedente)
        var orizzontale = false
        if iPad { IstantaneeMobile.orienta(orizzontale: false) }
        for (i, scena) in scene.enumerated() {
            if iPad && scena.orizzontale != orizzontale {
                orizzontale = scena.orizzontale
                IstantaneeMobile.orienta(orizzontale: orizzontale)
                try? await Task.sleep(nanoseconds: IstantaneeMobile.attesaRotazione)
            }
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
