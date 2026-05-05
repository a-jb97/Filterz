//
//  FilterzTests.swift
//  FilterzTests
//
//  Created by 전민돌 on 4/22/26.
//

import Testing
import Foundation
@testable import Filterz

struct FilterzTests {

    @MainActor
    @Test func filterAdjustmentDefaultsConvertToDTO() async throws {
        let values = FilterAdjustmentValues()

        #expect(values.dto.brightness == 0)
        #expect(values.dto.contrast == 1)
        #expect(values.dto.saturation == 1)
        #expect(values.dto.highlights == 0)
        #expect(values.dto.temperature == 6500)
        #expect(values.dto.blackPoint == 0)
    }

    @MainActor
    @Test func filterAdjustmentValuesClampDTOInput() async throws {
        let dto = FilterValuesDTO(
            brightness: 2,
            exposure: -10,
            contrast: 8,
            saturation: -1,
            sharpness: 4,
            blur: 30,
            vignette: 4,
            noiseReduction: 2,
            highlights: -1,
            shadows: 2,
            temperature: 12000,
            blackPoint: -1
        )
        let values = FilterAdjustmentValues(dto: dto)

        #expect(values.brightness == 1)
        #expect(values.exposure == -5)
        #expect(values.contrast == 4)
        #expect(values.saturation == 0)
        #expect(values.sharpness == 2)
        #expect(values.blur == 20)
        #expect(values.vignette == 2)
        #expect(values.noiseReduction == 1)
        #expect(values.highlights == -1)
        #expect(values.shadows == 1)
        #expect(values.temperature == 10000)
        #expect(values.blackPoint == 0)
    }

    @MainActor
    @Test func legacyZeroPresetUsesNeutralValues() async throws {
        let dto = FilterValuesDTO(
            brightness: 0,
            exposure: 0,
            contrast: 0,
            saturation: 0,
            sharpness: 0,
            blur: 0,
            vignette: 0,
            noiseReduction: 0,
            highlights: 0,
            shadows: 0,
            temperature: 0,
            blackPoint: 0
        )
        let values = FilterAdjustmentValues(dto: dto)

        #expect(values == .neutral)
        #expect(values.contrast == 1)
        #expect(values.saturation == 1)
        #expect(values.highlights == 0)
        #expect(values.temperature == 6500)
    }

    @MainActor
    @Test func invalidLegacyTemperatureUsesNeutralTemperature() async throws {
        let dto = FilterValuesDTO(
            brightness: 0.15,
            exposure: 0.3,
            contrast: 1.05,
            saturation: 1.1,
            sharpness: 0.5,
            blur: 0,
            vignette: 0.2,
            noiseReduction: 0.1,
            highlights: -0.1,
            shadows: 0.15,
            temperature: 0,
            blackPoint: 0.03
        )
        let values = FilterAdjustmentValues(dto: dto)

        #expect(values.temperature == 6500)
        #expect(values.highlights == -0.1)
        #expect(values.contrast == 1.05)
        #expect(values.saturation == 1.1)
    }

    @MainActor
    @Test func photoMetadataFileSizeFormatsBytesAsMegabytes() async throws {
        let exif = FilterExifData(
            camera: nil,
            lensInfo: nil,
            focalLength: nil,
            aperture: nil,
            iso: nil,
            shutterSpeed: nil,
            pixelWidth: nil,
            pixelHeight: nil,
            fileSize: 2_306_867,
            format: nil,
            dateTimeOriginal: nil,
            latitude: nil,
            longitude: nil
        )

        #expect(exif.fileSizeFormatted == "2.2MB")
    }

    @Test func rootFilterCommentRequestOmitsParentComment() throws {
        let query = FilterCommentRequestDTO(content: "hello", parentComment: nil)
        let data = try JSONEncoder().encode(query)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(object["content"] == "hello")
        #expect(object["parent_comment_id"] == nil)
    }

    @Test func replyFilterCommentRequestEncodesParentComment() throws {
        let query = FilterCommentRequestDTO(content: "reply", parentComment: "parent-1")
        let data = try JSONEncoder().encode(query)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(object["content"] == "reply")
        #expect(object["parent_comment_id"] == "parent-1")
    }

}
