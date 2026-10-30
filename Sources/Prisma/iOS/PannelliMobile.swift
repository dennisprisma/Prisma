#if os(iOS)
import SwiftUI

/// I livelli sopra la scrivania e la finestra di iPhone e iPad, come i pannelli di CorpoShell sul Mac: il centro
/// notifiche del Mac (`PannelloNotifiche`, sotto la barra a destra), il centro di controllo, «Tutte le app» (iPhone),
/// le app aperte (iPad), la Ricerca come Spotlight, la guida e la presentazione. Ognuno nel suo contenitore animato:
/// l'animazione resta sua e non tocca il resto.
struct PannelliMobile: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile
    @ObservedObject var sistema: StatoFinestre
    /// Dove finisce la barra (safe area + barra): i pannelli a destra stanno 6 punti sotto.
    let sottoBarra: CGFloat
    let misura: CGSize

    private typealias P = Tema.Misura.Mobile.Pannelli

    var body: some View {
        let alto = sottoBarra + P.sottoBarra
        ZStack(alignment: .topLeading) {
            ZStack {
                if sistema.pannelloNotifiche {
                    // Il pannello del Mac sta `Misure.Notifiche.alto` sotto il bordo: qui sotto la barra di iOS
                    PannelloNotifiche()
                        .padding(.top, max(0, alto - Misure.Notifiche.alto))
                        .frame(width: misura.width, height: misura.height)
                        .transition(.velo)
                }
            }
            .animation(Movimenti.curva(sistema.pannelloNotifiche ? Tema.Moto.Pannelli.notifiche : Tema.Moto.Pannelli.notificheUscita),
                       value: sistema.pannelloNotifiche)

            ZStack {
                if let pannello = mobile.pannello {
                    ZStack {
                        VeloPannelloMobile { mobile.pannello = nil }
                        scheda(pannello, alto: alto)
                    }
                    .transition(.velo)
                }
            }
            .animation(Movimenti.curva(mobile.pannello != nil ? Tema.Moto.Pannelli.appAperte : Tema.Moto.Pannelli.appAperteUscita),
                       value: mobile.pannello)

            ZStack {
                if sistema.pannelloRicerca {
                    RicercaSpotlight()
                        .frame(width: misura.width, height: misura.height)
                        .transition(.opacity)
                }
            }
            .animation(Movimenti.curva(sistema.pannelloRicerca ? Tema.Moto.Spotlight.entrata : Tema.Moto.Spotlight.uscita),
                       value: sistema.pannelloRicerca)

            ZStack {
                if sistema.guida != nil {
                    PannelloGuida()
                        .frame(width: misura.width, height: misura.height)
                        .transition(.opacity)
                }
            }
            .animation(Movimenti.curva(sistema.guida != nil ? Tema.Moto.Guida.entrata : Tema.Moto.Guida.uscita),
                       value: sistema.guida != nil)

            if let p = stato.presentazione {
                VistaPresentazione(p: p)
                    .frame(width: misura.width, height: misura.height)
                    .transition(.opacity)
            }
        }
        .frame(width: misura.width, height: misura.height, alignment: .topLeading)
    }

    /// La scheda del pannello: il centro di controllo sotto la barra a destra (.cc), le app al centro (.switcher).
    @ViewBuilder private func scheda(_ pannello: PannelloMobile, alto: CGFloat) -> some View {
        switch pannello {
        case .controllo:
            CentroControlloMobile()
                .frame(width: max(0, min(P.controllo, misura.width - 2 * P.margine)))
                .entrataScheda(Tema.Moto.Pannelli.notifiche, scala: Tema.Moto.Pannelli.spaziScala, ancora: .topTrailing)
                .padding(.top, alto)
                .padding(.trailing, P.margine)
                .frame(width: misura.width, height: misura.height, alignment: .topTrailing)
        case .tutteLeApp:
            TutteLeAppMobile()
                .frame(width: max(0, min(P.appAperte, misura.width - 2 * P.bordoAppAperte)))
                .frame(maxHeight: max(0, misura.height * P.quotaAltezza))
                .fixedSize(horizontal: false, vertical: true)
                .entrataScheda(Tema.Moto.Pannelli.appAperte, scala: Tema.Moto.Pannelli.appAperteScala, ancora: .center)
                .frame(width: misura.width, height: misura.height)
        case .appAperte:
            AppAperteiPad()
                .frame(width: max(0, min(P.appAperte, misura.width - 2 * P.bordoAppAperte)))
                .frame(maxHeight: max(0, misura.height * P.quotaAltezza))
                .fixedSize(horizontal: false, vertical: true)
                .entrataScheda(Tema.Moto.Pannelli.appAperte, scala: Tema.Moto.Pannelli.appAperteScala, ancora: .center)
                .frame(width: misura.width, height: misura.height)
        }
    }
}

