import Foundation

/// Accumulates a byte stream from a process and splits it into complete text
/// lines, holding back any trailing partial line until more data arrives.
struct TerminalLineBuffer {
    private var pending = Data()

    mutating func append(_ chunk: Data) -> [String] {
        pending.append(chunk)

        var lines: [String] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            var lineBytes = pending.subdata(in: pending.startIndex..<newline)
            if lineBytes.last == 0x0D {
                lineBytes.removeLast()
            }
            pending.removeSubrange(pending.startIndex...newline)
            lines.append(String(decoding: lineBytes, as: UTF8.self))
        }
        return lines
    }

    /// Returns whatever is left in the buffer (a final line without a newline).
    mutating func flush() -> String? {
        guard !pending.isEmpty else { return nil }
        let remainder = String(decoding: pending, as: UTF8.self)
        pending.removeAll()
        return remainder
    }
}
