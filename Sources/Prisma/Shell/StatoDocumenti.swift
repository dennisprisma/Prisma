#if os(macOS)
import AppKit
#endif
import Foundation

/// Che cosa creare da un documento (modulo «Crea…» e azione principale del dettaglio).
enum CreaDaDocumento { case scheda, posizione, proposta }

/// Lo stato dell'app Documenti (giro 5): elenco con stato e collegamento, categoria, dati scritti a mano, confronto dei
/// documenti del cliente (identità e questionari) con il dossier. Collegare, confrontare con posizioni e schede,
/// aggiornare e ripristinare sono della specifica 9 (StatoConfrontoDossier.swift) e qui non si riscrivono.
extension StatoShell {
    // MARK: - Lettura

    /// Le voci dell'elenco di un cliente (stato, canale e nome del bersaglio predefinito). Riguarda i documenti di un
    /// cliente solo (pochi): niente cache.
    func vociDocumenti(_ cliente: String) -> [MotoreDocumenti.Voce] {
        documentiCliente(cliente).map { d in
            var collegato = false
            var differenze = 0
            var canale: Canale?
            var nome: String?
            if MotoreDocumenti.delCliente(d) {
                // Identità e questionari sono del cliente per natura: il dossier c'è sempre
                collegato = true
                differenze = (confrontoCliente(d, canale: MotoreDocumenti.canaleQuestionario(d)) ?? [])
                    .filter { $0.aggiornabile && $0.esito != .uguale }.count
            } else if d.genere == .prisma {
                // Prospetti e report: niente da collegare né da confrontare
            } else if MotoreConfrontoDossier.confrontabile(d) {
                if let b = bersagli(d).first {
                    collegato = true
                    differenze = confronto(d, b)?.differenze ?? 0
                    if let n = nomeBersaglio(b) {
                        nome = n.nome
                        canale = n.canale
                    }
                }
            } else if let pid = d.posizioneId, let p = dati.posizioni.first(where: { $0.id == pid }) {
                collegato = true
                nome = p.nome
                canale = p.canale
            }
            let indicatori = MotoreDocumenti.indicatori(d, inLettura: documentiInLettura.contains(d.id),
                                                        collegato: collegato, differenze: differenze)
            return MotoreDocumenti.Voce(documento: d, indicatori: indicatori, canale: canale, nomeCollegato: nome)
        }
    }

    /// Le righe «Nel documento / Nel dossier» di un documento del cliente (nil se non è identità o questionario o se il
    /// cliente non c'è). `canale` = quello scelto nella vista o `canaleQuestionario`.
    func confrontoCliente(_ d: Documento, canale: Canale?) -> [MotoreDocumenti.RigaCliente]? {
        guard MotoreDocumenti.delCliente(d), let c = dati.clienti.first(where: { $0.id == d.clienteId }) else { return nil }
        return MotoreDocumenti.righeCliente(d, cliente: c, canale: canale)
    }

    /// Il bersaglio da mostrare nella barra e nell'elenco: per KID e polizze il predefinito della specifica 9, per gli
    /// altri documenti la posizione collegata (estratti conto), se c'è ancora.
    func collegamentoMostrato(_ d: Documento) -> BersaglioConfronto? {
        if MotoreDocumenti.delCliente(d) || d.genere == .prisma { return nil }
        if MotoreConfrontoDossier.confrontabile(d) { return bersagli(d).first }
        guard let pid = d.posizioneId, dati.posizioni.contains(where: { $0.id == pid }) else { return nil }
        return .posizione(pid)
    }

    /// Apre la posizione o la scheda prodotto di un bersaglio.
    func apriCollegamentoDocumento(_ b: BersaglioConfronto) {
        switch b {
        case .posizione(let id):
            if let p = dati.posizioni.first(where: { $0.id == id }) { apriPosizione(p) }
        case .prodotto(let id):
            guard prodotto(id) != nil else { return }
            prodottoSelezionato = id
            apri(.prodotti)
        }
    }

    /// Il valore di un estratto conto pronto per lo storico (con i dati del valore anche non ancora confermati) e la
    /// posizione a cui va: quella collegata o la più probabile. nil se manca qualcosa o se c'è già.
    func valoreEstrattoDaRegistrare(_ d: Documento) -> (valore: ValoriDaDocumento.Valore, posizione: Posizione)? {
        guard ValoriDaDocumento.pertinente(d) else { return nil }
        var copia = d
        for i in copia.campi.indices where Self.campiDelValore.contains(copia.campi[i].chiave) { copia.campi[i].confermato = true }
        guard let v = ValoriDaDocumento.valore(copia),
              let p = ValoriDaDocumento.posizioneProbabile(copia, tra: dati.posizioni),
              !ValoriDaDocumento.registrato(v, in: p) else { return nil }
        return (v, p)
    }

    private static let campiDelValore: Set<CampoDocumento> = [.controvalore, .dataValore, .totaleVersato]

    // MARK: - Scritture

    /// Cambia la categoria scelta dal consulente (e il tipo che ne segue). Prospetti e report restano di Prisma.
    func impostaCategoria(_ id: String, _ c: CategoriaDocumento) {
        guard !solaLettura, c.selezionabile else { return }
        aggiornaDocumento(id) { d in
            guard !d.tipo.creatoDaPrisma else { return }
            d.categoria = c
            d.tipo = c.tipo(da: d.tipo)
        }
    }

