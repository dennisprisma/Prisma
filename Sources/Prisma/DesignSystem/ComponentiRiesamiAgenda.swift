import SwiftUI

// MARK: - Riesami del mese (Agenda) e giorni di lavoro (Impostazioni)
// Viste pure: ricevono dati e azioni, senza StatoShell. Valori grafici in MisureRiesamiAgenda.swift.

/// Una scheda della striscia: il cliente, da quando il riesame è dovuto, i punti e i canali.
struct VoceRiesameAgenda: Identifiable {
    /// Id del cliente.
    let id: String
    let nome: String
    let iniziali: String
    let tinta: Colori.Avatar.Tinta
    /// «Scaduto dal 28 settembre» · «Dovuto dal 18 novembre» · «Mai incontrato in Prisma».
    let stato: String
    /// Scaduto o mai incontrato: lo stato in evidenza.
    let scaduto: Bool
    /// nil se il riesame non si è potuto calcolare.
    let punti: Int?
    /// Punti dell'ordine del giorno con priorità alta.
    let alta: Int
    /// 1 o 2 etichette; vuoto = nessuna.
    let canali: [Canale]
}

/// La striscia «Riesami del mese» in testa all'Agenda: intera (riga di testa e schede) o compatta (una riga).
struct StrisciaRiesami: View {
    /// «Ottobre 2026».
    let titoloMese: String
    /// Le schede mostrate (al massimo `Misure.RiesamiAgenda.massimoSchede`).
    let voci: [VoceRiesameAgenda]
    /// I clienti da fissare oltre le schede mostrate.
    var altri = 0
    /// Revisioni periodiche già in agenda nel mese.
    let fissati: Int
    /// Finestra bassa: una riga sola.
    let compatta: Bool
    let solaLettura: Bool
    @Binding var ridotta: Bool
    let prepara: (String) -> Void
    let pianifica: (String) -> Void
    let apriPortafoglio: () -> Void

    private var m: Misure.RiesamiAgenda.Type { Misure.RiesamiAgenda.self }
    private var daFissare: Int { voci.count + altri }

    var body: some View {
        Group {
            if compatta || ridotta { rigaCompatta } else { intera }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.sottile, forma: .arrotondata(Tema.Raggio.scheda))
    }

    // MARK: Intera

