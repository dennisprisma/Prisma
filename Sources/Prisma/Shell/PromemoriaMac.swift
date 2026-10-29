#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import UserNotifications

/// Il permesso di macOS per i promemoria (così StatoShell e le Impostazioni non importano UserNotifications).
enum PermessoPromemoria: Equatable {
    case daChiedere, consentiti, negati
}

/// Promemoria del Mac: notifiche locali (UNCalendarNotificationTrigger) ricavate dai dati con
/// `MotoreNotifiche.promemoria`, che arrivano anche a Prisma chiusa. Restano sul Mac: niente rete.
/// Funzionano solo nell'app vera (bundle .app, archivio sul disco): `UNUserNotificationCenter.current()`
/// fuori da un bundle .app manda in crash il processo, e nelle istantanee e nelle prove non parte mai.
final class PromemoriaMac: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let condiviso = PromemoriaMac()

    /// Nel userInfo della notifica: dove porta il clic (`DestinazioneRicerca.testo`).
    static let chiaveDestinazione = "destinazione"
    /// Il promemoria di prova delle Impostazioni (consegnato subito, mai tolto dagli aggiornamenti).
    static let prefissoProva = MotoreNotifiche.prefissoPromemoria + "prova-"

    /// Il clic su un promemoria porta qui; assegnato da `collega` (solo con StatoShell persistente).
    weak var stato: StatoShell?
    /// Gli ultimi promemoria consegnati (si tocca solo sul main thread): se non cambiano non si
    /// riparla col Centro notifiche.
    private var ultimi: [PromemoriaPianificato]?
    /// Ogni aggiornamento ha un numero: uno superato da uno più recente non tocca più nulla.
    private let serratura = NSLock()
    private var giro = 0
    /// I promemoria si calcolano su questa coda (sono un valore ricavato da un valore); ogni calcolo ha un
    /// numero (solo sul main thread): uno superato, o arrivato dopo lo spegnimento, non si consegna.
    private let codaCalcolo = DispatchQueue(label: "prisma.promemoria", qos: .utility)
    private var calcolo = 0

    /// true solo dentro Prisma.app avviata normalmente: mai con `--istantanee`, `--prova-…`
    /// né con il binario della build lanciato fuori dal bundle.
    static var disponibili: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
            && !CommandLine.arguments.dropFirst().contains { $0.hasPrefix("--") }
    }

    /// I promemoria sono stati consegnati in questa sessione (da togliere se si spengono).
    var haPianificato: Bool { ultimi != nil }

    /// Diventa il delegato del Centro notifiche: banner nascosti in modalità cliente, clic che porta in Prisma.
    func collega(_ s: StatoShell) {
        guard Self.disponibili, s.persistente else { return }
        stato = s
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: Permesso

    /// Lo stato del permesso, senza chiederlo (all'avvio e tornando a Prisma).
    func permesso(_ esito: @escaping (PermessoPromemoria) -> Void) {
        guard Self.disponibili else { return }
        UNUserNotificationCenter.current().getNotificationSettings { impostazioni in
            let p = PromemoriaMac.permesso(da: impostazioni.authorizationStatus)
            DispatchQueue.main.async { esito(p) }
        }
    }

    /// Chiede il permesso a macOS: solo quando l'utente accende i promemoria nelle Impostazioni.
    func chiediPermesso(_ esito: @escaping (Bool, String?) -> Void) {
        guard Self.disponibili else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { consentiti, errore in
            let testo = errore?.localizedDescription
            DispatchQueue.main.async { esito(consentiti, testo) }
        }
    }

    static func permesso(da stato: UNAuthorizationStatus) -> PermessoPromemoria {
        switch stato {
        case .authorized, .provisional: return .consentiti
        case .denied: return .negati
        default: return .daChiedere
        }
    }

    /// Impostazioni di Sistema › Notifiche (per riattivare i promemoria negati).
    static func apriImpostazioniDiSistema() {
        #if os(macOS)
        let indirizzi = ["x-apple.systempreferences:com.apple.Notifications-Settings.extension",
                         "x-apple.systempreferences:com.apple.preference.notifications"]
        for indirizzo in indirizzi {
            if let url = URL(string: indirizzo), NSWorkspace.shared.open(url) { return }
        }
        #elseif os(iOS)
        // Su iPhone e iPad: Impostazioni › Prisma › Notifiche
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        Task { @MainActor in UIApplication.shared.open(url, options: [:], completionHandler: nil) }
        #endif
    }

    // MARK: Consegna

    private func nuovoGiro() -> Int {
        serratura.lock()
        defer { serratura.unlock() }
        giro += 1
        return giro
    }

    private func attuale(_ numero: Int) -> Bool {
        serratura.lock()
        defer { serratura.unlock() }
        return giro == numero
    }

    /// Consegna i promemoria al Centro notifiche: toglie solo le richieste «prisma-» non più previste,
    /// aggiunge le nuove e sostituisce quelle cambiate (stesso id). Da chiamare sul main thread.
    func pianifica(_ voci: [PromemoriaPianificato]) {
        guard Self.disponibili, voci != ultimi else { return }
        ultimi = voci
        let numero = nuovoGiro()
        let centro = UNUserNotificationCenter.current()
        centro.getPendingNotificationRequests { [weak self] attese in
            guard let self, self.attuale(numero) else { return }
            let volute = Set(voci.map(\.id))
            let superate = attese.map(\.identifier).filter { id in
                id.hasPrefix(MotoreNotifiche.prefissoPromemoria) && !id.hasPrefix(PromemoriaMac.prefissoProva) && !volute.contains(id)
            }
            if !superate.isEmpty { centro.removePendingNotificationRequests(withIdentifiers: superate) }
            var presenti: [String: UNNotificationContent] = [:]
            for r in attese { presenti[r.identifier] = r.content }
            for v in voci {
                if let c = presenti[v.id], c.title == v.titolo, c.body == v.corpo { continue }
                centro.add(PromemoriaMac.richiesta(v)) { _ in }
            }
        }
    }

    /// Calcola i promemoria fuori dal thread principale e li consegna (`pianifica`). Da chiamare sul main thread.
    func calcolaEPianifica(_ dati: DatiPrisma, impostazioni: ImpostazioniPromemoria) {
        guard Self.disponibili else { return }
        calcolo &+= 1
        let numero = calcolo
        codaCalcolo.async { [weak self] in
            let voci = MotoreNotifiche.promemoria(dati, impostazioni: impostazioni)
            DispatchQueue.main.async {
                guard let self, self.calcolo == numero else { return }
                self.pianifica(voci)
            }
        }
    }

    /// Un calcolo ancora in corso non si consegna più (promemoria spenti o non consentiti).
    func annullaCalcolo() {
        calcolo &+= 1
    }

    /// Toglie tutti i promemoria di Prisma ancora in sospeso (promemoria spenti).
    func spegni() {
        guard Self.disponibili else { return }
        // Un calcolo ancora in corso non li riaccende
        annullaCalcolo()
        ultimi = nil
        _ = nuovoGiro()
        let centro = UNUserNotificationCenter.current()
        centro.getPendingNotificationRequests { attese in
            let nostre = attese.map(\.identifier).filter { $0.hasPrefix(MotoreNotifiche.prefissoPromemoria) }
            if !nostre.isEmpty { centro.removePendingNotificationRequests(withIdentifiers: nostre) }
        }
    }

    /// Un promemoria di prova, consegnato subito (Impostazioni › Promemoria del Mac › Prova).
    func inviaProva(_ esito: @escaping (String?) -> Void) {
        guard Self.disponibili else { return }
        let contenuto = UNMutableNotificationContent()
        contenuto.title = "Promemoria di prova"
        contenuto.body = "Così arrivano i promemoria di Prisma: appuntamenti, attività, scadenze e compleanni"
        contenuto.sound = .default
        contenuto.threadIdentifier = MotoreNotifiche.prefissoPromemoria + "prova"
        contenuto.userInfo = [PromemoriaMac.chiaveDestinazione: DestinazioneRicerca.app(.impostazioni).testo]
        let richiesta = UNNotificationRequest(identifier: PromemoriaMac.prefissoProva + UUID().uuidString,
                                              content: contenuto, trigger: nil)
        UNUserNotificationCenter.current().add(richiesta) { errore in
            let testo = errore?.localizedDescription
            DispatchQueue.main.async { esito(testo) }
        }
    }

    private static func richiesta(_ v: PromemoriaPianificato) -> UNNotificationRequest {
        let contenuto = UNMutableNotificationContent()
        contenuto.title = v.titolo
        contenuto.body = v.corpo
        contenuto.sound = .default
        contenuto.threadIdentifier = MotoreNotifiche.prefissoPromemoria + v.gruppo
        if let d = v.destinazione {
            contenuto.userInfo = [PromemoriaMac.chiaveDestinazione: d.testo]
        }
        let quando = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: v.data)
        let scatto = UNCalendarNotificationTrigger(dateMatching: quando, repeats: false)
        return UNNotificationRequest(identifier: v.id, content: contenuto, trigger: scatto)
    }

    // MARK: Delegato del Centro notifiche

    /// Con Prisma in primo piano: in modalità cliente, in presentazione o con lo schermo bloccato
    /// il banner non si mostra (il cliente davanti non deve vedere gli altri clienti).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let riservato = await MainActor.run { () -> Bool in
            guard let s = self.stato else { return false }
            return s.modoCliente != nil || s.presentazione != nil || s.bloccato
        }
        return riservato ? [] : [.banner, .list, .sound]
    }

    /// Il clic sul promemoria apre Prisma nel punto giusto (non in modalità cliente né a schermo bloccato).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let testo = response.notification.request.content.userInfo[PromemoriaMac.chiaveDestinazione] as? String
        let predefinita = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        await MainActor.run {
            guard predefinita else { return }
            #if os(macOS)
            NSApp.activate(ignoringOtherApps: true)
            #endif
            guard let s = self.stato, s.modoCliente == nil, s.presentazione == nil, !s.bloccato,
                  let t = testo, let destinazione = DestinazioneRicerca(testo: t) else { return }
            s.vai(a: destinazione)
        }
    }
}

