import Foundation

/// Una scadenza fiscale del cliente legata alle sue posizioni.
struct ScadenzaFiscale: Identifiable {
    enum Tipo: String {
        case deduzione, nonDedotti, detrazione, bollo
    }

    let tipo: Tipo
    let data: Date
    let titolo: String
    let dettaglio: String
    /// Il beneficio (IRPEF risparmiata, detrazione) o l'importo dovuto (bollo).
    var importo: Double?

    var id: String { tipo.rawValue }
}

/// Il calendario fiscale di un cliente per l'anno in corso: quanto può ancora dedurre versando alla
/// previdenza entro il 31 dicembre, i contributi non dedotti da comunicare al fondo, la detrazione dei
/// premi assicurativi e il bollo dell'anno. Cifre dalle regole fiscali di Prisma (RegoleFiscali).
struct FineAnno: Identifiable {
    let cliente: Cliente
    let anno: Int
    /// Piani di previdenza complementare in essere.
    let piani: [Posizione]
    /// Contributi annui ai piani (dai versamenti periodici registrati).
    let contributi: Double
    /// Quanto si può ancora dedurre quest'anno, fino al limite.
    let spazio: Double
    let reddito: Double?
    let aliquota: Double?
    /// IRPEF risparmiata con i contributi di oggi e quella in più usando tutto lo spazio.
    let risparmioOggi: Double
    let risparmioPossibile: Double
    /// Contributi oltre il limite: non dedotti, da comunicare al fondo.
    let eccedenza: Double
    let detraibili: Double
    let bollo: Double
    let scadenze: [ScadenzaFiscale]

    var id: String { cliente.id }
    var detrazione: Double { detraibili * RegoleFiscali.detrazionePremi / 100 }
}

enum MotoreFineAnno {
    /// Le scadenze entro questi giorni sono vicine (notifiche, riesame).
    static let giorniVicini = 60

