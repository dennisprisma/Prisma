import Foundation

/// Prove del confronto «TFR in azienda o nel fondo» (giro 6, specifica 11 §8.1, casi T0–T8): regole del TFR,
/// le due strade con e senza contributi, aliquota indicata a mano, rendimento negativo, retribuzione nulla,
/// rendimento di pareggio, ipotesi dal dossier di Marco, lettura tollerante e testi.
/// I valori attesi vengono da `calcoli_tfr.py` (stesse formule). Chiamata da `ProvaCalcoli.esegui()`.
enum ProvaCalcoliTFR {
    static func esegui(_ verifica: VerificaCalcoli) {
        regole(verifica)
        soloTFR(verifica)
        conContributi(verifica)
        casiLimite(verifica)
        provaPareggio(verifica)
        dalCliente(verifica)
        lettura(verifica)
        testi(verifica)
    }

    // MARK: - Aiuti

    /// Tolleranze: importi al centesimo, percentuali a 1e−4, rendimenti di pareggio a 0,001.
    private static let tEuro = 0.01
    private static let tPercento = 1e-4
    private static let tPareggio = 0.001

    private static func ipotesi(retribuzione: Double, crescita: Double, anni: Int, inflazione: Double, rendimento: Double,
                                costo: Double, lavoratore: Double = 0, datore: Double = 0, partecipazione: Int = 0) -> IpotesiTFR {
        var i = IpotesiTFR()
        i.retribuzione = retribuzione
        i.crescitaReale = crescita
        i.anni = anni
        i.inflazione = inflazione
        i.rendimentoFondo = rendimento
        i.costoFondo = costo
        i.contributoLavoratore = lavoratore
        i.contributoDatore = datore
        i.anniPartecipazione = partecipazione
        return i
    }

    /// T1: 30.000 €, 10 anni, inflazione 2%, fondo al 4% lordo con lo 0,5% di costi, nessun contributo.
    private static var t1: IpotesiTFR {
        ipotesi(retribuzione: 30_000, crescita: 0, anni: 10, inflazione: 2, rendimento: 4, costo: 0.5)
    }

    /// Il pareggio come coppia (lordo, netto); (−99, −99) se `.sempre`, (99, 99) se `.mai`, nil se manca.
    private static func coppia(_ p: PareggioTFR?) -> (Double, Double)? {
        guard let p else { return nil }
        switch p {
        case .a(let lordo, let netto): return (lordo, netto)
        case .sempre: return (-99, -99)
        case .mai: return (99, 99)
        }
    }

    // MARK: - T0 Regole

    private static func regole(_ verifica: VerificaCalcoli) {
        verifica("T0 TFR: quota annua 100/13,5 − 0,5", RegoleTFR.quotaAnnua, 6.907407, tolleranza: 1e-6)
        verifica("T0 TFR: rivalutazione netta con inflazione 2%", RegoleTFR.rivalutazioneNetta(inflazione: 2), 2.49, tolleranza: tPercento)
        verifica("T0 TFR: rivalutazione netta con inflazione −1% (resta l'1,5% fisso)", RegoleTFR.rivalutazioneNetta(inflazione: -1), 1.245,
                 tolleranza: tPercento)
        verifica("T0 TFR: rivalutazione lorda con inflazione 11,3%", RegoleTFR.rivalutazioneLorda(inflazione: 11.3), 9.975, tolleranza: 1e-9)
    }

    // MARK: - T1 Solo TFR