extension DestinazioneRicerca {
    /// La destinazione in testo, per il userInfo dei promemoria («cliente:<id>»): l'enum non è Codable.
    var testo: String {
        switch self {
        case .app(let app): return "app:" + app.rawValue
        case .cliente(let id): return "cliente:" + id
        case .posizione(let id): return "posizione:" + id
        case .documento(let id): return "documento:" + id
        case .nota(let id): return "nota:" + id
        case .appuntamento(let id): return "appuntamento:" + id
        case .attivita(let id): return "attivita:" + id
        case .obiettivo(let id): return "obiettivo:" + id
        case .incontro(let id): return "incontro:" + id
        case .prodotto(let id): return "prodotto:" + id
        }
    }

    /// Dal testo di `testo` (l'id può contenere «:», si divide al primo).
    init?(testo: String) {
        guard let due = testo.firstIndex(of: ":") else { return nil }
        let tipo = String(testo[..<due])
        let id = String(testo[testo.index(after: due)...])
        guard !id.isEmpty else { return nil }
        switch tipo {
        case "app":
            guard let app = AppPrisma(rawValue: id) else { return nil }
            self = .app(app)
        case "cliente": self = .cliente(id)
        case "posizione": self = .posizione(id)
        case "documento": self = .documento(id)
        case "nota": self = .nota(id)
        case "appuntamento": self = .appuntamento(id)
        case "attivita": self = .attivita(id)
        case "obiettivo": self = .obiettivo(id)
        case "incontro": self = .incontro(id)
        case "prodotto": self = .prodotto(id)
        default: return nil
        }
    }
}

