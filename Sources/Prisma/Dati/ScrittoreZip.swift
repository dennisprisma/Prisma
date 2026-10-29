import Foundation

/// Scrittore di file zip con voci solo memorizzate (metodo 0, senza compressione), scritto con Foundation e il
/// `CRC32` di LettoreZip: niente `Process` né dipendenze esterne. Su iPhone e iPad crea i backup di sicurezza
/// (per esempio prima di un ripristino), che `ditto -x -k` del Mac e `LettoreZip` riaprono.
/// - Come `ditto -c -k --keepParent`: le voci sono `<nome della cartella>/…`, con le cartelle come voci proprie.
/// - Nomi in UTF-8 (bit 11), permessi Unix negli attributi esterni, date dei file in formato MS-DOS.
/// - Un file alla volta a pezzi da 64 KB: il CRC si calcola mentre si copia e si scrive poi nell'intestazione
///   locale (niente descrittori di dati).
/// - Senza Zip64: un file o uno zip oltre i 4 GB, o più di 65.535 voci, sono un errore chiaro.
enum ScrittoreZip {
    /// Cosa contiene una voce.
    enum Contenuto {
        case cartella
        case file(URL)
        case dati(Data)
    }

    /// Una voce da scrivere: `nome` è il percorso nello zip («Prisma/Documenti/a.pdf»; le cartelle finiscono con «/»).
    struct Voce {
        var nome: String
        var contenuto: Contenuto
        var data: Date = Date()
    }

    /// Crea lo zip `zip` con la cartella `cartella` e tutto il suo contenuto, file nascosti compresi (come ditto).
    /// I collegamenti simbolici si saltano (l'archivio di Prisma non ne ha). Se `zip` c'era viene sostituito.
    static func crea(da cartella: URL, a zip: URL) throws {
        let fm = FileManager.default
        var cartellaSi: ObjCBool = false
        guard fm.fileExists(atPath: cartella.path, isDirectory: &cartellaSi), cartellaSi.boolValue else {
            throw ErroreZip.nonValido("la cartella «\(cartella.lastPathComponent)» non c'è")
        }
        let radice = cartella.lastPathComponent
        var voci: [Voce] = [Voce(nome: radice + "/", contenuto: .cartella, data: dataModifica(cartella.path))]
        // In ordine di percorso: ogni cartella arriva prima del suo contenuto
        for relativo in try fm.subpathsOfDirectory(atPath: cartella.path).sorted() {
            let url = cartella.appendingPathComponent(relativo)
            let attributi = try fm.attributesOfItem(atPath: url.path)
            let tipo = attributi[.type] as? FileAttributeType
            let data = (attributi[.modificationDate] as? Date) ?? Date()
            if tipo == .typeDirectory {
                voci.append(Voce(nome: radice + "/" + relativo + "/", contenuto: .cartella, data: data))
            } else if tipo == .typeRegular {
                voci.append(Voce(nome: radice + "/" + relativo, contenuto: .file(url), data: data))
            }
        }
        try crea(voci: voci, a: zip)
    }

    /// Crea lo zip `zip` con le voci date, nell'ordine dato (le prove lo usano anche per costruire zip rovinati).
    static func crea(voci: [Voce], a zip: URL) throws {
        let fm = FileManager.default
        guard voci.count < 0xFFFF else { throw ErroreZip.troppoGrande("più di 65.535 file") }
        try? fm.removeItem(at: zip)
        guard fm.createFile(atPath: zip.path, contents: nil) else {
            throw ErroreZip.nonValido("non riesco a creare «\(zip.lastPathComponent)»")
        }
        do {
            let h = try FileHandle(forWritingTo: zip)
            defer { try? h.close() }
            try scrivi(voci, in: h)
        } catch {
            try? fm.removeItem(at: zip)
            throw error
        }
    }

    // MARK: Scrittura

    private static let limite = UInt64(0xFFFF_FFFF)

