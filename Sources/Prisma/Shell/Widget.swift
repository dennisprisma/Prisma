import SwiftUI

/// Bacheca dei widget della scrivania (tema «Liquid Glass»): sei pannelli di vetro, come nel tema.
///
///   ┌──────── Agenda ────────┐┌── Cliente in primo piano ──┐
///   │                        ││                            │
///   │                        │├──────── Eve (barra) ───────┤
///   └────────────────────────┘└────────────────────────────┘
///   ┌─ Da fare ─┐┌─ Scadenze ─┐┌─ Portafoglio ─┐
struct BachecaWidget: View {
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
                    WidgetAgenda()
                        .frame(width: meta)
                    VStack(spacing: s) {
                        WidgetCliente()
                        WidgetEve()
                    }
                    .frame(width: meta)
                }
                .frame(height: fila + s + eve)
                HStack(spacing: s) {
                    WidgetAttivita().frame(width: terzo)
                    WidgetScadenze().frame(width: terzo)
                    WidgetPortafoglio().frame(width: terzo)
                }
            }
        }
    }
}

// MARK: - Cornice comune

extension View {
    /// Cornice dei widget: vetro spesso del tema (raggio 26), contenuto tagliato alla forma.
    func corniceWidget(raggio: CGFloat = Tema.Raggio.widget) -> some View {
        let forma = FormaVetro.arrotondata(raggio)
        return frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipShape(forma)
            .vetro(.spesso, forma: forma)
    }

    /// Elenco che sfuma negli ultimi punti in basso (.w-scroll del tema).
    func sfumaInBasso() -> some View {
        mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: Tema.Misura.Shell.sfumaturaElenco)
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

    var body: some View {
        Button {
            prima?()
            stato.apri(app)
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
    }
}

/// Testata di un widget (.w-head): icona dell'app, titolo e collegamento a destra.
private struct IntestazioneWidget<Destra: View>: View {
    let titolo: String
    var icona: AppPrisma? = nil
    @ViewBuilder let destra: () -> Destra

