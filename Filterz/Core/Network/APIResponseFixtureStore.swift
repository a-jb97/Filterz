// APIResponseFixtureStore.swift

import Foundation

enum APIResponseFixtureStore {
    static func bundledData(for router: Router) -> Data? {
        guard let url = Bundle.main.url(
            forResource: router.fixtureKey,
            withExtension: "json",
            subdirectory: "APIResponseFixtures"
        ) ?? Bundle.main.url(
            forResource: router.fixtureKey,
            withExtension: "json",
            subdirectory: "Resources/APIResponseFixtures"
        ) ?? Bundle.main.url(
            forResource: router.fixtureKey,
            withExtension: "json"
        ) else {
            return nil
        }

        return try? Data(contentsOf: url)
    }
}

enum APIResponseCaptureStore {
    static func save(data: Data, for router: Router) {
        #if DEBUG
        guard !data.isEmpty else { return }

        let sanitizedData = APIFixtureSanitizer.sanitize(data)
        let fileManager = FileManager.default

        guard let baseDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        let directory = baseDirectory.appendingPathComponent(
            "APIResponseCaptures",
            isDirectory: true
        )
        let fileURL = directory.appendingPathComponent(router.fixtureFileName)

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try sanitizedData.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("API response capture failed for \(router.fixtureFileName): \(error)")
            #endif
        }
        #endif
    }
}

enum APIFixtureSanitizer {
    nonisolated static func sanitize(_ data: Data) -> Data {
        guard
            let json = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(json)
        else {
            return data
        }

        let sanitized = sanitize(json)

        guard
            JSONSerialization.isValidJSONObject(sanitized),
            let sanitizedData = try? JSONSerialization.data(
                withJSONObject: sanitized,
                options: [.prettyPrinted, .sortedKeys]
            )
        else {
            return data
        }

        return sanitizedData
    }

    nonisolated private static func sanitize(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, item in
                if let replacement = replacement(for: item.key) {
                    result[item.key] = replacement
                } else {
                    result[item.key] = sanitize(item.value)
                }
            }
        }

        if let array = value as? [Any] {
            return array.map(sanitize)
        }

        return value
    }

    nonisolated private static func replacement(for key: String) -> String? {
        switch key {
        case "accessToken", "Authorization":
            return "fixture-access-token"
        case "refreshToken", "RefreshToken":
            return "fixture-refresh-token"
        case "email":
            return "fixture@example.com"
        case "phoneNum", "phone_num":
            return "010-0000-0000"
        case "deviceToken":
            return "fixture-device-token"
        case "oauthToken":
            return "fixture-oauth-token"
        case "idToken":
            return "fixture-id-token"
        case "imp_uid":
            return "imp_fixture_uid"
        case "merchant_uid":
            return "merchant_fixture_uid"
        case "pg_tid":
            return "fixture_pg_tid"
        case "card_number":
            return "0000-0000-0000-0000"
        case "buyer_email":
            return "buyer@example.com"
        case "buyer_tel":
            return "010-0000-0000"
        case "buyer_addr":
            return "fixture-address"
        case "buyer_postcode":
            return "00000"
        default:
            return nil
        }
    }
}
