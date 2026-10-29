import Foundation

/// I dati delle scene del pannello «Aggiorna i valori» (180–183): relativi a oggi, così le istantanee si
/// ripetono a ogni ora del server. `DatiDemo` non cambia: le posizioni di prova hanno il valore a −5 giorni.
enum DatiAggiornaValoriDemo {
    /// Un elenco «della compagnia» per i clienti di prova (righe CSV, date relative a oggi).
    /// −2 giorni è più recente del valore delle posizioni di prova, −200 va nello storico.
    static func elenco(oggi: Date) -> String {
        func g(_ n: Int) -> String {
            Formati.dataBreve.string(from: Calendar.current.date(byAdding: .day, value: n, to: oggi) ?? oggi)
        }
        let righe = [
            "Contraente;Numero polizza;Prodotto;Controvalore;Data valore;Totale versato;Valore gestione separata",
            "Giulia Rossi;AL-2022-104851;Piano di risparmio rivalutabile;7.790;\(g(-2));7.350;",
            "Giulia Rossi;;ETF azionario globale;37.150;\(g(-2));;",
            "Marco Bianchi;AL-2020-055120;Polizza rivalutabile a premio unico;54.420;\(g(-2));;",
            "Marco Bianchi;AL-2021-118842;Polizza multiramo;61.380;\(g(-2));;25.100",
            "Marco Bianchi;AL-2021-118842;Polizza multiramo;60.200;\(g(-200));;",
            "Sofia Romano;AL-2016-009311;Polizza rivalutabile;52.000;\(g(-2));;",
            "Giulia Rossi;AL-2023-220417;Temporanea caso morte;0;\(g(-2));;",
            "Laura Moretti;;ETF azionario globale;27.400;\(g(-2));;",
            "Paolo Neri;AL-2025-777001;Piano futuro;10.000;\(g(-2));;",
        ]
        return righe.joined(separator: "\n") + "\n"
    }

    /// Invecchia i valori di tre posizioni di prova e toglie la data a una (solo per la scena della griglia).
    /// I valori passati più recenti della data nuova si tolgono, perché lo storico resti in ordine.
    static func invecchia(_ s: StatoShell) {
        let cal = Calendar.current
        let oggi = Date()
        func indietro(_ giorni: Int) -> Date {
            ValoriDaDocumento.mezzogiorno(cal.date(byAdding: .day, value: -giorni, to: oggi) ?? oggi)
        }
        let giorni = ["pos-giulia-fondo-obbligazionario-euro": 400,
                      "pos-laura-fondo-pensione-aperto": 430,
                      "pos-sofia-portafoglio-di-fondi": 380]
        var posizioni = s.dati.posizioni
        for i in posizioni.indices {
            let id = posizioni[i].id
            if let n = giorni[id] {
                let data = indietro(n)
                posizioni[i].dataValore = data
                posizioni[i].rilevazioni?.removeAll { $0.data >= data }
            } else if id == "pos-marco-piano-individuale-pensionistico" {
                posizioni[i].dataValore = nil
            }
        }
        s.dati.posizioni = posizioni
    }

    /// Le caselle già scritte nella griglia della scena.
    static func bozze() -> [String: AggiornaValori.Bozza] {
        ["pos-giulia-fondo-obbligazionario-euro": AggiornaValori.Bozza(valore: "21.350"),
         "pos-sofia-portafoglio-di-fondi": AggiornaValori.Bozza(valore: "33.100", versato: "28.000")]
    }
}
