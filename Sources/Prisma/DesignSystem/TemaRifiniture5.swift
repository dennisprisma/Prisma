import SwiftUI

// MARK: - Gettoni delle rifiniture grafiche (gruppo 5: Agenda, Attività, Eve, Documenti, Ricerca, Incontri)
// Valori nuovi per le correzioni d'impaginazione che non hanno un file di gettoni del gruppo (il modulo dell'esito
// usa `Misure.Seguito`, che sta in TemaSeguito.swift) e la sfumatura comune in fondo agli elenchi che scorrono.

extension Misure.Seguito {
    /// Modulo compatto dell'esito (riquadro dell'Agenda): con spazio sufficiente etichetta a sinistra e campo a
    /// destra, come una griglia; altrimenti l'etichetta torna sopra il campo.
    static let etichettaGriglia: CGFloat = 96
    /// Larghezza del campo che decide se la griglia ci sta (le note sotto i campi vanno a capo).
    static let campoGriglia: CGFloat = 200
}

extension View {
    /// Il contenuto che scorre sfuma sui bordi invece di finire tagliato a metà sotto una barra o un piede.
    /// Solo una maschera: nessun colore, vale sul vetro chiaro e su quello scuro.
    func sfumaturaBordiScorrimento(sopra: CGFloat = 0, sotto: CGFloat = 0) -> some View {
        mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: sopra)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: sotto)
            }
        }
    }
}
