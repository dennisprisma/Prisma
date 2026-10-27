import SwiftUI
import AppKit

// App Note nel tema Liquid Glass: l'indice delle note a sinistra sul vetro della barra laterale,
// la nota su una scheda chiara con righe appena accennate, i pulsanti in capsula di vetro.

extension Colori {
    enum Note {
        // Fondo dell'app: il vetro della finestra
        static let fondoAlto = Color.clear
        static let fondoBasso = Color.clear
        static let taccuinoBordo = Tema.Colore.bordoScheda
        static let taccuinoOmbra1 = Color.clear
        static let taccuinoOmbra2 = Color.clear
        static let taccuinoOmbra3 = Color.clear
        static let taccuinoOmbra4 = Color(r: 8, g: 40, b: 60, a: 0.1)
        // Testate (erano la rilegatura in cuoio)
        static let cuoioAlto = Color.clear
        static let cuoioMezzo = Color.clear
        static let cuoioBasso = Color.clear
        static let cuoioBordo = Tema.Colore.separatore
        static let cuoioLuce = Color.clear
        static let cuoioTesto = Tema.Colore.inchiostro
        static let cuoioIncisione = Color.clear
        static let cucitura = Color.clear
        static let cucituraOmbra = Color.clear
        static let contatore = Tema.Colore.pozzetto
        static let contatoreBordo = Color.clear
        static let stato = Tema.Colore.inchiostroSecondario
        static let statoModificato = Tema.Colore.testoProposta
        // Pulsanti (capsule di vetro)
        static let pulsanteAlto = Tema.Colore.chip
        static let pulsanteMezzoAlto = Tema.Colore.chip
        static let pulsanteMezzoBasso = Tema.Colore.chip
        static let pulsanteBasso = Tema.Colore.chip
        static let pulsanteBordo = Tema.Colore.bordoChip
        static let pulsanteTesto = Tema.Colore.inchiostro
        static let pulsanteFissato = Tema.Colore.testoProposta
        // Indice
        static let indiceSinistra = Tema.Colore.laterale
        static let indiceCentro = Tema.Colore.laterale
        static let indiceDestra = Tema.Colore.laterale
        static let indiceBordo = Tema.Colore.separatore
        static let campo = Tema.Colore.pozzetto
        static let campoBordo = Tema.Colore.separatore
        static let voceTesto = Tema.Colore.inchiostro
        static let voceSecondario = Tema.Colore.inchiostroSecondario
        static let voceBordo = Tema.Colore.separatore
        static let voceLuce = Color.clear
        static let voceFondo = Color.clear
        static let selezioneAlto = Tema.Colore.selezione
        static let selezioneBasso = Tema.Colore.selezione
        static let selezioneTesto = Tema.Colore.inchiostro
        static let selezioneLuce = Color.clear
        static let selezioneBordo = Color.clear
        static let fissata = Tema.Colore.arancio
        static let piedeIndice = Tema.Colore.inchiostroTerziario
        static let piedeIndiceBordo = Tema.Colore.separatore
        // Pagina
        static let paginaSinistra = Tema.Colore.scheda
        static let paginaChiara = Tema.Colore.scheda
        static let paginaCentro = Tema.Colore.scheda
        static let paginaDestra = Tema.Colore.scheda
        static let paginaOmbra = Color.clear
        static let margine1 = Color(r: 255, g: 59, b: 48, a: 0.22)
        static let margine2 = Color(r: 255, g: 59, b: 48, a: 0.14)
        static let righe = Tema.Colore.separatore
        static let lineaCliente = Tema.Colore.separatore
        static let etichetta = Tema.Colore.inchiostroSecondario
        static let collegamento = Tema.Colore.link
        static let titolo = Tema.Colore.inchiostro
        static let testo = Tema.Colore.inchiostro
        static let segnaposto = Tema.Colore.inchiostroTerziario
        static let azioniAlto = Color.clear
        static let azioniBasso = Color.clear
        static let azioniBordo = Tema.Colore.separatore
        static let vuotoIcona = Tema.Colore.inchiostroTerziario
        static let vuotoTitolo = Tema.Colore.inchiostroSecondario
        static let vuotoTesto = Tema.Colore.inchiostroTerziario
    }
}

