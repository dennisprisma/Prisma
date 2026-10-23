import SwiftUI

/// Bacheca dei widget della scrivania, nello stile dei widget della Dashboard di Mac OS X:
/// ogni widget è un oggetto (calendario da scrivania, cartella in pelle, pannello di Borsa,
/// foglietto, promemoria). Le app si aprono dal dock.
///
///   ┌─────── Oggi (calendario) ───────┐┌──── Cliente in primo piano ────┐
///   └─────────────────────────────────┘└────────────────────────────────┘
///   ┌ Da fare ┐┌ Scadenze ┐┌ Portafoglio ┐┌ Eve ┐
struct BachecaWidget: View {
    var body: some View {
        GeometryReader { geo in
            let s = Misure.Widget.spazio
            let alta = (geo.size.height - s) * Misure.Widget.quotaAlta
            VStack(spacing: s) {
                HStack(spacing: s) {
                    WidgetCalendario()
                    WidgetCliente()
                }
                .frame(height: alta)
                HStack(spacing: s) {
                    WidgetAttivita()
                    WidgetScadenze()
                    WidgetPortafoglio()
                    WidgetEve()
                }
            }
        }
    }
}

// MARK: - Cornice comune

extension View {
    /// Cornice dei widget: angoli arrotondati, filetto di luce e doppia ombra (vicina e lontana).
    func corniceWidget<Fondo: View>(_ fondo: Fondo, bordo: Color = Colori.Widget.bordo) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fondo)
            .clipShape(RoundedRectangle(cornerRadius: Misure.Widget.raggio))
            .overlay(
                RoundedRectangle(cornerRadius: Misure.Widget.raggio)
                    .inset(by: 1)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .overlay(RoundedRectangle(cornerRadius: Misure.Widget.raggio).strokeBorder(bordo, lineWidth: 1).allowsHitTesting(false))
            .ombraCSS(Colori.Widget.ombraVicina, y: 2, sfocatura: 4)
            .ombraCSS(Colori.Widget.ombraLontana, y: 9, sfocatura: 22)
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

// MARK: - Oggi: calendario da scrivania

struct WidgetCalendario: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(.everyMinute) { contesto in
                pagina(contesto.date)
            }
            .frame(width: Misure.Widget.paginaCalendario)
            // Doppio filetto rosso, come il margine di una pagina d'agenda
            HStack(spacing: 2) {
                Rectangle().fill(Colori.Widget.calendarioMargine).frame(width: 1)
                Rectangle().fill(Colori.Widget.calendarioMargine).frame(width: 1)
            }
            incontri
        }
        .corniceWidget(Gradienti.paginaCalendario, bordo: Colori.Widget.anelloBordo)
    }

    private func pagina(_ oggi: Date) -> some View {
        VStack(spacing: 0) {
            Text(Formati.meseAnno.string(from: oggi).uppercased())
                .font(Tipo.calendarioMese)
                .tracking(1.2)
                .foregroundColor(Colori.Widget.calendarioTesto)
                .incisione(Colori.Widget.calendarioBordo, y: -1)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Gradienti.calendario)
                .luceInterna(Colori.Widget.calendarioLuce)
                .bordoBasso(Colori.Widget.calendarioBordo)
                .overlay(alignment: .top) { anelli.offset(y: 9) }
            Spacer(minLength: 4)
            Text(Formati.giornoSettimana.string(from: oggi).capitalized)
                .font(Tipo.calendarioGiornoSettimana)
                .foregroundColor(Colori.Widget.calendarioGiorno)
            Text(Formati.giorno.string(from: oggi))
                .font(Tipo.calendarioNumero)
                .foregroundStyle(Gradienti.agendaInchiostro)
                .shadow(color: .white, radius: 0, x: 0, y: 1)
                .padding(.top, -6)
            Text(stato.appuntamentiDiOggi.isEmpty
                 ? "Nessun incontro oggi"
                 : "\(stato.appuntamentiDiOggi.count) \(stato.appuntamentiDiOggi.count == 1 ? "incontro" : "incontri") oggi")
                .font(Tipo.calendarioAnno)
                .foregroundColor(Colori.Widget.secondario)
            Spacer(minLength: 10)
        }
    }

    /// Due anelli metallici della spirale del calendario.
    private var anelli: some View {
        HStack(spacing: Misure.Widget.paginaCalendario - 62) {
            ForEach(0..<2, id: \.self) { _ in
                Capsule()
                    .fill(Gradienti.anello)
                    .overlay(Capsule().strokeBorder(Colori.Widget.anelloBordo, lineWidth: 1))
                    .frame(width: 8, height: 18)
                    .ombraCSS(Color.black.opacity(0.35), y: 1, sfocatura: 2)
            }
        }
        .offset(y: -5)
        .padding(.top, 0)
    }

    private var incontri: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PROSSIMI INCONTRI")
                    .font(Tipo.colonnaIntestazione)
                    .tracking(0.6)
                    .foregroundColor(Colori.Widget.calendarioGiorno)
                Spacer()
                CollegamentoApp(testo: "Apri Agenda ↗", app: .agenda)
            }
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 6, trailing: 16))
            ScrollView {
                VStack(spacing: 0) {
                    let eventi = Array(stato.prossimiAppuntamenti.prefix(6))
                    if eventi.isEmpty {
                        Text("Nessun appuntamento in programma.")
                            .font(Tipo.widgetTesto)
                            .foregroundColor(Colori.Widget.secondario)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    }
                    ForEach(eventi) { e in
                        Button {
                            stato.clienteAttivoId = e.clienteId
                            stato.mostraInAgenda(e)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Formati.ora.string(from: e.inizio))
                                        .font(Tipo.calendarioOra)
                                        .foregroundColor(Colori.Widget.calendarioOra)
                                    Text(Formati.giornoRelativo(e.inizio))
                                        .font(Tipo.chip)
                                        .foregroundColor(Colori.Widget.secondario)
                                }
                                .frame(width: 52, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stato.cliente(e.clienteId)?.nome ?? e.titolo)
                                        .font(Tipo.rigaNome)
                                        .foregroundColor(Colori.Colonna.rigaNome)
                                    Text("\(e.titolo) · \(e.luogo)")
                                        .font(Tipo.rigaSecondario)
                                        .foregroundColor(Colori.Colonna.rigaSecondario)
                                }
                                .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 9)
                            .bordoBasso(Colori.Widget.calendarioRighe)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(StileSemplice())
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Colori.Widget.cartaBianca)
    }
}