/// Il velo sotto un pannello (.scrim del tema): si tocca per chiudere.
private struct VeloPannelloMobile: View {
    let chiudi: () -> Void

    var body: some View {
        Tema.Colore.Shell.veloPannello
            .contentShape(Rectangle())
            .onTapGesture(perform: chiudi)
            .accessibilityLabel(Text("Chiudi il pannello"))
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Centro di controllo

/// Il centro di controllo del tema (.cc): pannello di vetro con le tessere in due colonne (.cc-tile, chip raggio 20).
/// In cima, larghe: aspetto, sfondo e pioggia (gli stessi valori di Impostazioni › Esperienza). Sotto, rotonde:
/// apri un backup, invia il backup al Mac, modalità cliente, impostazioni.
struct CentroControlloMobile: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile

    private typealias P = Tema.Misura.Mobile.Pannelli

    var body: some View {
        let impostazioni = stato.dati.impostazioni
        VStack(spacing: P.spazioTessere) {
            tessera("Aspetto") {
                ControlloSegmenti(opzioni: AspettoInterfaccia.allCases.map { ($0, $0.nome) },
                                  selezione: $stato.dati.impostazioni.aspetto, riempi: true)
            }
            tessera("Sfondo") {
                ControlloSegmenti(opzioni: [(true, "Animato"), (false, "Fermo")],
                                  selezione: $stato.dati.impostazioni.sfondoAnimato, riempi: true)
            }
            tessera("Pioggia") {
                ControlloSegmenti(opzioni: IntensitaPioggia.allCases.map { ($0, $0.nome) },
                                  selezione: $stato.dati.impostazioni.pioggia, riempi: true)
                    .disabled(!impostazioni.sfondoAnimato)
                    .opacity(impostazioni.sfondoAnimato ? 1 : Tema.Misura.Shell.opacitaDisabilitato)
            }
            HStack(spacing: P.spazioTessere) {
                TesseraRotonda(simbolo: "lock.doc", titolo: "Apri un backup", stato: "Dal Mac", acceso: false) {
                    mobile.apriBackup()
                }
                .disabled(stato.backupInCorso || mobile.preparazioneBackup)
                TesseraRotonda(simbolo: "square.and.arrow.up", titolo: "Backup per il Mac", stato: "Impostazioni › Archivio",
                               acceso: false) {
                    stato.schedaImpostazioni = .archivio
                    mobile.apri(.impostazioni)
                }
                .disabled(!stato.appConsentita(.impostazioni))
            }
            HStack(spacing: P.spazioTessere) {
                TesseraRotonda(simbolo: stato.inModoCliente ? "person.fill.checkmark" : "person.crop.rectangle",
                               titolo: "Modalità cliente", stato: stato.inModoCliente ? "Attiva" : "Spenta",
                               acceso: stato.inModoCliente) {
                    stato.alternaModoCliente()
                }
                TesseraRotonda(simbolo: "gearshape", titolo: "Impostazioni", stato: "Tutte le scelte", acceso: false) {
                    mobile.apri(.impostazioni)
                }
                .disabled(!stato.appConsentita(.impostazioni))
            }
        }
        .padding(P.margineControllo)
        .vetro(.pannello, forma: .arrotondata(Tema.Raggio.centroControllo), riempimento: Tema.Colore.PannelliShell.coprente)
    }

    /// Una tessera larga (.cc-tile.wide): il titolo piccolo e il controllo.
    private func tessera<C: View>(_ titolo: String, @ViewBuilder _ contenuto: () -> C) -> some View {
        VStack(alignment: .leading, spacing: P.spazioTessera) {
            Text(titolo)
                .font(Tipo.Mobile.titoloTessera)
                .foregroundColor(Tema.Colore.inchiostroSecondario)
            contenuto()
        }
        .padding(P.margineTessera)
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetro(.chip, forma: .arrotondata(Tema.Raggio.Mobile.tessera), ombra: false)
    }
}

/// Una tessera rotonda del centro di controllo (.cc-round): il cerchio col simbolo (blu se acceso), nome e stato.
private struct TesseraRotonda: View {
    let simbolo: String
    let titolo: String
    let stato: String
    let acceso: Bool
    let azione: () -> Void
    @Environment(\.isEnabled) var abilitato

