import SwiftUI

/// Un valore passato della posizione (da un vecchio estratto conto o da una comunicazione
/// annuale): arricchisce lo storico da cui si calcola l'andamento.
struct ModuloRilevazione: View {
    @Environment(\.dismiss) var chiudi
    let posizione: Posizione
    let salva: (Rilevazione) -> Void
    @State private var data: Date
    @State private var valore: Double?
    @State private var versato: Double?

    private static let numero = FloatingPointFormatStyle<Double>.number.locale(Formati.italiano)

    init(posizione: Posizione, salva: @escaping (Rilevazione) -> Void) {
        self.posizione = posizione
        self.salva = salva
        let limite = posizione.dataValore ?? Date()
        _data = State(initialValue: Calendar.current.date(byAdding: .year, value: -1, to: limite) ?? limite)
    }

    /// I valori passati vengono prima del valore attuale: quello si aggiorna con «Modifica».
    private var limite: Date { Calendar.current.startOfDay(for: posizione.dataValore ?? Date()) }
    private var dataValida: Bool { data < limite && (posizione.decorrenza.map { data >= Calendar.current.startOfDay(for: $0) } ?? true) }
    private var valida: Bool { (valore ?? -1) >= 0 && dataValida }

    var body: some View {
        CorniceModulo(titolo: "Valore passato") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Da un estratto conto o dalla comunicazione annuale di \(posizione.nome). Con il versato a quella data il rendimento è esatto; senza, Prisma stima i versamenti dai premi periodici.")
                    .font(Tipo.campoEtichetta)
                    .foregroundColor(Colori.Rubrica.secondario)
                    .fixedSize(horizontal: false, vertical: true)
                CampoModulo(etichetta: "Data") {
                    DatePicker("", selection: $data, displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 140)
                }
                CampoModulo(etichetta: "Valore a quella data") { campoEuro($valore, segnaposto: "0") }
                CampoModulo(etichetta: "Versato fino ad allora") { campoEuro($versato, segnaposto: "—") }
                if !dataValida {
                    Text(data >= limite ? "La data deve venire prima del valore attuale (\(Formati.dataEstesa.string(from: limite))): per un valore più recente aggiorna la posizione con «Modifica»."
                                        : "La data viene prima della decorrenza della posizione.")
                        .font(Tipo.kpiNota)
                        .foregroundColor(Colori.Analisi.erroreTesto)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } piede: {
            Spacer()
            Button("Annulla") { chiudi() }
                .buttonStyle(StileVetro())
                .keyboardShortcut(.cancelAction)
            Button("Aggiungi") {
                salva(Rilevazione(data: data, controvalore: valore ?? 0, versato: versato))
                chiudi()
            }
            .buttonStyle(StileBlu())
            .disabled(!valida)
            .opacity(valida ? 1 : 0.5)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: Misure.Analisi.moduloRilevazione.width, height: Misure.Analisi.moduloRilevazione.height)
    }

    private func campoEuro(_ valore: Binding<Double?>, segnaposto: String) -> some View {
        HStack(spacing: 6) {
            TextField(segnaposto, value: valore, format: Self.numero)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
            Text("€").font(Tipo.campoEtichetta).foregroundColor(Colori.Rubrica.secondario)
        }
    }
}