extension Gradienti {
    static let fondoNote = LinearGradient.verticale(Colori.Note.fondoAlto, Colori.Note.fondoBasso)
    static let cuoioNote = LinearGradient.verticale([(Colori.Note.cuoioAlto, 0), (Colori.Note.cuoioMezzo, 0.55), (Colori.Note.cuoioBasso, 1)])
    static let pulsanteNote = LinearGradient.verticale([
        (Colori.Note.pulsanteAlto, 0), (Colori.Note.pulsanteMezzoAlto, 0.49), (Colori.Note.pulsanteMezzoBasso, 0.5), (Colori.Note.pulsanteBasso, 1),
    ])
    static let indiceNote = LinearGradient(stops: [
        .init(color: Colori.Note.indiceSinistra, location: 0), .init(color: Colori.Note.indiceCentro, location: 0.93),
        .init(color: Colori.Note.indiceDestra, location: 1),
    ], startPoint: .leading, endPoint: .trailing)
    static let selezioneNote = LinearGradient.verticale(Colori.Note.selezioneAlto, Colori.Note.selezioneBasso)
    static let paginaNote = LinearGradient(stops: [
        .init(color: Colori.Note.paginaSinistra, location: 0), .init(color: Colori.Note.paginaChiara, location: 0.02),
        .init(color: Colori.Note.paginaCentro, location: 0.92), .init(color: Colori.Note.paginaDestra, location: 1),
    ], startPoint: .leading, endPoint: .trailing)
    static let azioniNote = LinearGradient.verticale(Colori.Note.azioniAlto, Colori.Note.azioniBasso)
}

extension Misure {
    enum Note {
        static let indice: CGFloat = 235
        static let raggio: CGFloat = Tema.Raggio.scheda
        static let etichetta = EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16)
        static let barra = EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
        static let campoAltezza: CGFloat = 30
        static let voce = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        static let carta = EdgeInsets(top: 15, leading: 45, bottom: 12, trailing: 29)
        static let margine: CGFloat = 32
        /// Corpo del testo della nota (15, come nel tema) e passo delle righe (15 × 1,6).
        static let corpoTesto: CGFloat = 15
        static let riga: CGFloat = 24
        /// Altezza di una riga di testo nel carattere della nota come la misura l'editor (NSLayoutManager):
        /// con l'interlinea ogni riga è alta `riga` e il testo resta sulle righe della pagina.
        static let altezzaTesto: CGFloat = {
            let f = NSFont.systemFont(ofSize: Misure.Note.corpoTesto)
            return NSLayoutManager().defaultLineHeight(for: f)
        }()
        static let interlinea: CGFloat = max(0, riga - altezzaTesto)
        /// La prima riga della pagina, appena sotto la prima riga di testo.
        static let primaRiga: CGFloat = altezzaTesto + 2
        static let azioni = EdgeInsets(top: 10, leading: 26, bottom: 10, trailing: 20)
        static let avatar: CGFloat = 24
        static let minimaPagina: CGFloat = 340
        /// Pulsanti in capsula della barra della pagina.
        static let pulsante = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
    }
}

extension Tipo {
    static let noteEtichetta = Tema.Testo.sf(12, .semibold)
    static let noteContatore = Tema.Testo.sf(11, .semibold)
    static let noteVoceTitolo = Tema.Testo.sf(13, .semibold)
    static let noteVoceTesto = Tema.Testo.sf(12)
    static let noteVoceData = Tema.Testo.sf(11.5)
    static let notePiede = Tema.Testo.sf(11.5)
    static let noteStato = Tema.Testo.sf(11.5)
    static let notePulsante = Tema.Testo.sf(12.5, .medium)
    static let notePer = Tema.Testo.sf(10.5, .semibold)
    static let noteCliente = Tema.Testo.sf(12, .semibold)
    static let noteCollegamento = Tema.Testo.sf(12)
    static let noteTitolo = Tema.Testo.titoloNota
    /// Il testo della nota: corpo fisso, perché le righe della pagina si contano su questo carattere.
    static let noteTesto = Font.system(size: Misure.Note.corpoTesto)
    static let notePiedePagina = Tema.Testo.sf(11, .medium)
    static let noteDidascalia = Tema.Testo.sf(11.5)
    static let noteVuotoIcona = Tema.Testo.sf(50)
    static let noteVuotoTitolo = Tema.Testo.sf(19, .bold)
    static let noteVuotoTesto = Tema.Testo.sf(13)
}

/// Pulsante della barra della pagina: capsula di vetro (.btn); `evidenziato` (nota fissata) in ambra.
struct StileCuoioNote: ButtonStyle {
    var evidenziato = false

