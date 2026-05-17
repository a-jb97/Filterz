import ComposableArchitecture
import Foundation

struct HLSSubtitleTrack: Equatable, Sendable {
    let language: String
    let uri: URL
}

struct HLSSegmentInfo: Equatable, Sendable {
    let targetDuration: Double?
    let segmentDurations: [Double]
    let subtitleTracks: [HLSSubtitleTrack]

    init(targetDuration: Double?, segmentDurations: [Double], subtitleTracks: [HLSSubtitleTrack] = []) {
        self.targetDuration = targetDuration
        self.segmentDurations = segmentDurations
        self.subtitleTracks = subtitleTracks
    }

    var segmentCount: Int {
        segmentDurations.count
    }

    var averageDuration: Double? {
        guard !segmentDurations.isEmpty else { return nil }
        return segmentDurations.reduce(0, +) / Double(segmentDurations.count)
    }

    var minDuration: Double? {
        segmentDurations.min()
    }

    var maxDuration: Double? {
        segmentDurations.max()
    }
}

enum HLSPlaylistParser {
    nonisolated static func parseMediaPlaylist(_ playlist: String) throws -> HLSSegmentInfo {
        var targetDuration: Double?
        var segmentDurations: [Double] = []

        for rawLine in playlist.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("#EXT-X-TARGETDURATION:") {
                let value = line.replacingOccurrences(of: "#EXT-X-TARGETDURATION:", with: "")
                targetDuration = Double(value)
            } else if line.hasPrefix("#EXTINF:") {
                let value = line
                    .replacingOccurrences(of: "#EXTINF:", with: "")
                    .split(separator: ",", maxSplits: 1)
                    .first
                    .map(String.init)
                if let value, let duration = Double(value) {
                    segmentDurations.append(duration)
                }
            }
        }

        guard !segmentDurations.isEmpty else {
            throw HLSPlaylistClientError.noSegments
        }

        return HLSSegmentInfo(
            targetDuration: targetDuration,
            segmentDurations: segmentDurations
        )
    }

    nonisolated static func firstVariantURL(in playlist: String, baseURL: URL) -> URL? {
        let lines = playlist.components(separatedBy: .newlines)
        for index in lines.indices {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("#EXT-X-STREAM-INF") else { continue }

            for candidateIndex in lines.index(after: index)..<lines.endIndex {
                let candidate = lines[candidateIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !candidate.isEmpty, !candidate.hasPrefix("#") else { continue }
                return URL(string: candidate, relativeTo: baseURL)?.absoluteURL
            }
        }
        return nil
    }

    // EXT-X-MEDIA TYPE=SUBTITLES 항목을 파싱해서 (언어, URI) 목록 반환
    nonisolated static func subtitleTracks(in playlist: String, baseURL: URL) -> [(language: String, uri: URL)] {
        playlist.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("#EXT-X-MEDIA") && $0.contains("TYPE=SUBTITLES") }
            .compactMap { line -> (language: String, uri: URL)? in
                guard
                    let uriString = extractQuotedAttribute("URI", from: line),
                    let uri = URL(string: uriString, relativeTo: baseURL)?.absoluteURL
                else { return nil }
                let lang = extractQuotedAttribute("LANGUAGE", from: line) ?? "unknown"
                return (language: lang, uri: uri)
            }
    }

    private nonisolated static func extractQuotedAttribute(_ name: String, from line: String) -> String? {
        let prefix = "\(name)=\""
        guard let start = line.range(of: prefix) else { return nil }
        let tail = line[start.upperBound...]
        guard let end = tail.firstIndex(of: "\"") else { return nil }
        return String(tail[..<end])
    }
}

enum HLSPlaylistClientError: Error, Equatable {
    case invalidResponse
    case noSegments
}

struct HLSPlaylistClient: Sendable {
    var fetchSegmentInfo: @Sendable (_ url: URL) async throws -> HLSSegmentInfo
}

