import Foundation

/// Una fascia dell'orario di lavoro, in minuti dalla mezzanotte (9:00 = 540, 18:30 = 1110).
struct FasciaOraria: Codable, Equatable, Hashable {
    var inizio: Int
    var fine: Int

    /// Dentro la giornata e con la fine dopo l'inizio.
    var valida: Bool { inizio >= 0 && fine <= 24 * 60 && inizio < fine }
}

/// Gli orari di lavoro del consulente (Impostazioni › Esperienza › Orari di lavoro): «Pianifica» cerca
/// lo spazio libero solo qui. Dalla versione 21 dell'archivio; letti con tolleranza (gli archivi di prima
/// non li hanno, un valore fuori scelta torna al predefinito).
struct OrariLavoro: Codable, Equatable {
    /// Giorni di lavoro come `Calendar.weekday` (1 = domenica … 7 = sabato), in ordine crescente.
    var giorni: [Int] = [2, 3, 4, 5, 6]
    var mattina = FasciaOraria(inizio: 9 * 60, fine: 13 * 60)
    var pomeriggio = FasciaOraria(inizio: 14 * 60 + 30, fine: 18 * 60 + 30)
    /// Spento: si lavora solo nella fascia del mattino (che può anche essere un orario continuato, 8:30-17:00).
    var pomeriggioAttivo = true
    /// Tempo libero lasciato prima e dopo ogni appuntamento esistente.
    var margineMinuti = 15
    /// Quanti riesami (appuntamenti di tipo Revisione periodica) al massimo in un giorno; 0 = senza limite.
    var riesamiAlGiorno = 2
    /// Salta le festività nazionali (vedi `MotorePianificazione.festivo`).
    var festivi = true

    static let margini = [0, 10, 15, 30]
    static let limitiRiesami = [1, 2, 3, 0]
    /// Le ore che si possono scegliere: dalle 7:00 alle 21:00, ogni mezz'ora.
    static let orariScelta: [Int] = Array(stride(from: 7 * 60, through: 21 * 60, by: 30))

    init() {}

    private enum CodingKeys: String, CodingKey {
        case giorni, mattina, pomeriggio, pomeriggioAttivo, margineMinuti, riesamiAlGiorno, festivi
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = OrariLavoro()
        // Con Swift 5 `try?` su un `decodeIfPresent` dà già un Optional semplice (SE-0230): basta `?? predefinito`
        let g = Array(Set(((try? c.decodeIfPresent([Int].self, forKey: .giorni)) ?? []).filter { (1...7).contains($0) })).sorted()
        giorni = g.isEmpty ? base.giorni : g
        let m = try? c.decodeIfPresent(FasciaOraria.self, forKey: .mattina)
        mattina = m.flatMap { $0.valida ? $0 : nil } ?? base.mattina
        let p = try? c.decodeIfPresent(FasciaOraria.self, forKey: .pomeriggio)
        pomeriggio = p.flatMap { $0.valida ? $0 : nil } ?? base.pomeriggio
        pomeriggioAttivo = (try? c.decodeIfPresent(Bool.self, forKey: .pomeriggioAttivo)) ?? true
        let mg = (try? c.decodeIfPresent(Int.self, forKey: .margineMinuti)) ?? base.margineMinuti
        margineMinuti = OrariLavoro.margini.contains(mg) ? mg : base.margineMinuti
        let r = (try? c.decodeIfPresent(Int.self, forKey: .riesamiAlGiorno)) ?? base.riesamiAlGiorno
        riesamiAlGiorno = OrariLavoro.limitiRiesami.contains(r) ? r : base.riesamiAlGiorno
        festivi = (try? c.decodeIfPresent(Bool.self, forKey: .festivi)) ?? true
    }

    /// Le fasce in cui cercare, in ordine; un pomeriggio che si accavalla alla mattina si unisce a lei.
    var fasce: [FasciaOraria] {
        guard mattina.valida else { return [] }
        guard pomeriggioAttivo, pomeriggio.valida else { return [mattina] }
        let (a, b) = mattina.inizio <= pomeriggio.inizio ? (mattina, pomeriggio) : (pomeriggio, mattina)
        if b.inizio <= a.fine { return [FasciaOraria(inizio: a.inizio, fine: max(a.fine, b.fine))] }
        return [a, b]
    }

    /// «09:00», «14:30».
    static func testoOra(_ minuti: Int) -> String { String(format: "%02d:%02d", minuti / 60, minuti % 60) }

    /// Nomi brevi dei giorni, indicizzati con `weekday − 1`.
    private static let nomiGiorni = ["dom", "lun", "mar", "mer", "gio", "ven", "sab"]

    /// «lun–ven, 09:00–13:00 e 14:30–18:30»; giorni non consecutivi: «lun, mer, ven, 08:30–17:00».
    var descrizione: String {
        let validi = giorni.filter { (1...7).contains($0) }.sorted()
        let nomi = validi.map { OrariLavoro.nomiGiorni[$0 - 1] }
        let consecutivi = validi.count >= 3 && zip(validi, validi.dropFirst()).allSatisfy { $1 == $0 + 1 }
        let testoGiorni = consecutivi ? "\(nomi[0])–\(nomi[nomi.count - 1])" : nomi.joined(separator: ", ")
        let testoFasce = fasce.map { "\(OrariLavoro.testoOra($0.inizio))–\(OrariLavoro.testoOra($0.fine))" }
            .joined(separator: " e ")
        return [testoGiorni, testoFasce].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