    private static func soloTFR(_ verifica: VerificaCalcoli) {
        guard let e = MotoreTFR.calcola(t1) else {
            verifica.vero("T1 TFR: esito calcolato", false)
            return
        }
        verifica("T1 TFR: crescita nominale 2%", e.crescitaNominale, 2, tolleranza: tPercento)
        verifica("T1 TFR: rendimento netto del fondo", e.rendimentoNettoFondo, 2.784, tolleranza: tPercento)
        verifica("T1 TFR: quote accantonate", e.quote, 22_690.2552, tolleranza: tEuro)
        verifica("T1 TFR: montante in azienda", e.azienda.montante, 25_307.2504, tolleranza: tEuro)
        verifica("T1 TFR: reddito di riferimento", e.redditoRiferimento, 27_228.3062, tolleranza: tEuro)
        verifica("T1 TFR: aliquota della tassazione separata", e.azienda.aliquota, 23.0, tolleranza: tPercento)
        verifica("T1 TFR: imposta in azienda", e.azienda.imposta, 5_218.7587, tolleranza: tEuro)
        verifica("T1 TFR: netto in azienda", e.azienda.netto, 20_088.4918, tolleranza: tEuro)
        verifica("T1 TFR: netto in azienda in euro di oggi", e.azienda.reale, 16_479.5601, tolleranza: tEuro)
        verifica("T1 TFR: montante nel fondo", e.fondo.montante, 25_639.3459, tolleranza: tEuro)
        verifica("T1 TFR: aliquota del fondo 15%", e.fondo.aliquota, 15.0, tolleranza: tPercento)
        verifica("T1 TFR: imposta nel fondo", e.fondo.imposta, 3_403.5383, tolleranza: tEuro)
        verifica("T1 TFR: netto nel fondo", e.fondo.netto, 22_235.8076, tolleranza: tEuro)
        verifica("T1 TFR: netto nel fondo in euro di oggi", e.fondo.reale, 18_241.1070, tolleranza: tEuro)
        verifica("T1 TFR: differenza", e.differenza, 2_147.3159, tolleranza: tEuro)
        let p = coppia(e.pareggio)
        verifica("T1 TFR: pareggio lordo", p?.0 ?? -1, 1.5049, tolleranza: tPareggio)
        verifica("T1 TFR: pareggio netto", p?.1 ?? -1, 0.7979, tolleranza: tPareggio)
        verifica.vero("T1 TFR: senza contributi nessuna terza strada", e.fondoContributi == nil && e.pareggioContributi == nil
                      && e.differenzaContributi == nil && e.puntiFondoContributi == nil)
        verifica.vero("T1 TFR: 10 anni e 11 punti per grafico", e.anni.count == 10 && e.puntiAzienda.count == 11 && e.puntiFondo.count == 11
                      && e.puntiAzienda.first?.valore == 0)
        verifica("T1 TFR: l'ultimo punto del fondo è il montante", e.puntiFondo.last?.valore ?? 0, e.fondo.montante, tolleranza: tEuro)
        verifica("T1 TFR: il versato dell'ultimo punto sono le quote", e.puntiFondo.last?.versato ?? 0, e.quote, tolleranza: tEuro)
    }

    // MARK: - T2, T3 Con i contributi

