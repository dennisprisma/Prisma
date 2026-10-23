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
    static func sinistra(_ app: AppPrisma) -> FinestraSpazio {
        FinestraSpazio(app: app, x: 0, y: 0, larghezza: 0.5, altezza: 1)
    }
    static func destra(_ app: AppPrisma) -> FinestraSpazio {
        FinestraSpazio(app: app, x: 0.5, y: 0, larghezza: 0.5, altezza: 1)
    }
    static func destraAlto(_ app: AppPrisma) -> FinestraSpazio {
        FinestraSpazio(app: app, x: 0.5, y: 0, larghezza: 0.5, altezza: 0.5)
    }
    static func destraBasso(_ app: AppPrisma) -> FinestraSpazio {
        FinestraSpazio(app: app, x: 0.5, y: 0.5, larghezza: 0.5, altezza: 0.5)
    }
}

extension SpazioLavoro {
    /// Le disposizioni pronte: al massimo due colonne, perché le finestre hanno una misura minima.
    /// L'app principale a sinistra, per tutta l'altezza.
    static let predefiniti: [SpazioLavoro] = [
        SpazioLavoro(id: "pronto-incontro", nome: "Incontro con il cliente",
                     finestre: [.destraAlto(.posizioni), .destraBasso(.eve), .sinistra(.clienti)], predefinito: true),
        SpazioLavoro(id: "pronto-analisi", nome: "Analisi delle posizioni",
                     finestre: [.destraAlto(.analisi360), .destraBasso(.simulazioni), .sinistra(.posizioni)], predefinito: true),
        SpazioLavoro(id: "pronto-giornata", nome: "La giornata",
                     finestre: [.destra(.attivita), .sinistra(.agenda)], predefinito: true),
        SpazioLavoro(id: "pronto-prospetti", nome: "Prospetti e report",
                     finestre: [.destra(.presentazioni), .sinistra(.posizioni)], predefinito: true),
    ]

    /// Le app, dalla principale (l'ultima, in primo piano) alle altre.
    var app: [AppPrisma] { finestre.reversed().map(\.app) }
}
