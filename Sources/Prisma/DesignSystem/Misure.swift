import SwiftUI

/// Misure, spaziature e raggi delle schermate (in punti, a 1440×900). Nel tema «Liquid Glass»
/// barra, dock, finestre e raggi seguono `Tema.Misura`/`Tema.Raggio`; il resto resta com'era
/// perché le schermate ci sono impaginate.
enum Misure {
    enum Barra {
        static let altezza: CGFloat = Tema.Misura.barra
        static let margine: CGFloat = 18
        /// Spazio a sinistra per i pulsanti nativi della finestra macOS.
        static let spazioSemaforiNativi: CGFloat = 70
        static let spazioMarchio: CGFloat = 7
        static let spazioApp: CGFloat = 17
        static let spazioOra: CGFloat = 11
        static let spazioDestra: CGFloat = 17
        static let spazioCerca: CGFloat = 14
        static let icona: CGFloat = Tema.Misura.iconaBarra
        static let avatar: CGFloat = Tema.Misura.avatarBarra
        static let badge: CGFloat = Tema.Misura.badge
        static let raggioTasto: CGFloat = Tema.Raggio.tasto
    }

    enum Scrivania {
        static let margineAlto: CGFloat = 18
        static let margineLato: CGFloat = 30
        static let margineBasso: CGFloat = 10
        static let colonne = 4
        static let spazioColonne: CGFloat = 12
        static let spazioRighe: CGFloat = 6
        static let icona: CGFloat = 64
        static let lanciatoreSpazio: CGFloat = 6
        static let lanciatoreRaggio: CGFloat = Tema.Raggio.riga
        static let badge: CGFloat = 21
        static let colonnaLarghezza: CGFloat = 300
        static let colonnaSpazio: CGFloat = 26
        static let spazioPulsanti: CGFloat = 10
        static let altezzaSezione: CGFloat = 28
    }

    enum Analisi {
        static let rail: CGFloat = 210
        static let margineRail: CGFloat = 10
        static let segAltezza: CGFloat = 28
        static let navAltezza: CGFloat = 34
        /// Pannelli, KPI e tabelle: più tondi che nel tema iOS 5, meno delle schede del tema (il contenuto tocca i bordi).
        static let raggio: CGFloat = 10
        static let kpiMargine = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        static let cellaMargine = EdgeInsets(top: 8, leading: 9, bottom: 8, trailing: 9)
        static let testaMargine = EdgeInsets(top: 7, leading: 9, bottom: 7, trailing: 9)
        static let anello: CGFloat = 150
        static let spessoreAnello: CGFloat = 23
        static let grafico: CGFloat = 200
        static let barraStato: CGFloat = 36
        static let dettaglio = CGSize(width: 820, height: 680)
        static let modulo = CGSize(width: 680, height: 640)
        static let moduloRilevazione = CGSize(width: 500, height: 360)
        static let moduloSalvaPDF = CGSize(width: 520, height: 330)
        static let moduloImporta = CGSize(width: 640, height: 600)
        static let moduloImportaPosizioni = CGSize(width: 820, height: 620)
        /// Prova di resistenza: la barra della perdita sui mercati e la colonna delle cifre.
        static let barraResistenza: CGFloat = 8
        static let colonnaPerdita: CGFloat = 110
        static let colonnaCanale: CGFloat = 90
        static let righeResistenza = 4
        /// Peso dei costi: le colonne delle cifre e dell'alternativa.
        static let colonnaCosto: CGFloat = 92
        static let colonnaAlternativa: CGFloat = 230
        /// Passaggio generazionale: la colonna degli eredi e quella del destino.
        static let colonnaEredi: CGFloat = 290
        static let colonnaDestino: CGFloat = 92
    }

    enum Rubrica {
        static let indice: CGFloat = 220
        static let raggioLibro: CGFloat = Tema.Raggio.gruppo
        static let avatarElenco: CGFloat = 34
        static let avatarProfilo: CGFloat = 40
        static let cornicesAvatar: CGFloat = 3
        static let margineRiga = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        static let margineProfilo = EdgeInsets(top: 10, leading: 17, bottom: 10, trailing: 17)
        static let margineContenuto = EdgeInsets(top: 12, leading: 17, bottom: 15, trailing: 17)
        static let schedaAltezza: CGFloat = 33
        static let schedaMargine: CGFloat = 15
        static let spazioSchede: CGFloat = 22
        /// Icone dei collegamenti del dossier: più grandi perché si riconoscano a colpo d'occhio.
        static let iconaApp: CGFloat = 38
        static let modulo = CGSize(width: 620, height: 560)
    }

