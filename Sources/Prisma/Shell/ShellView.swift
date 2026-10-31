#if os(macOS)
import AppKit
#endif
import SwiftUI
import UniformTypeIdentifiers

/// L'unica finestra di Prisma: sfondo, scrivania, finestre interne, dock e barra superiore.
/// Involucro: mette a disposizione lo stato delle finestre (StatoFinestre) e disegna CorpoShell,
/// così PrismaApp, Istantanee e le prove non devono iniettare nient'altro che StatoShell.
struct ShellView: View {
    /// Spazio di coordinate dell'area delle finestre interne.
    static let spazioFinestre = "areaFinestre"
    /// Spazio di coordinate dell'intera shell (da dove si aprono le app: dock, scrivania, widget).
    static let spazioShell = "shell"

    @EnvironmentObject var stato: StatoShell

    var body: some View {
        CorpoShell(sistema: stato.sistema)
            .environmentObject(stato.sistema)
    }

    /// Area delle finestre interne: sotto la barra superiore, sopra il dock. Con il dock nascosto
    /// (almeno una finestra aperta) le finestre arrivano fino in fondo.
    static func area(per dimensione: CGSize, dockNascosto: Bool = false) -> CGRect {
        let dock = dockNascosto ? Misure.Dock.riservatoNascosto : Misure.Dock.riservato
        return CGRect(
            x: Misure.Finestra.margineLato,
            y: Misure.Barra.altezza + Misure.Finestra.margineAlto,
            width: max(0, dimensione.width - 2 * Misure.Finestra.margineLato),
            height: max(0, dimensione.height - Misure.Barra.altezza - Misure.Finestra.margineAlto
                - dock - Misure.Finestra.margineBasso)
        )
    }
}

/// Il disegno della shell: osserva StatoShell (dati, avvisi, presentazione) e StatoFinestre (finestre, pannelli, blocco).
/// Le animazioni nuove non partono nelle istantanee (`modoIstantanea`): le schermate ferme restano quelle di prima.
struct CorpoShell: View {
    @EnvironmentObject var stato: StatoShell
    @ObservedObject var sistema: StatoFinestre
    @Environment(\.modoIstantanea) var modoIstantanea
    /// Il puntatore è sul dock (o sul bordo in basso) mentre è nascosto: si mostra sopra le finestre.
    @State private var dockRichiamato = false
    /// Il dock richiamato si nasconde di nuovo poco dopo che il puntatore se ne va, come in macOS. In una scatola:
    /// passare sul dock non deve ridisegnare la shell (né rallentare l'acqua o il dock stesso).
    @State private var attesaDock = AttesaDock()
    /// Un file trascinato sopra Prisma: si mostra dove va.
    @State private var fileSopra = false
    /// Durante la presentazione la scrivania sotto la sala tiene la misura di prima: il tutto schermo non la reimpagina.
    @State private var misuraCongelata: CGSize?
    /// La sala della presentazione copre tutto (a dissolvenza finita): la scrivania sotto non si disegna.
    @State private var salaCoprente = false

    /// Con una finestra aperta il dock si nasconde, come in macOS: torna portando il puntatore in basso.
    private var dockNascosto: Bool { !sistema.visibili.isEmpty }

