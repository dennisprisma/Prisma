import AppKit
import SwiftUI

/// La presentazione all'incontro: le pagine di un documento a tutto schermo, una alla volta,
/// da sfogliare con le frecce mentre il cliente guarda. Si abbina alla modalità cliente.
struct Presentazione {
    let titolo: String
    let cliente: String
    let formato: CGSize
    let pagine: [AnyView]
    var pagina = 0
    /// La modalità cliente l'ha accesa la presentazione: all'uscita si spegne.
    var haAccesoModoCliente = false
    /// La finestra è passata a tutto schermo per la presentazione: all'uscita torna com'era.
    var haAccesoSchermoIntero = false
    /// Il cliente e l'appuntamento a cui vanno le annotazioni prese durante la presentazione.
    var clienteId: String?
    var appuntamentoId: String?
    var annotazioni = 0
}

extension StatoShell {
    /// Mostra il documento a tutto schermo. Per un documento di un cliente accende anche la modalità cliente.
    func presenta(_ d: DocumentoStampabile, delCliente: Bool = true) {
        guard !d.pagine.isEmpty else { return }
        var p = Presentazione(titolo: d.titolo, cliente: d.cliente, formato: d.formato, pagine: d.pagine)
        if delCliente {
            p.clienteId = clienteAttivoId
            // Il fascicolo preparato dall'Agenda porta con sé l'appuntamento
            if case .fascicolo? = prospetto { p.appuntamentoId = fascicoloAppuntamento }
        }
        if delCliente, !inModoCliente {
            entraModoCliente(avviso: false)
            p.haAccesoModoCliente = inModoCliente
        }
        if persistente, let finestra = NSApp.keyWindow, !finestra.styleMask.contains(.fullScreen) {
            finestra.toggleFullScreen(nil)
            p.haAccesoSchermoIntero = true
        }
        pannelloNotifiche = false
        presentazione = p
    }

    func paginaSeguente() {
        guard var p = presentazione, p.pagina < p.pagine.count - 1 else { return }
        p.pagina += 1
        presentazione = p
    }

    func paginaPrecedente() {
        guard var p = presentazione, p.pagina > 0 else { return }
        p.pagina -= 1
        presentazione = p
    }

    /// Un'annotazione presa durante la presentazione: va negli appunti dell'incontro (quello dell'appuntamento,
    /// o quello di oggi, creato se manca) con il documento e la pagina; come attività, anche tra le cose da fare.
    func annotaPresentazione(_ testo: String, comeAttivita: Bool = false, oggi: Date = Date()) {
        let t = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, var p = presentazione, let cliente = p.clienteId else { return }
        let cal = Calendar.current
        var incontro = dati.incontri.first { i in p.appuntamentoId.map { i.appuntamentoId == $0 } ?? false }
            ?? dati.incontri.first { $0.clienteId == cliente && cal.isDate($0.data, inSameDayAs: oggi) }
        if incontro == nil {
            let a = p.appuntamentoId.flatMap { id in dati.appuntamenti.first { $0.id == id } }
            incontro = Incontro(clienteId: cliente, titolo: a?.titolo ?? "Incontro del \(CifreDoc.dataBreve(oggi))",
                                data: a?.inizio ?? Appuntamento.alMinuto(oggi), appuntamentoId: a?.id)
        }
        guard var i = incontro else { return }
        let riga = "• \(p.titolo), pagina \(p.pagina + 1): \(t)" + (comeAttivita ? " → attività" : "")
        i.appunti = i.appunti.isEmpty ? riga : i.appunti + "\n" + riga
        salvaIncontro(i)
        if comeAttivita {
            var a = Attivita.nuova(clienteId: cliente, scadenza: cal.date(byAdding: .day, value: 7, to: oggi) ?? oggi)
            a.titolo = t
            salvaAttivita(a)
        }
        p.annotazioni += 1
        presentazione = p
    }

    func chiudiPresentazione() {
        guard let p = presentazione else { return }
        presentazione = nil
        if p.haAccesoModoCliente { esciModoCliente() }
        if p.haAccesoSchermoIntero, let finestra = NSApp.keyWindow, finestra.styleMask.contains(.fullScreen) {
            finestra.toggleFullScreen(nil)
        }
    }
}

