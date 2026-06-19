//
//  UIImageExtensions.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-25.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Cross-platform image editing API on PlatformImage

public extension PlatformImage {
    /// Applies the provided lossless edits using the image's current size as the render target.
    ///
    /// This applies crop, rotation, and color adjustments. The `cropConstraint` stored in
    /// `LosslessEdits` is preserved for UI state only and is not used during rendering.
    func applying(_ edits: LosslessEdits) -> PlatformImage? {
        applying(edits, outputSize: cgSize)
    }

    /// Applies the provided lossless edits and renders the result to fit the requested output size.
    ///
    /// This applies crop, rotation, and color adjustments. The `cropConstraint` stored in
    /// `LosslessEdits` is preserved for UI state only and is not used during rendering.
    ///
    /// - Parameters:
    ///   - edits: The edit description to render.
    ///   - outputSize: The maximum rendered image size.
    /// - Returns: A new image containing the rendered edits, or `nil` if rendering fails.
    func applying(_ edits: LosslessEdits, outputSize: CGSize) -> PlatformImage? {
        let sourceSize = cgSize
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        guard outputSize.width > 0, outputSize.height > 0 else { return nil }

        let normalized = self.normalizedUpOrientation()
        let sourceImage = normalized.applyingColorAdjustments(using: edits, targetSize: outputSize) ?? normalized

        let imageSize = sourceImage.cgSize
        let layoutRotation = edits.rotation.nearestQuarterTurn
        let tiltRotation = edits.rotation - layoutRotation
        let layoutImageSize = imageSize.rotatedForLayout(by: layoutRotation)
        let fittedSize = LosslessEditGeometry.aspectFitSize(for: layoutImageSize, in: layoutImageSize)
        let visibleImageSize = LosslessEditGeometry.visibleImageSize(for: fittedSize, angle: tiltRotation)
        let renderSize = fittedSize.rotatedForLayout(by: -layoutRotation)
        let renderScale = LosslessEditGeometry.rotationFitScale(for: fittedSize, angle: tiltRotation)

        let cropFrame: CGRect
        if let crop = edits.crop?.standardized,
           crop.width > 0.0001,
           crop.height > 0.0001 {
            cropFrame = LosslessEditGeometry.croppedFrame(
                from: crop,
                in: layoutImageSize,
                visibleImageSize: visibleImageSize
            )
        } else {
            cropFrame = LosslessEditGeometry.uncroppedFrame(
                in: layoutImageSize,
                visibleImageSize: visibleImageSize,
                rotation: tiltRotation
            )
        }

        let outputScale = min(
            outputSize.width / cropFrame.width,
            outputSize.height / cropFrame.height,
            1
        )
        let outputBounds = CGRect(origin: .zero, size: CGSize(
            width: ceil(cropFrame.width * outputScale),
            height: ceil(cropFrame.height * outputScale)
        ))
        guard outputBounds.width > 0, outputBounds.height > 0 else { return nil }

#if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: outputBounds.size, format: format)
        return renderer.image { _ in
            let outputCenter = CGPoint(x: outputBounds.midX, y: outputBounds.midY)
            let context = UIGraphicsGetCurrentContext()
            context?.translateBy(x: outputCenter.x, y: outputCenter.y)
            context?.scaleBy(x: outputScale, y: outputScale)
            context?.translateBy(
                x: layoutImageSize.width / 2 - cropFrame.midX,
                y: layoutImageSize.height / 2 - cropFrame.midY
            )
            context?.rotate(by: CGFloat(edits.rotation.radians))
            context?.scaleBy(x: renderScale, y: renderScale)

            let imageRect = CGRect(
                x: -renderSize.width / 2,
                y: -renderSize.height / 2,
                width: renderSize.width,
                height: renderSize.height
            )

            sourceImage.draw(in: imageRect)
        }
#elseif canImport(AppKit)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(outputBounds.width),
            pixelsHigh: Int(outputBounds.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { return nil }
        rep.size = outputBounds.size

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = context
        context.cgContext.translateBy(x: outputBounds.midX, y: outputBounds.midY)
        context.cgContext.scaleBy(x: outputScale, y: outputScale)
        context.cgContext.translateBy(
            x: layoutImageSize.width / 2 - cropFrame.midX,
            y: layoutImageSize.height / 2 - cropFrame.midY
        )
        context.cgContext.rotate(by: CGFloat(edits.rotation.radians))
        context.cgContext.scaleBy(x: renderScale, y: renderScale)

        let imageRect = CGRect(
            x: -renderSize.width / 2,
            y: -renderSize.height / 2,
            width: renderSize.width,
            height: renderSize.height
        )
        sourceImage.draw(in: imageRect)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let output = NSImage(size: outputBounds.size)
        output.addRepresentation(rep)
        return output
#else
        return nil
#endif
    }
}

// MARK: - Color adjustments

public extension PlatformImage {
    func applyingColorAdjustments(using edits: LosslessEdits, targetSize: CGSize? = nil) -> PlatformImage? {
        let workingImage = resizedToFit(targetSize) ?? self
        guard let inputCI = CIImage.from(platformImage: workingImage) else { return nil }

        let temperatureAndTint = CIFilter.temperatureAndTint()
        temperatureAndTint.inputImage = inputCI
        temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
        temperatureAndTint.targetNeutral = CIVector(
            x: 6500 - (CGFloat(edits.warmth) * 2000),
            y: CGFloat(edits.tint) * 100
        )
        guard let whiteBalancedImage = temperatureAndTint.outputImage else { return nil }

        let vibrance = CIFilter.vibrance()
        vibrance.inputImage = whiteBalancedImage
        vibrance.amount = Float(edits.vibrance)
        guard let vibranceAdjustedImage = vibrance.outputImage else { return nil }

        let exposureAdjust = CIFilter.exposureAdjust()
        exposureAdjust.inputImage = vibranceAdjustedImage
        exposureAdjust.ev = Float(edits.exposure)
        guard let exposureAdjustedImage = exposureAdjust.outputImage else { return nil }

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = exposureAdjustedImage
        colorControls.brightness = Float(edits.brightness)
        colorControls.contrast = Float(edits.contrast)
        colorControls.saturation = Float(edits.saturation)
        guard let colorAdjustedImage = colorControls.outputImage else { return nil }

        let sharpenLuminance = CIFilter.sharpenLuminance()
        sharpenLuminance.inputImage = colorAdjustedImage
        sharpenLuminance.sharpness = Float(edits.sharpness)
        guard let outputImage = sharpenLuminance.outputImage else { return nil }

        let context = CIContext(options: nil)
        guard let renderedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

#if canImport(UIKit)
        return PlatformImage(cgImage: renderedCGImage, scale: workingImage.scale, orientation: .up)
#elseif canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: renderedCGImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
#else
        return nil
#endif
    }
}

// MARK: - Resizing and normalization helpers

public extension PlatformImage {
    var cgSize: CGSize {
#if canImport(UIKit)
        return self.size
#elseif canImport(AppKit)
        return self.size
#endif
    }

