//
//  PhotoEditor.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI

public struct PhotoEditor: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    static let checkmark = "checkmark.circle.fill"
    static let xmark = "xmark.circle.fill"

    private static let minimumStoredCropDimension: CGFloat = 0.0001

    @Binding var edits: LosslessEdits
    let image: PlatformImage
    @State private var selectedSection: AdjustmentSection = .tone

    let save: (() -> Void)?
    @State private var draftEdits: LosslessEdits
    @State private var selectedAdjustment: PhotoEditConfiguration.Adjustment = .tilt
    @State private var adjustedPreviewImage: PlatformImage?
    @FocusState private var editorSurfaceIsFocused: Bool

    let photoEditConfiguration: PhotoEditConfiguration

    private var cropIsAllowed: Bool {
        photoEditConfiguration.allowedAdjustments.contains(.crop)
    }

    private var hasAvailableAdjustments: Bool {
        !photoEditConfiguration.allowedAdjustments.isEmpty
    }

    private var showsCroppingMode: Bool {
        selectedAdjustment == .crop && cropIsAllowed
    }


    public init(
        _ edits: Binding<LosslessEdits>,
        image: PlatformImage,
        configuration: PhotoEditConfiguration = PhotoEditConfiguration(),
        save: (() -> Void)? = nil
    ) {
        _edits = edits
        self.image = image
        self.photoEditConfiguration = configuration
        self.save = save

        _draftEdits = State(initialValue: edits.wrappedValue)
        let initialAdjustment = PhotoEditConfiguration.Adjustment.allCases.first(where: configuration.allowedAdjustments.contains) ?? .tilt
        _selectedAdjustment = State(initialValue: initialAdjustment)
        _selectedSection = State(initialValue: initialAdjustment.section)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
                .zIndex(1)

            editorContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .editorInitialFocus($editorSurfaceIsFocused)
        .onChange(of: edits) { _, newValue in
            draftEdits = newValue
            sanitizeSelection()
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Layout

private extension PhotoEditor {
    var topBar: some View {
        HStack {
            cancelButton

            Spacer()

            acceptButton
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    var editorContent: some View {
        GeometryReader { geometry in
            Group {
                if showsCroppingMode, hasAvailableAdjustments {
                    cropEditorContent(in: geometry.size)
                } else {
                    overlayEditorContent(in: geometry.size)
                }
            }
            .onChange(of: selectedAdjustment) { _, newValue in
                if newValue.section != selectedSection {
                    selectedSection = newValue.section
                }
            }
            .onAppear {
                sanitizeSelection()
            }
        }
        .border(.yellow, width: photoEditConfiguration.showFrames ? 1 : 0)
    }

    func cropEditorContent(in availableSize: CGSize) -> some View {
        let availableDisplayGeometry = displayGeometry(in: availableSize)
        let availableCropFrame = committedCropFrame(in: availableSize, visibleImageSize: availableDisplayGeometry.visibleImageSize)

        return VStack(spacing: 0) {
            GeometryReader { canvasGeometry in
                let canvasSize = canvasGeometry.size
                let displayGeometry = displayGeometry(in: canvasSize)
                let previewRenderKey = adjustmentPreviewRenderKey(targetSize: canvasSize)
                let currentCropFrame = committedCropFrame(in: canvasSize, visibleImageSize: displayGeometry.visibleImageSize)

                editorCanvas(canvasSize: canvasSize, currentCropFrame: currentCropFrame)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .animation(.snappy(duration: 0.25), value: selectedSection)
                    .animation(.snappy(duration: 0.25), value: selectedAdjustment)
                    .task(id: previewRenderKey) {
                        adjustedPreviewImage = image.applyingColorAdjustments(using: draftEdits, targetSize: canvasSize) ?? image
                    }
            }

            controlsPanel(
                currentCropFrame: availableCropFrame,
                canvasSize: availableSize,
                displayGeometry: availableDisplayGeometry
            )
        }
    }

    func overlayEditorContent(in canvasSize: CGSize) -> some View {
        let displayGeometry = displayGeometry(in: canvasSize)
        let previewRenderKey = adjustmentPreviewRenderKey(targetSize: canvasSize)
        let currentCropFrame = committedCropFrame(in: canvasSize, visibleImageSize: displayGeometry.visibleImageSize)

        return ZStack(alignment: .bottom) {
            editorCanvas(canvasSize: canvasSize, currentCropFrame: currentCropFrame)
                .frame(width: canvasSize.width, height: canvasSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(.snappy(duration: 0.25), value: selectedSection)
                .animation(.snappy(duration: 0.25), value: selectedAdjustment)

            if hasAvailableAdjustments {
                controlsPanel(
                    currentCropFrame: currentCropFrame,
                    canvasSize: canvasSize,
                    displayGeometry: displayGeometry
                )
                .zIndex(1)
            }
        }
        .task(id: previewRenderKey) {
            adjustedPreviewImage = image.applying(draftEdits, outputSize: canvasSize) ?? image
        }
    }

    @ViewBuilder
    func editorCanvas(canvasSize: CGSize, currentCropFrame: CGRect) -> some View {
        if showsCroppingMode {
            CroppingView(
                image: image,
                canvasSize: canvasSize,
                edits: $draftEdits,
                photoEditConfiguration: photoEditConfiguration
            )
        } else if hasAvailableAdjustments {
            adjustCanvas(
                geometrySize: canvasSize,
                cropFrame: currentCropFrame
            )
        } else {
            Image(platformImage: image)
                .resizable()
                .scaledToFit()
                .padding()
        }
    }

    func controlsPanel(
        currentCropFrame: CGRect,
        canvasSize: CGSize,
        displayGeometry: DisplayGeometry
    ) -> some View {
        ControlsView(
            edits: controlsEdits,
            cropConstraint: $draftEdits.cropConstraint,
            photoEditConfiguration: photoEditConfiguration,
            selectedAdjustment: $selectedAdjustment,
            selectedSection: $selectedSection,
            onSelectCropConstraint: { constraint in
                applyAspectRatioConstraint(
                    constraint,
                    to: currentCropFrame,
                    inCanvas: canvasSize,
                    displaySize: displayGeometry.visibleImageSize
                )
            },
            onRotate: { direction in
                withAnimation(.snappy(duration: 0.25)) {
                    rotateByQuarterTurn(direction: direction, in: canvasSize)
                }
            }
        )
    }

    @ViewBuilder
    func adjustCanvas(geometrySize: CGSize, cropFrame: CGRect) -> some View {
        ZStack {
            Color.black

            adjustmentPreviewImage
                .resizable()
                .scaledToFit()
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: geometrySize.width, height: geometrySize.height)
        .clipped()
    }

}

// MARK: - Crop State

private extension PhotoEditor {

    var controlsEdits: Binding<LosslessEdits> {
        Binding(
            get: {
                var controlEdits = draftEdits
                controlEdits.rotation = draftEdits.rotation - draftEdits.rotation.nearestQuarterTurn
                return controlEdits
            },
            set: { newValue in
                let layoutRotation = draftEdits.rotation.nearestQuarterTurn
                let incomingTiltRotation = newValue.rotation - newValue.rotation.nearestQuarterTurn

                var updatedEdits = newValue
                updatedEdits.rotation = layoutRotation + incomingTiltRotation
                draftEdits = updatedEdits
            }
        )
    }

    var adjustmentPreviewImage: Image {
        Image(platformImage: adjustedPreviewImage ?? image)
    }

    func adjustmentPreviewRenderKey(targetSize: CGSize) -> AdjustmentPreviewRenderKey {
        AdjustmentPreviewRenderKey(targetSize: targetSize, edits: draftEdits)
    }

    func sanitizeSelection() {
        if !photoEditConfiguration.allowedAdjustments.contains(selectedAdjustment),
           let firstAdjustment = PhotoEditConfiguration.Adjustment.allCases.first(where: photoEditConfiguration.allowedAdjustments.contains) {
            selectedAdjustment = firstAdjustment
        }

        if selectedAdjustment.section != selectedSection {
            selectedSection = selectedAdjustment.section
        }
    }

    func committedCropFrame(in geometrySize: CGSize, visibleImageSize: CGSize) -> CGRect {
        if let crop = draftEdits.crop?.standardized,
           crop.width > Self.minimumStoredCropDimension,
           crop.height > Self.minimumStoredCropDimension {
            return LosslessEditGeometry.croppedFrame(
                from: crop,
                in: geometrySize,
                visibleImageSize: visibleImageSize
            )
        }

        let displayGeometry = displayGeometry(in: geometrySize)
        return LosslessEditGeometry.uncroppedFrame(
            in: geometrySize,
            visibleImageSize: visibleImageSize,
            rotation: displayGeometry.tiltRotation
        )
    }

    func applyAspectRatioConstraint(
        _ constraint: CropConstraint,
        to cropFrame: CGRect,
        inCanvas geometrySize: CGSize,
        displaySize visibleImageSize: CGSize
    ) {
        draftEdits.cropConstraint = constraint

        let displayGeometry = displayGeometry(in: geometrySize)

        let updatedCropFrame: CGRect
        if let ratio = constraint.ratio {
            updatedCropFrame = CropFrameMutation.aspectRatioAdjustedCropFrame(cropFrame, ratio: ratio)
        } else {
            updatedCropFrame = cropFrame
        }

        let constrained = CropFrameMutation.constrainedCropFrame(
            updatedCropFrame,
            moving: .all,
            within: CGRect(origin: .zero, size: geometrySize),
            visibleImageSize: visibleImageSize,
            rotation: displayGeometry.tiltRotation,
            cropConstraint: constraint
        )

        draftEdits.crop = LosslessEditGeometry.normalizedCrop(
            from: CropFrameMutation.clamped(cropFrame: constrained.standardized, to: CGRect(origin: .zero, size: geometrySize)),
            in: geometrySize,
            visibleImageSize: visibleImageSize
        )
    }
}

// MARK: - Buttons

private extension PhotoEditor {
    var cancelButton: some View {
        CircularSymbolButton(systemName: Self.xmark) {
            sanitizeSelection()
            dismiss()
        }
        .accessibilityLabel("Cancel")
    }

    var acceptButton: some View {
        CircularSymbolButton(systemName: Self.checkmark) {
            edits = draftEdits
            sanitizeSelection()
            save?()
            dismiss()
        }
        .accessibilityLabel("OK")
    }
}

// MARK: - Rotation Helpers
private extension PhotoEditor {
    func rotateByQuarterTurn(direction: RotationDirection, in canvasSize: CGSize) {
        let hasStoredCrop = draftEdits.crop?.standardized.width ?? 0 > Self.minimumStoredCropDimension
            && draftEdits.crop?.standardized.height ?? 0 > Self.minimumStoredCropDimension

        guard hasStoredCrop, let crop = draftEdits.crop?.standardized else {
            draftEdits.rotation = .degrees(draftEdits.rotation.degrees + Double(direction.rawValue * 90))
            draftEdits.crop = nil
            return
        }

        let currentDisplaySize = displayGeometry(in: canvasSize).visibleImageSize
        let currentCanvasCrop = LosslessEditGeometry.croppedFrame(
            from: crop,
            in: canvasSize,
            visibleImageSize: currentDisplaySize
        )

        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let rotatedCanvasCrop = rotateAxisAlignedRect90(currentCanvasCrop, around: center, direction: direction)

        draftEdits.rotation = .degrees(draftEdits.rotation.degrees + Double(direction.rawValue * 90))

        let newDisplayGeometry = displayGeometry(in: canvasSize)
        let newDisplaySize = newDisplayGeometry.visibleImageSize
        let bounds = CropBounds(
            in: CGRect(origin: .zero, size: canvasSize),
            visibleImageSize: newDisplaySize,
            rotation: newDisplayGeometry.tiltRotation
        )
        let clamped = bounds.clamped(rotatedCanvasCrop)

        draftEdits.crop = LosslessEditGeometry.normalizedCrop(
            from: clamped,
            in: canvasSize,
            visibleImageSize: newDisplaySize
        )
    }

    /// Rotates an axis-aligned rect by ±90° around a center, returning an axis-aligned rect.
    func rotateAxisAlignedRect90(_ rect: CGRect, around center: CGPoint, direction: RotationDirection) -> CGRect {
        // Translate rect center relative to canvas center
        let dx = rect.midX - center.x
        let dy = rect.midY - center.y

        // Rotate center by ±90°: +90° -> (-y, x), -90° -> (y, -x)
        let rotatedCenter: CGPoint = direction.rawValue > 0
            ? CGPoint(x: center.x - dy, y: center.y + dx)
            : CGPoint(x: center.x + dy, y: center.y - dx)

        // Swap width/height for 90° rotations
        let newSize = CGSize(width: rect.height, height: rect.width)

        return CGRect(
            x: rotatedCenter.x - newSize.width / 2,
            y: rotatedCenter.y - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        ).standardized
    }
}

// MARK: - Display Geometry Helpers

private extension PhotoEditor {
    struct DisplayGeometry {
        let layoutRotation: Angle
        let tiltRotation: Angle
        let fittedSize: CGSize
        let visibleImageSize: CGSize

        var renderSize: CGSize {
            fittedSize.rotatedForLayout(by: -layoutRotation)
        }
    }

    func displayGeometry(in canvasSize: CGSize, rotation: Angle? = nil) -> DisplayGeometry {
        let rotation = rotation ?? draftEdits.rotation
        let layoutRotation = rotation.nearestQuarterTurn
        let tiltRotation = rotation - layoutRotation
        let layoutImageSize = image.size.rotatedForLayout(by: layoutRotation)
        let fittedSize = LosslessEditGeometry.aspectFitSize(for: layoutImageSize, in: canvasSize)
        let visibleImageSize = LosslessEditGeometry.visibleImageSize(for: fittedSize, angle: tiltRotation)

        return DisplayGeometry(
            layoutRotation: layoutRotation,
            tiltRotation: tiltRotation,
            fittedSize: fittedSize,
            visibleImageSize: visibleImageSize
        )
    }
}

// MARK: - Platform Focus

private extension View {
    @ViewBuilder
    func editorInitialFocus(_ isFocused: FocusState<Bool>.Binding) -> some View {
#if os(macOS)
        self
            .focusable()
            .focused(isFocused)
            .defaultFocus(isFocused, true)
#else
        self
#endif
    }
}

// MARK: - Preview

#Preview {
#if canImport(UIKit)
    if let image = PlatformImage(systemName: "photo") {
        PhotoEditor(
            .constant(LosslessEdits(crop: nil, rotation: .zero)),
            image: image
        )
    }
#elseif canImport(AppKit)
    let image = NSImage(size: NSSize(width: 100, height: 100))
    PhotoEditor(
        .constant(LosslessEdits(crop: nil, rotation: .zero)),
        image: image
    )
#endif
}
