import Foundation

/// Uno spazio libero trovato in agenda.
struct SpazioLibero: Equatable {
    let inizio: Date
    let fine: Date
    /// Giorni di lavoro guardati e trovati pieni prima di questo (i festivi e i giorni non lavorativi non contano).
    let giorniPieni: Int
}

/// Dove mettere un incontro: il primo spazio libero vero negli orari di lavoro, senza sovrapporsi agli
/// appuntamenti di nessun cliente (con il margine scelto), saltando weekend, festività nazionali e i giorni
/// che hanno già abbastanza riesami. Più il canale del riesame, la posizione di cui parlare e le note.
///
/// Perché il canale conta. Il riesame del canale Alleanza riguarda prodotti d'investimento assicurativi
/// distribuiti per Alleanza: valgono le regole IDD (Dir. (UE) 2016/97, art. 30; art. 121-septies del Codice
/// delle assicurazioni private, D.Lgs. 209/2005; Reg. IVASS 40/2018) e, se si è promessa una valutazione
/// periodica dell'adeguatezza, la relazione periodica ne contiene l'aggiornamento. Per la consulenza
/// indipendente valgono MiFID II (art. 25 par. 6) e il Reg. Delegato (UE) 2017/565 (art. 54) per la
/// valutazione periodica dell'adeguatezza. In tutti e due i casi l'incontro è anche il momento del controllo
/// costante antiriciclaggio (D.Lgs. 231/2007, art. 18, comma 1, lett. d): l'aggiornamento dei dati del cliente.
/// Di qui la regola: documenti e firme restano separati per canale e l'etichetta del canale è sempre visibile.
/// I dodici mesi del riesame (`MotoreRiesame.mesiRiesame`) sono una scelta di buona prassi di Prisma, non un
/// obbligo di legge.
///
/// Solo Foundation e i modelli: nessuna dipendenza da `StatoShell` né da SwiftUI.
enum MotorePianificazione {
    /// Gli inizi si propongono ogni mezz'ora (09:00, 09:30…), come il modulo dell'agenda.
    static let passoMinuti = 30
    /// Quanto avanti si cerca: otto settimane, poi «nessuno spazio libero».
    static let giorniRicerca = 56
    /// Il riesame annuale dura un'ora (come la bozza di sempre: lo controlla anche --prova-eve).
    static let durataRiesame = 60
    /// Si comincia a cercare dal giorno dopo: il tempo di preparare il prospetto del riesame e di avvisare il cliente.
    static let preavvisoGiorni = 1
    /// Dal 2026 il 4 ottobre torna festività nazionale (vedi `festivita`).
    static let annoSanFrancesco = 2026

