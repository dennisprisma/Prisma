import AppKit
import Combine
import QuartzCore
import SwiftUI

/// Prova della fluidità (`Prisma --prova-fluidita [tabella.md]`), eseguita dal workflow dopo la prova di carico.
/// Misura quanto lavora il thread principale per aprire, chiudere e cambiare app, ridurre, ingrandire e spostare
/// le finestre, bloccare e sbloccare, aprire i pannelli, cambiare aspetto e modificare i dati, con la shell vera
/// (`ShellView`) in una finestra fuori schermo, come le istantanee. Non corregge nulla: serve a confrontare
/// prima e dopo (la linea di base di oggi e i miglioramenti).
///
/// Per ogni azione, su 5 giri dopo un giro di riscaldamento («prima volta»):
/// - aggiornamento: l'azione, un giro del run loop (SwiftUI applica lì le modifiche) e `layoutSubtreeIfNeeded()`;
/// - disegno: `cacheDisplay(in:to:)` completo in un bitmap riusato (riferimento, non incrementale);
/// - avvisi: gli `objectWillChange` di `StatoShell` durante l'azione (ogni avviso rivaluta tutte le viste che lo osservano,
///   cioè le app aperte e i widget) e quelli di `StatoFinestre` (finestre, pannelli e blocco: shell, dock, barra e pannelli).
///
/// Due scenari: i clienti di prova, e 200 clienti con quattro app pesanti aperte sotto (Posizioni in modalità
/// portafoglio, Prospetti e report, Clienti, Agenda).
///
/// Niente archivio e niente permessi: `StatoShell(persistente: false)` non legge né scrive il disco, non tocca
/// il Portachiavi e non chiede il permesso delle notifiche; i promemoria del Mac sono spenti anche perché
/// l'app è avviata con un argomento `--` (vedi `PromemoriaMac.disponibili`).
///
/// I limiti sono larghissimi (il runner Intel virtuale è lento e senza una GPU vera): fallisce solo se la mediana
/// dell'avvio supera 8 s, quella di un'azione 3 s, o se dopo un'azione lo stato non è quello atteso.
@MainActor
enum ProvaFluidita {
    static var misura: CGSize { Istantanee.dimensione }
    /// Giri misurati per ogni azione (dopo quello di riscaldamento) e giri dell'avvio (stato nuovo ogni volta).
    static let giri = 5
    static let giriAvvio = 3
    // Limiti oltre i quali la prova fallisce (sulla mediana dei giri), in secondi
    static let limiteAvvio = 8.0
    static let limiteAzione = 3.0
    /// Oltre questa durata le misure rimaste si saltano (con un'avvertenza, senza fallire): la build non si allunga troppo.
    static let limiteTempo = 600.0
    /// Il giro del run loop dopo ogni azione: SwiftUI applica lì le modifiche dello stato.
    static let giroRunLoop = 0.002
    /// Pausa non misurata tra un'azione e l'altra; più lunga dopo una modifica dei dati, perché
    /// le notifiche si ricalcolano 0,4 s dopo (e non devono finire nella misura successiva).
    static let attesaBreve = 0.01
    static let attesaDati = 0.5
    static let fuoriSchermo = NSPoint(x: -20000, y: -20000)
    static let origineSpostata = CGPoint(x: 48, y: 32)
    /// Le app pesanti dello scenario con 200 clienti, dalla più in fondo a quella in primo piano.
    static let appPesanti: [AppPrisma] = [.agenda, .presentazioni, .clienti, .posizioni]