    func resizedToFit(_ targetSize: CGSize?) -> PlatformImage? {
        guard let targetSize, targetSize.width > 0, targetSize.height > 0 else { return nil }
        let currentSize = cgSize
        guard currentSize.width > targetSize.width || currentSize.height > targetSize.height else { return self }

        let fittedSize = LosslessEditGeometry.aspectFitSize(for: currentSize, in: targetSize)
        guard fittedSize.width > 0, fittedSize.height > 0 else { return nil }

#if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: fittedSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: fittedSize))
        }
#elseif canImport(AppKit)
        let output = NSImage(size: fittedSize)
        output.lockFocus()
        self.draw(in: CGRect(origin: .zero, size: fittedSize))
        output.unlockFocus()
        return output
#else
        return nil
#endif
    }

    func normalizedUpOrientation() -> PlatformImage {
#if canImport(UIKit)
        if self.imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = self.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: self.cgSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: self.cgSize))
        }
#elseif canImport(AppKit)
        // NSImage doesn't carry EXIF orientation the same way; return self.
        return self
#else
        return self
#endif
    }

    var swiftUIImage: Image {
        return Image(platformImage: self)
    }
}

// MARK: - CIImage bridging

private extension CIImage {
    static func from(platformImage: PlatformImage) -> CIImage? {
#if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
        let uiImage = platformImage as UIImage
        if let cg = uiImage.cgImage {
            return CIImage(cgImage: cg)
        }
        if let ci = uiImage.ciImage {
            return ci
        }
        return nil
#elseif os(macOS)
        var rect = CGRect(origin: .zero, size: (platformImage as NSImage).size)
        if let cg = (platformImage as NSImage).cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return CIImage(cgImage: cg)
        }
        // As a fallback, attempt to create bitmap rep and extract CGImage
        guard let tiff = (platformImage as NSImage).tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage else { return nil }
        return CIImage(cgImage: cg)
#else
        return nil
#endif
    }
}

private extension CGSize {
    func rotatedForLayout(by angle: Angle) -> CGSize {
        switch angle.normalizedQuarterTurns {
        case 1, 3:
            return CGSize(width: height, height: width)
        default:
            return self
        }
    }
}

private extension Angle {
    static prefix func - (angle: Angle) -> Angle {
        .degrees(-angle.degrees)
    }

    static func - (lhs: Angle, rhs: Angle) -> Angle {
        .degrees(lhs.degrees - rhs.degrees)
    }

    var nearestQuarterTurn: Angle {
        .degrees(Double(roundedQuarterTurns) * 90)
    }

    var normalizedQuarterTurns: Int {
        ((roundedQuarterTurns % 4) + 4) % 4
    }

    private var roundedQuarterTurns: Int {
        Int((degrees / 90).rounded())
    }
}
