//
//  AdjustmentPreviewRenderKey.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-06-28.
//

import SwiftUI

struct AdjustmentPreviewRenderKey: Hashable {
    var targetSize: CGSize
    var brightness: Double
    var exposure: Double
    var contrast: Double
    var saturation: Double
    var vibrance: Double
    var sharpness: Double
    var warmth: Double
    var tint: Double

    init(targetSize: CGSize, edits: LosslessEdits) {
        self.targetSize = targetSize
        brightness = edits.brightness
        exposure = edits.exposure
        contrast = edits.contrast
        saturation = edits.saturation
        vibrance = edits.vibrance
        sharpness = edits.sharpness
        warmth = edits.warmth
        tint = edits.tint
    }
}