    private typealias P = Tema.Misura.Mobile.Pannelli

    var body: some View {
        Button(action: azione) {
            HStack(spacing: P.spazioCerchio) {
                Image(systemName: simbolo)
                    .font(Tipo.Mobile.simboloTessera)
                    .foregroundColor(acceso ? Tema.Colore.Componenti.testoSuColore : Tema.Colore.inchiostro)
                    .frame(width: P.cerchioTessera, height: P.cerchioTessera)
                    .background(Circle().fill(acceso ? Tema.Colore.accento : Tema.Colore.pozzettoScuro))
                VStack(alignment: .leading, spacing: Tema.Misura.Shell.rigaTestoSpazio) {
                    Text(titolo)
                        .font(Tipo.Mobile.nomeTessera)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(stato)
                        .font(Tipo.Mobile.statoTessera)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(P.margineTessera)
            .frame(maxWidth: .infinity, minHeight: Tema.Misura.Mobile.areaTocco, alignment: .leading)
            .contentShape(Rectangle())
            .vetro(.chip, forma: .arrotondata(Tema.Raggio.Mobile.tessera), ombra: false)
            .opacity(abilitato ? 1 : Tema.Misura.Shell.opacitaDisabilitato)
        }
        .buttonStyle(StileSemplice())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(acceso ? [.isSelected] : [])
    }
}

// MARK: - Tutte le app (iPhone)

/// «Tutte le app» sull'iPhone (il dock ne tiene quattro): pannello di vetro con le app consentite in quattro colonne,
/// nell'ordine del dock del Mac (Clienti e Posizioni, il fulcro, in cima). Un tocco apre l'app dalla sua icona.
struct TutteLeAppMobile: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile
    @EnvironmentObject var sistema: StatoFinestre

    private typealias P = Tema.Misura.Mobile.Pannelli

    var body: some View {
        let app = AppPrisma.allCases.filter { stato.appConsentita($0) }
        VStack(alignment: .leading, spacing: P.sottoTitolo) {
            HStack {
                Text("Tutte le app")
                    .font(Tipo.Mobile.titoloPannello)
                    .foregroundColor(Tema.Colore.inchiostro)
                Spacer(minLength: P.spazioGriglia)
                TestoAppAperteMobile()
                    .font(Tema.Testo.secondario)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
            }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: P.cellaApp / 2), spacing: 0, alignment: .top), count: 4),
                          spacing: P.spazioGriglia) {
                    ForEach(app) { a in
                        CellaAppMobile(app: a, aperta: sistema.aperta(a)) { origine in
                            mobile.apri(a, da: origine)
                        }
                    }
                }
            }
        }
        .padding(P.margineAppAperte)
        .vetro(.pannello, forma: .arrotondata(Tema.Raggio.appAperte), riempimento: Tema.Colore.PannelliShell.coprente)
    }
}

/// Un'app della griglia: l'icona in vetro (56), il nome sotto e il puntino se è aperta.
private struct CellaAppMobile: View {
    let app: AppPrisma
    let aperta: Bool
    let azione: (CGPoint?) -> Void
    @State var origine = OrigineApertura()

    private typealias P = Tema.Misura.Mobile.Pannelli

    var body: some View {
        Button { azione(origine.punto) } label: {
            VStack(spacing: P.spazioNome) {
                IconaApp(app: app, lato: P.iconaGriglia)
                    .misuraOrigine(origine)
                Text(app.nomeDock)
                    .font(Tipo.Mobile.etichettaIcona)
                    .foregroundColor(Tema.Colore.inchiostro)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Circle()
                    .fill(Tema.Colore.inchiostroSecondario)
                    .frame(width: Tema.Misura.puntinoDock, height: Tema.Misura.puntinoDock)
                    .opacity(aperta ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(StileIconaGrigliaMobile())
        .accessibilityLabel(Text(app.titolo))
        .accessibilityHint(Text(app.sottotitolo))
    }
}

/// Icona premuta: più scura, come nel dock.
private struct StileIconaGrigliaMobile: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? Tema.Misura.Shell.premutoDock : 0)
    }
}
#endif