    var body: some View {
        GeometryReader { geo in
            let misura = misuraCongelata ?? geo.size
            let area = ShellView.area(per: misura, dockNascosto: dockNascosto)
            ZStack(alignment: .topLeading) {
                // Un solo sfondo d'acqua, anche sotto la schermata di benvenuto: sempre in movimento, anche con le
                // app aperte e ingrandite; fermo solo con «Sfondo fermo», sotto la sala della presentazione e nelle istantanee
                Materiale.SfondoScrivania(animato: stato.dati.impostazioni.sfondoAnimato && !stato.scrivaniaCoperta && !modoIstantanea,
                                          intensita: stato.dati.impostazioni.pioggia.forza)

                // Con la schermata di benvenuto la scrivania si nasconde senza sparire: le app restano come sono.
                // Opacità livello per livello (mai sull'insieme) e una leggera scala sul contenitore
                livelliScrivania(misura, area: area)
                    .frame(width: misura.width, height: misura.height, alignment: .topLeading)
                    .scaleEffect(scalaScena)
                    .opacity(salaCoprente ? 0 : 1)
                    .allowsHitTesting(!sistema.bloccato)

                // Lo strato degli effetti (genio e chiusura in Core Animation, MotoreGenio): sopra finestre, dock e
                // pannelli, sotto la presentazione e il benvenuto. Mai nelle istantanee e nelle prove
                #if os(macOS)
                if !modoIstantanea {
                    StratoEffettiVista()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                #endif

                if let p = stato.presentazione {
                    VistaPresentazione(p: p)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(modoIstantanea ? AnyTransition.identity : AnyTransition.opacity)
                }

                if sistema.bloccato {
                    // L'uscita ha una curva sua: nelle istantanee e nelle prove la schermata se ne va di colpo
                    SchermataBenvenuto()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(modoIstantanea ? AnyTransition.identity : SchermataBenvenuto.transizione)
                }

                if fileSopra {
                    RoundedRectangle(cornerRadius: Tema.Raggio.scheda, style: .continuous)
                        .strokeBorder(Tema.Colore.Shell.rilascio,
                                      style: StrokeStyle(lineWidth: Tema.Misura.Shell.rilascioTratto, dash: Tema.Misura.Shell.rilascioTrattino))
                        .background(RoundedRectangle(cornerRadius: Tema.Raggio.scheda, style: .continuous).fill(Tema.Colore.Shell.rilascioFondo))
                        .padding(Misure.Avvisi.rilascioMargine)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                    VistaAvviso(testo: "Rilascia per importare: Excel o CSV di clienti e posizioni, vCard, PDF e foto di documenti.")
                        .frame(width: geo.size.width, height: geo.size.height - Misure.Avvisi.distanzaBasso, alignment: .bottom)
                        .allowsHitTesting(false)
                }

                if let testo = stato.avviso {
                    let posto = postoAvviso(misura: geo.size, area: area)
                    VistaAvviso(testo: testo, sfera: stato.avvisoDiEve)
                        .padding(.horizontal, Misure.Avvisi.margineLato)
                        .frame(width: posto.width, height: posto.height, alignment: .bottom)
                        .offset(x: posto.minX, y: posto.minY)
                        .transition(transizioneAvviso)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: ShellView.spazioShell)
            .onDrop(of: [.fileURL], isTargeted: Binding(get: { fileSopra }, set: { fileSopra = $0 && puoRicevereFile })) { fornitori in
                guard puoRicevereFile else { return false }
                raccogliURL(fornitori) { stato.importaFileTrascinati($0) }
                return true
            }
            .onAppear { aggiornaArea(geo.size) }
            // La dimensione nuova, non l'area calcolata nel disegno precedente (durante la presentazione, quella congelata)
            .onChange(of: geo.size) { aggiornaArea(misuraCongelata ?? $0) }
            .onChange(of: dockNascosto) { nascosto in
                aggiornaArea(misuraCongelata ?? geo.size)
                if !nascosto {
                    annullaNascondiDock()
                    if dockRichiamato { dockRichiamato = false }
                }
            }
            .onChange(of: stato.presentazione != nil) { attiva in
                guard !modoIstantanea else { return }
                if attiva {
                    misuraCongelata = geo.size
                    // A dissolvenza finita la sala copre tutto: la scrivania sotto smette di disegnarsi
                    Movimenti.dopo(Tema.Moto.Pannelli.durataPresentazione) {
                        if stato.presentazione != nil { salaCoprente = true }
                    }
                } else {
                    // All'uscita la scrivania c'è già, di colpo, sotto la sala che svanisce
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        salaCoprente = false
                        misuraCongelata = nil
                    }
                    aggiornaArea(geo.size)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 1100, minHeight: 720)
        .ignoresSafeArea()
        .background {
            if !modoIstantanea { ConfiguraFinestra() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            stato.schermoIntero = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            stato.schermoIntero = false
        }
        // Aspetto scelto in Impostazioni (Automatico = segue il Mac). Si cambia l'aspetto dell'app e non
        // preferredColorScheme, che su macOS non torna bene ad «Automatico». All'avvio lo applica StatoShell.init
        .onChange(of: stato.dati.impostazioni.aspetto) { aspetto in
            if !modoIstantanea { PrismaApp.applicaAspetto(aspetto) }
        }
        #elseif os(iOS)
        // Su iPhone e iPad niente misura minima della finestra né tutto schermo da seguire;
        // l'aspetto lo dà `.preferredColorScheme` della radice (StatoMobile)
        .ignoresSafeArea()
        #endif
    }

    /// Scala del contenitore della scrivania con il benvenuto: al blocco si allontana appena (0,98), a blocco
    /// finito aspetta un po' più grande (1,03) e allo sblocco arriva da lì. Mai nelle istantanee, mai con «Riduci movimento».
    private var scalaScena: CGFloat {
        guard sistema.bloccato, !modoIstantanea, !Movimenti.calmo else { return 1 }
        return sistema.bloccatoStabile ? Tema.Moto.Sblocco.scalaScrivania : Tema.Moto.Blocco.scalaScrivania
    }

    /// Scrivania, finestre, dock, pannelli e barra superiore, nell'ordine in cui si sovrappongono.
    private func livelliScrivania(_ misura: CGSize, area: CGRect) -> some View {
        let nascosti = sistema.bloccato
        // Durante un genio il dock si vede sempre (come macOS con il dock nascosto): la finestra va nella sua icona
        let dockGiu = dockNascosto && !dockRichiamato && sistema.dockPerEffetti.isEmpty
        return ZStack(alignment: .topLeading) {
            Scrivania()
                .frame(width: misura.width, height: max(0, misura.height - Misure.Barra.altezza - Misure.Dock.riservato))
                .offset(y: Misure.Barra.altezza)
                // Sotto una finestra ingrandita, a transizione finita, la scrivania non si disegna (resta montata)
                .opacity(nascosti || sistema.scrivaniaNascosta ? 0 : 1)
                .allowsHitTesting(!sistema.scrivaniaNascosta)

            livelloFinestre(area: area, misura: misura)
                .opacity(nascosti ? 0 : 1)

            if dockGiu {
                // Striscia invisibile sul bordo in basso: richiama il dock
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: misura.width, height: Misure.Dock.strisciaRichiamo)
                    .offset(y: misura.height - Misure.Dock.strisciaRichiamo)
                    .onHover { if $0 { richiamaDock() } }
            }

            Dock()
                .onHover { sopra in
                    if sopra { annullaNascondiDock() } else if dockRichiamato { nascondiDockTraPoco() }
                }
                .padding(.bottom, Tema.Misura.dockDalBasso)
                .offset(y: dockGiu ? Misure.Dock.corsaNascosto : 0)
                // Il dock scende e risale da solo (e con la prima finestra che si apre), come l'autohide del Mac
                .animation(modoIstantanea ? nil : Movimenti.curva(dockGiu ? Tema.Moto.Dock.nascondi : Tema.Moto.Dock.mostra),
                           value: dockGiu)
                .frame(width: misura.width, height: misura.height, alignment: .bottom)
                .clipped()
                .opacity(nascosti ? 0 : 1)

            // I pannelli in contenitori animati: l'animazione resta loro e non tocca il resto della shell
            ZStack {
                if sistema.pannelloSpazi {
                    PannelloSpazi()
                        .frame(width: misura.width, height: misura.height)
                        .transition(transizionePannello)
                }
            }
            .animation(curvaPannello(sistema.pannelloSpazi, Tema.Moto.Pannelli.spazi, Tema.Moto.Pannelli.spaziUscita),
                       value: sistema.pannelloSpazi)
            .opacity(nascosti ? 0 : 1)

            ZStack {
                if sistema.pannelloNotifiche {
                    PannelloNotifiche()
                        .frame(width: misura.width, height: misura.height)
                        .transition(transizionePannello)
                }
            }
            .animation(curvaPannello(sistema.pannelloNotifiche, Tema.Moto.Pannelli.notifiche, Tema.Moto.Pannelli.notificheUscita),
                       value: sistema.pannelloNotifiche)
            .opacity(nascosti ? 0 : 1)

            BarraSuperiore()
                .opacity(nascosti ? 0 : 1)

            ZStack {
                if sistema.pannelloAppAperte {
                    PannelloAppAperte()
                        .frame(width: misura.width, height: misura.height)
                        .transition(transizionePannello)
                }
            }
            .animation(curvaPannello(sistema.pannelloAppAperte, Tema.Moto.Pannelli.appAperte, Tema.Moto.Pannelli.appAperteUscita),
                       value: sistema.pannelloAppAperte)
            .opacity(nascosti ? 0 : 1)

            // Ricerca ⌘K come Spotlight: in alto al centro, sopra tutto (anche sopra la barra superiore)
            ZStack {
                if sistema.pannelloRicerca {
                    RicercaSpotlight()
                        .frame(width: misura.width, height: misura.height)
                        .transition(transizionePannello)
                }
            }
            .animation(curvaPannello(sistema.pannelloRicerca, Tema.Moto.Spotlight.entrata, Tema.Moto.Spotlight.uscita),
                       value: sistema.pannelloRicerca)
            .opacity(nascosti ? 0 : 1)

            // La guida di Prisma: sopra tutto, come «Le tue app aperte». Cambiare pagina non anima il contenitore
            ZStack {
                if sistema.guida != nil {
                    PannelloGuida()
                        .frame(width: misura.width, height: misura.height)
                        .transition(transizionePannello)
                }
            }
            .animation(curvaPannello(sistema.guida != nil, Tema.Moto.Guida.entrata, Tema.Moto.Guida.uscita),
                       value: sistema.guida != nil)
            .opacity(nascosti ? 0 : 1)
        }
    }

    /// Velo e contenitore dei pannelli: solo opacità (la scheda dentro entra con la sua scala, `entrataScheda`).
    private var transizionePannello: AnyTransition { modoIstantanea ? AnyTransition.identity : AnyTransition.velo }

    private func curvaPannello(_ aperto: Bool, _ entrata: Animation, _ uscita: Animation) -> Animation? {
        modoIstantanea ? nil : Movimenti.curva(aperto ? entrata : uscita)
    }

    /// Dove si posa l'avviso (allineato in basso al centro del riquadro): sopra la barra di stato della finestra
    /// attiva, centrato su di essa, così non copre il contenuto; senza finestre aperte, sopra il dock.
    private func postoAvviso(misura: CGSize, area: CGRect) -> CGRect {
        let tutto = CGRect(x: 0, y: 0, width: misura.width, height: max(0, misura.height - Misure.Avvisi.distanzaBasso))
        guard let app = sistema.appAttiva, let f = sistema.elenco.first(where: { $0.app == app }), !f.ridotta else {
            return tutto
        }
        let c = stato.cornice(di: f, in: area)
        let sopra = Misure.Avvisi.distanzaBarraStato
        guard c.height > sopra else { return tutto }
        return CGRect(x: area.minX + c.minX, y: area.minY + c.minY, width: c.width, height: c.height - sopra)
    }

    /// L'avviso sale appena e cresce dal basso; esce in dissolvenza (tema :898).
    private var transizioneAvviso: AnyTransition {
        guard !modoIstantanea else { return .identity }
        let m = Tema.Moto.Pannelli.self
        let entrata: AnyTransition = Movimenti.calmo ? .opacity
            : AnyTransition.opacity.combined(with: .offset(y: m.avvisoSpostamento)).combined(with: .scale(scale: m.avvisoScala, anchor: .bottom))
        return .asymmetric(insertion: entrata.animation(Movimenti.curva(m.avviso)),
                           removal: AnyTransition.opacity.animation(Movimenti.curva(m.avvisoUscita)))
    }

    // MARK: Dock nascosto

    private func richiamaDock() {
        annullaNascondiDock()
        if !dockRichiamato { dockRichiamato = true }
    }

    private func annullaNascondiDock() {
        attesaDock.lavoro?.cancel()
        attesaDock.lavoro = nil
    }

    /// Il puntatore ha lasciato il dock richiamato: si nasconde dopo un attimo, se non torna.
    private func nascondiDockTraPoco() {
        annullaNascondiDock()
        let lavoro = DispatchWorkItem { dockRichiamato = false }
        attesaDock.lavoro = lavoro
        DispatchQueue.main.asyncAfter(deadline: .now() + Tema.Moto.Dock.ritardoNascondi, execute: lavoro)
    }

    /// Niente importazioni a schermo bloccato, in modalità cliente o in sola lettura.
    private var puoRicevereFile: Bool { !sistema.bloccato && !stato.inModoCliente && !stato.solaLettura && stato.presentazione == nil }

    /// Gli indirizzi dei file trascinati, tutti insieme, sul thread principale.
    private func raccogliURL(_ fornitori: [NSItemProvider], poi: @escaping ([URL]) -> Void) {
        let gruppo = DispatchGroup()
        let coda = DispatchQueue(label: "prisma.rilascio")
        var urls: [URL] = []
        for f in fornitori {
            gruppo.enter()
            _ = f.loadObject(ofClass: URL.self) { url, _ in
                coda.async {
                    if let url { urls.append(url) }
                    gruppo.leave()
                }
            }
        }
        gruppo.notify(queue: .main) { if !urls.isEmpty { poi(urls) } }
    }

    private func aggiornaArea(_ dimensione: CGSize) {
        // Non pubblicata: serve a sapere dov'è l'icona di un'app nel dock
        sistema.misura = dimensione
        let nuova = ShellView.area(per: dimensione, dockNascosto: dockNascosto)
        if stato.area != nuova { stato.area = nuova }
    }

    // MARK: Finestre

    /// Le finestre in un ordine fisso (quello delle app): l'ordine davanti-dietro lo dà `zIndex`, così portare
    /// un'app davanti non sposta le viste e non interrompe un gesto in corso.
    private static func inOrdineFisso(_ elenco: [StatoShell.Finestra]) -> [StatoShell.Finestra] {
        let ordine = AppPrisma.allCases
        return elenco.sorted { (ordine.firstIndex(of: $0.app) ?? 0) < (ordine.firstIndex(of: $1.app) ?? 0) }
    }

    private func livelloFinestre(area: CGRect, misura: CGSize) -> some View {
        let elenco = sistema.elenco
        let attiva = sistema.appAttiva
        // Le finestre ridotte tengono la cornice che avevano (con il dock nascosto): ridurre l'ultima non le reimpagina
        let areaRidotte = ShellView.area(per: misura, dockNascosto: true)
        let calmo = !modoIstantanea && Movimenti.calmo
        return ZStack(alignment: .topLeading) {
            ForEach(CorpoShell.inOrdineFisso(elenco)) { f in
                finestra(f, z: elenco.firstIndex(where: { $0.app == f.app }) ?? 0, attiva: f.app == attiva,
                         area: f.ridotta ? areaRidotte : area, calmo: calmo)
            }
        }
        .frame(width: area.width, height: area.height, alignment: .topLeading)
        .coordinateSpace(name: ShellView.spazioFinestre)
        .offset(x: area.minX, y: area.minY)
    }

    /// Una finestra con i suoi movimenti, tutti trasformazioni e opacità sopra una cornice ferma:
    /// FLIP (ingrandisci, affianca, spazi), apertura (scala dall'icona), ripiego del genio, chiusura (transizione).
    /// Il genio vero e la chiusura con l'istantanea li fa MotoreGenio: intanto la finestra è `nascosta` (opacità 0,
    /// di colpo). Il contenuto dell'app non si rifà durante i movimenti: cambiano solo i valori dei modificatori.
    private func finestra(_ f: StatoShell.Finestra, z: Int, attiva: Bool, area: CGRect, calmo: Bool) -> some View {
        let c = stato.cornice(di: f, in: area)
        let w = max(c.width, 1)
        let h = max(c.height, 1)
        let origine = sistema.origini[f.app]
        // L'icona del dock (per il ripiego del genio), nelle coordinate della finestra; senza, il bordo in basso della shell
        let bersaglio = origine.map { p in
            CGPoint(x: p.x - area.minX - c.minX, y: p.y - area.minY - c.minY)
        } ?? CGPoint(x: c.width / 2, y: sistema.misura.height - area.minY - c.minY)
        let arrivo = sistema.inArrivo.contains(f.app)
        let coperta = sistema.coperte.contains(f.app)
        let nascosta = sistema.nascoste.contains(f.app)
        let flip = sistema.flip[f.app]
        let genio: CGFloat = f.ridotta ? 1 : 0
        // L'apertura come macOS: dall'icona (o dal punto da cui si apre) cresce fino al suo posto; senza origine,
        // al suo posto, appena più piccola
        let ancoraArrivo = origine.map { p in
            UnitPoint(x: (p.x - area.minX - c.minX) / w, y: (p.y - area.minY - c.minY) / h)
        } ?? .center
        let scalaArrivo: CGFloat = calmo ? 1
            : (origine == nil ? Tema.Moto.Finestre.scalaAperturaSulPosto : Tema.Moto.Finestre.scalaApertura)
        // Il centro visibile della finestra (la transizione sta dopo lo spostamento)
        let centro = UnitPoint(x: c.midX / w, y: c.midY / h)
        // Chiusa dal motore (istantanea o di colpo): la finestra se ne va senza transizione
        let uscita: AnyTransition = modoIstantanea || nascosta ? AnyTransition.identity
            : AnyTransition.chiusuraFinestra(ancora: centro)
        return FinestraInterna(finestra: f, attiva: attiva, area: area)
            .frame(width: c.width, height: c.height, alignment: .topLeading)
            .modifier(EffettoCornice(progresso: flip?.progresso ?? 1, da: flip?.da ?? c, a: c))
            // Ripiego senza istantanea: solo una scala verso l'icona (con il motore la finestra è già nascosta)
            .modifier(RiduzioneSemplice(progresso: genio, ancora: bersaglio, calmo: calmo))
            .modifier(OpacitaGenio(progresso: genio, calmo: calmo))
            // L'opacità dell'apertura ha la sua curva breve (prima della scala: la sua animazione tocca solo lei)
            .modifier(OpacitaApertura(visibile: !arrivo))
            .modifier(EffettoFinestra(scala: arrivo ? scalaArrivo : 1, ancora: ancoraArrivo, y: 0, opacita: 1))
            .offset(x: c.minX, y: c.minY)
            // Coperta da una finestra ingrandita (a transizione finita): resta montata ma non si disegna.
            // Nascosta sotto la sua istantanea durante un effetto: di colpo, nessun fantasma
            .opacity(coperta || nascosta ? 0 : 1)
            .allowsHitTesting(!f.ridotta && !coperta && !nascosta)
            // Ridotta nel dock resta montata (si riapre subito), ma i suoi comandi da tastiera tacciono: a genio
            // finito (`spente`), perché spegnere i controlli ridisegna tutta l'app e non deve cadere nel movimento
            .disabled(f.ridotta && (modoIstantanea || sistema.spente.contains(f.app)))
            .accessibilityHidden(f.ridotta || coperta)
            .zIndex(Double(z))
            .transition(uscita)
    }
}

/// Il lavoro che nasconde di nuovo il dock richiamato. Una classe: cambiarlo non è un cambio di stato della vista.
private final class AttesaDock {
    var lavoro: DispatchWorkItem?
}

#if os(macOS)
/// Imposta la finestra macOS: barra del titolo trasparente, fondo del colore del cielo (chiaro o scuro), dimensione minima.
struct ConfiguraFinestra: NSViewRepresentable {
    final class Vista: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let w = window else { return }
            w.title = "Prisma"
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = false
            w.backgroundColor = Tema.Colore.Shell.fondoFinestraMac
            w.minSize = NSSize(width: 1100, height: 720)
            w.collectionBehavior.insert(.fullScreenPrimary)
        }
    }

    func makeNSView(context: Context) -> Vista { Vista() }
    func updateNSView(_ nsView: Vista, context: Context) {}
}
#endif