/// Il velo scuro con la pagina al centro, grande quanto lo schermo permette, e una barra discreta in basso.
struct VistaPresentazione: View {
    @EnvironmentObject var stato: StatoShell
    let p: Presentazione
    /// Si sta scrivendo un'annotazione: le scorciatoie per sfogliare tacciono.
    @State private var scrivendo = false
    @State private var nota = ""
    @FocusState private var campo: Bool

    var body: some View {
        GeometryReader { geo in
            let spazio = CGSize(width: geo.size.width - Misure.Presentazione.margine * 2,
                                height: geo.size.height - Misure.Presentazione.margine * 2 - Misure.Presentazione.barra)
            let scala = max(0.1, min(spazio.width / p.formato.width, spazio.height / p.formato.height))
            ZStack {
                Colori.Presentazione.sfondo.ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer(minLength: Misure.Presentazione.margine)
                    p.pagine[min(p.pagina, p.pagine.count - 1)]
                        .frame(width: p.formato.width, height: p.formato.height)
                        .scaleEffect(scala)
                        .frame(width: p.formato.width * scala, height: p.formato.height * scala)
                        .shadow(color: Colori.Presentazione.ombra, radius: 24, y: 8)
                        .id(p.pagina)
                        .transition(.opacity)
                    Spacer(minLength: 0)
                    Group { if scrivendo { editor } else { barra } }
                        .frame(height: Misure.Presentazione.barra)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // Un clic sulla pagina va avanti, come in Presentazioni
            .contentShape(Rectangle())
            .onTapGesture { if !scrivendo { stato.paginaSeguente() } }
        }
    }

    private var barra: some View {
        HStack(spacing: 16) {
            Text("\(p.titolo) · \(p.cliente)").lineLimit(1)
            Spacer()
            Button("←") { stato.paginaPrecedente() }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(p.pagina == 0)
            Text("\(p.pagina + 1) / \(p.pagine.count)").monospacedDigit()
            Button("→") { stato.paginaSeguente() }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(p.pagina >= p.pagine.count - 1)
            // Spazio e Invio vanno avanti, come in Keynote
            Button("") { stato.paginaSeguente() }.keyboardShortcut(.space, modifiers: []).frame(width: 0).opacity(0)
            Button("") { stato.paginaSeguente() }.keyboardShortcut(.return, modifiers: []).frame(width: 0).opacity(0)
            if p.clienteId != nil {
                Button(p.annotazioni == 0 ? "Annota  N" : "Annota  N · \(p.annotazioni)") { inizia() }
                    .keyboardShortcut("n", modifiers: [])
                    .help("Annota una reazione o una decisione su questa pagina: va negli appunti dell'incontro")
            }
            Button("Esci  esc") { stato.chiudiPresentazione() }
                .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(StileSemplice())
        .font(Tipo.barraOra)
        .foregroundColor(Colori.Presentazione.testo)
        .padding(.horizontal, Misure.Presentazione.margine)
    }

    private func inizia() {
        nota = ""
        scrivendo = true
        // Il campo esiste solo dal prossimo giro: lì prende il fuoco
        DispatchQueue.main.async { campo = true }
    }

    private func salva(comeAttivita: Bool) {
        stato.annotaPresentazione(nota, comeAttivita: comeAttivita)
        scrivendo = false
    }

    /// La riga per scrivere: Invio salva negli appunti, ⌘Invio anche come attività, esc annulla.
    private var editor: some View {
        HStack(spacing: 12) {
            Text("Pagina \(p.pagina + 1)").foregroundColor(Colori.Presentazione.testo)
            TextField("Una reazione, una decisione, una cosa da fare…", text: $nota)
                .textFieldStyle(.roundedBorder)
                .focused($campo)
                .onSubmit { salva(comeAttivita: false) }
            Button("Salva come attività  ⌘↩") { salva(comeAttivita: true) }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Annulla  esc") { scrivendo = false }
                .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(StileSemplice())
        .font(Tipo.barraOra)
        .foregroundColor(Colori.Presentazione.testo)
        .padding(.horizontal, Misure.Presentazione.margine)
    }
}