    static func esegui(uscita: URL? = nil) -> Int32 {
        _ = NSApplication.shared
        // Come nelle istantanee: vetro disegnato, niente materiali di sistema né Metal
        Vetro.semplificato = true
        let sessione = SessioneFluidita()
        sessione.controlla(!PromemoriaMac.disponibili,
                           "Prova senza archivio, Portachiavi né permesso delle notifiche (stato non persistente, promemoria del Mac spenti)")
        guard sessione.errori == 0 else { return 1 }

        let molti: DatiPrisma
        do {
            molti = try ProvaCarico.moltiplica(DatiPrisma.demo(), copie: ProvaCarico.copie)
        } catch {
            print("ERRORE: archivio con \(ProvaCarico.copie) copie dei clienti di prova non creato: \(error.localizedDescription)")
            return 1
        }

        scenario(sessione, nome: "\(DatiPrisma.demo().clienti.count) clienti", dati: nil, pesanti: false)
        scenario(sessione, nome: "\(molti.clienti.count) clienti", dati: molti, pesanti: true)
        return sessione.concludi(uscita: uscita)
    }

    /// Uno scenario: avvio, apertura e chiusura di ogni app, poi le azioni sulle app aperte.
    private static func scenario(_ s: SessioneFluidita, nome: String, dati: DatiPrisma?, pesanti: Bool) {
        s.scenario = nome
        let banco = s.avvio(dati: dati)
        defer { banco.chiudi() }
        let stato = banco.stato
        let lavoro: [AppPrisma] = pesanti ? appPesanti : [.clienti, .posizioni]

        func ingrandita(_ app: AppPrisma) -> Bool? { stato.finestre.first { $0.app == app }?.ingrandita }

        if pesanti {
            // Posizioni in modalità portafoglio (i motori su tutti i clienti), Prospetti, Clienti e Agenda, aperte sotto.
            // La prima apertura è come un avvio: vale il limite dell'avvio
            s.unaVolta(banco, PassoFluidita(nome: "apre \(lavoro.count) app pesanti (prima volta)", azione: {
                stato.portafoglio = true
                for app in lavoro { stato.apri(app) }
            }, verifica: { lavoro.allSatisfy { stato.aperta($0) } }), limite: limiteAvvio)
        }

        // Ogni app del dock, una alla volta: apertura e chiusura (le app già aperte: chiusura e riapertura)
        for app in AppPrisma.allCases where stato.appConsentita(app) {
            let apri = PassoFluidita(nome: "apri \(app.titolo)", azione: { stato.apri(app) },
                                     verifica: { stato.appAttiva == app })
            let chiudi = PassoFluidita(nome: "chiudi \(app.titolo)", azione: { stato.chiudi(app) },
                                       verifica: { !stato.aperta(app) })
            s.misura(banco, stato.aperta(app) ? [chiudi, apri] : [apri, chiudi])
        }

        // Da qui in poi le app di lavoro restano aperte
        s.prepara(banco) { for app in lavoro where !stato.aperta(app) { stato.apri(app) } }

        // Cambio d'app: quella più in fondo torna in primo piano, a rotazione
        var portata: AppPrisma?
        s.misura(banco, [PassoFluidita(nome: "passa all'app sotto (\(lavoro.count) aperte)", azione: {
            portata = stato.finestreVisibili.first?.app
            if let a = portata { stato.primoPiano(a) }
        }, verifica: { portata != nil && stato.appAttiva == portata })])

        s.misura(banco, [
            PassoFluidita(nome: "riduci Posizioni", azione: { stato.riduci(.posizioni) },
                          verifica: { stato.finestre.contains { $0.app == .posizioni && $0.ridotta } }),
            PassoFluidita(nome: "ripristina Posizioni", azione: { stato.apri(.posizioni) },
                          verifica: { stato.appAttiva == .posizioni }),
        ])

        s.misura(banco, [
            PassoFluidita(nome: "riduci a finestra Clienti", azione: { stato.alternaIngrandimento(.clienti) },
                          verifica: { ingrandita(.clienti) == false }),
            PassoFluidita(nome: "ingrandisci Clienti", azione: { stato.alternaIngrandimento(.clienti) },
                          verifica: { ingrandita(.clienti) == true }),
        ])

        // Schermata di benvenuto: lo sblocco è quello del cursore e del pulsante (stato.sblocca)
        s.misura(banco, [
            PassoFluidita(nome: "blocca (schermata di benvenuto)", azione: { stato.blocca() },
                          verifica: { stato.bloccato }),
            PassoFluidita(nome: "sblocca", azione: { stato.sblocca() },
                          verifica: { !stato.bloccato }),
        ])

        s.misura(banco, [
            PassoFluidita(nome: "apri il centro notifiche", azione: { stato.alternaNotifiche() },
                          verifica: { stato.pannelloNotifiche }),
            PassoFluidita(nome: "chiudi il centro notifiche", azione: { stato.alternaNotifiche() },
                          verifica: { !stato.pannelloNotifiche }),
        ])

        // Aspetto chiaro e scuro: l'impostazione e l'aspetto della finestra, come fa PrismaApp.applicaAspetto
        let aspettoIniziale = stato.dati.impostazioni.aspetto
        let aspettoChiaro: AspettoInterfaccia = aspettoIniziale == .scuro ? .chiaro : aspettoIniziale
        s.misura(banco, [
            PassoFluidita(nome: "aspetto scuro", azione: {
                stato.dati.impostazioni.aspetto = .scuro
                banco.aspetto(scuro: true)
            }, verifica: { stato.dati.impostazioni.aspetto == .scuro }),
            PassoFluidita(nome: "aspetto chiaro", azione: {
                stato.dati.impostazioni.aspetto = aspettoChiaro
                banco.aspetto(scuro: false)
            }, verifica: { stato.dati.impostazioni.aspetto == aspettoChiaro }),
        ])

        // Una modifica dei dati: il costo di un tasto in una nota con le app aperte
        let indiceNota = stato.dati.note.indices.first
        func testoToccato() -> String {
            if let i = indiceNota, stato.dati.note.indices.contains(i) { return stato.dati.note[i].testo }
            return stato.dati.impostazioni.nomeUtente
        }
        func ritocca(_ modifica: (inout String) -> Void) {
            if let i = indiceNota, stato.dati.note.indices.contains(i) {
                modifica(&stato.dati.note[i].testo)
            } else {
                modifica(&stato.dati.impostazioni.nomeUtente)
            }
        }
        let testoIniziale = testoToccato()
        let cosa = indiceNota == nil ? "il nome dell'utente" : "una nota"
        s.misura(banco, [
            PassoFluidita(nome: "modifica \(cosa) (un tasto)", azione: { ritocca { t in t += "x" } },
                          verifica: { testoToccato() == testoIniziale + "x" }),
            PassoFluidita(nome: "annulla la modifica", azione: { ritocca { t in t = String(t.dropLast()) } },
                          verifica: { testoToccato() == testoIniziale }),
        ])

        var ordine: [AppPrisma] = []
        s.misura(banco, [
            PassoFluidita(nome: "mostra la scrivania", azione: {
                ordine = stato.finestreVisibili.map(\.app)
                stato.mostraScrivania()
            }, verifica: { stato.appAttiva == nil }),
            PassoFluidita(nome: "riapri le app (\(lavoro.count))", azione: { for app in ordine { stato.apri(app) } },
                          verifica: { !ordine.isEmpty && stato.appAttiva == ordine.last }),
        ])

        // Spostare una finestra: oggi ogni passo del trascinamento cambia lo stato
        s.prepara(banco) { if ingrandita(.clienti) == true { stato.alternaIngrandimento(.clienti) } }
        var altrove = false
        s.misura(banco, [PassoFluidita(nome: "sposta Clienti (un passo)", azione: {
            altrove.toggle()
            stato.sposta(.clienti, origine: altrove ? ProvaFluidita.origineSpostata : .zero)
        }, verifica: { ingrandita(.clienti) == false })])
        s.prepara(banco) { if ingrandita(.clienti) == false { stato.alternaIngrandimento(.clienti) } }

        s.misura(banco, [
            PassoFluidita(nome: "apri gli spazi di lavoro", azione: { stato.pannelloSpazi = true },
                          verifica: { stato.pannelloSpazi }),
            PassoFluidita(nome: "chiudi gli spazi di lavoro", azione: { stato.pannelloSpazi = false },
                          verifica: { !stato.pannelloSpazi }),
        ])

        s.misura(banco, [
            PassoFluidita(nome: "apri «Le tue app aperte»", azione: { stato.pannelloAppAperte = true },
                          verifica: { stato.pannelloAppAperte }),
            PassoFluidita(nome: "chiudi «Le tue app aperte»", azione: { stato.pannelloAppAperte = false },
                          verifica: { !stato.pannelloAppAperte }),
        ])
    }

