// FilterAdjustmentValues.swift

import Foundation

struct FilterAdjustmentValues: Equatable, Sendable {
    static let neutral = FilterAdjustmentValues()

    var brightness: Float = 0
    var exposure: Float = 0
    var contrast: Float = 1
    var saturation: Float = 1
    var sharpness: Float = 0
    var blur: Float = 0
    var vignette: Float = 0
    var noiseReduction: Float = 0
    var highlights: Float = 0
    var shadows: Float = 0
    var temperature: Float = 6500
    var blackPoint: Float = 0

    subscript(key: FilterAdjustmentKey) -> Float {
        get {
            switch key {
            case .brightness: brightness
            case .exposure: exposure
            case .contrast: contrast
            case .saturation: saturation
            case .sharpness: sharpness
            case .blur: blur
            case .vignette: vignette
            case .noiseReduction: noiseReduction
            case .highlights: highlights
            case .shadows: shadows
            case .temperature: temperature
            case .blackPoint: blackPoint
            }
        }
        set {
            let value = key.clamp(newValue)
            switch key {
            case .brightness: brightness = value
            case .exposure: exposure = value
            case .contrast: contrast = value
            case .saturation: saturation = value
            case .sharpness: sharpness = value
            case .blur: blur = value
            case .vignette: vignette = value
            case .noiseReduction: noiseReduction = value
            case .highlights: highlights = value
            case .shadows: shadows = value
            case .temperature: temperature = value
            case .blackPoint: blackPoint = value
            }
        }
    }

    nonisolated var dto: FilterValuesDTO {
        FilterValuesDTO(
            brightness: Double(brightness),
            exposure: Double(exposure),
            contrast: Double(contrast),
            saturation: Double(saturation),
            sharpness: Double(sharpness),
            blur: Double(blur),
            vignette: Double(vignette),
            noiseReduction: Double(noiseReduction),
            highlights: Double(highlights),
            shadows: Double(shadows),
            temperature: Double(temperature),
            blackPoint: Double(blackPoint)
        )
    }

    func clamped() -> Self {
        var values = self
        for key in FilterAdjustmentKey.allCases {
            values[key] = values[key]
        }
        return values
    }
}

extension FilterAdjustmentValues {
    init(dto: FilterValuesDTO?) {
        self.init()
        guard let dto else { return }
        if dto.isLegacyZeroPreset {
            return
        }
        brightness = dto.brightness.map(Float.init) ?? brightness
        exposure = dto.exposure.map(Float.init) ?? exposure
        contrast = dto.contrast.map(Float.init) ?? contrast
        saturation = dto.saturation.map(Float.init) ?? saturation
        sharpness = dto.sharpness.map(Float.init) ?? sharpness
        blur = dto.blur.map(Float.init) ?? blur
        vignette = dto.vignette.map(Float.init) ?? vignette
        noiseReduction = dto.noiseReduction.map(Float.init) ?? noiseReduction
        highlights = dto.highlights.map(Float.init) ?? highlights
        shadows = dto.shadows.map(Float.init) ?? shadows
        temperature = normalizedTemperature(dto.temperature.map(Float.init))
        blackPoint = dto.blackPoint.map(Float.init) ?? blackPoint
        self = clamped()
    }

    init(presets: FilterPresetValues) {
        self.init()
        if presets.isLegacyZeroPreset {
            return
        }
        brightness = presets.brightness ?? brightness
        exposure = presets.exposure ?? exposure
        contrast = presets.contrast ?? contrast
        saturation = presets.saturation ?? saturation
        sharpness = presets.sharpness ?? sharpness
        blur = presets.blur ?? blur
        vignette = presets.vignette ?? vignette
        noiseReduction = presets.noiseReduction ?? noiseReduction
        highlights = presets.highlights ?? highlights
        shadows = presets.shadows ?? shadows
        temperature = normalizedTemperature(presets.temperature)
        blackPoint = presets.blackPoint ?? blackPoint
        self = clamped()
    }

    private func normalizedTemperature(_ value: Float?) -> Float {
        guard let value, value > 0 else { return Self.neutral.temperature }
        return value
    }
}

private extension FilterValuesDTO {
    var isLegacyZeroPreset: Bool {
        let values = [
            brightness,
            exposure,
            contrast,
            saturation,
            sharpness,
            blur,
            vignette,
            noiseReduction,
            highlights,
            shadows,
            temperature,
            blackPoint
        ]
        return values.allSatisfy { ($0 ?? 0) == 0 }
    }
}

private extension FilterPresetValues {
    var isLegacyZeroPreset: Bool {
        let values = [
            brightness,
            exposure,
            contrast,
            saturation,
            sharpness,
            blur,
            vignette,
            noiseReduction,
            highlights,
            shadows,
            temperature,
            blackPoint
        ]
        return values.allSatisfy { ($0 ?? 0) == 0 }
    }
}

enum FilterAdjustmentKey: CaseIterable, Equatable, Sendable, Identifiable {
    case brightness
    case exposure
    case contrast
    case saturation
    case sharpness
    case blur
    case vignette
    case noiseReduction
    case highlights
    case shadows
    case temperature
    case blackPoint

    var id: Self { self }

    var title: String {
        switch self {
        case .brightness: "BRIGHTNESS"
        case .exposure: "EXPOSURE"
        case .contrast: "CONTRAST"
        case .saturation: "SATURATION"
        case .sharpness: "SHARPNESS"
        case .blur: "BLUR"
        case .vignette: "VIGNETTE"
        case .noiseReduction: "NOISE"
        case .highlights: "HIGHLIGHTS"
        case .shadows: "SHADOWS"
        case .temperature: "TEMPERATURE"
        case .blackPoint: "BLACKPOINT"
        }
    }

    var icon: String {
        switch self {
        case .brightness: "gearshape.fill"
        case .exposure: "plus.forwardslash.minus"
        case .contrast: "circle.lefthalf.filled"
        case .saturation: "circle.hexagongrid"
        case .sharpness: "triangle.fill"
        case .blur: "camera.filters"
        case .vignette: "camera.aperture"
        case .noiseReduction: "waveform.path.ecg"
        case .highlights: "sun.max"
        case .shadows: "shadow"
        case .temperature: "thermometer.medium"
        case .blackPoint: "circle.fill"
        }
    }

    var range: ClosedRange<Float> {
        switch self {
        case .brightness: -1...1
        case .exposure: -5...5
        case .contrast: 0...4
        case .saturation: 0...2
        case .sharpness: 0...2
        case .blur: 0...20
        case .vignette: 0...2
        case .noiseReduction: 0...1
        case .highlights: -1...1
        case .shadows: 0...1
        case .temperature: 2000...10000
        case .blackPoint: 0...1
        }
    }

    func clamp(_ value: Float) -> Float {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
