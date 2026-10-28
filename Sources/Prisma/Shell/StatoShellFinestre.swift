import AppKit
import SwiftUI

// Proprietario: G1 (movimento delle finestre). Spostato qui da StatoShell.swift dalle fondamenta (G0).
// Ogni azione ha la sua curva (DesignSystem/Movimento.swift); con lo stato non persistente (istantanee e prove)
// tutto cambia di colpo e subito, come prima.
// In un giro del run loop la prima modifica dello stato porta la transazione giusta: le modifiche senza
// animazione vengono dopo quella animata, mai prima, altrimenti la vista le leggerebbe tutte insieme senza animazione.

// MARK: - Inoltri a StatoFinestre

extension StatoShell {
    // Le finestre, i pannelli e il blocco vivono in `sistema` (StatoFinestre): cambiarli non pubblica StatoShell,
    // così le app aperte e i widget non si ricalcolano. I nomi restano quelli di sempre.

    /// Finestre aperte; l'ultima è quella in primo piano.
    var finestre: [Finestra] {
        get { sistema.elenco }
        set { sistema.elenco = newValue }
    }

    /// La schermata di benvenuto copre le finestre (il lucchetto in alto).
    var bloccato: Bool {
        get { sistema.bloccato }
        set { sistema.bloccato = newValue }
    }

    var pannelloAppAperte: Bool {
        get { sistema.pannelloAppAperte }
        set { sistema.pannelloAppAperte = newValue }
    }

    /// Il pannello degli spazi di lavoro è aperto.
    var pannelloSpazi: Bool {
        get { sistema.pannelloSpazi }
        set { sistema.pannelloSpazi = newValue }
    }

    /// Il centro notifiche è aperto.
    var pannelloNotifiche: Bool {
        get { sistema.pannelloNotifiche }
        set { sistema.pannelloNotifiche = newValue }
    }

    var finestreVisibili: [Finestra] { sistema.visibili }

    /// App in primo piano (nil = scrivania).
    var appAttiva: AppPrisma? { sistema.appAttiva }

    /// Lo sfondo d'acqua non si vede affatto: lo copre la sala (opaca) della presentazione. Solo allora l'acqua
    /// si ferma: lo sfondo è sempre attivo, anche sotto le finestre aperte e ingrandite (si vede dal vetro e dalla
    /// cornice attorno) e sotto la schermata di benvenuto.
    var scrivaniaCoperta: Bool { presentazione != nil }

    func aperta(_ app: AppPrisma) -> Bool { sistema.aperta(app) }
}

// MARK: - Finestre

