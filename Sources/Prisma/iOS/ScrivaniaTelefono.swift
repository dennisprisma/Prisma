#if os(iOS)
import SwiftUI

/// La scrivania del tema sul telefono (`@media (max-width: 760px)` di Design/tema-liquid-glass.html): sotto la barra,
/// il saluto, i pulsanti di vetro, «La tua giornata» e i sei widget del Mac uno sotto l'altro a larghezza piena
/// (alti 330 / 310 / 64 / 300 / 280 / 250, come il tema), poi il piede. Comincia sotto la barra e scorre sotto il dock.
/// I widget sono quelli del Mac: aprono le app con `stato.apri` dal punto toccato (`misuraOrigine`), e StatoMobile
/// porta l'app nella finestra di vetro.
struct ScrivaniaTelefono: View {
    /// Dove comincia la scrivania (sotto la barra) e quanto lasciare in basso (il dock).
    let alto: CGFloat
    let basso: CGFloat
    /// Solo istantanee: la scrivania parte già scorsa fino al piede.
    var inFondo = false

    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile

    private typealias S = Tema.Misura.Mobile.Scrivania

    /// L'ancora del piede (istantanee in fondo alla scrivania).
    static let ancoraPiede = "piede"
    static let attesaInFondo: Double = 0.3

    var body: some View {
        ScrollViewReader { lettore in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    introduzione
                    intestazioneBacheca
                    bacheca
                    piede
                    // Lo spazio del dock, in fondo: la scrivania scorre fino a mostrare il piede sopra il dock
                    Color.clear
                        .frame(height: basso)
                        .id(Self.ancoraPiede)
                }
                .padding(.horizontal, S.margineTelefono)
                .padding(.top, S.alto)
            }
            // Come .desk del tema: comincia sotto la barra (lì si taglia) e scorre sotto il dock
            .onAppear {
                guard inFondo else { return }
                // A impaginazione fatta: prima la ScrollView non sa ancora dov'è il piede
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.attesaInFondo) {
                    lettore.scrollTo(Self.ancoraPiede, anchor: .bottom)
                }
            }
        }
        .padding(.top, alto)
    }

    /// .hero: il saluto con il sottotitolo, poi i pulsanti di vetro a capo (flex-wrap del tema).
    private var introduzione: some View {
        VStack(alignment: .leading, spacing: S.salutoPulsanti) {
            SalutoScrivaniaMobile(carattere: Tipo.Mobile.salutoTelefono, spaziatura: Tipo.Mobile.spaziaturaSaluto)
            HStack(spacing: Tema.Misura.Shell.pulsantiSpazio) {
                Button {
                    stato.cercaOvunque()
                } label: {
                    Label("Cerca ovunque", systemImage: "magnifyingglass")
                }
                Button {
                    stato.apriGuida(.introduzione(0))
                } label: {
                    Label("Come funziona", systemImage: "questionmark.circle")
                }
            }
            .buttonStyle(StilePulsanteVetro())
            .labelStyle(EtichettaPulsante())
            .gruppoVetro()
        }
        .padding(.top, S.salutoAlto)
    }

    /// .sec-head: «La tua giornata» e quante app sono aperte (apre «Tutte le app»).
    private var intestazioneBacheca: some View {
        HStack {
            Text("La tua giornata")
                .font(Tema.Testo.sezione)
                .tracking(Tema.Testo.spaziaturaSezione)
                .foregroundColor(Tema.Colore.inchiostroSfondo)
                .aloneSfondo()
            Spacer(minLength: Tema.Misura.Shell.pulsantiSpazio)
            Button {
                mobile.pannello = .tutteLeApp
            } label: {
                HStack(spacing: Tema.Misura.Shell.pulsanteVetroSpazio) {
                    TestoAppAperteMobile()
                    Image(systemName: "square.grid.2x2.fill")
                }
            }
            .buttonStyle(StilePulsanteVetro(piccolo: true))
        }
        .padding(.top, Tema.Misura.Shell.sezioneAlto)
        .padding(.bottom, Tema.Misura.Shell.sezioneBasso)
        .padding(.horizontal, Tema.Misura.Shell.sezioneLato)
    }

    /// .board a una colonna: i sei widget del Mac, i vetri campionati insieme.
    private var bacheca: some View {
        VStack(spacing: Tema.Misura.grigliaSpazio) {
            WidgetAgenda().frame(height: S.agenda)
            WidgetCliente().frame(height: S.cliente)
            WidgetEve().frame(height: Tema.Misura.widgetEve)
            WidgetAttivita().frame(height: S.attivita)
            WidgetScadenze().frame(height: S.scadenze)
            WidgetPortafoglio().frame(height: S.portafoglio)
        }
        .gruppoVetro()
    }

    /// .foot: le due frasi vanno a capo una sotto l'altra (flex-wrap del tema).
    private var piede: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Mobile.spazioTesto) {
            Text("Un tocco per entrare. Il dock per cambiare app.")
            Text(PiedeScrivaniaMobile.backup(stato))
        }
        .font(Tema.Testo.Shell.piede)
        .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
        .fixedSize(horizontal: false, vertical: true)
        .aloneSfondo()
        .padding(.horizontal, Tema.Misura.Shell.sezioneLato)
        .padding(.top, Tema.Misura.Shell.piedeAlto)
    }
}

/// Il saluto della scrivania (.hero h1 e p): «Buongiorno, Denis.» sull'acqua, aggiornato ogni minuto (solo lui).
struct SalutoScrivaniaMobile: View {
    @EnvironmentObject var stato: StatoShell
    let carattere: Font
    let spaziatura: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Shell.salutoSpazio) {
            TimelineView(.everyMinute) { contesto in
                Text(Self.saluto(contesto.date, nome: stato.nomeUtente))
                    .font(carattere)
                    .tracking(spaziatura)
                    .foregroundColor(Tema.Colore.inchiostroSfondo)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text("Tutto il tuo lavoro, a portata di mano.")
                .font(Tema.Testo.sottotitoloSaluto)
                .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
        }
        .aloneSfondo()
    }

    /// Lo stesso saluto della scrivania del Mac: prima delle 13 buongiorno, prima delle 18 buon pomeriggio.
    static func saluto(_ ora: Date, nome: String) -> String {
        let h = Calendar.current.component(.hour, from: ora)
        let s = h < 13 ? "Buongiorno" : h < 18 ? "Buon pomeriggio" : "Buonasera"
        return "\(s), \(nome)."
    }
}

/// Quante app sono aperte: osserva solo le finestre, così la scrivania non si ricalcola quando si apre un'app.
struct TestoAppAperteMobile: View {
    @EnvironmentObject var sistema: StatoFinestre

    var body: some View {
        Text(testo)
    }

    private var testo: String {
        switch sistema.elenco.count {
        case 0: return "Nessuna app aperta"
        case 1: return "1 app aperta"
        default: return "\(sistema.elenco.count) app aperte"
        }
    }
}

/// Il testo del piede della scrivania (.foot): l'ultimo backup, come sul Mac.
enum PiedeScrivaniaMobile {
    static func backup(_ stato: StatoShell) -> String {
        stato.dati.impostazioni.backup.ultimo.map { "Ultimo backup: \(Formati.dataOra.string(from: $0)) · archivio locale" }
            ?? "Nessun backup ancora · archivio locale"
    }
}
#endif
