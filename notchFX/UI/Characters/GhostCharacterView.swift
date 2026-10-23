import SwiftUI

struct GhostShape: Shape {
    var waves: Int = 3

    func path(in rect: CGRect) -> Path {
        let amplitude = rect.height * 0.12
        let bottomY = rect.maxY - amplitude
        let radius = rect.width / 2

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: bottomY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: bottomY))

        let segment = rect.width / CGFloat(max(1, waves))
        for index in 0..<max(1, waves) {
            let startX = rect.maxX - CGFloat(index) * segment
            let endX = startX - segment
            path.addQuadCurve(
                to: CGPoint(x: endX, y: bottomY),
                control: CGPoint(x: (startX + endX) / 2, y: bottomY + amplitude * 2)
            )
        }

        path.closeSubpath()
        return path
    }
}

struct GhostCharacterView: View {
    let style: GhostStyle
    let state: CharacterRunState
    var size: CGFloat = 32

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !state.isRunning)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let running = state.isRunning
            let bob = running ? sin(time * 4.4) * size * 0.05 : 0
            let blinkPhase = time.truncatingRemainder(dividingBy: 3.4)
            let blinking = running && blinkPhase < 0.12
            let lookX = running ? sin(time * 2.6) * size * 0.035 : 0
            let lookY = eyeOffsetY

            ZStack {
                GhostShape()
                    .fill(style.color)

                HStack(spacing: size * 0.14) {
                    eye(blinking: blinking, lookX: lookX, lookY: lookY)
                    eye(blinking: blinking, lookX: lookX, lookY: lookY)
                }
                .offset(y: -size * 0.08)
            }
            .frame(width: size, height: size)
            .offset(y: bob)
        }
        .frame(width: size, height: size)
    }

    private var eyeOffsetY: CGFloat {
        switch state {
        case .succeeded:
            return -size * 0.05
        case .failed:
            return size * 0.05
        case .idle, .running, .stopped:
            return 0
        }
    }

    private func eye(blinking: Bool, lookX: CGFloat, lookY: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.white)
            Ellipse()
                .fill(Color(red: 0.10, green: 0.12, blue: 0.36))
                .frame(width: size * 0.11, height: size * 0.13)
                .offset(x: lookX, y: lookY)
        }
        .frame(width: size * 0.23, height: blinking ? size * 0.035 : size * 0.30)
    }
}

extension GhostStyle {
    var color: Color {
        switch self {
        case .blinky:
            return Color(red: 0.93, green: 0.16, blue: 0.16)
        case .pinky:
            return Color(red: 0.98, green: 0.55, blue: 0.76)
        case .inky:
            return Color(red: 0.24, green: 0.84, blue: 0.95)
        case .clyde:
            return Color(red: 0.98, green: 0.65, blue: 0.19)
        }
    }
}