extension StatoShell {
    /// Cambia lo stato senza animazione. Con `implicite` le animazioni circoscritte di ShellView (dock, pannelli)
    /// lavorano lo stesso; senza (istantanee, prove, stop del Mac) cambia tutto di colpo.
    fileprivate func diColpo(implicite: Bool = true, _ cambia: () -> Void) {
        if implicite && persistente {
            withTransaction(Transaction(animation: nil), cambia)
        } else {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t, cambia)
        }
    }

    /// Il centro dell'icona dell'app nel dock (coordinate `ShellView.spazioShell`). Con finestre aperte il dock
    /// è nascosto: l'icona è sul bordo in basso. `nascosto`: come sarà il dock a movimento finito.
    fileprivate func centroDock(_ app: AppPrisma, nascosto: Bool? = nil) -> CGPoint? {
        DisposizioneDock.centroIcona(app, tra: AppPrisma.allCases.filter { appConsentita($0) },
                                     in: sistema.misura, nascosto: nascosto ?? !finestreVisibili.isEmpty)
    }

    /// Apre l'app (o la riporta davanti). `origine`: da dove si apre, nelle coordinate `ShellView.spazioShell`
    /// (icona della scrivania, widget). Come in macOS la finestra nuova compare al suo posto e quella ridotta
    /// torna sempre dall'icona del dock: l'origine serve solo se il dock non c'è.
    func apri(_ app: AppPrisma, da origine: CGPoint? = nil) {
        guard appConsentita(app) else {
            mostraAvviso("In modalità cliente \(app.titolo) non si apre: mostra i dati di altri clienti.")
            return
        }
        sistema.giroScrivania &+= 1
        if let f = finestre.first(where: { $0.app == app }) {
            if f.ridotta {
                ripristina(app, da: origine)
            } else {
                // Già aperta: davanti di colpo, come su macOS
                primoPiano(app)
            }
        } else {
            nuova(app, da: origine)
        }
        if app == .impostazioni { aggiornaElencoBackup() }
        if app == .eve || app == .impostazioni { verificaMotoreLocale() }
    }

    /// Una finestra nuova: entra subito, trasparente e piccola, senza animazione (il corpo dell'app si costruisce
    /// qui); al giro dopo compare al suo posto con la curva d'apertura, già pronta.
    fileprivate func nuova(_ app: AppPrisma, da origine: CGPoint?) {
        let f = Finestra(app: app, cornice: corniceIniziale())
        guard persistente else {
            diColpo(implicite: false) {
                finestre.append(f)
                sistema.spente.remove(app)
            }
            return
        }
        // Il punto del genio si fissa riducendo; un'origine rimasta da prima non serve più
        sistema.origini[app] = origine
        diColpo {
            finestre.append(f)
            sistema.inArrivo.insert(app)
            if sistema.spente.contains(app) { sistema.spente.remove(app) }
        }
        Movimenti.alGiroDopo(Tema.Moto.Finestre.apertura, durata: Tema.Moto.Finestre.durataApertura) { [weak self] in
            guard let self else { return }
            self.sistema.inArrivo.remove(app)
        }
        aggiornaCoperte(dopo: Tema.Moto.Finestre.durataApertura)
    }

    /// La finestra ridotta rientra dall'icona del dock («genio» al contrario): è rimasta montata, non si ricostruisce.
    fileprivate func ripristina(_ app: AppPrisma, da origine: CGPoint?) {
        guard finestre.contains(where: { $0.app == app }) else { return }
        let m = Tema.Moto.Finestre.self
        guard persistente else {
            diColpo(implicite: false) {
                rimetti(app)
                sistema.spente.remove(app)
            }
            return
        }
        // Come macOS: sempre dall'icona del dock (come sarà il dock adesso)
        if let punto = centroDock(app) ?? origine { sistema.origini[app] = punto }
        if sistema.spente.contains(app) {
            // I controlli si riaccendono subito, di colpo: il costo cade prima del primo fotogramma del genio
            diColpo { _ = sistema.spente.remove(app) }
            Movimenti.alGiroDopo(m.ripristino, durata: m.durataRipristino) { [weak self] in self?.rimetti(app) }
        } else {
            // Ripristinata mentre il genio era ancora in corso: torna indietro da dove si trova
            Movimenti.anima(m.ripristino, durata: m.durataRipristino) { rimetti(app) }
        }
        aggiornaCoperte(dopo: m.durataRipristino)
    }

    /// Riporta l'app ridotta in primo piano (la transazione la dà chi chiama).
    fileprivate func rimetti(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), finestre[i].ridotta else { return }
        var elenco = finestre
        var f = elenco.remove(at: i)
        f.ridotta = false
        elenco.append(f)
        finestre = elenco
    }

    /// Porta l'app davanti: istantaneo come su macOS (cambia solo l'ordine e l'ombra passa ad attiva di colpo).
    func primoPiano(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), i != finestre.count - 1 else { return }
        sistema.giroScrivania &+= 1
        var elenco = finestre
        let f = elenco.remove(at: i)
        elenco.append(f)
        diColpo { finestre = elenco }
        aggiornaCoperte(dopo: 0)
    }

    /// Chiude l'app: breve, in accelerazione (la curva sta nella transizione di ShellView).
    func chiudi(_ app: AppPrisma) {
        if aperta(app) {
            Movimenti.anima(Tema.Moto.Finestre.chiusura, durata: Tema.Moto.Finestre.durataChiusura, animato: persistente) {
                finestre.removeAll { $0.app == app }
            }
            if sistema.flip[app] != nil || sistema.inArrivo.contains(app) || sistema.spente.contains(app) {
                diColpo {
                    sistema.flip[app] = nil
                    sistema.inArrivo.remove(app)
                    sistema.spente.remove(app)
                }
            }
            aggiornaCoperte(dopo: Tema.Moto.Finestre.durataChiusura)
        }
        if app == .eve { spegniVoceSeEveSparisce() }
    }

    /// Riduce l'app nel dock con il «genio»: la finestra resta montata, invisibile, con tutto il suo stato.
    func riduci(_ app: AppPrisma) {
        // Se è l'ultima finestra in vista il dock ricompare: il genio va nella sua icona, non sul bordo
        riduci(app, dockNascosto: finestreVisibili.contains { $0.app != app })
    }

    /// `dockNascosto`: come sarà il dock a genio finito (dove sta l'icona in cui entra la finestra).
    fileprivate func riduci(_ app: AppPrisma, dockNascosto: Bool) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), !finestre[i].ridotta else { return }
        let m = Tema.Moto.Finestre.self
        if persistente, let punto = centroDock(app, nascosto: dockNascosto) { sistema.origini[app] = punto }
        Movimenti.anima(m.genio, durata: m.durataGenio, animato: persistente) {
            finestre[i].ridotta = true
        }
        if persistente {
            // A genio finito i controlli dell'app si spengono (se nel frattempo non è tornata)
            Movimenti.dopo(m.durataGenio) { [weak self] in
                guard let self, self.finestre.first(where: { $0.app == app })?.ridotta == true,
                      !self.sistema.spente.contains(app) else { return }
                self.sistema.spente.insert(app)
            }
        } else {
            diColpo(implicite: false) { _ = sistema.spente.insert(app) }
        }
        aggiornaCoperte(dopo: m.durataGenio)
        // Il campo con il cursore resta nella finestra ridotta: i tasti non devono finirci
        if persistente { NSApp.keyWindow?.makeFirstResponder(nil) }
        if app == .eve { spegniVoceSeEveSparisce() }
    }

    func alternaIngrandimento(_ app: AppPrisma) {
        guard let i = finestre.firstIndex(where: { $0.app == app }) else { return }
        cambiaCornici {
            finestre[i].ingrandita.toggle()
            if !finestre[i].ingrandita {
                finestre[i].cornice = limita(finestre[i].cornice)
            }
        }
        primoPiano(app)
        aggiornaCoperte(dopo: Tema.Moto.Finestre.durataIngrandimento)
    }

    /// Mostra la schermata di benvenuto sopra tutto (chiude i pannelli aperti).
    /// `animato == false`: di colpo (per esempio prima dello stop del Mac).
    func blocca(animato: Bool = true) {
        let movimento = animato && persistente
        let giro = sistema.giroBlocco &+ 1
        sistema.giroBlocco = giro
        // I pannelli escono con le loro curve (contenitori di ShellView), nella stessa transazione del blocco
        Movimenti.anima(Tema.Moto.Blocco.scrivania, durata: Tema.Moto.Blocco.durata, animato: movimento) {
            if pannelloNotifiche { pannelloNotifiche = false }
            if pannelloSpazi { pannelloSpazi = false }
            if pannelloAppAperte { pannelloAppAperte = false }
            if !bloccato { bloccato = true }
        }
        // Dalla schermata di blocco si torna sempre a Prisma completo (e la finestra esce dal tutto schermo)
        chiudiPresentazione()
        guard movimento else {
            diColpo(implicite: false) {
                fermaVoce()
                if modoCliente != nil { modoCliente = nil }
                sistema.bloccatoStabile = true
            }
            return
        }
        // La voce si ferma al giro dopo; la modalità cliente (che rifiltra tutte le app) a blocco finito, sotto la schermata
        DispatchQueue.main.async { [weak self] in self?.fermaVoce() }
        Movimenti.dopo(Tema.Moto.Blocco.durata) { [weak self] in
            guard let self else { return }
            if self.modoCliente != nil { self.modoCliente = nil }
            if self.sistema.giroBlocco == giro && self.bloccato { self.sistema.bloccatoStabile = true }
        }
    }

    /// Toglie la schermata di benvenuto. `velocita`: quella del gesto di sblocco, in percorsi al secondo
    /// (una parte passa all'entrata della scrivania).
    func sblocca(velocita: Double = 0) {
        guard bloccato else { return }
        let giro = sistema.giroBlocco &+ 1
        sistema.giroBlocco = giro
        Movimenti.anima(Tema.Moto.Sblocco.entrata(velocita: velocita), durata: Tema.Moto.Sblocco.durataEntrata,
                        animato: persistente) {
            bloccato = false
        }
        guard persistente else {
            diColpo(implicite: false) { sistema.bloccatoStabile = false }
            return
        }
        Movimenti.dopo(Tema.Moto.Sblocco.durataEntrata) { [weak self] in
            guard let self, self.sistema.giroBlocco == giro, !self.bloccato else { return }
            self.sistema.bloccatoStabile = false
        }
    }

    /// Riduce tutte le finestre e mostra la scrivania: una ogni 50 ms, dalla finestra in alto (tema showDesk).
    func mostraScrivania() {
        let davanti = finestreVisibili.reversed().map(\.app)
        guard !davanti.isEmpty else { return }
        guard persistente else {
            var elenco = finestre
            for i in elenco.indices { elenco[i].ridotta = true }
            diColpo(implicite: false) {
                finestre = elenco
                sistema.spente.formUnion(elenco.map(\.app))
            }
            return
        }
        let giro = sistema.giroScrivania &+ 1
        sistema.giroScrivania = giro
        // A scrivania scoperta il dock ricompare: tutte le finestre entrano nelle loro icone
        for (k, app) in davanti.enumerated() {
            if k == 0 {
                riduci(app, dockNascosto: false)
                continue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * Tema.Moto.Finestre.sfalsamento) { [weak self] in
                // Nel frattempo si è aperta o portata davanti un'app: quella resta dov'è
                guard let self, self.sistema.giroScrivania == giro else { return }
                self.riduci(app, dockNascosto: false)
            }
        }
    }

    // MARK: - Transizioni delle cornici e finestre coperte

    /// Ingrandisci, affianca, spazi: la cornice nuova vale subito (una sola impaginazione dell'app), poi una
    /// trasformazione porta ogni finestra dalla cornice vecchia alla nuova (FLIP, come lo zoom di macOS).
    /// `arrivi`: le finestre che compaiono, che entrano con l'apertura.
    fileprivate func cambiaCornici(arrivi: Set<AppPrisma> = [], _ cambia: () -> Void) {
        guard persistente else {
            diColpo(implicite: false, cambia)
            return
        }
        let calmo = Movimenti.calmo
        var prima: [AppPrisma: CGRect] = [:]
        for f in finestreVisibili { prima[f.app] = cornice(di: f) }
        var passaggi: [AppPrisma: CGRect] = [:]
        diColpo {
            cambia()
            sistema.inArrivo.formUnion(arrivi)
            // Con «Riduci movimento» le cornici cambiano di colpo
            guard !calmo else { return }
            for f in finestreVisibili where !arrivi.contains(f.app) {
                guard let da = prima[f.app], da != cornice(di: f) else { continue }
                passaggi[f.app] = da
                sistema.flip[f.app] = PassaggioCornice(da: da, progresso: 0)
            }
        }
        let fatti = passaggi
        if !arrivi.isEmpty {
            Movimenti.alGiroDopo(Tema.Moto.Finestre.apertura, durata: Tema.Moto.Finestre.durataApertura) { [weak self] in
                guard let self else { return }
                self.sistema.inArrivo.subtract(arrivi)
            }
        }
        guard !fatti.isEmpty else { return }
        Movimenti.alGiroDopo(Tema.Moto.Finestre.ingrandimento, durata: Tema.Moto.Finestre.durataIngrandimento) { [weak self] in
            guard let self else { return }
            for (app, da) in fatti where self.sistema.flip[app]?.da == da {
                self.sistema.flip[app]?.progresso = 1
            }
        }
        Movimenti.dopo(Tema.Moto.Finestre.fineIngrandimento) { [weak self] in
            guard let self else { return }
            for (app, da) in fatti where self.sistema.flip[app] == PassaggioCornice(da: da, progresso: 1) {
                self.sistema.flip[app] = nil
            }
        }
    }

    /// Le finestre sotto una finestra ingrandita (e la scrivania) a transizione finita non si disegnano: restano
    /// montate. Quelle che tornano in vista si mostrano subito, quelle coperte solo dopo `durata`.
    fileprivate func aggiornaCoperte(dopo durata: Double) {
        // Istantanee e prove: si disegna tutto, come prima
        guard persistente else { return }
        let giro = sistema.giroCoperte &+ 1
        sistema.giroCoperte = giro
        let previste = copertePreviste
        let scoperte = sistema.coperte.subtracting(previste.finestre)
        if !scoperte.isEmpty || (sistema.scrivaniaNascosta && !previste.scrivania) {
            diColpo {
                if !scoperte.isEmpty { sistema.coperte.subtract(scoperte) }
                if sistema.scrivaniaNascosta && !previste.scrivania { sistema.scrivaniaNascosta = false }
            }
        }
        Movimenti.dopo(durata) { [weak self] in
            guard let self, self.sistema.giroCoperte == giro else { return }
            let ora = self.copertePreviste
            if self.sistema.coperte != ora.finestre { self.sistema.coperte = ora.finestre }
            if self.sistema.scrivaniaNascosta != ora.scrivania { self.sistema.scrivaniaNascosta = ora.scrivania }
        }
    }

    /// Le finestre visibili sotto l'ultima finestra ingrandita, e se la scrivania è coperta.
    fileprivate var copertePreviste: (finestre: Set<AppPrisma>, scrivania: Bool) {
        let visibili = finestreVisibili
        guard let i = visibili.lastIndex(where: { $0.ingrandita }) else { return ([], false) }
        return (Set(visibili[..<i].map(\.app)), true)
    }

    // MARK: - Spazi di lavoro

    /// Gli spazi pronti e quelli salvati dal consulente.
    var spaziDiLavoro: [SpazioLavoro] { SpazioLavoro.predefiniti + dati.spazi }

    /// L'area che avranno le finestre: con una finestra aperta il dock si nasconde e lo spazio cresce.
    fileprivate var areaConFinestre: CGRect {
        guard finestreVisibili.isEmpty else { return area }
        var a = area
        a.size.height += Misure.Dock.riservato - Misure.Dock.riservatoNascosto
        return a
    }

    /// Cornice di una finestra dello spazio nell'area, con un piccolo stacco tra finestre affiancate.
    fileprivate func cornice(da f: FinestraSpazio, in area: CGRect) -> CGRect {
        let r = CGRect(x: f.x * area.width, y: f.y * area.height, width: f.larghezza * area.width, height: f.altezza * area.height)
            .insetBy(dx: Misure.Spazi.stacco / 2, dy: Misure.Spazi.stacco / 2)
        return limita(CGRect(origin: r.origin, size: CGSize(width: max(r.width, Misure.Finestra.minima.width),
                                                           height: max(r.height, Misure.Finestra.minima.height))), in: area)
    }

    /// Apre lo spazio: le sue app, disposte come salvate, al posto delle finestre aperte. Le finestre che non ne
    /// fanno parte si chiudono; quelle che restano in vista vanno al loro posto (al giro dopo, FLIP); le altre si aprono.
    func apriSpazio(_ s: SpazioLavoro) {
        let area = areaConFinestre
        sistema.giroScrivania &+= 1
        // In modalità cliente le app che leggono tutti i clienti restano chiuse
        let nuove = s.finestre.filter { appConsentita($0.app) }.map { f in
            Finestra(app: f.app, cornice: cornice(da: f, in: area), ingrandita: f.ingrandita)
        }
        // A cose fatte: le modifiche senza animazione non vanno prima di quelle animate
        defer { if s.finestre.contains(where: { $0.app == .impostazioni }) { aggiornaElencoBackup() } }
        guard persistente else {
            diColpo(implicite: false) {
                if pannelloSpazi { pannelloSpazi = false }
                finestre = nuove
                sistema.spente.removeAll()
            }
            return
        }
        let restano = Set(nuove.map(\.app))
        // Le app nuove si aprono senza punto d'origine; quelle ridotte tornano dal dock
        for app in restano where !aperta(app) { sistema.origini[app] = nil }
        let ferme = Set(finestreVisibili.map(\.app)).intersection(restano)
        guard !ferme.isEmpty else {
            // Nessuna finestra resta in vista: le vecchie si chiudono e quelle dello spazio si aprono insieme
            Movimenti.anima(Tema.Moto.Finestre.chiusura, durata: Tema.Moto.Finestre.durataChiusura) {
                if pannelloSpazi { pannelloSpazi = false }
                finestre = nuove
                sistema.inArrivo.formUnion(restano)
                if !sistema.spente.isEmpty { sistema.spente.removeAll() }
            }
            Movimenti.alGiroDopo(Tema.Moto.Finestre.apertura, durata: Tema.Moto.Finestre.durataApertura) { [weak self] in
                self?.sistema.inArrivo.subtract(restano)
            }
            aggiornaCoperte(dopo: Tema.Moto.Finestre.durataApertura)
            return
        }
        Movimenti.anima(Tema.Moto.Finestre.chiusura, durata: Tema.Moto.Finestre.durataChiusura) {
            if pannelloSpazi { pannelloSpazi = false }
            finestre.removeAll { !restano.contains($0.app) }
            // Le finestre dello spazio tornano tutte in vista: i loro controlli si riaccendono
            if !sistema.spente.isEmpty { sistema.spente.removeAll() }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let arrivi = restano.subtracting(self.finestreVisibili.map(\.app))
            self.cambiaCornici(arrivi: arrivi) { self.finestre = nuove }
            self.aggiornaCoperte(dopo: Tema.Moto.Finestre.durataIngrandimento)
        }
    }

    /// Salva le finestre aperte come nuovo spazio (dalla più in fondo a quella in primo piano).
    @discardableResult
    func salvaSpazio(nome: String) -> SpazioLavoro? {
        let n = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !finestreVisibili.isEmpty, area.width > 0, area.height > 0 else { return nil }
        let elenco = finestreVisibili.map { f -> FinestraSpazio in
            guard !f.ingrandita else { return .intera(f.app) }
            // Lo stacco tra finestre affiancate si toglie qui e si rimette alla riapertura
            let c = cornice(di: f).insetBy(dx: -Misure.Spazi.stacco / 2, dy: -Misure.Spazi.stacco / 2)
            return FinestraSpazio(app: f.app, x: c.minX / area.width, y: c.minY / area.height,
                                  larghezza: c.width / area.width, altezza: c.height / area.height)
        }
        let spazio = SpazioLavoro(nome: String(n.prefix(Misure.Spazi.nomeMassimo)), finestre: elenco)
        dati.spazi.append(spazio)
        mostraAvviso("Spazio «\(spazio.nome)» salvato.")
        return spazio
    }

    func eliminaSpazio(_ id: String) {
        dati.spazi.removeAll { $0.id == id }
    }

    /// ◫ nella barra del titolo: la finestra a sinistra e quella sotto di lei a destra.
    func affianca(_ app: AppPrisma) {
        let visibili = finestreVisibili
        guard let altra = visibili.last(where: { $0.app != app }) else {
            mostraAvviso("Apri un'altra app dal dock per affiancarla a questa.")
            return
        }
        guard let i = finestre.firstIndex(where: { $0.app == app }),
              let j = finestre.firstIndex(where: { $0.app == altra.app }) else { return }
        let area = self.area
        cambiaCornici {
            finestre[i].ingrandita = false
            finestre[i].cornice = cornice(da: .sinistra(app), in: area)
            finestre[j].ingrandita = false
            finestre[j].cornice = cornice(da: .destra(altra.app), in: area)
        }
        primoPiano(app)
        aggiornaCoperte(dopo: Tema.Moto.Finestre.durataIngrandimento)
    }

    /// Sposta la finestra (al rilascio del trascinamento, senza animazione).
    func sposta(_ app: AppPrisma, origine: CGPoint) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), !finestre[i].ingrandita else { return }
        var c = finestre[i].cornice
        c.origin = origine
        finestre[i].cornice = limita(c)
    }

    /// Ridimensiona la finestra (al rilascio della maniglia, senza animazione).
    func ridimensiona(_ app: AppPrisma, dimensione: CGSize) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), !finestre[i].ingrandita else { return }
        var c = finestre[i].cornice
        c.size = CGSize(width: max(Misure.Finestra.minima.width, dimensione.width),
                        height: max(Misure.Finestra.minima.height, dimensione.height))
        finestre[i].cornice = limita(c)
    }

    /// Cornice effettiva da disegnare.
    func cornice(di f: Finestra) -> CGRect { cornice(di: f, in: area) }

    /// Cornice dentro un'area precisa: il disegno usa la stessa area in cui mette le finestre,
    /// così una finestra non è mai più alta del suo spazio (e la barra del titolo resta visibile).
    func cornice(di f: Finestra, in area: CGRect) -> CGRect {
        f.ingrandita ? CGRect(origin: .zero, size: area.size) : limita(f.cornice, in: area)
    }

    fileprivate func corniceIniziale() -> CGRect {
        let l = max(Misure.Finestra.minima.width, area.width * 0.72)
        let a = max(Misure.Finestra.minima.height, area.height * 0.8)
        let passo = CGFloat(finestre.count % 6) * 24
        return CGRect(x: (area.width - l) / 2 + passo, y: (area.height - a) / 3 + passo, width: l, height: a)
    }

    /// Tiene la finestra dentro l'area (la barra del titolo resta sempre raggiungibile).
    fileprivate func limita(_ c: CGRect) -> CGRect { limita(c, in: area) }

    fileprivate func limita(_ c: CGRect, in area: CGRect) -> CGRect {
        var r = c
        r.size.width = min(r.width, area.width)
        r.size.height = min(r.height, area.height)
        r.origin.x = min(max(r.minX, 0), area.width - r.width)
        r.origin.y = min(max(r.minY, 0), area.height - r.height)
        return r
    }
}