// MARK: - Cliente in primo piano: cartella in pelle cucita

struct WidgetCliente: View {
    @EnvironmentObject var stato: StatoShell
    @State var sceltaCliente = false

    var body: some View {
        // Su schermi più bassi il widget si accorcia invece di accavallarsi agli altri:
        // prima toglie la nota e la barra dei canali, poi la seconda riga di numeri.
        ViewThatFits(in: .vertical) {
            contenuto(dettaglio: 2)
            contenuto(dettaglio: 1)
            contenuto(dettaglio: 0)
        }
        .corniceWidget(fondoPelle, bordo: Colori.Colonna.pelleBordo)
    }

    private func contenuto(dettaglio: Int) -> some View {
        let id = stato.clienteAttivoId
        let r = RiepilogoPosizioni(stato.posizioniCliente(id))
        let prossimo = stato.prossimiAppuntamenti.first { $0.clienteId == id }
        let aperte = stato.attivitaAperte.filter { $0.clienteId == id }.count
        return VStack(alignment: .leading, spacing: dettaglio == 0 ? 10 : 14) {
            HStack(spacing: 14) {
                if let c = stato.clienteAttivo {
                    AvatarCliente(iniziali: c.iniziali, tinta: c.tinta.colori, lato: Misure.Widget.avatarCliente)
                        .padding(3)
                        .background(Circle().fill(Colori.Rubrica.avatarCornice))
                        .ombraCSS(Color.black.opacity(0.45), y: 2, sfocatura: 4)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("IL CLIENTE IN PRIMO PIANO")
                        .font(Tipo.colonnaEtichetta)
                        .tracking(0.6)
                        .foregroundColor(Colori.Colonna.pelleEtichetta)
                    Button { sceltaCliente = true } label: {
                        HStack(spacing: 6) {
                            Text(stato.clienteAttivo?.nome ?? "Nessun cliente")
                                .font(Tipo.clienteNome)
                                .lineLimit(1)
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Colori.Colonna.pelleNome)
                    }
                    .buttonStyle(StileSemplice())
                    .popover(isPresented: $sceltaCliente, arrowEdge: .bottom) { ElencoClienti(aperto: $sceltaCliente) }
                    Text(stato.clienteAttivo?.tema ?? "")
                        .font(Tipo.colonnaTema)
                        .foregroundColor(Colori.Colonna.pelleTema)
                        .lineLimit(1)
                }
                .incisione(Color.black.opacity(0.5), y: -1)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 5) {
                    ForEach(stato.clienteAttivo?.canali ?? []) { EtichettaCanale(canale: $0, compatta: true) }
                }
            }

            // Cartoncino con i numeri del cliente
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 0) {
                    dato("Patrimonio netto", Formati.euro(r.patrimonioNetto))
                    dato("Prossimo incontro", prossimo.map { "\(Formati.giornoRelativo($0.inizio)), \(Formati.ora.string(from: $0.inizio))" } ?? "—")
                    dato("Da fare", "\(aperte) attività")
                }
                if dettaglio >= 1 {
                    HStack(alignment: .top, spacing: 0) {
                        dato("Capitale assicurato", Formati.euro(r.capitaleAssicurato))
                        dato("Premi annui", Formati.euro(r.premiAnnui))
                        dato("Proposte aperte", r.proposteAperte == 0 ? "nessuna" : "\(r.proposteAperte) · \(Formati.euroBreve(r.valoreProposte))")
                    }
                }
                if dettaglio >= 2, r.attivita > 0 {
                    VStack(alignment: .leading, spacing: 5) {
                        BarraCanali(quotaAlleanza: r.quota(.alleanza))
                        HStack {
                            Text("Alleanza \(Formati.euro(r.perCanale[.alleanza] ?? 0))")
                            Spacer()
                            Text("Indipendente \(Formati.euro(r.perCanale[.indipendente] ?? 0))")
                        }
                        .font(Tipo.chip)
                        .foregroundColor(Colori.Widget.cartoncinoEtichetta)
                    }
                }
                if dettaglio >= 2, let nota = stato.clienteAttivo?.nota, !nota.isEmpty {
                    Text(nota)
                        .font(Tipo.widgetTesto)
                        .foregroundColor(Colori.Widget.cartoncinoTesto)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Gradienti.cartoncino))
            .overlay(alignment: .top) {
                LinearGradient(colors: [Colori.Widget.cartoncinoOmbra, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Colori.Widget.cartoncinoBordo, lineWidth: 1))
            .shadow(color: Colori.Colonna.pelleLuce.opacity(0.6), radius: 0, x: 0, y: 1)

            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button("Apri la scheda") { stato.apri(.clienti) }
                Button("Posizioni") { stato.apri(.posizioni) }
                Button("Chiedi a Eve") { stato.apri(.eve) }
            }
            .buttonStyle(StileCuoioChiaro())
        }
        .padding(dettaglio == 0 ? EdgeInsets(top: 14, leading: 22, bottom: 14, trailing: 22) : EdgeInsets(top: 20, leading: 22, bottom: 18, trailing: 22))
    }

    /// Pelle con la cucitura impunturata lungo il bordo.
    private var fondoPelle: some View {
        ZStack {
            Materiale.Pelle()
            RoundedRectangle(cornerRadius: Misure.Widget.raggio - 3)
                .inset(by: 7)
                .stroke(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                .offset(y: 1)
            RoundedRectangle(cornerRadius: Misure.Widget.raggio - 3)
                .inset(by: 7)
                .stroke(Colori.Widget.cucitura.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
        }
    }

    private func dato(_ etichetta: String, _ valore: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(etichetta.uppercased())
                .font(Tipo.chip)
                .tracking(0.4)
                .foregroundColor(Colori.Widget.cartoncinoEtichetta)
            Text(valore)
                .font(Tipo.cartoncinoValore)
                .foregroundColor(Colori.Widget.cartoncinoValore)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .incisione(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Da fare: promemoria su carta a righe

struct WidgetAttivita: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Da fare").font(Tipo.promemoriaTitolo).foregroundColor(Colori.Widget.promemoriaTitolo)
                if !stato.attivitaAperte.isEmpty {
                    Badge(numero: stato.attivitaAperte.count, grande: false)
                }
                Spacer()
                CollegamentoApp(testo: "Apri ↗", app: .attivita)
            }
            .incisione(.white)
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 8, trailing: 14))
            .bordoBasso(Colori.Widget.promemoriaRighe, spessore: 2)
            ScrollView {
                VStack(spacing: 0) {
                    let aperte = stato.attivitaAperte
                    if aperte.isEmpty {
                        Text("Tutto fatto.").font(Tipo.widgetTesto).foregroundColor(Colori.Widget.secondario)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                    }
                    ForEach(aperte) { a in
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                withAnimation(Animazioni.passaggio) { stato.alternaCompletata(a.id) }
                            } label: {
                                Circle()
                                    .strokeBorder(Colori.Widget.promemoriaCerchio, lineWidth: 1.5)
                                    .frame(width: 17, height: 17)
                                    .background(Circle().fill(Color.white))
                            }
                            .buttonStyle(StileSemplice())
                            .help("Segna come completata")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.titolo).font(Tipo.contenuto(12, .medium)).foregroundColor(Colori.Colonna.rigaNome).lineLimit(2)
                                Text([stato.cliente(a.clienteId)?.nome, Formati.giornoRelativo(a.scadenza)].compactMap { $0 }.joined(separator: " · "))
                                    .font(Tipo.chip)
                                    .foregroundColor(a.scadenza < Calendar.current.startOfDay(for: Date()) ? Colori.Analisi.erroreTesto : Colori.Widget.secondario)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .bordoBasso(Colori.Widget.promemoriaRighe)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
        .corniceWidget(Colori.Widget.cartaBianca)
    }
}

