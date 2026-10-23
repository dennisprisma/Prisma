import SwiftUI
import AppKit

/// App Ricerca: «Cerca ovunque» (⌘K). Si scrive, i risultati arrivano raggruppati per app;
/// ↑ ↓ scelgono, Invio apre il risultato nella sua app.
struct AppRicerca: View {
    @EnvironmentObject var stato: StatoShell
    @FocusState private var fuoco: Bool
    @State private var selezione = 0
    @State private var tasti: Any?

    private var sezioni: [SezioneRicerca] { MotoreRicerca.cerca(stato.testoRicerca, in: stato) }

    var body: some View {
        let sezioni = sezioni
        let elenco = sezioni.flatMap(\.risultati)
        VStack(spacing: 0) {
            barra(elenco)
            ScrollViewReader { scorri in
                ScrollView {
                    VStack(alignment: .leading, spacing: Misure.Ricerca.spazioSezioni) {
                        if stato.testoRicerca.trimmingCharacters(in: .whitespaces).isEmpty {
                            vuoto("Cerca in tutto Prisma",
                                  "Clienti, posizioni, documenti (anche il testo delle pagine), appuntamenti, attività, obiettivi, incontri e prodotti. Tutto resta sul Mac.")
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
            installaTasti()
            FrecceRicerca.condivise.attiva = stato.appAttiva == .ricerca
        }
        .onDisappear {
            if let t = tasti { NSEvent.removeMonitor(t) }
            tasti = nil
            FrecceRicerca.condivise.attiva = false
        }
        .onChange(of: stato.appAttiva) { app in FrecceRicerca.condivise.attiva = app == .ricerca }
        .onChange(of: stato.richiestaFuocoRicerca) { _ in fuoco = true }
        .onChange(of: stato.testoRicerca) { _ in selezione = 0 }
    }

    private func barra(_ elenco: [RisultatoRicerca]) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundColor(Colori.Ricerca.lente)
            TextField("Cerca clienti, posizioni, documenti, appuntamenti…", text: $stato.testoRicerca)
                .textFieldStyle(.plain)
                .font(Tipo.ricercaCampo)
                .focused($fuoco)
                .onSubmit { apri(elenco, selezione) }
            if !stato.testoRicerca.isEmpty {
                Button { stato.testoRicerca = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Colori.Ricerca.lente)
                }
                .buttonStyle(StileSemplice())
                .help("Cancella la ricerca")
            }
            Text("⌘ K").font(Tipo.ricercaTasto).foregroundColor(Colori.Ricerca.tasto)
        }
        .padding(.horizontal, 12)
        .frame(height: Misure.Ricerca.campoAltezza)
        .frame(maxWidth: Misure.Ricerca.larghezzaMassima)
        .background(RoundedRectangle(cornerRadius: Misure.Ricerca.campoRaggio).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: Misure.Ricerca.campoRaggio).strokeBorder(Colori.Ricerca.campoBordo, lineWidth: 1))
        .ombraCSS(Colori.Ricerca.barraLuce, y: 1, sfocatura: 0)
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
            .incisione(Colori.Ricerca.sezioneIncisione)
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
                        Rectangle().fill(Colori.Ricerca.separatore).frame(height: 1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Misure.Ricerca.raggioCella))
            .overlay(RoundedRectangle(cornerRadius: Misure.Ricerca.raggioCella).strokeBorder(Colori.Ricerca.cellaBordo, lineWidth: 1))
            .ombraCSS(Colori.Ricerca.barraLuce, y: 1, sfocatura: 0)
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
        .incisione(Colori.Ricerca.sezioneIncisione)
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func apri(_ elenco: [RisultatoRicerca], _ i: Int) {
        guard elenco.indices.contains(i) else { return }
        stato.vai(a: elenco[i].destinazione)
    }

    /// ↑ e ↓ scelgono il risultato anche mentre si scrive (solo con la Ricerca in primo piano).
    private func installaTasti() {
        guard tasti == nil, !ProcessInfo.processInfo.arguments.contains("--istantanee") else { return }
        let frecce = FrecceRicerca.condivise
        frecce.sposta = { passo in
            let totale = MotoreRicerca.cerca(stato.testoRicerca, in: stato).reduce(0) { $0 + $1.risultati.count }
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
