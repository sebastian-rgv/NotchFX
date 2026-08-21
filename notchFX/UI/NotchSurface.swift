import SwiftUI

struct NotchSurface: View {
    let width: CGFloat
    let height: CGFloat
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
            NotchShape(cornerRadius: cornerRadius)
                .fill(.black)
            content
                .frame(width: width, height: height)
                .clipped()
        }
        .frame(width: width, height: height)
        .animation(.notchHover, value: cornerRadius)
    }
}
