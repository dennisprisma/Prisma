#if os(iOS)
import SwiftUI

/// Impostazioni › Archivio su iPhone e iPad, al posto di quello del Mac (cartella dei backup, backup automatico,
/// Finder): i dati arrivano dal backup del Mac e tornano al Mac con un backup protetto salvato in File o iCloud
/// Drive. L'aspetto (chiaro, scuro, automatico) resta nella scheda Esperienza, come sul Mac.
struct ArchivioMobile: View {
    @EnvironmentObject var stato: StatoShell
    @EnvironmentObject var mobile: StatoMobile
    @State private var password = ""
    @State private var conferma = ""
    @FocusState private var campo: CampoPassword?

    private enum CampoPassword: Hashable { case password, conferma }

    private typealias M = Tema.Misura.Mobile

    private var minima: Int { ImpostazioniBackup.lunghezzaMinimaPassword }

    /// Il motivo per cui il backup non si può ancora creare (nil = si può).
    private var ostacolo: String? {
        if password.count < minima { return "Almeno \(minima) caratteri: è la password con cui il Mac aprirà il backup." }
        if conferma != password { return "Scrivi la stessa password nei due campi." }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Misure.Impostazioni.spazioGruppi) {
            GruppoImpostazioni(titolo: "Su questo dispositivo") {
                RigaImpostazione(titolo: "Dati",
                                 sottotitolo: "\(stato.clienti.count) clienti · \(stato.posizioni.count) posizioni · \(stato.dati.documenti.count) documenti") {
                    EmptyView()
                }
                RigaImpostazione(titolo: "Archivio di Prisma",
                                 sottotitolo: "Solo qui, protetto quando il dispositivo è bloccato e fuori dal backup iCloud del dispositivo") {
                    EmptyView()
                }
                RigaImpostazione(titolo: "Apri un altro backup",
                                 sottotitolo: "I dati di qui vengono sostituiti da un backup creato sul Mac; prima Prisma ne salva una copia di sicurezza",
                                 ultima: true) {
                    ValoreRiga(testo: "Apri") { mobile.apriBackup() }
                        .disabled(stato.backupInCorso || mobile.preparazioneBackup)
                }
            }

            GruppoImpostazioni(titolo: "Rimanda al Mac") {
                RigaImpostazione(titolo: "Backup per il Mac",
                                 sottotitolo: "Un backup protetto con i dati di qui, da salvare in File o iCloud Drive. Sul Mac: Impostazioni › Archivio › «Ripristina da un file…».",
                                 avvertenza: "Sul Mac sostituisce i dati: usalo solo se le modifiche le hai fatte qui") {
                    EmptyView()
                }
                VStack(alignment: .leading, spacing: M.spazioRiga) {
                    campoPassword("Password del backup", testo: $password, campo: .password)
                    campoPassword("Ripeti la password", testo: $conferma, campo: .conferma)
                    if let ostacolo, !password.isEmpty {
                        Text(ostacolo)
                            .font(Tema.Testo.secondario)
                            .foregroundColor(Tema.Colore.inchiostroSecondario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: M.spazioRiga) {
                        Button(action: crea) {
                            Label("Crea il backup per il Mac", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(StileVetro(accento: true))
                        .fixedSize()
                        .disabled(ostacolo != nil || mobile.preparazioneBackup || stato.backupInCorso || stato.solaLettura)
                        if mobile.preparazioneBackup {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .padding(Tema.Misura.Componenti.margineRiga)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func campoPassword(_ titolo: String, testo: Binding<String>, campo questo: CampoPassword) -> some View {
        SecureField(titolo, text: testo)
            .font(Tipo.Mobile.corpo)
            .textContentType(.newPassword)
            .submitLabel(questo == .password ? .next : .done)
            .focused($campo, equals: questo)
            .onSubmit {
                if questo == .password { campo = .conferma } else if ostacolo == nil { crea() }
            }
            .padding(.horizontal, M.spazioRiga)
            .frame(height: M.altezzaControllo)
            .background {
                RoundedRectangle(cornerRadius: Tema.Raggio.Mobile.controllo, style: .continuous)
                    .fill(Tema.Colore.pozzetto)
            }
            .disabled(mobile.preparazioneBackup)
    }

    private func crea() {
        guard ostacolo == nil else { return }
        campo = nil
        mobile.preparaBackupPerMac(password: password)
        // La password non resta nei campi: il backup pronto la porta con sé
        password = ""
        conferma = ""
    }
}
#endif
