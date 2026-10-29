import CoreGraphics

/// L'imbuto dell'«effetto genio» (CurveGenio e Shell/MotoreGenio.swift), nelle coordinate della finestra:
/// i due lati vanno dagli angoli in alto della finestra (y = 0) ai lati dell'icona del dock (y = `collo`,
/// la cima dell'icona) con una curva a S: dritti in alto, piegati nel mezzo, di nuovo dritti sull'icona.
/// `piega` dice quanto l'imbuto è formato: 0 = lati dritti (la finestra com'è), 1 = imbuto pieno.
/// Sotto il collo l'imbuto è largo quanto l'icona. Solo conti: nessun valore grafico (i tempi delle fasi
/// sono in Tema.Moto.Finestre, la misura dell'icona in Tema.Misura.dockIcona).
struct GenioImbuto {
    /// La larghezza della finestra.
    let larghezza: CGFloat
    /// La x del centro dell'icona.
    let centroIcona: CGFloat
    /// Il lato dell'icona.
    let lato: CGFloat
    /// La y della cima dell'icona, dove l'imbuto diventa largo quanto lei.
    let collo: CGFloat
    /// 0…1: quanto si sono piegati i lati.
    let piega: CGFloat

    /// Il lato sinistro e il lato destro dell'imbuto all'altezza `y`.
    func lati(a y: CGFloat) -> (sinistra: CGFloat, destra: CGFloat) {
        let u = GenioImbuto.limita(y / max(collo, 1))
        let k = GenioImbuto.morbido(u) * GenioImbuto.limita(piega)
        let mezzo = lato / 2
        return (GenioImbuto.verso(0, centroIcona - mezzo, k),
                GenioImbuto.verso(larghezza, centroIcona + mezzo, k))
    }

    // MARK: Aiuti

    static func limita(_ x: CGFloat) -> CGFloat { min(max(x, 0), 1) }

    static func verso(_ da: CGFloat, _ a: CGFloat, _ t: CGFloat) -> CGFloat { da + (a - da) * t }

    /// La S: parte e arriva piano (smoothstep).
    static func morbido(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }

    /// Parte svelta e arriva piano.
    static func esce(_ t: CGFloat) -> CGFloat { 1 - (1 - t) * (1 - t) }
}
