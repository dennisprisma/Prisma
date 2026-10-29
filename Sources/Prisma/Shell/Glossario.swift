import Foundation

// Proprietario: G7 (guida). Solo dati e funzioni pure: lo usano la guida, le «i» accanto alle etichette e la
// prova dei calcoli. Le cifre fiscali vengono da `RegoleFiscali` e `RegoleTFR`, mai scritte a mano.

/// Una parola della finanza spiegata in modo semplice (scheda della «i» e voce del glossario).
struct VoceGlossario: Identifiable, Equatable {
    /// Le voci, nell'ordine del glossario.
    enum Chiave: String, CaseIterable {
        case polizzaVita, ramoI, ramoIII, ramoV, multiramo, gestioneSeparata, fondoComune, etf, pac, premio
        case tcm, ltc, fondoPensione, pip
        case kid, sri, riy, ter, caricamento, trattenuto, minimoGarantito, consolidamento, riscatto, penali
        case periodoRaccomandato, volatilita, diversificazione, rendimentoNetto, inflazione, interesseComposto
        case tfr, previdenzaComplementare, deducibilita, montante, tassoSostituzione, rendita, tasse, bollo
        case ruoliPolizza, capitaleMorte
        case recesso, idd, adeguatezza, coerenza, profiloRischio, antiriciclaggio, mifid
        case inEssere, canale, dossier, riesame, prospettoReport, patrimonioNetto, riservaLiquidita
    }

    enum Categoria: String, CaseIterable, Hashable {
        case prodotti, costiRischi, previdenzaFisco, regole, prisma

        var nome: String {
            switch self {
            case .prodotti: return "Prodotti"
            case .costiRischi: return "Costi e rischi"
            case .previdenzaFisco: return "Previdenza e tasse"
            case .regole: return "Regole"
            case .prisma: return "Le parole di Prisma"
            }
        }
    }

    let chiave: Chiave
    /// Come si scrive nell'interfaccia: «SRI», «Gestione separata».
    let termine: String
    /// La sigla per esteso, se è una sigla: «Summary Risk Indicator».
    let perEsteso: String?
    let categoria: Categoria
    /// Una riga (al massimo 110 caratteri): il suggerimento della «i» e la prima riga della voce.
    let breve: String
    /// La spiegazione semplice (2-4 frasi).
    let spiegazione: String
    /// Un esempio con le cifre, se aiuta.
    let esempio: String?
    /// Dove si trova in Prisma.
    let dove: [AppPrisma]

    var id: String { chiave.rawValue }
}

