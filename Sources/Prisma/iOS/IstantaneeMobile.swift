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

    /// Le scene dell'iPad e dell'iPhone (le dimensioni vengono dal dispositivo: ognuno scatta le sue). Dal giro 3 le
    /// app stanno nella finestra di vetro sopra la scrivania (`m.apri`), e ci sono le scene della scrivania, del
    /// dock e dei pannelli. Prima `m.apri`, poi i percorsi dell'iPhone: le icone li azzerano.
    static func scene(iPad: Bool) -> [Scena] {
        var elenco: [Scena] = [
            Scena(nome: "1-apertura-backup") { m in m.apriBackup() },
            Scena(nome: "2-apertura-password") { m in
                m.simulaScelta(nome: "Prisma 2026-10-29 09.12.04.zip.cifrato", protetto: true,
                               fase: .errore("La password non è corretta: riprova."))
            },
            Scena(nome: "3-clienti") { m in m.apri(.clienti) },
            Scena(nome: "4-clienti-scheda") { m in
                m.stato.clienteAttivoId = "marco"
                m.apri(.clienti)
                m.percorsoClienti = [.cliente("marco")]
            },
            Scena(nome: "5-posizioni") { m in m.apri(.posizioni) },
            Scena(nome: "6-posizioni-dettaglio") { m in
                m.stato.posizioneInDettaglio = "pos-giulia-etf-azionario-globale"
                m.apri(.posizioni)
                m.percorsoPosizioni = [.posizione("pos-giulia-etf-azionario-globale")]
            },
            Scena(nome: "7-agenda") { m in
                m.stato.appuntamentoSelezionato = "event-marco"
                m.apri(.agenda)
            },
        ]
        if iPad {
            elenco += [
                Scena(nome: "8-simulazioni") { m in m.apri(.simulazioni) },
                Scena(nome: "9-eve") { m in m.apri(.eve) },
                Scena(nome: "10-impostazioni-archivio") { m in
                    m.stato.schedaImpostazioni = .archivio
                    m.apri(.impostazioni)
                },
                Scena(nome: "11-ricerca") { m in
                    m.stato.testoRicerca = "Marco"
                    m.apri(.clienti)
                    m.stato.cercaOvunque()
                },
                // Tutte le app dell'iPad, in verticale (la finestra più stretta del 13")
                Scena(nome: "12-analisi360") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.apri(.analisi360)
                },
                Scena(nome: "13-incontri") { m in
                    m.stato.clienteAttivoId = "marco"
                    m.apri(.incontri)
                },
                Scena(nome: "14-obiettivi") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.obiettivoSelezionato = "obiettivo-giulia-casa"
                    m.apri(.obiettivi)
                },
                Scena(nome: "15-confronti") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.apri(.confronti)
                },
                Scena(nome: "16-prodotti") { m in m.apri(.prodotti) },
                Scena(nome: "17-attivita") { m in m.apri(.attivita) },
                Scena(nome: "18-note") { m in m.apri(.note) },
                // Documenti: il KID di Giulia (nelle istantanee senza il file PDF: c'è la scheda dei dati)
                Scena(nome: "19-documenti") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.documentoSelezionato = "doc-giulia-kid"
                    m.apri(.documenti)
                },
                // Prospetti: le pagine del PDF in anteprima, come a schermo sul Mac
                Scena(nome: "20-prospetti-resoconto") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.apriProspetto(.resoconto(report: false))
                    m.apri(.presentazioni)
                },
                Scena(nome: "21-prospetto-proposta") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.apriProspetto(.posizione("pos-giulia-piano-previdenziale-integrativo"))
                    m.apri(.presentazioni)
                },
                Scena(nome: "22-impostazioni") { m in
                    m.stato.schedaImpostazioni = .esperienza
                    m.apri(.impostazioni)
                },
                // La scrivania del Mac sull'iPad in verticale: due colonne di widget, il dock senza nomi
                Scena(nome: "41-scrivania-verticale") { m in m.mostraHome() },
                // Le stesse app con l'iPad in orizzontale: le colonne del Mac tornano affiancate
                Scena(nome: "30-clienti-orizzontale", orizzontale: true) { m in
                    m.stato.clienteAttivoId = "marco"
                    m.apri(.clienti)
                },
                Scena(nome: "31-posizioni-orizzontale", orizzontale: true) { m in m.apri(.posizioni) },
                Scena(nome: "32-posizioni-dettaglio-orizzontale", orizzontale: true) { m in
                    m.stato.posizioneInDettaglio = "pos-giulia-etf-azionario-globale"
                    m.apri(.posizioni)
                },
                Scena(nome: "33-documenti-orizzontale", orizzontale: true) { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.documentoSelezionato = "doc-giulia-kid"
                    m.apri(.documenti)
                },
                Scena(nome: "34-prospetti-orizzontale", orizzontale: true) { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.stato.apriProspetto(.resoconto(report: false))
                    m.apri(.presentazioni)
                },
                Scena(nome: "35-impostazioni-orizzontale", orizzontale: true) { m in
                    m.stato.schedaImpostazioni = .archivio
                    m.apri(.impostazioni)
                },
                // La scrivania in orizzontale: la bacheca del Mac, il dock con i nomi; poi i pannelli
                Scena(nome: "40-scrivania-orizzontale", orizzontale: true) { m in m.mostraHome() },
                Scena(nome: "42-scrivania-notifiche", orizzontale: true) { m in
                    m.mostraHome()
                    m.stato.alternaNotifiche()
                },
                Scena(nome: "43-scrivania-controllo", orizzontale: true) { m in
                    m.mostraHome()
                    m.pannello = .controllo
                },
                Scena(nome: "44-app-aperte", orizzontale: true) { m in
                    m.apri(.clienti)
                    m.apri(.posizioni)
                    m.apri(.agenda)
                    m.pannello = .appAperte
                },
            ]
        } else {
            elenco += [
                Scena(nome: "8-agenda-dettaglio") { m in
                    m.apri(.agenda)
                    m.percorsoAgenda = [.appuntamento("event-marco")]
                },
                // Il centro notifiche del Mac sotto la barra, sopra la scrivania
                Scena(nome: "9-notifiche") { m in
                    m.mostraHome()
                    m.stato.alternaNotifiche()
                },
                Scena(nome: "10-impostazioni") { m in m.apri(.impostazioni) },
                // La scrivania del tema a una colonna: in cima e in fondo (Scadenze, Portafoglio, piede, dock)
                Scena(nome: "40-scrivania") { m in m.mostraHome() },
                Scena(nome: "41-scrivania-giu") { m in
                    m.mostraHome()
                    m.scrivaniaInFondo = true
                },
                Scena(nome: "43-ricerca") { m in
                    m.mostraHome()
                    m.stato.testoRicerca = "Marco"
                    m.stato.cercaOvunque()
                },
                Scena(nome: "44-controllo") { m in
                    m.mostraHome()
                    m.pannello = .controllo
                },
                Scena(nome: "45-tutte-le-app") { m in
                    m.mostraHome()
                    m.pannello = .tutteLeApp
                },
                Scena(nome: "46-attivita") { m in m.apri(.attivita) },
                Scena(nome: "47-note") { m in m.apri(.note) },
                Scena(nome: "48-documenti") { m in
                    m.stato.clienteAttivoId = "giulia"
                    m.apri(.documenti)
                },
                Scena(nome: "49-in-arrivo") { m in m.apri(.analisi360) },
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