    private static func conContributi(_ verifica: VerificaCalcoli) {
        let i2 = ipotesi(retribuzione: 35_000, crescita: 1, anni: 30, inflazione: 2, rendimento: 4, costo: 0.5, lavoratore: 1.2, datore: 1.6)
        if let e = MotoreTFR.calcola(i2) {
            verifica("T2 TFR: crescita nominale", e.crescitaNominale, 3.02, tolleranza: tPercento)
            verifica("T2 TFR: quote accantonate", e.quote, 115_391.3539, tolleranza: tEuro)
            verifica("T2 TFR: reddito di riferimento", e.redditoRiferimento, 46_156.5416, tolleranza: tEuro)
            verifica("T2 TFR: aliquota della tassazione separata", e.azienda.aliquota, 26.9337, tolleranza: tPercento)
            verifica("T2 TFR: imposta in azienda", e.azienda.imposta, 31_079.1468, tolleranza: tEuro)
            verifica("T2 TFR: netto in azienda", e.azienda.netto, 128_575.3439, tolleranza: tEuro)
            verifica("T2 TFR: montante nel fondo", e.fondo.montante, 166_292.3659, tolleranza: tEuro)
            verifica("T2 TFR: aliquota del fondo dopo 30 anni", e.fondo.aliquota, 10.5, tolleranza: tPercento)
            verifica("T2 TFR: netto nel fondo", e.fondo.netto, 154_176.2737, tolleranza: tEuro)
            verifica("T2 TFR: montante con i contributi", e.fondoContributi?.montante ?? 0, 233_700.9603, tolleranza: tEuro)
            verifica("T2 TFR: contributi dedotti", e.dedotti, 46_775.2620, tolleranza: tEuro)
            verifica("T2 TFR: imposta con i contributi", e.fondoContributi?.imposta ?? 0, 17_027.4947, tolleranza: tEuro)
            verifica("T2 TFR: netto con i contributi", e.fondoContributi?.netto ?? 0, 216_673.4656, tolleranza: tEuro)
            verifica("T2 TFR: versato dal lavoratore", e.versatoLavoratore, 20_046.5408, tolleranza: tEuro)
            verifica("T2 TFR: versato dal datore", e.versatoDatore, 26_728.7211, tolleranza: tEuro)
            verifica("T2 TFR: IRPEF risparmiata", e.risparmioIrpef, 7_772.0865, tolleranza: tEuro)
            verifica("T2 TFR: costo dei contributi", e.costoContributi, 17_235.4373, tolleranza: tEuro)
            verifica("T2 TFR: differenza con i contributi", e.differenzaContributi ?? 0, 70_862.6844, tolleranza: tEuro)
            let p = coppia(e.pareggio)
            verifica("T2 TFR: pareggio lordo", p?.0 ?? -1, 2.4538, tolleranza: tPareggio)
            verifica("T2 TFR: pareggio netto", p?.1 ?? -1, 1.5533, tolleranza: tPareggio)
            let pc = coppia(e.pareggioContributi)
            verifica("T2 TFR: pareggio lordo con i contributi", pc?.0 ?? -1, 0.5447, tolleranza: tPareggio)
            verifica("T2 TFR: pareggio netto con i contributi", pc?.1 ?? -1, 0.0336, tolleranza: tPareggio)
            verifica.vero("T2 TFR: 31 punti per la terza strada", e.puntiFondoContributi?.count == 31)
        } else {
            verifica.vero("T2 TFR: esito calcolato", false)
        }

        let i3 = ipotesi(retribuzione: 120_000, crescita: 0, anni: 5, inflazione: 0, rendimento: 3, costo: 1, lavoratore: 4, datore: 2,
                         partecipazione: 20)
        if let e = MotoreTFR.calcola(i3) {
            verifica("T3 TFR: dedotti nel limite di 5.300 € l'anno", e.dedotti, 26_500, tolleranza: tEuro)
            verifica("T3 TFR: non dedotti", e.nonDedotti, 9_500, tolleranza: tEuro)
            verifica("T3 TFR: IRPEF risparmiata (2.900 € l'anno al 43%)", e.risparmioIrpef, 6_235, tolleranza: tEuro)
            verifica("T3 TFR: aliquota in azienda", e.azienda.aliquota, 35.1582, tolleranza: tPercento)
            verifica("T3 TFR: aliquota del fondo dopo 25 anni", e.fondo.aliquota, 12.0, tolleranza: tPercento)
            verifica("T3 TFR: netto in azienda", e.azienda.netto, 27_918.2282, tolleranza: tEuro)
            verifica("T3 TFR: netto nel fondo", e.fondo.netto, 37_798.1905, tolleranza: tEuro)
            verifica("T3 TFR: netto con i contributi", e.fondoContributi?.netto ?? 0, 71_770.9350, tolleranza: tEuro)
            verifica("T3 TFR: costo dei contributi", e.costoContributi, 18_212.8901, tolleranza: tEuro)
        } else {
            verifica.vero("T3 TFR: esito calcolato", false)
        }
    }

    // MARK: - T4, T5, T6 Aliquota a mano, rendimento negativo, retribuzione nulla