extension HLSPlaylistClient: DependencyKey {
    static var liveValue: HLSPlaylistClient {
        HLSPlaylistClient { url in
            let playlist = try await fetchPlaylist(url: url)
            let parsedTracks = HLSPlaylistParser.subtitleTracks(in: playlist, baseURL: url)
            let subtitleTracks = parsedTracks.map { HLSSubtitleTrack(language: $0.language, uri: $0.uri) }
#if DEBUG
            if subtitleTracks.isEmpty {
                print("HLS subtitle tracks: 없음 (EXT-X-MEDIA TYPE=SUBTITLES 미선언)")
            } else {
                for track in subtitleTracks {
                    print("HLS subtitle track: lang=\(track.language), uri=\(track.uri)")
                }
            }
#endif
            let base: HLSSegmentInfo
            if let variantURL = HLSPlaylistParser.firstVariantURL(in: playlist, baseURL: url) {
                let variantPlaylist = try await fetchPlaylist(url: variantURL)
                base = try HLSPlaylistParser.parseMediaPlaylist(variantPlaylist)
            } else {
                base = try HLSPlaylistParser.parseMediaPlaylist(playlist)
            }
            return HLSSegmentInfo(
                targetDuration: base.targetDuration,
                segmentDurations: base.segmentDurations,
                subtitleTracks: subtitleTracks
            )
        }
    }

    static var testValue: HLSPlaylistClient {
        HLSPlaylistClient { _ in
            HLSSegmentInfo(targetDuration: 6, segmentDurations: [6, 6, 5.5])
        }
    }

    private static func fetchPlaylist(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue(APIKey.apiKey, forHTTPHeaderField: "SeSACKey")
        request.setValue(APIKey.accessToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode),
            let playlist = String(data: data, encoding: .utf8)
        else {
            throw HLSPlaylistClientError.invalidResponse
        }
        return playlist
    }
}

extension DependencyValues {
    var hlsPlaylistClient: HLSPlaylistClient {
        get { self[HLSPlaylistClient.self] }
        set { self[HLSPlaylistClient.self] = newValue }
    }
}

// MARK: - WebVTT

struct VTTCue: Equatable, Sendable {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

enum VTTParser {
    nonisolated static func parse(_ content: String) -> [VTTCue] {
        var cues: [VTTCue] = []
        let lines = content.components(separatedBy: "\n")
        var i = lines.startIndex

        while i < lines.endIndex {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)

            if line.contains("-->") {
                let segments = line.components(separatedBy: "-->")
                guard segments.count >= 2,
                      let start = parseTime(segments[0].trimmingCharacters(in: .whitespaces)),
                      let end = parseTime(
                          segments[1].trimmingCharacters(in: .whitespaces)
                              .components(separatedBy: " ").first ?? ""
                      )
                else {
                    i = lines.index(after: i)
                    continue
                }

                var textLines: [String] = []
                i = lines.index(after: i)
                while i < lines.endIndex {
                    let textLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !textLine.isEmpty else { break }
                    textLines.append(textLine)
                    i = lines.index(after: i)
                }

                let text = textLines.joined(separator: "\n")
                if !text.isEmpty {
                    cues.append(VTTCue(start: start, end: end, text: text))
                }
                continue
            }

            i = lines.index(after: i)
        }

        return cues
    }

    // HH:MM:SS.mmm 및 MM:SS.mmm 두 형식 모두 지원
    private nonisolated static func parseTime(_ str: String) -> TimeInterval? {
        let parts = str.components(separatedBy: ":")
        switch parts.count {
        case 3:
            guard let h = Double(parts[0]),
                  let m = Double(parts[1]),
                  let s = Double(parts[2]) else { return nil }
            return h * 3600 + m * 60 + s
        case 2:
            guard let m = Double(parts[0]),
                  let s = Double(parts[1]) else { return nil }
            return m * 60 + s
        default:
            return nil
        }
    }
}
