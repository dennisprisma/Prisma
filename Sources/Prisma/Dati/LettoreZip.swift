import Compression
import Foundation

// MARK: - CRC32

/// CRC32 dei file zip (polinomio 0xEDB88320, lo stesso di zlib), scritto a mano: nell'SDK non c'è un modulo Swift
/// `zlib` senza un target di sistema. Lo usano `ScrittoreZip` (per scrivere le voci) e `LettoreZip` (per verificare
/// ogni voce estratta).
struct CRC32 {
    /// Tabella dei 256 resti, calcolata una volta sola.
    static let tabella: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    private var stato: UInt32 = 0xFFFF_FFFF

    /// Il CRC dei byte passati finora.
    var valore: UInt32 { stato ^ 0xFFFF_FFFF }

    mutating func aggiorna(_ byte: UnsafeBufferPointer<UInt8>) {
        var c = stato
        CRC32.tabella.withUnsafeBufferPointer { t in
            for b in byte { c = t[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        }
        stato = c
    }

    mutating func aggiorna(_ dati: Data) {
        dati.withUnsafeBytes { grezzo in aggiorna(grezzo.bindMemory(to: UInt8.self)) }
    }

    /// Il CRC di un blocco di byte intero.
    static func di(_ dati: Data) -> UInt32 {
        var c = CRC32()
        c.aggiorna(dati)
        return c.valore
    }
}

// MARK: - Errori

enum ErroreZip: LocalizedError {
    /// Il file non è uno zip o è troncato.
    case nonValido(String)
    /// Uno zip che Prisma non sa leggere (metodo di compressione, voce cifrata, archivio in più parti).
    case nonSupportato(String)
    /// Un percorso assoluto o con «..»: estrarlo scriverebbe fuori dalla cartella scelta.
    case percorsoNonSicuro(String)
    /// La voce estratta non ha il CRC o la dimensione dichiarati: zip danneggiato.
    case controlloFallito(String)
    /// Troppo grande per uno zip senza Zip64 (solo in scrittura).
    case troppoGrande(String)

    var errorDescription: String? {
        switch self {
        case .nonValido(let m): return "Lo zip non è leggibile: \(m)"
        case .nonSupportato(let m): return "Lo zip usa un formato che Prisma non legge: \(m)"
        case .percorsoNonSicuro(let n): return "Lo zip contiene un percorso non sicuro: «\(n)»"
        case .controlloFallito(let n): return "Lo zip è danneggiato: «\(n)» non supera il controllo"
        case .troppoGrande(let m): return "Il file è troppo grande per lo zip: \(m)"
        }
    }
}

// MARK: - Lettore

/// Lettore di file zip scritto con Foundation e il framework Compression, senza `Process` né dipendenze esterne:
/// apre su iPhone e iPad i backup creati sul Mac con `ditto -c -k --sequesterRsrc --keepParent` e i fogli .xlsx.
/// - Voci memorizzate (metodo 0) e deflate (metodo 8, `COMPRESSION_ZLIB` = deflate grezzo).
/// - Dimensioni, CRC e posizioni dalla directory centrale: ditto scrive i descrittori di dati (bit 3), quindi le
///   intestazioni locali non hanno le dimensioni. Zip64 letto se presente.
/// - Salta `__MACOSX/` e i file `._*` (risorse ed attributi estesi messi a parte da `--sequesterRsrc`) e i
///   collegamenti simbolici.
/// - Rifiuta i percorsi assoluti o con «..» prima di scrivere qualunque file.
/// - Un file alla volta, a pezzi da 64 KB (memoria bassa anche sul telefono); ogni voce si verifica con il CRC32.
enum LettoreZip {
    /// Pezzo di lettura e di scrittura.
    static let pezzo = 64 * 1024

    /// Una voce della directory centrale.
    struct Voce {
        let nome: String
        let metodo: UInt16
        let flag: UInt16
        let crc: UInt32
        let compressa: UInt64
        let dimensione: UInt64
        let inizioIntestazione: UInt64
        let creatoDa: UInt16
        let attributiEsterni: UInt32

        var cartella: Bool { nome.hasSuffix("/") }
        /// Collegamento simbolico scritto da un sistema Unix (tipo del file negli attributi esterni).
        var collegamento: Bool { (creatoDa >> 8) == 3 && ((attributiEsterni >> 16) & 0o170000) == 0o120000 }
    }

    /// Estrae tutto lo zip `zip` dentro la cartella `destinazione` (creata se manca). Le voci dello zip mantengono i
    /// loro percorsi (un backup di ditto con `--keepParent` dà quindi `destinazione/Prisma/…`).
    /// Se una voce non supera il controllo l'errore arriva subito; i file già estratti restano (chi chiama cancella
    /// la cartella, come fa `GestoreBackup`).
    static func estrai(_ zip: URL, in destinazione: URL) throws {
        let fm = FileManager.default
        let h: FileHandle
        do { h = try FileHandle(forReadingFrom: zip) } catch { throw ErroreZip.nonValido(error.localizedDescription) }
        defer { try? h.close() }
        let (voci, fineDati) = try directoryCentrale(h)
        // Prima tutti i percorsi: un solo percorso non sicuro ferma l'estrazione prima di scrivere qualunque file
        var daEstrarre: [(Voce, String)] = []
        for v in voci {
            guard let relativo = try percorsoSicuro(v.nome), !v.collegamento else { continue }
            daEstrarre.append((v, relativo))
        }
        try fm.createDirectory(at: destinazione, withIntermediateDirectories: true)
        for (v, relativo) in daEstrarre {
            if v.cartella {
                try fm.createDirectory(at: destinazione.appendingPathComponent(relativo, isDirectory: true), withIntermediateDirectories: true)
                continue
            }
            let url = destinazione.appendingPathComponent(relativo)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: url)
            guard fm.createFile(atPath: url.path, contents: nil) else {
                throw ErroreZip.nonValido("non riesco a creare «\(relativo)»")
            }
            do {
                let uscita = try FileHandle(forWritingTo: url)
                defer { try? uscita.close() }
                try leggi(v, da: h, fineDati: fineDati) { byte in
                    try uscita.write(contentsOf: Data(buffer: byte))
                }
            } catch {
                // Niente file a metà
                try? fm.removeItem(at: url)
                throw error
            }
        }
    }

    /// Il contenuto di una sola voce (per nome esatto, per esempio «xl/workbook.xml»), in memoria.
    /// nil se la voce non c'è; un errore se lo zip non si legge o la voce supera `massimo` byte.
    static func dati(_ zip: URL, voce nome: String, massimo: Int = 256 * 1024 * 1024) throws -> Data? {
        let h: FileHandle
        do { h = try FileHandle(forReadingFrom: zip) } catch { throw ErroreZip.nonValido(error.localizedDescription) }
        defer { try? h.close() }
        let (voci, fineDati) = try directoryCentrale(h)
        guard let v = voci.first(where: { $0.nome == nome && !$0.cartella }) else { return nil }
        guard v.dimensione <= UInt64(massimo) else { throw ErroreZip.troppoGrande("«\(nome)» supera \(massimo) byte") }
        var risultato = Data(capacity: Int(v.dimensione))
        try leggi(v, da: h, fineDati: fineDati) { byte in risultato.append(byte) }
        return risultato
    }

    /// I nomi delle voci (cartelle comprese, nell'ordine dello zip).
    static func nomi(_ zip: URL) throws -> [String] {
        let h: FileHandle
        do { h = try FileHandle(forReadingFrom: zip) } catch { throw ErroreZip.nonValido(error.localizedDescription) }
        defer { try? h.close() }
        return try directoryCentrale(h).voci.map(\.nome)
    }

    /// Il percorso relativo in cui estrarre la voce `nome`; nil per le voci da saltare (`__MACOSX/`, `._*`, vuote).
    /// Un percorso assoluto o con «..» è un errore.
    static func percorsoSicuro(_ nome: String) throws -> String? {
        guard !nome.contains("\0"), !nome.hasPrefix("/") else { throw ErroreZip.percorsoNonSicuro(nome) }
        let componenti = nome.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !componenti.contains("..") else { throw ErroreZip.percorsoNonSicuro(nome) }
        let pulite = componenti.filter { $0 != "." }
        guard let ultima = pulite.last, pulite.first != "__MACOSX", !ultima.hasPrefix("._") else { return nil }
        return pulite.joined(separator: "/")
    }

    // MARK: Directory centrale

    /// Le voci della directory centrale e il byte dove finiscono i dati delle voci (inizio della directory).
    static func directoryCentrale(_ h: FileHandle) throws -> (voci: [Voce], fineDati: UInt64) {
        let lunghezza = try h.seekToEnd()
        guard lunghezza >= 22 else { throw ErroreZip.nonValido("file troppo corto") }
        // Fine della directory centrale: 22 byte più un commento fino a 64 KB, più il localizzatore Zip64
        let coda = min(lunghezza, UInt64(22 + 65_535 + 20))
        try h.seek(toOffset: lunghezza - coda)
        let fine = [UInt8](try h.read(upToCount: Int(coda)) ?? Data())
        guard fine.count >= 22,
              let i = stride(from: fine.count - 22, through: 0, by: -1).first(where: { u32(fine, $0) == 0x0605_4B50 }) else {
            throw ErroreZip.nonValido("manca la directory centrale")
        }
        var totale = UInt64(u16(fine, i + 10))
        var dimensioneCD = UInt64(u32(fine, i + 12))
        var inizioCD = UInt64(u32(fine, i + 16))
        let disco = u16(fine, i + 4), discoCD = u16(fine, i + 6)
        if totale == 0xFFFF || dimensioneCD == 0xFFFF_FFFF || inizioCD == 0xFFFF_FFFF {
            // Zip64: il localizzatore sta subito prima della fine della directory centrale
            guard i >= 20, u32(fine, i - 20) == 0x0706_4B50 else { throw ErroreZip.nonValido("Zip64 senza localizzatore") }
            let posizione64 = u64(fine, i - 20 + 8)
            guard posizione64 + 56 <= lunghezza else { throw ErroreZip.nonValido("Zip64 fuori dal file") }
            try h.seek(toOffset: posizione64)
            let fine64 = [UInt8](try h.read(upToCount: 56) ?? Data())
            guard fine64.count == 56, u32(fine64, 0) == 0x0606_4B50 else { throw ErroreZip.nonValido("Zip64 non valido") }
            guard u32(fine64, 16) == 0, u32(fine64, 20) == 0 else { throw ErroreZip.nonSupportato("zip in più parti") }
            totale = u64(fine64, 32)
            dimensioneCD = u64(fine64, 40)
            inizioCD = u64(fine64, 48)
        } else {
            guard disco == 0, discoCD == 0 else { throw ErroreZip.nonSupportato("zip in più parti") }
        }
        guard inizioCD + dimensioneCD <= lunghezza, dimensioneCD <= UInt64(Int32.max) else {
            throw ErroreZip.nonValido("directory centrale fuori dal file")
        }
        try h.seek(toOffset: inizioCD)
        let cd = [UInt8](try h.read(upToCount: Int(dimensioneCD)) ?? Data())
        guard cd.count == Int(dimensioneCD) else { throw ErroreZip.nonValido("directory centrale troncata") }

        var voci: [Voce] = []
        voci.reserveCapacity(Int(min(totale, 100_000)))
        var p = 0
        for _ in 0..<totale {
            guard p + 46 <= cd.count, u32(cd, p) == 0x0201_4B50 else { throw ErroreZip.nonValido("voce della directory centrale non valida") }
            let creatoDa = u16(cd, p + 4)
            let flag = u16(cd, p + 8)
            let metodo = u16(cd, p + 10)
            let crc = u32(cd, p + 16)
            var compressa = UInt64(u32(cd, p + 20))
            var dimensione = UInt64(u32(cd, p + 24))
            let lungNome = Int(u16(cd, p + 28)), lungExtra = Int(u16(cd, p + 30)), lungCommento = Int(u16(cd, p + 32))
            let esterni = u32(cd, p + 38)
            var inizio = UInt64(u32(cd, p + 42))
            let inizioNome = p + 46
            guard inizioNome + lungNome + lungExtra + lungCommento <= cd.count else { throw ErroreZip.nonValido("voce troncata") }
            let byteNome = Array(cd[inizioNome..<inizioNome + lungNome])
            // Nomi in UTF-8 (bit 11, o comunque validi come UTF-8: ditto li scrive così); altrimenti Latin-1
            let nome = String(bytes: byteNome, encoding: .utf8) ?? String(bytes: byteNome, encoding: .isoLatin1) ?? ""
            // Campo Zip64 (0x0001): solo i valori saturati, in quest'ordine
            var e = inizioNome + lungNome
            let fineExtra = e + lungExtra
            while e + 4 <= fineExtra {
                let id = u16(cd, e), lung = Int(u16(cd, e + 2))
                guard e + 4 + lung <= fineExtra else { break }
                if id == 0x0001 {
                    var q = e + 4
                    if dimensione == 0xFFFF_FFFF, q + 8 <= e + 4 + lung { dimensione = u64(cd, q); q += 8 }
                    if compressa == 0xFFFF_FFFF, q + 8 <= e + 4 + lung { compressa = u64(cd, q); q += 8 }
                    if inizio == 0xFFFF_FFFF, q + 8 <= e + 4 + lung { inizio = u64(cd, q); q += 8 }
                }
                e += 4 + lung
            }
            voci.append(Voce(nome: nome, metodo: metodo, flag: flag, crc: crc, compressa: compressa, dimensione: dimensione,
                             inizioIntestazione: inizio, creatoDa: creatoDa, attributiEsterni: esterni))
            p = fineExtra + lungCommento
        }
        return (voci, inizioCD)
    }

    // MARK: Lettura di una voce

    /// Legge la voce `v` e ne consegna il contenuto a pezzi; alla fine verifica dimensione e CRC32.
    private static func leggi(_ v: Voce, da h: FileHandle, fineDati: UInt64,
                              consegna: @escaping (UnsafeBufferPointer<UInt8>) throws -> Void) throws {
        guard v.flag & 0x0001 == 0 else { throw ErroreZip.nonSupportato("«\(v.nome)» è cifrata") }
        guard v.metodo == 0 || v.metodo == 8 else { throw ErroreZip.nonSupportato("metodo \(v.metodo) per «\(v.nome)»") }
        // L'intestazione locale: nome ed extra possono essere diversi da quelli della directory centrale
        guard v.inizioIntestazione + 30 <= fineDati else { throw ErroreZip.nonValido("«\(v.nome)» fuori dal file") }
        try h.seek(toOffset: v.inizioIntestazione)
        let locale = [UInt8](try h.read(upToCount: 30) ?? Data())
        guard locale.count == 30, u32(locale, 0) == 0x0403_4B50 else { throw ErroreZip.nonValido("intestazione di «\(v.nome)» non valida") }
        let inizioDati = v.inizioIntestazione + 30 + UInt64(u16(locale, 26)) + UInt64(u16(locale, 28))
        guard inizioDati + v.compressa <= fineDati else { throw ErroreZip.nonValido("«\(v.nome)» troncata") }
        try h.seek(toOffset: inizioDati)

        // Voce vuota (anche deflate senza byte, come può scriverla ditto): niente da decomprimere
        if v.compressa == 0 {
            guard v.dimensione == 0, v.crc == 0 else { throw ErroreZip.controlloFallito(v.nome) }
            return
        }
        var crc = CRC32()
        var scritti: UInt64 = 0
        let conta: (UnsafeBufferPointer<UInt8>) throws -> Void = { byte in
            scritti += UInt64(byte.count)
            // Più byte di quelli dichiarati: zip danneggiato (o costruito per riempire il disco)
            guard scritti <= v.dimensione else { throw ErroreZip.controlloFallito(v.nome) }
            crc.aggiorna(byte)
            try consegna(byte)
        }
        if v.metodo == 0 {
            guard v.compressa == v.dimensione else { throw ErroreZip.controlloFallito(v.nome) }
            var restanti = v.compressa
            while restanti > 0 {
                let blocco = try h.read(upToCount: Int(min(restanti, UInt64(pezzo)))) ?? Data()
                guard !blocco.isEmpty else { throw ErroreZip.nonValido("«\(v.nome)» troncata") }
                restanti -= UInt64(blocco.count)
                try blocco.withUnsafeBytes { try conta($0.bindMemory(to: UInt8.self)) }
            }
        } else {
            try decomprimi(da: h, byte: v.compressa, nome: v.nome, consegna: conta)
        }
        guard scritti == v.dimensione, crc.valore == v.crc else { throw ErroreZip.controlloFallito(v.nome) }
    }

    /// Deflate grezzo a pezzi da 64 KB con `compression_stream` (`COMPRESSION_ZLIB` non vuole l'intestazione zlib).
    private static func decomprimi(da h: FileHandle, byte: UInt64, nome: String,
                                   consegna: (UnsafeBufferPointer<UInt8>) throws -> Void) throws {
        let flusso = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { flusso.deallocate() }
        guard compression_stream_init(flusso, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            throw ErroreZip.nonValido("decompressione non disponibile")
        }
        defer { compression_stream_destroy(flusso) }
        let uscita = UnsafeMutablePointer<UInt8>.allocate(capacity: pezzo)
        defer { uscita.deallocate() }

        var restanti = byte
        var finito = false
        while !finito {
            let blocco: Data
            if restanti > 0 {
                blocco = try h.read(upToCount: Int(min(restanti, UInt64(pezzo)))) ?? Data()
                guard !blocco.isEmpty else { throw ErroreZip.nonValido("«\(nome)» troncata") }
                restanti -= UInt64(blocco.count)
            } else {
                blocco = Data()
            }
            let ultimo = restanti == 0
            try blocco.withUnsafeBytes { (grezzo: UnsafeRawBufferPointer) in
                // Con un blocco vuoto il puntatore non si legge (src_size = 0), ma deve esserci
                flusso.pointee.src_ptr = grezzo.bindMemory(to: UInt8.self).baseAddress ?? UnsafePointer(uscita)
                flusso.pointee.src_size = grezzo.count
                repeat {
                    flusso.pointee.dst_ptr = uscita
                    flusso.pointee.dst_size = pezzo
                    let stato = compression_stream_process(flusso, ultimo ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0)
                    let prodotti = pezzo - flusso.pointee.dst_size
                    if prodotti > 0 { try consegna(UnsafeBufferPointer(start: uscita, count: prodotti)) }
                    if stato == COMPRESSION_STATUS_END {
                        finito = true
                    } else if stato != COMPRESSION_STATUS_OK {
                        throw ErroreZip.controlloFallito(nome)
                    }
                    // Si continua finché resta ingresso o l'uscita si è riempita (ce n'è ancora)
                } while !finito && (flusso.pointee.src_size > 0 || flusso.pointee.dst_size == 0)
            }
            // Tutto l'ingresso dato ma il flusso deflate non è finito: dati compressi incompleti
            if ultimo && !finito { throw ErroreZip.controlloFallito(nome) }
        }
    }

    // MARK: Numeri little-endian

    static func u16(_ b: [UInt8], _ i: Int) -> UInt16 {
        UInt16(b[i]) | UInt16(b[i + 1]) << 8
    }

    static func u32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24
    }

    static func u64(_ b: [UInt8], _ i: Int) -> UInt64 {
        UInt64(u32(b, i)) | UInt64(u32(b, i + 4)) << 32
    }
}