    /// Mediana (0 se non ci sono valori).
    nonisolated static func mediana(_ valori: [Double]) -> Double {
        guard !valori.isEmpty else { return 0 }
        let ordinati = valori.sorted()
        let m = ordinati.count / 2
        return ordinati.count % 2 == 1 ? ordinati[m] : (ordinati[m - 1] + ordinati[m]) / 2
    }

    nonisolated static func ms(_ secondi: Double) -> String {
        "\(Int((secondi * 1000).rounded())) ms"
    }

    nonisolated static func secondi(_ s: Double) -> String {
        String(format: "%.1f s", s)
    }
}

/// Un'azione misurata: che cosa fa e come si controlla che lo stato sia quello atteso.
private struct PassoFluidita {
    let nome: String
    let azione: () -> Void
    let verifica: () -> Bool
}

/// I tempi di un'azione in uno scenario (secondi).
private struct RigaFluidita {
    let scenario: String
    let azione: String
    let limite: Double
    var aggiornamento: [Double] = []
    var disegno: [Double] = []
    /// Aggiornamento + disegno, giro per giro.
    var tempi: [Double] = []
    var avvisi: [Int] = []
    var avvisiFinestre: [Int] = []
    /// Il giro di riscaldamento (aggiornamento + disegno), escluso da mediana e massimo.
    var primaVolta: Double?
    var incoerente = false