    /// Porta nel cliente le righe scelte di un documento d'identità o di un questionario e conferma nel documento i
    /// dati portati.
    func aggiornaClienteDaDocumento(_ id: String, campi: Set<CampoDocumento>, canale: Canale?) {
        guard !solaLettura else {
            mostraAvviso("Archivio in sola lettura: aggiorna Prisma per cambiare il dossier.")
            return
        }
        guard let d = documento(id), var c = dati.clienti.first(where: { $0.id == d.clienteId }) else { return }
        let applicati = MotoreDocumenti.applicaCliente(campi, da: d, a: &c, canale: canale)
        guard !applicati.isEmpty else { return }
        salvaCliente(c)
        aggiornaDocumento(id) { x in
            for i in x.campi.indices where applicati.contains(x.campi[i].chiave) { x.campi[i].confermato = true }
        }
        let nomi = applicati.map { Self.nomeNellaFrase($0.nome) }.joined(separator: ", ")
        mostraAvviso(applicati.count == 1
                     ? "Aggiornato 1 dato nel dossier di «\(c.nome)»: \(nomi)"
                     : "Aggiornati \(applicati.count) dati nel dossier di «\(c.nome)»: \(nomi)")
    }

    /// Un dato scritto a mano dal consulente: pagina 0, «A mano», confermato. Se il dato c'è già lo corregge.
    func aggiungiCampo(_ id: String, _ chiave: CampoDocumento, valore: String) {
        guard !solaLettura else { return }
        let v = valore.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty, let d = documento(id) else { return }
        if d.campo(chiave) != nil {
            modificaCampo(id, chiave, valore: v)
            return
        }
        aggiornaDocumento(id) { x in
            x.campi.append(CampoEstratto(chiave: chiave, valore: v, pagina: 0, estratto: "", origine: "A mano", confermato: true))
            // Nell'ordine dei dati di Prisma, come li restituiscono le regole
            let ordine = CampoDocumento.allCases
            x.campi.sort { (ordine.firstIndex(of: $0.chiave) ?? 0) < (ordine.firstIndex(of: $1.chiave) ?? 0) }
        }
    }

    /// Toglie un dato (rileggendo, un dato delle regole può tornare).
    func togliCampo(_ id: String, _ chiave: CampoDocumento) {
        guard !solaLettura else { return }
        aggiornaDocumento(id) { $0.campi.removeAll { $0.chiave == chiave } }
    }

    /// Conferma tutti i dati letti (la vista scrive prima i testi in attesa con `TestiRinviati.scriviOra()`).
    func confermaTutti(_ id: String) {
        guard !solaLettura else { return }
        aggiornaDocumento(id) { d in
            for i in d.campi.indices { d.campi[i].confermato = true }
        }
    }

    /// «Aggiorna il valore» di un estratto conto: conferma controvalore, data e versato e li porta nello storico della
    /// posizione collegata o della più probabile (che resta collegata).
    func aggiornaValoreDaDocumento(_ id: String) {
        guard !solaLettura else {
            mostraAvviso("Archivio in sola lettura: aggiorna Prisma per registrare il valore.")
            return
        }
        guard let d = documento(id) else { return }
        guard let pronto = valoreEstrattoDaRegistrare(d) else {
            mostraAvviso("Collega l'estratto a una posizione in essere del cliente, poi registra il valore.")
            return
        }
        aggiornaDocumento(id) { x in
            for i in x.campi.indices where Self.campiDelValore.contains(x.campi[i].chiave) { x.campi[i].confermato = true }
        }
        registraValore(daDocumento: id, posizione: pronto.posizione.id)
    }

    /// Crea dal documento una scheda prodotto, una posizione in essere o una proposta (con la scheda, se manca).
    func creaDaDocumento(_ id: String, cosa: CreaDaDocumento, canale: Canale, area: AreaPosizione, confermaPrima: Bool) {
        guard !solaLettura else {
            mostraAvviso("Archivio in sola lettura: aggiorna Prisma per creare schede e posizioni.")
            return
        }
        guard let d = documento(id) else { return }
        if confermaPrima { confermaTutti(id) }
        switch cosa {
        case .scheda:
            creaProdotto(da: id, canale: canale, area: area)
        case .posizione:
            creaPosizione(da: id, canale: canale, area: area)
        case .proposta:
            if prodotto(d.prodottoId) == nil { creaProdotto(da: id, canale: canale, area: area) }
            guard let p = prodotto(documento(id)?.prodottoId) else { return }
            clienteAttivoId = d.clienteId
            proponi(p)
        }
    }

    /// Il rilascio e «+»: i formati letti da Prisma entrano, gli altri si dicono.
    func aggiungiDocumenti(_ urls: [URL]) {
        let accettati = urls.filter { LetturaDocumenti.estensioniAccettate.contains($0.pathExtension.lowercased()) }
        let rifiutati = urls.filter { !LetturaDocumenti.estensioniAccettate.contains($0.pathExtension.lowercased()) }
        if let primo = rifiutati.first {
            let formati = "Prisma legge PDF e immagini (PNG, JPEG, TIFF, HEIC)"
            mostraAvviso(rifiutati.count == 1
                         ? "\(primo.lastPathComponent) non si può aggiungere: \(formati)"
                         : "\(rifiutati.count) file non si possono aggiungere: \(formati)")
        }
        if !accettati.isEmpty { importaDocumenti(accettati) }
    }

    /// Mostra il file del documento nel Finder, se c'è.
    func mostraNelFinder(_ d: Documento) {
        guard let url = urlDocumento(d), FileManager.default.fileExists(atPath: url.path) else {
            mostraAvviso("Il documento non ha un file sul Mac.")
            return
        }
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #elseif os(iOS)
        // Su iPhone e iPad il Finder non c'è
        mostraAvviso(StatoShell.soloSulMacPerOra)
        #endif
    }

    /// Il nome di un dato nel corso di una frase: l'iniziale minuscola, le sigle restano («codice ISIN»).
    private static func nomeNellaFrase(_ s: String) -> String {
        guard let prima = s.first else { return s }
        return prima.lowercased() + s.dropFirst()
    }
}