extension StatoShell {
    /// Ricalcola e consegna i promemoria del Mac (dopo le modifiche dei dati, al cambio di giorno,
    /// tornando a Prisma). Spenti o non consentiti: toglie quelli consegnati in questa sessione.
    /// Il calcolo è in background: il thread principale passa solo una copia dei dati.
    func aggiornaPromemoria() {
        guard persistente, PromemoriaMac.disponibili else { return }
        let scelte = dati.impostazioni.promemoria
        guard scelte.attivi, permessoPromemoria != .negati else {
            if PromemoriaMac.condiviso.haPianificato {
                PromemoriaMac.condiviso.spegni()
            } else {
                PromemoriaMac.condiviso.annullaCalcolo()
            }
            return
        }
        PromemoriaMac.condiviso.calcolaEPianifica(dati, impostazioni: scelte)
    }

    /// Legge il permesso di macOS (senza chiederlo): può cambiare in Impostazioni di Sistema.
    func aggiornaPermessoPromemoria() {
        guard persistente, PromemoriaMac.disponibili else { return }
        PromemoriaMac.condiviso.permesso { [weak self] permesso in
            guard let self else { return }
            // Accesi in un backup ripristinato su un Mac che non li ha mai consentiti: si spengono,
            // il permesso si chiede solo riaccendendoli
            if permesso == .daChiedere, self.dati.impostazioni.promemoria.attivi {
                self.dati.impostazioni.promemoria.attivi = false
            }
            guard self.permessoPromemoria != permesso else { return }
            self.permessoPromemoria = permesso
            self.aggiornaPromemoria()
        }
    }

    /// L'interruttore delle Impostazioni: accendendolo Prisma chiede il permesso a macOS (solo adesso,
    /// mai all'avvio); spegnendolo toglie i promemoria in sospeso.
    func attivaPromemoria(_ acceso: Bool) {
        guard acceso else {
            dati.impostazioni.promemoria.attivi = false
            if persistente, PromemoriaMac.disponibili { PromemoriaMac.condiviso.spegni() }
            return
        }
        guard persistente, PromemoriaMac.disponibili else {
            mostraAvviso("I promemoria del Mac funzionano solo aprendo Prisma.app")
            return
        }
        PromemoriaMac.condiviso.chiediPermesso { [weak self] consentiti, errore in
            guard let self else { return }
            self.permessoPromemoria = consentiti ? .consentiti : .negati
            self.dati.impostazioni.promemoria.attivi = consentiti
            if consentiti {
                self.aggiornaPromemoria()
                self.mostraAvviso("Promemoria del Mac attivi: arrivano anche a Prisma chiusa")
            } else {
                let motivo = errore.map { " (\($0))" } ?? ""
                self.mostraAvviso("macOS non consente i promemoria a Prisma\(motivo): attivali in Impostazioni di Sistema › Notifiche › Prisma")
            }
        }
    }

    /// Il pulsante «Prova»: un promemoria subito, per vedere come arriva.
    func provaPromemoria() {
        guard persistente, PromemoriaMac.disponibili, dati.impostazioni.promemoria.attivi else { return }
        PromemoriaMac.condiviso.inviaProva { [weak self] errore in
            guard let self else { return }
            if let errore {
                self.mostraAvviso("Il promemoria di prova non è partito: \(errore)")
            } else {
                self.mostraAvviso("Promemoria di prova inviato")
            }
        }
    }
}
