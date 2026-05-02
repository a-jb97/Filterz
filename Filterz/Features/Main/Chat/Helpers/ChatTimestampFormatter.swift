import Foundation

private nonisolated func makeUTCISO8601Parser() -> ISO8601DateFormatter {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}

private nonisolated func makeUTCISO8601ParserNoFraction() -> ISO8601DateFormatter {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}

private nonisolated func makeUTCISO8601Writer() -> ISO8601DateFormatter {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    f.timeZone = TimeZone(identifier: "UTC")
    return f
}

private nonisolated func makeTimeFormatter() -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "a h:mm"
    return f
}

private nonisolated func makeDateFormatter() -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "yyyy.MM.dd"
    return f
}

private nonisolated func makeDateSeparatorFormatter() -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.dateFormat = "M월 d일 EEEE"
    return f
}

extension Date {
    nonisolated static func parseUTCISO8601(_ string: String) -> Date? {
        if let date = makeUTCISO8601Parser().date(from: string) { return date }
        return makeUTCISO8601ParserNoFraction().date(from: string)
    }

    nonisolated var iso8601UTC: String {
        makeUTCISO8601Writer().string(from: self)
    }

    nonisolated var chatDisplay: String {
        if Calendar.current.isDateInToday(self) {
            return makeTimeFormatter().string(from: self)
        }
        return makeDateFormatter().string(from: self)
    }

    nonisolated var chatTimeDisplay: String {
        makeTimeFormatter().string(from: self)
    }

    nonisolated var chatSeparatorDisplay: String {
        makeDateSeparatorFormatter().string(from: self)
    }
}
