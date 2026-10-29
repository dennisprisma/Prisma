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
    /// La finestra messa a tutto schermo: all'uscita si rimette com'era quella, non la finestra in primo piano.
    var finestra: NSWindow?
}

extension StatoShell {
    /// Mostra il documento a tutto schermo. Per un documento di un cliente accende anche la modalità cliente.
    /// Prima la sala compare in dissolvenza sopra la scrivania, poi (a dissolvenza finita) la finestra passa a
    /// tutto schermo: sotto la sala non si reimpagina niente.
    func presenta(_ d: DocumentoStampabile, delCliente: Bool = true) {
        guard !d.pagine.isEmpty else { return }
        var p = Presentazione(titolo: d.titolo, cliente: d.cliente, formato: d.formato, pagine: d.pagine)
        if delCliente, let c = clienteAttivo {
            p.clienteId = c.id
            // Il fascicolo preparato dall'Agenda porta con sé l'appuntamento, se è proprio di questo cliente
            if case .fascicolo? = prospetto, let id = fascicoloAppuntamento,
               dati.appuntamenti.contains(where: { $0.id == id && $0.clienteId == c.id }) {
                p.appuntamentoId = id
            }
        }
        // La finestra da mettere a tutto schermo (nessuna se lo è già)
        var schermoIntero: NSWindow?
        if persistente, let finestra = NSApp.keyWindow, !finestra.styleMask.contains(.fullScreen) { schermoIntero = finestra }
        if let finestra = schermoIntero {
            p.haAccesoSchermoIntero = true
            p.finestra = finestra
        }
        let accendeModoCliente = p.clienteId != nil && !inModoCliente
        // La sala per prima, con la sua dissolvenza; le modifiche senza animazione vengono dopo
        Movimenti.anima(Tema.Moto.Pannelli.presentazione, durata: Tema.Moto.Pannelli.durataPresentazione, animato: persistente) {
            presentazione = p
        }
        if accendeModoCliente {
            entraModoCliente(avviso: false)
            presentazione?.haAccesoModoCliente = inModoCliente
        }
        if pannelloNotifiche { pannelloNotifiche = false }
        // La guida resterebbe sotto la sala con il suo Esc: si chiude (l'introduzione non si segna come vista)
        if sistema.guida != nil { sistema.guida = nil }
        // Nessun campo sotto il velo deve ricevere i tasti: il commento o la chat di Eve resterebbero scrivibili
        if persistente { NSApp.keyWindow?.makeFirstResponder(nil) }
        guard let finestra = schermoIntero else { return }
        let giro = sistema.giroPresentazione &+ 1
        sistema.giroPresentazione = giro
        Movimenti.dopo(Tema.Moto.Pannelli.durataPresentazione) { [weak self, weak finestra] in
            guard let self, let finestra, self.sistema.giroPresentazione == giro, self.presentazione != nil,
                  !finestra.styleMask.contains(.fullScreen) else { return }
            finestra.toggleFullScreen(nil)
        }
    }

    func paginaSeguente() {
        guard var p = presentazione, p.pagina < p.pagine.count - 1 else { return }
        p.pagina += 1
        mostraPagina(p)
    }

    func paginaPrecedente() {
        guard var p = presentazione, p.pagina > 0 else { return }
        p.pagina -= 1
        mostraPagina(p)
    }

    /// Le pagine si avvicendano in dissolvenza, come in Keynote.
    private func mostraPagina(_ p: Presentazione) {
        if persistente {
            withAnimation(Movimenti.curva(Tema.Moto.Pannelli.paginaPresentazione)) { presentazione = p }
        } else {
            presentazione = p
        }
    }

