import SwiftUI

// Memoria del riesame (specifica 12 §6): la scheda «Riesami» del dossier e i riquadri brevi di Prospetti,
// Incontri e Panoramica. Le cifre vengono da `StatoShell.memoriaRiesame` (in cache): qui solo impaginazione.

/// La scheda «Riesami» del dossier del cliente: che cosa è cambiato dal riesame precedente, le azioni,
/// la linea del tempo delle fotografie salvate e le fonti.
struct CronologiaRiesami: View {
    @EnvironmentObject var stato: StatoShell
    let cliente: Cliente
    /// La fotografia da eliminare, dopo la conferma.
    @State private var daEliminare: FotografiaRiesame?

    var body: some View {
        let m = stato.haFotografie(cliente.id) ? stato.memoriaRiesame(cliente.id) : nil
        let salvate = stato.fotografieCliente(cliente.id)
        VStack(alignment: .leading, spacing: Tema.Misura.Memoria.spazioSezioni) {
            cambiato(m, salvate: salvate)
            azioni
            cronologia(salvate)
            Text(TestiMemoria.fonti)
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.Memoria.secondario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(titoloElimina, isPresented: confermaElimina, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                if let f = daEliminare { stato.eliminaFotografia(f.id) }
                daEliminare = nil
            }
            Button("Annulla", role: .cancel) { daEliminare = nil }
        } message: {
            Text(TestiMemoria.eliminaMessaggio)
        }
    }

    /// Il titolo della conferma (spezzato per il controllo dei tipi).
    private var titoloElimina: String {
        guard let f = daEliminare else { return "" }
        return TestiMemoria.eliminaTitolo(data: f.data)
    }

    private var confermaElimina: Binding<Bool> {
        Binding(get: { daEliminare != nil }, set: { if !$0 { daEliminare = nil } })
    }

