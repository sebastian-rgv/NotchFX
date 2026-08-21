import CoreGraphics
import Foundation

enum GestureMath {
    static let dismissThreshold: CGFloat = 44
    static let dismissPredictedThreshold: CGFloat = 140
    static let rubberBandLinearLimit: CGFloat = 120

    static func dampedOffset(_ raw: CGFloat) -> CGFloat {
        guard abs(raw) > rubberBandLinearLimit else { return raw }

        let sign: CGFloat = raw < 0 ? -1 : 1
        let overflow = abs(raw) - rubberBandLinearLimit
        let resistance = overflow / (1 + overflow / rubberBandLinearLimit)
        return sign * (rubberBandLinearLimit + resistance)
    }

    static func shouldDismiss(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        threshold: CGFloat = GestureMath.dismissThreshold
    ) -> Bool {
        translation.height > threshold
            || predictedEndTranslation.height > dismissPredictedThreshold
    }
}
