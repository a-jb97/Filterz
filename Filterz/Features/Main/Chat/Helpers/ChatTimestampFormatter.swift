import Foundation

private nonisolated(unsafe) let utcISO8601Parser: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private nonisolated(unsafe) let utcISO8601ParserNoFraction: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private nonisolated(unsafe) let utcISO8601Writer: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    f.timeZone = TimeZone(identifier: "UTC")
    return f
}()

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "a h:mm"
    return f
}()

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "yyyy.MM.dd"
    return f
}()

private let dateSeparatorFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "M월 d일 a h:mm"
    return f
}()

extension Date {
    nonisolated static func parseUTCISO8601(_ string: String) -> Date? {
        if let date = utcISO8601Parser.date(from: string) { return date }
        return utcISO8601ParserNoFraction.date(from: string)
    }

    nonisolated var iso8601UTC: String {
        utcISO8601Writer.string(from: self)
    }

    nonisolated var chatDisplay: String {
        if Calendar.current.isDateInToday(self) {
            return timeFormatter.string(from: self)
        }
        return dateFormatter.string(from: self)
    }

    nonisolated var chatSeparatorDisplay: String {
        dateSeparatorFormatter.string(from: self)
    }
}