    mutating func registra(aggiornamento t: Double, disegno d: Double?, conteggio: Int?, conteggioFinestre: Int? = nil,
                           riscaldamento: Bool) {
        let somma = t + (d ?? 0)
        if riscaldamento {
            primaVolta = somma
            return
        }
        aggiornamento.append(t)
        if let d { disegno.append(d) }
        tempi.append(somma)
        if let conteggio { avvisi.append(conteggio) }
        if let conteggioFinestre { avvisiFinestre.append(conteggioFinestre) }
    }
}

/// Gli avvisi contati dagli abbonamenti (fuori dalla classe del banco: le chiusure lo catturano da solo).
private final class ContiFluidita {
    var avvisi = 0
    var avvisiFinestre = 0
    var modificheDati = 0
}

/// La shell in una finestra fuori schermo, con il conto delle pubblicazioni di `StatoShell` e di `StatoFinestre`.
@MainActor
private final class BancoFluidita {
    let stato: StatoShell
    let host: NSHostingView<AnyView>
    let finestra: NSWindow
    let conti = ContiFluidita()
    private var abbonamenti = Set<AnyCancellable>()
    private var bitmap: NSBitmapImageRep?
    private var bitmapProvato = false

    init(stato: StatoShell) {
        self.stato = stato
        let misura = ProvaFluidita.misura
        stato.area = ShellView.area(per: misura, dockNascosto: !stato.finestreVisibili.isEmpty)
        let vista = ShellView()
            .environmentObject(stato)
            .environment(\.modoIstantanea, true)
            .frame(width: misura.width, height: misura.height)
        let h = NSHostingView(rootView: AnyView(vista))
        h.frame = NSRect(origin: .zero, size: misura)
        let f = NSWindow(contentRect: h.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        f.isReleasedWhenClosed = false
        f.contentView = h
        f.setFrameOrigin(ProvaFluidita.fuoriSchermo)
        host = h
        finestra = f
        aspetto(scuro: false)
        f.orderFront(nil)
        let conti = self.conti
        stato.objectWillChange.sink { _ in conti.avvisi += 1 }.store(in: &abbonamenti)
        stato.sistema.objectWillChange.sink { _ in conti.avvisiFinestre += 1 }.store(in: &abbonamenti)
        stato.$dati.dropFirst().sink { _ in conti.modificheDati += 1 }.store(in: &abbonamenti)
    }

    /// Aspetto della finestra (i colori dinamici del tema e il colorScheme di SwiftUI lo seguono).
    func aspetto(scuro: Bool) {
        let a = NSAppearance(named: scuro ? .darkAqua : .aqua)
        host.appearance = a
        finestra.appearance = a
    }

    func azzeraConti() {
        conti.avvisi = 0
        conti.avvisiFinestre = 0
        conti.modificheDati = 0
    }

    /// Azione + giro del run loop (SwiftUI applica lì le modifiche) + impaginazione. Secondi.
    func aggiorna(_ azione: () -> Void) -> Double {
        let inizio = CACurrentMediaTime()
        azione()
        let fine = CACurrentMediaTime() + ProvaFluidita.giroRunLoop
        repeat {
            _ = RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.0005))
        } while CACurrentMediaTime() < fine
        host.layoutSubtreeIfNeeded()
        return CACurrentMediaTime() - inizio
    }

    /// Disegno completo nel bitmap riusato (nil se il server di build non disegna).
    func disegna() -> Double? {
        if !bitmapProvato {
            bitmapProvato = true
            bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)
        }
        guard let b = bitmap else { return nil }
        let inizio = CACurrentMediaTime()
        host.cacheDisplay(in: host.bounds, to: b)
        return CACurrentMediaTime() - inizio
    }

    /// Lascia girare il run loop senza misurare (lavori rimandati, notifiche ricalcolate).
    func riposa(_ secondi: Double) {
        let fine = CACurrentMediaTime() + secondi
        while CACurrentMediaTime() < fine {
            _ = RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.002))
        }
    }

    func chiudi() {
        abbonamenti.removeAll()
        finestra.orderOut(nil)
    }
}

