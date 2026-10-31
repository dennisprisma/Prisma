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

    /// In alto, sull'acqua: la data e il saluto (Design/iphone.html). Cerca e le app aperte stanno nella barra e nel dock.
    private var introduzione: some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Mobile.spazioTesto) {
            TimelineView(.everyMinute) { contesto in
                Text(Formati.dataLunga.string(from: contesto.date).prefix(1).uppercased() + Formati.dataLunga.string(from: contesto.date).dropFirst())
                    .font(Tipo.Mobile.dataSaluto)
                    .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
            }
            SalutoScrivaniaMobile(carattere: Tipo.Mobile.salutoTelefono, spaziatura: Tipo.Mobile.spaziaturaSaluto, sottotitolo: false)
        }
        .aloneSfondo()
        .padding(.top, S.salutoAlto)
        .padding(.horizontal, Tema.Misura.Shell.sezioneLato)
        .padding(.bottom, Tema.Misura.Shell.sezioneBasso * 2)
    }

    /// .board a una colonna, in ordine di importanza (Design/iphone.html): il prossimo incontro in grande, ciò che
    /// richiede attenzione, Eve, il portafoglio. Alti quanto il contenuto; i vetri campionati insieme.
    private var bacheca: some View {
        VStack(spacing: Tema.Misura.grigliaSpazio) {
            WidgetIncontroTelefono()
            WidgetAttenzioneTelefono()
            BarraEveTelefono()
            WidgetPortafoglio().frame(height: Tema.Misura.ScrivaniaTelefono.portafoglio)
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
    /// «Tutto il tuo lavoro, a portata di mano.» sotto il saluto (sull'iPhone c'è la data sopra, al suo posto).
    var sottotitolo = true

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
            if sottotitolo {
                Text("Tutto il tuo lavoro, a portata di mano.")
                    .font(Tema.Testo.sottotitoloSaluto)
                    .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
            }
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
