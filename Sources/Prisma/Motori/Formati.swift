import Foundation

// MARK: - Formati

enum Formati {
    static let italiano = Locale(identifier: "it_IT")

    static func formato(_ schema: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = italiano
        f.dateFormat = schema
        return f
    }

    static let giorno = formato("d")
    static let meseBreve = formato("MMM")
    static let barraData = formato("EEE d MMM")
    static let ora = formato("HH:mm")
    static let dataOra = formato("d MMM yyyy, HH:mm")
    static let dataLunga = formato("EEEE d MMMM")
    static let giornoSettimana = formato("EEEE")
    static let dataEstesa = formato("d MMMM yyyy")
    static let dataBreve = formato("dd/MM/yyyy")
    static let giornoBreve = formato("EEE d")
    static let giornoMese = formato("d MMMM")
    static let giornoMeseBreve = formato("d MMM")

    /// "oggi", "domani", "ieri" oppure "gio 23".
    static func giornoRelativo(_ data: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(data) { return "oggi" }
        if cal.isDateInTomorrow(data) { return "domani" }
        if cal.isDateInYesterday(data) { return "ieri" }
        return giornoBreve.string(from: data)
    }
    /// Data proposta quando si indica una data di nascita (1 gennaio 1980).
    static let dataPredefinitaNascita = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1980, month: 1, day: 1)) ?? Date()
    static let meseAnno = formato("MMMM yyyy")
    /// "mar 25" per gli assi dei grafici.
    static let meseAnnoBreve = formato("MMM yy")
    /// Per i nomi dei file (nessun carattere vietato dal Finder).
    static let nomeFile = formato("yyyy-MM-dd HH.mm.ss")

    /// Per gli importi: separatori italiani (punto per le migliaia, virgola per i decimali), ma con il
    /// punto anche sulle cifre a quattro (7.650 €). Le regole it_IT non lo mettono sotto i 10.000;
    /// quelle tedesche sì, con gli stessi separatori e il simbolo dopo l'importo.
    static let localeImporti = Locale(identifier: "de_DE")

    /// Il segno meno tipografico (−), come nei prospetti: mai il trattino accanto a "− 130.000 €".
    static let meno = "\u{2212}"

    static let euroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = localeImporti
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.maximumFractionDigits = 0
        f.minusSign = meno
        return f
    }()

    static let numeroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = localeImporti
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minusSign = meno
        return f
    }()

    /// "12.345 €"
    static func euro(_ valore: Double) -> String {
        euroFormatter.string(from: NSNumber(value: valore.rounded())) ?? "\(Int(valore)) €"
    }

    static let euroDecimaliFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = localeImporti
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.minusSign = meno
        return f
    }()

    /// "1,47 €"
    static func euroDecimali(_ valore: Double) -> String {
        euroDecimaliFormatter.string(from: NSNumber(value: valore)) ?? euro(valore)
    }

    /// "12k €", "1,12 mln €" per gli assi dei grafici.
    static func euroBreve(_ valore: Double) -> String {
        if abs(valore) >= 1_000_000 {
            return "\(numeroFormatter.string(from: NSNumber(value: valore / 1_000_000)) ?? "") mln €"
        }
        return abs(valore) >= 1000 ? "\(numeroFormatter.string(from: NSNumber(value: (valore / 1000).rounded())) ?? "")k €" : euro(valore)
    }

    /// "2,5%"
    static func percentuale(_ valore: Double) -> String {
        "\(numeroFormatter.string(from: NSNumber(value: valore)) ?? "\(valore)")%"
    }

    static func dimensione(_ byte: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: byte)
    }
}
