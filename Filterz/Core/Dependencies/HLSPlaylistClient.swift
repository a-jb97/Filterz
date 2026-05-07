import ComposableArchitecture
import Foundation

struct HLSSegmentInfo: Equatable, Sendable {
    let targetDuration: Double?
    let segmentDurations: [Double]

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
            if let variantURL = HLSPlaylistParser.firstVariantURL(in: playlist, baseURL: url) {
                let variantPlaylist = try await fetchPlaylist(url: variantURL)
                return try HLSPlaylistParser.parseMediaPlaylist(variantPlaylist)
            }
            return try HLSPlaylistParser.parseMediaPlaylist(playlist)
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