/// Le righe misurate, gli errori e il tempo della prova.
@MainActor
private final class SessioneFluidita {
    var scenario = ""
    private(set) var righe: [RigaFluidita] = []
    private(set) var errori = 0
    private var saltate = 0
    private var disegnoAssenteSegnalato = false
    private let inizio = CACurrentMediaTime()

    var trascorso: Double { CACurrentMediaTime() - inizio }

    func controlla(_ ok: Bool, _ descrizione: String) {
        print("\(ok ? "OK   " : "ERRORE") \(descrizione)")
        if !ok { errori += 1 }
    }

    /// Stato nuovo, dati, finestra, primo aggiornamento e primo disegno, `giriAvvio` volte: resta l'ultimo banco.
    func avvio(dati: DatiPrisma?) -> BancoFluidita {
        var riga = RigaFluidita(scenario: scenario, azione: "avvio (stato, dati e primo disegno)", limite: ProvaFluidita.limiteAvvio)
        var ultimo: BancoFluidita?
        for _ in 0..<ProvaFluidita.giriAvvio {
            ultimo?.chiudi()
            ultimo = nil
            let inizio = CACurrentMediaTime()
            let stato = StatoShell(persistente: false)
            if let dati {
                stato.dati = dati
                // Come all'avvio vero, le notifiche si calcolano subito su tutto l'archivio
                stato.ricalcolaNotifiche()
            }
            let banco = BancoFluidita(stato: stato)
            _ = banco.aggiorna {}
            let t = CACurrentMediaTime() - inizio
            let d = banco.disegna()
            segnalaDisegno(d)
            riga.registra(aggiornamento: t, disegno: d, conteggio: nil, riscaldamento: false)
            banco.riposa(ProvaFluidita.attesaDati)
            ultimo = banco
        }
        righe.append(riga)
        return ultimo ?? BancoFluidita(stato: StatoShell(persistente: false))
    }

