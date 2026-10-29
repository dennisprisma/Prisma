import SwiftUI

private typealias T = Tipo.Documento
private typealias D = Misure.Documento

/// Il prospetto del piano previdenziale: A4 verticale, per il consulente. Divario, piani alla pensione,
/// vantaggio fiscale dei versamenti, aliquota della prestazione nel tempo, uscite anticipate, scenari.
enum ProspettoPrevidenza {
    /// `ipotesi`: i dati da completare del cliente; se ci sono, una pagina in fondo li dichiara
    /// (prima della numerazione, così «pag. x di y» la conta). `percentuale`: la completezza dei dati.
    static func pagine(_ t: TestiPrevidenza, ipotesi: [VoceCompletezza] = [], percentuale: Int? = nil) -> [AnyView] {
        var pagine: [AnyView] = [AnyView(PaginaDivario(t: t))]
        // La pensione pubblica stimata con il contributivo, se il cliente ha i dati del lavoro
        if let stima = t.e.stimaPensione { pagine.append(AnyView(PaginaPensioneStimata(t: t, s: stima))) }
        pagine += [AnyView(PaginaFiscoPrevidenza(t: t)), AnyView(PaginaProiezionePrevidenza(t: t))]
        if !ipotesi.isEmpty { pagine.append(AnyView(PaginaIpotesiStimate(voci: ipotesi, percentuale: percentuale))) }
        return pagine.enumerated().map { i, p in
            AnyView(FoglioProspetto(piede: t.piede, avvertenza: TestiPrevidenza.avvertenza, numero: i + 1, totale: pagine.count) { p })
        }
    }
}

private var larghezza: CGFloat { FoglioProspetto<EmptyView>.larghezza }

// MARK: - Pagina 1: divario e piani