    private static func casiLimite(_ verifica: VerificaCalcoli) {
        var i4 = t1
        i4.aliquotaTFR = 25
        if let e = MotoreTFR.calcola(i4) {
            verifica("T4 TFR: imposta in azienda con l'aliquota indicata", e.azienda.imposta, 5_672.5638, tolleranza: tEuro)
            verifica("T4 TFR: netto in azienda", e.azienda.netto, 19_634.6867, tolleranza: tEuro)
            verifica("T4 TFR: differenza", e.differenza, 2_601.1210, tolleranza: tEuro)
        } else {
            verifica.vero("T4 TFR: esito calcolato", false)
        }

        var i5 = t1
        i5.rendimentoFondo = -5
        if let e = MotoreTFR.calcola(i5) {
            verifica("T5 TFR: rendimento netto negativo, senza imposta", e.rendimentoNettoFondo, -5.475, tolleranza: tPercento)
            verifica("T5 TFR: montante nel fondo", e.fondo.montante, 18_006.2847, tolleranza: tEuro)
            verifica("T5 TFR: imponibile = montante (meno delle quote)", e.fondo.imponibile, e.fondo.montante, tolleranza: tEuro)
            verifica("T5 TFR: imposta nel fondo", e.fondo.imposta, 2_700.9427, tolleranza: tEuro)
            verifica("T5 TFR: netto nel fondo", e.fondo.netto, 15_305.3420, tolleranza: tEuro)
            verifica("T5 TFR: differenza", e.differenza, -4_783.1498, tolleranza: tEuro)
        } else {
            verifica.vero("T5 TFR: esito calcolato", false)
        }

        var i6 = t1
        i6.retribuzione = 0
        verifica.vero("T6 TFR: retribuzione nulla, nessun esito", MotoreTFR.calcola(i6) == nil)

        // Inflazione negativa: il TFR si rivaluta comunque dell'1,5% fisso (netto 1,245%)
        let negativa = ipotesi(retribuzione: 30_000, crescita: 0, anni: 1, inflazione: -1, rendimento: 3, costo: 0)
        if let e = MotoreTFR.calcola(negativa) {
            verifica("T6b TFR: rivalutazione netta con inflazione negativa", e.rivalutazioneNetta, 1.245, tolleranza: tPercento)
            verifica("T6b TFR: un anno, netto in azienda", e.azienda.netto, 1_595.6111, tolleranza: tEuro)
            verifica("T6b TFR: un anno, netto nel fondo", e.fondo.netto, 1_761.3889, tolleranza: tEuro)
        } else {
            verifica.vero("T6b TFR: esito calcolato", false)
        }
    }

    // MARK: - T7 Pareggio

    private static func provaPareggio(_ verifica: VerificaCalcoli) {
        var i7 = t1
        i7.rendimentoFondo = 1.5049002869
        if let e = MotoreTFR.calcola(i7) {
            verifica("T7 TFR: al rendimento di pareggio le due strade si equivalgono", e.differenza, 0, tolleranza: tEuro)
        } else {
            verifica.vero("T7 TFR: esito calcolato", false)
        }
        let sempre = ipotesi(retribuzione: 30_000, crescita: 0, anni: 5, inflazione: 2, rendimento: 3, costo: 0.5, lavoratore: 0, datore: 5)
        let e = MotoreTFR.calcola(sempre)
        verifica.vero("T7b TFR: con il 5% del datore il fondo resta sempre avanti", e?.pareggioContributi == .sempre)
        // Neanche al 30%: un'aliquota a mano nulla in azienda e un'imposta del fondo che non può scendere sotto il 9%
        var mai = t1
        mai.aliquotaTFR = 0
        mai.anni = 1
        verifica.vero("T7c TFR: con l'aliquota in azienda a zero il fondo non raggiunge mai il TFR in un anno",
                      MotoreTFR.calcola(mai)?.pareggio == .mai)
    }

    // MARK: - T8 Ipotesi dal dossier di Marco

    private static func dalCliente(_ verifica: VerificaCalcoli) {
        let dati = DatiPrisma.demo()
        guard let marco = dati.clienti.first(where: { $0.id == "marco" }) else {
            verifica.vero("T8 TFR: Marco tra i clienti di prova", false)
            return
        }
        let posizioni = dati.posizioni.filter { $0.clienteId == "marco" }
        let i = IpotesiTFR.dalCliente(marco, posizioni: posizioni)
        verifica("T8 TFR: retribuzione di Marco", i.retribuzione, 48_000, tolleranza: tEuro)
        verifica("T8 TFR: crescita oltre l'inflazione", i.crescitaReale, 1, tolleranza: tPercento)
        verifica("T8 TFR: anni alla pensione = 67 − età", Double(i.anni), Double(67 - (marco.eta ?? 0)), tolleranza: 0)
        let pip = posizioni.first { $0.regime == .previdenza && $0.stato == .inEssere }
        verifica("T8 TFR: anni nella previdenza dal suo PIP", Double(i.anniPartecipazione),
                 Double(pip.map { MotoreFiscale.anniPartecipazione($0) } ?? -1), tolleranza: 0)
        verifica.vero("T8 TFR: nessun contributo (il PIP non riceve il TFR)", i.contributoLavoratore == 0 && i.contributoDatore == 0)
        verifica.vero("T8 TFR: canale Alleanza (Marco ha solo Alleanza)", i.canale == .alleanza)

        // Un fondo che riceve già il TFR: contributi in % della retribuzione, nome e canale del fondo
        var fondo = AiutiProva.posizione("Fondo negoziale", .previdenza, 20_000, canale: .indipendente) {
            $0.clienteId = "marco"
            $0.premio = 624
            $0.frequenza = .annuale
            $0.contributoDatore = 720
            $0.tfrConferito = 3_300
        }
        fondo.tipologia = "Fondo pensione negoziale"
        let conFondo = IpotesiTFR.dalCliente(marco, posizioni: posizioni + [fondo])
        verifica("T8b TFR: contributo del lavoratore 624 / 48.000", conFondo.contributoLavoratore, 1.3, tolleranza: tPercento)
        verifica("T8b TFR: contributo del datore 720 / 48.000", conFondo.contributoDatore, 1.5, tolleranza: tPercento)
        verifica.vero("T8b TFR: nome e canale del fondo", conFondo.nomeFondo == "Fondo negoziale" && conFondo.canale == .indipendente)

        // Senza cliente: i valori di partenza
        let vuoto = IpotesiTFR.dalCliente(nil, posizioni: [])
        verifica.vero("T8c TFR: senza cliente 30.000 €, 27 anni, canale indipendente",
                      vuoto.retribuzione == 30_000 && vuoto.anni == 27 && vuoto.canale == .indipendente)
    }