    func makeBody(configuration: Configuration) -> some View {
        CorpoPulsante(etichetta: configuration.label
                        .font(Tipo.notePulsante)
                        .foregroundColor(evidenziato ? Colori.Note.pulsanteFissato : Colori.Note.pulsanteTesto),
                      aspetto: .vetro, premuto: configuration.isPressed, margine: Misure.Note.pulsante)
    }
}

/// Testata dell'indice e della pagina (era la rilegatura in cuoio): trasparente sul vetro, filo sotto.
struct CuoioNote: View {
    var body: some View {
        Color.clear
            .overlay(alignment: .bottom) {
                Rectangle().fill(Colori.Note.cuoioBordo).frame(height: Tema.Misura.filo)
            }
    }
}

/// Le righe orizzontali della pagina, ogni `Misure.Note.riga` punti. `scorrimento` è quanto il
/// testo è salito nell'editor: le righe salgono con lui e restano sotto le parole.
struct RigheNote: Shape {
    var inizio: CGFloat = Misure.Note.primaRiga
    var scorrimento: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y = rect.minY + inizio - scorrimento
        if y < rect.minY { y += ceil((rect.minY - y) / Misure.Note.riga) * Misure.Note.riga }
        while y < rect.maxY {
            p.addRect(CGRect(x: rect.minX, y: y, width: rect.width, height: 1))
            y += Misure.Note.riga
        }
        return p
    }
}

/// Il margine rosso a sinistra della pagina (due linee sottili).
struct MargineNote: View {
    var body: some View {
        HStack(spacing: 1) {
            Rectangle().fill(Colori.Note.margine1).frame(width: 1)
            Rectangle().fill(Colori.Note.margine2).frame(width: 1)
        }
        .frame(maxHeight: .infinity)
    }
}

/// Legge di quanto è scorso il testo dell'editor che ha accanto (il TextEditor di SwiftUI non lo
/// dice): cerca la vista di testo AppKit che sta sotto di sé e ne segue lo scorrimento.
struct ScorrimentoEditor: NSViewRepresentable {
    @Binding var scorrimento: CGFloat

    func makeCoordinator() -> Osservatore { Osservatore() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        context.coordinator.aggiorna = { y in if abs(scorrimento - y) > 0.5 { scorrimento = y } }
        DispatchQueue.main.async { context.coordinator.aggancia(da: v) }
        return v
    }

    func updateNSView(_ v: NSView, context: Context) {
        context.coordinator.aggiorna = { y in if abs(scorrimento - y) > 0.5 { scorrimento = y } }
        if context.coordinator.clip == nil { DispatchQueue.main.async { context.coordinator.aggancia(da: v) } }
    }

    static func dismantleNSView(_ v: NSView, coordinator: Osservatore) { coordinator.stacca() }

    final class Osservatore {
        var aggiorna: (CGFloat) -> Void = { _ in }
        weak var clip: NSClipView?
        private var token: NSObjectProtocol?

        /// La vista di testo il cui riquadro contiene il centro del segnaposto, salendo di qualche livello.
        func aggancia(da segno: NSView) {
            guard clip == nil, let finestra = segno.window else { return }
            let centro = segno.convert(NSPoint(x: segno.bounds.midX, y: segno.bounds.midY), to: nil)
            var livello: NSView? = segno.superview
            for _ in 0..<6 {
                guard let l = livello else { break }
                if let s = Self.cerca(in: l, centro: centro), s.window === finestra {
                    let c = s.contentView
                    c.postsBoundsChangedNotifications = true
                    clip = c
                    token = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: c, queue: .main) { [weak self] _ in
                        guard let self, let c = self.clip else { return }
                        self.aggiorna(c.bounds.origin.y)
                    }
                    aggiorna(c.bounds.origin.y)
                    return
                }
                livello = l.superview
            }
        }

        private static func cerca(in vista: NSView, centro: NSPoint) -> NSScrollView? {
            for v in vista.subviews {
                if let s = v as? NSScrollView, s.documentView is NSTextView,
                   s.convert(s.bounds, to: nil).contains(centro) { return s }
                if let s = cerca(in: v, centro: centro) { return s }
            }
            return nil
        }

        func stacca() {
            if let token { NotificationCenter.default.removeObserver(token) }
            token = nil
        }

        deinit { stacca() }
    }
}
