import AppKit
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
        ascoltoEve.problema = { [weak self] motivo in self?.problemaAscolto(motivo) }
        ascoltoEve.avvia(dati.impostazioni.eve.riconoscimento)
    }

    /// Eve non ha potuto ascoltare o capire: lo scrive nella conversazione, dove si vede, con cosa fare.
    func problemaAscolto(_ motivo: String) {
        conversazioneAVoce = false
        rispostaAVoce = false
        let chiave = evePortafoglio ? EvePortafoglio.chiave : clienteAttivoId
        // Lo stesso avviso due volte di fila non serve
        guard conversazione(chiave).last?.testo != motivo else { return }
        aggiungiMessaggio(MessaggioEve(autore: .eve, testo: motivo, titolo: "Non riesco ad ascoltarti", motore: "Voce"), cliente: chiave)
        // Detto anche a voce, in breve: chi parla a Eve non sempre guarda lo schermo
        let eve = dati.impostazioni.eve
        if persistente, eve.risposteAVoce != .mai {
            voceEve.finito = nil
            voceEve.di("Scusa, non sono riuscita a capirti. Ti ho scritto il motivo.", voce: eve.voce, velocita: eve.velocitaVoce)
        }
    }

    /// Prova il riconoscimento senza microfono: la voce di Eve dice una frase e si vede cosa capisce,
    /// prima con il riconoscimento nuovo, poi con la dettatura classica.
    func provaRiconoscimento() {
        guard persistente, esitoProvaRiconoscimento != "In prova…" else { return }
        esitoProvaRiconoscimento = "In prova…"
        let prima = ProvaRiconoscimento()
        provaInCorso = prima
        prima.esegui(.nuovo) { [weak self] nuovo in
            let seconda = ProvaRiconoscimento()
            self?.provaInCorso = seconda
            seconda.esegui(.classico) { classico in
                self?.esitoProvaRiconoscimento = nuovo + "\n" + classico
                self?.provaInCorso = nil
            }
        }
    }

    /// Copia la diagnostica dell'ascolto, da mandare a chi sistema Prisma (niente audio né frasi dette).
    func copiaDiagnosticaVoce() {
        let testo = DiagnosticaVoce.testo + (esitoProvaRiconoscimento.map { "\n\nProva: " + $0 } ?? "")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(testo, forType: .string)
        mostraAvviso("Diagnostica copiata: incollala nel messaggio")
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
