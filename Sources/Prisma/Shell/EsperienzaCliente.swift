import SwiftUI

/// Esperienza per tipo di prodotto e capacità di sostenere perdite, nel profilo del cliente: si compila
/// con il cliente, un clic per casella, e si salva subito.
struct EsperienzaCliente: View {
    @EnvironmentObject var stato: StatoShell
    let cliente: Cliente
    @State private var mostraMetodo = false

    private typealias M = Tema.Misura.Esperienza

    var body: some View {
        // Il cliente com'è adesso nell'archivio: le caselle scrivono subito
        let c = stato.cliente(cliente.id) ?? cliente
        let e = c.profilo.esperienzaProdotti
        let posizioni = stato.posizioniCliente(c.id)
        let prodotti = stato.dati.prodotti
        let notaData: String = EsperienzaCliente.notaAggiornata(e)
        VStack(alignment: .leading, spacing: M.spazioSezione) {
            OcchielloSezione(titolo: "Esperienza per tipo di prodotto", nota: notaData)
            HStack(alignment: .firstTextBaseline, spacing: M.spazioRiga) {
                Text("Per ogni tipo: lo conosce, l'ha già avuto, ne ha capito rischi e costi. Un clic sulla casella: sì, no, non indicato. Prisma avvisa se proponi un tipo che il cliente non conosce o non ha capito.")
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { mostraMetodo.toggle() } label: {
                    Label(mostraMetodo ? "Nascondi il metodo" : "Come si giudica?",
                          systemImage: mostraMetodo ? "chevron.up" : "questionmark.circle")
                }
                .buttonStyle(StileCollegamento())
                    .fixedSize()
            }
            if mostraMetodo {
                NotaMetodo(testo: TestiEsperienza.metodo.joined(separator: "\n"), titolo: "Come si giudica")
            }
            GrigliaEsperienza(esperienza: e,
                              inEssere: MotoreEsperienza.inEssere(posizioni, prodotti: prodotti),
                              suggerimenti: MotoreEsperienza.suggerimenti(e, posizioni: posizioni, prodotti: prodotti)) { tipo, domanda, valore in
                stato.rispondiEsperienza(c.id, tipo: tipo, domanda: domanda, valore: valore)
            }
            capacita(c, e)
            piede(c, e)
        }
    }

    /// «Aggiornata il 12 ottobre 2026» o «Da compilare con il cliente».
    private static func notaAggiornata(_ e: EsperienzaProdotti?) -> String {
        guard let d = e?.aggiornataIl else { return "Da compilare con il cliente" }
        return "Aggiornata il " + Formati.dataEstesa.string(from: d)
    }

    /// «Dalla griglia l'esperienza finanziaria sembra «media»; nel profilo è «base».»
    private static func testoSuggerita(_ s: ProfiloInvestitore.Esperienza, profilo: ProfiloInvestitore.Esperienza?) -> String {
        let nelProfilo: String = profilo?.nome.lowercased() ?? "non indicata"
        let dallaGriglia: String = s.nome.lowercased()
        return "Dalla griglia l'esperienza finanziaria sembra «\(dallaGriglia)»; nel profilo è «\(nelProfilo)»."
    }

    // MARK: - Capacità di sostenere perdite

    private func capacita(_ c: Cliente, _ e: EsperienzaProdotti?) -> some View {
        var opzioni: [(CapacitaPerdite?, String)] = [(nil, "Non indicata")]
        opzioni += CapacitaPerdite.allCases.map { k -> (CapacitaPerdite?, String) in (k, k.etichetta) }
        let selezione = Binding<CapacitaPerdite?>(get: { e?.capacitaPerdite },
                                                  set: { stato.impostaCapacitaPerdite(c.id, $0) })
        let spiegazione: String
        if let k = e?.capacitaPerdite {
            spiegazione = "Il cliente \(k.frase). Prisma confronta ogni proposta con la perdita che avrebbe avuto nella crisi peggiore del passato."
        } else {
            spiegazione = "Quanto può perdere senza cambiare i suoi piani? È diversa dalla propensione al rischio."
        }
        return VStack(alignment: .leading, spacing: M.spazioCapacita) {
            HStack(spacing: M.spazioRiga) {
                Text("Capacità di sostenere perdite")
                    .font(Tipo.campoEtichetta)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .lineLimit(1)
                Spacer(minLength: M.spazioRiga)
                ControlloSegmenti(opzioni: opzioni, selezione: selezione, compatto: true)
                    .frame(maxWidth: M.larghezzaCapacita)
            }
            Text(spiegazione)
                .font(Tipo.kpiNota)
                .foregroundColor(Colori.Analisi.kpiNota)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Piede

    @ViewBuilder private func piede(_ c: Cliente, _ e: EsperienzaProdotti?) -> some View {
        Text(MotoreEsperienza.sintesi(e))
            .font(Tipo.kpiNota)
            .foregroundColor(Colori.Analisi.kpiNota)
        if let s = MotoreEsperienza.esperienzaSuggerita(e), s != c.profilo.esperienza {
            HStack(alignment: .firstTextBaseline, spacing: M.spazioRiga) {
                Text(EsperienzaCliente.testoSuggerita(s, profilo: c.profilo.esperienza))
                    .font(Tipo.kpiNota)
                    .foregroundColor(Colori.Analisi.kpiNota)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Usa «\(s.nome.lowercased())»") { stato.impostaEsperienzaFinanziaria(c.id, s) }
                    .buttonStyle(StileCuoioChiaro())
                    .fixedSize()
            }
        }
    }
}

// MARK: - Scritture

extension StatoShell {
    /// Cambia la griglia dell'esperienza di un cliente; vuota torna nil (l'archivio resta come prima).
    func aggiornaEsperienza(_ id: String, _ cambia: (inout EsperienzaProdotti) -> Void) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == id }) else { return }
        var e = dati.clienti[i].profilo.esperienzaProdotti ?? EsperienzaProdotti()
        cambia(&e)
        e.aggiornataIl = Appuntamento.alMinuto(Date())
        dati.clienti[i].profilo.esperienzaProdotti = e.compilata ? e : nil
    }

    /// Una casella della griglia. Chi ha avuto o ha capito un prodotto lo conosce: «conosce» si segna da solo
    /// se era vuoto (si può sempre rimettere a «no»).
    func rispondiEsperienza(_ id: String, tipo: TipoProdotto, domanda: DomandaEsperienza, valore: Bool?) {
        aggiornaEsperienza(id) { e in
            var v = e.voce(tipo)
            v[domanda] = valore
            if domanda != .conosce, valore == true, v.conosce == nil { v.conosce = true }
            e.imposta(v)
        }
    }

    func impostaCapacitaPerdite(_ id: String, _ c: CapacitaPerdite?) {
        aggiornaEsperienza(id) { $0.capacitaPerdite = c }
    }

    /// «Usa …» sotto la griglia: aggiorna l'esperienza finanziaria del profilo (e la data del profilo).
    func impostaEsperienzaFinanziaria(_ id: String, _ e: ProfiloInvestitore.Esperienza) {
        guard let i = dati.clienti.firstIndex(where: { $0.id == id }) else { return }
        dati.clienti[i].profilo.esperienza = e
        dati.clienti[i].profilo.aggiornatoIl = Appuntamento.alMinuto(Date())
    }
}