    static func calcola(cliente: Cliente, posizioni: [Posizione], oggi: Date = Date()) -> FineAnno {
        let cal = Calendar.current
        let anno = cal.component(.year, from: oggi)
        let fineAnno = cal.date(from: DateComponents(year: anno, month: 12, day: 31, hour: 12)) ?? oggi
        let dichiarazione = cal.date(from: DateComponents(year: anno + 1, month: 9, day: 30, hour: 12)) ?? oggi
        let euro: (Double) -> String = { CifreDoc.euroCentesimi($0) }
        let mie = posizioni.filter { $0.clienteId == cliente.id && $0.stato == .inEssere }

        let piani = mie.filter { $0.regime == .previdenza }
        let contributi = piani.reduce(0) { $0 + $1.premioAnnuo }
        let limite = RegoleFiscali.limiteDeducibilita
        let spazio = max(0, limite - contributi)
        let eccedenza = max(0, contributi - limite)
        let reddito = cliente.profilo.redditoLordoAnnuo
        let risparmioOggi = reddito.map { RegoleFiscali.risparmioDeduzione(reddito: $0, deduzione: min(contributi, limite)) } ?? 0
        let risparmioPieno = reddito.map { RegoleFiscali.risparmioDeduzione(reddito: $0, deduzione: limite) } ?? 0
        let detraibili = RegoleFiscali.premiDetraibili(mie.filter { $0.area == .protezione && !$0.scaduta })
        let bollo = mie.reduce(0) { $0 + MotoreFiscale.bolloAnnuo($1, valore: $1.valore) }

        var scadenze: [ScadenzaFiscale] = []
        if !piani.isEmpty, spazio >= 1 {
            let quanto = reddito.map { r in
                "un versamento aggiuntivo di \(euro(spazio)) entro il 31 dicembre farebbe risparmiare circa \(euro(risparmioPieno - risparmioOggi)) di IRPEF (aliquota marginale \(CifreDoc.condizione(RegoleFiscali.aliquotaMarginale(reddito: r))))."
            } ?? "manca il reddito nel profilo per stimare il risparmio d'imposta."
            scadenze.append(ScadenzaFiscale(tipo: .deduzione, data: fineAnno, titolo: "Versamenti deducibili entro il 31 dicembre",
                                            dettaglio: "Contributi dell'anno circa \(euro(contributi)) su \(euro(limite)) deducibili: " + quanto,
                                            importo: reddito == nil ? nil : risparmioPieno - risparmioOggi))
        }
        let dichiarati = piani.reduce(0) { $0 + ($1.contributiNonDedotti ?? 0) }
        if eccedenza >= 1 || dichiarati > 0 {
            let testo = eccedenza >= 1
                ? "I contributi superano il limite di circa \(euro(eccedenza)) l'anno: la parte non dedotta dell'anno scorso va comunicata al fondo entro il 31 dicembre, così alla prestazione non si tassa."
                : "Ci sono contributi non dedotti: quelli dell'anno scorso vanno comunicati al fondo entro il 31 dicembre, così alla prestazione non si tassano."
            scadenze.append(ScadenzaFiscale(tipo: .nonDedotti, data: fineAnno, titolo: "Contributi non dedotti da comunicare", dettaglio: testo))
        }
        if detraibili >= 1 {
            scadenze.append(ScadenzaFiscale(tipo: .detrazione, data: dichiarazione, titolo: "Detrazione dei premi nella dichiarazione",
                                            dettaglio: "Premi detraibili dell'anno circa \(euro(detraibili)): detrazione IRPEF del \(CifreDoc.condizione(RegoleFiscali.detrazionePremi)) di circa \(euro(detraibili * RegoleFiscali.detrazionePremi / 100)) nella dichiarazione del \(anno + 1). Premi pagati con mezzi tracciabili; conservare le quietanze.",
                                            importo: detraibili * RegoleFiscali.detrazionePremi / 100))
        }
        if bollo >= 1 {
            scadenze.append(ScadenzaFiscale(tipo: .bollo, data: fineAnno, titolo: "Bollo dell'anno",
                                            dettaglio: "Imposta di bollo sui prodotti finanziari di circa \(euro(bollo)): la addebita l'intermediario (nelle polizze si paga al riscatto).",
                                            importo: bollo))
        }
        scadenze.sort { $0.data < $1.data }

        return FineAnno(cliente: cliente, anno: anno, piani: piani, contributi: contributi, spazio: spazio, reddito: reddito,
                        aliquota: reddito.map { RegoleFiscali.aliquotaMarginale(reddito: $0) },
                        risparmioOggi: risparmioOggi, risparmioPossibile: max(0, risparmioPieno - risparmioOggi),
                        eccedenza: eccedenza, detraibili: detraibili, bollo: bollo, scadenze: scadenze)
    }

    /// I clienti con un piano di previdenza e ancora spazio deducibile quest'anno: prima chi risparmierebbe di più.
    static func conSpazio(clienti: [Cliente], posizioni: [Posizione], oggi: Date = Date()) -> [FineAnno] {
        let conPiani = Set(posizioni.filter { $0.stato == .inEssere && $0.regime == .previdenza }.map(\.clienteId))
        return clienti.filter { conPiani.contains($0.id) }
            .map { calcola(cliente: $0, posizioni: posizioni, oggi: oggi) }
            .filter { $0.spazio >= 1 }
            .sorted { $0.risparmioPossibile != $1.risparmioPossibile ? $0.risparmioPossibile > $1.risparmioPossibile : $0.spazio > $1.spazio }
    }

    /// true se mancano al massimo `giorniVicini` giorni.
    static func vicina(_ s: ScadenzaFiscale, oggi: Date = Date()) -> Bool {
        let giorni = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: oggi), to: s.data).day ?? 999
        return giorni >= 0 && giorni <= giorniVicini
    }
}
