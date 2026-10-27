import SwiftUI

// MARK: - Logo di Prisma

/// Geometria del simbolo, presa da Prisma_logo.svg (viewBox 680 × 680): un triangolo dagli angoli arrotondati
/// (raggio 64) diviso in tre spicchi. Gli archi sono `A64 64 0 0 1`: angolo crescente, cioè `clockwise: false` in SwiftUI.
enum GeometriaLogo {
    struct Arco {
        let centro: CGPoint
        let inizio: CGPoint
        let fine: CGPoint
    }

    struct Spicchio {
        /// Il vertice verso il centro del triangolo.
        let punta: CGPoint
        let archi: [Arco]
    }

    static let raggio: CGFloat = 64
    /// Centri degli angoli arrotondati (triangolo equilatero).
    static let centroAlto = CGPoint(x: 340, y: 136)
    static let centroSinistra = CGPoint(x: 104.4409, y: 544)
    static let centroDestra = CGPoint(x: 575.5591, y: 544)

    /// Riquadro del disegno dentro il viewBox (senza i margini del file).
    static let riquadro = CGRect(x: 40.4409, y: 73.78, width: 599.1182, height: 534.22)
    /// Larghezza / altezza del simbolo.
    static let proporzione: CGFloat = 599.1182 / 534.22

    /// Spicchio sinistro (opacità 1).
    static let sinistra = Spicchio(punta: CGPoint(x: 325, y: 399.34), archi: [
        Arco(centro: centroSinistra, inizio: CGPoint(x: 43.06, y: 562.12), fine: CGPoint(x: 49.02, y: 512)),
        Arco(centro: centroAlto, inizio: CGPoint(x: 284.57, y: 104), fine: CGPoint(x: 325, y: 73.78)),
    ])
    /// Spicchio destro (opacità 0,66).
    static let destra = Spicchio(punta: CGPoint(x: 355, y: 399.34), archi: [
        Arco(centro: centroAlto, inizio: CGPoint(x: 355, y: 73.78), fine: CGPoint(x: 395.43, y: 104)),
        Arco(centro: centroDestra, inizio: CGPoint(x: 630.98, y: 512), fine: CGPoint(x: 636.94, y: 562.12)),
    ])
    /// Spicchio in basso (opacità 0,38).
    static let base = Spicchio(punta: CGPoint(x: 340, y: 425.32), archi: [
        Arco(centro: centroDestra, inizio: CGPoint(x: 621.94, y: 588.1), fine: CGPoint(x: 575.56, y: 608)),
        Arco(centro: centroSinistra, inizio: CGPoint(x: 104.44, y: 608), fine: CGPoint(x: 58.06, y: 588.1)),
    ])

    /// Nel logo con nome: corpo del nome e spazio tra simbolo e nome, in frazioni dell'altezza del simbolo.
    static let corpoNome: CGFloat = 0.91
    static let spazioNome: CGFloat = 0.24
    /// letter-spacing del nome (-0,01 em, come il marchio nella barra del tema).
    static let spaziaturaNome: CGFloat = -0.01

    /// Il tracciato di uno spicchio adattato a `rect` (proporzioni mantenute, centrato).
    static func tracciato(_ spicchio: Spicchio, in rect: CGRect) -> Path {
        let scala = min(rect.width / riquadro.width, rect.height / riquadro.height)
        guard scala > 0 else { return Path() }
        let ox = rect.minX + (rect.width - riquadro.width * scala) / 2 - riquadro.minX * scala
        let oy = rect.minY + (rect.height - riquadro.height * scala) / 2 - riquadro.minY * scala
        func punto(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * scala + ox, y: p.y * scala + oy) }
        func angolo(_ p: CGPoint, _ c: CGPoint) -> Double { atan2(Double(p.y - c.y), Double(p.x - c.x)) }

        var path = Path()
        path.move(to: punto(spicchio.punta))
        for arco in spicchio.archi {
            let inizio = angolo(arco.inizio, arco.centro)
            var fine = angolo(arco.fine, arco.centro)
            if fine < inizio { fine += 2 * Double.pi }
            // addArc traccia da solo il lato diritto fino all'inizio dell'arco
            path.addArc(center: punto(arco.centro), radius: raggio * scala,
                        startAngle: .radians(inizio), endAngle: .radians(fine), clockwise: false)
        }
        path.closeSubpath()
        return path
    }
}

/// Uno dei tre spicchi del simbolo, adattato al riquadro mantenendo le proporzioni.
struct SpicchioLogoPrisma: Shape {
    enum Parte: Int, CaseIterable {
        case sinistra, destra, base

        /// Opacità dello spicchio (fill-opacity del file SVG).
        var opacita: Double {
            switch self {
            case .sinistra: return 1
            case .destra: return 0.66
            case .base: return 0.38
            }
        }

        var spicchio: GeometriaLogo.Spicchio {
            switch self {
            case .sinistra: return GeometriaLogo.sinistra
            case .destra: return GeometriaLogo.destra
            case .base: return GeometriaLogo.base
            }
        }
    }

    let parte: Parte

    func path(in rect: CGRect) -> Path {
        GeometriaLogo.tracciato(parte.spicchio, in: rect)
    }
}

/// Il simbolo intero in un solo tracciato (per maschere o versioni a tinta unica).
struct SimboloPrisma: Shape {
    func path(in rect: CGRect) -> Path {
        var path = GeometriaLogo.tracciato(GeometriaLogo.sinistra, in: rect)
        path.addPath(GeometriaLogo.tracciato(GeometriaLogo.destra, in: rect))
        path.addPath(GeometriaLogo.tracciato(GeometriaLogo.base, in: rect))
        return path
    }
}

/// Il logo di Prisma: tre spicchi con opacità 1 / 0,66 / 0,38. Vettoriale puro: va bene anche nei PDF
/// (lì con `Tema.Colore.logoStampa`). Si adatta allo spazio mantenendo le proporzioni.
struct LogoPrisma: View {
    var colore: Color = Tema.Colore.logo

    var body: some View {
        ZStack {
            ForEach(SpicchioLogoPrisma.Parte.allCases, id: \.self) { parte in
                SpicchioLogoPrisma(parte: parte).fill(colore.opacity(parte.opacita))
            }
        }
        .aspectRatio(GeometriaLogo.proporzione, contentMode: .fit)
    }
}

/// Simbolo + «Prisma» in SF neretto, nelle proporzioni di Prisma_logo_con_nome.svg.
struct LogoPrismaConNome: View {
    var colore: Color = Tema.Colore.logo
    /// Altezza del simbolo: il nome si proporziona da sé.
    var altezza: CGFloat = 22

    var body: some View {
        let corpo = altezza * GeometriaLogo.corpoNome
        HStack(spacing: altezza * GeometriaLogo.spazioNome) {
            LogoPrisma(colore: colore)
                .frame(width: altezza * GeometriaLogo.proporzione, height: altezza)
            Text("Prisma")
                .font(.system(size: corpo, weight: .bold))
                .tracking(corpo * GeometriaLogo.spaziaturaNome)
                .foregroundColor(colore)
                .lineLimit(1)
                .fixedSize()
        }
    }
}
