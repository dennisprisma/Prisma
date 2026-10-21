import Foundation

/// Le 16 app di Prisma, nell'ordine del dock del template.
enum AppPrisma: String, CaseIterable, Identifiable, Codable {
    case clienti, analisi360, incontri, analisi, obiettivi, confronti, prodotti, simulazioni
    case agenda, attivita, note, documenti, presentazioni, eve, ricerca, impostazioni

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .clienti: return "Clienti"
        case .analisi360: return "Analisi 360"
        case .incontri: return "Incontri"
        case .analisi: return "Analisi"
        case .obiettivi: return "Obiettivi"
        case .confronti: return "Confronti"
        case .prodotti: return "Prodotti"
        case .simulazioni: return "Simulazioni"
        case .agenda: return "Agenda"
        case .attivita: return "Attività"
        case .note: return "Note"
        case .documenti: return "Documenti"
        case .presentazioni: return "Presentazioni"
        case .eve: return "Eve"
        case .ricerca: return "Ricerca"
        case .impostazioni: return "Impostazioni"
        }
    }

    var sottotitolo: String {
        switch self {
        case .clienti: return "Le persone, prima di tutto"
        case .analisi360: return "Previdenza, protezione, investimenti, risparmio"
        case .incontri: return "Dall'ascolto ai prossimi passi"
        case .analisi: return "Il quadro, senza perdere i dettagli"
        case .obiettivi: return "Un nome al futuro"
        case .confronti: return "Le ipotesi una accanto all'altra"
        case .prodotti: return "Condizioni, costi e fonti"
        case .simulazioni: return "Il tempo e le possibilità"
        case .agenda: return "Spazio alle relazioni"
        case .attivita: return "Un passo alla volta"
        case .note: return "Le parole da ricordare"
        case .documenti: return "Tutto al proprio posto"
        case .presentazioni: return "Una prospettiva condivisa"
        case .eve: return "Un filo tra le tue app"
        case .ricerca: return "Ritrova ciò che conta"
        case .impostazioni: return "Il tuo modo di lavorare"
        }
    }

    /// Occhiello dell'intestazione dentro la finestra.
    var occhiello: String {
        switch self {
        case .clienti: return "Rubrica Prisma"
        case .analisi360: return "Il centro della consulenza"
        case .incontri: return "Il tempo della relazione"
        case .analisi: return "Dossier patrimoniale"
        case .obiettivi: return "Il quaderno dei progetti"
        case .confronti: return "Ipotesi trasparenti"
        case .prodotti: return "Schede e fonti verificabili"
        case .simulazioni: return "Il laboratorio delle ipotesi"
        case .agenda: return "Prisma · Agenda personale"
        case .attivita: return "Prisma · Promemoria"
        case .note: return "Taccuino personale"
        case .documenti: return "Archivio Prisma"
        case .presentazioni: return "Una prospettiva condivisa"
        case .eve: return "Assistente personale"
        case .ricerca: return "Ritrova il filo"
        case .impostazioni: return "Sentiti a casa"
        }
    }

    /// Nome del file in Risorse/Icone (senza estensione).
    var icona: String {
        switch self {
        case .clienti: return "Clienti"
        case .analisi360: return "Analisi_360"
        case .incontri: return "Incontri"
        case .analisi: return "Analisi"
        case .obiettivi: return "Obiettivi"
        case .confronti: return "Confronti"
        case .prodotti: return "Prodotti"
        case .simulazioni: return "Simulazioni"
        case .agenda: return "Agenda_base"
        case .attivita: return "Attivita"
        case .note: return "Note"
        case .documenti: return "Documenti"
        case .presentazioni: return "Presentazioni"
        case .eve: return "Eve"
        case .ricerca: return "Ricerca"
        case .impostazioni: return "Impostazioni"
        }
    }

    /// Fase in cui l'app viene sviluppata (per il messaggio delle app ancora vuote).
    var inArrivo: String {
        switch self {
        case .clienti: return "La rubrica e il dossier dei clienti arrivano con il modulo Clienti."
        case .agenda, .attivita, .incontri: return "Arriva con il modulo Agenda: appuntamenti, attività, incontri e scadenze."
        case .analisi, .analisi360, .prodotti, .confronti, .simulazioni, .obiettivi:
            return "Fa parte del modulo Posizioni, il cuore di Prisma, con il canale Alleanza / indipendente sempre in vista."
        case .eve: return "Eve arriva con il suo modulo: lettura dei documenti, estrazione dei dati e risposte in chat, tutto sul Mac."
        case .note, .documenti, .presentazioni, .ricerca: return "Arriva nelle prossime fasi di sviluppo."
        case .impostazioni: return "Profilo, backup manuale e settimanale, ripristino e impostazioni di Eve."
        }
    }
}
