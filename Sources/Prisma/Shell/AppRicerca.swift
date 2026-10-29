import SwiftUI
import AppKit

/// App Ricerca in finestra: resta per compatibilità (spazi di lavoro e sessioni salvate con la Ricerca aperta).
/// ⌘K, il dock, la barra e Eve aprono il pannello in alto come Spotlight (`RicercaSpotlight`).
/// Si scrive, i risultati arrivano raggruppati per app; ↑ ↓ scelgono, Invio apre il risultato nella sua app.
struct AppRicerca: View {
    @EnvironmentObject var stato: StatoShell
    /// App in primo piano, pannelli e blocco: decidono se le frecce scelgono i risultati.
    @EnvironmentObject var sistema: StatoFinestre
    @FocusState private var fuoco: Bool
    @State private var selezione = 0
    @State private var tasti: Any?
    /// I risultati si calcolano quando cambia il testo (o si torna alla Ricerca), non a ogni disegno.
    @State private var sezioni: [SezioneRicerca] = []
    /// Il testo del campo: resta qui e passa allo stato poco dopo l'ultimo tasto, così ogni lettera
    /// ridisegna solo la Ricerca (il titolo della finestra lo segue un attimo dopo).
    @State private var testo = ""
    @State private var invio = Rinvio()

    /// Quanto aspettare dopo l'ultimo tasto prima di passare il testo allo stato condiviso.
    static let attesa = 0.15

    var body: some View {
        let sezioni = sezioni
        let elenco = sezioni.flatMap(\.risultati)
        VStack(spacing: 0) {
            barra(elenco)
            ScrollViewReader { scorri in
                ScrollView {
                    VStack(alignment: .leading, spacing: Misure.Ricerca.spazioSezioni) {
                        if testo.trimmingCharacters(in: .whitespaces).isEmpty {
                            vuoto("Cerca in tutto Prisma",
                                  "Clienti, posizioni, documenti (anche il testo delle pagine), note, appuntamenti, attività, obiettivi, incontri e prodotti. Tutto resta sul Mac.")
                        } else if sezioni.isEmpty {
                            vuoto("Nessun risultato", "Prova con meno parole o con una parte del nome.")
                        } else {
                            ForEach(sezioni) { s in sezione(s, elenco: elenco) }
                        }
                    }
                    .padding(Misure.Ricerca.margineContenuto)
                    .frame(maxWidth: Misure.Ricerca.larghezzaMassima)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: selezione) { i in
                    if elenco.indices.contains(i) { scorri.scrollTo(elenco[i].id) }
                }
            }
        }
        .background(FondoRicerca())
        .onAppear {
            fuoco = true
            if testo != stato.testoRicerca { testo = stato.testoRicerca }
            cerca()
            installaTasti()
            aggiornaFrecce()
        }
        .onDisappear {
            invio.subito()
            if let t = tasti { NSEvent.removeMonitor(t) }
            tasti = nil
            FrecceRicerca.condivise.attiva = false
        }
        .onChange(of: sistema.appAttiva) { app in
            if app == .ricerca { cerca() }
            aggiornaFrecce()
        }
        .onChange(of: fuoco) { _ in aggiornaFrecce() }
        .onChange(of: sistema.pannelloSpazi) { _ in aggiornaFrecce() }
        .onChange(of: sistema.pannelloAppAperte) { _ in aggiornaFrecce() }
        .onChange(of: sistema.pannelloNotifiche) { _ in aggiornaFrecce() }
        .onChange(of: sistema.bloccato) { _ in aggiornaFrecce() }
        .onChange(of: sistema.pannelloRicerca) { _ in aggiornaFrecce() }
        // ⌘K apre il pannello: il campo della finestra non gli ruba il cursore
        .onChange(of: stato.richiestaFuocoRicerca) { _ in if !sistema.pannelloRicerca { fuoco = true } }
        .onChange(of: testo) { _ in
            selezione = 0
            cerca()
            invio.dopo(Self.attesa) { if stato.testoRicerca != testo { stato.testoRicerca = testo } }
        }
        // Cambiato da fuori: vale quello dello stato
        .onChange(of: stato.testoRicerca) { nuovo in if nuovo != testo { testo = nuovo } }
    }

    private func cerca() {
        sezioni = MotoreRicerca.cerca(testo, in: stato)
    }

    /// Le frecce scelgono i risultati solo con la Ricerca davanti, il cursore nel campo e nessun pannello aperto.
    private func aggiornaFrecce() {
        FrecceRicerca.condivise.attiva = sistema.appAttiva == .ricerca && fuoco && !sistema.pannelloSpazi
            && !sistema.pannelloAppAperte && !sistema.pannelloNotifiche && !sistema.pannelloRicerca && !sistema.bloccato
    }

