import SwiftUI

extension Notification.Name {
    static let notchTapReceived = Notification.Name("notch.tap.received")
}

extension Animation {
    static let notchMorph = Animation.spring(duration: 0.45, bounce: 0.32)
    static let notchCollapse = Animation.spring(duration: 0.38, bounce: 0.14)
    static let notchShowHide = Animation.spring(duration: 0.4, bounce: 0.22)
    static let notchHover = Animation.spring(duration: 0.25, bounce: 0.18)
}

private struct NotchHoveringKey: EnvironmentKey {
    static let defaultValue = false
}

private struct NotchDraggingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var notchHovering: Bool {
        get { self[NotchHoveringKey.self] }
        set { self[NotchHoveringKey.self] = newValue }
    }

    var notchDragging: Bool {
        get { self[NotchDraggingKey.self] }
        set { self[NotchDraggingKey.self] = newValue }
    }
}

struct NotchGestureModifier: ViewModifier {
    let onTap: () -> Void
    let onDismiss: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .offset(y: dragOffset)
            .opacity(dragOpacity)
            .environment(\.notchHovering, isHovering)
            .environment(\.notchDragging, isDragging)
            .onHover { hovering in
                withAnimation(.notchHover) {
                    isHovering = hovering
                }
            }
            .onTapGesture(perform: onTap)
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .updating($dragOffset) { value, state, _ in
                        state = GestureMath.dampedOffset(value.translation.height)
                    }
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onEnded { value in
                        if GestureMath.shouldDismiss(
                            translation: value.translation,
                            predictedEndTranslation: value.predictedEndTranslation
                        ) {
                            onDismiss()
                        }
                    }
            )
    }

    private var dragOpacity: Double {
        guard isDragging else { return 1 }
        let progress = min(1, max(0, dragOffset / GestureMath.dismissThreshold))
        return 1 - progress * 0.55
    }
}

extension View {
    func notchGestures(
        onTap: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(NotchGestureModifier(onTap: onTap, onDismiss: onDismiss))
    }
}
