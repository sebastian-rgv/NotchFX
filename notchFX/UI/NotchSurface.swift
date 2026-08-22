import SwiftUI

struct NotchSurface: View {
    let width: CGFloat
    let height: CGFloat
    let style: NotchSettings.SurfaceStyle
    let content: AnyView

    @Environment(\.notchHovering) private var isHovering
    @Environment(\.notchDragging) private var isDragging

    private var cornerRadius: CGFloat {
        if isDragging {
            return 26
        }
        if isHovering {
            return 20
        }
        return 14
    }

    var body: some View {
        ZStack(alignment: .top) {
            surfaceShape
                .fill(Color.black)
            surfaceShape
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            content
                .frame(width: width, height: height)
                .clipped()
        }
        .frame(width: width, height: height)
        .animation(.notchHover, value: cornerRadius)
    }

    private var surfaceShape: AnyShape {
        switch style {
        case .notch:
            AnyShape(NotchShape(cornerRadius: cornerRadius))
        case .capsule:
            AnyShape(RoundedCornerShape(
                topLeading: cornerRadius,
                topTrailing: cornerRadius,
                bottomLeading: cornerRadius,
                bottomTrailing: cornerRadius
            ))
        }
    }


}
