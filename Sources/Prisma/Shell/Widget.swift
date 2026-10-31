import SwiftUI

/// Bacheca dei widget della scrivania (tema «Liquid Glass»): sei pannelli di vetro, come nel tema.
///
///   ┌──────── Agenda ────────┐┌── Cliente in primo piano ──┐
///   │                        ││                            │
///   │                        │├──────── Eve (barra) ───────┤
///   └────────────────────────┘└────────────────────────────┘
///   ┌─ Da fare ─┐┌─ Scadenze ─┐┌─ Portafoglio ─┐
struct BachecaWidget: View {
    /// Il blocco: con la schermata di benvenuto i widget escono, allo sblocco rientrano uno dopo l'altro.
    @EnvironmentObject var sistema: StatoFinestre
    @Environment(\.modoIstantanea) private var istantanea
    /// Vero poco dopo la prima comparsa: all'apertura di Prisma i widget entrano uno dopo l'altro.
    @State private var avviato = false
    /// La prima entrata (all'apertura di Prisma) ha i tempi dell'avvio; le altre quelli dello sblocco.
    @State private var primaEntrata = true

    var body: some View {
        GeometryReader { geo in
            let s = Tema.Misura.grigliaSpazio
            let eve = Tema.Misura.widgetEve
            // Righe 1fr / 64 / 1.04fr
            let fila = max(0, (geo.size.height - eve - 2 * s) / (1 + Tema.Misura.Shell.quotaFilaBassa))
            let meta = max(0, (geo.size.width - s) / 2)
            let terzo = max(0, (geo.size.width - 2 * s) / 3)
            VStack(spacing: s) {
                HStack(spacing: s) {
                    entrata(WidgetAgenda().frame(width: meta), 0)
                    VStack(spacing: s) {
                        entrata(WidgetCliente(), 1)
                        entrata(WidgetEve(), 2)
                    }
                    .frame(width: meta)
                }
                .frame(height: fila + s + eve)
                HStack(spacing: s) {
                    entrata(WidgetAttivita().frame(width: terzo), 3)
                    entrata(WidgetScadenze().frame(width: terzo), 4)
                    entrata(WidgetPortafoglio().frame(width: terzo), 5)
                }
            }
            // I sei vetri si campionano insieme (vetro nativo di macOS 26)
            .gruppoVetro()
        }
        .onAppear {
            guard !istantanea, !avviato else { return }
            // Con la schermata di benvenuto davanti, la prima entrata è quella dello sblocco
            if sistema.bloccato { primaEntrata = false }
            // Il ritardo dell'avvio: il primo disegno della scrivania cade prima del primo fotogramma animato
            DispatchQueue.main.asyncAfter(deadline: .now() + Tema.Moto.Avvio.ritardo) { avviato = true }
        }
        .onChange(of: sistema.bloccato) { bloccato in
            if bloccato { primaEntrata = false }
        }
    }

    /// Nascosti prima dell'avvio e con Prisma bloccata; nelle istantanee sempre al loro posto, fermi.
    private var nascosto: Bool { !istantanea && (sistema.bloccato || !avviato) }

    /// Entrata sfalsata di un widget (solo opacità, spostamento e scala del widget stesso). Stessa vista
    /// con i tempi dell'avvio o dello sblocco: cambiare i tempi non ricostruisce il widget.
    private func entrata<W: View>(_ widget: W, _ indice: Int) -> some View {
        let avvio = primaEntrata
        return widget.entrataSfalsata(indice: indice, nascosto: nascosto,
                                      curva: avvio ? Tema.Moto.Avvio.widget : Tema.Moto.Sblocco.widget,
                                      sfalsamento: avvio ? Tema.Moto.Avvio.sfalsamento : Tema.Moto.Sblocco.sfalsamentoWidget,
                                      spostamento: avvio ? Tema.Moto.Avvio.spostamento : Tema.Moto.Sblocco.widgetSpostamento,
                                      scala: avvio ? Tema.Moto.Avvio.scala : Tema.Moto.Sblocco.widgetScala)
    }
}

/// Il centro di un pulsante nelle coordinate della shell, da cui si apre l'app. Una classe: si aggiorna
/// senza ridisegnare nulla e si legge solo al clic.
final class OrigineApertura {
    var punto: CGPoint?
}

extension View {
    /// Tiene aggiornato in `origine` il centro della vista nello spazio della shell (ShellView.spazioShell).
    func misuraOrigine(_ origine: OrigineApertura) -> some View {
        background {
            GeometryReader { geo in
                let cornice = geo.frame(in: CoordinateSpace.named(ShellView.spazioShell))
                Color.clear
                    .onAppear { origine.punto = CGPoint(x: cornice.midX, y: cornice.midY) }
                    .onChange(of: cornice) { c in origine.punto = CGPoint(x: c.midX, y: c.midY) }
            }
        }
    }
}

