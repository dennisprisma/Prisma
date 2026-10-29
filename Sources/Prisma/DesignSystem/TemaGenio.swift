import SwiftUI

// Gettoni dell'istantanea delle finestre (genio e chiusura in Core Animation, Shell/MotoreGenio.swift).
// I tempi e le misure del movimento stanno in Movimento.swift (Tema.Moto.Finestre).

extension Tema.Colore.Shell {
    /// Sotto l'istantanea della finestra (genio, chiusura): il vetro disegnato non sfoca, così l'istantanea è
    /// coprente come la finestra vera sul vetro di Apple e attraverso non si vede la scrivania.
    static let fondoIstantaneaFinestra = Tema.Colore.finestraRidotta
}