enum Glossario {
    /// Le voci, nell'ordine di `VoceGlossario.Chiave`.
    static let voci: [VoceGlossario] = [
        // MARK: Prodotti
        v(.polizzaVita, "Polizza vita", nil, .prodotti,
          "Un contratto con una compagnia per risparmiare o investire, con una tutela in caso di morte.",
          "Il cliente versa dei premi alla compagnia. La compagnia paga un capitale o una rendita a una data stabilita, oppure ai beneficiari se l'assicurato muore prima. In Prisma è quasi sempre un modo di risparmiare o investire.",
          nil, [.posizioni, .prodotti]),
        v(.ramoI, "Ramo I", nil, .prodotti,
          "Polizza vita «tradizionale»: cresce piano, con garanzie della compagnia.",
          "Nelle polizze di Ramo I (dette «rivalutabili») i soldi vanno nella gestione separata della compagnia. Ogni anno la polizza si rivaluta di una parte del rendimento ottenuto. Secondo il contratto, il capitale (o un rendimento minimo) è garantito.",
          nil, [.posizioni, .prodotti]),
        v(.ramoIII, "Ramo III (unit linked)", nil, .prodotti,
          "Polizza il cui valore segue quello di fondi d'investimento: può salire e scendere.",
          "Nelle unit linked il valore dipende dalle quote di uno o più fondi. Si può guadagnare di più, ma si può anche perdere: il rischio è del cliente, e di solito non c'è un capitale garantito.",
          "10.000 € in un fondo che perde il 10% valgono circa 9.000 €.", [.posizioni, .prodotti]),
        v(.ramoV, "Capitalizzazione (Ramo V)", nil, .prodotti,
          "Contratto con la compagnia per far crescere un capitale, senza legame con la vita di una persona.",
          "Funziona come un Ramo I (spesso con una gestione separata), ma la somma non dipende dalla vita o dalla morte di qualcuno: matura a una scadenza.",
          nil, [.prodotti]),
        v(.multiramo, "Multiramo", nil, .prodotti,
          "Una sola polizza, con una parte in gestione separata e una in fondi.",
          "La multiramo unisce un Ramo I (più stabile, con garanzie) e un Ramo III (fondi, con più rischio e più possibilità). Prisma calcola le due parti separatamente: costi, rischio, bollo e garanzia di ciascuna.",
          "70% in gestione separata e 30% in fondi.", [.posizioni, .prodotti]),
        v(.gestioneSeparata, "Gestione separata", nil, .prodotti,
          "Il fondo interno della compagnia dove vanno i soldi delle polizze di Ramo I.",
          "È un patrimonio che la compagnia tiene separato dal resto e investe soprattutto in obbligazioni. Il suo rendimento è calcolato ogni anno sul costo storico dei titoli, per cui si muove poco. Alla polizza va quel rendimento meno quanto trattiene la compagnia.",
          "Rendimento della gestione 3,2%, trattenuto 1,2 punti: alla polizza va il 2%.", [.posizioni, .prodotti]),
        v(.fondoComune, "Fondo comune (OICR)", "Organismo di investimento collettivo del risparmio", .prodotti,
          "Tanti risparmiatori mettono insieme i soldi; un gestore li investe.",
          "Ogni risparmiatore ha delle quote, il cui valore cambia ogni giorno con i titoli del fondo. È gestito da una società di gestione, ed è controllato e tenuto separato dal suo patrimonio.",
          nil, [.posizioni]),
        v(.etf, "ETF", "Exchange Traded Fund", .prodotti,
          "Fondo comprato e venduto in Borsa che di solito copia un indice, con costi bassi.",
          "Invece di scegliere i titoli, l'ETF replica un indice (per esempio le principali Borse del mondo). Costa meno di un fondo tradizionale e il suo valore cambia durante la giornata.",
          nil, [.posizioni]),
        v(.pac, "PAC", "Piano di accumulo del capitale", .prodotti,
          "Investire una piccola somma ogni mese invece di tutto insieme.",
          "Con versamenti regolari si entra nel mercato un po' alla volta: nei mesi in cui i prezzi sono bassi si comprano più quote. È adatto a chi risparmia dallo stipendio.",
          "200 € al mese per 10 anni = 24.000 € versati.", [.simulazioni, .posizioni]),
        v(.premio, "Premio", nil, .prodotti,
          "Quanto si versa in una polizza: tutto insieme (unico) o a rate (ricorrente).",
          "Il premio unico si versa una volta sola. Il premio ricorrente si versa a scadenze regolari (mensili, annuali) per tutta la durata o per un periodo. Il premio di una copertura di rischio è il suo costo.",
          nil, [.posizioni, .prodotti]),
        v(.tcm, "Temporanea caso morte (TCM)", nil, .prodotti,
          "Copertura pura: se l'assicurato muore entro la durata, la famiglia riceve il capitale.",
          "Serve a proteggere chi dipende dal reddito dell'assicurato (figli, mutuo). Se alla fine non è successo niente non si riceve nulla: come per l'assicurazione dell'auto, si paga la protezione.",
          "200.000 € di capitale per 20 anni.", [.analisi360, .posizioni]),
        v(.ltc, "Long Term Care (LTC)", "Assistenza di lungo periodo", .prodotti,
          "Una rendita se si perde l'autosufficienza.",
          "Paga una somma ogni mese se l'assicurato non riesce più a compiere da solo gli atti della vita quotidiana (lavarsi, vestirsi, mangiare…). Aiuta a pagare l'assistenza.",
          nil, [.analisi360]),
        v(.fondoPensione, "Fondo pensione", nil, .previdenzaFisco,
          "Un salvadanaio per la pensione, con tasse più basse.",
          "È la forma più comune di previdenza complementare. Può essere negoziale (di categoria, per i dipendenti) o aperto (per tutti). Riceve i versamenti del lavoratore, spesso del datore di lavoro e il TFR. I versamenti sono deducibili e le tasse sono ridotte.",
          nil, [.posizioni, .analisi360]),
        v(.pip, "PIP", "Piano individuale pensionistico", .previdenzaFisco,
          "Una polizza vita che fa da fondo pensione.",
          "È un fondo pensione costruito come polizza vita (Ramo I, Ramo III o multiramo). Ha gli stessi vantaggi fiscali dei fondi pensione e si sceglie individualmente.",
          nil, [.posizioni, .analisi360]),

        // MARK: Costi e rischi
        v(.kid, "KID", "Key Information Document", .costiRischi,
          "Il foglio di massimo 3 pagine con rischi, scenari e costi di un prodotto d'investimento.",
          "Lo prevede il regolamento europeo PRIIPs ed è uguale per tutti i prodotti: così si possono confrontare. Va consegnato al cliente prima della firma. Prisma lo legge in Documenti e ne riprende SRI, costi e periodo raccomandato.",
          nil, [.documenti, .prodotti]),
        v(.sri, "SRI", "Summary Risk Indicator", .costiRischi,
          "L'indicatore di rischio del KID: da 1 (più basso) a 7 (più alto).",
          "Unisce due cose: quanto il valore può salire e scendere, e il rischio che chi ha emesso il prodotto non riesca a pagare. Un 1-2 è prudente, un 6-7 può oscillare molto. Non dice quanto si guadagnerà.",
          nil, [.posizioni, .prodotti, .documenti]),
        v(.riy, "RIY (incidenza dei costi)", "Reduction in Yield", .costiRischi,
          "Quanto i costi tolgono ogni anno al rendimento, in percentuale.",
          "Somma tutti i costi del prodotto (d'ingresso, di gestione, trattenuti) e li esprime come una riduzione del rendimento annuo. Nel KID si chiama «incidenza annuale dei costi». Prisma confronta quello dichiarato con il suo calcolo.",
          "Un rendimento del 4% senza costi e un RIY dell'1,5% lasciano circa il 2,5% l'anno.", [.prodotti, .confronti, .documenti]),
        v(.ter, "TER", "Total Expense Ratio", .costiRischi,
          "I costi annui di gestione di un fondo, in percentuale.",
          "Comprende commissioni di gestione e altre spese del fondo, ed è già tolto dal valore della quota. Non comprende i costi d'ingresso o d'uscita.",
          nil, [.prodotti]),
        v(.caricamento, "Costi d'ingresso (caricamento)", nil, .costiRischi,
          "La percentuale trattenuta da ogni versamento prima di investirlo.",
          "Si paga all'entrata: con un caricamento del 3%, di 10.000 € versati se ne investono 9.700. Pesa di più se si esce presto.",
          "3% su 10.000 € = 300 €.", [.prodotti, .posizioni]),
        v(.trattenuto, "Trattenuto e retrocessione", nil, .costiRischi,
          "Quanta parte del rendimento della gestione separata resta alla compagnia.",
          "Il contratto dice o quanti punti trattiene la compagnia (il trattenuto, per esempio 1,2 punti) o quale quota riconosce al cliente (la retrocessione, per esempio il 90%). È il costo principale delle polizze di Ramo I.",
          "Gestione al 3%, retrocessione del 90%: alla polizza va il 2,7%.", [.prodotti, .posizioni]),
        v(.minimoGarantito, "Minimo garantito", nil, .costiRischi,
          "Il rendimento minimo che la compagnia promette (anche lo 0%, cioè il solo capitale).",
          "Vale secondo le condizioni: a scadenza, in caso di morte, oppure ogni anno se c'è il consolidamento annuo. Con un minimo dello 0% è garantito di riavere i premi versati, al netto dei costi indicati nel contratto.",
          nil, [.prodotti, .posizioni]),
        v(.consolidamento, "Consolidamento", nil, .costiRischi,
          "Il rendimento riconosciuto resta acquisito: gli anni dopo non lo tolgono.",
          "Con il consolidamento annuo, ogni anno il valore raggiunto diventa la nuova base garantita. Senza, la garanzia vale solo in certi momenti (a scadenza o in caso di morte) e nel frattempo il valore di riscatto può essere più basso.",
          nil, [.prodotti, .posizioni]),
        v(.riscatto, "Riscatto", nil, .costiRischi,
          "Chiedere indietro i soldi prima della scadenza.",
          "La polizza si chiude (o si riduce, con il riscatto parziale) e si riceve il valore maturato, meno eventuali penali e le tasse sul guadagno. Spesso non si può fare prima che sia passato un anno. Prisma calcola anno per anno quanto si riavrebbe.",
          nil, [.posizioni]),
        v(.penali, "Penali di riscatto", nil, .costiRischi,
          "Quanto si perde se si riscatta nei primi anni.",
          "È una percentuale del valore che scende con gli anni fino a sparire. Prisma mostra da quando si esce senza penali e il primo anno in cui si riavrebbe almeno quanto versato.",
          "2% il secondo anno, 1% il terzo, nulla dal quarto.", [.posizioni, .confronti]),
        v(.periodoRaccomandato, "Periodo di detenzione raccomandato", nil, .costiRischi,
          "Quanto tempo, secondo il KID, conviene tenere il prodotto.",
          "È l'orizzonte per cui il prodotto è pensato. Uscire prima può costare (penali) e aumenta il rischio di uscire in un momento sfavorevole.",
          nil, [.prodotti, .documenti]),
        v(.volatilita, "Volatilità", nil, .costiRischi,
          "Quanto il valore di un investimento sale e scende nel tempo.",
          "Più è alta, più sono ampie le oscillazioni, in su e in giù. Le azioni sono più volatili delle obbligazioni; una gestione separata lo è pochissimo.",
          nil, [.simulazioni]),
        v(.diversificazione, "Diversificazione", nil, .costiRischi,
          "Non mettere tutte le uova nello stesso paniere.",
          "Distribuire i risparmi su prodotti, mercati ed emittenti diversi riduce il danno se uno va male. Analisi 360 e Posizioni mostrano come è ripartito il patrimonio.",
          nil, [.posizioni, .analisi360]),
        v(.rendimentoNetto, "Rendimento lordo e netto", nil, .costiRischi,
          "Lordo: prima di costi e tasse. Netto: quello che resta davvero.",
          "Il rendimento che si legge nelle pubblicità è spesso lordo. Prisma toglie costi, bollo e tasse e mostra anche il valore «in euro di oggi», cioè tolta l'inflazione.",
          "5% lordo, 1,5% di costi, tasse al \(pct(RegoleFiscali.ordinaria)) sul guadagno: circa il 2,6% netto.", [.simulazioni, .confronti]),
        v(.inflazione, "Inflazione", nil, .costiRischi,
          "L'aumento dei prezzi, che fa valere meno gli stessi euro nel tempo.",
          "Con un'inflazione del 2% l'anno, 10.000 € tra 10 anni comprano quanto circa 8.200 € di oggi. Per questo Prisma mostra anche i valori «in euro di oggi».",
          nil, [.simulazioni, .obiettivi]),
        v(.interesseComposto, "Interesse composto", nil, .costiRischi,
          "Anche i guadagni producono guadagni: il capitale cresce sempre più in fretta.",
          "Ogni anno il rendimento si calcola sul capitale più i guadagni degli anni prima. Su periodi lunghi la differenza è grande: per questo conta cominciare presto.",
          "10.000 € al 4% per 20 anni diventano circa 21.900 €.", [.simulazioni, .obiettivi]),

        // MARK: Previdenza e tasse
        v(.tfr, "TFR", "Trattamento di fine rapporto", .previdenzaFisco,
          "La parte di stipendio che il datore di lavoro accantona ogni anno e paga alla fine del rapporto.",
          "Ogni anno si accantona la retribuzione annua divisa per \(cifra(RegoleTFR.divisore)) (circa il \(pct(100 / RegoleTFR.divisore))), meno lo \(pct(RegoleTFR.contributoIVS)) che va all'INPS: in pratica il \(pct(RegoleTFR.quotaAnnua)). Il dipendente può lasciarlo in azienda (si rivaluta dell'\(pct(RegoleTFR.rivalutazioneFissa)) più il \(pct(RegoleTFR.quotaInflazione * 100)) dell'inflazione, con un'imposta del \(pct(RegoleTFR.impostaRivalutazione)) sulla rivalutazione) o versarlo a un fondo pensione. Prisma confronta le due strade.",
          "Stipendio lordo di 30.000 €: circa \(Formati.euro((30_000 * RegoleTFR.quotaAnnua / 100 / 10).rounded() * 10)) di TFR l'anno.",
          [.analisi360, .simulazioni]),
        v(.previdenzaComplementare, "Previdenza complementare", nil, .previdenzaFisco,
          "Una pensione in più, accanto a quella pubblica.",
          "La pensione dell'INPS spesso è più bassa dell'ultimo stipendio. Fondi pensione e PIP servono a coprire la differenza, con tasse ridotte.",
          nil, [.analisi360]),
        v(.deducibilita, "Deducibilità", nil, .previdenzaFisco,
          "I versamenti per la pensione si tolgono dal reddito su cui si pagano le tasse.",
          "I contributi alla previdenza complementare (del lavoratore e del datore di lavoro, non il TFR) si deducono dal reddito fino a \(Formati.euro(RegoleFiscali.limiteDeducibilita)) l'anno. Si risparmia IRPEF in base alla propria aliquota.",
          "1.000 € versati con l'aliquota del 33%: 330 € di IRPEF in meno.", [.analisi360, .posizioni]),
        v(.montante, "Montante", nil, .previdenzaFisco,
          "Tutto il capitale accumulato a una certa data: versamenti più rendimenti, tolti i costi.",
          "Alla pensione il montante di un fondo si trasforma in una rendita, in parte anche in capitale secondo le regole. Prisma lo stima anno per anno.",
          nil, [.analisi360, .simulazioni]),
        v(.tassoSostituzione, "Tasso di sostituzione", nil, .previdenzaFisco,
          "Quanto sarà la pensione rispetto all'ultimo stipendio, in percentuale.",
          "Un tasso del 65% vuol dire che con 2.000 € di stipendio la pensione sarà di circa 1.300 €. La differenza è il «buco» che la previdenza complementare può colmare.",
          nil, [.analisi360]),
        v(.rendita, "Rendita vitalizia", nil, .previdenzaFisco,
          "Una somma pagata ogni mese per tutta la vita.",
          "Trasforma un capitale in un'entrata regolare che dura finché si vive. È la forma tipica della pensione complementare.",
          nil, [.analisi360]),
        v(.tasse, "Tasse sui guadagni", nil, .previdenzaFisco,
          "Sui guadagni finanziari si paga il \(pct(RegoleFiscali.ordinaria)); sui titoli di Stato il \(pct(RegoleFiscali.titoliStato)).",
          "Le tasse si pagano sul guadagno (valore finale meno versato), di solito quando si incassa. Nei fondi pensione i rendimenti pagano il \(pct(RegoleFiscali.previdenzaRendimenti)) e le prestazioni dal \(pct(RegoleFiscali.previdenzaBase)), che scende fino al \(pct(RegoleFiscali.previdenzaMinima)) con gli anni di adesione.",
          nil, [.simulazioni, .confronti, .analisi360]),
        v(.bollo, "Imposta di bollo", nil, .previdenzaFisco,
          "Una piccola tassa annua sul valore dei prodotti finanziari: lo \(pct(RegoleFiscali.bollo)).",
          "Riguarda per esempio fondi, titoli e polizze di Ramo III e di capitalizzazione (Ramo V); non la pagano le polizze di Ramo I né i fondi pensione e i PIP (nelle multiramo la paga solo la parte in fondi). Prisma la conta anno per anno, anche se nelle polizze può essere trattenuta in un momento diverso (per esempio all'uscita).",
          "\(pct(RegoleFiscali.bollo)) di 50.000 € = \(Formati.euro(50_000 * RegoleFiscali.bollo / 100)) l'anno.", [.posizioni, .prodotti]),
        v(.ruoliPolizza, "Contraente, assicurato, beneficiario", nil, .prodotti,
          "Chi firma e paga, sulla vita di chi è la polizza, chi riceve i soldi.",
          "Il contraente stipula e paga i premi. L'assicurato è la persona sulla cui vita è fatta la polizza (spesso la stessa). Il beneficiario riceve il capitale alla scadenza o in caso di morte.",
          nil, [.posizioni]),
        v(.capitaleMorte, "Capitale in caso di morte", nil, .previdenzaFisco,
          "Di solito le somme di una polizza vita pagate ai beneficiari non entrano nell'eredità.",
          "Per legge i beneficiari le ricevono per diritto proprio: non pagano l'imposta di successione e i creditori non possono pignorarle (art. 1923 del Codice civile). Vale per le polizze con una vera copertura assicurativa: per quelle quasi solo finanziarie i giudici possono decidere diversamente. Per questo le polizze servono anche a pianificare la successione.",
          nil, [.posizioni, .analisi360]),

        // MARK: Regole
        v(.recesso, "Recesso", nil, .regole,
          "Il diritto di ripensarci: 30 giorni per le polizze vita.",
          "Entro 30 giorni da quando sa che il contratto è concluso, il cliente può recedere e riavere i premi (nelle unit linked il valore delle quote), meno eventuali spese indicate nel contratto.",
          nil, [.prodotti]),
        v(.idd, "IDD", "Insurance Distribution Directive", .regole,
          "Le regole europee su come si propongono le assicurazioni.",
          "La direttiva UE 2016/97, recepita nel Codice delle assicurazioni e nei regolamenti IVASS (n. 40 e 41 del 2018), chiede: informazioni chiare prima della firma, verifica di richieste ed esigenze, adeguatezza per i prodotti d'investimento, attenzione ai conflitti d'interesse e formazione del consulente.",
          nil, [.posizioni, .prodotti]),
        v(.adeguatezza, "Adeguatezza", nil, .regole,
          "La verifica che un prodotto d'investimento sia adatto a quel cliente.",
          "Prima di proporlo, il consulente raccoglie le conoscenze e l'esperienza del cliente, la sua situazione finanziaria (anche quanto può permettersi di perdere), gli obiettivi e la tolleranza al rischio. Se il prodotto non è adatto, lo dice per iscritto. Prisma ha la scheda di adeguatezza nella posizione.",
          nil, [.posizioni, .clienti]),
        v(.coerenza, "Richieste ed esigenze", nil, .regole,
          "Ogni contratto deve rispondere a ciò che il cliente chiede e di cui ha bisogno.",
          "È il primo controllo, obbligatorio per tutte le assicurazioni: il consulente scrive che cosa ha chiesto il cliente e perché il prodotto è coerente.",
          nil, [.posizioni, .incontri]),
        v(.profiloRischio, "Profilo di rischio", nil, .regole,
          "Quanto rischio il cliente è disposto e in grado di sopportare.",
          "Nasce dal questionario: esperienza, obiettivi, orizzonte, reazione alle perdite. Serve a scegliere prodotti con un SRI adatto.",
          nil, [.clienti, .posizioni]),
        v(.antiriciclaggio, "Antiriciclaggio", nil, .regole,
          "Conoscere il cliente e da dove vengono i soldi, come vuole la legge.",
          "Il D.Lgs. 231/2007 chiede l'«adeguata verifica»: identificare il cliente con un documento valido, il titolare effettivo, lo scopo del rapporto e l'origine dei fondi; conservare i dati e segnalare le operazioni sospette. Prisma ricorda quando la verifica va rinnovata.",
          nil, [.clienti]),
        v(.mifid, "MiFID II", "Markets in Financial Instruments Directive", .regole,
          "Le regole europee per i servizi d'investimento (fondi, titoli).",
          "Valgono per chi consiglia strumenti finanziari. Chiedono profilatura del cliente, adeguatezza, trasparenza dei costi e gestione dei conflitti d'interesse. Per le polizze d'investimento valgono regole simili, quelle dell'IDD.",
          nil, [.posizioni]),

        // MARK: Le parole di Prisma
        v(.inEssere, "In essere e in proposta", nil, .prisma,
          "In essere: ciò che il cliente ha già. In proposta: ciò che gli consigli.",
          "Prisma le tiene distinte ovunque: le analisi mostrano la situazione di oggi e come cambierebbe con le proposte.",
          nil, [.posizioni]),
        v(.canale, "Canale", nil, .prisma,
          "Da dove viene una posizione: Alleanza (blu) o consulenza indipendente (cuoio).",
          "Alleanza Assicurazioni colloca solo i suoi prodotti; con la consulenza indipendente si guarda a tutto il mercato. Il canale è sempre scritto, anche nei PDF.",
          nil, [.posizioni, .prodotti]),
        v(.dossier, "Dossier", nil, .prisma,
          "Tutto quello che Prisma sa di un cliente, in un posto.",
          "Scheda personale, famiglia, posizioni, documenti, incontri, note e attività. Ogni app lavora sul dossier del cliente scelto.",
          nil, [.clienti]),
        v(.riesame, "Riesame", nil, .prisma,
          "Il controllo periodico (di solito annuale) della situazione del cliente.",
          "Si rivedono posizioni, obiettivi e bisogni, per capire se va tutto bene o se serve cambiare. Prisma ricorda in Agenda a chi tocca e conserva com'era la situazione l'ultima volta.",
          nil, [.clienti, .agenda]),
        v(.prospettoReport, "Prospetto e report", nil, .prisma,
          "Prospetto: il documento dettagliato per il consulente. Report: quello essenziale per il cliente.",
          "Entrambi escono in PDF, su carta bianca, con le stesse cifre calcolate da Prisma; il report usa parole semplici e meno tabelle.",
          nil, [.presentazioni]),
        v(.patrimonioNetto, "Patrimonio netto", nil, .prisma,
          "Tutto quello che il cliente ha, meno i debiti.",
          "Somma conti, investimenti, polizze e immobili indicati e toglie mutui e prestiti. Dice quanto vale davvero la sua situazione.",
          nil, [.posizioni, .analisi360]),
        v(.riservaLiquidita, "Riserva di liquidità", nil, .prisma,
          "I soldi da tenere sempre a portata di mano per gli imprevisti.",
          "Di solito si calcolano da 3 a 6 mesi di spese, sul conto o su strumenti senza vincoli. Prima di investire a lungo, Prisma controlla che ci siano.",
          "Spese di 2.000 € al mese: una riserva da 6.000 a 12.000 €.", [.analisi360]),
    ]