    var body: some View {
        HStack(spacing: Tema.Misura.Shell.testaSpazio) {
            if let icona {
                IconaApp(app: icona, lato: Tema.Misura.Shell.iconaWidget)
            }
            Text(titolo)
                .font(Tema.Testo.titolo)
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
        HStack(spacing: 0) {
            TimelineView(.everyMinute) { contesto in
                giorno(contesto.date)
            }
            .frame(width: Tema.Misura.Shell.colonnaGiorno)
            Rectangle().fill(Tema.Colore.separatore).frame(width: Tema.Misura.filo)
            incontri
                .padding(.leading, Tema.Misura.widgetMargine)
        }
        .padding(Tema.Misura.widgetMargine)
        .corniceWidget()
    }

    /// Il giorno grande: giorno della settimana in rosso, numero, mese e il riepilogo di oggi.
    private func giorno(_ oggi: Date) -> some View {
        let incontriOggi = stato.appuntamentiDiOggi.count
        let prossimo = stato.prossimiAppuntamenti.first { $0.inizio >= oggi }
        return VStack(alignment: .leading, spacing: 0) {
            Text(Formati.giornoSettimana.string(from: oggi).capitalized)
                .font(Tema.Testo.Shell.giornoSettimana)
                .foregroundColor(Tema.Colore.rosso)
            Text(Formati.giorno.string(from: oggi))
                .font(Tema.Testo.giornoAgenda)
                .tracking(Tema.Testo.spaziaturaGiornoAgenda)
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
        }
        .padding(Tema.Misura.Shell.colonnaGiornoMargine)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var incontri: some View {
        VStack(alignment: .leading, spacing: 0) {
            IntestazioneWidget(titolo: "Prossimi incontri") {
                CollegamentoApp(testo: "Apri Agenda", app: .agenda)
            }
            ScrollView {
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
    @State var sceltaCliente = false

    /// I numeri del cliente, calcolati una volta sola per tutte le varianti.
    private struct Numeri {
        let riepilogo: RiepilogoPosizioni
        let incontro: String
        let aperte: Int
    }

    var body: some View {
        let id = stato.clienteAttivoId
        let numeri = Numeri(riepilogo: RiepilogoPosizioni(stato.posizioniCliente(id)),
                            incontro: stato.prossimiAppuntamenti.first { $0.clienteId == id }
                                .map { "\(Formati.giornoRelativo($0.inizio)), \(Formati.ora.string(from: $0.inizio))" } ?? "—",
                            aperte: stato.attivitaAperte.filter { $0.clienteId == id }.count)
        // Su schermi più bassi il widget si accorcia invece di accavallarsi agli altri: ViewThatFits
        // misura l'altezza che serve a ogni variante e prende la prima che ci sta, in quest'ordine:
        // tutto; senza la nota; senza i pulsanti; una riga di numeri con i pulsanti; solo quella;
        // poi la sola testata, che entra sempre.
        // Il GeometryReader fissa la misura del widget alla sua cella: anche l'ultima variante,
        // se mai non ci stesse, resta dentro la cornice invece di sporgere sui vicini.
        GeometryReader { geo in
            ViewThatFits(in: .vertical) {
                contenuto(numeri, righe: 2, nota: true, pulsanti: true)
                contenuto(numeri, righe: 2, nota: false, pulsanti: true)
                contenuto(numeri, righe: 2, nota: false, pulsanti: false)
                contenuto(numeri, righe: 1, nota: false, pulsanti: true)
                contenuto(numeri, righe: 1, nota: false, pulsanti: false)
                contenuto(numeri, righe: 0, nota: false, pulsanti: false)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .padding(Tema.Misura.widgetMargine)
        .corniceWidget()
    }

    private func contenuto(_ n: Numeri, righe: Int, nota: Bool, pulsanti: Bool) -> some View {
        let r = n.riepilogo
        let m = Tema.Misura.Shell.self
        return VStack(alignment: .leading, spacing: m.clienteSpazio) {
            testata
            // I numeri (.kpis): griglia di tre colonne sul chip di vetro
            if righe >= 1 {
                VStack(alignment: .leading, spacing: m.kpiSpazioRighe) {
                    HStack(alignment: .top, spacing: m.kpiSpazioColonne) {
                        dato("Patrimonio netto", Formati.euro(r.patrimonioNetto))
                        dato("Prossimo incontro", n.incontro)
                        dato("Da fare", "\(n.aperte) attività")
                    }
                    if righe >= 2 {
                        HStack(alignment: .top, spacing: m.kpiSpazioColonne) {
                            dato("Capitale assicurato", Formati.euro(r.capitaleAssicurato))
                            dato("Premi annui", Formati.euro(r.premiAnnui))
                            dato("Proposte aperte", r.proposteAperte == 0 ? "nessuna" : "\(r.proposteAperte) · \(Formati.euroBreve(r.valoreProposte))")
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
                    Button("Apri la scheda") { stato.apri(.clienti) }
                    Button("Posizioni") {
                        stato.portafoglio = false
                        stato.apri(.posizioni)
                    }
                    Button("Chiedi a Eve") { stato.apri(.eve) }
                }
                .buttonStyle(StileVetro())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Avatar, occhiello, nome (con la scelta del cliente), tema e canali.
    private var testata: some View {
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
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: m.canaliSpazio) {
                ForEach(stato.clienteAttivo?.canali ?? []) { CapsulaCanale(canale: $0) }
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
                .font(Tema.Testo.valoreKpi)
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

    var body: some View {
        Button { stato.apri(.eve) } label: {
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
    }
}

// MARK: - Da fare: le attività aperte

struct WidgetAttivita: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let aperte = stato.attivitaAperte
        VStack(alignment: .leading, spacing: 0) {
            IntestazioneWidget(titolo: aperte.isEmpty ? "Da fare" : "\(aperte.count) \(aperte.count == 1 ? "attività aperta" : "attività aperte")",
                               icona: .attivita) {
                CollegamentoApp(testo: "Apri Attività", app: .attivita)
            }
            ScrollView {
                VStack(spacing: 0) {
                    if aperte.isEmpty {
                        ElencoVuoto(testo: "Tutto fatto.")
                    }
                    ForEach(aperte) { a in
                        RigaAttivita(attivita: a, cliente: stato.cliente(a.clienteId), ultima: a.id == aperte.last?.id) {
                            withAnimation(Animazioni.passaggio) { stato.alternaCompletata(a.id) }
                        }
                    }
                }
            }
            .sfumaInBasso()
        }
        .padding(Tema.Misura.widgetMargine)
        .corniceWidget()
    }
}

// MARK: - Scadenze: le posizioni in scadenza, con la tessera della data

struct WidgetScadenze: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let scadenze = Array(RiepilogoPosizioni(stato.posizioni).inScadenza.prefix(6))
        VStack(alignment: .leading, spacing: 0) {
            IntestazioneWidget(titolo: "In scadenza entro \(RiepilogoPosizioni.giorniScadenza) giorni", icona: .posizioni) {
                CollegamentoApp(testo: "Apri Posizioni", app: .posizioni, prima: { stato.portafoglio = false })
            }
            ScrollView {
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
        .padding(Tema.Misura.widgetMargine)
        .corniceWidget()
    }

    private func riga(_ p: Posizione) -> some View {
        let m = Tema.Misura.Shell.self
        let giorni = giorniAllaScadenza(p)
        let colore = p.scaduta || giorni <= 30 ? Tema.Colore.scadenzaOra : Tema.Colore.scadenzaVicina
        return Button { stato.apriPosizione(p) } label: {
            HStack(spacing: m.rigaSpazio) {
                PiastrellaData(data: p.scadenza ?? Date())
                VStack(alignment: .leading, spacing: m.rigaTestoSpazio) {
                    Text(stato.cliente(p.clienteId)?.nome ?? "")
                        .font(Tema.Testo.Shell.secondarioRiga)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
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
                Spacer(minLength: 0)
                CapsulaCanale(canale: p.canale, compatta: true)
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
        let r = RiepilogoPosizioni(stato.posizioni)
        VStack(alignment: .leading, spacing: 0) {
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
        .padding(Tema.Misura.widgetMargine)
        .corniceWidget()
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
                        .font(Tema.Testo.importo)
                        .foregroundColor(Tema.Colore.inchiostro)
                }
                .font(Tema.Testo.corpo)
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
                .font(Tema.Testo.corpo)
                .foregroundColor(Tema.Colore.inchiostro)
            Spacer(minLength: 0)
            Text(Formati.euro(importo))
                .font(Tema.Testo.importo)
                .foregroundColor(Tema.Colore.inchiostro)
            Text(Formati.percentuale((quota * 100).rounded()))
                .font(Tema.Testo.corpo.monospacedDigit())
                .foregroundColor(Tema.Colore.inchiostroSecondario)
                .frame(width: m.colonnaQuota, alignment: .trailing)
        }
        .lineLimit(1)
    }
}
