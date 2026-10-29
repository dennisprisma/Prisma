import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

/// Un PDF pronto da salvare, con il cliente a cui è destinato.
struct PDFDaSalvare: Identifiable {
    let id = UUID()
    let dati: Data
    let nome: String
    let cliente: Cliente?
}

/// Prima di salvare un PDF per il cliente: protezione con password (proposta dalle Impostazioni,
/// ricavata dai dati del cliente). Prisma non conserva la password.
struct ModuloSalvaPDF: View {
    @Environment(\.dismiss) var chiudi
    @EnvironmentObject var stato: StatoShell
    let pdf: PDFDaSalvare
    @State private var proteggi: Bool
    @State private var password: String
    #if os(iOS)
    /// Il PDF pronto per «Salva in File…» e il pannello del sistema che lo salva.
    @State private var daEsportare: FilePDF?
    @State private var esporta = false
    #endif

    init(pdf: PDFDaSalvare, impostazioni: ImpostazioniPDF) {
        self.pdf = pdf
        _proteggi = State(initialValue: impostazioni.proteggi)
        _password = State(initialValue: impostazioni.password(per: pdf.cliente))
    }

    private var valida: Bool { !proteggi || password.count >= ImpostazioniPDF.lunghezzaMinima }

    var body: some View {
        CorniceModulo(titolo: "Salva il PDF") {
            VStack(alignment: .leading, spacing: 14) {
                Text(pdf.nome).font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario).lineLimit(2)
                CampoModulo(etichetta: "Proteggi con password") {
                    Toggle("", isOn: $proteggi)
                        .toggleStyle(StileInterruttore())
                        .labelsHidden()
                }
                if proteggi {
                    CampoModulo(etichetta: "Password") {
                        TextField("almeno \(ImpostazioniPDF.lunghezzaMinima) caratteri", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                    }
                    Text(suggerimento)
                        .font(Tipo.kpiNota)
                        .foregroundColor(valida ? Colori.Analisi.kpiNota : Colori.Analisi.erroreTesto)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Senza password chiunque riceva il file può leggerlo: per un documento con i dati patrimoniali del cliente è meglio proteggerlo, soprattutto se lo mandi per email.")
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.Analisi.kpiNota)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } piede: {
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro())
                .keyboardShortcut(.cancelAction)
            #if os(macOS)
            Button {
                let dati = proteggi ? StampaCarta.protetto(pdf.dati, password: password) : pdf.dati
                chiudi()
                guard let dati else {
                    stato.mostraAvviso("Non sono riuscito a proteggere il PDF.")
                    return
                }
                // Il pannello di salvataggio dopo la chiusura del foglio
                DispatchQueue.main.async { StampaCarta.salva(dati, nome: pdf.nome) }
            } label: {
                Label("Salva…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(StileBlu())
            .disabled(!valida)
            .opacity(valida ? 1 : 0.5)
            .keyboardShortcut(.defaultAction)
            #elseif os(iOS)
            // Su iPhone e iPad: la condivisione (AirDrop, Mail…) e il salvataggio in File, con la stessa protezione
            ShareLink(item: PDFCondiviso(dati: pdf.dati, nome: pdf.nome, password: proteggi ? password : nil),
                      preview: SharePreview(pdf.nome)) {
                Label("Condividi…", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(StileVetro())
            .disabled(!valida)
            .opacity(valida ? 1 : 0.5)
            Button(action: preparaEsportazione) {
                Label("Salva in File…", systemImage: "folder")
            }
            .buttonStyle(StileBlu())
            .disabled(!valida)
            .opacity(valida ? 1 : 0.5)
            .keyboardShortcut(.defaultAction)
            #endif
        }
        #if os(macOS)
        .frame(width: Misure.Analisi.moduloSalvaPDF.width, height: Misure.Analisi.moduloSalvaPDF.height)
        #elseif os(iOS)
        // Nel foglio di iPad la stessa misura del Mac; su iPhone si stringe alla larghezza dello schermo
        .frame(maxWidth: Misure.Analisi.moduloSalvaPDF.width, minHeight: Misure.Analisi.moduloSalvaPDF.height)
        .fileExporter(isPresented: $esporta, document: daEsportare, contentType: .pdf,
                      defaultFilename: (pdf.nome as NSString).deletingPathExtension) { esito in
            daEsportare = nil
            switch esito {
            case .success:
                chiudi()
            case .failure(let errore):
                // Annullato dall'utente: il modulo resta aperto, senza avvisi
                if (errore as? CocoaError)?.code == .userCancelled { return }
                stato.mostraAvviso("Non sono riuscito a salvare il PDF: \(errore.localizedDescription)")
            }
        }
        #endif
    }

    #if os(iOS)
    /// I dati del PDF (protetti, se richiesto) per il pannello «Salva in File…» del sistema.
    private func preparaEsportazione() {
        guard let dati = proteggi ? StampaCarta.protetto(pdf.dati, password: password) : pdf.dati else {
            stato.mostraAvviso("Non sono riuscito a proteggere il PDF.")
            return
        }
        daEsportare = FilePDF(dati: dati)
        esporta = true
    }
    #endif

    private var suggerimento: String {
        if !valida { return "La password deve avere almeno \(ImpostazioniPDF.lunghezzaMinima) caratteri." }
        let regola = stato.dati.impostazioni.pdf.regola
        let proposta = stato.dati.impostazioni.pdf.password(per: pdf.cliente)
        if regola != .aMano, !proposta.isEmpty, password == proposta {
            return "È \(regola == .dataNascita ? "la data di nascita" : "il codice fiscale") di \(pdf.cliente?.nome ?? "del cliente"): comunicala al cliente a voce o per telefono, non nella stessa email del PDF."
        }
        return "Comunicala al cliente a voce o per telefono, non nella stessa email del PDF. Prisma non la conserva."
    }
}
