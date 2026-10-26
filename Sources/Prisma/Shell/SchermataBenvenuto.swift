import SwiftUI
import AppKit

/// Schermata di benvenuto (il lucchetto in alto): copre le finestre con lo sfondo, l'ora e il
/// marchio, per esempio quando ci si allontana dalla scrivania con un cliente in studio.
/// Si entra facendo scorrere il cursore, con un clic o con Invio. È una schermata di cortesia:
/// non protegge i dati (per quello c'è il blocco del Mac).
struct SchermataBenvenuto: View {
    @EnvironmentObject var stato: StatoShell
    @State private var corsa: CGFloat = 0

    private var corsaMassima: CGFloat {
        Misure.Benvenuto.binario.width - Misure.Benvenuto.cursore.width - 2 * Misure.Benvenuto.margineCursore
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Materiale.SfondoScrivania()
                Colori.Benvenuto.velo
                VStack(spacing: 0) {
                    orologio
                    Spacer()
                    marchio
                    Spacer()
                    sblocco
                }
                .padding(.top, geo.size.height * Misure.Benvenuto.alto)
                .padding(.bottom, geo.size.height * Misure.Benvenuto.basso)
                .foregroundColor(Colori.Benvenuto.testo)
                .ombraCSS(Colori.Benvenuto.ombraTesto, y: 2, sfocatura: 3)
            }
        }
        .contentShape(Rectangle())
        // Il cursore lascia il campo sotto la schermata: niente si scrive nelle finestre coperte
        .onAppear { NSApp.keyWindow?.makeFirstResponder(nil) }
    }

    private var orologio: some View {
        TimelineView(.everyMinute) { contesto in
            VStack(spacing: 7) {
                Text(Formati.ora.string(from: contesto.date)).font(Tipo.benvenutoOra).tracking(-3)
                Text(Formati.dataLunga.string(from: contesto.date).capitalized).font(Tipo.benvenutoData)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Misure.Benvenuto.fascia)
            .background(Gradienti.fasciaBenvenuto)
            .bordoAlto(Colori.Benvenuto.fasciaLuce)
            .bordoBasso(Colori.Benvenuto.fasciaBordo)
        }
    }

    private var marchio: some View {
        VStack(spacing: 0) {
            ImmagineNitida(percorso: "Icone/Prisma.png", lato: Misure.Benvenuto.marchio)
            HStack(spacing: 10) {
                Text("PRISMA").font(Tipo.benvenutoMarchio)
                Text("OS").font(Tipo.benvenutoMarchioLeggero)
            }
            .tracking(4)
            .padding(.top, 20)
            .padding(.bottom, 8)
            Text("Il tuo mondo. Al tuo ritmo.").font(Tipo.benvenutoMotto).tracking(1)
        }
    }

    private var sblocco: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Misure.Benvenuto.raggioBinario).fill(Gradienti.binarioBenvenuto)
                RoundedRectangle(cornerRadius: Misure.Benvenuto.raggioBinario).strokeBorder(Colori.Benvenuto.binarioBordo, lineWidth: 1)
                Text("scorri per entrare")
                    .font(Tipo.benvenutoScritta)
                    .tracking(-0.4)
                    .foregroundColor(Colori.Benvenuto.scritta)
                    .opacity(1 - Double(corsa / max(1, corsaMassima)))
                    .padding(.leading, Misure.Benvenuto.scrittaSinistra)
                cursore
                    .offset(x: Misure.Benvenuto.margineCursore + corsa)
                    .gesture(
                        DragGesture()
                            .onChanged { corsa = min(max(0, $0.translation.width), corsaMassima) }
                            .onEnded { _ in
                                if corsa >= corsaMassima * Misure.Benvenuto.soglia { entra() } else {
                                    withAnimation(Animazioni.apertura) { corsa = 0 }
                                }
                            }
                    )
            }
            .frame(width: Misure.Benvenuto.binario.width, height: Misure.Benvenuto.binario.height)
            .shadow(color: Colori.Benvenuto.binarioLuce, radius: 0, x: 0, y: 1)
            Button("oppure entra con un clic") { entra() }
                .buttonStyle(StileSemplice())
                .font(Tipo.benvenutoCollegamento)
                .foregroundColor(Colori.Benvenuto.collegamento)
                .keyboardShortcut(.defaultAction)
            Text("Schermata di cortesia · non protegge i dati")
                .font(Tipo.benvenutoNota)
                .foregroundColor(Colori.Benvenuto.nota)
        }
    }

    private var cursore: some View {
        Text("➜")
            .font(Tipo.benvenutoFreccia)
            .foregroundColor(Colori.Benvenuto.freccia)
            .shadow(color: .white, radius: 0, x: 0, y: 1)
            .frame(width: Misure.Benvenuto.cursore.width, height: Misure.Benvenuto.cursore.height)
            .background(RoundedRectangle(cornerRadius: Misure.Benvenuto.raggioCursore).fill(Gradienti.cursoreBenvenuto))
            .luceInterna(.white, raggio: Misure.Benvenuto.raggioCursore)
            .overlay(RoundedRectangle(cornerRadius: Misure.Benvenuto.raggioCursore).strokeBorder(Colori.Benvenuto.cursoreBordo, lineWidth: 1))
            .ombraCSS(Colori.Benvenuto.cursoreOmbra, y: 2, sfocatura: 3)
    }

    private func entra() {
        withAnimation(Animazioni.apertura) { stato.bloccato = false }
        corsa = 0
    }
}