    private static let calendarioItaliano: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "it_IT")
        c.firstWeekday = 2
        return c
    }()

    /// Gregoriano, in italiano, settimana da lunedì, fuso del Mac (come `CalendarioAgenda.cal`).
    static var calendario: Calendar { calendarioItaliano }

    // MARK: - Festività nazionali

    // Fonti delle festività nazionali:
    // - L. 27 maggio 1949, n. 260 («Disposizioni in materia di ricorrenze festive»);
    // - L. 5 marzo 1977, n. 54, che sopprime alcune festività;
    // - D.P.R. 28 dicembre 1985, n. 792, che ripristina l'Epifania;
    // - L. 20 novembre 2000, n. 336, che ripristina il 2 giugno;
    // - 4 ottobre (San Francesco d'Assisi e Santa Caterina da Siena): legge del 2025, festività nazionale dal 2026.
    // Il santo patrono e le ferie non sono previsti: si bloccano con un appuntamento «Ferie» o «Patrono».

    /// Pasqua (calendario gregoriano, algoritmo anonimo di Meeus/Jones/Butcher): (mese, giorno).
    static func pasqua(_ anno: Int) -> (mese: Int, giorno: Int) {
        let a = anno % 19, b = anno / 100, c = anno % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let n = h + l - 7 * m + 114
        return (mese: n / 31, giorno: n % 31 + 1)
    }

    /// Le festività dell'anno come mese × 100 + giorno (1 gennaio = 101).
    private static func chiaviFestive(_ anno: Int) -> Set<Int> {
        var chiavi: Set<Int> = [101, 106, 425, 501, 602, 815, 1101, 1208, 1225, 1226]
        if anno >= annoSanFrancesco { chiavi.insert(1004) }
        let p = pasqua(anno)
        chiavi.insert(p.mese * 100 + p.giorno)
        // Lunedì dell'Angelo: il giorno dopo Pasqua (Pasqua va dal 22 marzo al 25 aprile: solo il 31 marzo cambia mese)
        chiavi.insert(p.mese == 3 && p.giorno == 31 ? 401 : p.mese * 100 + p.giorno + 1)
        return chiavi
    }

    /// Le festività nazionali dell'anno, a mezzanotte, in ordine.
    static func festivita(_ anno: Int, cal: Calendar = calendario) -> [Date] {
        chiaviFestive(anno).sorted().compactMap { k in
            cal.date(from: DateComponents(year: anno, month: k / 100, day: k % 100))
        }
    }

    static func festivo(_ giorno: Date, cal: Calendar = calendario) -> Bool {
        let c = cal.dateComponents([.year, .month, .day], from: giorno)
        guard let a = c.year, let m = c.month, let g = c.day else { return false }
        return chiaviFestive(a).contains(m * 100 + g)
    }

    /// Giorno della settimana di lavoro e (se `orari.festivi`) non festivo.
    static func lavorativo(_ giorno: Date, orari: OrariLavoro, cal: Calendar = calendario) -> Bool {
        guard orari.giorni.contains(cal.component(.weekday, from: giorno)) else { return false }
        return !(orari.festivi && festivo(giorno, cal: cal))
    }

    // MARK: - Spazio libero e sovrapposizioni

    /// Il momento `minuti` dopo la mezzanotte del giorno (con l'ora legale); da 24:00 in poi il giorno dopo.
    static func orario(_ giorno: Date, minuti: Int, cal: Calendar = calendario) -> Date {
        let inizio = cal.startOfDay(for: giorno)
        let giornata = 24 * 60
        let avanti = max(0, minuti) / giornata
        let resto = max(0, minuti) % giornata
        let base = avanti == 0 ? inizio : (cal.date(byAdding: .day, value: avanti, to: inizio) ?? inizio)
        return cal.date(bySettingHour: resto / 60, minute: resto % 60, second: 0, of: base)
            ?? base.addingTimeInterval(TimeInterval(resto * 60))
    }

    /// Arrotonda all'inizio successivo sulla griglia di `passo` minuti dalla mezzanotte (10:15 → 10:30;
    /// 10:00 resta 10:00; 10:00:30 → 10:30); oltre le 24 va alla mezzanotte dopo.
    static func allineato(_ d: Date, passo: Int = passoMinuti, cal: Calendar = calendario) -> Date {
        let giorno = cal.startOfDay(for: d)
        let c = cal.dateComponents([.hour, .minute], from: d)
        let minuti = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let p = max(1, passo)
        // Secondi o frazioni oltre il minuto: si va al passo dopo
        let esatto = d.timeIntervalSince(orario(giorno, minuti: minuti, cal: cal)) < 0.001
        let allineati = esatto && minuti % p == 0 ? minuti : (minuti / p + 1) * p
        return orario(giorno, minuti: allineati, cal: cal)
    }

    /// Il primo spazio libero di `durata` minuti da `da` in avanti, o nil se in `giorni` giorni non ce n'è.
    static func primoSpazio(durata: Int, da: Date, appuntamenti: [Appuntamento], orari: OrariLavoro,
                            cal: Calendar = calendario, giorni: Int = giorniRicerca) -> SpazioLibero? {
        let fasce = orari.fasce
        guard !fasce.isEmpty, durata > 0, giorni > 0 else { return nil }
        let primoGiorno = cal.startOfDay(for: da)
        guard let fineFinestra = cal.date(byAdding: .day, value: giorni, to: primoGiorno) else { return nil }
        let margine = TimeInterval(max(0, orari.margineMinuti) * 60)
        let lunghezza = TimeInterval(durata * 60)
        // Tutti gli appuntamenti occupano il tempo (di qualunque cliente e stato, anche conclusi), allargati del
        // margine; si tengono solo quelli che toccano la finestra, così il calcolo è una sola passata
        let vicini = appuntamenti.filter {
            $0.inizio.addingTimeInterval(-margine) < fineFinestra && primoGiorno < $0.fine.addingTimeInterval(margine)
        }
        let occupati = vicini.map { (inizio: $0.inizio.addingTimeInterval(-margine), fine: $0.fine.addingTimeInterval(margine)) }
        // I riesami già in agenda per giorno: oltre il limite il giorno è pieno
        var riesami: [Date: Int] = [:]
        if orari.riesamiAlGiorno > 0 {
            for a in vicini where a.tipo == .revisione { riesami[cal.startOfDay(for: a.inizio), default: 0] += 1 }
        }
        var pieni = 0
        for n in 0..<giorni {
            guard let g = cal.date(byAdding: .day, value: n, to: primoGiorno) else { continue }
            let giorno = cal.startOfDay(for: g)
            // Weekend, giorni non lavorativi e festivi si saltano e non contano come pieni
            guard lavorativo(giorno, orari: orari, cal: cal) else { continue }
            if orari.riesamiAlGiorno > 0, (riesami[giorno] ?? 0) >= orari.riesamiAlGiorno {
                pieni += 1
                continue
            }
            // Gli occupati che toccano questo giorno (le fasce non vanno oltre la mezzanotte dopo)
            let domani = orario(giorno, minuti: 24 * 60, cal: cal)
            let delGiorno = occupati.filter { $0.inizio < domani && giorno < $0.fine }
            for f in fasce {
                var t = orario(giorno, minuti: f.inizio, cal: cal)
                let fineFascia = orario(giorno, minuti: f.fine, cal: cal)
                if t < da { t = allineato(da, cal: cal) }
                while t.addingTimeInterval(lunghezza) <= fineFascia {
                    let candidato = (inizio: t, fine: t.addingTimeInterval(lunghezza))
                    // Confronti stretti: due intervalli che si toccano soltanto non si sovrappongono
                    let toccati = delGiorno.filter { $0.inizio < candidato.fine && candidato.inizio < $0.fine }
                    if toccati.isEmpty {
                        return SpazioLibero(inizio: candidato.inizio, fine: candidato.fine, giorniPieni: pieni)
                    }
                    let prossimo = allineato(toccati.map { $0.fine }.max() ?? candidato.fine, cal: cal)
                    // Per sicurezza: il cursore va sempre avanti
                    guard prossimo > t else { break }
                    t = prossimo
                }
            }
            pieni += 1
        }
        return nil
    }

    /// Gli appuntamenti (diversi da `a`, per id) il cui orario si accavalla con quello di `a`, allargati di
    /// `margine` minuti; in ordine d'inizio. Uno che finisce quando l'altro comincia non si sovrappone.
    static func sovrapposti(_ a: Appuntamento, in elenco: [Appuntamento], margine: Int = 0) -> [Appuntamento] {
        let m = TimeInterval(max(0, margine) * 60)
        let inizio = a.inizio.addingTimeInterval(-m)
        let fine = a.fine.addingTimeInterval(m)
        return elenco
            .filter { $0.id != a.id && $0.inizio < fine && inizio < $0.fine }
            .sorted { $0.inizio < $1.inizio }
    }

    /// L'appuntamento cade fuori dagli orari di lavoro: giorno non lavorativo o festivo, oppure non sta
    /// tutto dentro una fascia (stesso giorno, inizio e fine compresi).
    static func fuoriOrario(_ a: Appuntamento, orari: OrariLavoro, cal: Calendar = calendario) -> Bool {
        let giorno = cal.startOfDay(for: a.inizio)
        guard lavorativo(giorno, orari: orari, cal: cal) else { return true }
        return !orari.fasce.contains { f in
            orario(giorno, minuti: f.inizio, cal: cal) <= a.inizio && a.fine <= orario(giorno, minuti: f.fine, cal: cal)
        }
    }

    // MARK: - Note dell'appuntamento: l'ordine del giorno

    /// Le note del riesame: l'ordine del giorno (stesso formato di `MotoreRiesame.agenda`, la prima riga è
    /// «Ordine del giorno:»), con il canale accanto ai punti quando il cliente segue tutti e due i canali,
    /// poi il canale dell'incontro e l'ultimo contatto.
    static func noteRiesame(punti: [Riesame.Punto], canali: [Canale], canale: Canale?,
                            ultimoContatto: Date?, dovutoDal: Date?, oggi: Date, massimo: Int = 8) -> String {
        var righe = ["Ordine del giorno:"]
        let dueCanali = canale == nil && canali.count == 2
        if punti.isEmpty {
            righe.append("1. Fare il punto su posizioni, obiettivi e famiglia")
        } else {
            for (i, p) in punti.prefix(max(0, massimo)).enumerated() {
                let etichetta = dueCanali ? p.canale.map { " (\($0.nomeBreve))" } ?? "" : ""
                righe.append("\(i + 1). \(p.titolo)\(etichetta)")
            }
            if punti.count > massimo {
                righe.append("…e altri \(punti.count - massimo) punti nel prospetto del riesame.")
            }
        }
        righe.append("")
        switch canale {
        case .alleanza?:
            righe.append("Canale: Alleanza Assicurazioni.")
        case .indipendente?:
            righe.append("Canale: Denis Vicenzoni · Consulenza finanziaria.")
        case nil:
            if canali.count == 2 {
                righe.append("Canale: Alleanza e indipendente. Proposte, documenti e firme restano distinti per canale.")
            }
        }
        let data: (Date) -> String = { Formati.dataEstesa.string(from: $0) }
        if let u = ultimoContatto {
            if let d = dovutoDal {
                righe.append("Ultimo contatto il \(data(u)): riesame \(d <= oggi ? "scaduto" : "dovuto") dal \(data(d)).")
            } else {
                righe.append("Ultimo contatto il \(data(u)).")
            }
        } else {
            righe.append("Nessun incontro registrato in Prisma: è il primo riesame.")
        }
        return righe.joined(separator: "\n")
    }

    // MARK: - Canale del riesame

    /// I canali del cliente presi dalle posizioni: in essere e proposte ancora aperte (non rifiutate; una
    /// rimandata resta aperta), nell'ordine di `Canale.allCases`. Le posizioni chiuse non contano.
    static func canali(_ posizioni: [Posizione]) -> [Canale] {
        let presenti = Set(posizioni.filter { p in
            p.stato == .inEssere || (p.stato == .proposta && p.esito != .rifiutata)
        }.map(\.canale))
        return Canale.allCases.filter { presenti.contains($0) }
    }

    /// Il canale dell'incontro: quello unico delle posizioni; con tutti e due nil («entrambi», come vuole
    /// `Appuntamento.canale`); senza posizioni, il canale del cliente se ne ha uno solo (`Cliente.canali`).
    static func canale(_ posizioni: [Posizione], cliente: Cliente?) -> Canale? {
        let c = canali(posizioni)
        if c.count == 1 { return c[0] }
        if c.count > 1 { return nil }
        guard let cliente else { return nil }
        let suoi = Canale.allCases.filter { cliente.canali.contains($0) }
        return suoi.count == 1 ? suoi[0] : nil
    }

    // MARK: - Posizione di cui si parla

    /// La scadenza più vicina tra quelle del riesame che cade entro `MotoreRiesame.mesiScadenzaVicina` mesi
    /// (polizza da rinnovare, capitale da reinvestire), o nil. `r.scadenze` è già in ordine di scadenza.
    static func posizioneDaDiscutere(_ r: Riesame) -> String? {
        let cal = calendario
        let inizio = cal.startOfDay(for: r.oggi)
        guard let limite = cal.date(byAdding: .month, value: MotoreRiesame.mesiScadenzaVicina, to: inizio) else { return nil }
        return r.scadenze.first { p in p.scadenza.map { $0 < limite } ?? false }?.id
    }

    // MARK: - Riesami del mese

    /// I mesi da chiedere a `MotoreRiesame.dovuti` perché l'orizzonte arrivi alla fine del mese mostrato:
    /// mesi tra il mese di oggi e quello mostrato, più uno (mai meno di 1).
    static func mesiOrizzonte(mese: Date, oggi: Date, cal: Calendar = calendario) -> Int {
        let a = cal.dateComponents([.year, .month], from: oggi)
        let b = cal.dateComponents([.year, .month], from: mese)
        let distanza = ((b.year ?? 0) - (a.year ?? 0)) * 12 + ((b.month ?? 0) - (a.month ?? 0))
        return max(1, distanza + 1)
    }

    /// I riesami da fissare nel mese mostrato in Agenda. Mese passato: nessuno. Mese corrente: gli scaduti,
    /// chi non è mai stato incontrato e i dovuti entro la fine del mese. Mese futuro: solo i dovuti in quel mese.
    /// L'ordine resta quello di `MotoreRiesame.dovuti` (prima chi non è mai stato incontrato, poi chi aspetta da più tempo).
    static func delMese(_ dovuti: [RiesameDovuto], mese: Date, oggi: Date, cal: Calendar = calendario) -> [RiesameDovuto] {
        guard let mostrato = cal.dateInterval(of: .month, for: mese),
              let corrente = cal.dateInterval(of: .month, for: oggi) else { return [] }
        if mostrato.start < corrente.start { return [] }
        if mostrato.start == corrente.start {
            return dovuti.filter { d in d.dovutoDal.map { $0 < mostrato.end } ?? true }
        }
        return dovuti.filter { d in d.dovutoDal.map { $0 >= mostrato.start && $0 < mostrato.end } ?? false }
    }
}
