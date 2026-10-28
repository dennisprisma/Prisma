import SwiftUI

// I pannelli delle analisi nuove di Obiettivi e Analisi 360: la probabilità di raggiungere un obiettivo
// (scenari con le probabilità), la pensione pubblica stimata con il contributivo, la protezione persona
// per persona e il fisco delle coperture e della previdenza complementare. Ogni stima è presentata come
// stima, con le sue ipotesi a portata di mano («Le ipotesi»).

// MARK: - Ipotesi e avvisi

/// Collegamento che apre e chiude le note di metodo di una stima, per averle a portata di mano senza affollare.
struct IpotesiApribili: View {
    let titolo: String
    let righe: [String]
    @State var aperte = false

    var body: some View {
        let m = Tema.Misura.MotoriAnalisi.self
        VStack(alignment: .leading, spacing: m.spazioElenco) {
            Button {
                withAnimation(Tema.Moto.passaggio) { aperte.toggle() }
            } label: {
                HStack(spacing: m.spazioElenco) {
                    Image(systemName: aperte ? "chevron.down" : "chevron.right")
                        .font(Tema.Testo.MotoriAnalisi.freccia)
                    Text(titolo)
                        .font(Tema.Testo.didascalia)
                }
                .foregroundColor(Tema.Colore.MotoriAnalisi.apriIpotesi)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if aperte {
                NotaMetodo(testo: righe.map { "• " + $0 }.joined(separator: "\n"))
            }
        }
    }
}

/// Avvisi sotto le cifre (requisiti non raggiunti, coperture che scadono presto…), in arancio.
struct AvvisiAnalisi: View {
    let testi: [String]

