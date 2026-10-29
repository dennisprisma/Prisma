import SwiftUI

// Gettoni e componenti delle scadenze di conformità («In regola», specifica 3), ricavati dal tema Liquid Glass:
// solo riferimenti ai gettoni comuni, nessun colore nuovo. Le pillole usano i toni di `Pillola`.

extension Tema.Misura {
    enum Conformita {
        /// Tra i blocchi della scheda (come Anagrafica).
        static let spazioGruppi: CGFloat = 18
        /// Tra l'occhiello o l'etichetta del canale e le righe.
        static let spazioIntestazione: CGFloat = 8
        /// Margine sopra e sotto di una riga.
        static let rigaVerticale: CGFloat = 9
        /// Tra testo, pillola e pulsanti.
        static let spazioRiga: CGFloat = 12
        /// Tra la pillola e i pulsanti della colonna destra.
        static let spazioAzioni: CGFloat = 6
        /// Tra titolo e dettaglio.
        static let spazioTesto: CGFloat = 2
        /// Larghezza minima della colonna destra (pillola + pulsanti).
        static let colonnaAzioni: CGFloat = 230
        static let margineAzione = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        /// Il riquadro della Panoramica: spazio tra l'occhiello e la riga.
        static let spazioRiquadro: CGFloat = 6
        /// Il piede della scheda: pulsante, avvertenza, fonti.
        static let spazioPiede: CGFloat = 10
        static let spazioFonti: CGFloat = 8
        // Il modulo delle date
        static let spazioSezioniModulo: CGFloat = 20
        static let spazioCampiModulo: CGFloat = 10
        static let marginePiedeModulo = EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
        static let spazioCampoPulsante: CGFloat = 10
        static let tendinaValidita: CGFloat = 240
        static let tendinaRischio: CGFloat = 170
        static let tendinaDocumento: CGFloat = 200
        static let campoNumero: CGFloat = 180
        /// Caselle «Non richiesti per questo cliente»: due colonne.
        static let colonnaCasella: CGFloat = 220
    }
}

extension Tema.Colore {
    enum Conformita {
        static let titolo = Tema.Colore.inchiostro
        static let dettaglio = Tema.Colore.inchiostroSecondario
        static let fonte = Tema.Colore.inchiostroTerziario
        static let filo = Tema.Colore.separatore
    }
}

extension Tema.Testo {
    enum Conformita {
        static let titolo = Tema.Testo.corpo
        static let dettaglio = Tema.Testo.didascalia
        static let fonte = Tema.Testo.didascalia
        /// Il titolo di una fonte nella sezione «Come si calcola e fonti».
        static let titoloFonte = Tema.Testo.Inserimento.gruppo
    }
}

extension VoceConformita.Stato {
    /// Il tono della pillola: scaduta rosso, mancante e entro 30 arancio, entro 60 neutro, in regola verde.
    var tono: Pillola.Tono {
        switch self {
        case .scaduta: return .errore
        case .mancante, .entro30: return .attenzione
        case .entro60, .nonRichiesta: return .neutro
        case .inRegola: return .ok
        }
    }
}

/// Riga di una voce di conformità: nome e dettaglio a sinistra, pillola dello stato e azioni a destra,
/// filo in basso (come `RigaCampo`).
struct RigaConformita<Azioni: View>: View {
    let titolo: String
    let dettaglio: String
    let pillola: String
    let tono: Pillola.Tono
    @ViewBuilder let azioni: () -> Azioni

    var body: some View {
        let m = Tema.Misura.Conformita.self
        HStack(alignment: .firstTextBaseline, spacing: m.spazioRiga) {
            VStack(alignment: .leading, spacing: m.spazioTesto) {
                Text(titolo)
                    .font(Tema.Testo.Conformita.titolo)
                    .foregroundColor(Tema.Colore.Conformita.titolo)
                Text(dettaglio)
                    .font(Tema.Testo.Conformita.dettaglio)
                    .foregroundColor(Tema.Colore.Conformita.dettaglio)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: m.spazioAzioni) {
                Pillola(testo: pillola, tono: tono)
                azioni()
            }
            .fixedSize()
            .frame(minWidth: m.colonnaAzioni, alignment: .trailing)
        }
        .padding(.vertical, m.rigaVerticale)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tema.Colore.Conformita.filo).frame(height: Tema.Misura.filo)
        }
    }
}

extension RigaConformita where Azioni == EmptyView {
    /// Una riga senza pulsanti.
    init(titolo: String, dettaglio: String, pillola: String, tono: Pillola.Tono) {
        self.init(titolo: titolo, dettaglio: dettaglio, pillola: pillola, tono: tono) { EmptyView() }
    }
}
