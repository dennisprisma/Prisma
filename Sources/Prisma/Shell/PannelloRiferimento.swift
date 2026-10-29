import SwiftUI

private typealias T = TestiRiferimenti
private typealias K = Tema.Colore.Riferimenti
private typealias M = Tema.Misura.Riferimenti
private typealias F = Tema.Testo.Riferimenti

/// Posizioni › dettaglio: il pannello «Contro un riferimento» sotto l'andamento (giro 6, specifica 11, §7.3).
/// Lo stesso periodo dell'andamento misurato con un metro esterno: inflazione, rivalutazione del TFR, gestioni
/// separate o un indice del consulente. Calcola nel `body` (pochi anni, nessuna cache).
struct PannelloRiferimento: View {
    @EnvironmentObject var stato: StatoShell
    let posizione: Posizione
    let andamento: AndamentoPosizione
    let voce: VoceResoconto?
    @State private var mostraMetodo = false

    var body: some View {
        let tabella = stato.tabellaRiferimenti
        let impostazioni = stato.dati.impostazioni.riferimenti
        let scelta = MotoreRiferimenti.serieDi(posizione, impostazioni: impostazioni, tabella: tabella)
        let c = MotoreRiferimenti.confronto(posizione, andamento: andamento, flussi: voce?.flussiDatati,
                                            serie: scelta.serie, rispettata: scelta.rispettata, tabella: tabella)
        let famiglia = FamigliaRiferimento.di(posizione)
        PannelloAnalisi(titolo: T.titoloPannello, nota: T.notaPannello(dal: c.dal, al: c.al)) {
            HStack(spacing: M.spazioTestata) {
                if let g = c.giudizio {
                    Pillola(testo: T.pillola(g, c.serie), tono: tono(g))
                }
                Text(T.etichettaMetro)
                    .font(F.testaGriglia)
                    .foregroundColor(K.testa)
                MenuTendina(selezione: sceltaMetro(tabella), opzioni: opzioni(tabella, impostazioni: impostazioni, famiglia: famiglia),
                            larghezza: M.tendinaMetro)
                    // In modalità cliente si guarda, non si cambia
                    .disabled(stato.inModoCliente)
            }
        } contenuto: {
            VStack(alignment: .leading, spacing: M.spazioPannello) {
                if c.riferimento == nil {
                    avviso(c)
                } else {
                    tessere(c)
                    GraficoAndamento(punti: c.punti, coloreAtteso: K.linea)
                    legenda(c)
                    gettoni(c)
                }
                note(c, tabella: tabella, famiglia: famiglia)
                HStack(spacing: M.spazioTestata) {
                    if famiglia == .previdenza && !stato.inModoCliente {
                        Button(T.apriTFR) { apriTFR() }
                            .buttonStyle(StileSemplice())
                            .font(F.collegamento)
                            .foregroundColor(K.collegamento)
                    }
                    Spacer(minLength: 0)
                    Button(mostraMetodo ? T.nascondiMetodo : T.mostraMetodo) { mostraMetodo.toggle() }
                        .buttonStyle(StileVetro(margine: M.marginePulsante))
                }
                if mostraMetodo {
                    NotaMetodo(testo: T.metodo.joined(separator: "\n"), titolo: T.titoloMetodo)
                }
            }
        }
    }

    /// Il tono della pillola: sopra il metro bene, sotto male, in linea neutro.
    private func tono(_ g: ConfrontoRiferimento.Giudizio) -> Pillola.Tono {
        switch g {
        case .sopra: return .ok
        case .sotto: return .errore
        case .inLinea: return .neutro
        }
    }

    // MARK: Metro

    /// La scelta della posizione; un metro che non c'è più (indice eliminato) vale come «del tipo».
    private func sceltaMetro(_ tabella: TabellaRiferimenti) -> Binding<String?> {
        let id = posizione.id
        let attuale = posizione.riferimento.flatMap { tabella.serie($0) == nil ? nil : $0 }
        return Binding(get: { attuale },
                       set: { stato.scegliRiferimento($0, per: id) })
    }

    /// Prima «del tipo» (il metro delle impostazioni o di Prisma), poi tutte le serie della tabella.
    private func opzioni(_ tabella: TabellaRiferimenti, impostazioni: RiferimentiRendimento,
                         famiglia: FamigliaRiferimento) -> [(String?, String)] {
        // Spezzato per il controllo dei tipi: `serie` è sia proprietà sia funzione di TabellaRiferimenti
        let sceltaTipo: SerieRiferimento? = impostazioni.scelta(per: famiglia).flatMap { id in tabella.serie(id) }
        let predefinita: SerieRiferimento? = tabella.serie(famiglia.seriePredefinita)
        let delTipo: SerieRiferimento = sceltaTipo ?? predefinita ?? TabellaRiferimenti.serieInflazione
        let tutte: [SerieRiferimento] = tabella.serie
        return [(nil, T.opzionePredefinita(delTipo))] + tutte.map { (Optional($0.id), $0.nome) }
    }

    // MARK: Contenuto

