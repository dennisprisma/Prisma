#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

/// La prima schermata su iPhone e iPad quando l'archivio non ha ancora dati veri: «Apri il backup di Prisma
/// dal Mac». Il file arriva dal selettore (File, iCloud Drive) o da «Apri con Prisma» (AirDrop, File:
/// `onOpenURL` nella radice); la password apre il backup protetto e il ripristino usa le funzioni del Mac.
struct AperturaBackup: View {
    @EnvironmentObject var mobile: StatoMobile

    @State private var password = ""
    @State private var scegliFile = false
    @FocusState private var campoAttivo: Bool

    private typealias M = Tema.Misura.Mobile

    var body: some View {
        ZStack {
            // Sotto c'è l'acqua di RadiceMobile, la stessa della scrivania: questa schermata non ne disegna una sua
            ScrollView {
                VStack(spacing: M.spazioApertura) {
                    intestazione
                    scheda
                    piede
                }
                .frame(maxWidth: M.aperturaMassima)
                .padding(M.margine)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .fileImporter(isPresented: $scegliFile, allowedContentTypes: [.backupPrisma, .zip, .data]) { esito in
            switch esito {
            case .success(let url): mobile.ricevi(url)
            case .failure(let errore): mobile.selezioneFallita(errore)
            }
        }
        .onChange(of: mobile.fase) { fase in
            // Dopo un tentativo la password non resta scritta; con una nuova scelta si ricomincia
            if fase == .riuscita || fase == .copia { password = "" }
        }
    }

    // MARK: - Parti

    private var intestazione: some View {
        VStack(spacing: M.spazioTesto * 3) {
            LogoPrisma()
                .frame(height: M.logoApertura)
                .padding(.bottom, M.spazioTesto * 2)
            Text("Apri il backup di Prisma dal Mac")
                .font(Tipo.Mobile.titoloGrande)
                .foregroundColor(Tema.Colore.inchiostroSfondo)
                .multilineTextAlignment(.center)
            Text("I dati dei clienti arrivano dal Mac, cifrati, e restano solo su questo dispositivo.")
                .font(Tipo.Mobile.sottotitolo)
                .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
                .multilineTextAlignment(.center)
        }
        .aloneSfondo()
        .padding(.top, M.margine * 2)
    }

    private var scheda: some View {
        VStack(alignment: .leading, spacing: M.spazioApertura) {
            passi
            Divider()
            sceltaFile
            if mobile.fileScelto != nil {
                campoPassword
                pulsanteApri
            }
            messaggio
        }
        .padding(M.margineApertura)
        .vetro(.pannello, forma: .arrotondata(Tema.Raggio.Mobile.apertura))
    }

    private var passi: some View {
        VStack(alignment: .leading, spacing: M.spazioRiga) {
            passo(1, "Sul Mac, in Prisma: Impostazioni › Archivio › «Crea backup» (con la password).")
            passo(2, "Manda il file .zip.cifrato a questo dispositivo con AirDrop, oppure mettilo in iCloud Drive o in File.")
            passo(3, "Aprilo qui sotto e scrivi la password del backup.")
        }
    }

    private func passo(_ numero: Int, _ testo: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: M.spazioRiga) {
            Text("\(numero)")
                .font(Tipo.Mobile.etichetta)
                .foregroundColor(Tema.Colore.inchiostro)
                .frame(width: M.iconaLaterale * 0.8, height: M.iconaLaterale * 0.8)
                .vetro(.chip, forma: .capsula, ombra: false)
            Text(testo)
                .font(Tipo.Mobile.corpo)
                .foregroundColor(Tema.Colore.inchiostro)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sceltaFile: some View {
        Button {
            scegliFile = true
        } label: {
            HStack(spacing: M.spazioRiga) {
                Image(systemName: mobile.fileScelto == nil ? "doc.badge.plus" : "lock.doc")
                    .font(Tipo.Mobile.titolo)
                    .foregroundColor(Tema.Colore.accento)
                VStack(alignment: .leading, spacing: M.spazioTesto) {
                    Text(mobile.nomeFile ?? "Scegli il backup…")
                        .font(Tipo.Mobile.rigaNome)
                        .foregroundColor(Tema.Colore.inchiostro)
                        .lineLimit(2)
                    Text(descrizioneFile)
                        .font(Tipo.Mobile.rigaDettaglio)
                        .foregroundColor(Tema.Colore.inchiostroSecondario)
                }
                Spacer(minLength: 0)
                if mobile.fase == .copia {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Tema.Colore.inchiostroTerziario)
                }
            }
            .padding(M.margineRiga)
            .frame(minHeight: M.rigaMinima)
            .contentShape(Rectangle())
            .vetro(.sottile, forma: .arrotondata(Tema.Raggio.Mobile.riga), ombra: false)
        }
        .buttonStyle(.plain)
        .disabled(occupato)
    }

    private var descrizioneFile: String {
        guard mobile.fileScelto != nil else { return "Da File, iCloud Drive o da un AirDrop ricevuto" }
        return mobile.protetto ? "Backup protetto da password · tocca per sceglierne un altro"
                               : "Backup non protetto · tocca per sceglierne un altro"
    }

    @ViewBuilder private var campoPassword: some View {
        if mobile.protetto {
            VStack(alignment: .leading, spacing: M.spazioTesto * 2) {
                Text("PASSWORD DEL BACKUP")
                    .font(Tipo.Mobile.sezione)
                    .foregroundColor(Tema.Colore.inchiostroSecondario)
                SecureField("La password scelta sul Mac", text: $password)
                    .font(Tipo.Mobile.corpo)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($campoAttivo)
                    .onSubmit(apri)
                    .padding(.horizontal, M.spazioRiga)
                    .frame(height: M.altezzaControllo)
                    .background {
                        RoundedRectangle(cornerRadius: Tema.Raggio.Mobile.controllo, style: .continuous)
                            .fill(Tema.Colore.pozzetto)
                    }
                    .disabled(occupato)
            }
        }
    }

    private var pulsanteApri: some View {
        Button(action: apri) {
            HStack(spacing: M.spazioRiga) {
                if mobile.fase == .ripristino { ProgressView() }
                Text(mobile.fase == .ripristino ? "Apertura in corso…" : "Apri il backup")
                    .font(Tipo.Mobile.pulsante)
            }
            .frame(maxWidth: .infinity, minHeight: M.altezzaControllo)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: Tema.Raggio.Mobile.controllo))
        .disabled(occupato || (mobile.protetto && password.isEmpty))
    }

    @ViewBuilder private var messaggio: some View {
        switch mobile.fase {
        case .errore(let testo):
            Label(testo, systemImage: "exclamationmark.triangle.fill")
                .font(Tipo.Mobile.rigaDettaglio)
                .foregroundColor(Tema.Colore.Mobile.errore)
                .fixedSize(horizontal: false, vertical: true)
        case .riuscita:
            VStack(alignment: .leading, spacing: M.spazioRiga) {
                Label("Backup aperto: i dati del Mac sono su questo dispositivo. L'archivio di prima è salvato in una copia di sicurezza.",
                      systemImage: "checkmark.seal.fill")
                    .font(Tipo.Mobile.rigaDettaglio)
                    .foregroundColor(Tema.Colore.Mobile.riuscita)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Vai ai clienti") { mobile.chiudiApertura() }
                    .font(Tipo.Mobile.pulsante)
                    .buttonStyle(.borderedProminent)
            }
        case .attesa, .copia, .ripristino:
            EmptyView()
        }
    }

    private var piede: some View {
        VStack(spacing: M.spazioRiga) {
            if mobile.fase != .riuscita {
                Button(StatoMobile.soloDatiDiProva(mobile.stato.dati) ? "Intanto guarda i dati di prova" : "Torna ai dati di questo dispositivo") {
                    mobile.chiudiApertura()
                }
                .font(Tipo.Mobile.pulsante)
                .disabled(mobile.fase == .ripristino)
            }
            Text("Il file del backup resta dove l'hai messo (è cifrato): cancellalo da File o da iCloud Drive se non ti serve più.")
                .font(Tipo.Mobile.rigaDettaglio)
                .foregroundColor(Tema.Colore.inchiostroSfondoSecondario)
                .multilineTextAlignment(.center)
        }
        .aloneSfondo()
        .padding(.bottom, M.margine)
    }

    // MARK: - Azioni

    private var occupato: Bool { mobile.fase == .copia || mobile.fase == .ripristino }

    private func apri() {
        guard !occupato else { return }
        campoAttivo = false
        let scritta = password
        password = ""
        mobile.ripristina(password: scritta)
    }
}
#endif
