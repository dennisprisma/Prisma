import SwiftUI
import AppKit

// App Note (.os-app-notes del template): il blocco giallo di iOS con la rilegatura in cuoio
// cucito, l'indice delle note a sinistra e la pagina a righe con il margine rosso.

extension Colori {
    enum Note {
        static let fondoAlto = Color(hex: "#e5e1d8")
        static let fondoBasso = Color(hex: "#d6d1c6")
        static let taccuinoBordo = Color(hex: "#4c3320")
        static let taccuinoOmbra1 = Color(hex: "#f7e8ba")
        static let taccuinoOmbra2 = Color(hex: "#b4a070")
        static let taccuinoOmbra3 = Color(hex: "#806d46")
        static let taccuinoOmbra4 = Color(r: 57, g: 38, b: 13, a: 0.34)
        // Rilegatura (--ios5-binding)
        static let cuoioAlto = Color(hex: "#765842")
        static let cuoioMezzo = Color(hex: "#5b3c2b")
        static let cuoioBasso = Color(hex: "#422919")
        static let cuoioBordo = Color(hex: "#382316")
        static let cuoioLuce = Color(hex: "#b89777")
        static let cuoioTesto = Color(hex: "#f1dfbe")
        static let cuoioIncisione = Color(hex: "#2b190c")
        static let cucitura = Color(hex: "#d6b286")
        static let cucituraOmbra = Color(hex: "#281606")
        static let contatore = Color(r: 93, g: 66, b: 42, a: 0.47)
        static let contatoreBordo = Color(r: 77, g: 53, b: 31, a: 0.54)
        static let stato = Color(hex: "#e0ccaa")
        static let statoModificato = Color(hex: "#ffe89f")
        // Pulsanti in cuoio scuro (--ios5-button-bg)
        static let pulsanteAlto = Color(hex: "#947253")
        static let pulsanteMezzoAlto = Color(hex: "#725039")
        static let pulsanteMezzoBasso = Color(hex: "#583a27")
        static let pulsanteBasso = Color(hex: "#78543a")
        static let pulsanteBordo = Color(hex: "#342116")
        static let pulsanteTesto = Color(hex: "#f6e7cb")
        static let pulsanteFissato = Color(hex: "#ffd982")
        // Indice
        static let indiceSinistra = Color(hex: "#eed99a")
        static let indiceCentro = Color(hex: "#fff0b6")
        static let indiceDestra = Color(hex: "#b9a46d")
        static let indiceBordo = Color(hex: "#a48b51")
        static let campo = Color(hex: "#fff9df")
        static let campoBordo = Color(hex: "#d7c794")
        static let voceTesto = Color(hex: "#463b26")
        static let voceSecondario = Color(hex: "#776443")
        static let voceBordo = Color(r: 199, g: 175, b: 112, a: 0.5)
        static let voceLuce = Color(r: 255, g: 255, b: 255, a: 0.6)
        static let voceFondo = Color(r: 255, g: 243, b: 182, a: 0.1)
        static let selezioneAlto = Color(hex: "#f3d87c")
        static let selezioneBasso = Color(hex: "#e6bd4b")
        static let selezioneTesto = Color(hex: "#463215")
        static let selezioneLuce = Color(hex: "#fff0b5")
        static let selezioneBordo = Color(hex: "#b58c29")
        static let fissata = Color(hex: "#b48a37")
        static let piedeIndice = Color(hex: "#927943")
        static let piedeIndiceBordo = Color(hex: "#c6b277")
        // Pagina
        static let paginaSinistra = Color(r: 200, g: 170, b: 92, a: 0.4)
        static let paginaChiara = Color(hex: "#fff3b7")
        static let paginaCentro = Color(hex: "#fff5c4")
        static let paginaDestra = Color(hex: "#eee0a6")
        static let paginaOmbra = Color(r: 114, g: 86, b: 23, a: 0.35)
        static let margine1 = Color(r: 206, g: 114, b: 112, a: 0.38)
        static let margine2 = Color(r: 206, g: 114, b: 112, a: 0.3)
        static let righe = Color(r: 135, g: 156, b: 156, a: 0.31)
        static let lineaCliente = Color(hex: "#c9b36d")
        static let etichetta = Color(hex: "#806b36")
        static let collegamento = Color(hex: "#655127")
        static let titolo = Color(hex: "#302717")
        static let testo = Color(hex: "#443420")
        static let segnaposto = Color(hex: "#b4a064")
        static let azioniAlto = Color(hex: "#f8eabe")
        static let azioniBasso = Color(hex: "#e6d18c")
        static let azioniBordo = Color(hex: "#bba160")
        static let vuotoIcona = Color(hex: "#c9b474")
        static let vuotoTitolo = Color(hex: "#ab9456")
        static let vuotoTesto = Color(hex: "#baa76e")
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
        static let raggio: CGFloat = 5
        static let etichetta = EdgeInsets(top: 17, leading: 18, bottom: 16, trailing: 18)
        static let barra = EdgeInsets(top: 12, leading: 20, bottom: 14, trailing: 20)
        static let campoAltezza: CGFloat = 30
        static let voce = EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)
        static let carta = EdgeInsets(top: 15, leading: 45, bottom: 12, trailing: 29)
        static let margine: CGFloat = 32
        static let riga: CGFloat = 30
        /// Altezza di una riga di testo in Noteworthy 16: con l'interlinea ogni riga è alta `riga`.
        static let altezzaTesto: CGFloat = {
            let f = NSFont(name: "Noteworthy-Light", size: 16) ?? .systemFont(ofSize: 16)
            return ceil(f.ascender - f.descender + f.leading)
        }()
        static let interlinea: CGFloat = max(0, riga - altezzaTesto)
        /// La prima riga della pagina, appena sotto la prima riga di testo.
        static let primaRiga: CGFloat = altezzaTesto + 2
        static let azioni = EdgeInsets(top: 12, leading: 26, bottom: 13, trailing: 20)
        static let avatar: CGFloat = 27
        static let minimaPagina: CGFloat = 340
    }
}

