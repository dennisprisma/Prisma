import SwiftUI

private typealias T = TestiRiferimenti
private typealias K = Tema.Colore.Riferimenti
private typealias M = Tema.Misura.Riferimenti
private typealias F = Tema.Testo.Riferimenti
private typealias R = Tema.Raggio.Riferimenti

/// Impostazioni › Riferimenti (giro 6, specifica 11, §7.4): il metro per tipo di posizione, la griglia dei valori
/// anno per anno (quelli di Prisma, quelli del consulente, il TFR calcolato), gli indici del consulente e le fonti.
/// I valori stanno nell'archivio e nel backup (`Impostazioni.riferimenti`).
struct ImpostazioniRiferimenti: View {
    @EnvironmentObject var stato: StatoShell
    /// L'indice aperto nel popover di modifica (anche quello appena aggiunto).
    @State private var indiceInModifica: String?
    /// L'indice da eliminare, dopo la conferma.
    @State private var daEliminare: String?

    var body: some View {
        let tabella = stato.tabellaRiferimenti
        let r = stato.dati.impostazioni.riferimenti
        VStack(alignment: .leading, spacing: Misure.Impostazioni.spazioGruppi) {
            Text(T.introduzione)
                .font(Tipo.informazioniTesto)
                .foregroundColor(Colori.Impostazioni.nota)
                .fixedSize(horizontal: false, vertical: true)
            metro(tabella, r)
            valori(tabella)
            indici(r)
            fonti(r)
        }
        .alert(T.confermaElimina(nomeDaEliminare(r)),
               isPresented: Binding(get: { daEliminare != nil }, set: { if !$0 { daEliminare = nil } })) {
            Button(T.annulla, role: .cancel) {}
            Button(T.elimina, role: .destructive) {
                if let id = daEliminare { stato.eliminaIndice(id) }
                daEliminare = nil
            }
        } message: {
            Text(T.spiegaElimina)
        }
    }

    // MARK: Il metro per tipo di posizione

    private func metro(_ tabella: TabellaRiferimenti, _ r: RiferimentiRendimento) -> some View {
        let tutte: [SerieRiferimento] = tabella.serie
        let opzioni: [(String?, String)] = [(nil, T.quelloDiPrisma)] + tutte.map { (Optional($0.id), $0.nome) }
        let famiglie = FamigliaRiferimento.allCases
        return GruppoImpostazioni(titolo: T.gruppoMetro) {
            ForEach(famiglie) { f in
                RigaImpostazione(titolo: f.nome,
                                 sottotitolo: tabella.serie(f.seriePredefinita).map(T.diPrisma),
                                 ultima: f == famiglie.last) {
                    MenuTendina(selezione: legameMetro(f, r, tabella), opzioni: opzioni, larghezza: M.tendinaImpostazioni)
                }
            }
        }
    }

    /// La scelta di una famiglia (nil = quello di Prisma; un indice eliminato torna a nil). Spezzato per il controllo dei tipi.
    private func legameMetro(_ f: FamigliaRiferimento, _ r: RiferimentiRendimento,
                             _ tabella: TabellaRiferimenti) -> Binding<String?> {
        let stato = self.stato
        return Binding<String?>(
            get: {
                guard let id = r.scelta(per: f), tabella.serie(id) != nil else { return nil }
                return id
            },
            set: { nuovo in stato.impostaMetro(nuovo, per: f) })
    }

    // MARK: La griglia dei valori

