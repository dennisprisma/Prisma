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
        // Chiusa un attimo fa e non ancora tolta: si toglie ora e si riapre da capo
        if sistema.inChiusura.contains(app) { completaChiusura(app) }
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
        // Come macOS: la finestra cresce dal punto da cui si apre (icona della scrivania, widget); dal dock (senza
        // origine, con il dock in vista) dalla sua icona. Senza né l'uno né l'altro, al suo posto
        sistema.origini[app] = origine ?? (finestreVisibili.isEmpty ? centroDock(app, nascosto: false) : nil)
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
    /// Con il motore la finestra vera torna subito (nascosta sotto la sua istantanea, che esce dall'icona): dock,
    /// controlli e impaginazione si ridisegnano sotto il genio. Senza, il ripiego (solo scala).
    fileprivate func ripristina(_ app: AppPrisma, da origine: CGPoint?) {
        guard let f = finestre.first(where: { $0.app == app }) else { return }
        let m = Tema.Moto.Finestre.self
        guard persistente else {
            diColpo(implicite: false) {
                rimetti(app)
                sistema.spente.remove(app)
            }
            return
        }
        let durata = m.durataRipristino * rallentamento
        // Ridotta a metà: torna su da dove si trova
        if let motore = motoreGenio, f.ridotta,
           motore.inverti(app, durata: durata, fatto: { [weak self] in self?.dopoRipristino(app) }) {
            diColpo {
                sistema.spente.remove(app)
                rimetti(app)
            }
            aggiornaCoperte(dopo: durata)
            return
        }
        let calmo = Movimenti.calmo
        // Come macOS: sempre dall'icona del dock, che durante il genio si vede (ferma al suo posto)
        let punto = centroDock(app, nascosto: calmo ? nil : false) ?? origine
        if let punto { sistema.origini[app] = punto }
        if let motore = motoreGenio, !calmo, let punto, let foto = istantaneaRipristino(f) {
            mostraDockPerEffetto(app)
            // Prima Core Animation (flush dentro `genio`), poi lo stato, tutto di colpo
            motore.genio(app, .ripristina, istantanea: foto, cornice: corniceInShell(f), icona: punto,
                         lato: Tema.Misura.dockIcona, durata: durata, ombra: ombraFinestra(f)) { [weak self] in
                self?.dopoRipristino(app)
            }
            diColpo {
                sistema.nascoste.insert(app)
                sistema.spente.remove(app)
                rimetti(app)
            }
            aggiornaCoperte(dopo: durata)
            return
        }
        // Ripiego: la finestra viva cresce dall'icona (solo scala)
        if sistema.spente.contains(app) {
            // I controlli si riaccendono subito, di colpo: il costo cade prima del primo fotogramma
            diColpo { _ = sistema.spente.remove(app) }
            Movimenti.alGiroDopo(m.ripristino, durata: durata) { [weak self] in self?.rimetti(app) }
        } else {
            // Ripristinata mentre il ripiego era ancora in corso: torna indietro da dove si trova
            Movimenti.anima(m.ripristino, durata: durata) { rimetti(app) }
        }
        // Il dock in vista dopo il cambio animato (mai prima, nello stesso giro)
        if !calmo {
            mostraDockPerEffetto(app)
            rilasciaDock(app, dopo: durata)
        }
        aggiornaCoperte(dopo: durata)
    }

    /// Il ripristino è finito: la finestra vera compare (il piano si toglie poco dopo) e il dock torna com'era.
    fileprivate func dopoRipristino(_ app: AppPrisma) {
        if sistema.nascoste.contains(app) { diColpo { _ = sistema.nascoste.remove(app) } }
        rilasciaDock(app, dopo: 0)
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

    /// Chiude l'app. Con l'istantanea pronta (il puntatore è passato sui semafori) la sua copia svanisce con un
    /// lieve rimpicciolimento; senza, come macOS, la finestra se ne va di colpo (niente vetro che sfuma, niente
    /// fantasma). Con «Riduci movimento», nelle istantanee e nelle prove: la dissolvenza di sempre.
    func chiudi(_ app: AppPrisma) {
        if let f = finestre.first(where: { $0.app == app }) {
            let m = Tema.Moto.Finestre.self
            if persistente && !Movimenti.calmo {
                let genio = MotoreGenio.condiviso
                // Un genio in corso per l'app finisce qui
                genio.annulla(app)
                var conIstantanea = false
                if let motore = motoreGenio, !f.ridotta, !sistema.coperte.contains(app),
                   let foto = genio.pronte[app], fresca(foto, per: f) {
                    motore.dissolvi(app, istantanea: foto, cornice: corniceInShell(f)) { MotoreGenio.condiviso.dimentica(app) }
                    conIstantanea = true
                } else {
                    genio.dimentica(app)
                }
                // Prima invisibile di colpo (così la sua uscita è senza transizione), poi via al giro dopo
                diColpo(implicite: false) { _ = sistema.nascoste.insert(app) }
                sistema.inChiusura.insert(app)
                rilasciaDock(app, dopo: 0)
                let dopo = conIstantanea ? m.durataChiusura : 0
                DispatchQueue.main.async { [weak self] in self?.completaChiusura(app, coperteDopo: dopo) }
            } else {
                Movimenti.anima(m.chiusura, durata: m.durataChiusura, animato: persistente) {
                    finestre.removeAll { $0.app == app }
                }
                if sistema.flip[app] != nil || sistema.inArrivo.contains(app) || sistema.spente.contains(app)
                    || sistema.nascoste.contains(app) {
                    diColpo {
                        sistema.flip[app] = nil
                        sistema.inArrivo.remove(app)
                        sistema.spente.remove(app)
                        sistema.nascoste.remove(app)
                    }
                }
                aggiornaCoperte(dopo: m.durataChiusura)
            }
        }
        if app == .eve { spegniVoceSeEveSparisce() }
    }

    /// Toglie davvero la finestra chiusa (il giro dopo `chiudi`, o subito se nel frattempo la si riapre).
    fileprivate func completaChiusura(_ app: AppPrisma, coperteDopo: Double = 0) {
        guard sistema.inChiusura.remove(app) != nil else { return }
        diColpo(implicite: false) {
            finestre.removeAll { $0.app == app }
            if sistema.nascoste.contains(app) { sistema.nascoste.remove(app) }
            if sistema.flip[app] != nil { sistema.flip[app] = nil }
            if sistema.inArrivo.contains(app) { sistema.inArrivo.remove(app) }
            if sistema.spente.contains(app) { sistema.spente.remove(app) }
        }
        aggiornaCoperte(dopo: coperteDopo)
    }

    /// Riduce l'app nel dock con il «genio»: la finestra resta montata, invisibile, con tutto il suo stato.
    func riduci(_ app: AppPrisma) {
        // Se è l'ultima finestra in vista il dock ricompare: il genio va nella sua icona, non sul bordo
        riduci(app, dockNascosto: finestreVisibili.contains { $0.app != app })
    }

    /// `dockNascosto`: come sarà il dock a genio finito. `conIstantanea`: false per le finestre oltre
    /// genioIstantaneeTenute di «Mostra la scrivania» (ripiego, niente memoria in più).
    /// Con il motore: prima Core Animation (l'istantanea a strisce entra nell'icona), poi lo stato, di colpo:
    /// dock, area, scrivania e app si ridisegnano sotto il genio, che non dipende più dal thread principale.
    fileprivate func riduci(_ app: AppPrisma, dockNascosto: Bool, conIstantanea: Bool = true) {
        guard let i = finestre.firstIndex(where: { $0.app == app }), !finestre[i].ridotta else { return }
        let m = Tema.Moto.Finestre.self
        guard persistente else {
            diColpo(implicite: false) {
                finestre[i].ridotta = true
                sistema.spente.insert(app)
            }
            if app == .eve { spegniVoceSeEveSparisce() }
            return
        }
        let durata = m.durataGenio * rallentamento
        defer {
            // Il campo con il cursore resta nella finestra ridotta: i tasti non devono finirci
            NSApp.keyWindow?.makeFirstResponder(nil)
            if app == .eve { spegniVoceSeEveSparisce() }
        }
        // Ripristinata a metà: torna giù da dove si trova
        if let motore = motoreGenio,
           motore.inverti(app, durata: durata, fatto: { [weak self] in self?.dopoRiduzione(app) }) {
            diColpo { finestre[i].ridotta = true }
            aggiornaCoperte(dopo: durata)
            return
        }
        let calmo = Movimenti.calmo
        // Il dock si vede durante il genio (anche se poi resta nascosto): il punto è la sua icona a riposo
        let punto = centroDock(app, nascosto: calmo ? dockNascosto : false)
        if let punto { sistema.origini[app] = punto }
        let f = finestre[i]
        if let motore = motoreGenio, !calmo, conIstantanea, let punto, let foto = istantaneaRiduzione(f) {
            mostraDockPerEffetto(app)
            // 1. Core Animation prima (il flush è dentro `genio`)
            motore.genio(app, .riduci, istantanea: foto, cornice: corniceInShell(f), icona: punto,
                         lato: Tema.Misura.dockIcona, durata: durata, ombra: ombraFinestra(f)) { [weak self] in
                self?.dopoRiduzione(app)
            }
            // 2. Poi lo stato, tutto di colpo, sotto il genio
            diColpo {
                sistema.nascoste.insert(app)
                finestre[i].ridotta = true
            }
            aggiornaCoperte(dopo: durata)
            return
        }
        // Ripiego (istantanea lenta o non disponibile, «Riduci movimento»): la finestra viva rimpicciolisce verso
        // l'icona e svanisce, solo con una scala
        let ripiego = m.durataRipiegoGenio * rallentamento
        Movimenti.anima(calmo ? Tema.Moto.dissolvenzaCalma : m.ripiegoGenio, durata: ripiego) {
            finestre[i].ridotta = true
        }
        // A movimento finito i controlli dell'app si spengono (se nel frattempo non è tornata)
        Movimenti.dopo(ripiego) { [weak self] in
            guard let self, self.finestre.first(where: { $0.app == app })?.ridotta == true,
                  !self.sistema.spente.contains(app) else { return }
            self.sistema.spente.insert(app)
        }
        // Il dock in vista dopo il cambio animato (mai prima, nello stesso giro)
        if !calmo {
            mostraDockPerEffetto(app)
            rilasciaDock(app, dopo: ripiego)
        }
        // L'istantanea per il ripristino si prepara al giro dopo, mentre il ripiego scorre
        if motoreGenio != nil, !calmo {
            DispatchQueue.main.async { [weak self] in
                guard let self, let f = self.finestre.first(where: { $0.app == app }), f.ridotta,
                      MotoreGenio.condiviso.pronte[app] == nil else { return }
                _ = self.catturaIstantanea(f)
            }
        }
        aggiornaCoperte(dopo: ripiego)
    }

    /// La riduzione è finita: la finestra (ridotta, quindi invisibile) esce dalle nascoste e i suoi controlli si spengono.
    fileprivate func dopoRiduzione(_ app: AppPrisma) {
        let ridotta = finestre.first(where: { $0.app == app })?.ridotta == true
        if sistema.nascoste.contains(app) || (ridotta && !sistema.spente.contains(app)) {
            diColpo {
                if sistema.nascoste.contains(app) { sistema.nascoste.remove(app) }
                if ridotta && !sistema.spente.contains(app) { sistema.spente.insert(app) }
            }
        }
        rilasciaDock(app, dopo: 0)
    }

    // MARK: - Istantanee ed effetti (MotoreGenio)

    /// Il motore degli effetti: solo nell'app vera, con lo strato installato in una finestra visibile.
    fileprivate var motoreGenio: MotoreGenio? { persistente ? MotoreGenio.condiviso.pronto : nil }

    /// Con Maiusc premuto il genio va al rallentatore, come su macOS.
    fileprivate var rallentamento: Double {
        NSEvent.modifierFlags.contains(.shift) ? Tema.Moto.Finestre.fattoreRallentato : 1
    }

    /// L'area in cui si disegna la finestra: le ridotte tengono quella con il dock nascosto (come `livelloFinestre`).
    fileprivate func areaDi(_ f: Finestra) -> CGRect {
        f.ridotta ? ShellView.area(per: sistema.misura, dockNascosto: true) : area
    }

    /// La cornice della finestra nelle coordinate della shell (y in giù).
    fileprivate func corniceInShell(_ f: Finestra) -> CGRect {
        let a = areaDi(f)
        return cornice(di: f, in: a).offsetBy(dx: a.minX, dy: a.minY)
    }

    /// L'ombra della finestra attiva, già sfocata (la stessa bitmap di OmbraVetroPronta).
    fileprivate func ombraFinestra(_ f: Finestra) -> OmbraPrecalcolata.Pronta? {
        let scala = MotoreGenio.condiviso.strato?.window?.backingScaleFactor ?? 2
        return OmbraPrecalcolata.ombra(raggio: f.ingrandita ? Tema.Raggio.finestraIngrandita : Tema.Raggio.finestra,
                                       strati: Tema.Ombra.finestra(attiva: true), scala: scala)
    }

    /// Un'istantanea pronta vale se è recente e della misura della finestra.
    fileprivate func fresca(_ foto: IstantaneaFinestra.Pronta, per f: Finestra) -> Bool {
        let c = cornice(di: f, in: areaDi(f))
        return CACurrentMediaTime() - foto.quando < Tema.Moto.Finestre.genioValiditaIstantanea
            && abs(foto.misura.width - c.width) < 0.5 && abs(foto.misura.height - c.height) < 0.5
    }

    /// Cattura ora l'istantanea della finestra e la mette da parte nel motore.
    @discardableResult
    fileprivate func catturaIstantanea(_ f: Finestra) -> IstantaneaFinestra.Pronta? {
        guard let w = MotoreGenio.condiviso.strato?.window else { return nil }
        let scuro = w.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        guard let foto = IstantaneaFinestra.cattura(f, stato: self, area: areaDi(f), scala: w.backingScaleFactor,
                                                    scuro: scuro) else { return nil }
        MotoreGenio.condiviso.tieni(f.app, foto)
        return foto
    }

    /// Per la riduzione: quella preparata sui semafori se fresca; altrimenti la si cattura ora, se l'ultima
    /// cattura non è stata lenta (se lo è stata: ripiego, e l'istantanea si prepara al giro dopo).
    fileprivate func istantaneaRiduzione(_ f: Finestra) -> IstantaneaFinestra.Pronta? {
        if let foto = MotoreGenio.condiviso.pronte[f.app], fresca(foto, per: f) { return foto }
        guard !IstantaneaFinestra.lenta else { return nil }
        return catturaIstantanea(f)
    }

    /// Per il ripristino: quella tenuta dalla riduzione (della misura giusta), o una nuova se la cattura è veloce.
    fileprivate func istantaneaRipristino(_ f: Finestra) -> IstantaneaFinestra.Pronta? {
        let c = cornice(di: f, in: areaDi(f))
        if let foto = MotoreGenio.condiviso.pronte[f.app],
           abs(foto.misura.width - c.width) < 0.5, abs(foto.misura.height - c.height) < 0.5 { return foto }
        guard !IstantaneaFinestra.lenta else { return nil }
        return catturaIstantanea(f)
    }

    /// Il puntatore è sui semafori: l'istantanea si prepara ora (al giro dopo), così chiudi e riduci partono senza
    /// attesa. Non più spesso di genioIntervalloPreparazione, mai con un effetto o un movimento in corso.
    func preparaEffetto(_ app: AppPrisma) {
        guard persistente, motoreGenio != nil, !Movimenti.calmo else { return }
        let motore = MotoreGenio.condiviso
        let adesso = CACurrentMediaTime()
        guard adesso - motore.ultimaPreparazione >= Tema.Moto.Finestre.genioIntervalloPreparazione else { return }
        motore.ultimaPreparazione = adesso
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.bloccato, self.presentazione == nil,
                  let f = self.finestre.first(where: { $0.app == app }), !f.ridotta,
                  !motore.inCorso(app), self.sistema.flip[app] == nil, !self.sistema.inArrivo.contains(app),
                  !self.sistema.nascoste.contains(app) else { return }
            if let foto = motore.pronte[app], self.fresca(foto, per: f) { return }
            self.catturaIstantanea(f)
        }
    }

    /// Il dock resta in vista durante l'effetto dell'app (con il dock nascosto si mostra, come macOS).
    fileprivate func mostraDockPerEffetto(_ app: AppPrisma) {
        guard !sistema.dockPerEffetti.contains(app) else { return }
        diColpo { _ = sistema.dockPerEffetti.insert(app) }
    }

    /// Dopo `dopo` secondi più il ritardo del dock, il dock torna com'era (si nasconde con la sua curva, se ci
    /// sono finestre in vista), a meno che l'app non abbia nel frattempo un altro effetto.
    fileprivate func rilasciaDock(_ app: AppPrisma, dopo: Double) {
        guard sistema.dockPerEffetti.contains(app) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + dopo + Tema.Moto.Dock.ritardoNascondi) { [weak self] in
            guard let self, self.sistema.dockPerEffetti.contains(app), !MotoreGenio.condiviso.inCorso(app) else { return }
            // Con la transazione vuota il dock scende con la sua animazione
            self.diColpo { _ = self.sistema.dockPerEffetti.remove(app) }
        }
    }

    /// Toglie di colpo tutti gli effetti in corso (blocco, presentazione, stop del Mac): le finestre tornano
    /// come dice lo stato e il dock com'era.
    func annullaEffetti() {
        MotoreGenio.condiviso.annullaTutto()
        // Le finestre chiuse un attimo fa restano nascoste: si tolgono al giro dopo
        let restano = sistema.nascoste.intersection(sistema.inChiusura)
        guard sistema.nascoste != restano || !sistema.dockPerEffetti.isEmpty else { return }
        diColpo(implicite: false) {
            if sistema.nascoste != restano { sistema.nascoste = restano }
            if !sistema.dockPerEffetti.isEmpty { sistema.dockPerEffetti.removeAll() }
        }
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
            // La guida si chiude senza segnare l'introduzione come vista: riparte al prossimo sblocco
            if sistema.guida != nil { sistema.guida = nil }
            if !bloccato { bloccato = true }
        }
        // Gli effetti in corso finiscono di colpo (dopo il cambio animato: mai prima, nello stesso giro)
        annullaEffetti()
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
            // Al primo avvio parte l'introduzione «Come funziona Prisma»
            self.dopoSblocco()
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
        // Oltre genioIstantaneeTenute finestre il genio delle altre è il ripiego (memoria: 8 GB)
        let tenute = Tema.Moto.Finestre.genioIstantaneeTenute
        for (k, app) in davanti.enumerated() {
            if k == 0 {
                riduci(app, dockNascosto: false)
                continue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * Tema.Moto.Finestre.sfalsamento) { [weak self] in
                // Nel frattempo si è aperta o portata davanti un'app: quella resta dov'è
                guard let self, self.sistema.giroScrivania == giro else { return }
                self.riduci(app, dockNascosto: false, conIstantanea: k < tenute)
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