    enum Widget {
        /// La striscia della guida «Comincia con i tuoi dati» e il suo elenco.
        static let striscia: CGFloat = 34
        static let elencoGuida: CGFloat = 480
        // Widget di vetro del tema (--r-w)
        static let raggio: CGFloat = Tema.Raggio.widget
        static let spazio: CGFloat = 20
        static let intestazione: CGFloat = 40
        /// Quota d'altezza della fila alta (Agenda, Cliente in primo piano con la barra di Eve).
        static let quotaAlta: CGFloat = 0.56
        static let margine = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        /// La piastrella grande del giorno nel widget Agenda.
        static let piastrellaGrande = CGSize(width: 72, height: 96)
        static let colonnaGiorno: CGFloat = 132
        /// Intestazione dei pannelli (.os-desk-panel-heading) e righe (.os-desk-event).
        static let intestazionePannello = EdgeInsets(top: 12, leading: 13, bottom: 7, trailing: 13)
        static let margineElenco: CGFloat = 15
        /// Il pannello carta dentro il cliente (.os-panel) e i suoi numeri.
        static let pannelloMargine: CGFloat = 12
        static let pannelloMargineCompatto: CGFloat = 8
        static let pannelloRaggio: CGFloat = Tema.Raggio.kpi
        /// Il widget del cliente: testata in pelle (.os-desk-client: 13/14/10, compatta 9/12 sugli
        /// schermi bassi), margine del corpo (ridotto nella variante compatta) e spazio fra
        /// pannello, righe e pulsanti.
        static let clienteTestata = EdgeInsets(top: 13, leading: 14, bottom: 10, trailing: 14)
        static let clienteTestataCompatta = EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
        static let clienteMargine = EdgeInsets(top: 10, leading: 13, bottom: 10, trailing: 13)
        static let clienteMargineCompatto = EdgeInsets(top: 8, leading: 13, bottom: 8, trailing: 13)
        static let clienteSpazio: CGFloat = 8
        /// Lo spazio fra totale, barre dei canali e proposte nel portafoglio.
        static let portafoglioSpazio: CGFloat = 10
        /// La barra di Eve sotto il cliente (.os-desk-eve).
        static let barraEve: CGFloat = 60
        static let avatarCliente: CGFloat = 39
        /// Ex cucitura della pelle (nel tema non si vede più).
        static let cucituraRientro: CGFloat = 6
        static let cucituraRaggio: CGFloat = 3
        /// La casella delle attività (tonda, come la spunta del tema) e la barra del portafoglio.
        static let casella: CGFloat = 14
        static let casellaRaggio: CGFloat = 7
        static let progresso: CGFloat = 7
    }

    enum Agenda {
        static let margine: CGFloat = 14
        static let cuoioMargine = EdgeInsets(top: 10, leading: 20, bottom: 14, trailing: 20)
        static let cuoioRaggio: CGFloat = Tema.Raggio.riga
        static let cucitura: CGFloat = 7
        static let targhetta: CGFloat = 50
        static let anello = CGSize(width: 10, height: 26)
        static let anelli = 4
        static let rientroAnelli: CGFloat = 0.12
        static let rigatura: CGFloat = 49
        static let segno: CGFloat = 3
        static let colonnaOra: CGFloat = 40
        static let etichettaVoce: CGFloat = 58
        static let cellaMese: CGFloat = 34
        static let puntino: CGFloat = 4
        static let modulo = CGSize(width: 620, height: 600)
    }

    enum Incontri {
        static let rigatura: CGFloat = 24
        static let margine: CGFloat = 34
        static let raggio: CGFloat = Tema.Raggio.miniatura
        static let campo: CGFloat = 110
    }

    enum Bisogni {
        static let ruota: CGFloat = 200
        static let foro: CGFloat = 0.38
        static let raggioCarta: CGFloat = Tema.Raggio.riga
        static let icona: CGFloat = 26
    }

    enum Eve {
        static let giornata: CGFloat = 290
        static let raggioNuvola: CGFloat = 16
        static let larghezzaNuvola: CGFloat = 0.78
        static let sfera: CGFloat = 38
        static let display: CGFloat = 44
    }

    enum Strumenti {
        static let console: CGFloat = 300
        static let lcd = CGSize(width: 124, height: 26)
        static let ipotesi: CGFloat = 300
        static let campo: CGFloat = 96
        static let rigaCarta: CGFloat = 25
        static let schedaArea: CGFloat = 150
        static let colonnaConfronto: CGFloat = 150
        static let raggio: CGFloat = 8
    }

    enum Attivita {
        static let margine: CGFloat = 14
        static let margineRiga: CGFloat = 43
        static let rigatura: CGFloat = 40
        static let rigaMinima: CGFloat = 62
        static let spunta: CGFloat = 19
        static let colonnaScadenza: CGFloat = 96
        static let progresso: CGFloat = 7
        static let modulo = CGSize(width: 580, height: 470)
    }

    enum Colonna {
        static let raggio: CGFloat = Tema.Raggio.kpi
        static let avatar: CGFloat = 39
        static let schedeAltezza: CGFloat = 28
        /// Segmenti in capsula (metà dell'altezza).
        static let schedeRaggio: CGFloat = 14
        static let data = CGSize(width: 36, height: 48)
        static let dataRaggio: CGFloat = Tema.Raggio.tesseraData
        static let dataMese: CGFloat = 17
        static let iconaEve: CGFloat = 37
    }

