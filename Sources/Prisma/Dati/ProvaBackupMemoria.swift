import Foundation

// Riesame con memoria (specifica 12 §8.2): le fotografie dei riesami dentro `Prisma --prova-backup`. Le chiama
// ProvaBackup.esegui() con due righe: le fotografie di prova prima di scrivere l'archivio e il controllo subito dopo
// il confronto dei dati estratti.

extension ProvaBackup {
    /// Due fotografie di prova per «giulia» (una completa, una con i soli campi obbligatori), date a secondi interi
    /// (il codificatore ISO 8601 dell'archivio non conserva le frazioni di secondo).
    static func fotografieDiProva() -> [FotografiaRiesame] {
        let cal = Calendar(identifier: .gregorian)
        typealias F = FotografiaRiesame
        var completa = F(clienteId: "giulia", data: cal.startOfDay(for: AiutiProva.data(2026, 3, 12)))
        completa.id = "foto-prova-completa"
        completa.origini = ["prospetto", "incontro"]
        completa.propensione = "moderata"
        completa.orizzonteAnni = 10
        completa.esperienza = "media"
        completa.profiloAggiornatoIl = AiutiProva.data(2026, 2, 1)
        completa.statoCivile = "convivente"
        completa.famiglia = [F.FamiliareFoto(id: "f-prova-luca", nome: "Luca", relazione: "convivente", aCarico: false),
                             F.FamiliareFoto(id: "f-prova-sofia", nome: "Sofia", relazione: "figlia", aCarico: true)]
        completa.semafori = [F.SemaforoFoto(id: "riserva", titolo: "Riserva di emergenza", colore: "giallo", valore: "6 mesi su 12"),
                             F.SemaforoFoto(id: "morte", titolo: "Protezione della famiglia", colore: "rosso", valore: "45% coperto"),
                             F.SemaforoFoto(id: "invalidita", titolo: "Reddito in caso di invalidità", colore: "rosso", valore: "1.400 € al mese"),
                             F.SemaforoFoto(id: "previdenza", titolo: "Pensione", colore: "giallo", valore: "40% del divario"),
                             F.SemaforoFoto(id: "investimenti", titolo: "Risparmi che lavorano", colore: "verde", valore: "65.000 €"),
                             F.SemaforoFoto(id: "debiti", titolo: "Peso dei debiti", colore: "verde", valore: "nessuna rata"),
                             F.SemaforoFoto(id: "obiettivi", titolo: "Obiettivi", colore: "verde", valore: "77% in media")]
        completa.redditoDesiderato = 2_200
        completa.pensionePubblica = 1_790
        completa.renditaPiani = 0
        completa.divarioPensione = 410
        completa.fabbisognoCasoMorte = 335_000
        completa.capitaleCasoMorte = 150_000
        completa.scopertoCasoMorte = 185_000
        completa.ammancoInvalidita = 1_400
        completa.obiettivi = [F.ObiettivoFoto(id: "obiettivo-prova-casa", titolo: "Casa", importo: 60_000,
                                              scadenza: AiutiProva.data(2030, 1, 1), quota: 0.75)]
        completa.patrimonioAlleanza = 42_000
        completa.patrimonioIndipendente = 37_300
        completa.debiti = 90_000
        completa.proposteAperte = 1
        completa.completezza = 77
        completa.livelloCompletezza = "Quasi completi"
        completa.conformita = [F.VoceConformitaFoto(tipo: "questionarioAlleanza", titolo: "Questionario di adeguatezza",
                                                    canale: .alleanza, stato: "inRegola")]
        var minima = F(clienteId: "giulia", data: cal.startOfDay(for: AiutiProva.data(2026, 10, 20)))
        minima.id = "foto-prova-minima"
        return [completa, minima]
    }

