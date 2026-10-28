import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// L'unica finestra di Prisma: sfondo, scrivania, finestre interne, dock e barra superiore.
struct ShellView: View {
    static let spazioFinestre = "areaFinestre"

    @EnvironmentObject var stato: StatoShell
    @Environment(\.modoIstantanea) var modoIstantanea
    /// Il puntatore è sul dock (o sul bordo in basso) mentre è nascosto: si mostra sopra le finestre.
    @State private var dockRichiamato = false
    /// Un file trascinato sopra Prisma: si mostra dove va.
    @State private var fileSopra = false

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

    /// Con una finestra aperta il dock si nasconde, come in macOS: torna portando il puntatore in basso.
    private var dockNascosto: Bool { !stato.finestreVisibili.isEmpty }

    var body: some View {
        GeometryReader { geo in
            let area = ShellView.area(per: geo.size, dockNascosto: dockNascosto)
            ZStack(alignment: .topLeading) {
                // Un solo sfondo d'acqua, anche sotto la schermata di benvenuto: si muove solo se si vede
                Materiale.SfondoScrivania(animato: stato.dati.impostazioni.sfondoAnimato && !stato.scrivaniaCoperta && !modoIstantanea)

                // Con la schermata di benvenuto la scrivania si nasconde senza sparire: le app restano come sono
                livelliScrivania(geo.size, area: area)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .opacity(stato.bloccato ? 0 : 1)
                    .allowsHitTesting(!stato.bloccato)

                if let p = stato.presentazione {
                    VistaPresentazione(p: p)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(.opacity)
                }

                if stato.bloccato {
                    SchermataBenvenuto()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(.opacity)
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
                    VistaAvviso(testo: testo)
                        .frame(width: geo.size.width, height: geo.size.height - Misure.Avvisi.distanzaBasso, alignment: .bottom)
                        .transition(.opacity.combined(with: .offset(y: 15)))
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: Binding(get: { fileSopra }, set: { fileSopra = $0 && puoRicevereFile })) { fornitori in
                guard puoRicevereFile else { return false }
                raccogliURL(fornitori) { stato.importaFileTrascinati($0) }
                return true
            }
            .onAppear { aggiornaArea(geo.size) }
            // La dimensione nuova, non l'area calcolata nel disegno precedente
            .onChange(of: geo.size) { aggiornaArea($0) }
            .onChange(of: dockNascosto) { nascosto in
                aggiornaArea(geo.size)
                if !nascosto { dockRichiamato = false }
            }
        }
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
    }

    /// Scrivania, finestre, dock, pannelli e barra superiore, nell'ordine in cui si sovrappongono.
    private func livelliScrivania(_ misura: CGSize, area: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Scrivania()
                .frame(width: misura.width, height: max(0, misura.height - Misure.Barra.altezza - Misure.Dock.riservato))
                .offset(y: Misure.Barra.altezza)

            livelloFinestre(area: area)

            if dockNascosto && !dockRichiamato {
                // Striscia invisibile sul bordo in basso: richiama il dock
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: misura.width, height: Misure.Dock.strisciaRichiamo)
                    .offset(y: misura.height - Misure.Dock.strisciaRichiamo)
                    .onHover { if $0 { withAnimation(Animazioni.passaggio) { dockRichiamato = true } } }
            }

            Dock()
                .onHover { sopra in
                    if !sopra { withAnimation(Animazioni.passaggio) { dockRichiamato = false } }
                }
                .padding(.bottom, Tema.Misura.dockDalBasso)
                .offset(y: dockNascosto && !dockRichiamato ? Misure.Dock.corsaNascosto : 0)
                .frame(width: misura.width, height: misura.height, alignment: .bottom)
                .clipped()

            if stato.pannelloSpazi {
                PannelloSpazi()
                    .frame(width: misura.width, height: misura.height)
                    .transition(.opacity)
            }

            if stato.pannelloNotifiche {
                PannelloNotifiche()
                    .frame(width: misura.width, height: misura.height)
                    .transition(.opacity.combined(with: .offset(x: 12)))
            }

            BarraSuperiore()

            if stato.pannelloAppAperte {
                PannelloAppAperte()
                    .frame(width: misura.width, height: misura.height)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }

    /// Niente importazioni a schermo bloccato, in modalità cliente o in sola lettura.
    private var puoRicevereFile: Bool { !stato.bloccato && !stato.inModoCliente && !stato.solaLettura && stato.presentazione == nil }

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
        let nuova = ShellView.area(per: dimensione, dockNascosto: dockNascosto)
        if stato.area != nuova { stato.area = nuova }
    }

    private func livelloFinestre(area: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            let visibili = stato.finestreVisibili
            ForEach(visibili) { f in
                let c = stato.cornice(di: f, in: area)
                FinestraInterna(finestra: f, attiva: f.app == visibili.last?.app)
                    .frame(width: c.width, height: c.height)
                    .offset(x: c.minX, y: c.minY)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .offset(y: 12)),
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    ))
            }
        }
        .frame(width: area.width, height: area.height, alignment: .topLeading)
        .coordinateSpace(name: ShellView.spazioFinestre)
        .offset(x: area.minX, y: area.minY)
    }
}

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