// MARK: - Cornice comune

extension View {
    /// Cornice dei widget: vetro spesso del tema (raggio 26), contenuto tagliato alla forma.
    /// Dentro, chip e pulsanti di vetro restano quelli chiari del tema: stanno sul vetro, non su schede bianche.
    func corniceWidget(raggio: CGFloat = Tema.Raggio.widget) -> some View {
        let forma = FormaVetro.arrotondata(raggio)
        return frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environment(\.chipDelTema, true)
            .clipShape(forma)
            .vetro(.spesso, forma: forma)
    }

    /// Elenco che sfuma negli ultimi punti in basso (.w-scroll del tema).
    func sfumaInBasso() -> some View {
        mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: Tema.Misura.RifinitureScrivania.sfumaturaElenco)
            }
        }
    }
}

/// Collegamento a un'app nella testata di un widget: capsula chiara con il testo del colore dei link.
struct CollegamentoApp: View {
    @EnvironmentObject var stato: StatoShell
    let testo: String
    let app: AppPrisma
    /// Da fare prima di aprire l'app (per esempio scegliere il portafoglio).
    var prima: (() -> Void)? = nil
    /// L'app si apre dal collegamento.
    @State private var origine = OrigineApertura()

    var body: some View {
        Button {
            prima?()
            stato.apriApp(app, da: origine.punto)
        } label: {
            Text(testo)
                .font(Tema.Testo.Shell.collegamento)
                .foregroundColor(Tema.Colore.link)
                .lineLimit(1)
                .padding(.horizontal, Tema.Misura.Shell.collegamentoMargine)
                .frame(height: Tema.Misura.testaWidget)
                .vetro(.chip, forma: .capsula)
        }
        .buttonStyle(StileSemplice())
        .misuraOrigine(origine)
    }
}

/// Testata di un widget (.w-head): icona dell'app, titolo e collegamento a destra.
struct IntestazioneWidget<Destra: View>: View {
    let titolo: String
    var icona: AppPrisma? = nil
    @ViewBuilder let destra: () -> Destra

    var body: some View {
        HStack(spacing: Tema.Misura.Shell.testaSpazio) {
            if let icona {
                IconaApp(app: icona, lato: Tema.Misura.Shell.iconaWidget)
            }
            Text(titolo)
                .font(Tema.Testo.Shell.titoloWidget)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
            Spacer(minLength: 0)
            destra()
        }
        .frame(minHeight: Tema.Misura.testaWidget)
        .padding(.bottom, Tema.Misura.Shell.testaSpazio)
    }
}

/// Messaggio di un elenco vuoto.
private struct ElencoVuoto: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(Tema.Testo.Shell.secondarioRiga)
            .foregroundColor(Tema.Colore.inchiostroSecondario)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tema.Misura.Shell.rigaMargine)
    }
}

// MARK: - Agenda: il giorno e i prossimi incontri

struct WidgetAgenda: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        // Il contenuto si rifà solo con dati dei calcoli nuovi, un altro giorno o un'altra ora: non a ogni
        // nota, messaggio di Eve o cliente scelto
        CorpoWidgetAgenda(stato: stato, chiave: stato.chiaveVista)
            .equatable()
            .padding(Tema.Misura.widgetMargine)
            .corniceWidget()
    }
}

/// Il giorno e i prossimi incontri. Non osserva StatoShell (lo riceve per i dati in cache e per le azioni):
/// si ridisegna quando cambia la chiave, e il giorno grande anche ogni minuto (TimelineView).
private struct CorpoWidgetAgenda: View, Equatable {
    let stato: StatoShell
    let chiave: ChiaveVista

    nonisolated static func == (a: CorpoWidgetAgenda, b: CorpoWidgetAgenda) -> Bool { a.chiave == b.chiave }
    /// Il Portafoglio si apre dalla riga delle proposte ferme.
    @State private var origineSeguito = OrigineApertura()

