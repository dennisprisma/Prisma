#if os(iOS)
import SwiftUI

// I widget della scrivania dell'iPhone (Design/iphone.html, schermata 1): la stessa cornice di vetro dei widget del
// Mac, uno per riga, in ordine di importanza. In alto il prossimo incontro in grande, poi ciò che richiede attenzione,
// la riga di Eve (la sfera) e il portafoglio.

private typealias M = Tema.Misura.ScrivaniaTelefono

/// Il prossimo incontro: fra quanto, l'ora grande, il titolo, il cliente con i canali e due pulsanti.
struct WidgetIncontroTelefono: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile

    var body: some View {
        TimelineView(.everyMinute) { contesto in
            let adesso = contesto.date
            let prossimo = stato.prossimiAppuntamenti.first { $0.inizio.addingTimeInterval(Double($0.durataMinuti) * 60) >= adesso }
            VStack(alignment: .leading, spacing: 0) {
                IntestazioneWidget(titolo: "Prossimo incontro", icona: .agenda) {
                    CollegamentoApp(testo: "Apri Agenda", app: .agenda)
                }
                if let a = prossimo {
                    incontro(a, adesso: adesso)
                } else {
                    Text("Nessun incontro in programma.")
                        .font(Tipo.Mobile.corpo)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
            }
        }
        .padding(Tema.Misura.widgetMargine)
        .corniceWidget()
    }

    private func incontro(_ a: Appuntamento, adesso: Date) -> some View {
        let cliente = stato.cliente(a.clienteId)
        return VStack(alignment: .leading, spacing: M.spazioRighe) {
            Text(Self.quando(a.inizio, adesso: adesso).uppercased())
                .font(Tipo.Mobile.occhielloIncontro)
                .tracking(Tipo.Mobile.spaziaturaOcchiello)
                .foregroundColor(Tema.Colore.accento)
            Text(Formati.ora.string(from: a.inizio))
                .font(Tipo.Mobile.cifraPrincipale)
                .foregroundColor(Tema.Colore.inchiostro)
            Text(a.titolo)
                .font(Tipo.Mobile.titoloIncontro)
                .foregroundColor(Tema.Colore.inchiostro)
                .fixedSize(horizontal: false, vertical: true)
            if let c = cliente {
                HStack(spacing: M.spazioRighe * 2) {
                    AvatarCliente(iniziali: c.iniziali, tinta: c.tinta.colori, lato: M.avatar)
                    VStack(alignment: .leading, spacing: M.spazioTesto) {
                        HStack(spacing: M.spazioTesto * 2) {
                            Text(c.nome).font(Tipo.Mobile.rigaNome).foregroundColor(Tema.Colore.inchiostro)
                            PuntiniCanaliTelefono(canali: c.canali)
                        }
                        Text([a.luogo, "\(a.durataMinuti) min"].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(Tipo.Mobile.rigaDettaglio)
                            .foregroundColor(Tema.Colore.inchiostroSecondario)
                    }
                }
                .padding(.top, M.spazioRighe)
                HStack(spacing: M.spazioPulsanti) {
                    Button {
                        stato.evePortafoglio = false
                        stato.clienteAttivoId = c.id
                        mobile.apri(.eve)
                    } label: {
                        Text("Prepara con Eve").frame(maxWidth: .infinity, minHeight: M.pulsante)
                    }
                    .buttonStyle(StileBlu())
                    Button {
                        stato.clienteAttivoId = c.id
                        mobile.apri(.clienti)
                        mobile.percorsoClienti = [.cliente(c.id)]
                    } label: {
                        Text("Apri la scheda").frame(maxWidth: .infinity, minHeight: M.pulsante)
                    }
                    .buttonStyle(StileVetro())
                }
                .font(Tipo.Mobile.pulsante)
                .padding(.top, M.spazioRighe * 2)
            }
        }
    }

    /// «Tra 25 minuti», «Tra 2 ore», «Domani», «Lunedì 2»…
    static func quando(_ inizio: Date, adesso: Date) -> String {
        let minuti = Int(inizio.timeIntervalSince(adesso) / 60)
        if minuti <= 0 { return "Adesso" }
        if minuti < 60 { return "Tra \(minuti) \(minuti == 1 ? "minuto" : "minuti")" }
        if Calendar.current.isDate(inizio, inSameDayAs: adesso) {
            let ore = minuti / 60
            return "Oggi, tra \(ore) \(ore == 1 ? "ora" : "ore")"
        }
        return Formati.giornoRelativo(inizio)
    }
}

/// I puntini dei canali del cliente (versione compatta: resta il colore del canale).
struct PuntiniCanaliTelefono: View {
    let canali: [Canale]

    var body: some View {
        HStack(spacing: M.spazioTesto) {
            ForEach(canali) { c in
                Circle().fill(Tema.Colore.canale(c)).frame(width: M.puntino, height: M.puntino)
            }
        }
        .accessibilityLabel(canali.map(\.nome).joined(separator: " e "))
    }
}

/// Ciò che richiede attenzione: scadenze vicine, attività di oggi o scadute, proposte ferme. In rosso e arancio.
struct WidgetAttenzioneTelefono: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile

    private struct Voce: Identifiable {
        enum Livello { case urgente, vicino, oggi }
        let id: String
        let livello: Livello
        let titolo: String
        let sotto: String
        var canale: Canale?
        let apri: () -> Void
    }

    var body: some View {
        let voci = Array(elenco.prefix(M.massimoAttenzione))
        VStack(alignment: .leading, spacing: 0) {
            IntestazioneWidget(titolo: "Richiede attenzione", icona: .attivita) {
                CollegamentoApp(testo: "Tutto", app: .attivita)
            }
            if voci.isEmpty {
                Text("Niente di urgente: tutto in ordine.")
                    .font(Tipo.Mobile.corpo)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
            }
            ForEach(Array(voci.enumerated()), id: \.element.id) { i, v in
                Button(action: v.apri) { riga(v) }
                    .buttonStyle(StileSemplice())
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(Tema.Colore.separatore).frame(height: Tema.Misura.filo) }
                    }
            }
        }
        .padding(Tema.Misura.widgetMargine)
        .corniceWidget()
    }

    private func riga(_ v: Voce) -> some View {
        HStack(alignment: .top, spacing: M.spazioRighe * 2) {
            ZStack {
                RoundedRectangle(cornerRadius: M.raggioSegno, style: .continuous).fill(colore(v.livello))
                Image(systemName: simbolo(v.livello)).font(Tipo.Mobile.simboloAttenzione).foregroundColor(.white)
            }
            .frame(width: M.segno, height: M.segno)
            VStack(alignment: .leading, spacing: M.spazioTesto) {
                Text(v.titolo)
                    .font(Tipo.Mobile.rigaNome)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: M.spazioRighe) {
                    Text(v.sotto)
                        .font(Tipo.Mobile.rigaDettaglio)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .lineLimit(1)
                    if let c = v.canale { EtichettaCanale(canale: c, compatta: true) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, M.spazioRighe * 2)
        .contentShape(Rectangle())
    }

    private func colore(_ l: Voce.Livello) -> Color {
        switch l {
        case .urgente: return Tema.Colore.rosso
        case .vicino: return Tema.Colore.arancio
        case .oggi: return Tema.Colore.accento
        }
    }

    private func simbolo(_ l: Voce.Livello) -> String {
        switch l {
        case .urgente: return "exclamationmark"
        case .vicino: return "clock"
        case .oggi: return "checkmark"
        }
    }

    private var elenco: [Voce] {
        var voci: [Voce] = []
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: Date())
        // Le posizioni in scadenza: entro 30 giorni in rosso, poi in arancio
        for p in stato.riepilogoTuttePosizioni.inScadenza.prefix(3) {
            let giorni = max(0, cal.dateComponents([.day], from: oggi, to: cal.startOfDay(for: p.scadenza ?? oggi)).day ?? 0)
            let titolo = p.scaduta ? "\(p.nome) è scaduta" : giorni == 0 ? "\(p.nome) scade oggi" : "\(p.nome) scade tra \(giorni) \(giorni == 1 ? "giorno" : "giorni")"
            voci.append(Voce(id: "p-" + p.id, livello: p.scaduta || giorni <= 30 ? .urgente : .vicino, titolo: titolo,
                             sotto: stato.cliente(p.clienteId)?.nome ?? "", canale: p.canale) {
                stato.apriPosizione(p)
                mobile.apri(.posizioni)
                mobile.percorsoPosizioni = [.posizione(p.id)]
            })
        }
        // Le attività di oggi (e quelle rimaste indietro)
        let daFare = stato.attivitaAperte.filter { $0.scadenza < cal.date(byAdding: .day, value: 1, to: oggi) ?? oggi }
        if !daFare.isEmpty {
            let indietro = daFare.contains { $0.scadenza < oggi }
            voci.append(Voce(id: "attivita", livello: indietro ? .urgente : .oggi,
                             titolo: "\(daFare.count) \(daFare.count == 1 ? "attività" : "attività") per oggi",
                             sotto: daFare.prefix(2).map(\.titolo).joined(separator: " · ")) { mobile.apri(.attivita) })
        }
        // Le proposte che aspettano una risposta
        let ferme = stato.proposteInSospeso
        if !ferme.isEmpty {
            voci.append(Voce(id: "proposte", livello: ferme.contains { $0.urgente } ? .urgente : .vicino,
                             titolo: TestiSeguito.aspettano(ferme.count),
                             sotto: ferme.prefix(2).map(\.cliente.nome).joined(separator: " · ")) {
                stato.posizioneInDettaglio = nil
                stato.portafoglio = true
                mobile.apri(.posizioni)
            })
        }
        return voci.sorted { ordine($0.livello) < ordine($1.livello) }
    }

    private func ordine(_ l: Voce.Livello) -> Int {
        switch l {
        case .urgente: return 0
        case .vicino: return 1
        case .oggi: return 2
        }
    }
}

/// La riga di Eve sulla scrivania: la sfera, una frase, lo stato di Qwen sul Mac. Un tocco apre Eve.
struct BarraEveTelefono: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile

    var body: some View {
        Button { mobile.apri(.eve) } label: {
            HStack(spacing: M.spazioRighe * 2) {
                SferaAcquaEve(lato: M.sfera, spenta: !stato.disponibilitaLocale.pronto, animata: false)
                VStack(alignment: .leading, spacing: M.spazioTesto) {
                    Text("Ritrova il filo con Eve.")
                        .font(Tipo.Mobile.rigaNome)
                        .foregroundColor(Tema.Colore.inchiostro)
                    Text(stato.disponibilitaLocale.pronto ? "Qwen sul Mac · sintesi e prossimi passi" : "Collegala a Qwen del tuo Mac")
                        .font(Tipo.Mobile.rigaDettaglio)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Tipo.Mobile.etichetta)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
            }
            .padding(Tema.Misura.widgetMargine)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
        .corniceWidget()
    }
}
#endif
