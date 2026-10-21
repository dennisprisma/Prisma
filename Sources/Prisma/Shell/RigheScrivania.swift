import SwiftUI

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

/// Elenco dei clienti in un riquadro a comparsa, per scegliere il cliente in primo piano.
struct ElencoClienti: View {
    @EnvironmentObject var stato: StatoShell
    @Binding var aperto: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(stato.clienti) { c in
                Button {
                    stato.clienteAttivoId = c.id
                    aperto = false
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
                    .contentShape(Rectangle())
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
