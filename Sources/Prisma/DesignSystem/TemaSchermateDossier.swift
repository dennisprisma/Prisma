import SwiftUI

// MARK: - Gettoni delle schermate del dossier (tema Liquid Glass)
// Clienti (rubrica, dossier, bisogni), Posizioni (dossier, dettaglio, portafoglio), Agenda,
// Attività, Note e i loro moduli: quello che non sta tra i gettoni comuni del tema.

extension Tema.Colore {
    /// Colori delle schermate del dossier.
    enum Dossier {
        /// Fondo dei tre scenari nel modulo della valutazione: in chiaro le tinte del documento,
        /// in scuro gli stati del tema appena accennati (il testo chiaro resta leggibile).
        static func fondoScenario(_ t: TipoScenario) -> Color {
            let chiaro = Colori.Documento.prisma.scenarioFondo(t)
            switch t {
            case .favorevole: return Color.dinamico(chiaro: chiaro, scuro: Tema.Colore.verde.opacity(0.16))
            case .intermedio: return Color.dinamico(chiaro: chiaro, scuro: Tema.Colore.accento.opacity(0.16))
            case .sfavorevole: return Color.dinamico(chiaro: chiaro, scuro: Tema.Colore.rosso.opacity(0.16))
            }
        }
    }
}

extension Tema.Raggio {
    /// Raggi delle schermate del dossier.
    enum Dossier {
        /// Giorno scelto (o di oggi) nella settimana dell'Agenda e nella griglia del mese.
        static let giornoSettimana: CGFloat = Tema.Raggio.riga
        static let giornoMese: CGFloat = Tema.Raggio.voceLaterale
        /// Riquadri dentro i dettagli: note dell'incontro, posizione di cui si parla, appuntamento collegato.
        static let riquadro: CGFloat = Tema.Raggio.riga
        /// Campi di testo su più righe (note del cliente, moduli).
        static let campoLungo: CGFloat = Tema.Raggio.miniatura
        /// Icone delle aree dei bisogni: come le icone delle app, in piccolo.
        static let iconaBisogno: CGFloat = Tema.Raggio.iconaApp(Misure.Bisogni.icona)
        /// Caselle della scala di rischio (SRI).
        static let casellaRischio: CGFloat = Tema.Raggio.tasto
        /// Quadratini colorati delle aree nelle legende e nelle tabelle.
        static let quadratinoArea: CGFloat = Tema.Raggio.quadratinoCanale
        /// Barretta colorata dell'area accanto al nome della posizione.
        static let barrettaArea: CGFloat = 4
        /// Tabelle dentro le schede (posizioni, portafoglio, scenari, importazioni).
        static let tabella: CGFloat = Misure.Analisi.raggio
    }
}

extension Tema.Misura {
    /// Misure delle schermate del dossier.
    enum Dossier {
        /// Elenchi a voci arrotondate (rubrica, indice delle note): margine ai lati e spazio tra le voci.
        static let margineElenco: CGFloat = 8
        static let spazioVoci: CGFloat = 2
        /// Spazio tra la fascia in testa all'Agenda e la scheda della settimana.
        static let spazioAgenda: CGFloat = 10
        /// Separatori verticali del riepilogo delle Attività.
        static let separatoreRiepilogo: CGFloat = 34
        /// Testata dell'elenco laterale di Posizioni nel Portafoglio: come «Dossier di» (DossierRail).
        static let testataRail = EdgeInsets(top: 8, leading: 8, bottom: 9, trailing: 8)
        /// Sfumatura in fondo all'elenco laterale che scorre, sopra il piede «Archivio locale».
        static let sfumaturaRail: CGFloat = 12
        /// Dettaglio della posizione: la colonna sinistra (contratto) non va oltre, la destra (costi,
        /// fiscalità, storico) parte da qui e prende il resto.
        static let dettaglioSinistraMassima: CGFloat = 520
        static let dettaglioDestraMinima: CGFloat = 360
        /// Sfumatura sotto la barra del dettaglio: il contenuto che scorre sparisce prima del filo.
        static let sfumaturaBarra: CGFloat = 10
    }
}

extension View {
    /// Contorno delle tabelle dentro le schede: angoli arrotondati e filo da 0,5 pt.
    /// Taglia il contenuto alla forma (le righe alternate non escono dagli angoli).
    func contornoTabella(raggio: CGFloat = Tema.Raggio.Dossier.tabella) -> some View {
        let forma = FormaVetro.arrotondata(raggio)
        return self
            .clipShape(forma)
            .overlay {
                forma.strokeBorder(Colori.Analisi.tabellaBordo, lineWidth: Tema.Misura.filo)
                    .allowsHitTesting(false)
            }
    }
}
