import SwiftUI

/// Bacheca dei widget della scrivania, con i materiali e le misure del pannello laterale del template
/// (.os-desk-sidebar): carta avorio, pelle con la cucitura, righe con la piastrella della data, lino per Eve.
///
///   ┌──────── Agenda ────────┐┌── Cliente in primo piano ──┐
///   │                        ││                            │
///   │                        │├──────── Eve (barra) ───────┤
///   └────────────────────────┘└────────────────────────────┘
///   ┌─ Da fare ─┐┌─ Scadenze ─┐┌─ Portafoglio ─┐
struct BachecaWidget: View {
    var body: some View {
        GeometryReader { geo in
            let s = Misure.Widget.spazio
            let alta = (geo.size.height - s) * Misure.Widget.quotaAlta
            VStack(spacing: s) {
                HStack(spacing: s) {
                    WidgetAgenda()
                    VStack(spacing: s) {
                        WidgetCliente()
                        WidgetEve()
                    }
                }
                .frame(height: alta)
                HStack(spacing: s) {
                    WidgetAttivita()
                    WidgetScadenze()
                    WidgetPortafoglio()
                }
            }
        }
    }
}

// MARK: - Cornice comune

extension View {
    /// Cornice dei widget come il pannello del template: raggio 6, bordo 1 px, filetto bianco interno, una sola ombra.
    func corniceWidget<Fondo: View>(_ fondo: Fondo, bordo: Color = Colori.Widget.bordo) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fondo)
            .clipShape(RoundedRectangle(cornerRadius: Misure.Widget.raggio))
            .luceInterna(.white, raggio: Misure.Widget.raggio)
            .overlay(RoundedRectangle(cornerRadius: Misure.Widget.raggio).strokeBorder(bordo, lineWidth: 1).allowsHitTesting(false))
            .ombraCSS(Colori.Widget.ombra, y: 4, sfocatura: 13)
    }
}

struct CollegamentoApp: View {
    @EnvironmentObject var stato: StatoShell
    let testo: String
    let app: AppPrisma
    var colore: Color = Colori.Colonna.collegamento

    var body: some View {
        Button(testo) { stato.apri(app) }
            .buttonStyle(StileSemplice())
            .font(Tipo.colonnaCollegamento)
            .foregroundColor(colore)
    }
}

/// Intestazione di un pannello (.os-desk-panel-heading): etichetta in maiuscoletto e collegamento a destra.
private struct IntestazionePannello<Destra: View>: View {
    let titolo: String
    @ViewBuilder let destra: () -> Destra

    var body: some View {
        HStack {
            Text(titolo)
                .font(Tipo.colonnaIntestazione)
                .tracking(0.8)
                .foregroundColor(Colori.Colonna.intestazione)
            Spacer()
            destra()
        }
        .padding(Misure.Widget.intestazionePannello)
    }
}