    static let perChiave: [VoceGlossario.Chiave: VoceGlossario] =
        Dictionary(voci.map { ($0.chiave, $0) }, uniquingKeysWith: { a, _ in a })

    static func voce(_ c: VoceGlossario.Chiave) -> VoceGlossario? { perChiave[c] }

    /// Le etichette dell'interfaccia che hanno una voce (testo esatto): accanto compare la «i».
    static let etichette: [String: VoceGlossario.Chiave] = [
        "Rischio (SRI)": .sri, "SRI dei fondi": .sri, "SRI del fondo": .sri,
        "Costi nel KID (RIY)": .riy,
        "Gestione separata": .gestioneSeparata,
        "Minimo garantito": .minimoGarantito,
        "Consolidamento": .consolidamento,
        "Penali di riscatto": .penali, "Senza penali dal": .penali,
        "Riscatto possibile": .riscatto, "Riscatto": .riscatto, "Riscatto e liquidabilità": .riscatto,
        "Montante dei piani": .montante, "Montante alla pensione": .montante, "Montante contributivo": .montante,
        "Periodo raccomandato": .periodoRaccomandato,
        "Trattenuto": .trattenuto, "Trattenuto dalla compagnia": .trattenuto, "Trattenuto in un anno": .trattenuto,
        "Retrocessione": .trattenuto, "Retrocessione al cliente": .trattenuto,
        "Imposta di bollo": .bollo,
        "Premio unico": .premio,
        "TFR conferito": .tfr,
        "Patrimonio netto": .patrimonioNetto,
    ]