private struct PaginaDivario: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza

    private var e: EsitoPianoPrevidenziale { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                OcchielloDoc(testo: "Prospetto di dettaglio · Previdenza", font: T.pOcchiello)
                Text(verbatim: "Il piano pensionistico di \(t.cliente)").font(T.pTitolo).foregroundColor(C.titolo)
                Text(verbatim: "\(e.eta) anni oggi · pensione a \(e.etaPensione) anni, tra \(t.anniAllaPensione) · importi mensili netti in euro di oggi")
                    .font(T.pSottotitolo).foregroundColor(C.testo)
            }
            HStack(alignment: .bottom, spacing: 14) {
                CampoProspetto(etichetta: "Cliente", valore: t.cliente)
                CampoProspetto(etichetta: "Consulente", valore: TestiValutazione.consulente)
                CampoProspetto(etichetta: "Data", valore: CifreDoc.dataBreve(t.data)).frame(width: 90)
            }
            // Cifre in euro e «al mese» nella nota: tutte allo stesso corpo, senza troncarsi
            FilaCifre {
                CifraProspetto("Reddito desiderato", CifreDoc.euro(e.redditoDesiderato), TestiPrevidenza.alMese("netto, in euro di oggi"))
                CifraProspetto("Pensione pubblica", CifreDoc.euro(e.pensionePubblica), TestiPrevidenza.alMese("stima INPS da verificare"))
                CifraProspetto("Divario", CifreDoc.euro(e.divario), TestiPrevidenza.alMese("da integrare"), colore: e.divario > 0.5 ? C.negativo : nil)
                CifraProspetto("Dai piani di oggi", CifreDoc.euro(e.renditaInEssere), TestiPrevidenza.alMese("per \(e.anniIntegrazione) anni"))
                CifraProspetto("Resta da coprire", CifreDoc.euro(e.divarioResiduo), TestiPrevidenza.alMese("senza le proposte"),
                               colore: e.divarioResiduo > 0.5 ? C.negativo : C.positivo)
            }
            FilaCifre {
                CifraProspetto("Con le proposte", CifreDoc.euro(e.renditaInEssere + e.renditaProposte), TestiPrevidenza.alMese(notaProposte))
                CifraProspetto("Resta con le proposte", CifreDoc.euro(e.divarioConProposte), TestiPrevidenza.alMese("divario residuo"),
                               colore: e.divarioConProposte > 0.5 ? C.negativo : C.positivo)
                CifraProspetto("Versamento che manca", e.versamentoMancante.map { CifreDoc.euro($0) } ?? "—",
                               TestiPrevidenza.alMese("al \(CifreDoc.condizione(e.rendimentoReale)) reale annuo"))
                CifraProspetto("Risparmio IRPEF", e.aliquotaMarginale == nil ? "—" : CifreDoc.euro(e.risparmioConProposte),
                               e.aliquotaMarginale.map { "l'anno, aliquota \(CifreDoc.condizione($0))" } ?? "reddito non indicato")
                // Quinto posto vuoto: le schede restano larghe e allineate a quelle della riga sopra (alto zero,
                // altrimenti prende tutto lo spazio libero della pagina)
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
            }
            SezioneProspetto(titolo: "I piani alla pensione",
                             testo: Text(verbatim: "Ogni piano portato fino a \(e.etaPensione) anni con i suoi versamenti, il rendimento netto dell'imposta sui rendimenti e i suoi costi. Alla prestazione si tassano solo i contributi dedotti, con l'aliquota che spetterà allora."))
            if e.piani.isEmpty {
                Text(verbatim: "Nessun piano di previdenza complementare, né in essere né proposto.").font(T.pCorpo).foregroundColor(C.tenue)
            } else {
                TabellaCanali(colonne: [
                    ColonnaDoc(titolo: "Piano", sottotitolo: "stato · partecipazione", peso: 2.1, destra: false),
                    ColonnaDoc(titolo: "Oggi", sottotitolo: "versamenti l'anno", peso: 1.1),
                    ColonnaDoc(titolo: "Rendimento", sottotitolo: "netto · costi", peso: 0.95),
                    ColonnaDoc(titolo: "Montante", sottotitolo: "alla pensione", peso: 1.1),
                    ColonnaDoc(titolo: "Imposta", sottotitolo: "aliquota allora", peso: 1),
                    ColonnaDoc(titolo: "Netto", sottotitolo: "in euro di oggi", peso: 1.3),
                    ColonnaDoc(titolo: "Rendita", sottotitolo: "al mese", peso: 0.9),
                ], gruppi: Canale.allCases.compactMap { c in
                    let mie = e.piani.filter { $0.posizione.canale == c }
                    guard !mie.isEmpty else { return nil }
                    return GruppoCanale(canale: c, righe: mie.map { riga($0) }, nota: mie.count == 1 ? "1 piano" : "\(mie.count) piani")
                })
            }
            RiquadroBarra(titolo: "In sintesi") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(t.sintesi.enumerated()), id: \.offset) { _, p in
                        PuntoElenco(testo: Text(verbatim: "\(p.0): ").bold() + Text(verbatim: p.1))
                    }
                }
            }
        }
    }

    /// "nessuna proposta aperta", "1 proposta", "2 proposte".
    private var notaProposte: String {
        if e.proposte.isEmpty { return "nessuna proposta aperta" }
        return e.proposte.count == 1 ? "1 proposta" : "\(e.proposte.count) proposte"
    }

    private func riga(_ p: PianoPrevidenza) -> RigaDoc {
        let pos = p.posizione
        var nome = CellaDoc(pos.nome, sotto: "\(p.proposta ? "proposta" : "in essere") · \(p.anniOggi) → \(p.anniAllaPensione) anni", font: T.pTabellaForte)
        nome.coloreSotto = p.proposta ? C.evidenzaTitolo : C.tenue
        return RigaDoc(celle: [
            nome,
            CellaDoc(CifreDoc.euro(p.valoreOggi), sotto: p.versamentoAnnuo > 0 ? "\(CifreDoc.euro(p.versamentoAnnuo))/anno" : "—", font: T.pTabella),
            CellaDoc(CifreDoc.percento(p.rendimentoNetto), sotto: pos.costoComplessivo.map { "costi \(CifreDoc.condizione($0))" } ?? "", font: T.pTabella),
            CellaDoc(CifreDoc.euro(p.montante), sotto: "versati \(CifreDoc.euro(p.versatoTotale))", font: T.pTabella),
            CellaDoc(CifreDoc.togli(p.imposta), sotto: CifreDoc.percento(p.aliquota, decimali: 2), colore: C.negativo, font: T.pTabella),
            CellaDoc(CifreDoc.euro(p.nettoReale), sotto: "nominali \(CifreDoc.euro(p.netto))", font: T.pTabellaForte),
            CellaDoc(CifreDoc.euro(p.renditaMensile), font: T.pTabellaForte),
        ], altezza: 22, sfondo: p.proposta ? C.evidenza : .clear)
    }
}

