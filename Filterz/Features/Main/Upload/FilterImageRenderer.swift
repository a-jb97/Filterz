// FilterImageRenderer.swift

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum FilterImageRenderer {
    struct PreviewSource: @unchecked Sendable {
        let image: UIImage
        let ciImage: CIImage
        let extent: CGRect
    }

    nonisolated private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpaceCreateDeviceRGB()
    ])

    nonisolated static func makePreviewSource(from sourceData: Data, maxSide: CGFloat = 760) -> PreviewSource? {
        guard let image = UIImage(data: sourceData) else { return nil }
        return makePreviewSource(from: image, maxSide: maxSide)
    }

    nonisolated static func makePreviewSource(from image: UIImage, maxSide: CGFloat = 760) -> PreviewSource? {
        let normalized = normalize(image, maxSide: maxSide)
        guard let ciImage = CIImage(image: normalized) else { return nil }
        return PreviewSource(image: normalized, ciImage: ciImage, extent: ciImage.extent)
    }

    nonisolated static func previewImage(from source: PreviewSource, values: FilterAdjustmentValues) -> UIImage? {
        let filtered = apply(values: values, to: source.ciImage, extent: source.extent)
        guard let cgImage = context.createCGImage(filtered, from: source.extent) else {
            return source.image
        }
        return UIImage(cgImage: cgImage)
    }

    nonisolated static func previewData(from sourceData: Data, values: FilterAdjustmentValues) -> Data? {
        guard let source = makePreviewSource(from: sourceData, maxSide: 760),
              let image = previewImage(from: source, values: values)
        else { return nil }
        return image.jpegData(compressionQuality: 0.9)
    }

    nonisolated static func renderedData(
        from sourceData: Data,
        values: FilterAdjustmentValues,
        compressionQuality: CGFloat = 0.92
    ) -> Data? {
        guard let source = makePreviewSource(from: sourceData, maxSide: .greatestFiniteMagnitude),
              let image = previewImage(from: source, values: values)
        else { return nil }
        return image.jpegData(compressionQuality: compressionQuality)
    }

    nonisolated private static func apply(
        values: FilterAdjustmentValues,
        to image: CIImage,
        extent: CGRect
    ) -> CIImage {
        var output = image

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = output
        colorControls.brightness = values.brightness
        colorControls.contrast = values.contrast
        colorControls.saturation = values.saturation
        output = colorControls.outputImage ?? output

        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = output
        exposure.ev = values.exposure
        output = exposure.outputImage ?? output

        if values.temperature != 6500 {
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = output
            temperature.neutral = CIVector(x: 6500, y: 0)
            temperature.targetNeutral = CIVector(x: CGFloat(values.temperature), y: 0)
            output = temperature.outputImage ?? output
        }

        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = output
        highlightShadow.highlightAmount = 1 + values.highlights
        highlightShadow.shadowAmount = values.shadows
        output = highlightShadow.outputImage ?? output

        if values.blackPoint > 0 {
            let blackPoint = CIFilter.colorPolynomial()
            blackPoint.inputImage = output
            let offset = CGFloat(values.blackPoint)
            let slope = 1 - offset
            blackPoint.redCoefficients = CIVector(x: offset, y: slope, z: 0, w: 0)
            blackPoint.greenCoefficients = CIVector(x: offset, y: slope, z: 0, w: 0)
            blackPoint.blueCoefficients = CIVector(x: offset, y: slope, z: 0, w: 0)
            blackPoint.alphaCoefficients = CIVector(x: 0, y: 1, z: 0, w: 0)
            output = blackPoint.outputImage ?? output
        }

        if values.noiseReduction > 0 {
            let noise = CIFilter.noiseReduction()
            noise.inputImage = output
            noise.noiseLevel = values.noiseReduction
            noise.sharpness = 0.4
            output = noise.outputImage ?? output
        }

        if values.sharpness > 0 {
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = output
            sharpen.sharpness = values.sharpness
            output = sharpen.outputImage ?? output
        }

        if values.blur > 0 {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = output.clampedToExtent()
            blur.radius = values.blur
            output = (blur.outputImage ?? output).cropped(to: extent)
        }

        if values.vignette > 0 {
            let vignette = CIFilter.vignette()
            vignette.inputImage = output
            vignette.intensity = values.vignette
            vignette.radius = Float(max(extent.width, extent.height))
            output = vignette.outputImage ?? output
        }

        return output.cropped(to: extent)
    }

    nonisolated private static func normalize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let side = max(image.size.width, image.size.height)
        let scale = min(maxSide / side, 1)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