    private static func scrivi(_ voci: [Voce], in h: FileHandle) throws {
        var posizione: UInt64 = 0
        var centrale = [UInt8]()
        for voce in voci {
            let nome = Array(voce.nome.utf8)
            guard nome.count <= 0xFFFF else { throw ErroreZip.troppoGrande("nome troppo lungo") }
            guard posizione < limite else { throw ErroreZip.troppoGrande("lo zip supera i 4 GB") }
            let inizio = posizione
            let (ora, giorno) = dataDOS(voce.data)
            var cartella = false
            if case .cartella = voce.contenuto { cartella = true }

            // Intestazione locale con CRC e dimensioni a zero: si correggono dopo la copia
            var locale = [UInt8]()
            metti32(&locale, 0x0403_4B50)
            metti16(&locale, 20)          // versione necessaria
            metti16(&locale, 0x0800)      // nomi in UTF-8
            metti16(&locale, 0)           // memorizzata
            metti16(&locale, ora)
            metti16(&locale, giorno)
            metti32(&locale, 0)           // CRC
            metti32(&locale, 0)           // dimensione compressa
            metti32(&locale, 0)           // dimensione
            metti16(&locale, UInt16(nome.count))
            metti16(&locale, 0)           // extra
            locale.append(contentsOf: nome)
            try h.write(contentsOf: Data(locale))
            posizione += UInt64(locale.count)

            var crc = CRC32()
            var dimensione: UInt64 = 0
            switch voce.contenuto {
            case .cartella:
                break
            case .dati(let d):
                crc.aggiorna(d)
                dimensione = UInt64(d.count)
                guard dimensione < limite else { throw ErroreZip.troppoGrande("«\(voce.nome)» supera i 4 GB") }
                try h.write(contentsOf: d)
            case .file(let url):
                let ingresso = try FileHandle(forReadingFrom: url)
                defer { try? ingresso.close() }
                while let blocco = try ingresso.read(upToCount: LettoreZip.pezzo), !blocco.isEmpty {
                    crc.aggiorna(blocco)
                    dimensione += UInt64(blocco.count)
                    guard dimensione < limite else { throw ErroreZip.troppoGrande("«\(voce.nome)» supera i 4 GB") }
                    try h.write(contentsOf: blocco)
                }
            }
            posizione += dimensione
            if dimensione > 0 {
                // CRC e dimensioni vere nell'intestazione locale (byte 14-25), poi di nuovo in fondo
                var correzione = [UInt8]()
                metti32(&correzione, crc.valore)
                metti32(&correzione, UInt32(dimensione))
                metti32(&correzione, UInt32(dimensione))
                try h.seek(toOffset: inizio + 14)
                try h.write(contentsOf: Data(correzione))
                try h.seek(toOffset: posizione)
            }

            // Voce della directory centrale
            let modo: UInt32 = cartella ? 0o040755 : 0o100644
            metti32(&centrale, 0x0201_4B50)
            metti16(&centrale, 3 << 8 | 20)   // creato da Unix, versione 2.0
            metti16(&centrale, 20)
            metti16(&centrale, 0x0800)
            metti16(&centrale, 0)
            metti16(&centrale, ora)
            metti16(&centrale, giorno)
            metti32(&centrale, crc.valore)
            metti32(&centrale, UInt32(dimensione))
            metti32(&centrale, UInt32(dimensione))
            metti16(&centrale, UInt16(nome.count))
            metti16(&centrale, 0)             // extra
            metti16(&centrale, 0)             // commento
            metti16(&centrale, 0)             // disco
            metti16(&centrale, 0)             // attributi interni
            metti32(&centrale, modo << 16 | (cartella ? 0x10 : 0))
            metti32(&centrale, UInt32(inizio))
            centrale.append(contentsOf: nome)
        }
        guard posizione < limite, UInt64(centrale.count) < limite else { throw ErroreZip.troppoGrande("lo zip supera i 4 GB") }
        // Fine della directory centrale
        var fine = [UInt8]()
        metti32(&fine, 0x0605_4B50)
        metti16(&fine, 0)
        metti16(&fine, 0)
        metti16(&fine, UInt16(voci.count))
        metti16(&fine, UInt16(voci.count))
        metti32(&fine, UInt32(centrale.count))
        metti32(&fine, UInt32(posizione))
        metti16(&fine, 0)
        try h.write(contentsOf: Data(centrale + fine))
    }

    private static func dataModifica(_ percorso: String) -> Date {
        ((try? FileManager.default.attributesOfItem(atPath: percorso))?[.modificationDate] as? Date) ?? Date()
    }

    /// Ora e giorno in formato MS-DOS (ora locale, a 2 secondi), dal 1980.
    private static func dataDOS(_ data: Date) -> (ora: UInt16, giorno: UInt16) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: data)
        let anno = max(1980, min(2107, c.year ?? 1980))
        let ore: Int = c.hour ?? 0
        let minuti: Int = c.minute ?? 0
        let secondi: Int = c.second ?? 0
        let mese: Int = c.month ?? 1
        let giornoMese: Int = c.day ?? 1
        let bitOra: Int = (ore << 11) | (minuti << 5) | (secondi / 2)
        let bitGiorno: Int = ((anno - 1980) << 9) | (mese << 5) | giornoMese
        let ora = UInt16(truncatingIfNeeded: bitOra)
        let giorno = UInt16(truncatingIfNeeded: bitGiorno)
        return (ora, giorno)
    }

    private static func metti16(_ b: inout [UInt8], _ v: UInt16) {
        b.append(UInt8(v & 0xFF))
        b.append(UInt8(v >> 8))
    }

    private static func metti32(_ b: inout [UInt8], _ v: UInt32) {
        for i in 0..<4 { b.append(UInt8((v >> (8 * UInt32(i))) & 0xFF)) }
    }
}
