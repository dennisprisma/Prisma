import Foundation

/// Uno spazio di lavoro: un gruppo di app con la loro disposizione, da riaprire con un clic
/// (per esempio «Incontro con il cliente»: Clienti, Posizioni ed Eve affiancate).
struct SpazioLavoro: Identifiable, Codable, Hashable {
    var id = "spazio-\(UUID().uuidString.prefix(8).lowercased())"
    var nome: String
    var finestre: [FinestraSpazio]
    /// Gli spazi pronti di Prisma non si eliminano e non si salvano nell'archivio.
    var predefinito = false

    private enum CodingKeys: String, CodingKey { case id, nome, finestre }
}

/// Una finestra dello spazio, in frazioni dell'area delle finestre (0…1): così la disposizione
/// si adatta a qualsiasi schermo.
struct FinestraSpazio: Codable, Hashable {
    var app: AppPrisma
    var x: Double
    var y: Double
    var larghezza: Double
    var altezza: Double
    var ingrandita = false

    var frazione: CGRect { CGRect(x: x, y: y, width: larghezza, height: altezza) }

    static func intera(_ app: AppPrisma) -> FinestraSpazio {
        FinestraSpazio(app: app, x: 0, y: 0, larghezza: 1, altezza: 1, ingrandita: true)
    }
    /// Quota dell'app principale quando due app sono affiancate (l'altra prende il resto).
    static let quotaPrincipale = 0.58

    static func sinistra(_ app: AppPrisma, quota: Double = quotaPrincipale) -> FinestraSpazio {
        FinestraSpazio(app: app, x: 0, y: 0, larghezza: quota, altezza: 1)
    }
    static func destra(_ app: AppPrisma, quota: Double = 1 - quotaPrincipale) -> FinestraSpazio {
        FinestraSpazio(app: app, x: 1 - quota, y: 0, larghezza: quota, altezza: 1)
    }
}

extension SpazioLavoro {
    /// Le disposizioni pronte: due app affiancate, la principale più larga e in primo piano.
    /// Non di più: le app hanno bisogno di spazio e le finestre una misura minima. Posizioni non
    /// si affianca: su uno schermo da 13″ rende solo a schermo pieno. Eve sta bene nella colonna stretta.
    static let predefiniti: [SpazioLavoro] = [
        SpazioLavoro(id: "pronto-incontro", nome: "Incontro con il cliente",
                     finestre: [.destra(.eve), .sinistra(.clienti)], predefinito: true),
        SpazioLavoro(id: "pronto-analisi", nome: "Analisi 360 con Eve",
                     finestre: [.destra(.eve), .sinistra(.analisi360)], predefinito: true),
        SpazioLavoro(id: "pronto-giornata", nome: "La giornata",
                     finestre: [.destra(.attivita), .sinistra(.agenda)], predefinito: true),
        SpazioLavoro(id: "pronto-prospetti", nome: "Prospetti con Eve",
                     finestre: [.destra(.eve), .sinistra(.presentazioni)], predefinito: true),
    ]

    /// Le app, dalla principale (l'ultima, in primo piano) alle altre.
    var app: [AppPrisma] { finestre.reversed().map(\.app) }
}