    /// Un'annotazione presa durante la presentazione: va negli appunti dell'incontro (quello dell'appuntamento,
    /// o quello di oggi, creato se manca) con il documento e la pagina; come attività, anche tra le cose da fare.
    func annotaPresentazione(_ testo: String, comeAttivita: Bool = false, oggi: Date = Date()) {
        let t = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, var p = presentazione, let cliente = p.clienteId else { return }
        let cal = Calendar.current
        // Sempre e solo incontri e appuntamenti di questo cliente
        var incontro = dati.incontri.first { i in i.clienteId == cliente && (p.appuntamentoId.map { i.appuntamentoId == $0 } ?? false) }
            ?? dati.incontri.first { $0.clienteId == cliente && cal.isDate($0.data, inSameDayAs: oggi) }
        if incontro == nil {
            let a = p.appuntamentoId.flatMap { id in dati.appuntamenti.first { $0.id == id && $0.clienteId == cliente } }
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
            // Collegata all'appuntamento da cui nasce: si ritrova sotto di lui in Agenda
            a.appuntamentoId = p.appuntamentoId
            salvaAttivita(a)
        }
        p.annotazioni += 1
        presentazione = p
    }

    func chiudiPresentazione() {
        guard let p = presentazione else { return }
        sistema.giroPresentazione &+= 1
        Movimenti.anima(Tema.Moto.Pannelli.presentazione, durata: Tema.Moto.Pannelli.durataPresentazione, animato: persistente) {
            presentazione = nil
        }
        // Un genio o una chiusura in corso sotto la sala finiscono di colpo (dopo il cambio animato)
        annullaEffetti()
        if p.haAccesoModoCliente { esciModoCliente() }
        if p.haAccesoSchermoIntero, let finestra = p.finestra ?? NSApp.keyWindow, finestra.styleMask.contains(.fullScreen) {
            finestra.toggleFullScreen(nil)
        }
    }
}

/// La sala scura (il cielo scuro dello sfondo d'acqua) con la pagina al centro, grande quanto lo schermo
/// permette, e una barra discreta in basso in una capsula di vetro scuro.
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
                LinearGradient(colors: [Tema.Colore.PannelliShell.salaAlto, Tema.Colore.PannelliShell.salaBasso],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer(minLength: Misure.Presentazione.margine)
                    p.pagine[min(p.pagina, p.pagine.count - 1)]
                        // In sala le etichette piccole (valori finali dei grafici, piede) si leggono da lontano
                        .environment(\.documentoInSala, true)
                        .frame(width: p.formato.width, height: p.formato.height)
                        .scaleEffect(scala)
                        .frame(width: p.formato.width * scala, height: p.formato.height * scala)
                        .shadow(color: Tema.Colore.PannelliShell.ombraPaginaPresentazione,
                                radius: Tema.Misura.PannelliShell.ombraPaginaRaggio, y: Tema.Misura.PannelliShell.ombraPaginaY)
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
        HStack(spacing: Tema.Misura.PannelliShell.barraPresentazioneSpazio) {
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
        .font(Tema.Testo.PannelliShell.presentazione)
        .foregroundColor(Tema.Colore.PannelliShell.testoPresentazione)
        .modifier(CapsulaPresentazione())
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
            Text("Pagina \(p.pagina + 1)").foregroundColor(Tema.Colore.PannelliShell.testoPresentazione)
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
        .font(Tema.Testo.PannelliShell.presentazione)
        .foregroundColor(Tema.Colore.PannelliShell.testoPresentazione)
        .modifier(CapsulaPresentazione())
    }
}

/// La barra della presentazione in una capsula di vetro scuro dai colori fissi: la sala è sempre scura.
private struct CapsulaPresentazione: ViewModifier {
    func body(content: Content) -> some View {
        let m = Tema.Misura.PannelliShell.self
        let c = Tema.Colore.PannelliShell.self
        return content
            .padding(.horizontal, m.barraPresentazioneMargine)
            .frame(height: m.barraPresentazioneAltezza)
            .background {
                FormaVetro.capsula
                    .fill(c.barraPresentazione)
                    .overlay {
                        FormaVetro.capsula.strokeBorder(c.bordoBarraPresentazione, lineWidth: Tema.Misura.filo)
                    }
                    .overlay {
                        FiloInterno(forma: .capsula)
                            .fill(c.luceBarraPresentazione, style: FillStyle(eoFill: true))
                            .clipShape(FormaVetro.capsula)
                    }
            }
            .padding(.horizontal, Misure.Presentazione.margine)
    }
}
