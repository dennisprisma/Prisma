import Foundation

/// Parlare con Eve: il microfono, la risposta a voce e la conversazione che continua finché non le dici «basta».
/// L'ascolto e la voce lavorano sul Mac; il testo segue la stessa strada delle domande scritte.
extension StatoShell {
    /// Il pulsante del microfono (e ⌥⌘E): se Eve ascolta, chiude la frase e la manda; se parla, la ferma e
    /// ascolta; altrimenti inizia ad ascoltare. Dal menu, a conversazione a voce aperta, la chiude.
    func alternaAscolto(daMenu: Bool = false) {
        guard persistente, !bloccato, presentazione == nil else { return }
        if ascoltoEve.ascolta {
            ascoltoEve.ferma(invia: true)
            return
        }
        if daMenu, conversazioneAVoce {
            fermaVoce()
            return
        }
        if !aperta(.eve) || appAttiva != .eve { apri(.eve) }
        ascolta()
    }

    /// Eve si mette in ascolto (smettendo di parlare).
    func ascolta() {
        guard persistente, !eveInCorso else { return }
        voceEve.zitta()
        ascoltoEve.azzera()
        ascoltoEve.concluso = { [weak self] frase in self?.fraseDetta(frase) }
        ascoltoEve.avvia()
    }

    /// Chiude la conversazione a voce: Eve smette di ascoltare e di parlare.
    func fermaVoce() {
        conversazioneAVoce = false
        rispostaAVoce = false
        guard persistente else { return }
        ascoltoEve.ferma(invia: false)
        voceEve.zitta()
    }

    /// Una frase detta a Eve: diventa una domanda come quelle scritte, con la risposta anche a voce.
    func fraseDetta(_ frase: String) {
        let eve = dati.impostazioni.eve
        if CongedoEve.e(frase) {
            conversazioneAVoce = false
            rispostaAVoce = false
            if persistente, eve.risposteAVoce != .mai {
                voceEve.finito = nil
                voceEve.di("Va bene. Sono qui quando ti servo.", voce: eve.voce, velocita: eve.velocitaVoce)
            }
            return
        }
        rispostaAVoce = eve.risposteAVoce != .mai
        conversazioneAVoce = eve.conversazioneContinua && eve.risposteAVoce != .mai
        let chiave = evePortafoglio ? EvePortafoglio.chiave : clienteAttivoId
        let ultimo = conversazione(chiave).last?.id
        if evePortafoglio { chiediEvePortafoglio(frase) } else { chiediEve(frase) }
        // Se la domanda non è partita (Eve era già al lavoro, nessun cliente), niente attesa a vuoto
        if conversazione(chiave).last?.id == ultimo {
            rispostaAVoce = false
            conversazioneAVoce = false
        }
    }

    /// Dice a voce una risposta di Eve, se la domanda è arrivata a voce o se le risposte a voce sono sempre attive.
    /// A conversazione aperta, finita la risposta Eve torna ad ascoltare.
    func parlaRisposta(_ m: MessaggioEve) {
        let eve = dati.impostazioni.eve
        let aVoce = eve.risposteAVoce == .sempre || (rispostaAVoce && eve.risposteAVoce != .mai)
        rispostaAVoce = false
        guard persistente, aVoce else {
            conversazioneAVoce = false
            return
        }
        voceEve.finito = { [weak self] in
            guard let self, self.conversazioneAVoce, !self.bloccato, self.presentazione == nil else { return }
            self.ascolta()
        }
        voceEve.di(TestoParlato.da(titolo: m.titolo, testo: m.testo, completo: eve.leggiTutto), voce: eve.voce, velocita: eve.velocitaVoce)
    }

    /// Fa ascoltare la voce scelta (dalle impostazioni).
    func provaVoce() {
        guard persistente else { return }
        let eve = dati.impostazioni.eve
        voceEve.finito = nil
        voceEve.di("Ciao \(nomeUtente), sono Eve. Dimmi pure: ti preparo quello che serve.", voce: eve.voce, velocita: eve.velocitaVoce)
    }
}