    private func valori(_ tabella: TabellaRiferimenti) -> some View {
        // Le tre serie di Prisma e al massimo tre indici
        let tutte: [SerieRiferimento] = tabella.serie
        let colonne = Array(tutte.prefix(3 + RiferimentiRendimento.massimoIndici))
        let annoCorrente = Calendar.current.component(.year, from: Date())
        let anni = Array(stride(from: annoCorrente, through: min(annoCorrente, RiferimentiStorici.annoMinimo), by: -1))
        return GruppoImpostazioni(titolo: T.gruppoValori) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(T.testaAnno)
                        .frame(width: M.colonnaAnno, alignment: .leading)
                    ForEach(colonne) { s in
                        Text(s.calcolata ? T.testaTFR : s.nome)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(minWidth: M.colonnaValoreMinima, maxWidth: M.colonnaValore, alignment: .trailing)
                            .help(s.fonte)
                    }
                }
                .font(F.testaGriglia)
                .foregroundColor(K.testa)
                .frame(height: M.rigaGriglia)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(K.filetto).frame(height: Tema.Misura.filo)
                }
                ForEach(Array(anni.enumerated()), id: \.element) { i, anno in
                    HStack(spacing: 0) {
                        Text(String(anno))
                            .font(F.annoGriglia)
                            .foregroundColor(Tema.Colore.inchiostro)
                            .frame(width: M.colonnaAnno, alignment: .leading)
                        ForEach(colonne) { s in
                            if s.calcolata {
                                CellaCalcolata(valore: tabella.valore(s.id, anno: anno))
                            } else {
                                CellaRiferimento(serie: s.id, anno: anno, valore: tabella.valore(s.id, anno: anno))
                            }
                        }
                    }
                    .frame(height: M.rigaGriglia)
                    .background(i % 2 == 1 ? K.rigaAlterna : Color.clear)
                }
                notaGriglia(tabella, colonne: colonne, annoCorrente: annoCorrente)
                    .padding(.top, M.spazioNotaGriglia)
            }
            .padding(M.margineGriglia)
        }
    }

    /// «Ultimo anno: …» e, se manca l'inflazione dell'anno appena chiuso, l'avviso in arancio.
    private func notaGriglia(_ tabella: TabellaRiferimenti, colonne: [SerieRiferimento], annoCorrente: Int) -> some View {
        let voci: [(nome: String, anno: Int?)] = colonne.filter { !$0.calcolata }.map { s in
            (nome: T.nomeBreve(s), anno: tabella.ultimoAnno(s.id))
        }
        let ultimaInflazione = tabella.ultimoAnno(SerieRiferimento.idInflazione)
        var mancanti: [Int] = []
        if let u = ultimaInflazione, u + 1 < annoCorrente { mancanti = Array((u + 1)..<annoCorrente) }
        return VStack(alignment: .leading, spacing: M.spazioTesti) {
            Text(T.ultimiAnni(voci))
                .font(F.nota)
                .foregroundColor(K.nota)
                .fixedSize(horizontal: false, vertical: true)
            if !mancanti.isEmpty {
                Text(T.inflazioneDaAggiornare(mancanti))
                    .font(F.nota)
                    .foregroundColor(K.avviso)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Indici

    private func indici(_ r: RiferimentiRendimento) -> some View {
        let mostrati = Array(r.indici.prefix(RiferimentiRendimento.massimoIndici))
        let pieni = r.indici.count >= RiferimentiRendimento.massimoIndici
        return GruppoImpostazioni(titolo: T.gruppoIndici) {
            ForEach(mostrati) { i in
                rigaIndice(i)
            }
            RigaImpostazione(titolo: T.aggiungiIndice, sottotitolo: pieni ? T.massimoIndici : nil, ultima: true) {
                ValoreRiga(testo: T.aggiungi) {
                    if let id = stato.aggiungiIndice() { indiceInModifica = id }
                }
                .disabled(pieni)
            }
        }
    }

    private func rigaIndice(_ i: IndiceRiferimento) -> some View {
        let aperto = Binding<Bool>(get: { indiceInModifica == i.id },
                                   set: { if !$0, indiceInModifica == i.id { indiceInModifica = nil } })
        let id = i.id
        return RigaImpostazione(titolo: i.nome.isEmpty ? T.indiceSenzaNome : i.nome,
                                sottotitolo: i.fonte.isEmpty ? T.fonteNonIndicata : i.fonte) {
            ValoreRiga(testo: T.modifica) { indiceInModifica = id }
                .popover(isPresented: aperto, arrowEdge: .leading) {
                    ModuloIndice(indiceId: id,
                                 chiudi: { indiceInModifica = nil },
                                 elimina: {
                                     indiceInModifica = nil
                                     daEliminare = id
                                 })
                        .environmentObject(stato)
                }
        }
    }

    private func nomeDaEliminare(_ r: RiferimentiRendimento) -> String {
        guard let id = daEliminare, let i = r.indici.first(where: { $0.id == id }) else { return "" }
        return i.nome.isEmpty ? T.indiceSenzaNome : i.nome
    }

    // MARK: Fonti

    private func fonti(_ r: RiferimentiRendimento) -> some View {
        let diPrisma = [TabellaRiferimenti.serieInflazione, TabellaRiferimenti.serieTFR, TabellaRiferimenti.serieGestioniSeparate]
        return GruppoImpostazioni(titolo: T.gruppoFonti) {
            ForEach(diPrisma) { s in
                RigaImpostazione(titolo: s.nome, sottotitolo: s.fonte) { EmptyView() }
            }
            RigaImpostazione(titolo: T.valoriRivisti, sottotitolo: T.ultimaRevisione(r.rivistiIl), ultima: true) {
                ValoreRiga(testo: T.segnaRivisti) { stato.segnaRiferimentiRivisti() }
            }
        }
    }
}

// MARK: - Celle della griglia

/// Le cifre della griglia: fino a due decimali, separatori italiani, senza il simbolo (la testata dice %).
private let formatoCella = FloatingPointFormatStyle<Double>.number.locale(Formati.localeImporti).precision(.fractionLength(0...2))

/// Una cella modificabile: il valore del consulente (blu, con il pallino) o quello di Prisma (inchiostro).
/// Vuota = nil: si toglie il valore del consulente e torna quello di Prisma, se c'è.
private struct CellaRiferimento: View {
    @EnvironmentObject var stato: StatoShell
    let serie: String
    let anno: Int
    let valore: ValoreAnnuo?

    var body: some View {
        let inserito = valore?.origine == .consulente
        let prisma = TabellaRiferimenti.valorePrisma(serie, anno: anno)
        let forma = FormaVetro.arrotondata(R.cella)
        HStack(spacing: M.spazioPallino) {
            Circle()
                .fill(inserito ? K.inseritoDaTe : Color.clear)
                .frame(width: M.pallino, height: M.pallino)
            TextField("", value: legame, format: formatoCella, prompt: Text(T.segnaposto))
                .textFieldStyle(.plain)
                .font(inserito ? F.cellaGrigliaInserita : F.cellaGriglia)
                .foregroundColor(inserito ? K.inseritoDaTe : K.valorePrisma)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, M.margineCella)
        .frame(height: M.pozzettoCella)
        .background { forma.fill(K.pozzetto) }
        .overlay { forma.strokeBorder(K.bordoPozzetto, lineWidth: Tema.Misura.filo).allowsHitTesting(false) }
        .padding(.horizontal, M.margineCellaEsterno)
        .frame(minWidth: M.colonnaValoreMinima, maxWidth: M.colonnaValore)
        .contextMenu {
            // Il consulente ha coperto un valore di Prisma: si può tornare a quello
            if inserito, let p = prisma {
                Button(T.tornaAPrisma(p)) { stato.impostaRiferimento(serie, anno: anno, valore: nil) }
            }
        }
    }

    /// Il valore della cella (spezzato per il controllo dei tipi): vuoto = nil, torna quello di Prisma.
    private var legame: Binding<Double?> {
        let stato = self.stato
        let serie = self.serie
        let anno = self.anno
        let attuale: Double? = valore?.valore
        return Binding<Double?>(get: { attuale },
                                set: { nuovo in stato.impostaRiferimento(serie, anno: anno, valore: nuovo) })
    }
}

/// La cella del TFR: calcolata dall'inflazione dello stesso anno, in grigio, sola lettura.
private struct CellaCalcolata: View {
    let valore: ValoreAnnuo?

    var body: some View {
        Text(valore.map { $0.valore.formatted(formatoCella) } ?? T.segnaposto)
            .font(F.cellaGriglia)
            .foregroundColor(K.calcolato)
            .lineLimit(1)
            .padding(.horizontal, M.margineCella + M.margineCellaEsterno)
            .frame(minWidth: M.colonnaValoreMinima, maxWidth: M.colonnaValore, alignment: .trailing)
            .help(RiferimentiStorici.fonteTFR)
    }
}

// MARK: - Popover di un indice

/// Nome e fonte di un indice, cercato per id (l'elenco può cambiare mentre il popover è aperto), ed eliminazione.
private struct ModuloIndice: View {
    @EnvironmentObject var stato: StatoShell
    let indiceId: String
    let chiudi: () -> Void
    let elimina: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: M.spazioPopover) {
            campo(T.campoNome) {
                TestoRinviato(testo: legame(\.nome), salvaOra: { stato.salvaOra() }) { bozza in
                    TextField(T.campoNome, text: bozza)
                        .campoTesto()
                }
            }
            campo(T.campoFonte) {
                TestoRinviato(testo: legame(\.fonte), salvaOra: { stato.salvaOra() }) { bozza in
                    TextField(T.campoFonte, text: bozza)
                        .campoTesto()
                }
            }
            HStack {
                Button(action: elimina) {
                    Text(T.eliminaIndice).foregroundColor(K.elimina)
                }
                .buttonStyle(StileVetro(margine: M.marginePulsante))
                Spacer()
                Button(T.fatto) { chiudi() }
                    .buttonStyle(StileBlu())
            }
        }
        .padding(M.marginePopover)
        .frame(width: M.larghezzaPopover, alignment: .leading)
        .id(indiceId)
    }

    private func legame(_ chiave: WritableKeyPath<IndiceRiferimento, String>) -> Binding<String> {
        let id = indiceId
        return Binding(
            get: { stato.dati.impostazioni.riferimenti.indici.first { $0.id == id }?[keyPath: chiave] ?? "" },
            set: { nuovo in
                guard var i = stato.dati.impostazioni.riferimenti.indici.first(where: { $0.id == id }) else { return }
                i[keyPath: chiave] = nuovo
                stato.rinominaIndice(id, nome: i.nome, fonte: i.fonte)
            })
    }

    private func campo<Contenuto: View>(_ titolo: String, @ViewBuilder _ contenuto: () -> Contenuto) -> some View {
        VStack(alignment: .leading, spacing: M.spazioCampo) {
            Text(titolo)
                .font(F.campo)
                .foregroundColor(K.nota)
            contenuto()
        }
    }
}