// MARK: - Pagina 2: la pensione pubblica stimata

private struct PaginaPensioneStimata: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza
    let s: StimaPensione

    private var e: EsitoPianoPrevidenziale { t.e }
    private typealias M = Misure.Documento.Motori

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SezioneProspetto(titolo: "La pensione pubblica stimata con il contributivo",
                             testo: Text(verbatim: "Stima di Prisma con il metodo contributivo: i contributi accantonati fino all'uscita, rivalutati, per il coefficiente di trasformazione dell'età (\(RegolePensione.validitaCoefficienti)). In euro di oggi, netta di IRPEF e addizionali stimate, su 13 mensilità. Si affianca alla pensione dell'Analisi 360 e va verificata sull'estratto conto INPS."))
            FilaCifre {
                CifraProspetto("Pensione netta stimata", CifreDoc.euro(s.nettaMensile), TestiPrevidenza.alMese("su 13 mensilità, a \(s.etaPensione) anni"))
                CifraProspetto("Pensione lorda", CifreDoc.euro(s.lordaMensile), TestiPrevidenza.alMese("\(CifreDoc.euro(s.lordaAnnua)) l'anno"))
                CifraProspetto("Montante all'uscita", CifreDoc.euro(s.montante), "coefficiente \(CifreDoc.percento(s.coefficiente, decimali: 3))")
                CifraProspetto("Tasso di sostituzione", s.tassoSostituzione.map { CifreDoc.percento($0, decimali: 0) } ?? "—", "lordo, sull'ultimo reddito")
                CifraProspetto("Divario con la stima", e.divarioStimato.map { CifreDoc.euro($0) } ?? "—",
                               TestiPrevidenza.alMese("nell'analisi \(CifreDoc.euro(e.divario))"),
                               colore: (e.divarioStimato ?? 0) > 0.5 ? C.negativo : C.positivo)
            }
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Dato", peso: 1.6, destra: false), ColonnaDoc(titolo: "Valore", peso: 1.2),
                                                       ColonnaDoc(titolo: "Dato", peso: 1.6, destra: false), ColonnaDoc(titolo: "Valore", peso: 1.2)],
                       righe: righe, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            SezioneProspetto(titolo: "Il montante fino all'uscita",
                             testo: Text(verbatim: "Contributi accumulati anno per anno, in euro di oggi (capitalizzazione reale \(CifreDoc.percento(s.capitalizzazioneReale, decimali: 2)) l'anno)."))
            GraficoLineeDoc(serie: [SerieDoc(nome: "Montante", colore: C.intermedio, valori: s.punti)],
                            etichetteAsse: s.punti.indices.map { etichetta($0) }, fontAssi: T.pAssi, fontValori: T.pTabellaNota)
                .frame(height: M.graficoMontante)
                .background(C.riquadro.opacity(0.5))
            RiquadroBarra(titolo: "Con la stima o con l'Analisi 360") {
                Text(verbatim: confronto).font(T.pCorpo).foregroundColor(C.testo).fixedSize(horizontal: false, vertical: true)
            }
            if !s.avvisi.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(s.avvisi.enumerated()), id: \.offset) { _, a in
                        PuntoElenco(testo: Text(verbatim: "Attenzione: ").bold() + Text(verbatim: a))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(s.metodo.enumerated()), id: \.offset) { _, m in
                    Text(verbatim: "• " + m).font(T.pTabellaNota).foregroundColor(C.tenue).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var righe: [RigaDoc] {
        let coppie: [(String, String)] = [
            ("Età oggi e all'uscita", "\(s.eta) → \(s.etaPensione) anni"),
            ("Aliquota contributiva", CifreDoc.condizione(s.aliquota)),
            ("Reddito lordo oggi", CifreDoc.euro(s.redditoOggi)),
            ("Ultimo reddito stimato", CifreDoc.euro(s.redditoFinale)),
            ("Montante di oggi", CifreDoc.euro(s.montanteOggi) + (s.montanteStimato ? " (stimato)" : " (estratto INPS)")),
            ("Anni di contributi all'uscita", anniContributi),
            ("IRPEF e addizionali", "\(CifreDoc.togli(s.irpef + s.addizionali)) l'anno"),
            ("Requisiti all'uscita", s.requisitoRaggiunto ? "raggiunti" : "non raggiunti"),
            ("Sistema", s.sistemaMisto ? "misto (stima indicativa)" : "contributivo"),
            ("Pensione nell'Analisi 360", TestiPrevidenza.mese(e.pensionePubblica)),
        ]
        return stride(from: 0, to: coppie.count, by: 2).map { i -> RigaDoc in
            let a = coppie[i]
            let b: (String, String) = i + 1 < coppie.count ? coppie[i + 1] : ("", "")
            return RigaDoc(celle: [CellaDoc(a.0, colore: C.tenue, font: T.pTabella), CellaDoc(a.1, font: T.pTabellaForte),
                                   CellaDoc(b.0, colore: C.tenue, font: T.pTabella), CellaDoc(b.1, font: T.pTabellaForte)],
                           altezza: M.rigaTabellaBassa)
        }
    }

    /// "33 anni", "33,5 anni".
    private var anniContributi: String {
        let n = s.anniContributi
        let testo = n == n.rounded() ? "\(Int(n))" : (Formati.numeroFormatter.string(from: NSNumber(value: (n * 10).rounded() / 10)) ?? "\(n)")
        return testo + " anni"
    }

    private var confronto: String {
        let analisi = "Nel divario del piano conta la pensione dell'Analisi 360: \(TestiPrevidenza.mese(e.pensionePubblica)), divario \(TestiPrevidenza.mese(e.divario))."
        let stima = " Con la stima contributiva (\(TestiPrevidenza.mese(s.nettaMensile))) il divario sarebbe di \(TestiPrevidenza.mese(e.divarioStimato ?? 0))."
        return analisi + stima + " La stima netta è su 13 mensilità e il reddito desiderato su 12: il divario stimato esce un po' più alto, cioè prudente."
    }

    private func etichetta(_ anno: Int) -> String {
        let n = max(s.punti.count - 1, 1)
        let passo = n <= 12 ? 2 : (n <= 30 ? 5 : 10)
        if anno == 0 { return "oggi" }
        return anno % passo == 0 || anno == n ? "\(s.eta + anno) anni" : ""
    }
}

