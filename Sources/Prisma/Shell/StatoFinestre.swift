import Combine
import SwiftUI

// Proprietario: G1 (movimento delle finestre). Creato dalle fondamenta (G0).

/// Finestre interne, pannelli e blocco: lo osservano solo shell, dock, barra e pannelli,
/// così aprire o cambiare app non ricalcola il contenuto delle app aperte né i widget.
/// StatoShell lo tiene in `sistema` e ne inoltra le proprietà con i nomi di sempre.
final class StatoFinestre: ObservableObject {
    typealias Finestra = StatoShell.Finestra

    /// Finestre aperte; l'ultima è quella in primo piano.
    @Published var elenco: [Finestra] = []
    /// La schermata di benvenuto copre le finestre (il lucchetto in alto).
    @Published var bloccato = false
    @Published var pannelloAppAperte = false
    /// Il pannello degli spazi di lavoro è aperto.
    @Published var pannelloSpazi = false
    @Published var pannelloNotifiche = false
    /// Finestre appena aperte che aspettano il giro dopo per animarsi (G1).
    @Published var inArrivo: Set<AppPrisma> = []
    /// FLIP in corso: cornice di partenza e progresso (G1).
    @Published var flip: [AppPrisma: PassaggioCornice] = [:]
    /// Finestre del tutto coperte da una finestra ingrandita, a transizione finita: non si disegnano (G1).
    @Published var coperte: Set<AppPrisma> = []
    /// Finestre ridotte nel dock a genio finito: i loro controlli sono spenti (i tasti non ci finiscono).
    @Published var spente: Set<AppPrisma> = []
    /// Da dove si apre ogni app (coordinate `ShellView.spazioShell`): non pubblicato, si legge all'apertura.
    /// Riducendo un'app vale il centro della sua icona nel dock, dove va il «genio».
    var origini: [AppPrisma: CGPoint] = [:]
    /// La scrivania sta sotto una finestra ingrandita, a transizione finita: non si disegna (resta montata).
    @Published var scrivaniaNascosta = false
    /// Il blocco a transizione finita: l'acqua non riparte né si ferma a metà dell'animazione, e la scrivania
    /// nascosta si prepara all'entrata dello sblocco.
    @Published var bloccatoStabile = false
    /// Misura della shell (non pubblicata): serve a sapere dov'è l'icona di un'app nel dock.
    var misura: CGSize = .zero
    // Contatori delle transizioni (non pubblicati): un lavoro rimandato vale solo se nel frattempo non ne è partita un'altra
    var giroCoperte = 0
    var giroBlocco = 0
    var giroScrivania = 0
    var giroPresentazione = 0

    var visibili: [Finestra] { elenco.filter { !$0.ridotta } }
    /// App in primo piano (nil = scrivania).
    var appAttiva: AppPrisma? { visibili.last?.app }
    func aperta(_ app: AppPrisma) -> Bool { elenco.contains { $0.app == app } }
}

/// Un passaggio FLIP: la cornice da cui parte la finestra (coordinate dell'area delle finestre) e a che punto è.
struct PassaggioCornice: Equatable {
    var da: CGRect
    var progresso: CGFloat
}

/// Solo ciò che cambia titoli e abilitazioni del menu Vai: il menu non osserva StatoShell.
final class StatoMenu: ObservableObject {
    @Published private(set) var bloccato = false
    @Published private(set) var inModoCliente = false
    @Published private(set) var inPresentazione = false
    @Published private(set) var conversazioneAVoce = false

    /// Copia i valori solo se cambiano: il menu si ricostruisce il meno possibile.
    func aggiorna(bloccato: Bool, inModoCliente: Bool, inPresentazione: Bool, conversazioneAVoce: Bool) {
        if self.bloccato != bloccato { self.bloccato = bloccato }
        if self.inModoCliente != inModoCliente { self.inModoCliente = inModoCliente }
        if self.inPresentazione != inPresentazione { self.inPresentazione = inPresentazione }
        if self.conversazioneAVoce != conversazioneAVoce { self.conversazioneAVoce = conversazioneAVoce }
    }
}
