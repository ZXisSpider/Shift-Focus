import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info  = "INFO"
    case warn  = "WARN"
    case error = "ERROR"
}

enum Logger {

    private static let logDirectory: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Shift-Focus")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let logFileURL: URL = {
        logDirectory.appendingPathComponent("shift-focus.log")
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private static let logQueue = DispatchQueue(label: "com.shiftfocus.logger")

    // MARK: - Public API

    static func debug(_ message: String, file: String = #file, line: Int = #line) {
        write(level: .debug, message, file: file, line: line)
    }

    static func info(_ message: String, file: String = #file, line: Int = #line) {
        write(level: .info, message, file: file, line: line)
    }

    static func warn(_ message: String, file: String = #file, line: Int = #line) {
        write(level: .warn, message, file: file, line: line)
    }

    static func error(_ message: String, file: String = #file, line: Int = #line) {
        write(level: .error, message, file: file, line: line)
    }

    static var logFilePath: String { logFileURL.path }

    // MARK: - Internal

    private static func write(level: LogLevel, _ message: String, file: String, line: Int) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let entry = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(message)\n"

        print(entry, terminator: "")

        logQueue.async {
            if let data = entry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: logFileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: logFileURL)
                }
            }
        }
    }
}
