import Foundation

/// I metri di confronto dei rendimenti (giro 6, specifica 11, §5): la tabella costruita dalle impostazioni e le
/// scritture del pannello del dettaglio e di Impostazioni › Riferimenti. Nessuna cache: la tabella costa pochi anni.
extension StatoShell {
    var tabellaRiferimenti: TabellaRiferimenti { TabellaRiferimenti(dati.impostazioni.riferimenti) }

    /// Metro scelto per una posizione (nil = quello del suo tipo). Scrive solo `riferimento`, senza storico.
    func scegliRiferimento(_ serie: String?, per posizioneId: String) {
        guard let i = dati.posizioni.firstIndex(where: { $0.id == posizioneId }),
              dati.posizioni[i].riferimento != serie else { return }
        dati.posizioni[i].riferimento = serie
    }

    /// Valore di un anno: nil toglie il valore del consulente (resta quello di Prisma, se c'è). Un valore uguale
    /// a quello di Prisma non si salva. Aggiorna `rivistiIl`. Il TFR si calcola dall'inflazione: non si scrive.
    func impostaRiferimento(_ serie: String, anno: Int, valore: Double?) {
        guard serie != SerieRiferimento.idTFR, !serie.isEmpty else { return }
        var r = dati.impostazioni.riferimenti
        r.valori.removeAll { $0.serie == serie && $0.anno == anno }
        if let v = valore, v.isFinite {
            let limitato = min(max(v, MotoreRiferimenti.valoreMinimo), MotoreRiferimenti.valoreMassimo)
            // Il valore di Prisma non si riscrive: resta di Prisma (e torna tale se cambia la fonte)
            let prisma = TabellaRiferimenti.valorePrisma(serie, anno: anno)
            if prisma.map({ abs($0 - limitato) > 1e-9 }) ?? true {
                r.valori.append(ValoreRiferimento(serie: serie, anno: anno, valore: limitato))
            }
        }
        guard r.valori != dati.impostazioni.riferimenti.valori else { return }
        r.valori.sort { $0.serie == $1.serie ? $0.anno < $1.anno : $0.serie < $1.serie }
        r.rivistiIl = Posizione.oggiArrotondato
        dati.impostazioni.riferimenti = r
    }

    /// Il metro di un tipo di posizione (nil = quello di Prisma).
    func impostaMetro(_ serie: String?, per famiglia: FamigliaRiferimento) {
        guard dati.impostazioni.riferimenti.scelta(per: famiglia) != serie else { return }
        switch famiglia {
        case .previdenza: dati.impostazioni.riferimenti.perPrevidenza = serie
        case .gestioneSeparata: dati.impostazioni.riferimenti.perGestioneSeparata = serie
        case .mercato: dati.impostazioni.riferimenti.perMercato = serie
        }
    }

    /// Aggiunge un indice «Nuovo indice» e ne restituisce l'id; nil oltre `RiferimentiRendimento.massimoIndici`.
    @discardableResult func aggiungiIndice() -> String? {
        guard dati.impostazioni.riferimenti.indici.count < RiferimentiRendimento.massimoIndici else { return nil }
        let indice = IndiceRiferimento(nome: TestiRiferimenti.nuovoIndice)
        dati.impostazioni.riferimenti.indici.append(indice)
        return indice.id
    }

    func rinominaIndice(_ id: String, nome: String, fonte: String) {
        guard let i = dati.impostazioni.riferimenti.indici.firstIndex(where: { $0.id == id }) else { return }
        let attuale = dati.impostazioni.riferimenti.indici[i]
        guard attuale.nome != nome || attuale.fonte != fonte else { return }
        dati.impostazioni.riferimenti.indici[i].nome = nome
        dati.impostazioni.riferimenti.indici[i].fonte = fonte
    }

    /// Toglie l'indice, i suoi valori e le scelte che lo usavano (impostazioni e posizioni).
    func eliminaIndice(_ id: String) {
        var d = dati
        d.impostazioni.riferimenti.indici.removeAll { $0.id == id }
        d.impostazioni.riferimenti.valori.removeAll { $0.serie == id }
        if d.impostazioni.riferimenti.perPrevidenza == id { d.impostazioni.riferimenti.perPrevidenza = nil }
        if d.impostazioni.riferimenti.perGestioneSeparata == id { d.impostazioni.riferimenti.perGestioneSeparata = nil }
        if d.impostazioni.riferimenti.perMercato == id { d.impostazioni.riferimenti.perMercato = nil }
        for i in d.posizioni.indices where d.posizioni[i].riferimento == id {
            d.posizioni[i].riferimento = nil
        }
        // Una sola scrittura: un solo salvataggio e un solo ridisegno
        if d != dati { dati = d }
    }

    func segnaRiferimentiRivisti() {
        dati.impostazioni.riferimenti.rivistiIl = Posizione.oggiArrotondato
    }
}