    /// «Cosa è cambiato»: le variazioni dalla fotografia di almeno 30 giorni fa, oppure perché non ci sono.
    @ViewBuilder private func cambiato(_ m: MemoriaRiesame?, salvate: [FotografiaRiesame]) -> some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Memoria.spazioOcchiello) {
            if let m, let p = m.precedente {
                let tempo = TestiMemoria.tempoFa(mesi: TestiMemoria.mesi(da: p.data, a: m.oggi, cal: Calendar.current))
                OcchielloSezione(titolo: TestiMemoria.titoloCambiato, nota: TestiMemoria.notaCambiato(data: p.data, tempo: tempo))
                PannelloVariazioni(variazioni: m.variazioni, massimo: MotoreMemoria.massimoScheda,
                                   intestazione: TestiMemoria.riassunto(m: m),
                                   vuoto: TestiMemoria.nessunaVariazione(data: p.data))
            } else {
                OcchielloSezione(titolo: TestiMemoria.titoloCambiato)
                // Senza precedente: le fotografie che ci sono sono di meno di 30 giorni fa (stesso riesame)
                Text(salvate.first.map { TestiMemoria.soloRecenti(data: $0.data) } ?? TestiMemoria.primaFotografia)
                    .font(Tema.Testo.corpo)
                    .foregroundColor(Tema.Colore.Memoria.secondario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var azioni: some View {
        HStack(spacing: Tema.Misura.Memoria.spazioPulsanti) {
            Button(TestiMemoria.salvaOggi) {
                _ = stato.fotografaRiesame(cliente.id, origine: .manuale)
            }
            .buttonStyle(StileCuoioChiaro())
            .help(TestiMemoria.aiutoSalvaOggi)
            .disabled(stato.solaLettura)
            Button(TestiMemoria.preparaRiesame) {
                stato.clienteAttivoId = cliente.id
                stato.apriProspetto(.riesame)
            }
            .buttonStyle(StileBlu())
            Spacer()
        }
    }

    private func cronologia(_ salvate: [FotografiaRiesame]) -> some View {
        VStack(alignment: .leading, spacing: Tema.Misura.Memoria.spazioOcchiello) {
            OcchielloSezione(titolo: TestiMemoria.titoloCronologia,
                             nota: salvate.isEmpty ? nil : TestiMemoria.notaCronologia(n: salvate.count))
            if salvate.isEmpty {
                Text(TestiMemoria.nessunaFotografia)
                    .font(Tema.Testo.secondario)
                    .foregroundColor(Tema.Colore.Memoria.secondario)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LineaTempoRiesami(fotografie: salvate) { daEliminare = $0 }
            }
        }
    }
}

/// Prospetti › Riesame: che cosa è cambiato dal riesame precedente, in breve, sopra i punti da trattare.
struct RiepilogoMemoria: View {
    @EnvironmentObject var stato: StatoShell
    let clienteId: String

    var body: some View {
        // Senza fotografie del cliente è il primo riesame: la memoria non serve
        let m = stato.haFotografie(clienteId) ? stato.memoriaRiesame(clienteId) : nil
        let breve = MotoreMemoria.massimoBreve
        VStack(alignment: .leading, spacing: Tema.Misura.Memoria.righeCompatte) {
            if let m, let p = m.precedente {
                Text(TestiMemoria.occhielloCambiato(data: p.data))
                    .font(Tema.Testo.occhiello)
                    .foregroundColor(Tema.Colore.Memoria.secondario)
                if m.variazioni.isEmpty {
                    Text(TestiMemoria.nessunaVariazione(data: p.data))
                        .font(Tema.Testo.didascalia)
                        .foregroundColor(Tema.Colore.Memoria.secondario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(m.variazioni.prefix(breve)) { v in
                    RigaVariazione(variazione: v, compatta: true)
                }
                if m.variazioni.count > breve {
                    Text(TestiMemoria.altreNelProspetto(m.variazioni.count - breve))
                        .font(Tema.Testo.didascalia)
                        .foregroundColor(Tema.Colore.Memoria.secondario)
                }
            } else {
                Text(TestiMemoria.primaFotografia)
                    .font(Tema.Testo.didascalia)
                    .foregroundColor(Tema.Colore.Memoria.testo)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(TestiMemoria.piedeRiepilogo)
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.Memoria.secondario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Incontri › preparazione, colonna «Dal dossier»: le prime variazioni dal riesame precedente.
/// Solo con un riesame precedente e almeno una variazione; gli stessi gettoni degli altri occhielli della colonna.
struct CambiatoDalRiesame: View {
    @EnvironmentObject var stato: StatoShell
    let clienteId: String

    var body: some View {
        // Senza fotografie del cliente non c'è un riesame precedente: la memoria non si calcola
        if stato.haFotografie(clienteId), let m = stato.memoriaRiesame(clienteId), let p = m.precedente, !m.variazioni.isEmpty {
            let mm = Tema.Misura.Memoria.self
            VStack(alignment: .leading, spacing: mm.righeIncontro) {
                Text(TestiMemoria.occhielloDalRiesame(data: p.data))
                    .font(Tipo.incontroOcchiello)
                    .tracking(mm.trackingOcchielloIncontro)
                    .foregroundColor(Colori.Incontri.citazione)
                    .padding(.top, mm.staccoOcchielloIncontro)
                ForEach(m.variazioni.prefix(MotoreMemoria.massimoBreve)) { v in
                    HStack(alignment: .firstTextBaseline, spacing: mm.spazioCanale) {
                        Text("• \(v.testo)")
                            .font(Tipo.incontroNota)
                            .foregroundColor(Colori.Incontri.testo)
                            .fixedSize(horizontal: false, vertical: true)
                        if let c = v.canale { EtichettaCanale(canale: c, compatta: true) }
                    }
                }
            }
        }
    }
}

/// Panoramica › riquadro «Riesame annuale»: in una riga che cosa è cambiato e il collegamento alla scheda «Riesami».
/// Solo con un riesame precedente e almeno una variazione.
struct RigaMemoriaPanoramica: View {
    @EnvironmentObject var stato: StatoShell
    let clienteId: String

    var body: some View {
        if stato.haFotografie(clienteId), let m = stato.memoriaRiesame(clienteId), let testo = TestiMemoria.rigaPanoramica(m: m) {
            HStack(alignment: .firstTextBaseline, spacing: Tema.Misura.Memoria.spazioRiga) {
                Text(testo)
                    .font(Tema.Testo.secondario)
                    .foregroundColor(Tema.Colore.Memoria.secondario)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(TestiMemoria.collegamentoCronologia) { stato.schedaCliente = .riesami }
                    .buttonStyle(StileSemplice())
                    .font(Tema.Testo.Memoria.collegamento)
                    .foregroundColor(Colori.Colonna.collegamento)
            }
        }
    }
}

private extension StatoShell {
    /// true se il cliente ha almeno una fotografia salvata (controllo leggero, prima di calcolare la memoria).
    func haFotografie(_ clienteId: String) -> Bool {
        dati.fotografie.contains { $0.clienteId == clienteId }
    }
}
