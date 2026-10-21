import SwiftUI

/// Bacheca dei widget della scrivania. Le app si aprono dal dock: la scrivania mostra la giornata.
///
///   ┌──────── Oggi ────────┐┌── Cliente in primo piano ──┐
///   └──────────────────────┘└────────────────────────────┘
///   ┌──── Da fare ────┐┌─ Posizioni ─┐┌──── Eve ────┐
struct BachecaWidget: View {
    var body: some View {
        GeometryReader { geo in
            let s = Misure.Widget.spazio
            let alta = (geo.size.height - s) * Misure.Widget.quotaAlta
            let colonna = (geo.size.width - 3 * s) / 4
            VStack(spacing: s) {
                HStack(spacing: s) {
                    WidgetOggi()
                    WidgetCliente()
                }
                .frame(height: alta)
                HStack(spacing: s) {
                    WidgetAttivita().frame(width: colonna * 2 + s)
                    WidgetPosizioni().frame(width: colonna)
                    WidgetEve().frame(width: colonna)
                }
            }
        }
    }
}

// MARK: - Cornice comune

extension View {
    /// Cornice dei widget: carta, bordo grafite e ombra come la colonna della scrivania del template.
    func corniceWidget<Fondo: View>(_ fondo: Fondo) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fondo)
            .clipShape(RoundedRectangle(cornerRadius: Misure.Widget.raggio))
            .overlay(RoundedRectangle(cornerRadius: Misure.Widget.raggio).strokeBorder(Colori.Widget.bordo, lineWidth: 1))
            .ombraCSS(Colori.Widget.ombra, y: 4, sfocatura: 13)
    }
}

/// Intestazione grafite di Lion (come la barra del titolo delle finestre).
struct IntestazioneLion<Destra: View>: View {
    let titolo: String
    @ViewBuilder let destra: () -> Destra

    var body: some View {
        HStack(spacing: 8) {
            Text(titolo.uppercased())
                .font(Tipo.widgetTitolo)
                .tracking(0.4)
                .foregroundColor(Colori.Finestra.titoloTesto)
                .incisione(Colori.Finestra.titoloIncisione)
            Spacer(minLength: 4)
            destra()
        }
        .padding(.horizontal, 13)
        .frame(height: Misure.Widget.intestazione)
        .frame(maxWidth: .infinity)
        .background(Gradienti.barraTitolo(attiva: true))
        .luceInterna(Colori.Finestra.titoloLuce)
        .bordoBasso(Colori.Finestra.titoloBordoAttiva)
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

// MARK: - Oggi

/// Calendario della giornata: intestazione rossa come l'Agenda di iOS 5 e i prossimi incontri.
struct WidgetOggi: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.everyMinute) { contesto in
                HStack(alignment: .center, spacing: 12) {
                    Text(Formati.giorno.string(from: contesto.date))
                        .font(Tipo.widgetGiorno)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Formati.giornoSettimana.string(from: contesto.date).capitalized)
                            .font(Tipo.widgetGiornoNome)
                        Text(Formati.meseAnno.string(from: contesto.date))
                            .font(Tipo.rigaSecondario)
                            .foregroundColor(Colori.Widget.calendarioSecondario)
                    }
                    Spacer()
                    CollegamentoApp(testo: "Apri Agenda ↗", app: .agenda, colore: Colori.Widget.calendarioTesto)
                }
                .foregroundColor(Colori.Widget.calendarioTesto)
                .incisione(Colori.Widget.calendarioBordo, y: -1)
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Gradienti.calendario)
                .luceInterna(Colori.Widget.calendarioLuce)
                .bordoBasso(Colori.Widget.calendarioBordo)
            }
            HStack {
                Text("PROSSIMI INCONTRI")
                    .font(Tipo.colonnaIntestazione)
                    .foregroundColor(Colori.Colonna.intestazione)
                Spacer()
            }
            .padding(EdgeInsets(top: 12, leading: 15, bottom: 2, trailing: 15))
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
                            stato.apri(.agenda)
                        }
                    }
                }
                .padding(.horizontal, 15)
            }
        }
        .corniceWidget(Colori.Widget.carta)
    }
}

// MARK: - Cliente in primo piano

struct WidgetCliente: View {
    @EnvironmentObject var stato: StatoShell
    @State var sceltaCliente = false

    private var prossimo: Appuntamento? {
        stato.prossimiAppuntamenti.first { $0.clienteId == stato.clienteAttivoId }
    }

