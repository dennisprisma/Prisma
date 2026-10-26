import SwiftUI

/// Il centro notifiche: si apre dalla campanella, a destra sotto la barra. Un clic su una
/// notifica porta dove si risolve; un clic fuori dal pannello lo chiude.
struct PannelloNotifiche: View {
    @EnvironmentObject var stato: StatoShell

    var body: some View {
        let elenco = stato.notifiche
        ZStack(alignment: .topTrailing) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { stato.pannelloNotifiche = false }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("CENTRO NOTIFICHE").font(Tipo.notificheOcchiello).tracking(1.7).foregroundColor(Colori.Notifiche.occhiello)
                    Spacer()
                    Button { stato.pannelloNotifiche = false } label: {
                        Text("×").font(Tipo.notificheChiudi).foregroundColor(Colori.Notifiche.chiudi)
                    }
                    .buttonStyle(StileSemplice())
                    .help("Chiudi le notifiche")
                }
                .padding(.horizontal, Misure.Notifiche.margine)
                .padding(.vertical, 12)
                .bordoBasso(Colori.Notifiche.separatore)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Il filo delle tue attività.")
                            .font(Tipo.notificheTitolo)
                            .foregroundColor(Colori.Notifiche.titolo)
                            .padding(.top, 20)
                        Text(elenco.isEmpty ? "Niente in sospeso: tutto in ordine." : "Ciò che chiede attenzione, ricavato dai tuoi dati.")
                            .font(Tipo.notificheSottotitolo)
                            .foregroundColor(Colori.Notifiche.sottotitolo)
                            .padding(.top, 6)
                            .padding(.bottom, 14)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Misure.Notifiche.margine)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Notifica.Gruppo.allCases) { g in
                            let voci = elenco.filter { $0.gruppo == g }
                            if !voci.isEmpty {
                                Text(g.titolo)
                                    .font(Tipo.notificheGruppo)
                                    .tracking(1.2)
                                    .foregroundColor(g == .daFare ? Colori.Notifiche.urgente : Colori.Notifiche.gruppo)
                                    .padding(.horizontal, Misure.Notifiche.margine)
                                    .padding(.top, 10)
                                    .padding(.bottom, 2)
                                ForEach(voci) { voce($0) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Calcolate sul Mac dai dati di Prisma")
                        .font(Tipo.notifichePiede)
                        .foregroundColor(Colori.Notifiche.piede)
                        .frame(maxWidth: .infinity)
                        .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: Misure.Notifiche.larghezza)
            .frame(maxHeight: .infinity)
            .background(Materiale.Lino())
            .clipShape(RoundedRectangle(cornerRadius: Misure.Notifiche.raggio))
            .luceInterna(Colori.Notifiche.luce, raggio: Misure.Notifiche.raggio)
            .overlay(RoundedRectangle(cornerRadius: Misure.Notifiche.raggio).strokeBorder(Colori.Notifiche.bordo, lineWidth: 1))
            .ombraCSS(Colori.Notifiche.ombra, y: 9, sfocatura: 40)
            .padding(.top, Misure.Notifiche.alto)
            .padding(.trailing, Misure.Notifiche.destra)
            .padding(.bottom, Misure.Notifiche.basso)
        }
    }

    private func voce(_ n: Notifica) -> some View {
        Button { stato.apriNotifica(n) } label: {
            HStack(spacing: 12) {
                IconaApp(app: n.app, lato: Misure.Notifiche.icona)
                VStack(alignment: .leading, spacing: 4) {
                    Text(n.titolo)
                        .font(Tipo.notificaTitolo)
                        .foregroundColor(Colori.Notifiche.voceTitolo)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        if let c = n.canale { EtichettaCanale(canale: c, compatta: true) }
                        Text(n.dettaglio)
                            .font(Tipo.notificaDettaglio)
                            .foregroundColor(Colori.Notifiche.voceDettaglio)
                            .lineLimit(1)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Text("›").font(Tipo.notificaFreccia).foregroundColor(Colori.Notifiche.freccia)
            }
            .padding(Misure.Notifiche.voce)
            .background(RoundedRectangle(cornerRadius: Misure.Notifiche.raggioVoce).fill(Gradienti.voceNotifica))
            .luceInterna(Colori.Notifiche.voceLuce, raggio: Misure.Notifiche.raggioVoce)
            .overlay(RoundedRectangle(cornerRadius: Misure.Notifiche.raggioVoce).strokeBorder(Colori.Notifiche.voceBordo, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(StileSemplice())
        .padding(Misure.Notifiche.marginiVoce)
    }
}