    static func voce(perEtichetta e: String) -> VoceGlossario? { etichette[e].flatMap { perChiave[$0] } }

    /// Ricerca senza maiuscole né accenti su termine, per esteso, breve e spiegazione; i termini che
    /// cominciano con il testo vengono prima. Testo vuoto: tutte le voci (della categoria), in ordine alfabetico.
    static func cerca(_ testo: String, categoria: VoceGlossario.Categoria?) -> [VoceGlossario] {
        let t = piega(testo.trimmingCharacters(in: .whitespaces))
        let base = voci.filter { categoria == nil || $0.categoria == categoria }
        guard !t.isEmpty else { return base.sorted { piega($0.termine) < piega($1.termine) } }
        let trovate = base.filter { v in
            [v.termine, v.perEsteso ?? "", v.breve, v.spiegazione].contains { piega($0).contains(t) }
        }
        return trovate.sorted { a, b in
            let pa = piega(a.termine).hasPrefix(t), pb = piega(b.termine).hasPrefix(t)
            return pa != pb ? pa : piega(a.termine) < piega(b.termine)
        }
    }

    // MARK: - Aiuti

    private static let italiano = Locale(identifier: "it_IT")

    private static func piega(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: italiano)
    }

    /// «6,91%» dalle regole fiscali (mai un Double interpolato nudo, che darebbe «6.907…»).
    private static func pct(_ valore: Double) -> String { Formati.percentuale(valore) }

    /// «13,5»: un numero con la virgola, senza unità.
    private static func cifra(_ valore: Double) -> String {
        Formati.numeroFormatter.string(from: NSNumber(value: valore)) ?? String(valore)
    }

    private static func v(_ chiave: VoceGlossario.Chiave, _ termine: String, _ perEsteso: String?,
                          _ categoria: VoceGlossario.Categoria, _ breve: String, _ spiegazione: String,
                          _ esempio: String?, _ dove: [AppPrisma]) -> VoceGlossario {
        VoceGlossario(chiave: chiave, termine: termine, perEsteso: perEsteso, categoria: categoria, breve: breve,
                      spiegazione: spiegazione, esempio: esempio, dove: dove)
    }
}
