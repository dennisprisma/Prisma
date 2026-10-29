import Foundation

/// I testi dell'esperienza per tipo di prodotto: cosa spiegare per ogni tipo, frasi delle incoerenze,
/// fonti normative per la scheda di adeguatezza e metodo della griglia.
enum TestiEsperienza {
    // MARK: - Titoli delle incoerenze

    static let titoloNonConosce = "Proposta di un tipo che non conosce"
    static let titoloDaSpiegare = "Proposta di un prodotto da spiegare meglio"
    static let titoloPerdita = "Perdita possibile oltre la capacità del cliente"
    static let titoloSoloScadenza = "Capitale garantito solo a scadenza"

    // MARK: - Cosa spiegare

    /// Cosa spiegare di un tipo di prodotto («Prima di presentarla spiega …»). Le cifre della previdenza
    /// vengono dal D.Lgs. 252/2005 (art. 8 c. 4, art. 11 c. 6) e da `RegoleFiscali`.
    static func daCapire(_ t: TipoProdotto) -> String {
        switch t {
        case .ramoI:
            return "come funziona: capitale garantito secondo le condizioni, rendimento della gestione separata meno il trattenuto, consolidamento, penali di riscatto nei primi anni"
        case .ramoIII:
            return "come funziona: il valore segue i fondi e può scendere, nessuna garanzia sul capitale, costi del contratto e dei fondi, bollo dello 0,20% l'anno"
        case .multiramo:
            return "come funziona: solo la parte in gestione separata è garantita, la parte in fondi sale e scende, le quote tra le due parti, i costi di ciascuna"
        case .fondiETF:
            return "come funzionano: il valore cambia ogni giorno con i mercati, nessuna garanzia, costi correnti, rischio di cambio per i titoli esteri"
        case .titoli:
            return "come funzionano: il rischio dell'emittente (si può perdere tutto il capitale), il prezzo che cambia con i tassi, cedole e dividendi non garantiti"
        case .previdenza:
            return "come funziona: il vincolo fino alla pensione salvo anticipazioni e riscatti di legge, la deducibilità fino a \(CifreDoc.euroCentesimi(RegoleFiscali.limiteDeducibilita)) l'anno, la tassazione della prestazione dal 15% fino al 9%"
        case .protezione:
            return "come funziona: si paga un premio per coprire un rischio e non si accumula capitale; esclusioni, carenze e franchigie"
        }
    }

    // MARK: - Dettagli delle incoerenze

    /// E1 (non conosce) ed E2 (da spiegare); con il tipo ricavato dai dati lo dice in fondo.
    static func dettaglioEsperienza(_ p: Posizione, _ c: ClassificazioneProdotto, _ livello: LivelloEsperienza) -> String {
        let t = c.tipo
        var testo: String
        if livello == .nonConosce {
            testo = "\(p.nome) (\(t.nome)): il cliente ha detto di non conoscere \(t.descrizione). Prima di presentarla spiega \(daCapire(t))."
        } else {
            testo = "\(p.nome) (\(t.nome)): il cliente conosce \(t.descrizione) ma non ne ha capito il funzionamento. Riprendi \(daCapire(t))."
        }
        if c.stimata {
            testo += " Il tipo è ricavato dai dati della posizione: indica la tipologia per esserne certo."
        }
        return testo
    }

    /// P1: la perdita nella crisi peggiore del passato oltre la capacità del cliente.
    static func dettaglioPerdita(_ p: Posizione, _ s: PerditaStimata, _ capacita: CapacitaPerdite) -> String {
        let crisi: String
        if let anno = s.anno {
            let titolo = s.titoloCrisi.map { " (\($0.lowercased()))" } ?? ""
            crisi = "in una crisi come quella del \(anno)\(titolo)"
        } else {
            crisi = "in una crisi come quelle del passato"
        }
        return "\(p.nome): \(crisi) perderebbe circa il \(CifreDoc.percento(s.percento, decimali: 0)) del capitale, \(CifreDoc.euro(s.euro)) su \(CifreDoc.euro(s.capitale)); il cliente \(capacita.frase)."
    }