/// «Le tue app aperte»: le finestre aperte, in primo piano o ridotte, con un clic per tornarci.
struct PannelloAppAperte: View {
    @EnvironmentObject var stato: StatoShell
    /// Altezza misurata delle schede: il riquadro si adatta, fino all'altezza massima.
    @State private var altezzaContenuto: CGFloat = 0

    var body: some View {
        ZStack {
            Colori.Benvenuto.veloApp
                .contentShape(Rectangle())
                .onTapGesture { stato.pannelloAppAperte = false }
            CorniceModulo(titolo: "Le tue app aperte") {
                let aperte = Array(stato.finestre.reversed())
                if aperte.isEmpty {
                    VStack(spacing: 6) {
                        Text("La scrivania è tutta tua.").font(Tipo.pannelloTitolo).foregroundColor(Colori.Pannello.titolo)
                        Text("Apri un'app dal dock o dalle icone per iniziare.").font(Tipo.pannelloTesto).foregroundColor(Colori.Pannello.testoSecondario)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: Misure.Benvenuto.colonne), spacing: 14) {
                        ForEach(aperte) { f in scheda(f, inPrimoPiano: f.app == stato.appAttiva) }
                    }
                    .background(GeometryReader { g in
                        Color.clear.preference(key: AltezzaAppAperte.self, value: g.size.height)
                    })
                }
            } piede: {
                Spacer()
                Button("Mostra la scrivania") {
                    stato.pannelloAppAperte = false
                    stato.mostraScrivania()
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                Button("Chiudi") { stato.pannelloAppAperte = false }
                    .buttonStyle(StileBlu())
                    .keyboardShortcut(.cancelAction)
            }
            .onPreferenceChange(AltezzaAppAperte.self) { altezzaContenuto = $0 }
            .frame(width: Misure.Benvenuto.riepilogo.width, height: altezzaRiquadro(vuoto: stato.finestre.isEmpty))
            .clipShape(RoundedRectangle(cornerRadius: Misure.Finestra.raggio))
            .ombraCSS(Colori.Spazi.schedaOmbra, y: 12, sfocatura: 40)
        }
    }

    /// Alto quanto le schede più la cornice, mai oltre il massimo (poi le schede scorrono).
    private func altezzaRiquadro(vuoto: Bool) -> CGFloat {
        let massimo = Misure.Benvenuto.riepilogo.height
        guard !vuoto, altezzaContenuto > 0 else { return vuoto ? min(massimo, Misure.Benvenuto.corniceModulo + Misure.Benvenuto.vuotoAltezza) : massimo }
        return min(massimo, altezzaContenuto + Misure.Benvenuto.corniceModulo)
    }

    private func scheda(_ f: StatoShell.Finestra, inPrimoPiano: Bool) -> some View {
        Button {
            stato.pannelloAppAperte = false
            stato.apri(f.app)
        } label: {
            VStack(spacing: 5) {
                IconaApp(app: f.app, lato: Misure.Benvenuto.iconaApp)
                    .padding(.bottom, 7)
                Text(f.app.titolo).font(Tipo.appApertaTitolo).foregroundColor(Colori.Benvenuto.schedaTitolo)
                Text(stato.clienteAttivo?.nome ?? "Nessun cliente").font(Tipo.appApertaCliente).foregroundColor(Colori.Benvenuto.schedaCliente)
                Text(f.ridotta ? "Ridotta a icona" : inPrimoPiano ? "In primo piano" : "Aperta")
                    .font(Tipo.appApertaStato)
                    .foregroundColor(Colori.Benvenuto.schedaStato)
                    .padding(.top, 3)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 7).fill(Gradienti.schedaAppAperta))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Colori.Benvenuto.schedaBordo, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }
}

/// L'altezza delle schede delle app aperte, misurata per adattare il riquadro.
private struct AltezzaAppAperte: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
