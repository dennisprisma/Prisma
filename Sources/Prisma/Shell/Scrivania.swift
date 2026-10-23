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
            VStack(alignment: .leading, spacing: 0) {
                intestazioneBacheca
                BachecaWidget()
                    .padding(.vertical, 6)
                piede
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
                stato.cercaOvunque()
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

    private var intestazioneBacheca: some View {
        HStack {
            Text("La tua giornata")
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
            Text("Le app sono nel dock. Un clic per entrare.")
            Spacer()
            Text(stato.dati.impostazioni.backup.ultimo.map { "Ultimo backup: \(Formati.dataOra.string(from: $0)) · archivio locale" }
                 ?? "Nessun backup ancora · archivio locale")
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