    /// Controlli delle fotografie sul backup estratto e su archivi scritti a mano. nil = tutto bene.
    static func verificaFotografie(originale: DatiPrisma, estratto: DatiPrisma) throws -> String? {
        // 1. Il backup le comprende (anche quelli protetti: passano dallo stesso archivio.json)
        guard estratto.fotografie == originale.fotografie, estratto.fotografie.count == 2 else {
            return "le fotografie dei riesami non tornano identiche dal backup"
        }
        // 2. La fotografia completa
        guard let c = estratto.fotografie.first(where: { $0.id == "foto-prova-completa" }),
              let o = originale.fotografie.first(where: { $0.id == "foto-prova-completa" }),
              c.conformita?.first?.canale == .alleanza, c.completezza == 77, c.semafori.count == 7,
              c.patrimonioAlleanza == o.patrimonioAlleanza, c.patrimonioIndipendente == o.patrimonioIndipendente else {
            return "la fotografia completa non conserva conformità, completezza, semafori o patrimonio per canale"
        }
        // 3. Un archivio della versione 20 non ha fotografie
        let vecchio = #"{"versione":20,"clienteAttivoId":"a","clienti":[{"id":"a","nome":"Cliente Vecchio","creatoIl":"2026-01-01T00:00:00Z"}]}"#
        guard try Archivio.decodifica(Data(vecchio.utf8)).fotografie.isEmpty else {
            return "un archivio della versione 20 ha fotografie"
        }
        // 4. Lettura tollerante: una fotografia senza cliente si scarta, le altre restano; i valori sconosciuti si conservano
        let tollerante = #"""
        {"versione":24,"clienteAttivoId":"a","clienti":[{"id":"a","nome":"Cliente","creatoIl":"2026-01-01T00:00:00Z"}],
         "fotografie":[
           {"id":"foto-1","clienteId":"a","data":"2026-03-12T00:00:00Z","origini":["prospetto","futura"],
            "semafori":[{"id":"previdenza","titolo":"Pensione","colore":"blu","valore":"—"}],"patrimonioAlleanza":42000,
            "campoFuturo":{"x":1}},
           {"id":"foto-2","clienteId":"a","data":"2026-10-20T00:00:00Z"},
           {"id":"foto-rotta","data":"2026-10-21T00:00:00Z"}
         ]}
        """#
        let letto = try Archivio.decodifica(Data(tollerante.utf8))
        guard letto.fotografie.count == 2,
              let f1 = letto.fotografie.first(where: { $0.id == "foto-1" }),
              let f2 = letto.fotografie.first(where: { $0.id == "foto-2" }) else {
            return "lettura tollerante: attese 2 fotografie su 3 (\(letto.fotografie.map(\.id).joined(separator: ", ")))"
        }
        guard f1.origini == ["prospetto", "futura"], f1.origineNote == [.prospetto], f1.semafori.first?.colore == "blu",
              f1.patrimonioAlleanza == 42_000, f1.patrimonioIndipendente == 0, f1.conformita == nil else {
            return "lettura tollerante: la fotografia con valori sconosciuti non è letta come atteso"
        }
        guard f2.famiglia.isEmpty, f2.semafori.isEmpty, f2.obiettivi.isEmpty, f2.divarioPensione == nil, f2.propensione == nil,
              f2.origini.isEmpty, f2.schema == 1, f2.completezza == nil, f2.conformita == nil else {
            return "lettura tollerante: la fotografia con i soli campi obbligatori non prende i predefiniti"
        }
        // 5. Andata e ritorno di quell'archivio: uguale, con l'origine «futura» conservata
        let riletto = try Archivio.decodifica(Archivio.codificatore.encode(letto))
        guard riletto == letto, riletto.fotografie.first(where: { $0.id == "foto-1" })?.origini.contains("futura") == true else {
            return "le fotografie lette con valori sconosciuti non tornano identiche dopo un salvataggio"
        }
        // 6. La versione dell'archivio
        guard DatiPrisma.versioneAttuale >= 24 else {
            return "l'archivio con le fotografie dei riesami deve essere almeno alla versione 24"
        }
        return nil
    }
}
