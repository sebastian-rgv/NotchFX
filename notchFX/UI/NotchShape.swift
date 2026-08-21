import SwiftUI

struct RoundedCornerShape: Shape {
    var topLeading: CGFloat = 0
    var topTrailing: CGFloat = 0
    var bottomLeading: CGFloat = 0
    var bottomTrailing: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let limit = min(rect.width, rect.height) / 2

        func clamped(_ value: CGFloat) -> CGFloat {
            min(max(0, value), limit)
        }

        let tl = clamped(topLeading)
        let tr = clamped(topTrailing)
        let bl = clamped(bottomLeading)
        let br = clamped(bottomTrailing)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))

        if tr > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                radius: tr,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))

        if br > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                radius: br,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))

        if bl > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                radius: bl,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))

        if tl > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                radius: tl,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }

        path.closeSubpath()
        return path
    }
}

struct NotchShape: Shape {
    var cornerRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        RoundedCornerShape(
            topLeading: 0,
            topTrailing: 0,
            bottomLeading: cornerRadius,
            bottomTrailing: cornerRadius
        )
        .path(in: rect)
    }
}
