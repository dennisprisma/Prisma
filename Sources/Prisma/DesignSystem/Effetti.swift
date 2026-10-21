import SwiftUI

extension View {
    /// Testo inciso (text-shadow senza sfocatura, es. `0 1px #fff9`).
    func incisione(_ colore: Color, y: CGFloat = 1) -> some View {
        shadow(color: colore, radius: 0, x: 0, y: y)
    }

    /// Ombra come `box-shadow`/`text-shadow` del CSS: la sfocatura CSS è circa il doppio del raggio SwiftUI.
    func ombraCSS(_ colore: Color, x: CGFloat = 0, y: CGFloat, sfocatura: CGFloat) -> some View {
        shadow(color: colore, radius: sfocatura / 2, x: x, y: y)
    }

    /// Filetto luminoso interno in alto (`inset 0 1px colore`).
    func luceInterna(_ colore: Color, raggio: CGFloat = 0, bordo: CGFloat = 1) -> some View {
        overlay(alignment: .top) {
            Rectangle()
                .fill(colore)
                .frame(height: 1)
                .padding(.top, bordo)
                .padding(.horizontal, raggio * 0.6)
                .allowsHitTesting(false)
        }
    }

    /// Filetto interno in basso (`inset 0 -1px colore`).
    func ombraInternaBasso(_ colore: Color, spessore: CGFloat = 1, bordo: CGFloat = 0) -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(colore)
                .frame(height: spessore)
                .padding(.bottom, bordo)
                .allowsHitTesting(false)
        }
    }

    /// Bordo inferiore di un solo lato (`border-bottom`).
    func bordoBasso(_ colore: Color, spessore: CGFloat = 1) -> some View {
        overlay(alignment: .bottom) {
            Rectangle().fill(colore).frame(height: spessore).allowsHitTesting(false)
        }
    }

    /// Bordo superiore di un solo lato (`border-top`).
    func bordoAlto(_ colore: Color, spessore: CGFloat = 1) -> some View {
        overlay(alignment: .top) {
            Rectangle().fill(colore).frame(height: spessore).allowsHitTesting(false)
        }
    }
}

/// Rettangolo con raggi diversi per angolo (UnevenRoundedRectangle esiste solo da macOS 14).
struct RettangoloAngoli: Shape {
    var altoSinistra: CGFloat = 0
    var altoDestra: CGFloat = 0
    var bassoDestra: CGFloat = 0
    var bassoSinistra: CGFloat = 0

    func path(in r: CGRect) -> Path {
        var p = Path()
        let tl = min(altoSinistra, r.width / 2, r.height / 2)
        let tr = min(altoDestra, r.width / 2, r.height / 2)
        let br = min(bassoDestra, r.width / 2, r.height / 2)
        let bl = min(bassoSinistra, r.width / 2, r.height / 2)
        p.move(to: CGPoint(x: r.minX + tl, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - tr, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX - tr, y: r.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
        p.addArc(center: CGPoint(x: r.maxX - br, y: r.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX + bl, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + bl, y: r.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + tl))
        p.addArc(center: CGPoint(x: r.minX + tl, y: r.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}
