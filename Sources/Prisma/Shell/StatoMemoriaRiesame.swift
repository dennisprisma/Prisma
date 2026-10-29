import Foundation

// Riesame con memoria (specifica 12 §5.1): fotografie dei riesami nello stato. La memoria di un cliente sta in
// cache in DerivatiDati (`memorie`): una fotografia nuova cambia i dati dei calcoli, quindi la cache si rifà da sola.
// Gli agganci (chiusura di un incontro, appuntamento di revisione concluso, eliminazione del cliente, prospetto del
// riesame) stanno in StatoShell.swift; le uscite del prospetto in AppProspetti.swift.

extension StatoShell {
    /// Le fotografie salvate di un cliente, dalla più recente.
    func fotografieCliente(_ id: String) -> [FotografiaRiesame] {
        MotoreMemoria.cronologia(dati.fotografie, cliente: id)
    }

    /// La fotografia delle cifre di oggi (non salvata): fonte del cliente, completezza (giro 3) e conformità (giro 4).
    func fotografiaAttuale(_ id: String, origine: FotografiaRiesame.Origine = .manuale) -> FotografiaRiesame? {
        guard let f = fonteEve(id) else { return nil }
        let completezza = completezzaCliente(id).map {
            DatiCompletezzaFoto(percentuale: $0.percentuale, livello: $0.livello.nome)
        }
        let conformita: [FotografiaRiesame.VoceConformitaFoto]? = conformitaCliente(id).map { e in
            e.voci.filter { $0.stato != .nonRichiesta }.map {
                FotografiaRiesame.VoceConformitaFoto(tipo: $0.tipo.rawValue, titolo: TestiConformita.nome($0.tipo),
                                                     canale: $0.canale, stato: Self.nomeStatoFoto($0.stato))
            }
        }
        return MotoreMemoria.fotografia(f, origine: origine, completezza: completezza, conformita: conformita)
    }

    /// La memoria del riesame (in cache in DerivatiDati.memorie).
    func memoriaRiesame(_ id: String) -> MemoriaRiesame? {
        let d = derivatiValidi()
        if let m = d.memorie[id] { return m }
        guard let attuale = fotografiaAttuale(id) else { return nil }
        let m = MotoreMemoria.memoria(attuale: attuale, fotografie: dati.fotografie, oggi: Date())
        d.memorie[id] = m
        return m
    }

    /// Salva la fotografia di oggi. Non fa niente in sola lettura o se il cliente non c'è.
    /// `oggi` serve alle prove: le cifre sono quelle di adesso, la data è `oggi`.
    /// Restituisce la fotografia registrata (con l'id di quella sostituita, se di meno di 30 giorni prima).
    @discardableResult
    func fotografaRiesame(_ id: String, origine: FotografiaRiesame.Origine, oggi: Date = Date(), avviso: Bool = true) -> FotografiaRiesame? {
        guard !solaLettura, var foto = fotografiaAttuale(id, origine: origine) else { return nil }
        let cal = Calendar.current
        foto.data = cal.startOfDay(for: oggi)
        let prima = dati.fotografie
        let elenco = MotoreMemoria.registra(foto, in: prima, cal: cal)
        dati.fotografie = elenco
        let registrata = elenco.first { $0.id == foto.id }
            ?? elenco.last { $0.clienteId == id && $0.data == foto.data }
        if avviso, let r = registrata {
            if r.id != foto.id, let vecchia = prima.first(where: { $0.id == r.id }) {
                mostraAvviso(TestiMemoria.avvisoSostituita(data: vecchia.data))
            } else {
                mostraAvviso(TestiMemoria.avvisoSalvata(data: r.data))
            }
        }
        return registrata
    }

    /// Elimina una fotografia (scheda Riesami del cliente).
    func eliminaFotografia(_ fotoId: String) {
        dati.fotografie.removeAll { $0.id == fotoId }
    }

    /// Un incontro di revisione: l'appuntamento collegato è `.revisione`, oppure il titolo contiene «riesame»
    /// o «revisione» (senza maiuscole).
    func incontroDiRiesame(_ i: Incontro) -> Bool {
        if let aid = i.appuntamentoId, let a = dati.appuntamenti.first(where: { $0.id == aid }), a.tipo == .revisione {
            return true
        }
        let titolo = i.titolo.lowercased()
        return titolo.contains("riesame") || titolo.contains("revisione")
    }

    /// Lo stato di una voce di conformità come si salva nella fotografia: l'unico punto che conosce il tipo del
    /// giro 4 (le voci non richieste non si salvano).
    private static func nomeStatoFoto(_ s: VoceConformita.Stato) -> String {
        switch s {
        case .scaduta: return "scaduta"
        case .mancante: return "mancante"
        case .entro30: return "entro30"
        case .entro60: return "entro60"
        case .inRegola: return "inRegola"
        case .nonRichiesta: return "nonRichiesta"
        }
    }
}