/// Il filetto fra le righe dei pannelli: bordo e luce.
private struct FilettoRiga: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Colori.Colonna.rigaBordo).frame(height: 1)
            Rectangle().fill(Colori.Colonna.rigaLuce).frame(height: 1)
        }
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
            .frame(width: Misure.Widget.colonnaGiorno)
            Rectangle().fill(Colori.Colonna.rigaBordo).frame(width: 1)
            incontri
        }
        .corniceWidget(Colori.Colonna.sfondo)
    }

    /// La piastrella grande del giorno, come quella delle righe ma a tutta altezza.
    private func giorno(_ oggi: Date) -> some View {
        let incontriOggi = stato.appuntamentiDiOggi.count
        return VStack(spacing: 10) {
            VStack(spacing: 0) {
                Text(Formati.giorno.string(from: oggi))
                    .font(Tipo.piastrellaGiorno)
                    .foregroundColor(Colori.Colonna.dataGiorno)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(Formati.meseBreve.string(from: oggi).uppercased())
                    .font(Tipo.piastrellaMese)
                    .tracking(0.5)
                    .foregroundColor(Colori.Colonna.dataMeseTesto)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .background(Gradienti.dataMese)
                    .bordoAlto(Colori.Colonna.dataMeseBordo)
                    .clipShape(RettangoloAngoli(bassoDestra: 3, bassoSinistra: 3))
                    .padding([.horizontal, .bottom], 1)
            }
            .frame(width: Misure.Widget.piastrellaGrande.width, height: Misure.Widget.piastrellaGrande.height)
            .background(RoundedRectangle(cornerRadius: Misure.Widget.pannelloRaggio).fill(Gradienti.data))
            .luceInterna(.white, raggio: Misure.Widget.pannelloRaggio)
            .overlay(RoundedRectangle(cornerRadius: Misure.Widget.pannelloRaggio).strokeBorder(Colori.Colonna.dataBordo, lineWidth: 1))
            .ombraCSS(Colori.Colonna.dataOmbra, y: 2, sfocatura: 2)
            Text(Formati.giornoSettimana.string(from: oggi).capitalized)
                .font(Tipo.rigaNome)
                .foregroundColor(Colori.Colonna.rigaNome)
            Text(incontriOggi == 0 ? "Nessun incontro oggi" : "\(incontriOggi) \(incontriOggi == 1 ? "incontro" : "incontri") oggi")
                .font(Tipo.rigaSecondario)
                .foregroundColor(Colori.Colonna.rigaSecondario)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 18)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var incontri: some View {
        VStack(alignment: .leading, spacing: 0) {
            IntestazionePannello(titolo: "PROSSIMI INCONTRI") {
                CollegamentoApp(testo: "Apri Agenda ↗", app: .agenda)
            }
            ScrollView {
                VStack(spacing: 0) {
                    let eventi = Array(stato.prossimiAppuntamenti.prefix(6))
                    if eventi.isEmpty {
                        Text("Nessun appuntamento in programma.")
                            .font(Tipo.rigaSecondario)
                            .foregroundColor(Colori.Colonna.rigaSecondario)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    }
                    ForEach(eventi) { e in
                        RigaAppuntamento(evento: e, cliente: stato.cliente(e.clienteId), ultima: e.id == eventi.last?.id) {
                            stato.clienteAttivoId = e.clienteId
                            stato.mostraInAgenda(e)
                        }
                    }
                }
                .padding(.horizontal, Misure.Widget.margineElenco)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Cliente in primo piano: testata in pelle e pannello con i numeri

struct WidgetCliente: View {
    @EnvironmentObject var stato: StatoShell
    @State var sceltaCliente = false

    var body: some View {
        // Su schermi più bassi il widget si accorcia invece di accavallarsi agli altri: ViewThatFits
        // misura l'altezza che serve a ogni variante e prende la prima che ci sta, in quest'ordine:
        // tutto; senza la nota; senza i pulsanti; una riga di numeri con i pulsanti; solo quella;
        // infine la testata compatta del template (senza il tema, margini ridotti).
        // Il GeometryReader fissa la misura del widget alla sua cella: anche l'ultima variante,
        // se mai non ci stesse, resta dentro la cornice invece di sporgere sui vicini.
        GeometryReader { geo in
            ViewThatFits(in: .vertical) {
                contenuto(righe: 2, nota: true, pulsanti: true)
                contenuto(righe: 2, nota: false, pulsanti: true)
                contenuto(righe: 2, nota: false, pulsanti: false)
                contenuto(righe: 1, nota: false, pulsanti: true)
                contenuto(righe: 1, nota: false, pulsanti: false)
                contenuto(righe: 1, nota: false, pulsanti: false, compatta: true)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .corniceWidget(Colori.Colonna.sfondo)
    }

    private func contenuto(righe: Int, nota: Bool, pulsanti: Bool, compatta: Bool = false) -> some View {
        let id = stato.clienteAttivoId
        let r = RiepilogoPosizioni(stato.posizioniCliente(id))
        let prossimo = stato.prossimiAppuntamenti.first { $0.clienteId == id }
        let aperte = stato.attivitaAperte.filter { $0.clienteId == id }.count
        return VStack(alignment: .leading, spacing: 0) {
            testata(compatta: compatta)
            VStack(alignment: .leading, spacing: Misure.Widget.clienteSpazio) {
                // Il pannello carta con i numeri (.os-panel + .os-kpi)
                VStack(alignment: .leading, spacing: Misure.Widget.clienteSpazio) {
                    HStack(alignment: .top, spacing: 0) {
                        dato("Patrimonio netto", Formati.euro(r.patrimonioNetto))
                        dato("Prossimo incontro", prossimo.map { "\(Formati.giornoRelativo($0.inizio)), \(Formati.ora.string(from: $0.inizio))" } ?? "—")
                        dato("Da fare", "\(aperte) attività")
                    }
                    if righe >= 2 {
                        HStack(alignment: .top, spacing: 0) {
                            dato("Capitale assicurato", Formati.euro(r.capitaleAssicurato))
                            dato("Premi annui", Formati.euro(r.premiAnnui))
                            dato("Proposte aperte", r.proposteAperte == 0 ? "nessuna" : "\(r.proposteAperte) · \(Formati.euroBreve(r.valoreProposte))")
                        }
                    }
                    if nota, let nota = stato.clienteAttivo?.nota, !nota.isEmpty {
                        Text(nota)
                            .font(Tipo.rigaSecondario)
                            .foregroundColor(Colori.Colonna.rigaSecondario)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Misure.Widget.pannelloMargine)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Misure.Widget.pannelloRaggio).fill(Gradienti.pannelloWidget))
                .luceInterna(.white, raggio: Misure.Widget.pannelloRaggio)
                .overlay(RoundedRectangle(cornerRadius: Misure.Widget.pannelloRaggio).strokeBorder(Colori.Widget.pannelloBordo, lineWidth: 1))
                .ombraCSS(Colori.Widget.pannelloOmbra, y: 2, sfocatura: 6)
                if pulsanti {
                    // Lo Spacer solo qui: nelle varianti senza pulsanti costerebbe comunque lo spazio della pila
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Button("Apri la scheda") { stato.apri(.clienti) }
                        Button("Posizioni") {
                            stato.portafoglio = false
                            stato.apri(.posizioni)
                        }
                        Button("Chiedi a Eve") { stato.apri(.eve) }
                    }
                    .buttonStyle(StileCuoioChiaro())
                }
            }
            .padding(Misure.Widget.clienteMargine)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// La testata in pelle con la cucitura (.os-desk-client): avatar, etichetta, nome, tema, canali.
    /// Compatta come sugli schermi bassi del template: niente tema e margini ridotti.
    private func testata(compatta: Bool) -> some View {
        HStack(alignment: .center, spacing: 11) {
            if let c = stato.clienteAttivo {
                AvatarCliente(iniziali: c.iniziali, tinta: c.tinta.colori, lato: Misure.Widget.avatarCliente)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("IL CLIENTE IN PRIMO PIANO")
                    .font(Tipo.colonnaEtichetta)
                    .tracking(0.5)
                    .foregroundColor(Colori.Colonna.pelleEtichetta)
                Button { sceltaCliente = true } label: {
                    HStack(spacing: 6) {
                        Text(stato.clienteAttivo?.nome ?? "Nessun cliente")
                            .font(Tipo.colonnaNome)
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Colori.Colonna.pelleNome)
                }
                .buttonStyle(StileSemplice())
                .popover(isPresented: $sceltaCliente, arrowEdge: .bottom) { ElencoClienti(aperto: $sceltaCliente) }
                if !compatta {
                    Text(stato.clienteAttivo?.tema ?? "")
                        .font(Tipo.colonnaTema)
                        .foregroundColor(Colori.Colonna.pelleTema)
                        .lineLimit(1)
                }
            }
            .incisione(Colori.Colonna.pelleBordo, y: -1)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 5) {
                ForEach(stato.clienteAttivo?.canali ?? []) { EtichettaCanale(canale: $0, compatta: true) }
            }
        }
        .padding(compatta ? Misure.Widget.clienteTestataCompatta : Misure.Widget.clienteTestata)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Materiale.Pelle())
        .overlay(
            // La cucitura: tratteggio chiaro con l'ombra di un punto sotto
            ZStack {
                RoundedRectangle(cornerRadius: Misure.Widget.cucituraRaggio)
                    .inset(by: Misure.Widget.cucituraRientro)
                    .stroke(Colori.Colonna.cucituraOmbra, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .offset(y: 1)
                RoundedRectangle(cornerRadius: Misure.Widget.cucituraRaggio)
                    .inset(by: Misure.Widget.cucituraRientro)
                    .stroke(Colori.Colonna.cucitura, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .allowsHitTesting(false)
        )
        .luceInterna(Colori.Colonna.pelleLuce)
        .ombraInternaBasso(Colori.Colonna.pelleOmbra, spessore: 2)
        .bordoBasso(Colori.Colonna.pelleBordo)
    }

    private func dato(_ etichetta: String, _ valore: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(etichetta.uppercased())
                .font(Tipo.kpiEtichettaWidget)
                .tracking(0.4)
                .foregroundColor(Colori.Widget.kpiEtichetta)
            Text(valore)
                .font(Tipo.kpiValoreWidget)
                .tracking(-0.5)
                .foregroundColor(Colori.Widget.kpiValore)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Eve: la barra in lino

struct WidgetEve: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        Button { stato.apri(.eve) } label: {
            HStack(spacing: 12) {
                IconaApp(app: .eve, lato: Misure.Colonna.iconaEve)
                    .ombraCSS(Colori.Colonna.eveIconaOmbra, y: 2, sfocatura: 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ritrova il filo con Eve.")
                        .font(Tipo.eveTitolo)
                        .foregroundColor(Colori.Colonna.eveTitolo)
                    Text(stato.evePortafoglio ? "Il tuo portafoglio, chi ricontattare, le scadenze" : "Incontri, sintesi e prossimi passi")
                        .font(Tipo.eveTesto)
                        .foregroundColor(Colori.Colonna.eveTesto)
                        .lineLimit(1)
                }
                .incisione(Colori.Colonna.eveIncisione, y: -1)
                Spacer(minLength: 0)
                Text("›").font(Tipo.rigaFreccia).foregroundColor(Colori.Colonna.eveFreccia)
            }
            .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
        .frame(height: Misure.Widget.barraEve)
        .corniceWidget(Materiale.Lino(), bordo: Colori.Colonna.eveBordo)
        .frame(height: Misure.Widget.barraEve)
    }
}

// MARK: - Da fare: le attività aperte

struct WidgetAttivita: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let aperte = stato.attivitaAperte
        VStack(alignment: .leading, spacing: 0) {
            IntestazionePannello(titolo: aperte.isEmpty ? "DA FARE" : "\(aperte.count) \(aperte.count == 1 ? "ATTIVITÀ APERTA" : "ATTIVITÀ APERTE")") {
                CollegamentoApp(testo: "Apri Attività ↗", app: .attivita)
            }
            ScrollView {
                VStack(spacing: 0) {
                    if aperte.isEmpty {
                        Text("Tutto fatto.")
                            .font(Tipo.rigaSecondario)
                            .foregroundColor(Colori.Colonna.rigaSecondario)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    }
                    ForEach(aperte) { a in
                        RigaAttivita(attivita: a, cliente: stato.cliente(a.clienteId), ultima: a.id == aperte.last?.id) {
                            withAnimation(Animazioni.passaggio) { stato.alternaCompletata(a.id) }
                        }
                    }
                }
                .padding(.horizontal, Misure.Widget.margineElenco)
            }
        }
        .corniceWidget(Colori.Colonna.sfondo)
    }
}

// MARK: - Scadenze: le posizioni in scadenza, con la piastrella della data

struct WidgetScadenze: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let scadenze = Array(RiepilogoPosizioni(stato.posizioni).inScadenza.prefix(6))
        VStack(alignment: .leading, spacing: 0) {
            IntestazionePannello(titolo: "SCADENZE · \(RiepilogoPosizioni.giorniScadenza) GIORNI") {
                CollegamentoApp(testo: "Apri Posizioni ↗", app: .posizioni)
            }
            ScrollView {
                VStack(spacing: 0) {
                    if scadenze.isEmpty {
                        Text("Nessuna nei prossimi \(RiepilogoPosizioni.giorniScadenza) giorni.")
                            .font(Tipo.rigaSecondario)
                            .foregroundColor(Colori.Colonna.rigaSecondario)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    }
                    ForEach(scadenze) { p in
                        Button { stato.apriPosizione(p) } label: {
                            HStack(spacing: 12) {
                                PiastrellaData(data: p.scadenza ?? Date())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(stato.cliente(p.clienteId)?.nome ?? "")
                                        .font(Tipo.rigaSecondario)
                                        .foregroundColor(Colori.Colonna.rigaSecondario)
                                    Text(p.nome)
                                        .font(Tipo.rigaNome)
                                        .foregroundColor(p.scaduta ? Colori.Analisi.erroreTesto : Colori.Colonna.rigaNome)
                                    Text(p.scaduta ? "Scaduta" : "\(p.area.nome) · \(p.canale.nomeBreve)")
                                        .font(Tipo.rigaSecondario)
                                        .foregroundColor(p.scaduta ? Colori.Analisi.erroreTesto : Colori.Colonna.rigaSecondario)
                                }
                                .lineLimit(1)
                                Spacer(minLength: 0)
                                Text("›").font(Tipo.rigaFreccia).foregroundColor(Colori.Colonna.freccia)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .bottom) { if p.id != scadenze.last?.id { FilettoRiga() } }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(StileSemplice())
                    }
                }
                .padding(.horizontal, Misure.Widget.margineElenco)
            }
        }
        .corniceWidget(Colori.Colonna.sfondo)
    }
}

// MARK: - Portafoglio clienti: i numeri di tutti i clienti, per canale

struct WidgetPortafoglio: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let r = RiepilogoPosizioni(stato.posizioni)
        VStack(alignment: .leading, spacing: 0) {
            IntestazionePannello(titolo: "PORTAFOGLIO CLIENTI") {
                Button("Apri ↗") {
                    stato.portafoglio = true
                    stato.apri(.posizioni)
                }
                .buttonStyle(StileSemplice())
                .font(Tipo.colonnaCollegamento)
                .foregroundColor(Colori.Colonna.collegamento)
            }
            // Dove l'altezza non basta sparisce prima la riga delle proposte, poi le barre dei canali;
            // il GeometryReader tiene il widget nella sua cella, mai sopra il piede della scrivania
            GeometryReader { geo in
                ViewThatFits(in: .vertical) {
                    numeri(r, canali: true, proposte: true)
                    numeri(r, canali: true, proposte: false)
                    numeri(r, canali: false, proposte: false)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
        .corniceWidget(Colori.Colonna.sfondo)
    }

    private func numeri(_ r: RiepilogoPosizioni, canali: Bool, proposte: Bool) -> some View {
        VStack(alignment: .leading, spacing: Misure.Widget.portafoglioSpazio) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formati.euro(r.attivita))
                    .font(Tipo.portafoglioTotale)
                    .tracking(-0.7)
                    .foregroundColor(Colori.Widget.kpiValore)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("seguiti in essere · \(stato.clienti.count) \(stato.clienti.count == 1 ? "cliente" : "clienti")")
                    .font(Tipo.rigaSecondario)
                    .foregroundColor(Colori.Colonna.rigaSecondario)
            }
            if canali, r.attivita > 0 {
                canale(.alleanza, importo: r.perCanale[.alleanza] ?? 0, quota: r.quota(.alleanza))
                canale(.indipendente, importo: r.perCanale[.indipendente] ?? 0, quota: r.quota(.indipendente))
            }
            if proposte {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline) {
                    Text("Proposte aperte")
                        .font(Tipo.widgetMetricaEtichetta)
                        .foregroundColor(Colori.Colonna.metricaEtichetta)
                    Spacer()
                    Text(r.proposteAperte == 0 ? "nessuna" : "\(r.proposteAperte) · \(Formati.euroBreve(r.valoreProposte))")
                        .font(Tipo.widgetMetricaValore)
                        .foregroundColor(Colori.Colonna.metricaValore)
                }
                .padding(.top, 10)
                .bordoAlto(Colori.Colonna.rigaBordo)
            }
        }
        .padding(EdgeInsets(top: 2, leading: Misure.Widget.margineElenco, bottom: 12, trailing: Misure.Widget.margineElenco))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Un canale con l'importo e la barra (.os-progress).
    private func canale(_ c: Canale, importo: Double, quota: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                EtichettaCanale(canale: c, compatta: true)
                Spacer()
                Text(Formati.euro(importo))
                    .font(Tipo.rigaNome)
                    .foregroundColor(Colori.Colonna.rigaNome)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Colori.Widget.progressoFondo)
                    Capsule()
                        .fill(LinearGradient(colors: [Colori.Widget.progressoOmbra, .clear], startPoint: .top, endPoint: .center))
                        .padding(1)
                    Capsule()
                        .fill(c == .alleanza ? Colori.Analisi.canaleAlleanza : Colori.Analisi.canaleIndipendente)
                        .frame(width: max(0, geo.size.width * CGFloat(min(max(quota, 0), 1))))
                        .overlay(alignment: .top) {
                            Capsule().fill(Colori.Widget.progressoLuce).frame(height: 1).padding(.horizontal, 3).padding(.top, 1)
                        }
                }
            }
            .frame(height: Misure.Widget.progresso)
            .overlay(Capsule().strokeBorder(Colori.Widget.progressoBordo, lineWidth: 1))
        }
    }
}