// MARK: - Pagina 3: fisco dei versamenti e della prestazione

private struct PaginaFiscoPrevidenza: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza

    private var e: EsitoPianoPrevidenziale { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "I versamenti: deducibilità e risparmio IRPEF",
                             testo: Text(verbatim: "I contributi alla previdenza complementare si deducono dal reddito complessivo fino a \(CifreDoc.euroCentesimi(RegoleFiscali.limiteDeducibilita)) l'anno (compresi quelli del datore di lavoro, escluso il TFR). Il risparmio è l'IRPEF in meno sul reddito ridotto dei contributi, scaglione per scaglione" + (e.reddito.map { ": reddito lordo \(CifreDoc.euro($0)), aliquota marginale \(CifreDoc.condizione(e.aliquotaMarginale ?? 0))." } ?? ".")))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Voce", peso: 3, destra: false), ColonnaDoc(titolo: "Oggi", peso: 1.2),
                                                       ColonnaDoc(titolo: "Con le proposte", peso: 1.2)],
                       righe: righeDeducibilita, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            SezioneProspetto(titolo: "L'aliquota sulla prestazione nel tempo",
                             testo: Text(verbatim: "15% fino a 15 anni di partecipazione, poi 0,30 punti in meno ogni anno fino al 9% dopo 35 anni. Gli anni contano dalla prima adesione a una forma complementare."))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Piano", peso: 2.2, destra: false),
                                                       ColonnaDoc(titolo: "Oggi"), ColonnaDoc(titolo: "Tra 5 anni"), ColonnaDoc(titolo: "Tra 10 anni"),
                                                       ColonnaDoc(titolo: "Alla pensione", peso: 1.2)],
                       righe: e.piani.map { p in
                           func a(_ anni: Int) -> String { CifreDoc.percento(RegoleFiscali.aliquotaPrevidenza(anni: anni), decimali: 2) }
                           return RigaDoc(celle: [CellaDoc(p.posizione.nome, sotto: p.proposta ? "proposta" : "", font: T.pTabellaForte),
                                                  CellaDoc(a(p.anniOggi), font: T.pTabella), CellaDoc(a(p.anniOggi + 5), font: T.pTabella),
                                                  CellaDoc(a(p.anniOggi + 10), font: T.pTabella),
                                                  CellaDoc("\(a(p.anniAllaPensione)) · \(p.anniAllaPensione) anni", font: T.pTabellaForte)], altezza: 18)
                       }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            SezioneProspetto(titolo: "Se servisse prima: le uscite di oggi, piano per piano",
                             testo: Text(verbatim: "Netti al centesimo. Pensionamento, riscatti agevolati e spese sanitarie con l'aliquota agevolata; anticipazioni per la casa e per ulteriori esigenze (dopo 8 anni) e riscatti per altre cause al 23%."))
            ForEach(e.inEssere) { p in uscite(p) }
            if e.inEssere.isEmpty {
                Text(verbatim: "Nessun piano in essere.").font(T.pCorpo).foregroundColor(C.tenue)
            }
        }
    }

    private var righeDeducibilita: [RigaDoc] {
        func riga(_ voce: String, _ oggi: String, _ con: String, forte: Bool = false) -> RigaDoc {
            let font = forte ? T.pTabellaForte : T.pTabella
            return RigaDoc(celle: [CellaDoc(voce, font: font), CellaDoc(oggi, font: font), CellaDoc(con, font: font)], altezza: 14,
                           sfondo: forte ? C.riquadro : .clear, filetto: forte ? C.filettoForte : nil, spessore: forte ? 0.8 : 0.5)
        }
        let senzaReddito = e.aliquotaMarginale == nil
        var righe = [riga("Contributi annui", CifreDoc.euro(e.contributiInEssere), CifreDoc.euro(e.contributiInEssere + e.contributiProposte))]
        // Il contributo del datore conta nel limite di deducibilità; il TFR no
        if e.datoreInEssere + e.datoreProposte > 0.5 {
            righe.append(riga("Contributo del datore di lavoro (conta nel limite)", CifreDoc.euro(e.datoreInEssere), CifreDoc.euro(e.datoreInEssere + e.datoreProposte)))
            righe.append(riga("Limite che resta ai tuoi contributi", CifreDoc.euroCentesimi(e.limiteClienteOggi), CifreDoc.euroCentesimi(e.limiteClienteConProposte)))
        }
        let tfrOggi = e.inEssere.reduce(0) { $0 + $1.tfrConferito }
        if e.tfrConferito > 0.5 {
            righe.append(riga("TFR conferito ogni anno (fuori dal limite)", CifreDoc.euro(tfrOggi), CifreDoc.euro(e.tfrConferito)))
        }
        return righe + [
            riga("Deducibili (fino al limite)", CifreDoc.euroCentesimi(e.deducibiliOggi), CifreDoc.euroCentesimi(e.deducibiliConProposte)),
            riga("Risparmio IRPEF dell'anno", senzaReddito ? "—" : CifreDoc.euroCentesimi(e.risparmioOggi),
                 senzaReddito ? "—" : CifreDoc.euroCentesimi(e.risparmioConProposte), forte: true),
            riga("Costo netto dei versamenti, al mese", senzaReddito ? "—" : CifreDoc.euro((e.contributiInEssere - e.risparmioOggi) / 12),
                 senzaReddito ? "—" : CifreDoc.euro(e.costoNettoMensile)),
            riga("Spazio di deducibilità non usato", CifreDoc.euroCentesimi(max(0, e.limiteClienteOggi - e.contributiInEssere)),
                 CifreDoc.euroCentesimi(e.spazioResiduo)),
            riga("Risparmio in più usando tutto lo spazio", senzaReddito ? "—" : CifreDoc.euroCentesimi(risparmioInPiuOggi),
                 senzaReddito ? "—" : CifreDoc.euroCentesimi(e.risparmioPossibile)),
        ]
    }

    /// IRPEF in più che si risparmierebbe oggi usando tutto il limite che resta ai contributi del cliente.
    private var risparmioInPiuOggi: Double {
        guard let reddito = e.reddito else { return 0 }
        return max(0, RegoleFiscali.risparmioDeduzione(reddito: reddito, deduzione: e.limiteClienteOggi) - e.risparmioOggi)
    }

    private func uscite(_ p: PianoPrevidenza) -> some View {
        let f = MotoreFiscale.calcola(p.posizione, data: t.data)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                EtichettaCanale(canale: p.posizione.canale)
                Text(verbatim: "\(p.posizione.nome) · \(f.anniPartecipazione ?? 0) anni di partecipazione").font(T.pSottosezione).foregroundColor(C.titolo)
            }
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Causa", peso: 2.8, destra: false), ColonnaDoc(titolo: "Disponibile"),
                                                       ColonnaDoc(titolo: "Aliquota", peso: 0.8), ColonnaDoc(titolo: "Imposta"), ColonnaDoc(titolo: "Netto")],
                       righe: f.uscite.map { u in
                           guard u.possibile else {
                               return RigaDoc(celle: [CellaDoc(u.causa.nome, font: T.pTabella), CellaDoc("dopo 8 anni di iscrizione", colore: C.tenue, font: T.pTabella)], altezza: 13)
                           }
                           return RigaDoc(celle: [CellaDoc(u.causa.nome, font: T.pTabella), CellaDoc(CifreDoc.euroCentesimi(u.importo), font: T.pTabella),
                                                  CellaDoc(CifreDoc.percento(u.aliquota, decimali: 2), font: T.pTabella),
                                                  CellaDoc("\(CifreDoc.meno) " + CifreDoc.euroCentesimi(u.imposta), colore: C.negativo, font: T.pTabella),
                                                  CellaDoc(CifreDoc.euroCentesimi(u.netto), font: T.pTabellaForte)], altezza: 13)
                       }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
        }
    }
}