    enum Dock {
        // Icone del tema (--dock-ic 50) con il nome sotto: a 40 punti erano illeggibili
        static let elemento: CGFloat = 56
        static let icona: CGFloat = Tema.Misura.dockIcona
        static let spazio: CGFloat = 8
        /// Il nome sotto l'icona.
        static let etichetta: CGFloat = 14
        static let margineOrizzontale: CGFloat = 14
        static let margineAlto: CGFloat = 5
        static let margineBasso: CGFloat = 6
        static let ripianoAltezza: CGFloat = 44
        static let ripianoAlto: CGFloat = 21
        static let ripianoSporgenza: CGFloat = 9
        static let ripianoRientro: CGFloat = 12
        static let ingrandimento: CGFloat = 1.13
        /// Area riservata al dock sotto le finestre (--os-bottom).
        static let riservato: CGFloat = 104
        /// Con il dock nascosto (finestre aperte): il margine che resta in basso e la striscia che lo richiama.
        static let riservatoNascosto: CGFloat = 4
        static let strisciaRichiamo: CGFloat = 6
        /// Quanto scende il dock per nascondersi.
        static let corsaNascosto: CGFloat = 130
    }

    enum Finestra {
        static let raggio: CGFloat = Tema.Raggio.finestra
        /// Più alta che nel tema iOS 5 (il tema arriva a 52): resta spazio per i contenuti.
        static let barraTitolo: CGFloat = 36
        static let margineTitolo: CGFloat = 11
        static let margineLato: CGFloat = 8
        static let margineAlto: CGFloat = 5
        static let margineBasso: CGFloat = 5
        static let semaforo: CGFloat = Tema.Misura.semaforo
        static let spazioSemafori: CGFloat = Tema.Misura.spazioSemafori
        static let iconaTitolo: CGFloat = Tema.Misura.iconaFinestra
        static let affianca = CGSize(width: 27, height: 22)
        static let minima = CGSize(width: 560, height: 360)
        static let raggioAffianca: CGFloat = Tema.Raggio.tasto
    }

    enum IntestazioneApp {
        static let margineVerticale: CGFloat = 8
        static let margineOrizzontale: CGFloat = 12
        static let spazio: CGFloat = 10
    }

    /// Pulsanti in capsula del tema (raggio pari a circa metà dell'altezza).
    enum Pulsante {
        static let raggio: CGFloat = 16
        /// Anche l'etichetta del canale (che va pure nei PDF): quasi una capsula.
        static let raggioBlu: CGFloat = 12
        static let vetroMargine = EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        static let bluMargine = EdgeInsets(top: 6, leading: 13, bottom: 6, trailing: 13)
    }

    /// Il menu a tendina: margini come i pulsanti di vetro piccoli, altezza come un campo.
    enum Tendina {
        static let margine = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 10)
        static let altezza: CGFloat = 26
        static let raggio: CGFloat = 13
        static let freccia: CGFloat = 8
        static let spazio: CGFloat = 8
    }

    enum Avvisi {
        /// Capsula di vetro del tema (toast).
        static let raggio: CGFloat = 20
        static let distanzaBasso: CGFloat = 100
        static let margine = EdgeInsets(top: 13, leading: 19, bottom: 13, trailing: 19)
        /// Il riquadro tratteggiato quando si trascina un file su Prisma.
        static let rilascioRaggio: CGFloat = Tema.Raggio.scheda
        static let rilascioMargine: CGFloat = 8
    }

    enum Impostazioni {
        static let raggioGruppo: CGFloat = Tema.Raggio.gruppo
        static let margineRiga = EdgeInsets(top: 14, leading: 17, bottom: 14, trailing: 17)
        static let altezzaRiga: CGFloat = 64
        static let interruttore = Tema.Misura.interruttore
        static let raggioInterruttore: CGFloat = 13
        static let schedeAltezza: CGFloat = 30
        static let schedeMargine: CGFloat = 13
        static let spazioGruppi: CGFloat = 18
        static let informazioniLarghezza: CGFloat = 0.38
        static let informazioniMargine: CGFloat = 20
        static let iconaInformazioni: CGFloat = 61
    }

    enum Pannello {
        static let raggio: CGFloat = Tema.Raggio.tessera
    }

    /// Campi di testo (.os-input del template).
    enum Campo {
        static let raggio: CGFloat = 8
        static let margine = EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        /// Ombra interna in alto (inset 0 1px 3px).
        static let ombraSfocatura: CGFloat = 1.5
    }

    /// Spunti di Eve: la sfumatura sul bordo destro della riga che scorre.
    enum SpuntiEve {
        static let sfumatura: CGFloat = 24
    }
}

/// Durate e curve delle animazioni (tema «Liquid Glass», vedi `Tema.Moto`).
enum Animazioni {
    /// Apertura finestra: uscita morbida del tema (--out), un po' più breve dei 340 ms del tema.
    static let apertura = Tema.Moto.uscita(0.28)
    /// Avviso: 0,24 s.
    static let avviso = Tema.Moto.pannello
    /// Al passaggio del mouse: 0,15 s.
    static let passaggio = Tema.Moto.passaggio
    /// Il toast del tema resta 2,6 s.
    static let durataAvviso: TimeInterval = 2.6
}