    /// P3: gestione separata senza consolidamento annuo con capacità di perdita nessuna.
    static func dettaglioSoloScadenza(_ p: Posizione) -> String {
        "\(p.nome): la gestione separata non consolida il rendimento ogni anno, quindi prima della scadenza il valore può scendere; il cliente \(CapacitaPerdite.nessuna.frase)."
    }

    // MARK: - Scheda di adeguatezza

    /// Una frase sola sull'esperienza e la capacità di perdita di una proposta, per la scheda di adeguatezza.
    static func esitoScheda(_ v: VerificaEsperienza) -> String {
        // Esperienza e perdite con la griglia compilata: le stesse frasi del dettaglio delle incoerenze
        if !v.incoerenze.isEmpty {
            return v.incoerenze.map(\.dettaglio).joined(separator: " ")
        }
        switch v.livello {
        case .daChiedere:
            return "Esperienza con questo tipo di prodotto non rilevata."
        case .nonConosce, .daSpiegare:
            // Griglia non compilata non può dare questi livelli; per sicurezza la stessa frase del dettaglio
            return dettaglioEsperienza(v.posizione, v.classificazione, v.livello)
        case .conosce, .esperto:
            guard let s = v.perdita else { return "Il cliente conosce questo tipo di prodotto." }
            let perdita = CifreDoc.percento(s.percento, decimali: 0)
            if v.oltreCapacita == nil {
                return "Il cliente conosce questo tipo di prodotto; la perdita possibile (\(perdita)) non si confronta: capacità di sostenere perdite non indicata."
            }
            return "Il cliente conosce questo tipo di prodotto; la perdita possibile (\(perdita)) è entro la sua capacità."
        }
    }

    /// Le fonti normative dell'ambito, per la nota sotto la tabella della scheda. Riferimenti da verificare
    /// sul testo vigente prima di stampare la scheda ufficiale.
    static func fonte(_ ambito: AmbitoNormativo) -> String {
        switch ambito {
        case .ibip:
            return "Prodotti d'investimento assicurativi: IDD (Dir. UE 2016/97) art. 30; Codice delle assicurazioni private (D.Lgs. 209/2005) art. 121-septies; Reg. delegato UE 2017/2359 artt. 9 e 17 (conoscenza ed esperienza, situazione finanziaria e capacità di sostenere perdite); Regolamento IVASS n. 40/2018."
        case .mifid:
            return "Strumenti finanziari: MiFID II (Dir. 2014/65/UE) art. 25; TUF (D.Lgs. 58/1998) art. 21; Reg. delegato UE 2017/565 artt. 54–56; Regolamento Intermediari Consob n. 20307/2018; Orientamenti ESMA sull'adeguatezza (2022)."
        case .previdenza:
            return "Previdenza complementare: D.Lgs. 252/2005; Regolamento COVIP sulle modalità di adesione, con il Questionario di autovalutazione."
        case .protezione:
            return "Protezione: IDD art. 20 e Codice delle assicurazioni private art. 119-ter (contratto coerente con le richieste e le esigenze del contraente)."
        }
    }

    // MARK: - Metodo

    /// Il metodo della griglia, per l'aiuto «Come si giudica?».
    static var metodo: [String] {
        [
            "Per ogni tipo di prodotto: lo conosce, l'ha avuto, ne ha capito il funzionamento. Chi non lo conosce o non l'ha capito riceve un avviso quando gli si propone quel tipo; se l'esperienza non è indicata, Prisma ricorda di chiederla.",
            "Capacità di sostenere perdite: nessuna, fino al 10%, fino al 25% o oltre il 25% del capitale investito. Per le polizze d'investimento, i fondi e i titoli Prisma calcola la perdita che la proposta avrebbe avuto nella crisi peggiore del passato (2008, 2020, 2022), con la stessa composizione della prova di resistenza; con capacità nessuna basta una perdita sopra lo \(CifreDoc.percento(MotoreEsperienza.sogliaNessuna, decimali: 1)), o una gestione separata senza consolidamento annuo.",
            "Il tipo si ricava da area e tipologia: Ramo I, Ramo III (unit linked), multiramo, fondi ed ETF, azioni e obbligazioni, previdenza complementare, protezione. Non sostituisce i questionari di adeguatezza ufficiali.",
        ]
    }
}