    var body: some View {
        let m = Tema.Misura.MotoriAnalisi.self
        VStack(alignment: .leading, spacing: m.spazioElenco) {
            ForEach(Array(testi.enumerated()), id: \.offset) { _, testo in
                HStack(alignment: .firstTextBaseline, spacing: m.spazioValore) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(testo)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(Tema.Testo.didascalia)
        .foregroundColor(Tema.Colore.MotoriAnalisi.avviso)
    }
}

/// Testo di spiegazione di un pannello: come leggere le cifre.
struct SpiegazioneAnalisi: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(Tema.Testo.secondario)
            .foregroundColor(Tema.Colore.MotoriAnalisi.spiegazione)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Cifre comuni ai pannelli.
enum CifreAnalisi {
    /// «1.000», «12,5»: numero con i separatori italiani.
    static func numero(_ v: Double) -> String {
        Formati.numeroFormatter.string(from: NSNumber(value: v)) ?? String(v)
    }

    /// Anni con al più un decimale: «22», «22,5».
    static func anni(_ v: Double) -> String { numero((v * 10).rounded() / 10) }
}

// MARK: - Obiettivi: probabilità di arrivarci

/// La probabilità di raggiungere l'obiettivo (scenari con le probabilità): «7 possibilità su 10», i capitali
/// finali sfavorevole, mediano e favorevole e il ventaglio anno per anno. Per la colonna dell'obiettivo.
struct SezioneProbabilitaObiettivo: View {
    let esito: EsitoMonteCarlo
    /// L'importo dell'obiettivo, in euro di oggi.
    let importo: Double

    /// true se nessuna posizione collegata si muove con i mercati: c'è un solo risultato possibile.
    private var senzaOscillazioni: Bool { esito.p90 - esito.p10 < 1 }

    private var colore: Color {
        let c = Tema.Colore.MotoriAnalisi.self
        if esito.probabilita >= 0.7 { return c.probabilitaAlta }
        if esito.probabilita >= 0.4 { return c.probabilitaMedia }
        return c.probabilitaBassa
    }

    private var titolo: String {
        if senzaOscillazioni { return esito.probabilita >= 0.5 ? "Ci arriva in ogni caso" : "Così non ci arriva" }
        if esito.probabilita >= 0.95 { return "Più di 9 possibilità su 10" }
        if esito.probabilita < 0.05 { return "Meno di 1 possibilità su 10" }
        return "\(esito.suDieci) possibilità su 10"
    }

    private var frase: String {
        let traguardo = Formati.euro(esito.traguardo)
        let oggi = Formati.euro(importo)
        if senzaOscillazioni {
            return "Le posizioni collegate non si muovono con i mercati (conti, gestioni separate o solo il già da parte): alla scadenza ci sarebbero circa \(Formati.euro(esito.p50)) netti, contro i \(traguardo) che servono (i \(oggi) di oggi con l'inflazione). Per una probabilità serve collegare un investimento."
        }
        let quota = Formati.percentuale((esito.probabilita * 100).rounded())
        return "Con le posizioni collegate, i loro versamenti e il già da parte, senza aggiungere altro: su \(CifreAnalisi.numero(Double(esito.traiettorie))) andamenti possibili dei mercati, nel \(quota) dei casi si arriva a \(traguardo) (i \(oggi) di oggi con l'inflazione). È una stima, non una previsione."
    }

    var body: some View {
        let m = Tema.Misura.MotoriAnalisi.self
        let c = Tema.Colore.MotoriAnalisi.self
        VStack(alignment: .leading, spacing: m.spazioSezioni) {
            Text("PROBABILITÀ DI ARRIVARCI")
                .font(Tipo.incontroOcchiello)
                .tracking(m.spaziaturaOcchiello)
                .foregroundColor(Colori.Strumenti.occhiello)
            VStack(alignment: .leading, spacing: m.spazioValore) {
                Text(titolo)
                    .font(Tema.Testo.MotoriAnalisi.probabilita)
                    .foregroundColor(colore)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                BarraAvanzamento(quota: esito.probabilita, colore: colore)
            }
            SpiegazioneAnalisi(testo: frase)
            if !senzaOscillazioni {
                Text("CAPITALE FINALE, AL NETTO DELLE IMPOSTE")
                    .font(Tipo.incontroOcchiello)
                    .tracking(m.spaziaturaOcchiello)
                    .foregroundColor(Colori.Strumenti.occhiello)
                HStack(alignment: .top, spacing: m.spazioSezioni) {
                    percentile("Sfavorevole", esito.p10, "1 caso su 10 va peggio")
                    percentile("Mediano", esito.p50, "metà dei casi va meglio")
                    percentile("Favorevole", esito.p90, "1 caso su 10 va meglio")
                }
                if esito.anni.count >= 2 {
                    GraficoVentaglio(anni: esito.anni, traguardo: esito.traguardo)
                    HStack(spacing: m.spazioSezioni) {
                        LegendaLinea(colore: c.mediana, testo: "Mediano")
                        LegendaLinea(colore: c.traguardo, testo: "Obiettivo", tratteggio: true)
                        Text("Fascia: 8 casi su 10")
                            .font(Tema.Testo.didascalia)
                            .foregroundColor(c.spiegazione)
                    }
                }
            }
            IpotesiApribili(titolo: "Le ipotesi della stima", righe: MotoreMonteCarlo.metodo)
        }
    }

    private func percentile(_ nome: String, _ valore: Double, _ nota: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Misura.MotoriAnalisi.spazioElenco) {
            Text(nome)
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.MotoriAnalisi.spiegazione)
            Text(Formati.euro(valore))
                .font(Tema.Testo.importo)
                .foregroundColor(Tema.Colore.MotoriAnalisi.valore)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(nota)
                .font(Tema.Testo.didascalia)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Il ventaglio degli scenari anno per anno: la fascia tra il caso sfavorevole (1 su 10) e il favorevole
/// (9 su 10), la linea mediana e, tratteggiato, l'importo da raggiungere alla scadenza.
struct GraficoVentaglio: View {
    let anni: [EsitoMonteCarlo.Anno]
    let traguardo: Double

    var body: some View {
        let m = Tema.Misura.MotoriAnalisi.self
        let c = Tema.Colore.MotoriAnalisi.self
        GeometryReader { geo in
            let sinistra = m.ventaglioSinistra
            let basso = m.ventaglioBasso
            let w = max(1, geo.size.width - sinistra)
            let h = max(1, geo.size.height - basso)
            let massimo = max(anni.map(\.p90).max() ?? 1, traguardo, 1) * 1.08
            let ultimo = max(anni.last?.anno ?? 1, 1)
            let x: (Int) -> CGFloat = { sinistra + CGFloat($0) / CGFloat(ultimo) * w }
            let y: (Double) -> CGFloat = { h - CGFloat(max(0, $0) / massimo) * h }
            ZStack(alignment: .topLeading) {
                // Fascia tra il caso sfavorevole e il favorevole
                Path { p in
                    guard let primo = anni.first else { return }
                    p.move(to: CGPoint(x: x(primo.anno), y: y(primo.p90)))
                    for a in anni.dropFirst() { p.addLine(to: CGPoint(x: x(a.anno), y: y(a.p90))) }
                    for a in anni.reversed() { p.addLine(to: CGPoint(x: x(a.anno), y: y(a.p10))) }
                    p.closeSubpath()
                }
                .fill(c.fasciaVentaglio)
                linea(anni.map { CGPoint(x: x($0.anno), y: y($0.p90)) })
                    .stroke(c.bordoVentaglio, lineWidth: m.lineaBordo)
                linea(anni.map { CGPoint(x: x($0.anno), y: y($0.p10)) })
                    .stroke(c.bordoVentaglio, lineWidth: m.lineaBordo)
                linea(anni.map { CGPoint(x: x($0.anno), y: y($0.p50)) })
                    .stroke(c.mediana, style: StrokeStyle(lineWidth: m.lineaMediana, lineJoin: .round))
                // L'obiettivo alla scadenza
                linea([CGPoint(x: sinistra, y: y(traguardo)), CGPoint(x: sinistra + w, y: y(traguardo))])
                    .stroke(c.traguardo, style: StrokeStyle(lineWidth: m.lineaTraguardo, dash: m.trattiTraguardo))
                // Cifre dell'asse: zero e obiettivo
                Text(Formati.euroBreve(traguardo))
                    .font(Tema.Testo.Componenti.asse)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
                    .frame(width: sinistra - 4, alignment: .trailing)
                    .position(x: (sinistra - 4) / 2, y: y(traguardo))
                Text(Formati.euro(0))
                    .font(Tema.Testo.Componenti.asse)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
                    .frame(width: sinistra - 4, alignment: .trailing)
                    .position(x: (sinistra - 4) / 2, y: y(0))
                // Anni: oggi e scadenza
                Text("Oggi")
                    .font(Tema.Testo.Componenti.asse)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
                    .position(x: x(0) + sinistra / 2, y: geo.size.height - basso / 2)
                Text("+\(ultimo) \(ultimo == 1 ? "anno" : "anni")")
                    .font(Tema.Testo.Componenti.asse)
                    .foregroundColor(Tema.Colore.inchiostroTerziario)
                    .position(x: sinistra + w - sinistra / 2, y: geo.size.height - basso / 2)
            }
        }
        .frame(height: m.ventaglio)
    }

    /// Una spezzata per i punti dati.
    private func linea(_ punti: [CGPoint]) -> Path {
        Path { p in
            guard let primo = punti.first else { return }
            p.move(to: primo)
            for q in punti.dropFirst() { p.addLine(to: q) }
        }
    }
}

// MARK: - Analisi 360, previdenza: la pensione pubblica stimata

/// La pensione pubblica stimata con il metodo contributivo, affiancata a quella inserita nelle ipotesi
/// (che resta quella del divario finché il consulente non copia la stima).
struct PannelloPensioneStimata: View {
    let stima: StimaPensione?
    /// Perché la stima non si può fare, quando `stima` è nil.
    let motivo: String?
    let ipotesi: IpotesiPrevidenza
    /// Copia la pensione netta stimata (all'euro) nel campo «Pensione pubblica» dell'analisi.
    let usaStima: (Double) -> Void

    var body: some View {
        PannelloAnalisi(titolo: "La pensione pubblica stimata",
                        nota: "Metodo contributivo, dai dati del lavoro nella scheda del cliente") {
            if let s = stima {
                let netta = s.nettaMensile.rounded()
                Button("Usa la stima nell'analisi") { usaStima(netta) }
                    .buttonStyle(StileVetro(margine: Tema.Misura.MotoriAnalisi.marginePulsante))
                    .disabled(abs(netta - ipotesi.pensionePubblica) < 1)
                    .help("Copia la pensione netta stimata nel campo «Pensione pubblica»: resta modificabile")
            }
        } contenuto: {
            if let s = stima {
                dettaglio(s)
            } else {
                VStack(alignment: .leading, spacing: Tema.Misura.MotoriAnalisi.spazioElenco) {
                    Text(motivo ?? "Stima non disponibile per questo cliente.")
                        .font(Tema.Testo.corpo)
                        .foregroundColor(Tema.Colore.MotoriAnalisi.valore)
                    SpiegazioneAnalisi(testo: "Compila «Lavoro e contributi» nella scheda del cliente (tipo di lavoratore, reddito da lavoro, anni di contributi o montante dell'estratto conto INPS): Prisma stimerà la pensione con il metodo contributivo, da affiancare a quella inserita qui.")
                }
            }
        }
    }

    private func dettaglio(_ s: StimaPensione) -> some View {
        let m = Tema.Misura.MotoriAnalisi.self
        let netta = s.nettaMensile
        let inserita = ipotesi.pensionePubblica
        let scarto = netta - inserita
        let divarioInserita = max(0, ipotesi.redditoDesiderato - inserita)
        let frase = "A \(s.etaPensione) anni, con i dati del lavoro di oggi, la pensione pubblica sarebbe di circa \(Formati.euro(netta)) al mese netti, in euro di oggi. Il divario qui sopra usa la cifra inserita nelle ipotesi: «Usa la stima» la sostituisce, e resta modificabile."
        return VStack(alignment: .leading, spacing: m.spazioSezioni) {
            SpiegazioneAnalisi(testo: frase)
            FasciaKPI {
                KPI(titolo: "Stimata, netta", valore: "\(Formati.euro(netta))/mese") {
                    Text("lorda \(Formati.euro(s.lordaMensile)) · 13 mensilità")
                }
                KPI(titolo: "Inserita nelle ipotesi", valore: "\(Formati.euro(inserita))/mese") {
                    Text(abs(scarto) < 1 ? "uguale alla stima"
                         : "la stima è \(Formati.euro(abs(scarto))) \(scarto > 0 ? "in più" : "in meno")")
                }
                KPI(titolo: "Divario con la stima", valore: "\(Formati.euro(s.divario(obiettivo: ipotesi.redditoDesiderato)))/mese", ultimo: true) {
                    Text("con quella inserita \(Formati.euro(divarioInserita))")
                }
            }
            VStack(spacing: 0) {
                RigaDato("Montante contributivo oggi",
                         "\(Formati.euro(s.montanteOggi)) · \(s.montanteStimato ? "stimato dagli anni di contributi" : "dall'estratto conto INPS")",
                         larghezza: m.etichettaRiga)
                RigaDato("Montante alla pensione",
                         "\(Formati.euro(s.montante)) in euro di oggi, con \(CifreAnalisi.anni(s.anniContributi)) anni di contributi",
                         larghezza: m.etichettaRiga)
                RigaDato("Coefficiente di trasformazione",
                         "\(CifreDoc.percento(s.coefficiente, decimali: 3)) a \(s.etaPensione) anni (in vigore per il \(RegolePensione.validitaCoefficienti))",
                         larghezza: m.etichettaRiga)
                RigaDato("Pensione sull'ultimo reddito",
                         s.tassoSostituzione.map { "\(Formati.percentuale($0.rounded())) del reddito lordo (contributi al \(Formati.percentuale(s.aliquota)))" } ?? "—",
                         larghezza: m.etichettaRiga)
            }
            if !s.avvisi.isEmpty {
                AvvisiAnalisi(testi: s.avvisi)
            }
            IpotesiApribili(titolo: "Come è stimata e cosa non considera",
                            righe: s.metodo + ["La pensione netta è divisa per 13 mensilità (c'è la tredicesima), il reddito desiderato è al mese: il divario con la stima esce un po' più alto, dal lato prudente."])
        }
    }
}

// MARK: - Analisi 360, previdenza: il fisco dei versamenti

/// La deducibilità dei contributi alla previdenza complementare in essere: limite comune con il datore di
/// lavoro, TFR fuori dal limite, spazio che resta e IRPEF risparmiata.
struct PannelloFiscoPrevidenza: View {
    let deducibilita: DeducibilitaPrevidenza
    /// Reddito lordo annuo del cliente (per il risparmio d'imposta), se indicato.
    let reddito: Double?

    var body: some View {
        let m = Tema.Misura.MotoriAnalisi.self
        let d = deducibilita
        let limite = Formati.euro(d.limite)
        PannelloAnalisi(titolo: "Il fisco dei versamenti", nota: "Previdenza complementare in essere, in un anno") {
            EmptyView()
        } contenuto: {
            VStack(alignment: .leading, spacing: m.spazioSezioni) {
                SpiegazioneAnalisi(testo: "I contributi del cliente e quelli del datore di lavoro si deducono insieme fino a \(limite) l'anno; il TFR conferito al fondo non conta nel limite. Lo spazio che resta è IRPEF che il cliente può ancora risparmiare versando.")
                VStack(spacing: 0) {
                    RigaDato("Contributi del cliente",
                             "\(Formati.euro(d.lavoratore)) l'anno · deducibili \(Formati.euro(d.deducibili))", larghezza: m.etichettaRiga)
                    if d.datore > 0 {
                        RigaDato("Contributo del datore di lavoro", "\(Formati.euro(d.datore)) l'anno · conta nel limite", larghezza: m.etichettaRiga)
                    }
                    if d.tfr > 0 {
                        RigaDato("TFR conferito", "\(Formati.euro(d.tfr)) l'anno · non conta nel limite", larghezza: m.etichettaRiga)
                    }
                    RigaDato("Limite che resta al cliente", "\(Formati.euro(d.limiteLavoratore)) su \(limite)", larghezza: m.etichettaRiga)
                    RigaDato("Spazio ancora deducibile", "\(Formati.euro(d.spazio)) l'anno", larghezza: m.etichettaRiga)
                    if let r = reddito {
                        RigaDato("IRPEF risparmiata oggi", "\(Formati.euro(d.risparmio(reddito: r))) l'anno", larghezza: m.etichettaRiga)
                        RigaDato("In più usando tutto lo spazio", "\(Formati.euro(d.risparmioPossibile(reddito: r))) l'anno", larghezza: m.etichettaRiga)
                    } else {
                        RigaDato("Risparmio d'imposta", "indica il reddito lordo nel profilo del cliente", larghezza: m.etichettaRiga)
                    }
                }
                if d.eccedenza > 0 {
                    AvvisiAnalisi(testi: ["\(Formati.euro(d.eccedenza)) l'anno oltre il limite: non si deducono e alla prestazione non si tassano."])
                }
                IpotesiApribili(titolo: "Le regole e le fonti",
                                righe: FiscoPolizze.metodo.filter { $0.hasPrefix("Previdenza") })
            }
        }
    }
}

// MARK: - Analisi 360, protezione: persona per persona

/// La protezione per ogni persona che porta reddito: caso morte, invalidità e non autosufficienza confrontati
/// con le coperture di cui quella persona è l'assicurato.
struct PannelloProtezionePersone: View {
    let persone: [FabbisognoPersona]
    /// Apre una copertura in Posizioni.
    let apri: (Posizione) -> Void

    var body: some View {
        let m = Tema.Misura.MotoriAnalisi.self
        PannelloAnalisi(titolo: "Persona per persona",
                        nota: "Chi porta reddito: se viene a mancare, se non può più lavorare, se non è più autosufficiente") {
            EmptyView()
        } contenuto: {
            VStack(alignment: .leading, spacing: m.spazioSezioni) {
                SpiegazioneAnalisi(testo: "Per ogni persona contano solo le coperture di cui è l'assicurato. «Scoperto» è quanto mancherebbe alla famiglia: i tre casi sono scenari diversi, da non sommare tra loro né con il totale del nucleo qui sopra.")
                ForEach(persone) { p in
                    SchedaPersonaProtezione(persona: p, apri: apri)
                }
            }
        }
    }
}

/// Una persona: intestazione, tabella dei tre rischi, come leggere le cifre, chi dipende da lei, coperture, avvisi.
struct SchedaPersonaProtezione: View {
    let persona: FabbisognoPersona
    let apri: (Posizione) -> Void

    var body: some View {
        let p = persona
        let m = Tema.Misura.MotoriAnalisi.self
        VStack(alignment: .leading, spacing: m.spazioSezioni) {
            intestazione
            TabellaStrumento {
                CellaTesta(testo: "Se la persona…")
                CellaTesta(testo: "Serve", larghezza: m.colonnaCifra, destra: true)
                CellaTesta(testo: "Coperto", larghezza: m.colonnaCifra, destra: true)
                CellaTesta(testo: "Scoperto", larghezza: m.colonnaCifra, destra: true)
                CellaTesta(testo: "Con le proposte", larghezza: m.colonnaProposte, destra: true)
            } righe: {
                riga(0, "viene a mancare", serve: p.fabbisognoMorte, coperto: p.capitaleMorte, scoperto: p.divarioMorte,
                     proposte: p.capitaleMorteProposte, conProposte: p.divarioMorteConProposte)
                riga(1, "non può più lavorare", serve: p.fabbisognoInvalidita, coperto: p.capitaleInvalidita, scoperto: p.divarioInvalidita,
                     proposte: p.capitaleInvaliditaProposte, conProposte: p.divarioInvaliditaConProposte)
                riga(2, "non è più autosufficiente", serve: p.fabbisognoLTC, coperto: p.capitaleLTC, scoperto: p.divarioLTC,
                     proposte: p.capitaleLTCProposte, conProposte: p.divarioLTCConProposte)
            }
            SpiegazioneAnalisi(testo: comeSiLegge)
            if !p.dipendenti.isEmpty {
                SpiegazioneAnalisi(testo: dipendenti)
            }
            coperture
            if !p.avvisi.isEmpty {
                AvvisiAnalisi(testi: p.avvisi)
            }
        }
    }

    private var intestazione: some View {
        let p = persona
        var parti: [String] = [p.relazione?.nome ?? "Cliente"]
        if let eta = p.eta { parti.append("\(eta) anni") }
        parti.append("reddito netto \(Formati.euro(p.redditoNetto)) l'anno"
                     + (p.redditoStimato ? " (stimato dal fabbisogno: indicalo nel profilo)" : ""))
        return HStack(alignment: .firstTextBaseline, spacing: Tema.Misura.MotoriAnalisi.spazioValore) {
            Text(p.nome)
                .font(Tema.Testo.MotoriAnalisi.persona)
                .foregroundColor(Tema.Colore.MotoriAnalisi.valore)
            Text(parti.joined(separator: " · "))
                .font(Tema.Testo.secondario)
                .foregroundColor(Tema.Colore.MotoriAnalisi.spiegazione)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Pillola(testo: "\(Formati.percentuale((p.quotaReddito * 100).rounded())) del reddito di famiglia", tono: .neutro)
        }
    }

    private func riga(_ i: Int, _ caso: String, serve: Double, coperto: Double, scoperto: Double,
                      proposte: Double, conProposte: Double) -> some View {
        let m = Tema.Misura.MotoriAnalisi.self
        let c = Tema.Colore.MotoriAnalisi.self
        return RigaStrumento(indice: i) {
            CellaTabella(testo: caso, forte: true)
            CellaTabella(testo: Formati.euro(serve), larghezza: m.colonnaCifra, destra: true)
            CellaTabella(testo: Formati.euro(coperto), larghezza: m.colonnaCifra, destra: true)
            CellaTabella(testo: Formati.euro(scoperto), larghezza: m.colonnaCifra, destra: true,
                         colore: scoperto >= 1 ? c.scoperto : c.coperto)
            CellaTabella(testo: proposte > 0 ? Formati.euro(conProposte) : "—", larghezza: m.colonnaProposte, destra: true,
                         colore: proposte > 0 && conProposte < 1 ? c.coperto : c.valore)
        }
    }

    /// Da dove vengono le cifre di «Serve».
    private var comeSiLegge: String {
        let p = persona
        let assistenza = IpotesiPersona()
        let morte = "Viene a mancare: debiti a suo carico \(Formati.euro(p.debiti)) + spese immediate \(Formati.euro(p.speseImmediate)) + sostegno \(Formati.euro(p.sostegnoAnnuo)) l'anno per \(p.anniSostegno) \(p.anniSostegno == 1 ? "anno" : "anni") − capitale già disponibile \(Formati.euro(p.capitaleDisponibile))."
        let lavoro = "Non può più lavorare: \(Formati.euro(max(0, p.redditoNetto - p.entrateSostitutive))) l'anno da sostituire per \(p.anniAllaPensione) \(p.anniAllaPensione == 1 ? "anno" : "anni"), fino alla pensione."
        let ltc = "Non autosufficienza: assistenza di \(Formati.euro(assistenza.spesaAssistenzaMensile)) al mese per \(assistenza.anniAssistenza) anni (ipotesi prudente)."
        var testo = [morte, lavoro, ltc].joined(separator: " ")
        if p.capitaleInfortuni > 0 {
            testo += " Infortuni: \(Formati.euro(p.capitaleInfortuni)) assicurati, pagano solo se l'invalidità viene da un infortunio (non contati sopra)."
        }
        return testo
    }

    /// Chi dipende da questa persona e per quanti anni.
    private var dipendenti: String {
        let elenco = persona.dipendenti.map { d -> String in
            let eta = d.eta.map { " (\($0) anni)" } ?? ""
            let durata = d.aVita ? "per tutta la vita" : "per \(d.anni) \(d.anni == 1 ? "anno" : "anni")"
            return "\(d.nome)\(eta), \(durata)"
        }
        return "Dipendono da \(persona.nome): " + elenco.joined(separator: "; ") + "."
    }

    /// Le coperture di cui è l'assicurato, in essere e in proposta: un clic apre la posizione.
    @ViewBuilder private var coperture: some View {
        let p = persona
        let m = Tema.Misura.MotoriAnalisi.self
        let tutte = p.coperture + p.proposte
        VStack(alignment: .leading, spacing: m.spazioElenco) {
            Text("ASSICURATO IN")
                .font(Tema.Testo.MotoriAnalisi.sottotitolo)
                .tracking(m.spaziaturaOcchiello)
                .foregroundColor(Tema.Colore.inchiostroTerziario)
            if tutte.isEmpty {
                Text("Nessuna copertura in cui \(p.nome) è l'assicurato.")
                    .font(Tema.Testo.secondario)
                    .foregroundColor(Tema.Colore.MotoriAnalisi.spiegazione)
            }
            ForEach(tutte) { c in
                Button { apri(c) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: m.spazioValore) {
                        Text(c.nome)
                            .font(Tema.Testo.corpo)
                            .foregroundColor(Tema.Colore.MotoriAnalisi.valore)
                            .lineLimit(1)
                        Text("\(c.rischio?.nome ?? "Rischio non indicato") · \(Formati.euro(MotoreProtezioneFamiglia.capitaleAttuale(c, al: Date())))")
                            .font(Tema.Testo.didascalia)
                            .foregroundColor(Tema.Colore.MotoriAnalisi.spiegazione)
                            .lineLimit(1)
                        if c.stato == .proposta {
                            Pillola(testo: "Proposta", tono: .attenzione)
                        }
                        Spacer(minLength: 0)
                        EtichettaCanale(canale: c.canale, compatta: true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(StileSemplice())
            }
        }
    }
}

// MARK: - Analisi 360, protezione: il fisco delle coperture

/// Detrazione dei premi per persona e capitali caso morte ai beneficiari (esenti IRPEF, fuori successione).
struct PannelloFiscoCoperture: View {
    let fisco: FiscoPolizzeCliente

    var body: some View {
        let m = Tema.Misura.MotoriAnalisi.self
        let regola = "Chi paga i premi di caso morte, invalidità e infortuni detrae il \(Formati.percentuale(RegoleFiscali.detrazionePremi)) fino a \(Formati.euro(RegoleFiscali.limitePremiVita)) l'anno (con la non autosufficienza fino a \(Formati.euroDecimali(RegoleFiscali.limitePremiLTC)) in tutto): per intero fino a \(Formati.euro(RegoleFiscali.redditoDetrazionePiena)) di reddito, poi sempre meno fino a zero a \(Formati.euro(RegoleFiscali.redditoSenzaDetrazione)). Ai beneficiari il capitale caso morte arriva fuori dalla successione e, per la parte di rischio, senza IRPEF."
        PannelloAnalisi(titolo: "Il fisco delle coperture", nota: "Detrazione dei premi e capitali ai beneficiari") {
            EmptyView()
        } contenuto: {
            VStack(alignment: .leading, spacing: m.spazioSezioni) {
                SpiegazioneAnalisi(testo: regola)
                VStack(spacing: 0) {
                    if fisco.detrazioni.isEmpty {
                        RigaDato("Detrazione dei premi", "nessun premio detraibile sulle coperture in essere", larghezza: m.etichettaRiga)
                    }
                    ForEach(fisco.detrazioni) { d in
                        RigaDato("Detrazione di \(d.nome)",
                                 "\(Formati.euro(d.detrazione)) l'anno su \(Formati.euro(d.detraibili)) di premi detraibili" + (d.quota < 1 ? " (ridotta dal reddito)" : ""),
                                 larghezza: m.etichettaRiga)
                    }
                    RigaDato("Capitali caso morte esenti IRPEF", Formati.euro(fisco.capitaleEsenteIRPEF), larghezza: m.etichettaRiga)
                    RigaDato("Ai beneficiari fuori successione", Formati.euro(fisco.fuoriSuccessione), larghezza: m.etichettaRiga)
                    if fisco.impostaAlDecesso >= 1 {
                        RigaDato("Imposta sui guadagni al decesso", Formati.euro(fisco.impostaAlDecesso), larghezza: m.etichettaRiga)
                    }
                }
                IpotesiApribili(titolo: "Le regole e le fonti", righe: fisco.note)
            }
        }
    }
}
