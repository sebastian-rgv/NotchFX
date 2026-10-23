import Foundation

enum ANSIStripper {
    private static let osc = try! NSRegularExpression(
        pattern: "\u{1B}\\][^\u{07}\u{1B}]*(?:\u{07}|\u{1B}\\\\)"
    )
    private static let csi = try! NSRegularExpression(
        pattern: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]"
    )

    static func strip(_ line: String) -> String {
        guard line.contains("\u{1B}") else { return line }

        let range = NSRange(line.startIndex..., in: line)
        var result = osc.stringByReplacingMatches(in: line, range: range, withTemplate: "")

        let csiRange = NSRange(result.startIndex..., in: result)
        result = csi.stringByReplacingMatches(in: result, range: csiRange, withTemplate: "")
        result = result.replacingOccurrences(of: "\u{1B}", with: "")
        return result
    }
}
