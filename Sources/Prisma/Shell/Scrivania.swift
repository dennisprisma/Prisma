import SwiftUI

/// La scrivania: saluto, griglia delle 16 app e colonna del cliente in primo piano.
struct Scrivania: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                introduzione
                Spacer(minLength: 20)
                pulsantiRapidi
            }
            HStack(alignment: .top, spacing: Misure.Scrivania.colonnaSpazio) {
                VStack(alignment: .leading, spacing: 0) {
                    intestazioneApp
                    GrigliaApp()
                    piede
                }
                ColonnaCliente()
                    .frame(width: Misure.Scrivania.colonnaLarghezza)
            }
            .padding(.top, 12)
        }
        .padding(.top, Misure.Scrivania.margineAlto)
        .padding(.horizontal, Misure.Scrivania.margineLato)
        .padding(.bottom, Misure.Scrivania.margineBasso)
    }

    private var saluto: String {
        let ora = Calendar.current.component(.hour, from: Date())
        let s = ora < 13 ? "Buongiorno" : ora < 18 ? "Buon pomeriggio" : "Buonasera"
        return "\(s), \(stato.nomeUtente)."
    }

    private var introduzione: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PRISMA OS   •   CLASSIC EDITION")
                .font(Tipo.scrivaniaKicker)
                .tracking(0.3)
                .foregroundColor(Colori.Scrivania.kicker)
                .ombraCSS(Colori.Scrivania.ombraTesto, y: 1, sfocatura: 2)
                .padding(.bottom, 4)
            TimelineView(.everyMinute) { _ in
                Text(saluto)
                    .font(Tipo.scrivaniaTitolo)
                    .foregroundColor(Colori.Scrivania.titolo)
                    .ombraCSS(Colori.Scrivania.ombraTesto, y: 1, sfocatura: 3)
            }
            .padding(.bottom, 3)
            Text("Tutto il tuo lavoro, a portata di mano.")
                .font(Tipo.scrivaniaSottotitolo)
                .foregroundColor(Colori.Scrivania.sottotitolo)
                .ombraCSS(Colori.Scrivania.ombraTesto, y: 1, sfocatura: 2)
        }
        .padding(.top, 14)
    }

    private var pulsantiRapidi: some View {
        HStack(spacing: Misure.Scrivania.spazioPulsanti) {
            Button {
                stato.mostraAvviso("Gli spazi di lavoro arrivano nella prossima fase.")
            } label: {
                Label("Spazi di lavoro", systemImage: "rectangle.split.2x1")
            }
            Button {
                stato.mostraAvviso("La ricerca in tutto Prisma arriva nella prossima fase.")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Cerca ovunque")
                    Text("⌘ K").font(Tipo.barraTasto).foregroundColor(Colori.Barra.tasto)
                }
            }
            Button {
                stato.alternaSchermoIntero()
            } label: {
                Label(stato.schermoIntero ? "Esci da schermo intero" : "Schermo intero",
                      systemImage: stato.schermoIntero ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
        }
        .buttonStyle(StileVetro())
        .labelStyle(EtichettaPulsante())
        .padding(.top, 15)
    }

    private var intestazioneApp: some View {
        HStack {
            Text("Le tue applicazioni")
                .font(Tipo.scrivaniaSezione)
                .foregroundColor(Colori.Scrivania.intestazione)
                .ombraCSS(Colori.Scrivania.intestazioneOmbra, y: 1, sfocatura: 3)
            Spacer()
            Button {
                stato.mostraAvviso("Il riepilogo delle app aperte arriva nella prossima fase.")
            } label: {
                HStack(spacing: 8) {
                    Text("\(stato.finestre.count) \(stato.finestre.count == 1 ? "aperta" : "aperte")")
                    Image(systemName: "square.grid.2x2")
                }
            }
            .buttonStyle(StileVetro(margine: EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)))
        }
        .padding(.horizontal, 4)
        .frame(height: Misure.Scrivania.altezzaSezione)
    }

    private var piede: some View {
        HStack {
            Text("Un clic per entrare. Il dock per cambiare app.")
            Spacer()
            Text("Dati demo · archivio locale")
        }
        .font(Tipo.scrivaniaPiede)
        .foregroundColor(Colori.Scrivania.piede)
        .ombraCSS(Colori.Scrivania.piedeOmbra, y: 1, sfocatura: 3)
        .padding(.horizontal, 3)
        .padding(.top, 4)
    }
}

/// Icona + testo dei pulsanti di vetro, con lo spazio del template (8 pt).
struct EtichettaPulsante: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
            configuration.title
        }
    }
}

/// Griglia 4×4 delle app; le righe si dividono l'altezza disponibile come nel template.
struct GrigliaApp: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        GeometryReader { geo in
            let colonne = Misure.Scrivania.colonne
            let righe = Int((Double(AppPrisma.allCases.count) / Double(colonne)).rounded(.up))
            let altezzaRiga = max(110, (geo.size.height - CGFloat(righe - 1) * Misure.Scrivania.spazioRighe) / CGFloat(righe))
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Misure.Scrivania.spazioColonne), count: colonne),
                spacing: Misure.Scrivania.spazioRighe
            ) {
                ForEach(AppPrisma.allCases) { app in
                    Lanciatore(app: app, badge: app == .attivita ? stato.attivitaAperte.count : 0)
                        .frame(height: altezzaRiga)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

/// Un'app sulla scrivania (.os-app-launcher).
struct Lanciatore: View {
    @EnvironmentObject var stato: StatoShell
    let app: AppPrisma
    var badge = 0
    @State var sopra = false

    var body: some View {
        Button {
            stato.apri(app)
        } label: {
            VStack(spacing: Misure.Scrivania.lanciatoreSpazio) {
                IconaApp(app: app, lato: Misure.Scrivania.icona)
                    .ombraCSS(Colori.Scrivania.iconaOmbra1, y: 2, sfocatura: 1)
                    .ombraCSS(Colori.Scrivania.iconaOmbra2, y: sopra ? 6 : 5, sfocatura: sopra ? 5 : 4)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 { Badge(numero: badge).offset(x: 7, y: -7) }
                    }
                Text(app.titolo)
                    .font(Tipo.lanciatoreNome)
                    .foregroundColor(.white)
                    .ombraCSS(Colori.Scrivania.etichettaOmbra, y: 1, sfocatura: 2)
                Text(app.sottotitolo)
                    .font(Tipo.lanciatoreSottotitolo)
                    .foregroundColor(.white)
                    .opacity(0.92)
                    .ombraCSS(Colori.Scrivania.sottotitoloOmbra, y: 1, sfocatura: 2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 180)
            }
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(StileSemplice())
        .onHover { s in withAnimation(Animazioni.passaggio) { sopra = s } }
        .help(app.titolo)
    }
}