    private func tessere(_ c: ConfrontoRiferimento) -> some View {
        let testa = T.kpiPosizione(annuo: c.annuo)
        return FasciaKPI {
            KPI(titolo: testa.titolo, valore: CifreDoc.variazione(c.effettivo)) {
                Text(testa.nota)
            }
            KPI(titolo: c.serie.nome, valore: c.riferimento.map { CifreDoc.variazione($0) } ?? T.segnaposto) {
                Text(T.kpiRiferimento(c.serie, stimati: c.fattore.stimati))
            }
            KPI(titolo: T.kpiDifferenza, valore: c.scarto.map(MotoreAndamento.punti) ?? T.segnaposto,
                ultimo: c.versamenti == nil) {
                Text(T.notaDifferenza(c))
            }
            if let v = c.versamenti {
                KPI(titolo: T.kpiVersamenti(c.serie), valore: CifreDoc.euro(v.valoreRiferimento), ultimo: true) {
                    Text(T.notaVersamenti(v))
                }
                .help(T.aiutoVersamenti(v, c.serie))
            }
        }
    }

    private func legenda(_ c: ConfrontoRiferimento) -> some View {
        HStack(spacing: M.spazioLegenda) {
            LegendaLinea(colore: K.valore, testo: T.legendaValore)
            if c.punti.contains(where: { $0.atteso != nil }) {
                LegendaLinea(colore: K.linea, testo: T.legendaLinea(c.serie))
            }
            if c.punti.contains(where: { $0.versato != nil }) {
                LegendaLinea(colore: K.versato, testo: T.legendaVersato, tratteggio: true)
            }
        }
    }

    /// Un gettone per anno del periodo («2025 · +2,5% · inserito da te»), a righe di `gettoniPerRiga`.
    private func gettoni(_ c: ConfrontoRiferimento) -> some View {
        let anni = c.fattore.anni
        let righe = stride(from: 0, to: anni.count, by: M.gettoniPerRiga).map { Array(anni[$0..<min($0 + M.gettoniPerRiga, anni.count)]) }
        return VStack(alignment: .leading, spacing: M.spazioAnni) {
            ForEach(Array(righe.enumerated()), id: \.offset) { _, riga in
                HStack(spacing: M.spazioAnni) {
                    ForEach(riga) { a in
                        Chip(testo: T.gettoneAnno(a))
                    }
                }
            }
        }
        .help(c.serie.fonte)
    }

    /// Il confronto non si può fare: quali valori mancano e dove inserirli.
    private func avviso(_ c: ConfrontoRiferimento) -> some View {
        VStack(alignment: .leading, spacing: M.spazioAvviso) {
            ForEach(messaggi(c), id: \.self) { testo in
                Text(testo)
                    .font(F.nota)
                    .foregroundColor(K.avviso)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !stato.inModoCliente {
                collegamentoImpostazioni
            }
        }
        .padding(M.margineAvviso)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FormaVetro.arrotondata(Tema.Raggio.Riferimenti.avviso).fill(K.fondoAvviso) }
    }

    private func messaggi(_ c: ConfrontoRiferimento) -> [String] {
        guard let ultimo = c.fattore.ultimoAnno else { return [T.daAggiornare(c.serie, ultimo: nil)] }
        var elenco: [String] = []
        if !c.fattore.mancanti.isEmpty { elenco.append(T.mancanti(c.fattore.mancanti, c.serie)) }
        if c.fattore.daAggiornare { elenco.append(T.daAggiornare(c.serie, ultimo: ultimo)) }
        return elenco.isEmpty ? [T.daAggiornare(c.serie, ultimo: ultimo)] : elenco
    }

    /// Ripiego, anni stimati, versamenti senza valori e la frase di sintesi.
    @ViewBuilder
    private func note(_ c: ConfrontoRiferimento, tabella: TabellaRiferimenti, famiglia: FamigliaRiferimento) -> some View {
        if !c.sceltaRispettata, let voluta = tabella.serie(famiglia.seriePredefinita) {
            Text(T.ripiego(voluta))
                .font(F.nota)
                .foregroundColor(K.avviso)
                .fixedSize(horizontal: false, vertical: true)
        }
        if c.riferimento != nil {
            if !c.fattore.stimati.isEmpty, let ultimo = c.fattore.ultimoAnno {
                testoNota(T.stimati(c.fattore.stimati, ultimo: ultimo))
            }
            if c.versamenti == nil, let anno = c.versamentiMancantiDal {
                VStack(alignment: .leading, spacing: M.spazioTesti) {
                    testoNota(T.versamentiMancanti(dal: anno))
                    if !stato.inModoCliente {
                        collegamentoImpostazioni
                    }
                }
            }
            testoNota(T.sintesi(c, nome: posizione.nome))
        }
    }

    private func testoNota(_ testo: String) -> some View {
        Text(testo)
            .font(F.nota)
            .foregroundColor(K.nota)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var collegamentoImpostazioni: some View {
        Button(T.apriImpostazioni) {
            stato.schedaImpostazioni = .riferimenti
            stato.apri(.impostazioni)
        }
        .buttonStyle(StileSemplice())
        .font(F.collegamento)
        .foregroundColor(K.collegamento)
    }

    private func apriTFR() {
        stato.clienteAttivoId = posizione.clienteId
        stato.schedaSimulazioni = .tfr
        stato.apri(.simulazioni)
    }
}