    private var intera: some View {
        VStack(alignment: .leading, spacing: m.spazioSotto) {
            HStack(alignment: .firstTextBaseline, spacing: m.spazioTesta) {
                occhiello
                riassunto
                    .font(Tipo.notaSettimana)
                    .foregroundColor(Colori.Agenda.notaSettimana)
                    .lineLimit(1)
                Spacer(minLength: 0)
                collegamento
                freccia
            }
            if !voci.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: m.spazioSchede) {
                        ForEach(voci) { v in
                            SchedaRiesameAgenda(voce: v, solaLettura: solaLettura,
                                                prepara: { prepara(v.id) }, pianifica: { pianifica(v.id) })
                        }
                        if altri > 0 {
                            Button(altri == 1 ? "…e un altro cliente" : "…e altri \(altri) clienti", action: apriPortafoglio)
                                .buttonStyle(StileSemplice())
                                .font(Tipo.notaSettimanaForte)
                                .foregroundColor(Colori.Colonna.collegamento)
                                .help("I riesami di tutti i clienti nel Portafoglio di Posizioni")
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(m.margine)
    }

    /// «Ottobre 2026 · 3 da fissare · 1 revisione in agenda» (numeri più marcati).
    private var riassunto: Text {
        let forte = Tipo.notaSettimanaForte
        var t = Text(titoloMese)
        let separatore = Text(verbatim: " · ")
        if daFissare > 0 {
            let numero: Text = Text(verbatim: "\(daFissare)").font(forte)
            t = t + separatore
            t = t + numero
            t = t + Text(verbatim: " da fissare")
        } else {
            t = t + Text(verbatim: " · nessun riesame da fissare")
        }
        if fissati > 0 {
            let numero: Text = Text(verbatim: "\(fissati)").font(forte)
            let coda: String = fissati == 1 ? " revisione in agenda" : " revisioni in agenda"
            t = t + separatore
            t = t + numero
            t = t + Text(verbatim: coda)
        }
        return t
    }

    private var occhiello: some View {
        Text("RIESAMI DEL MESE")
            .font(Tipo.paginaOcchiello)
            .tracking(m.trackingOcchiello)
            .foregroundColor(Colori.Agenda.paginaOcchiello)
            .lineLimit(1)
            .fixedSize()
    }

    private var collegamento: some View {
        Button(action: apriPortafoglio) {
            HStack(spacing: Misure.RiesamiAgenda.spazioFreccia) {
                Text("Nel Portafoglio")
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(StileCollegamento())
        .fixedSize()
            .help("I riesami di tutti i clienti nel Portafoglio di Posizioni")
    }

    /// Riduce o allarga la striscia; con la finestra bassa la striscia resta comunque su una riga.
    @ViewBuilder private var freccia: some View {
        if !compatta {
            Button { ridotta.toggle() } label: {
                Image(systemName: ridotta ? "chevron.down" : "chevron.up")
                    .font(Tipo.riesameCompatto)
                    .foregroundColor(Colori.Agenda.notaSettimana)
                    .contentShape(Rectangle())
            }
            .buttonStyle(StileSemplice())
            .help(ridotta ? "Mostra le schede" : "Riduci la striscia")
        }
    }

    // MARK: Compatta

    private var rigaCompatta: some View {
        HStack(alignment: .center, spacing: m.spazioTesta) {
            occhiello
            Group {
                if voci.isEmpty {
                    riassunto
                } else {
                    Text("\(daFissare)").font(Tipo.notaSettimanaForte) + Text(" da fissare")
                }
            }
            .font(Tipo.notaSettimana)
            .foregroundColor(Colori.Agenda.notaSettimana)
            .lineLimit(1)
            .fixedSize()
            if voci.isEmpty {
                Spacer(minLength: 0)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: m.spazioSchede) {
                        ForEach(voci) { v in pastiglia(v) }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            collegamento
            freccia
        }
        .padding(m.margineCompatta)
    }

    /// Avatar piccolo, nome, punti del canale e «Pianifica»; lo stato è nell'aiuto.
    private func pastiglia(_ v: VoceRiesameAgenda) -> some View {
        var punti = ""
        if let n = v.punti {
            let parola: String = n == 1 ? "punto" : "punti"
            punti = " · \(n) \(parola)"
        }
        return HStack(spacing: m.spazioScheda) {
            AvatarCliente(iniziali: v.iniziali, tinta: v.tinta, lato: m.avatarCompatto)
            Text(v.nome)
                .font(Tipo.eventoDettagli)
                .foregroundColor(Colori.Agenda.evento)
                .lineLimit(1)
            HStack(spacing: m.spazioCanali) {
                ForEach(v.canali) { c in
                    Circle()
                        .fill(Colori.Agenda.puntoCanale(c))
                        .frame(width: m.puntoCanale, height: m.puntoCanale)
                }
            }
            Button("Pianifica") { pianifica(v.id) }
                .buttonStyle(StileVetro(margine: m.pulsanteCompatto))
                .disabled(solaLettura)
                .help("Cerca il primo spazio libero di un'ora negli orari di lavoro, senza sovrapposizioni, con l'ordine del giorno nelle note")
        }
        .padding(m.marginePastiglia)
        .vetro(.chip, forma: .capsula, riempimento: Colori.Agenda.riesameFondo)
        .help(v.stato + punti)
    }
}

/// Una scheda della striscia intera: cliente e canali, stato e punti, «Prepara» e «Pianifica».
struct SchedaRiesameAgenda: View {
    let voce: VoceRiesameAgenda
    let solaLettura: Bool
    let prepara: () -> Void
    let pianifica: () -> Void

    var body: some View {
        let m = Misure.RiesamiAgenda.self
        VStack(alignment: .leading, spacing: m.spazioRighe) {
            HStack(spacing: m.spazioScheda) {
                AvatarCliente(iniziali: voce.iniziali, tinta: voce.tinta, lato: m.avatar)
                Text(voce.nome)
                    .font(Tipo.eventoTitolo)
                    .foregroundColor(Colori.Agenda.evento)
                    .lineLimit(1)
                Spacer(minLength: 0)
                // Con due canali tutte e due le etichette: il canale resta sempre riconoscibile
                HStack(spacing: m.spazioCanali) {
                    ForEach(voce.canali) { c in EtichettaCanale(canale: c, compatta: true) }
                }
            }
            HStack(spacing: m.spazioScheda) {
                Text(voce.stato)
                    .foregroundColor(voce.scaduto ? Colori.Agenda.riesameScaduto : Colori.Agenda.riesameDovuto)
                    .lineLimit(1)
                if let n = voce.punti {
                    Text("· \(n) \(n == 1 ? "punto" : "punti")")
                        .foregroundColor(Colori.Agenda.riesameDovuto)
                        .lineLimit(1)
                        .fixedSize()
                }
                if voce.alta > 0 {
                    Pillola(testo: "\(voce.alta) alta", tono: .errore)
                }
                Spacer(minLength: 0)
            }
            .font(Tipo.eventoDettagli)
            HStack(spacing: m.spazioScheda) {
                Button("Prepara", action: prepara)
                    .buttonStyle(StileVetro(margine: m.pulsante))
                    .help("Apri il prospetto del riesame di \(voce.nome)")
                Spacer(minLength: 0)
                // L'azione consigliata della scheda, in vetro con l'accento: il blu dell'Agenda è «Appuntamento»
                Button(action: pianifica) {
                    Label("Pianifica", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(StileVetro(margine: m.pulsante, accento: true))
                    .disabled(solaLettura)
                    .help("Cerca il primo spazio libero di un'ora negli orari di lavoro, senza sovrapposizioni, con l'ordine del giorno nelle note")
            }
        }
        .padding(m.margineScheda)
        .frame(width: m.larghezzaScheda, alignment: .leading)
        .vetro(.chip, forma: .arrotondata(Tema.Raggio.Dossier.riquadro), riempimento: Colori.Agenda.riesameFondo)
    }
}

/// I giorni di lavoro in Impostazioni: sette cerchi da lunedì a domenica (L M M G V S D).
/// L'ultimo giorno rimasto non si spegne; `giorni` resta in ordine crescente (`Calendar.weekday`).
struct SceltaGiorniLavoro: View {
    @Binding var giorni: [Int]

    private struct Giorno: Identifiable {
        /// `Calendar.weekday` (1 = domenica … 7 = sabato).
        let id: Int
        let lettera: String
        let nome: String
    }

    private static let settimana: [Giorno] = [
        Giorno(id: 2, lettera: "L", nome: "Lunedì"), Giorno(id: 3, lettera: "M", nome: "Martedì"),
        Giorno(id: 4, lettera: "M", nome: "Mercoledì"), Giorno(id: 5, lettera: "G", nome: "Giovedì"),
        Giorno(id: 6, lettera: "V", nome: "Venerdì"), Giorno(id: 7, lettera: "S", nome: "Sabato"),
        Giorno(id: 1, lettera: "D", nome: "Domenica"),
    ]

    var body: some View {
        HStack(spacing: Misure.RiesamiAgenda.spazioGiorni) {
            ForEach(SceltaGiorniLavoro.settimana) { g in
                Button { alterna(g.id) } label: { cerchio(g, scelto: giorni.contains(g.id)) }
                    .buttonStyle(StileSemplice())
                    .help(g.nome)
            }
        }
    }

    @ViewBuilder private func cerchio(_ g: Giorno, scelto: Bool) -> some View {
        let lato = Misure.RiesamiAgenda.giorno
        let lettera = Text(g.lettera)
            .font(Tipo.giornoLavoro)
            .foregroundColor(scelto ? Colori.Agenda.giornoLavoroSceltoTesto : Colori.Agenda.giornoLavoroTesto)
            .frame(width: lato, height: lato)
            .contentShape(Circle())
        if scelto {
            lettera.background { Circle().fill(Colori.Agenda.giornoLavoroScelto) }
        } else {
            lettera.vetro(.chip, forma: .capsula)
        }
    }

    private func alterna(_ giorno: Int) {
        var scelti = Set(giorni)
        if scelti.contains(giorno) {
            // L'ultimo giorno rimasto non si spegne
            guard scelti.count > 1 else { return }
            scelti.remove(giorno)
        } else {
            scelti.insert(giorno)
        }
        giorni = scelti.sorted()
    }
}
