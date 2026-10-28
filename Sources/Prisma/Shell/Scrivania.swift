import SwiftUI

/// La scrivania (tema «Liquid Glass»): saluto sullo sfondo d'acqua, pulsanti di vetro,
/// «La tua giornata» con i widget e il piede.
struct Scrivania: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        GeometryReader { geo in
            // Margine laterale del tema: 3% della larghezza, tra 16 e 44 punti; contenuto al massimo 1480
            let margine = min(max(geo.size.width * Tema.Misura.margineScrivaniaQuota, Tema.Misura.margineScrivaniaMinimo),
                              Tema.Misura.margineScrivaniaMassimo)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    introduzione
                    Spacer(minLength: 20)
                    pulsantiRapidi
                }
                if stato.guidaVisibile && !stato.inModoCliente {
                    StrisciaGuida()
                        .padding(.top, Tema.Misura.Shell.guidaAlto)
                }
                intestazioneBacheca
                BachecaWidget()
                piede
            }
            .frame(maxWidth: Tema.Misura.scrivaniaMassima)
            .padding(.top, Tema.Misura.Shell.scrivaniaAlto)
            .padding(.horizontal, margine)
            .padding(.bottom, Tema.Misura.Shell.scrivaniaBasso)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    private var saluto: String {
        let ora = Calendar.current.component(.hour, from: Date())
        let s = ora < 13 ? "Buongiorno" : ora < 18 ? "Buon pomeriggio" : "Buonasera"
        return "\(s), \(stato.nomeUtente)."
    }

    private var introduzione: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Shell.salutoSpazio) {
            TimelineView(.everyMinute) { _ in
                Text(saluto)
                    .font(Tema.Testo.saluto)
                    .tracking(Tema.Testo.spaziaturaSaluto)
                    .foregroundColor(Tema.Colore.inchiostroSfondo)
                    .lineLimit(1)
            }
            Text("Tutto il tuo lavoro, a portata di mano.")
                .font(Tema.Testo.sottotitoloSaluto)
                .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
        }
        .aloneSfondo()
    }

    private var pulsantiRapidi: some View {
        HStack(spacing: Tema.Misura.Shell.pulsantiSpazio) {
            Button {
                stato.pannelloSpazi = true
            } label: {
                Label("Spazi di lavoro", systemImage: "rectangle.split.2x1")
            }
            .disabled(stato.inModoCliente)
            Button {
                stato.cercaOvunque()
            } label: {
                HStack(spacing: Tema.Misura.Shell.pulsanteVetroSpazio) {
                    Image(systemName: "magnifyingglass")
                    Text("Cerca ovunque")
                    TastoBarra(testo: "⌘K")
                }
            }
            Button {
                stato.alternaSchermoIntero()
            } label: {
                Label(stato.schermoIntero ? "Esci da schermo intero" : "Schermo intero",
                      systemImage: stato.schermoIntero ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
        }
        .buttonStyle(StilePulsanteVetro())
        .labelStyle(EtichettaPulsante())
        .padding(.top, Tema.Misura.Shell.pulsantiAlto)
    }

    private var intestazioneBacheca: some View {
        HStack {
            Text("La tua giornata")
                .font(Tema.Testo.sezione)
                .tracking(Tema.Testo.spaziaturaSezione)
                .foregroundColor(Tema.Colore.inchiostroSfondo)
                .aloneSfondo()
            Spacer()
            Button {
                stato.pannelloAppAperte = true
            } label: {
                HStack(spacing: Tema.Misura.Shell.pulsanteVetroSpazio) {
                    Text(testoAppAperte)
                    Image(systemName: "square.grid.2x2.fill")
                }
            }
            .buttonStyle(StilePulsanteVetro(piccolo: true))
        }
        .padding(.top, Tema.Misura.Shell.sezioneAlto)
        .padding(.bottom, Tema.Misura.Shell.sezioneBasso)
        .padding(.horizontal, Tema.Misura.Shell.sezioneLato)
    }

    private var testoAppAperte: String {
        switch stato.finestre.count {
        case 0: return "Nessuna app aperta"
        case 1: return "1 app aperta"
        default: return "\(stato.finestre.count) app aperte"
        }
    }

    private var piede: some View {
        HStack {
            Text("Un clic per entrare. Il dock per cambiare app.")
            Spacer()
            Text(stato.dati.impostazioni.backup.ultimo.map { "Ultimo backup: \(Formati.dataOra.string(from: $0)) · archivio locale" }
                 ?? "Nessun backup ancora · archivio locale")
        }
        .font(Tema.Testo.Shell.piede)
        .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
        .lineLimit(1)
        .aloneSfondo()
        .padding(.horizontal, Tema.Misura.Shell.sezioneLato)
        .padding(.top, Tema.Misura.Shell.piedeAlto)
    }
}

/// Icona + testo dei pulsanti di vetro, con lo spazio del tema.
struct EtichettaPulsante: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Tema.Misura.Shell.pulsanteVetroSpazio) {
            configuration.icon
            configuration.title
        }
    }
}

/// Pulsante di vetro sullo sfondo (.gbtn del tema): capsula di vetro sottile, più chiara al passaggio,
/// molla alla pressione. `piccolo`: alto 30 invece di 34.
struct StilePulsanteVetro: ButtonStyle {
    var piccolo = false

    func makeBody(configuration: Configuration) -> some View {
        CorpoPulsanteVetro(etichetta: configuration.label, piccolo: piccolo, premuto: configuration.isPressed)
    }
}

private struct CorpoPulsanteVetro<Etichetta: View>: View {
    let etichetta: Etichetta
    let piccolo: Bool
    let premuto: Bool
    @State var sopra = false
    @Environment(\.isEnabled) var abilitato

    var body: some View {
        etichetta
            .font(piccolo ? Tema.Testo.pulsantePiccolo : Tema.Testo.pulsante)
            .foregroundColor(Tema.Colore.inchiostro)
            .lineLimit(1)
            .padding(.horizontal, piccolo ? Tema.Misura.Shell.pulsanteVetroPiccoloMargine : Tema.Misura.Shell.pulsanteVetroMargine)
            .frame(height: piccolo ? Tema.Misura.pulsanteVetroPiccolo : Tema.Misura.pulsanteVetro)
            .contentShape(Capsule(style: .continuous))
            .vetro(.leggero, forma: .capsula, tinta: sopra ? Tema.Colore.Shell.passaggioVetro : nil, interattivo: true)
            .scaleEffect(premuto ? Tema.Moto.scalaPressione : 1)
            .animation(Tema.Moto.molla, value: premuto)
            .opacity(abilitato ? 1 : Tema.Misura.Shell.opacitaDisabilitato)
            .onHover { sopra = $0 }
    }
}
