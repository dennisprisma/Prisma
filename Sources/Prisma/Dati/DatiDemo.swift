import Foundation

/// I 5 clienti di prova del template, con appuntamenti e attività.
///
/// Nel template le date partono da lunedì 19 ottobre 2026: qui partono
/// da oggi, così la scrivania mostra sempre i prossimi incontri.
enum DatiDemo {
    static func clienti() -> [Cliente] {
        [
            Cliente(id: "giulia", nome: "Giulia Rossi", iniziali: "GR", tinta: .rosa, tema: "Una casa, un nuovo inizio.",
                    email: "giulia.rossi@example.com", telefono: "", preferito: true,
                    nota: "Il progetto casa è la priorità. Verificare tempi, disponibilità e domande rimaste aperte.",
                    creatoIl: data(-37)),
            Cliente(id: "marco", nome: "Marco Bianchi", iniziali: "MB", tinta: .blu, tema: "Il futuro della sua famiglia.",
                    email: "marco.bianchi@example.com", telefono: "", preferito: true,
                    nota: "Dedicare un momento ai progetti di famiglia. Preparare un riepilogo semplice e comprensibile.",
                    creatoIl: data(-31)),
            Cliente(id: "laura", nome: "Laura Moretti", iniziali: "LM", tinta: .viola, tema: "Più spazio alle possibilità.",
                    email: "laura.moretti@example.com", telefono: "", preferito: false,
                    nota: "Ripartire dagli obiettivi professionali e personali. La flessibilità è un tema importante.",
                    creatoIl: data(-26)),
            Cliente(id: "andrea", nome: "Andrea Conti", iniziali: "AC", tinta: .verde, tema: "Un percorso da costruire.",
                    email: "andrea.conti@example.com", telefono: "", preferito: false,
                    nota: "Primo incontro: ascolto, priorità e informazioni da raccogliere.",
                    creatoIl: data(-17)),
            Cliente(id: "sofia", nome: "Sofia Romano", iniziali: "SR", tinta: .oro, tema: "Le cose che contano, nel tempo.",
                    email: "sofia.romano@example.com", telefono: "", preferito: false,
                    nota: "Verificare se sono cambiati i progetti personali prima del prossimo incontro.",
                    creatoIl: data(-14)),
        ]
    }

    static func appuntamenti() -> [Appuntamento] {
        [
            Appuntamento(id: "event-giulia", clienteId: "giulia", titolo: "Il punto sul progetto casa", inizio: data(0, 9, 30),
                         durataMinuti: 45, luogo: "In studio",
                         note: "Riprendere gli obiettivi, la situazione attuale e concordare il prossimo passo.", stato: .pianificato),
            Appuntamento(id: "event-marco", clienteId: "marco", titolo: "Nuovi progetti di famiglia", inizio: data(0, 11, 0),
                         durataMinuti: 60, luogo: "Videochiamata",
                         note: "Preparare una presentazione con il riepilogo degli obiettivi.", stato: .pianificato),
            Appuntamento(id: "event-laura", clienteId: "laura", titolo: "Un progetto tutto suo", inizio: data(1, 10, 0),
                         durataMinuti: 45, luogo: "In studio",
                         note: "Raccogliere le nuove priorità professionali.", stato: .pianificato),
            Appuntamento(id: "event-andrea", clienteId: "andrea", titolo: "Il nostro primo incontro", inizio: data(2, 15, 0),
                         durataMinuti: 60, luogo: "In studio",
                         note: "Partire dalle domande e dalla storia personale.", stato: .pianificato),
            Appuntamento(id: "event-sofia", clienteId: "sofia", titolo: "Uno sguardo ai prossimi mesi", inizio: data(3, 11, 30),
                         durataMinuti: 30, luogo: "Telefonata",
                         note: "Aggiornare insieme le priorità.", stato: .pianificato),
        ]
    }

    static func attivita() -> [Attivita] {
        [
            Attivita(id: "task-casa", clienteId: "giulia", titolo: "Preparare il riepilogo per l’incontro", scadenza: data(0), priorita: .alta, completata: false),
            Attivita(id: "task-dati", clienteId: "giulia", titolo: "Verificare i dati delle spese mensili", scadenza: data(1), priorita: .normale, completata: false),
            Attivita(id: "task-marco", clienteId: "marco", titolo: "Rivedere la presentazione degli obiettivi", scadenza: data(0), priorita: .alta, completata: false),
            Attivita(id: "task-laura", clienteId: "laura", titolo: "Raccogliere le domande sul progetto", scadenza: data(1), priorita: .normale, completata: false),
            Attivita(id: "task-andrea", clienteId: "andrea", titolo: "Preparare la scheda del primo incontro", scadenza: data(2), priorita: .bassa, completata: false),
            Attivita(id: "task-done", clienteId: "giulia", titolo: "Aggiornare le note dell’ultimo colloquio", scadenza: data(-3), priorita: .normale, completata: true),
        ]
    }

    /// Oggi + `giorni`, all'ora indicata.
    private static func data(_ giorni: Int, _ ora: Int = 9, _ minuti: Int = 0) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let oggi = cal.startOfDay(for: Date())
        let giorno = cal.date(byAdding: .day, value: giorni, to: oggi) ?? oggi
        return cal.date(bySettingHour: ora, minute: minuti, second: 0, of: giorno) ?? giorno
    }
}
