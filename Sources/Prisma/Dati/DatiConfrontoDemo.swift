import Foundation

/// Documenti di prova del confronto con il dossier (specifica 9 del giro 5): il nuovo KID dell'ETF e un'appendice del
/// piano di risparmio di Giulia. Servono solo alle prove DD e alle scene 190–194: `DatiDemo` non cambia, così
/// `--prova-eve` e le altre prove vedono gli stessi dati di prima. Il testo entra nelle scene con `memorizzaTesto`.
enum DatiConfrontoDemo {
    static let idKIDETF = "doc-giulia-kid-etf-aggiornato"
    static let idAppendice = "doc-giulia-appendice-risparmio"

    /// Nuovo KID dell'ETF azionario globale: rischio 5 su 7, costi correnti e incidenza 0,25%.
    static let pagineKIDETF: [String] = [
        """
        Documento contenente le informazioni chiave
        Prodotto: ETF azionario globale, classe ad accumulazione
        Ideatore del PRIIP: Emittente ETF
        Tipo: ETF a replica fisica, piano di accumulo
        """,
        """
        Quali sono i rischi e qual è il potenziale rendimento?
        Abbiamo classificato questo prodotto nella classe di rischio 5 su 7, che corrisponde alla classe di rischio media-alta.
        Periodo di detenzione raccomandato: 5 anni
        Scenari di performance
        Scenario moderato  Possibile rimborso al netto dei costi 13.440 €  Rendimento medio per ciascun anno 6,1%
        """,
        """
        Quali sono i costi?
        Costi di ingresso: non applichiamo costi di ingresso, 0,00%
        Costi di uscita: 0,00%
        Commissioni di gestione e altri costi amministrativi o di esercizio: 0,25% del valore dell'investimento all'anno
        Incidenza annuale dei costi: 0,25% ogni anno
        """,
    ]

    /// Appendice di variazione del piano di risparmio di Giulia: nuovi beneficiari e premio mensile più alto.
    static func pagineAppendice(scadenza: Date) -> [String] {
        ["""
        ALLEANZA ASSICURAZIONI S.p.A.
        Appendice di variazione n. 2 alla polizza n. AL-2022-104851
        Prodotto: Piano di risparmio rivalutabile
        Contraente: Giulia Rossi
        Beneficiari caso morte: Luca Ferri
        Premio mensile: 180,00
        Scadenza: \(Formati.dataBreve.string(from: scadenza))
        """]
    }

    /// Il KID collegato alla scheda dell'ETF, con i dati confermati.
    static func kidETF(clienteId: String = "giulia") -> Documento {
        var d = Documento(clienteId: clienteId, titolo: "KID · ETF azionario globale (aggiornato)", tipo: .kid)
        d.id = idKIDETF
        d.prodottoId = "prodotto-etf-globale"
        d.pagine = pagineKIDETF.count
        d.dimensione = 151_552
        d.lettura = .letto
        d.importatoIl = Posizione.oggiArrotondato
        d.campi = confermati(EstrattoreDocumento.conRegole(pagineKIDETF))
        return d
    }

    /// L'appendice, con i dati confermati e senza collegamento.
    static func appendice(scadenza: Date, clienteId: String = "giulia") -> Documento {
        let pagine = pagineAppendice(scadenza: scadenza)
        var d = Documento(clienteId: clienteId, titolo: "Appendice di variazione n. 2 · Piano di risparmio rivalutabile", tipo: .polizza)
        d.id = idAppendice
        d.pagine = pagine.count
        d.dimensione = 88_064
        d.lettura = .letto
        d.importatoIl = Posizione.oggiArrotondato
        d.campi = confermati(EstrattoreDocumento.conRegole(pagine))
        return d
    }

    private static func confermati(_ campi: [CampoEstratto]) -> [CampoEstratto] {
        campi.map { c in
            var x = c
            x.confermato = true
            return x
        }
    }
}