extension Tipo {
    static let noteEtichetta = Tipo.sistema(12, .bold)
    static let noteContatore = Tipo.sistema(10, .bold)
    static let noteVoceTitolo = Tipo.sistema(14, .bold)
    static let noteVoceTesto = Tipo.sistema(11)
    static let noteVoceData = Tipo.sistema(9)
    static let notePiede = Tipo.sistema(10)
    static let noteStato = Tipo.sistema(10)
    static let notePulsante = Tipo.sistema(11, .semibold)
    static let notePer = Tipo.sistema(8, .medium)
    static let noteCliente = Tipo.sistema(11, .semibold)
    static let noteCollegamento = Tipo.sistema(10)
    static let noteTitolo = Font.custom("Noteworthy-Bold", fixedSize: 26)
    static let noteTesto = Font.custom("Noteworthy-Light", fixedSize: 16)
    static let notePiedePagina = Tipo.sistema(8, .medium)
    static let noteDidascalia = Tipo.sistema(9)
    static let noteVuotoIcona = Tipo.sistema(50)
    static let noteVuotoTitolo = Font.custom("Georgia", fixedSize: 25)
    static let noteVuotoTesto = Tipo.sistema(12)
}

/// Pulsante in cuoio scuro della barra della pagina (.notes-sheet-toolbar .os-btn).
struct StileCuoioNote: ButtonStyle {
    var evidenziato = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tipo.notePulsante)
            .foregroundColor(evidenziato ? Colori.Note.pulsanteFissato : Colori.Note.pulsanteTesto)
            .incisione(Colori.Note.cuoioIncisione, y: -1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: Misure.Pulsante.raggio).fill(Gradienti.pulsanteNote))
            .luceInterna(Colori.Note.cuoioLuce.opacity(0.6), raggio: Misure.Pulsante.raggio)
            .overlay(RoundedRectangle(cornerRadius: Misure.Pulsante.raggio).strokeBorder(Colori.Note.pulsanteBordo, lineWidth: 1))
            .brightness(configuration.isPressed ? -0.08 : 0)
            .contentShape(Rectangle())
    }
}

/// Cuoio della rilegatura con la cucitura tratteggiata in basso.
struct CuoioNote: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Gradienti.cuoioNote
            Materiale.Trama(nome: "Grana")
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundColor(Colori.Note.cucitura.opacity(0.85))
                .frame(height: 0.5)
                .shadow(color: Colori.Note.cucituraOmbra, radius: 0, x: 0, y: 1)
                .padding(.bottom, 5)
        }
        .luceInterna(Colori.Note.cuoioLuce)
        .bordoBasso(Colori.Note.cuoioBordo)
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
