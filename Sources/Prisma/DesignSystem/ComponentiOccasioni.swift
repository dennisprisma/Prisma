import SwiftUI

// Componenti del calendario delle occasioni: viste pure, ricevono dati e azioni (niente StatoShell).

/// Il simbolo del tipo in un cerchio con il vetro del canale (nella riga, nel dettaglio, nell'elenco).
struct SimboloOccasione: View {
    let tipo: TipoOccasione
    let canale: Canale?
    var grande = false

    var body: some View {
        let m = Misure.Occasioni.self
        let lato = grande ? m.simboloDettaglio : m.simbolo
        ZStack {
            Circle().fill(Colori.Agenda.fondoOccasione(canale))
            Image(systemName: TestiOccasioni.simbolo(tipo))
                .font(.system(size: grande ? m.glifoDettaglio : m.glifo, weight: .semibold))
                .foregroundColor(Colori.Agenda.occasione(canale))
        }
        .frame(width: lato, height: lato)
        .help(TestiOccasioni.etichetta(tipo))
        .accessibilityLabel(TestiOccasioni.etichetta(tipo))
    }
}

/// Quali colori di occasione ha un giorno: un anello per colore sotto il numero.
struct SegniOccasioni: Equatable {
    var alleanza = false
    var indipendente = false
    var neutra = false
    /// Quante occasioni ha il giorno (la nota «2 occasioni» della settimana).
    var numero = 0

    var vuoto: Bool { !alleanza && !indipendente && !neutra }

    init() {}

    init(_ elenco: [Occasione]) {
        numero = elenco.count
        for o in elenco {
            switch o.canale {
            case .alleanza?: alleanza = true
            case .indipendente?: indipendente = true
            case nil: neutra = true
            }
        }
    }

    /// I canali da disegnare, nell'ordine Alleanza, indipendente, neutro (nil).
    var canali: [Canale?] {
        var elenco: [Canale?] = []
        if alleanza { elenco.append(.alleanza) }
        if indipendente { elenco.append(.indipendente) }
        if neutra { elenco.append(nil) }
        return elenco
    }
}

/// Gli anelli delle occasioni sotto il giorno: vuoti, così si distinguono dai puntini pieni di incontri e scadenze.
struct AnelliOccasioni: View {
    let segni: SegniOccasioni
    let selezionato: Bool

    var body: some View {
        let m = Misure.Occasioni.self
        ForEach(Array(segni.canali.enumerated()), id: \.offset) { _, canale in
            Circle()
                .strokeBorder(selezionato ? Colori.Agenda.puntinoSelezione : Colori.Agenda.occasione(canale),
                              lineWidth: m.bordoAnello)
                .frame(width: m.anello, height: m.anello)
        }
    }
}