    /// Le azioni date, una dopo l'altra, per un giro di riscaldamento e `giri` giri misurati.
    func misura(_ banco: BancoFluidita, _ passi: [PassoFluidita]) {
        guard !passi.isEmpty else { return }
        guard trascorso < ProvaFluidita.limiteTempo else {
            saltate += passi.count
            return
        }
        let primo = righe.count
        for p in passi {
            righe.append(RigaFluidita(scenario: scenario, azione: p.nome, limite: ProvaFluidita.limiteAzione))
        }
        for giro in 0...ProvaFluidita.giri {
            for (k, passo) in passi.enumerated() {
                let esito = prova(banco, passo)
                righe[primo + k].registra(aggiornamento: esito.aggiornamento, disegno: esito.disegno,
                                          conteggio: esito.avvisi, conteggioFinestre: esito.avvisiFinestre,
                                          riscaldamento: giro == 0)
                if !passo.verifica() { righe[primo + k].incoerente = true }
                banco.riposa(esito.datiCambiati ? ProvaFluidita.attesaDati : ProvaFluidita.attesaBreve)
            }
        }
    }

    /// Un'azione misurata una volta sola, senza riscaldamento (per esempio la prima apertura delle app pesanti).
    func unaVolta(_ banco: BancoFluidita, _ passo: PassoFluidita, limite: Double) {
        var riga = RigaFluidita(scenario: scenario, azione: passo.nome, limite: limite)
        let esito = prova(banco, passo)
        riga.registra(aggiornamento: esito.aggiornamento, disegno: esito.disegno, conteggio: esito.avvisi,
                      conteggioFinestre: esito.avvisiFinestre, riscaldamento: false)
        if !passo.verifica() { riga.incoerente = true }
        righe.append(riga)
        banco.riposa(ProvaFluidita.attesaDati)
    }

    /// Prepara lo stato senza misurare.
    func prepara(_ banco: BancoFluidita, _ cambia: () -> Void) {
        _ = banco.aggiorna(cambia)
        _ = banco.disegna()
        banco.riposa(ProvaFluidita.attesaDati)
    }

    private func prova(_ banco: BancoFluidita, _ passo: PassoFluidita)
        -> (aggiornamento: Double, disegno: Double?, avvisi: Int, avvisiFinestre: Int, datiCambiati: Bool) {
        banco.azzeraConti()
        let t = banco.aggiorna(passo.azione)
        let d = banco.disegna()
        segnalaDisegno(d)
        return (t, d, banco.conti.avvisi, banco.conti.avvisiFinestre, banco.conti.modificheDati > 0)
    }

    private func segnalaDisegno(_ d: Double?) {
        guard d == nil, !disegnoAssenteSegnalato else { return }
        disegnoAssenteSegnalato = true
        print("ATTENZIONE disegno non disponibile: si misura solo l'aggiornamento")
    }

