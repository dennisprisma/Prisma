import SwiftUI

// Gettoni della completezza dei dati per l'analisi (specifica 7), ricavati dal tema Liquid Glass:
// colori dinamici chiari e scuri già esistenti, nessun valore sparso nelle viste.

extension Tema.Colore {
    enum Completezza {
        static let completo = Colori.Analisi.okTesto
        static let parziale = Colori.Analisi.attenzioneTesto
        static let scarso = Colori.Analisi.erroreTesto
        static let mancante = Tema.Colore.scadenzaOra
        static let daAggiornare = Tema.Colore.scadenzaVicina
        static let stimato = Tema.Colore.testoProposta
        static let traccia = Tema.Colore.pozzetto
        /// Il campo su cui si apre un modulo o l'Analisi 360: accento appena accennato e filo.
        static let evidenzaCampo = Tema.Colore.accento.opacity(0.12)
        static let bordoEvidenza = Tema.Colore.accento.opacity(0.55)
        /// I collegamenti del piede («Mostra tutte», «Ripristina»).
        static let collegamento = Tema.Colore.accento

        static func livello(_ l: LivelloCompletezza) -> Color {
            switch l {
            case .completo: return completo
            case .parziale: return parziale
            case .scarso: return scarso
            }
        }

        static func stato(_ s: StatoDato) -> Color {
            switch s {
            case .mancante: return mancante
            case .daAggiornare: return daAggiornare
            case .stimato: return stimato
            case .completo: return completo
            }
        }
    }
}

extension Tema.Misura {
    enum Completezza {
        static let riquadro = EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        static let barra: CGFloat = 6
        static let pallino: CGFloat = 7
        static let spazioRighe: CGFloat = 6
        static let margineEvidenza: CGFloat = 4
        /// Spazio tra le parti del riquadro (testa, barra, righe, piede).
        static let spazioBlocchi: CGFloat = 10
        /// Spazio tra gli elementi di una riga e tra le righe di testo di una voce.
        static let spazioRiga: CGFloat = 8
        static let spazioTesto: CGFloat = 2
        /// Margine verticale di una voce e margine del pulsante «Completa».
        static let margineVoce: CGFloat = 5
        static let marginePulsante = EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10)
        /// Analisi toccate (chip) mostrate al massimo accanto a una voce.
        static let chipPerVoce = 2
        /// Righe al massimo dell'ipotesi sotto il titolo di una voce.
        static let righeIpotesi = 2
    }
}

extension Tema.Raggio {
    enum Completezza {
        static let evidenza: CGFloat = 8
    }
}

extension Tema.Testo {
    enum Completezza {
        /// La percentuale grande della testa (come i valori delle tessere), cifre tabellari.
        static let percentuale = Tema.Testo.valoreTessera.monospacedDigit()
        /// La croce «non pertinente».
        static let croce = Tema.Testo.sf(10, .semibold)
        /// I collegamenti del piede.
        static let collegamento = Tema.Testo.sf(11.5, .medium)
    }
}

extension Tema.Moto {
    /// Attesa prima di portare in vista il campo di un modulo: il tempo che la sezione si apra.
    static let ritardoFuoco: Double = 0.15
}