// MARK: - Scadenze: foglietto giallo scritto a mano

struct WidgetScadenze: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let scadenze = Array(RiepilogoPosizioni(stato.posizioni).inScadenza.prefix(6))
        VStack(alignment: .leading, spacing: 0) {
            // Rilegatura in pelle scura
            Rectangle()
                .fill(Gradienti.rilegatura)
                .frame(height: Misure.Widget.rilegatura)
                .luceInterna(Colori.Widget.rilegaturaLuce)
                .ombraInternaBasso(Colori.Widget.rilegaturaOmbra)
                .overlay(
                    Rectangle()
                        .stroke(Colori.Widget.cucitura.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                )
            VStack(alignment: .leading, spacing: 0) {
                Text("Scadenze")
                    .font(Tipo.manoTitolo)
                    .foregroundColor(Colori.Widget.fogliettoTesto)
                    .frame(height: Misure.Widget.rigaFoglietto * 1.5, alignment: .bottom)
                if scadenze.isEmpty {
                    Text("Nessuna nei prossimi \(RiepilogoPosizioni.giorniScadenza) giorni.")
                        .font(Tipo.mano)
                        .foregroundColor(Colori.Widget.fogliettoSecondario)
                        .frame(height: Misure.Widget.rigaFoglietto, alignment: .bottom)
                }
                ForEach(scadenze) { p in
                    Button {
                        stato.apriPosizione(p)
                    } label: {
                        HStack(spacing: 6) {
                            Text(p.scadenza.map { "\(Formati.giorno.string(from: $0)) \(Formati.meseBreve.string(from: $0))" } ?? "")
                                .font(Tipo.manoTitolo)
                            Text(p.nome).font(Tipo.mano)
                            Text("· \(stato.cliente(p.clienteId)?.nome.split(separator: " ").first.map(String.init) ?? "")")
                                .font(Tipo.manoPiccola)
                                .foregroundColor(Colori.Widget.fogliettoSecondario)
                            Spacer(minLength: 0)
                        }
                        .foregroundColor(p.scaduta ? Colori.Analisi.erroreTesto : Colori.Widget.fogliettoTesto)
                        .lineLimit(1)
                        .frame(height: Misure.Widget.rigaFoglietto, alignment: .bottom)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(StileSemplice())
                }
            }
            .padding(.leading, 38)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(righe)
        }
        .corniceWidget(Gradienti.foglietto, bordo: Colori.Widget.rilegaturaOmbra)
    }

    /// Righe del foglietto e margine rosso, allineate alle righe di testo.
    private var righe: some View {
        GeometryReader { geo in
            Path { p in
                var y = Misure.Widget.rigaFoglietto * 1.5 + Misure.Widget.rigaFoglietto + 2
                while y < geo.size.height {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += Misure.Widget.rigaFoglietto
                }
            }
            .stroke(Colori.Widget.fogliettoRighe, lineWidth: 1)
            Rectangle().fill(Colori.Widget.fogliettoMargine).frame(width: 1).offset(x: 28)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Portafoglio clienti: pannello nero lucido come l'app Borsa

struct WidgetPortafoglio: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        Button { stato.apri(.posizioni) } label: {
            // Su schermi bassi la riga delle proposte lascia spazio ai canali
            ViewThatFits(in: .vertical) {
                contenuto(conProposte: true)
                contenuto(conProposte: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .top) {
                Gradienti.borsaRiflesso
                    .frame(height: 70)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(StileSemplice())
        .corniceWidget(Gradienti.borsa, bordo: Colori.Widget.borsaBordo)
    }

    private func contenuto(conProposte: Bool) -> some View {
        let r = RiepilogoPosizioni(stato.posizioni)
        return VStack(alignment: .leading, spacing: 10) {
                Text("PORTAFOGLIO CLIENTI")
                    .font(Tipo.chip)
                    .tracking(1)
                    .foregroundColor(Colori.Widget.borsaTitolo)
                VStack(alignment: .leading, spacing: 1) {
                    Text(Formati.euro(r.attivita))
                        .font(Tipo.borsaTotale)
                        .foregroundColor(Colori.Widget.borsaTesto)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("seguiti in essere · \(stato.clienti.count) clienti")
                        .font(Tipo.chip)
                        .foregroundColor(Colori.Widget.borsaSecondario)
                }
                Rectangle().fill(Colori.Widget.borsaFilo).frame(height: 1)
                riga("Alleanza", Colori.Widget.borsaAlleanza, r.perCanale[.alleanza] ?? 0, r.quota(.alleanza))
                riga("Indipendente", Colori.Widget.borsaIndipendente, r.perCanale[.indipendente] ?? 0, r.quota(.indipendente))
                if conProposte {
                    Rectangle().fill(Colori.Widget.borsaFilo).frame(height: 1)
                    HStack {
                        Text("Proposte aperte").font(Tipo.borsaRiga).foregroundColor(Colori.Widget.borsaTesto)
                        Spacer()
                        Text("\(r.proposteAperte)").font(Tipo.borsaRiga).foregroundColor(Colori.Widget.borsaTesto)
                    }
                    Text("per \(Formati.euro(r.valoreProposte)) nel primo anno")
                        .font(Tipo.chip)
                        .foregroundColor(Colori.Widget.borsaSecondario)
                }
                Spacer(minLength: 0)
            }
            .padding(Misure.Widget.margine)
    }

    private func riga(_ nome: String, _ colore: Color, _ valore: Double, _ quota: Double) -> some View {
        HStack(spacing: 8) {
            Circle().fill(colore).frame(width: 8, height: 8)
            Text(nome).font(Tipo.borsaRiga).foregroundColor(Colori.Widget.borsaTesto)
            Spacer(minLength: 4)
            Text(Formati.euroBreve(valore)).font(Tipo.borsaRiga).foregroundColor(Colori.Widget.borsaSecondario)
            Text(Formati.percentuale((quota * 100).rounded()))
                .font(Tipo.borsaPillola)
                .foregroundColor(.white)
                .incisione(Colori.Widget.borsaVerdeBordo, y: -1)
                .frame(width: 48, height: 22)
                .background(RoundedRectangle(cornerRadius: 4).fill(Gradienti.borsaVerde))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Colori.Widget.borsaVerdeBordo, lineWidth: 1))
        }
    }
}

// MARK: - Eve

struct WidgetEve: View {
    @EnvironmentObject var stato: StatoShell

    /// Altezze fisse dell'onda sonora (nessuna animazione continua: niente consumi inutili).
    private static let onda: [CGFloat] = [6, 10, 16, 24, 14, 30, 20, 34, 22, 28, 12, 18, 9, 14, 6]

    var body: some View {
        Button { stato.apri(.eve) } label: {
            // Su schermi bassi l'onda sonora lascia spazio al resto
            ViewThatFits(in: .vertical) {
                contenuto(conOnda: true)
                contenuto(conOnda: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(StileSemplice())
        .corniceWidget(Materiale.Lino(), bordo: Colori.Colonna.eveBordo)
    }

    private func contenuto(conOnda: Bool) -> some View {
        VStack(spacing: 10) {
                IconaApp(app: .eve, lato: 58)
                    .shadow(color: Colori.Widget.eveAlone.opacity(0.7), radius: 14)
                    .ombraCSS(Colori.Scrivania.iconaOmbra1, y: 2, sfocatura: 2)
                    .padding(.top, 6)
                Text("EVE · PRONTA")
                    .font(Tipo.chip)
                    .tracking(1.4)
                    .foregroundColor(Colori.Colonna.eveTesto)
                if conOnda {
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(Array(Self.onda.enumerated()), id: \.offset) { _, h in
                            Capsule().fill(Gradienti.onda).frame(width: 4, height: h)
                        }
                    }
                    .frame(height: 36)
                }
                VStack(spacing: 3) {
                    Text("Ritrova il filo con Eve.")
                        .font(Tipo.eveTitolo)
                        .foregroundColor(Colori.Colonna.eveTitolo)
                    Text("Incontri, sintesi e prossimi passi")
                        .font(Tipo.eveTesto)
                        .foregroundColor(Colori.Colonna.eveTesto)
                }
                .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .incisione(.black, y: -1)
            .padding(Misure.Widget.margine)
    }
}