    private func barra(_ elenco: [RisultatoRicerca]) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundColor(Colori.Ricerca.lente)
            TextField("Cerca clienti, posizioni, documenti, appuntamenti…", text: $testo)
                .textFieldStyle(.plain)
                .font(Tipo.ricercaCampo)
                .focused($fuoco)
                .onSubmit { apri(elenco, selezione) }
            if !testo.isEmpty {
                Button { testo = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Colori.Ricerca.lente)
                }
                .buttonStyle(StileSemplice())
                // Area di clic di 28 pt senza alzare il campo
                .contentShape(Rectangle().inset(by: -Tema.Misura.Componenti.allargamentoClic))
                .help("Cancella la ricerca")
                .accessibilityLabel("Cancella la ricerca")
            }
            Text("⌘ K").font(Tipo.ricercaTasto).foregroundColor(Colori.Ricerca.tasto)
        }
        .padding(.horizontal, 12)
        .frame(height: Misure.Ricerca.campoAltezza)
        .frame(maxWidth: Misure.Ricerca.larghezzaMassima)
        .background(RoundedRectangle(cornerRadius: Misure.Ricerca.campoRaggio, style: .continuous).fill(Tema.Colore.scheda))
        .overlay {
            RoundedRectangle(cornerRadius: Misure.Ricerca.campoRaggio, style: .continuous)
                .strokeBorder(Colori.Ricerca.campoBordo, lineWidth: Tema.Misura.filo)
        }
        .padding(Misure.Ricerca.barraMargine)
        .frame(maxWidth: .infinity)
        .background(Gradienti.barraRicerca)
        .bordoAlto(Colori.Ricerca.barraLuce)
        .bordoBasso(Colori.Ricerca.barraBordo)
    }

    private func sezione(_ s: SezioneRicerca, elenco: [RisultatoRicerca]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.gruppo.titolo)
                Spacer()
                if s.totale > s.risultati.count { Text("i primi \(s.risultati.count) di \(s.totale)").font(Tipo.ricercaDettaglio) }
            }
            .font(Tipo.ricercaSezione)
            .foregroundColor(Colori.Ricerca.sezione)
            .padding(.horizontal, 6)
            VStack(spacing: 0) {
                ForEach(Array(s.risultati.enumerated()), id: \.element.id) { i, r in
                    let indice = elenco.firstIndex(of: r) ?? 0
                    Button { apri(elenco, indice) } label: {
                        RigaRicerca(risultato: r, selezionata: indice == selezione)
                    }
                    .buttonStyle(StileSemplice())
                    .id(r.id)
                    if i < s.risultati.count - 1 {
                        Rectangle().fill(Colori.Ricerca.separatore).frame(height: Tema.Misura.filo)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Misure.Ricerca.raggioCella, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Misure.Ricerca.raggioCella, style: .continuous)
                    .strokeBorder(Colori.Ricerca.cellaBordo, lineWidth: Tema.Misura.filo)
            }
        }
    }

    private func vuoto(_ titolo: String, _ testo: String) -> some View {
        VStack(spacing: 8) {
            IconaApp(app: .ricerca, lato: Misure.Scrivania.icona)
            Text(titolo).font(Tipo.pannelloTitolo).foregroundColor(Colori.Ricerca.vuotoTitolo)
            Text(testo)
                .font(Tipo.pannelloTesto)
                .foregroundColor(Colori.Ricerca.vuotoTesto)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func apri(_ elenco: [RisultatoRicerca], _ i: Int) {
        guard elenco.indices.contains(i) else { return }
        if let a = elenco[i].azione {
            stato.eseguiAzione(a)
        } else {
            stato.vai(a: elenco[i].destinazione)
        }
    }

    /// ↑ e ↓ scelgono il risultato anche mentre si scrive (solo con la Ricerca in primo piano).
    private func installaTasti() {
        guard tasti == nil, !ProcessInfo.processInfo.arguments.contains("--istantanee") else { return }
        let frecce = FrecceRicerca.condivise
        frecce.sposta = { passo in
            let totale = sezioni.reduce(0) { $0 + $1.risultati.count }
            selezione = min(max(selezione + passo, 0), max(0, totale - 1))
        }
        tasti = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { evento in
            frecce.gestisci(evento.keyCode) ? nil : evento
        }
    }
}

/// Il ponte tra il monitor dei tasti (fuori dal thread principale per il compilatore) e la vista.
final class FrecceRicerca: @unchecked Sendable {
    static let condivise = FrecceRicerca()
    /// Vero quando la Ricerca è in primo piano.
    var attiva = false
    var sposta: (@MainActor (Int) -> Void)?

    func gestisci(_ tasto: UInt16) -> Bool {
        guard attiva, let passo = [125: 1, 126: -1][tasto] else { return false }
        let sposta = sposta
        Task { @MainActor in sposta?(passo) }
        return true
    }
}