    private var aperte: Int {
        stato.attivitaAperte.filter { $0.clienteId == stato.clienteAttivoId }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            intestazione
            VStack(alignment: .leading, spacing: 14) {
                if let c = stato.clienteAttivo {
                    Text(c.nota)
                        .font(Tipo.widgetTesto)
                        .foregroundColor(Colori.Colonna.rigaNome)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .top, spacing: 0) {
                    dato("Prossimo incontro",
                         prossimo.map { "\(Formati.giorno.string(from: $0.inizio)) \(Formati.meseBreve.string(from: $0.inizio)) · \(Formati.ora.string(from: $0.inizio))" } ?? "—")
                    dato("Attività aperte", "\(aperte)")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("POSIZIONI PER CANALE")
                        .font(Tipo.colonnaIntestazione)
                        .foregroundColor(Colori.Colonna.intestazione)
                    HStack(spacing: 6) {
                        EtichettaCanale(canale: .alleanza, compatta: true)
                        EtichettaCanale(canale: .indipendente, compatta: true)
                    }
                    Text("Il quadro delle posizioni arriva con il modulo Posizioni.")
                        .font(Tipo.rigaSecondario)
                        .foregroundColor(Colori.Colonna.rigaSecondario)
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button("Apri la scheda") { stato.apri(.clienti) }
                    Button("Posizioni") { stato.apri(.posizioni) }
                    Button("Chiedi a Eve") { stato.apri(.eve) }
                }
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)))
            }
            .padding(Misure.Widget.margine)
        }
        .corniceWidget(Colori.Widget.carta)
    }

    private func dato(_ etichetta: String, _ valore: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(etichetta)
                .font(Tipo.rigaSecondario)
                .foregroundColor(Colori.Colonna.rigaSecondario)
            Text(valore)
                .font(Tipo.widgetNumero)
                .foregroundColor(Colori.Widget.numero)
                .incisione(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Intestazione in pelle con la scelta del cliente.
    private var intestazione: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 12) {
                if let c = stato.clienteAttivo {
                    AvatarCliente(iniziali: c.iniziali, tinta: c.tinta.colori)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("IL CLIENTE IN PRIMO PIANO")
                        .font(Tipo.colonnaEtichetta)
                        .tracking(0.5)
                        .foregroundColor(Colori.Colonna.pelleEtichetta)
                    Button {
                        sceltaCliente = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(stato.clienteAttivo?.nome ?? "Nessun cliente")
                                .font(Tipo.colonnaNome)
                                .foregroundColor(Colori.Colonna.pelleNome)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Colori.Colonna.pelleNome)
                        }
                        .incisione(Color.black.opacity(0.45), y: -1)
                    }
                    .buttonStyle(StileSemplice())
                    .popover(isPresented: $sceltaCliente, arrowEdge: .bottom) { elencoClienti }
                }
                Spacer(minLength: 0)
            }
            Text(stato.clienteAttivo?.tema ?? "")
                .font(Tipo.colonnaTema)
                .foregroundColor(Colori.Colonna.pelleTema)
                .lineLimit(1)
        }
        .padding(EdgeInsets(top: 13, leading: 14, bottom: 10, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Materiale.Pelle())
        .clipped()
        .luceInterna(Colori.Colonna.pelleLuce, bordo: 0)
        .ombraInternaBasso(Colori.Colonna.pelleOmbra, spessore: 2, bordo: 1)
        .bordoBasso(Colori.Colonna.pelleBordo)
    }

    private var elencoClienti: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(stato.clienti) { c in
                Button {
                    stato.clienteAttivoId = c.id
                    sceltaCliente = false
                } label: {
                    HStack(spacing: 10) {
                        AvatarCliente(iniziali: c.iniziali, tinta: c.tinta.colori, lato: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.nome).font(Tipo.rigaNome).foregroundColor(Colori.Colonna.rigaNome)
                            Text(c.tema).font(Tipo.rigaSecondario).foregroundColor(Colori.Colonna.rigaSecondario)
                        }
                        Spacer(minLength: 12)
                        if c.id == stato.clienteAttivoId {
                            Image(systemName: "checkmark").foregroundColor(Colori.Colonna.collegamento)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
                .buttonStyle(StileSemplice())
                if c.id != stato.clienti.last?.id {
                    Rectangle().fill(Colori.Colonna.rigaBordo).frame(height: 1)
                }
            }
        }
        .frame(width: 270)
        .padding(.vertical, 4)
        .background(Colori.Colonna.sfondo)
    }
}

// MARK: - Da fare

struct WidgetAttivita: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        VStack(spacing: 0) {
            IntestazioneLion(titolo: "Da fare") {
                if !stato.attivitaAperte.isEmpty {
                    Badge(numero: stato.attivitaAperte.count, grande: false)
                }
                CollegamentoApp(testo: "Apri Attività ↗", app: .attivita)
            }
            ScrollView {
                VStack(spacing: 0) {
                    let aperte = stato.attivitaAperte
                    if aperte.isEmpty {
                        Text("Tutto fatto. Nessuna attività aperta.")
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
                .padding(.horizontal, 15)
            }
        }
        .corniceWidget(Colori.Widget.cartaBianca)
    }
}

// MARK: - Posizioni

struct WidgetPosizioni: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IntestazioneLion(titolo: "Posizioni") {
                CollegamentoApp(testo: "Apri ↗", app: .posizioni)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Il cuore di Prisma: le posizioni in essere e in proposta, sempre divise per canale.")
                    .font(Tipo.rigaSecondario)
                    .foregroundColor(Colori.Colonna.rigaSecondario)
                    .fixedSize(horizontal: false, vertical: true)
                EtichettaCanale(canale: .alleanza, compatta: true)
                EtichettaCanale(canale: .indipendente, compatta: true)
            }
            .padding(Misure.Widget.margine)
        }
        .corniceWidget(Colori.Widget.cartaBianca)
    }
}

// MARK: - Eve

struct WidgetEve: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        Button {
            stato.apri(.eve)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                IconaApp(app: .eve, lato: 44)
                    .ombraCSS(Colori.Scrivania.iconaOmbra1, y: 2, sfocatura: 1)
                Text("Ritrova il filo con Eve.")
                    .font(Tipo.eveTitolo)
                    .foregroundColor(Colori.Colonna.eveTitolo)
                Text("Incontri, sintesi e prossimi passi")
                    .font(Tipo.eveTesto)
                    .foregroundColor(Colori.Colonna.eveTesto)
                Spacer(minLength: 0)
                Text("Chiedi a Eve ›")
                    .font(Tipo.colonnaCollegamento)
                    .foregroundColor(Colori.Colonna.eveTesto)
            }
            .incisione(.black, y: -1)
            .padding(Misure.Widget.margine)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .luceInterna(Color.white.opacity(0.2), bordo: 1)
        }
        .buttonStyle(StileSemplice())
        .corniceWidget(Materiale.Lino())
    }
}