// MARK: - Pagina 4: proiezione, scenari, metodo

private struct PaginaProiezionePrevidenza: View {
    @Environment(\.paletteDocumento) private var C
    let t: TestiPrevidenza

    private var e: EsitoPianoPrevidenziale { t.e }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SezioneProspetto(titolo: "Come cresce il montante fino alla pensione",
                             testo: Text(verbatim: "Valore complessivo dei piani anno per anno, in euro nominali, prima dell'imposta sulla prestazione."))
            GraficoLineeDoc(serie: serie, etichetteAsse: (0...e.anniAccumulo).map { etichetta($0) },
                            fontAssi: T.pAssi, fontValori: T.pTabellaNota)
                .frame(height: 170)
                .background(C.riquadro.opacity(0.5))
            SezioneProspetto(titolo: "Se i rendimenti vanno diversamente",
                             testo: Text(verbatim: "Rendita mensile complessiva, con le proposte, con \(Formati.numeroFormatter.string(from: NSNumber(value: IpotesiCalcolo.ampiezzaScenari)) ?? "2") punti di rendimento lordo in meno o in più."))
            TabellaDoc(larghezza: larghezza, colonne: [ColonnaDoc(titolo: "Scenario", peso: 1.4, destra: false), ColonnaDoc(titolo: "Rendita al mese"),
                                                       ColonnaDoc(titolo: "Divario che resta"), ColonnaDoc(titolo: "Copertura del divario")],
                       righe: e.scenari.map { s in
                           let colore = s.scarto < 0 ? C.sfavorevole : (s.scarto > 0 ? C.favorevole : C.intermedio)
                           let resta = max(0, e.divario - s.rendita)
                           return RigaDoc(celle: [CellaDoc("■ \(s.nome)", colore: colore, font: T.pTabellaForte), CellaDoc(CifreDoc.euro(s.rendita), font: T.pTabella),
                                                  CellaDoc(CifreDoc.euro(resta), font: T.pTabella),
                                                  CellaDoc(e.divario > 0.5 ? CifreDoc.percento(min(100, s.rendita / e.divario * 100), decimali: 0) : "—", font: T.pTabellaForte)],
                                          altezza: 15)
                       }, fontTesta: T.pTabellaTesta, altezzaTesta: 12, margine: 4)
            SezioneProspetto(titolo: "Ipotesi e metodo")
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array((e.note + metodo).enumerated()), id: \.offset) { _, n in PuntoElenco(testo: Text(verbatim: n)) }
            }
            Rectangle().fill(C.filetto).frame(height: 0.6)
            (Text(verbatim: "Avvertenze. ").bold()
             + Text(verbatim: "Stime illustrative basate sulle ipotesi indicate: i rendimenti non sono garantiti e la pensione pubblica è una stima da verificare con l'INPS. Le regole fiscali sono quelle in vigore alla data del prospetto (D.Lgs. 252/2005). Fanno fede la Nota informativa e il regolamento di ciascun piano."))
                .font(T.pTabellaNota).foregroundColor(C.tenue).lineSpacing(1.2).fixedSize(horizontal: false, vertical: true)
            FirmeProspetto()
        }
    }

    private var serie: [SerieDoc] {
        var s = [SerieDoc(nome: "Piani di oggi", colore: C.premio, valori: e.serieInEssere, tratteggio: true)]
        if !e.proposte.isEmpty { s.append(SerieDoc(nome: "Con le proposte", colore: C.intermedio, valori: e.serieConProposte)) }
        return s
    }

    private func etichetta(_ anno: Int) -> String {
        let passo = e.anniAccumulo <= 12 ? 2 : (e.anniAccumulo <= 30 ? 5 : 10)
        if anno == 0 { return "oggi" }
        return anno % passo == 0 || anno == e.anniAccumulo ? "\(e.eta + anno) anni" : ""
    }

    private var metodo: [String] {
        ["Divario: reddito desiderato meno pensione pubblica stimata, al mese, in euro di oggi (come nell'Analisi 360).",
         "Montante: calcolo mese per mese con i versamenti del piano, il rendimento atteso al netto del 20% di imposta sui rendimenti e i costi annui.",
         "Imposta sulla prestazione: aliquota degli anni di partecipazione alla pensione sui contributi dedotti (versati meno non dedotti).",
         "Versamento che manca: versamento mensile che, al rendimento reale dell'Analisi 360, copre il divario che resta."]
    }
}
