import SwiftUI

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
                .buttonStyle(StileVetro(margine: EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)))
                .keyboardShortcut(.cancelAction)
            Button("Salva…") {
                let dati = proteggi ? StampaCarta.protetto(pdf.dati, password: password) : pdf.dati
                chiudi()
                guard let dati else {
                    stato.mostraAvviso("Non sono riuscito a proteggere il PDF.")
                    return
                }
                // Il pannello di salvataggio dopo la chiusura del foglio
                DispatchQueue.main.async { StampaCarta.salva(dati, nome: pdf.nome) }
            }
            .buttonStyle(StileBlu())
            .disabled(!valida)
            .opacity(valida ? 1 : 0.5)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Analisi.moduloSalvaPDF.width, height: Misure.Analisi.moduloSalvaPDF.height)
    }

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
