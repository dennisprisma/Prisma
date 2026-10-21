import SwiftUI

/// Colonna destra della scrivania: "Il cliente in primo piano" (.os-desk-sidebar).
struct ColonnaCliente: View {
    enum Scheda: Hashable { case agenda, attivita, dossier }

    @EnvironmentObject var stato: StatoShell
    @State var scheda: Scheda = .agenda
    @State var sceltaCliente = false

    var body: some View {
        VStack(spacing: 0) {
            intestazioneCliente
            Segmentato(opzioni: [(Scheda.agenda, "Agenda"), (Scheda.attivita, "Attività"), (Scheda.dossier, "Dossier")], selezione: $scheda)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(Gradienti.schedeColonna)
                .luceInterna(Color.white.opacity(0.6))
                .bordoBasso(Colori.Colonna.schedeBordo)
            Group {
                switch scheda {
                case .agenda: pannelloAgenda
                case .attivita: pannelloAttivita
                case .dossier: pannelloDossier
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            riquadroEve
        }
        .frame(maxHeight: .infinity)
        .background(Colori.Colonna.sfondo)
        .clipShape(RoundedRectangle(cornerRadius: Misure.Colonna.raggio))
        .overlay(RoundedRectangle(cornerRadius: Misure.Colonna.raggio).strokeBorder(Colori.Colonna.bordo, lineWidth: 1))
        .ombraCSS(Colori.Colonna.ombra, y: 4, sfocatura: 13)
    }

    // MARK: Intestazione in pelle

    private var intestazioneCliente: some View {
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

    // MARK: Pannelli

    private func intestazionePannello(_ titolo: String, collegamento: String, app: AppPrisma) -> some View {
        HStack {
            Text(titolo)
                .font(Tipo.colonnaIntestazione)
                .foregroundColor(Colori.Colonna.intestazione)
            Spacer()
            Button(collegamento) { stato.apri(app) }
                .buttonStyle(StileSemplice())
                .font(Tipo.colonnaCollegamento)
                .foregroundColor(Colori.Colonna.collegamento)
        }
        .padding(EdgeInsets(top: 12, leading: 13, bottom: 7, trailing: 13))
    }

    private var pannelloAgenda: some View {
        VStack(spacing: 0) {
            intestazionePannello("PROSSIMI INCONTRI", collegamento: "Apri Agenda ↗", app: .agenda)
            ScrollView {
                VStack(spacing: 0) {
                    let eventi = Array(stato.prossimiAppuntamenti.prefix(5))
                    if eventi.isEmpty {
                        vuoto("Nessun appuntamento in programma.")
                    }
                    ForEach(eventi) { e in
                        RigaAppuntamento(evento: e, cliente: stato.cliente(e.clienteId), ultima: e.id == eventi.last?.id) {
                            stato.clienteAttivoId = e.clienteId
                            stato.apri(.agenda)
                        }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
            }
        }
    }

    private var pannelloAttivita: some View {
        VStack(spacing: 0) {
            intestazionePannello("DA FARE", collegamento: "Apri Attività ↗", app: .attivita)
            ScrollView {
                VStack(spacing: 0) {
                    let aperte = stato.attivitaAperte
                    if aperte.isEmpty {
                        vuoto("Tutto fatto. Nessuna attività aperta.")
                    }
                    ForEach(aperte) { a in
                        RigaAttivita(attivita: a, cliente: stato.cliente(a.clienteId), ultima: a.id == aperte.last?.id) {
                            withAnimation(Animazioni.passaggio) { stato.alternaCompletata(a.id) }
                        }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
            }
        }
    }

    private var pannelloDossier: some View {
        VStack(alignment: .leading, spacing: 0) {
            intestazionePannello("IL DOSSIER", collegamento: "Apri Clienti ↗", app: .clienti)
            VStack(alignment: .leading, spacing: 8) {
                if let c = stato.clienteAttivo {
                    Text(c.nota)
                        .font(Tipo.contenuto(11))
                        .foregroundColor(Colori.Colonna.rigaNome)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Patrimonio, posizioni e obiettivi compaiono qui con i moduli Clienti e Posizioni.")
                    .font(Tipo.rigaSecondario)
                    .foregroundColor(Colori.Colonna.rigaSecondario)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    EtichettaCanale(canale: .alleanza, compatta: true)
                    EtichettaCanale(canale: .indipendente, compatta: true)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 15)
        }
    }

    private func vuoto(_ testo: String) -> some View {
        Text(testo)
            .font(Tipo.rigaSecondario)
            .foregroundColor(Colori.Colonna.rigaSecondario)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }

    // MARK: Eve

    private var riquadroEve: some View {
        Button {
            stato.apri(.eve)
        } label: {
            HStack(spacing: 12) {
                IconaApp(app: .eve, lato: Misure.Colonna.iconaEve)
                    .ombraCSS(Colori.Scrivania.iconaOmbra1, y: 2, sfocatura: 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ritrova il filo con Eve.")
                        .font(Tipo.eveTitolo)
                        .foregroundColor(Colori.Colonna.eveTitolo)
                    Text("Incontri, sintesi e prossimi passi")
                        .font(Tipo.eveTesto)
                        .foregroundColor(Colori.Colonna.eveTesto)
                }
                .incisione(.black, y: -1)
                Spacer(minLength: 0)
                Text("›").font(Tipo.rigaFreccia).foregroundColor(Colori.Colonna.eveTesto)
            }
            .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
            .frame(maxWidth: .infinity)
            .background(Materiale.Lino())
            .luceInterna(Color.white.opacity(0.2), bordo: 1)
            .bordoAlto(Colori.Colonna.eveBordo)
        }
        .buttonStyle(StileSemplice())
    }
}

/// Riga di un appuntamento (.os-desk-event).
struct RigaAppuntamento: View {
    let evento: Appuntamento
    let cliente: Cliente?
    let ultima: Bool
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            HStack(spacing: 12) {
                PiastrellaData(data: evento.inizio)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Formati.ora.string(from: evento.inizio)) · \(evento.luogo)")
                        .font(Tipo.rigaSecondario)
                        .foregroundColor(Colori.Colonna.rigaSecondario)
                    Text(cliente?.nome ?? evento.titolo)
                        .font(Tipo.rigaNome)
                        .foregroundColor(Colori.Colonna.rigaNome)
                    Text(evento.titolo)
                        .font(Tipo.rigaSecondario)
                        .foregroundColor(Colori.Colonna.rigaSecondario)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                Text("›").font(Tipo.rigaFreccia).foregroundColor(Colori.Colonna.freccia)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                if !ultima {
                    VStack(spacing: 0) {
                        Rectangle().fill(Colori.Colonna.rigaBordo).frame(height: 1)
                        Rectangle().fill(Colori.Colonna.rigaLuce).frame(height: 1)
                    }
                }
            }
        }
        .buttonStyle(StileSemplice())
    }
}

/// Riga di un'attività con il segno di completamento.
struct RigaAttivita: View {
    let attivita: Attivita
    let cliente: Cliente?
    let ultima: Bool
    let completa: () -> Void

    private var scadenza: String {
        let cal = Calendar.current
        if cal.isDateInToday(attivita.scadenza) { return "Oggi" }
        if cal.isDateInTomorrow(attivita.scadenza) { return "Domani" }
        if attivita.scadenza < cal.startOfDay(for: Date()) { return "Scaduta" }
        return "\(Formati.giorno.string(from: attivita.scadenza)) \(Formati.meseBreve.string(from: attivita.scadenza))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: completa) {
                ZStack {
                    Circle().fill(Gradienti.data)
                    Circle().strokeBorder(Colori.Colonna.dataBordo, lineWidth: 1)
                    if attivita.completata {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(Colori.Colonna.collegamento)
                    }
                }
                .frame(width: 18, height: 18)
            }
            .buttonStyle(StileSemplice())
            .help("Segna come completata")
            VStack(alignment: .leading, spacing: 3) {
                Text(attivita.titolo)
                    .font(Tipo.contenuto(12, .medium))
                    .foregroundColor(Colori.Colonna.rigaNome)
                    .lineLimit(2)
                Text([cliente?.nome, scadenza].compactMap { $0 }.joined(separator: " · "))
                    .font(Tipo.rigaSecondario)
                    .foregroundColor(Colori.Colonna.rigaSecondario)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if !ultima {
                VStack(spacing: 0) {
                    Rectangle().fill(Colori.Colonna.rigaBordo).frame(height: 1)
                    Rectangle().fill(Colori.Colonna.rigaLuce).frame(height: 1)
                }
            }
        }
    }
}

extension TintaAvatar {
    var colori: Colori.Avatar.Tinta {
        switch self {
        case .blu: return Colori.Avatar.blu
        case .rosa: return Colori.Avatar.rosa
        case .verde: return Colori.Avatar.verde
        case .viola: return Colori.Avatar.viola
        case .oro: return Colori.Avatar.oro
        }
    }
}
