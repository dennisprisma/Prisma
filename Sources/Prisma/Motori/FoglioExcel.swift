import Foundation

/// Legge il primo foglio di una cartella di lavoro Excel (.xlsx) come righe di testo, senza Excel e senza
/// librerie esterne: un .xlsx è un archivio zip di file XML, che si apre con `unzip` del Mac (su iPhone e iPad,
/// dove non c'è `Process`, con `LettoreZip`).
/// Tutto in locale: il file non lascia il Mac.
///
/// Le celle escono come le leggerebbe un CSV italiano: i numeri con la virgola decimale ("1234,5"),
/// le date come numero di serie di Excel (le converte `ImportaClienti.data`).
enum FoglioExcel {
    static func righe(_ url: URL) -> [[String]]? {
        guard let foglio = percorsoPrimoFoglio(url), let xml = estrai(url, foglio) else { return nil }
        let condivisi = estrai(url, "xl/sharedStrings.xml").map(stringheCondivise) ?? []
        return righe(foglioXML: xml, condivisi: condivisi)
    }

    /// Le righe di un foglio già estratto (usato anche dalle prove).
    static func righe(foglioXML: Data, condivisi: [String]) -> [[String]] {
        let lettore = LettoreFoglio(condivisi: condivisi)
        let parser = XMLParser(data: foglioXML)
        parser.delegate = lettore
        parser.parse()
        return lettore.righe.filter { $0.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    /// Il primo foglio nell'ordine delle schede (workbook.xml → relazioni), non per forza "sheet1.xml".
    private static func percorsoPrimoFoglio(_ url: URL) -> String? {
        if let libro = estrai(url, "xl/workbook.xml"), let relazioni = estrai(url, "xl/_rels/workbook.xml.rels"),
           let rid = primoAttributo(libro, elemento: "sheet", attributo: "r:id"),
           let destinazione = destinazione(relazioni, id: rid) {
            let pulita = destinazione.hasPrefix("/") ? String(destinazione.dropFirst()) : "xl/" + destinazione
            return pulita
        }
        return "xl/worksheets/sheet1.xml"
    }

    /// Un file dell'archivio, letto con `unzip -p` (sul Mac da sempre, nessuna installazione); su iPhone e iPad
    /// con `LettoreZip` (stessa regola: nil se la voce manca, è vuota o lo zip non si legge).
    static func estrai(_ archivio: URL, _ percorso: String) -> Data? {
        #if os(macOS)
        let processo = Process()
        processo.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        processo.arguments = ["-p", archivio.path, percorso]
        let uscita = Pipe()
        processo.standardOutput = uscita
        processo.standardError = FileHandle.nullDevice
        do { try processo.run() } catch { return nil }
        let dati = uscita.fileHandleForReading.readDataToEndOfFile()
        processo.waitUntilExit()
        return processo.terminationStatus == 0 && !dati.isEmpty ? dati : nil
        #elseif os(iOS)
        guard let dati = try? LettoreZip.dati(archivio, voce: percorso), !dati.isEmpty else { return nil }
        return dati
        #endif
    }

    // MARK: - XML

    static func stringheCondivise(_ dati: Data) -> [String] {
        let lettore = LettoreStringhe()
        let parser = XMLParser(data: dati)
        parser.delegate = lettore
        parser.parse()
        return lettore.stringhe
    }

    private static func primoAttributo(_ dati: Data, elemento: String, attributo: String) -> String? {
        let lettore = LettoreAttributo(elemento: elemento, attributo: attributo)
        let parser = XMLParser(data: dati)
        parser.delegate = lettore
        parser.parse()
        return lettore.valori.first
    }

    private static func destinazione(_ relazioni: Data, id: String) -> String? {
        let lettore = LettoreRelazioni()
        let parser = XMLParser(data: relazioni)
        parser.delegate = lettore
        parser.parse()
        return lettore.destinazioni[id]
    }

    /// "B12" → 1 (colonna B, a partire da zero).
    static func colonna(_ riferimento: String) -> Int? {
        var n = 0
        var trovate = false
        for ch in riferimento.uppercased() {
            guard let a = ch.asciiValue, a >= 65, a <= 90 else { break }
            n = n * 26 + Int(a - 64)
            trovate = true
        }
        return trovate ? n - 1 : nil
    }

    /// Un numero di Excel come in un CSV italiano: interi senza decimali, altrimenti con la virgola.
    static func numeroItaliano(_ s: String) -> String {
        guard let d = Double(s), d.isFinite else { return s }
        if d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
        var t = String(format: "%.6f", d)
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t.replacingOccurrences(of: ".", with: ",")
    }
}

/// Le celle del foglio: <row><c r="B2" t="s"><v>3</v></c>…</row>.
private final class LettoreFoglio: NSObject, XMLParserDelegate {
    let condivisi: [String]
    var righe: [[String]] = []
    private var riga: [String] = []
    private var tipo = ""
    private var indice = 0
    private var testo = ""
    private var dentroValore = false

    init(condivisi: [String]) { self.condivisi = condivisi }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        switch elementName {
        case "row":
            riga = []
        case "c":
            tipo = attributes["t"] ?? ""
            indice = attributes["r"].flatMap(FoglioExcel.colonna) ?? riga.count
            testo = ""
        case "v", "t":
            dentroValore = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if dentroValore { testo += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "v", "t":
            dentroValore = false
        case "c":
            let valore: String
            switch tipo {
            case "s": valore = Int(testo).flatMap { $0 < condivisi.count ? condivisi[$0] : nil } ?? ""
            case "inlineStr", "str", "e": valore = testo
            case "b": valore = testo == "1" ? "sì" : "no"
            default: valore = testo.isEmpty ? "" : FoglioExcel.numeroItaliano(testo)
            }
            // Le celle vuote non compaiono nel file: si riempie fino alla colonna giusta
            if indice < 16_384 {
                while riga.count < indice { riga.append("") }
                if riga.count == indice { riga.append(valore) }
            }
        case "row":
            righe.append(riga)
        default:
            break
        }
    }
}

/// sharedStrings.xml: <si><t>testo</t></si>, anche a pezzi formattati (<si><r><t>…</t></r>…</si>).
private final class LettoreStringhe: NSObject, XMLParserDelegate {
    var stringhe: [String] = []
    private var corrente = ""
    private var dentroTesto = false
    private var dentroFonetica = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "si" { corrente = "" }
        if elementName == "rPh" { dentroFonetica = true }
        if elementName == "t" && !dentroFonetica { dentroTesto = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if dentroTesto { corrente += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" { dentroTesto = false }
        if elementName == "rPh" { dentroFonetica = false }
        if elementName == "si" { stringhe.append(corrente) }
    }
}

private final class LettoreAttributo: NSObject, XMLParserDelegate {
    let elemento: String
    let attributo: String
    var valori: [String] = []

    init(elemento: String, attributo: String) {
        self.elemento = elemento
        self.attributo = attributo
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        if elementName == elemento, let v = attributes[attributo] { valori.append(v) }
    }
}

private final class LettoreRelazioni: NSObject, XMLParserDelegate {
    var destinazioni: [String: String] = [:]

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "Relationship", let id = attributes["Id"], let t = attributes["Target"] { destinazioni[id] = t }
    }
}