    // MARK: - Lettura tollerante

    private static func lettura(_ verifica: VerificaCalcoli) {
        let fuori = try? Archivio.decodificatore.decode(IpotesiTFR.self, from: Data(#"{"anni": 99, "retribuzione": "molta"}"#.utf8))
        verifica.vero("T9 TFR: lettura tollerante (anni 99 → 50, retribuzione illeggibile → 30.000)",
                      fuori?.anni == 50 && fuori?.retribuzione == 30_000)
        let vuoto = try? Archivio.decodificatore.decode(IpotesiTFR.self, from: Data("{}".utf8))
        verifica.vero("T9 TFR: un archivio senza campi prende i predefiniti", vuoto == IpotesiTFR())
        var i = t1
        i.contributoDatore = 1.6
        i.nomeFondo = "Fondo di prova"
        i.aliquotaTFR = 25
        let dati = try? Archivio.codificatore.encode(i)
        let riletta = dati.flatMap { try? Archivio.decodificatore.decode(IpotesiTFR.self, from: $0) }
        verifica.vero("T9 TFR: le ipotesi tornano uguali dall'archivio", riletta == i)
    }

    // MARK: - Testi

    private static func testi(_ verifica: VerificaCalcoli) {
        // Coppie (ottenuto, atteso): niente catene lunghe di && con le stringhe (controllo dei tipi)
        let articoli: [(String, String)] = [(TestiTFR.del("1,5%"), "dell'1,5%"), (TestiTFR.del("2%"), "del 2%"),
                                            (TestiTFR.il("8%"), "l'8%"), (TestiTFR.il("11,3%"), "l'11,3%"),
                                            (TestiTFR.il("12%"), "il 12%"), (TestiTFR.del("1.500 €"), "del 1.500 €")]
        verifica.vero("T10 TFR: «dell'1,5%», «del 2%», «l'8%», «l'11,3%», «il 12%»", articoli.allSatisfy { $0.0 == $0.1 })
        guard let e = MotoreTFR.calcola(t1) else { return }
        let t = TestiTFR(e, cliente: nil)
        verifica.vero("T10 TFR: titolo del confronto con il fondo avanti", t.titoloConfronto.hasPrefix("Nel fondo pensione ti resterebbero circa"))
        verifica.vero("T10 TFR: il pareggio nel testo", t.testoPareggio.contains("dell'1,50% lordo") && t.testoPareggio.contains("2,49%"))
        verifica.vero("T10 TFR: senza contributi nessun testo dei contributi", t.testoContributi == nil)
        verifica.vero("T10 TFR: sintesi in quattro punti senza contributi", t.sintesi.count == 4)
        verifica.vero("T10 TFR: il metodo legge le regole (6,91%, 5.300 €)",
                      TestiTFR.metodo.joined().contains("6,91%") && TestiTFR.metodo.joined().contains("5.300 €"))
        var i5 = t1
        i5.rendimentoFondo = -5
        if let e5 = MotoreTFR.calcola(i5) {
            verifica.vero("T10 TFR: titolo con l'azienda avanti", TestiTFR(e5, cliente: nil).titoloConfronto.hasPrefix("Lasciato in azienda"))
        }
    }
}