    /// Stampa la tabella, la scrive in `uscita` (Markdown) e controlla i limiti.
    func concludi(uscita: URL?) -> Int32 {
        let commit = (Bundle.main.object(forInfoDictionaryKey: "PrismaCommit") as? String).map { " · commit \($0)" } ?? ""
        var tabella: [String] = [
            "### Fluidità\(commit)",
            "",
            "Tempi del thread principale: mediana e massimo su \(ProvaFluidita.giri) giri, dopo un giro di riscaldamento (prima volta). "
                + "Aggiornamento = azione, run loop e impaginazione; disegno = cacheDisplay completo; "
                + "avvisi = objectWillChange di StatoShell (app e widget) e di StatoFinestre (shell, dock, barra, pannelli) durante l'azione.",
            "",
            "| Scenario | Azione | Mediana | Massimo | Aggiornamento | Disegno | Prima volta | Avvisi StatoShell | Avvisi StatoFinestre |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|",
        ]
        for r in righe {
            let mediana = ProvaFluidita.mediana(r.tempi)
            let massimo = r.tempi.max() ?? 0
            let aggiornamento = ProvaFluidita.mediana(r.aggiornamento)
            let disegno: Double? = r.disegno.isEmpty ? nil : ProvaFluidita.mediana(r.disegno)
            let conteggi = r.avvisi.sorted()
            let avvisi: Int? = conteggi.isEmpty ? nil : conteggi[conteggi.count / 2]
            let conteggiFinestre = r.avvisiFinestre.sorted()
            let avvisiFinestre: Int? = conteggiFinestre.isEmpty ? nil : conteggiFinestre[conteggiFinestre.count / 2]

            var parti = ["\(ProvaFluidita.ms(mediana)) (max \(ProvaFluidita.ms(massimo)))",
                         "aggiornamento \(ProvaFluidita.ms(aggiornamento))"]
            if let disegno { parti.append("disegno \(ProvaFluidita.ms(disegno))") }
            if let p = r.primaVolta { parti.append("prima volta \(ProvaFluidita.ms(p))") }
            if let avvisi { parti.append(avvisi == 1 ? "1 avviso di cambiamento" : "\(avvisi) avvisi di cambiamento") }
            if let avvisiFinestre { parti.append("\(avvisiFinestre) delle finestre") }
            print("INFO fluidità · \(r.scenario) · \(r.azione): \(parti.joined(separator: " · "))")

            if mediana > r.limite {
                controlla(false, "\(r.scenario) · \(r.azione): \(ProvaFluidita.ms(mediana)) di mediana, oltre il limite di \(ProvaFluidita.secondi(r.limite))")
            } else if massimo > r.limite {
                print("ATTENZIONE \(r.scenario) · \(r.azione): un giro da \(ProvaFluidita.ms(massimo)), oltre \(ProvaFluidita.secondi(r.limite)) (la mediana resta sotto)")
            }
            if r.incoerente {
                controlla(false, "\(r.scenario) · \(r.azione): dopo l'azione lo stato non è quello atteso")
            }

            let celle: [String] = [
                r.scenario, r.azione, ProvaFluidita.ms(mediana), ProvaFluidita.ms(massimo), ProvaFluidita.ms(aggiornamento),
                disegno.map { ProvaFluidita.ms($0) } ?? "—",
                r.primaVolta.map { ProvaFluidita.ms($0) } ?? "—",
                avvisi.map { String($0) } ?? "—",
                avvisiFinestre.map { String($0) } ?? "—",
            ]
            tabella.append("| " + celle.joined(separator: " | ") + " |")
        }

        tabella.append("")
        if disegnoAssenteSegnalato {
            tabella.append("Disegno non disponibile sul server di build: misurato solo l'aggiornamento.")
        }
        if saltate > 0 {
            print("ATTENZIONE \(saltate) azioni non misurate: la prova ha superato \(ProvaFluidita.secondi(ProvaFluidita.limiteTempo))")
            tabella.append("\(saltate) azioni non misurate: la prova ha superato \(ProvaFluidita.secondi(ProvaFluidita.limiteTempo)).")
        }
        let mb = ProvaCarico.memoriaMB()
        let durata = ProvaFluidita.secondi(trascorso)
        print("INFO fluidità: \(righe.count) misure in \(durata), memoria occupata alla fine \(Int(mb)) MB")
        tabella.append("Memoria occupata alla fine: \(Int(mb)) MB · durata della prova: \(durata).")
        tabella.append("")

        if let uscita {
            do {
                try tabella.joined(separator: "\n").write(to: uscita, atomically: true, encoding: .utf8)
                print("INFO tabella della fluidità scritta in \(uscita.path)")
            } catch {
                print("ATTENZIONE tabella della fluidità non scritta: \(error.localizedDescription)")
            }
        }

        if errori == 0 {
            print("OK: fluidità misurata")
            return 0
        }
        print("ERRORE: \(errori) verifiche di fluidità non riuscite")
        return 1
    }
}