    var body: some View {
        #if os(iOS)
        // iPhone e iPad: il widget può essere stretto (una colonna sul telefono, due sull'iPad in verticale).
        // La regola del tema `@container w (max-width: 430px)`: colonna del giorno 96 e numero a 50 punti.
        // Sul Mac (finestra di almeno 1100 punti, widget di almeno 480) non scatta mai: il ramo resta quello di sempre
        GeometryReader { geo in
            Group {
                if geo.size.width < Tema.Misura.Shell.sogliaAgendaTelefono {
                    // Sul telefono il giorno va in una riga in alto e gli incontri prendono tutta la larghezza:
                    // con la colonna del giorno a fianco nomi, titoli e luoghi si tagliavano
                    corpoTelefono
                } else {
                    corpo(stretto: geo.size.width < Tema.Misura.Shell.sogliaAgendaStretta)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        #else
        corpo(stretto: false)
        #endif
    }

    private func corpo(stretto: Bool) -> some View {
        HStack(spacing: 0) {
            TimelineView(.everyMinute) { contesto in
                giorno(contesto.date, stretto: stretto)
            }
            .frame(width: stretto ? Tema.Misura.Shell.colonnaGiornoStretta : Tema.Misura.Shell.colonnaGiorno)
            Rectangle().fill(Tema.Colore.separatore).frame(width: Tema.Misura.filo)
            incontri
                .padding(.leading, Tema.Misura.widgetMargine)
        }
    }

    #if os(iOS)
    /// Il telefono: «Venerdì 30 ottobre» e il riepilogo di oggi in una riga, sotto gli incontri a tutta larghezza.
    private var corpoTelefono: some View {
        VStack(alignment: .leading, spacing: 0) {
            TimelineView(.everyMinute) { contesto in
                let oggi = contesto.date
                let incontriOggi = stato.appuntamentiDiOggi.count
                HStack(alignment: .firstTextBaseline, spacing: Tema.Misura.Shell.rigaSpazio) {
                    Text(Formati.giornoSettimana.string(from: oggi).capitalized)
                        .font(Tema.Testo.Shell.giornoSettimana)
                        .foregroundColor(Tema.Colore.rosso)
                    Text(Formati.giorno.string(from: oggi) + " " + (Formati.meseAnno.string(from: oggi).components(separatedBy: " ").first ?? ""))
                        .font(Tema.Testo.Shell.giornoAgendaTelefono)
                        .foregroundColor(Tema.Colore.inchiostro)
                    Spacer(minLength: Tema.Misura.Shell.rigaSpazio)
                    Text(incontriOggi == 0 ? "Nessun incontro oggi" : "\(incontriOggi) \(incontriOggi == 1 ? "incontro" : "incontri") oggi")
                        .font(Tema.Testo.Shell.riepilogoAgenda)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
                .lineLimit(1)
            }
            .padding(.horizontal, Tema.Misura.Shell.colonnaGiornoStrettaMargine.leading)
            .padding(.bottom, Tema.Misura.widgetMargine / 2)
            Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo)
                .padding(.bottom, Tema.Misura.widgetMargine / 2)
            incontri
        }
    }
    #endif

    /// Il giorno grande: giorno della settimana in rosso, numero, mese e il riepilogo di oggi.
    /// `stretto`: la colonna stretta del tema (solo su iPhone e iPad).
    private func giorno(_ oggi: Date, stretto: Bool) -> some View {
        let incontriOggi = stato.appuntamentiDiOggi.count
        let prossimo = stato.prossimiAppuntamenti.first { $0.inizio >= oggi }
        // Le proposte ferme (cache oraria, leggera: niente motori del Portafoglio)
        let ferme = stato.proposteInSospeso
        return VStack(alignment: .leading, spacing: 0) {
            Text(Formati.giornoSettimana.string(from: oggi).capitalized)
                .font(Tema.Testo.Shell.giornoSettimana)
                .foregroundColor(Tema.Colore.rosso)
            Text(Formati.giorno.string(from: oggi))
                .font(stretto ? Tema.Testo.Shell.giornoAgendaStretto : Tema.Testo.giornoAgenda)
                .tracking(stretto ? Tema.Testo.Shell.spaziaturaGiornoAgendaStretto : Tema.Testo.spaziaturaGiornoAgenda)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(Formati.meseAnno.string(from: oggi).components(separatedBy: " ").first ?? "")
                .font(Tema.Testo.Shell.meseAgenda)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
            Spacer(minLength: Tema.Misura.Shell.rigaMargine)
            Text(incontriOggi == 0 ? "Nessun incontro oggi" : "\(incontriOggi) \(incontriOggi == 1 ? "incontro" : "incontri") oggi")
                .font(Tema.Testo.Shell.riepilogoAgendaForte)
                .foregroundColor(Tema.Colore.inchiostro)
            if let p = prossimo {
                Text("Il prossimo: \(Formati.giornoRelativo(p.inizio).lowercased()) alle \(Formati.ora.string(from: p.inizio))")
                    .font(Tema.Testo.Shell.riepilogoAgenda)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Tema.Misura.Shell.rigaTestoSpazio)
            }
            if !ferme.isEmpty {
                // Le proposte che aspettano una risposta: il pannello «Proposte da riprendere» del Portafoglio
                Button {
                    stato.posizioneInDettaglio = nil
                    stato.portafoglio = true
                    stato.ancoraPosizioni = "seguito"
                    stato.apriApp(.posizioni, da: origineSeguito.punto)
                } label: {
                    Text(TestiSeguito.aspettano(ferme.count))
                        .font(Tema.Testo.Shell.riepilogoAgenda)
                        .foregroundColor(ferme.contains { $0.urgente } ? Colori.Seguito.urgente : Colori.Seguito.ferma)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(StileSemplice())
                .misuraOrigine(origineSeguito)
                .padding(.top, Tema.Misura.Shell.rigaTestoSpazio)
            }
        }
        .padding(stretto ? Tema.Misura.Shell.colonnaGiornoStrettaMargine : Tema.Misura.Shell.colonnaGiornoMargine)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var incontri: some View {
        VStack(alignment: .leading, spacing: 0) {
            IntestazioneWidget(titolo: "Prossimi incontri") {
                CollegamentoApp(testo: "Apri Agenda", app: .agenda)
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    let eventi = Array(stato.prossimiAppuntamenti.prefix(6))
                    if eventi.isEmpty {
                        ElencoVuoto(testo: "Nessun appuntamento in programma.")
                    }
                    ForEach(eventi) { e in
                        RigaIncontro(evento: e, cliente: stato.cliente(e.clienteId)) {
                            stato.clienteAttivoId = e.clienteId
                            stato.mostraInAgenda(e)
                        }
                    }
                }
            }
            .sfumaInBasso()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Un incontro nel widget dell'Agenda: barretta del colore del cliente, nome e titolo, giorno e ora a destra.
private struct RigaIncontro: View {
    let evento: Appuntamento
    let cliente: Cliente?
    let azione: () -> Void

    var body: some View {
        let m = Tema.Misura.Shell.self
        Button(action: azione) {
            HStack(spacing: m.rigaSpazio) {
                Capsule(style: .continuous)
                    .fill(cliente?.tinta.colori.basso ?? Tema.Colore.accento)
                    .frame(width: m.barrettaEvento)
                VStack(alignment: .leading, spacing: m.rigaTestoSpazio) {
                    Text(cliente?.nome ?? evento.titolo)
                        .font(Tema.Testo.Shell.nomeRiga)
                        .foregroundColor(Tema.Colore.inchiostro)
                    Text(evento.titolo)
                        .font(Tema.Testo.Shell.secondarioRiga)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: m.rigaTestoSpazio) {
                    Text(Formati.giornoRelativo(evento.inizio))
                        .font(Tema.Testo.Shell.nomeRiga)
                        .foregroundColor(Tema.Colore.inchiostro)
                    Text("\(Formati.ora.string(from: evento.inizio)) · \(evento.luogo)")
                        .font(Tema.Testo.Shell.secondarioRiga)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
                .lineLimit(1)
            }
            .padding(m.rigaMargine)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }
}

// MARK: - Cliente in primo piano

struct WidgetCliente: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        // Il contenuto si rifà solo con dati dei calcoli nuovi (anche la nota del cliente), un altro cliente
        // in primo piano, un altro giorno o un'altra ora
        CorpoWidgetCliente(stato: stato, chiave: stato.chiaveVista, attivo: stato.clienteAttivoId)
            .equatable()
            .padding(Tema.Misura.widgetMargine)
            .corniceWidget()
    }
}

/// Il cliente in primo piano: non osserva StatoShell (lo riceve per i dati in cache e per le azioni).
private struct CorpoWidgetCliente: View, Equatable {
    let stato: StatoShell
    let chiave: ChiaveVista
    /// Il cliente in primo piano: non entra nei calcoli, quindi va nella chiave a parte.
    let attivo: String
    @State private var sceltaCliente = false
    /// I pulsanti in basso: le app si aprono da lì.
    @State private var origineScheda = OrigineApertura()
    @State private var originePosizioni = OrigineApertura()
    @State private var origineEve = OrigineApertura()

    nonisolated static func == (a: CorpoWidgetCliente, b: CorpoWidgetCliente) -> Bool {
        a.chiave == b.chiave && a.attivo == b.attivo
    }

    /// I numeri del cliente, calcolati una volta sola per tutte le varianti.
    private struct Numeri {
        let riepilogo: RiepilogoPosizioni
        let incontro: String
        let aperte: Int
    }

    var body: some View {
        let id = attivo
        let numeri = Numeri(riepilogo: stato.riepilogoPosizioniCliente(id),
                            incontro: stato.prossimiAppuntamenti.first { $0.clienteId == id }
                                .map { "\(Formati.giornoRelativo($0.inizio)), \(Formati.ora.string(from: $0.inizio))" } ?? "—",
                            aperte: stato.attivitaAperte.filter { $0.clienteId == id }.count)
        // Su schermi più bassi il widget si accorcia invece di accavallarsi agli altri: ViewThatFits
        // misura l'altezza che serve a ogni variante e prende la prima che ci sta, in quest'ordine:
        // tutto; senza la nota; con la nota ma senza i pulsanti; senza nota né pulsanti; una riga di numeri
        // con i pulsanti; solo quella;
        // poi la sola testata, che entra sempre.
        // Il GeometryReader fissa la misura del widget alla sua cella: anche l'ultima variante,
        // se mai non ci stesse, resta dentro la cornice invece di sporgere sui vicini.
        GeometryReader { geo in
            // Sul telefono i numeri vanno su due colonne e i canali sotto il nome: su tre colonne si tagliavano
            let telefono = Self.telefono(geo.size.width)
            ViewThatFits(in: .vertical) {
                contenuto(numeri, righe: 2, nota: true, pulsanti: true, telefono: telefono)
                contenuto(numeri, righe: 2, nota: false, pulsanti: true, telefono: telefono)
                contenuto(numeri, righe: 2, nota: true, pulsanti: false, telefono: telefono)
                contenuto(numeri, righe: 2, nota: false, pulsanti: false, telefono: telefono)
                contenuto(numeri, righe: 1, nota: false, pulsanti: true, telefono: telefono)
                contenuto(numeri, righe: 1, nota: false, pulsanti: false, telefono: telefono)
                contenuto(numeri, righe: 0, nota: false, pulsanti: false, telefono: telefono)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    /// Il widget è largo quanto un telefono (mai sul Mac).
    private static func telefono(_ larghezza: CGFloat) -> Bool {
        #if os(iOS)
        return larghezza < Tema.Misura.Shell.sogliaAgendaTelefono
        #else
        return false
        #endif
    }

    private func contenuto(_ n: Numeri, righe: Int, nota: Bool, pulsanti: Bool, telefono: Bool = false) -> some View {
        let r = n.riepilogo
        let m = Tema.Misura.Shell.self
        let proposte = r.proposteAperte == 0 ? "nessuna" : "\(r.proposteAperte) · \(Formati.euro(r.valoreProposte))"
        return VStack(alignment: .leading, spacing: m.clienteSpazio) {
            testata(telefono: telefono)
            // I numeri (.kpis): griglia di tre colonne sul chip di vetro (due sul telefono, i quattro che contano)
            if righe >= 1 {
                VStack(alignment: .leading, spacing: m.kpiSpazioRighe) {
                    if telefono {
                        HStack(alignment: .top, spacing: m.kpiSpazioColonne) {
                            dato("Patrimonio netto", Formati.euro(r.patrimonioNetto))
                            dato("Prossimo incontro", n.incontro)
                        }
                        if righe >= 2 {
                            HStack(alignment: .top, spacing: m.kpiSpazioColonne) {
                                dato("Da fare", "\(n.aperte) attività")
                                dato("Proposte aperte", proposte)
                            }
                        }
                    } else {
                        HStack(alignment: .top, spacing: m.kpiSpazioColonne) {
                            dato("Patrimonio netto", Formati.euro(r.patrimonioNetto))
                            dato("Prossimo incontro", n.incontro)
                            dato("Da fare", "\(n.aperte) attività")
                        }
                        if righe >= 2 {
                            HStack(alignment: .top, spacing: m.kpiSpazioColonne) {
                                dato("Capitale assicurato", Formati.euro(r.capitaleAssicurato))
                                dato("Premi annui", Formati.euro(r.premiAnnui))
                                dato("Proposte aperte", proposte)
                            }
                        }
                    }
                }
                .padding(m.kpiMargine)
                .frame(maxWidth: .infinity, alignment: .leading)
                .vetro(.chip, forma: .arrotondata(Tema.Raggio.kpi))
            }
            if nota, let testo = stato.clienteAttivo?.nota, !testo.isEmpty {
                Text(testo)
                    .font(Tema.Testo.Shell.notaCliente)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if pulsanti {
                // Lo Spacer solo qui: nelle varianti senza pulsanti costerebbe comunque lo spazio della pila
                Spacer(minLength: 0)
                HStack(spacing: m.pulsantiSpazio) {
                    Button("Apri la scheda") { stato.apri(.clienti, da: origineScheda.punto) }
                        .misuraOrigine(origineScheda)
                    Button("Posizioni") {
                        stato.portafoglio = false
                        stato.apri(.posizioni, da: originePosizioni.punto)
                    }
                    .misuraOrigine(originePosizioni)
                    Button("Chiedi a Eve") { stato.apri(.eve, da: origineEve.punto) }
                        .misuraOrigine(origineEve)
                }
                .buttonStyle(StileVetro())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Avatar, occhiello, nome (con la scelta del cliente), tema e canali (sul telefono sotto il tema).
    private func testata(telefono: Bool) -> some View {
        let m = Tema.Misura.Shell.self
        return HStack(alignment: .center, spacing: m.rigaSpazio) {
            if let c = stato.clienteAttivo {
                AvatarCliente(iniziali: c.iniziali, tinta: c.tinta.colori, lato: m.avatarCliente)
            }
            VStack(alignment: .leading, spacing: m.rigaTestoSpazio) {
                Text("Cliente in primo piano")
                    .font(Tema.Testo.Shell.occhielloCliente)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                Button { sceltaCliente = true } label: {
                    HStack(spacing: m.pulsanteBarraSpazio) {
                        Text(stato.clienteAttivo?.nome ?? "Nessun cliente")
                            .font(Tema.Testo.nomeCliente)
                            .tracking(Tema.Testo.Shell.spaziaturaNomeCliente)
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(Tema.Testo.Shell.chevron)
                    }
                    .foregroundColor(Tema.Colore.inchiostro)
                }
                .buttonStyle(StileSemplice())
                .popover(isPresented: $sceltaCliente, arrowEdge: .bottom) { ElencoClienti(aperto: $sceltaCliente) }
                Text(stato.clienteAttivo?.tema ?? "")
                    .font(Tema.Testo.Shell.temaCliente)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                    .lineLimit(1)
                if telefono {
                    HStack(spacing: m.canaliSpazio) {
                        ForEach(stato.clienteAttivo?.canali ?? []) { EtichettaCanale(canale: $0, compatta: true) }
                    }
                }
            }
            Spacer(minLength: 0)
            if !telefono {
                VStack(alignment: .trailing, spacing: m.canaliSpazio) {
                    ForEach(stato.clienteAttivo?.canali ?? []) { CapsulaCanale(canale: $0) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dato(_ etichetta: String, _ valore: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Shell.rigaTestoSpazio) {
            Text(etichetta)
                .font(Tema.Testo.Shell.etichettaKpi)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .lineLimit(1)
            Text(valore)
                .font(Tema.Testo.Shell.valoreKpiWidget)
                .tracking(Tema.Testo.Shell.spaziaturaKpi)
                .foregroundColor(Tema.Colore.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Eve: la barra per ritrovare il filo

struct WidgetEve: View {
    @EnvironmentObject var stato: StatoShell
    /// Eve si apre dalla barra.
    @State private var origine = OrigineApertura()

    var body: some View {
        Button { stato.apri(.eve, da: origine.punto) } label: {
            HStack(spacing: Tema.Misura.Shell.rigaSpazio) {
                IconaApp(app: .eve, lato: Tema.Misura.Shell.iconaEve)
                VStack(alignment: .leading, spacing: Tema.Misura.Shell.rigaTestoSpazio) {
                    Text("Ritrova il filo con Eve.")
                        .font(Tema.Testo.Shell.titoloEve)
                        .foregroundColor(Tema.Colore.inchiostro)
                    Text(stato.evePortafoglio ? "Il tuo portafoglio, chi ricontattare, le scadenze" : "Incontri, sintesi e prossimi passi")
                        .font(Tema.Testo.Shell.testoEve)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Tema.Testo.Shell.chevron)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
            }
            .padding(.horizontal, Tema.Misura.widgetMargine)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
        .frame(height: Tema.Misura.widgetEve)
        .corniceWidget(raggio: Tema.Raggio.widgetEve)
        .frame(height: Tema.Misura.widgetEve)
        .misuraOrigine(origine)
    }
}

// MARK: - Da fare: le attività aperte

struct WidgetAttivita: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        // Il contenuto si rifà solo con dati dei calcoli nuovi, un altro giorno o un'altra ora
        CorpoWidgetAttivita(stato: stato, chiave: stato.chiaveVista)
            .equatable()
            .padding(Tema.Misura.widgetMargine)
            .corniceWidget()
    }
}

/// Le attività aperte: non osserva StatoShell (lo riceve per i dati in cache e per le azioni). Pila pigra:
/// con molti clienti le attività aperte sono centinaia, ma si impaginano solo le righe che si vedono.
private struct CorpoWidgetAttivita: View, Equatable {
    let stato: StatoShell
    let chiave: ChiaveVista

    nonisolated static func == (a: CorpoWidgetAttivita, b: CorpoWidgetAttivita) -> Bool { a.chiave == b.chiave }

    var body: some View {
        let aperte = stato.attivitaAperte
        let ultima = aperte.last?.id
        return VStack(alignment: .leading, spacing: 0) {
            IntestazioneWidget(titolo: aperte.isEmpty ? "Da fare" : "\(aperte.count) \(aperte.count == 1 ? "attività aperta" : "attività aperte")",
                               icona: .attivita) {
                CollegamentoApp(testo: "Apri Attività", app: .attivita)
            }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if aperte.isEmpty {
                        ElencoVuoto(testo: "Tutto fatto.")
                    }
                    ForEach(aperte) { a in
                        // Senza animazione: una transazione animata su `dati` muoverebbe tutte le viste delle attività
                        RigaAttivita(attivita: a, cliente: stato.cliente(a.clienteId), ultima: a.id == ultima) {
                            stato.alternaCompletata(a.id)
                        }
                    }
                }
            }
            .sfumaInBasso()
        }
    }
}

// MARK: - Scadenze: le posizioni in scadenza, con la tessera della data

struct WidgetScadenze: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        // Il contenuto si rifà solo con dati dei calcoli nuovi, un altro giorno o un'altra ora
        CorpoWidgetScadenze(stato: stato, chiave: stato.chiaveVista)
            .equatable()
            .padding(Tema.Misura.widgetMargine)
            .corniceWidget()
    }
}

/// Le posizioni in scadenza: non osserva StatoShell (lo riceve per i dati in cache e per le azioni).
private struct CorpoWidgetScadenze: View, Equatable {
    let stato: StatoShell
    let chiave: ChiaveVista

    nonisolated static func == (a: CorpoWidgetScadenze, b: CorpoWidgetScadenze) -> Bool { a.chiave == b.chiave }

    var body: some View {
        let scadenze = Array(stato.riepilogoTuttePosizioni.inScadenza.prefix(6))
        return VStack(alignment: .leading, spacing: 0) {
            IntestazioneWidget(titolo: "In scadenza entro \(RiepilogoPosizioni.giorniScadenza) giorni", icona: .posizioni) {
                CollegamentoApp(testo: "Apri Posizioni", app: .posizioni, prima: { stato.portafoglio = false })
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if scadenze.isEmpty {
                        ElencoVuoto(testo: "Nessuna nei prossimi \(RiepilogoPosizioni.giorniScadenza) giorni.")
                    }
                    ForEach(scadenze) { p in
                        riga(p)
                    }
                }
            }
            .sfumaInBasso()
        }
    }

    private func riga(_ p: Posizione) -> some View {
        let m = Tema.Misura.Shell.self
        let giorni = giorniAllaScadenza(p)
        let colore = p.scaduta || giorni <= 30 ? Tema.Colore.scadenzaOra : Tema.Colore.scadenzaVicina
        return Button { stato.apriPosizione(p) } label: {
            HStack(spacing: m.rigaSpazio) {
                PiastrellaData(data: p.scadenza ?? Date())
                VStack(alignment: .leading, spacing: m.rigaTestoSpazio) {
                    #if os(iOS)
                    // iPhone e iPad: il canale accanto al nome del cliente (riga corta), così prodotto e giorni
                    // alla scadenza hanno tutta la larghezza
                    HStack(spacing: m.rigaSpazio) {
                        Text(stato.cliente(p.clienteId)?.nome ?? "")
                            .font(Tema.Testo.Shell.secondarioRiga)
                            .foregroundColor(Tema.Colore.inchiostroSecondario)
                        Spacer(minLength: 0)
                        CapsulaCanale(canale: p.canale, compatta: true)
                    }
                    #else
                    Text(stato.cliente(p.clienteId)?.nome ?? "")
                        .font(Tema.Testo.Shell.secondarioRiga)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                    #endif
                    Text(p.nome)
                        .font(Tema.Testo.Shell.nomeRiga)
                        .foregroundColor(Tema.Colore.inchiostro)
                    HStack(spacing: 0) {
                        Text("\(p.area.nome) · ")
                            .foregroundColor(Tema.Colore.inchiostroSecondario)
                        Text(p.scaduta ? "scaduta" : giorni == 0 ? "scade oggi" : "scade tra \(giorni) \(giorni == 1 ? "giorno" : "giorni")")
                            .foregroundColor(colore)
                    }
                    .font(Tema.Testo.Shell.secondarioRiga)
                }
                .lineLimit(1)
                #if os(macOS)
                Spacer(minLength: 0)
                CapsulaCanale(canale: p.canale, compatta: true)
                #endif
            }
            .padding(m.rigaMargine)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
    }

    /// Giorni da oggi alla scadenza (0 se oggi o già passata).
    private func giorniAllaScadenza(_ p: Posizione) -> Int {
        guard let s = p.scadenza else { return 0 }
        let cal = Calendar.current
        let giorni = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: s)).day ?? 0
        return max(0, giorni)
    }
}

// MARK: - Portafoglio clienti: i numeri di tutti i clienti, per canale

struct WidgetPortafoglio: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        // Il contenuto si rifà solo con dati dei calcoli nuovi, un altro giorno o un'altra ora
        CorpoWidgetPortafoglio(stato: stato, chiave: stato.chiaveVista)
            .equatable()
            .padding(Tema.Misura.widgetMargine)
            .corniceWidget()
    }
}

/// I numeri di tutti i clienti: non osserva StatoShell (lo riceve per i dati in cache e per le azioni).
private struct CorpoWidgetPortafoglio: View, Equatable {
    let stato: StatoShell
    let chiave: ChiaveVista

    nonisolated static func == (a: CorpoWidgetPortafoglio, b: CorpoWidgetPortafoglio) -> Bool { a.chiave == b.chiave }

    var body: some View {
        let r = stato.riepilogoTuttePosizioni
        return VStack(alignment: .leading, spacing: 0) {
            IntestazioneWidget(titolo: "Portafoglio clienti", icona: .posizioni) {
                CollegamentoApp(testo: "Apri", app: .posizioni, prima: { stato.portafoglio = true })
            }
            // Dove l'altezza non basta sparisce prima la riga delle proposte, poi la legenda dei canali;
            // il GeometryReader tiene il widget nella sua cella, mai sopra il piede della scrivania
            GeometryReader { geo in
                ViewThatFits(in: .vertical) {
                    numeri(r, legenda: true, proposte: true)
                    numeri(r, legenda: true, proposte: false)
                    numeri(r, legenda: false, proposte: false)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
    }

    private func numeri(_ r: RiepilogoPosizioni, legenda: Bool, proposte: Bool) -> some View {
        let m = Tema.Misura.Shell.self
        return VStack(alignment: .leading, spacing: m.portafoglioSpazio) {
            VStack(alignment: .leading, spacing: m.rigaTestoSpazio) {
                Text(Formati.euro(r.attivita))
                    .font(Tema.Testo.totale)
                    .tracking(Tema.Testo.spaziaturaTotale)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("In essere, \(stato.clienti.count) \(stato.clienti.count == 1 ? "cliente seguito" : "clienti seguiti")")
                    .font(Tema.Testo.Shell.secondarioRiga)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
            }
            .padding(.horizontal, m.rigaMargine)
            if r.attivita > 0 {
                barraCanali(r)
                    .padding(.horizontal, m.rigaMargine)
                if legenda {
                    VStack(spacing: m.rigaMargine) {
                        ForEach(Canale.allCases) { c in
                            voceCanale(c, importo: r.perCanale[c] ?? 0, quota: r.quota(c))
                        }
                    }
                    .padding(.horizontal, m.rigaMargine)
                }
            }
            if proposte {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline) {
                    Text("Proposte aperte")
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                    Spacer()
                    Text(r.proposteAperte == 0 ? "nessuna" : "\(r.proposteAperte) · \(Formati.euro(r.valoreProposte))")
                        .font(Tema.Testo.Shell.importoWidget)
                        .foregroundColor(Tema.Colore.inchiostro)
                }
                .font(Tema.Testo.Shell.corpoWidget)
                .padding(.top, m.rigaMargine)
                .padding(.horizontal, m.rigaMargine)
                .bordoAlto(Tema.Colore.separatore)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// La barra divisa per canale (.split): blu Alleanza, cuoio indipendente.
    private func barraCanali(_ r: RiepilogoPosizioni) -> some View {
        let m = Tema.Misura.Shell.self
        return GeometryReader { geo in
            let disponibile = max(0, geo.size.width - m.barraCanaliSpazio)
            HStack(spacing: m.barraCanaliSpazio) {
                ForEach(Canale.allCases) { c in
                    let quota = CGFloat(min(max(r.quota(c), 0), 1))
                    if quota > 0 {
                        RoundedRectangle(cornerRadius: Tema.Raggio.barraCanali, style: .continuous)
                            .fill(Tema.Colore.canale(c))
                            .frame(width: max(m.barraCanali / 2, disponibile * quota))
                            .help("\(c.nomeBreve): \(Formati.euro(r.perCanale[c] ?? 0))")
                    }
                }
            }
        }
        .frame(height: m.barraCanali)
    }

    /// Una riga della legenda: quadratino del canale, nome, importo e quota.
    private func voceCanale(_ c: Canale, importo: Double, quota: Double) -> some View {
        let m = Tema.Misura.Shell.self
        return HStack(spacing: m.rigaMargine) {
            RoundedRectangle(cornerRadius: Tema.Raggio.quadratinoCanale, style: .continuous)
                .fill(Tema.Colore.canale(c))
                .frame(width: m.quadratinoCanale, height: m.quadratinoCanale)
            Text(c.nomeBreve)
                .font(Tema.Testo.Shell.corpoWidget)
                .foregroundColor(Tema.Colore.inchiostro)
            Spacer(minLength: 0)
            Text(Formati.euro(importo))
                .font(Tema.Testo.Shell.importoWidget)
                .foregroundColor(Tema.Colore.inchiostro)
            Text(Formati.percentuale((quota * 100).rounded()))
                .font(Tema.Testo.Shell.corpoWidget.monospacedDigit())
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .frame(width: m.colonnaQuota, alignment: .trailing)
        }
        .lineLimit(1)
    }
}
