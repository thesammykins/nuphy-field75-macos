import Foundation

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let level: Level
    let message: String

    enum Level: String {
        case info = "Info"
        case success = "Success"
        case warning = "Warning"
        case error = "Error"
    }

    init(_ level: Level, _ message: String, date: Date = Date()) {
        self.level = level
        self.message = message
        self.date = date
    }
}
