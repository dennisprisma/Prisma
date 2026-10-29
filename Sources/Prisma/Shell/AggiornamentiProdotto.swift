import SwiftUI

// MARK: - Prodotti: avviso del nuovo KID e storico degli aggiornamenti (specifica 9, giro 5)

/// In cima alla scheda prodotto aggiornata da un nuovo KID che alza rischio o costi (per `giorniAvvisoKID` giorni):
/// gli aumenti, i primi clienti toccati, il confronto e le attività. Niente se l'ultimo aggiornamento non alza nulla.
struct AvvisoNuovoKID: View {
    @EnvironmentObject var stato: StatoShell
    let prodotto: Prodotto

    var body: some View {
        if let x = stato.impattoProdotto(prodotto) {
            let m = Misure.ConfrontoDossier.self
            let documento = stato.documento(x.documentoId)
            // Il titolo resta nello storico anche se il documento si elimina
            let variazione: VariazioneDossier? = (prodotto.variazioni ?? []).last { $0.documentoId == x.documentoId }
            let titolo: String = documento?.titolo ?? variazione?.titoloDocumento ?? ""
            let clienti = x.esito.clienti
            let mostrati = Array(clienti.prefix(m.clientiAvviso))
            PannelloAnalisi(titolo: TestiConfrontoDossier.titoloAvvisoKID, nota: Formati.dataEstesa.string(from: x.il)) {
                EmptyView()
            } contenuto: {
                VStack(alignment: .leading, spacing: m.spazio) {
                    Text(TestiConfrontoDossier.avvisoKID(il: x.il, titolo: titolo, aumenti: x.esito.aumenti))
                        .font(Tipo.strumentoTesto)
                        .foregroundColor(Colori.ConfrontoDossier.testo)
                        .fixedSize(horizontal: false, vertical: true)
                    if clienti.isEmpty {
                        Text(TestiConfrontoDossier.nessunClienteToccato)
                            .font(Tipo.kpiNota)
                            .foregroundColor(Colori.ConfrontoDossier.vuoto)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(mostrati) { c in
                                RigaClienteImpatto(cliente: c, compatta: true)
                            }
                        }
                        if clienti.count > mostrati.count {
                            Text(TestiConfrontoDossier.altriClienti(clienti.count - mostrati.count))
                                .font(Tipo.kpiNota)
                                .foregroundColor(Colori.ConfrontoDossier.vuoto)
                        }
                    }
                    HStack(spacing: m.spazio) {
                        if documento != nil {
                            Button(TestiConfrontoDossier.vediConfronto) { stato.apriConfronto(x.documentoId) }
                                .buttonStyle(StileVetro(margine: m.pulsante))
                        }
                        if !clienti.isEmpty {
                            Button(TestiConfrontoDossier.creaAttivita) {
                                stato.creaAttivitaImpatto(x.esito, prodotto: prodotto, il: x.il)
                            }
                            .buttonStyle(StileVetro(margine: m.pulsante))
                            .disabled(stato.solaLettura)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(m.margine)
            .frame(maxWidth: .infinity, alignment: .leading)
            .riquadroStrumento()
        }
    }
}

/// I dati della scheda cambiati dai documenti, con «Ripristina». Senza variazioni non si mostra: le schede senza
/// storico non hanno un pannello vuoto.
struct StoricoAggiornamentiProdotto: View {
    @EnvironmentObject var stato: StatoShell
    let prodotto: Prodotto

    var body: some View {
        let bersaglio = BersaglioConfronto.prodotto(prodotto.id)
        let variazioni = stato.variazioni(bersaglio)
        if !variazioni.isEmpty {
            PannelloAnalisi(titolo: TestiConfrontoDossier.titoloStoricoProdotto,
                            nota: TestiConfrontoDossier.notaStoricoProdotto(variazioni.count)) {
                EmptyView()
            } contenuto: {
                ElencoVariazioni(variazioni: variazioni, limite: Misure.ConfrontoDossier.storicoVisibile,
                                 ripristinabile: { v in
                                     guard let p = stato.prodotto(prodotto.id) else { return false }
                                     return MotoreConfrontoDossier.ripristinabile(v, in: p)
                                 },
                                 ripristina: { v in stato.ripristina(v.id, in: bersaglio) })
            }
        }
    }
}
