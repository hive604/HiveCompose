//
//  PhotoEditConfiguration.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-25.
//

import SwiftUI

public struct PhotoEditConfiguration {
    public enum Adjustment: String, CaseIterable, Hashable, Identifiable {
        case crop
        case tilt
        case brightness
        case exposure
        case contrast
        case saturation
        case vibrance
        case sharpness
        case warmth
        case tint

        public var id: String { rawValue }

        private struct Info {
            let title: LocalizedStringResource
            let systemImage: String
        }

        private static let info: [Adjustment: Info] = [
            .crop: Info(title: "Crop", systemImage: "crop"),
            .tilt: Info(title: "Tilt", systemImage: "rectangle.landscape.rotate"),
            .brightness: Info(title: "Brightness", systemImage: "sun.max"),
            .exposure: Info(title: "Exposure", systemImage: "plusminus.circle"),
            .contrast: Info(title: "Contrast", systemImage: "circle.lefthalf.filled"),
            .saturation: Info(title: "Saturation", systemImage: "drop"),
            .vibrance: Info(title: "Vibrance", systemImage: "paintbrush"),
            .sharpness: Info(title: "Sharpness", systemImage: "righttriangle.fill"),
            .warmth: Info(title: "Warmth", systemImage: "thermometer.variable"),
            .tint: Info(title: "Tint", systemImage: "drop.halffull")
        ]

        var title: LocalizedStringResource {
            info.title
        }

        var systemImage: String {
            info.systemImage
        }

        private var info: Info {
            Self.info[self]!
        }

        var section: AdjustmentSection {
            switch self {
            case .crop, .tilt:
                return .geometry
            case .brightness, .exposure, .contrast, .sharpness:
                return .tone
            case .saturation, .vibrance:
                return .color
            case .warmth, .tint:
                return .whiteBalance
            }
        }

        var displayRange: ClosedRange<Double> {
            switch self {
            case .crop:
                return 0...1
            case .tilt:
                return -15...15
            case .brightness, .exposure, .vibrance, .warmth, .tint:
                return -1...1
            case .contrast, .saturation, .sharpness:
                return 0...2
            }
        }

        var defaultValue: Double {
            switch self {
            case .crop:
                return 0.0
            case .tilt, .brightness, .exposure, .vibrance, .sharpness, .warmth, .tint:
                return 0.0
            case .contrast, .saturation:
                return 1.0
            }
        }

        var isSliderAdjustment: Bool {
            self != .crop
        }
    }

    public var croppingEffects: CroppingEffectSet
    public var allowedAdjustments: Set<Adjustment>
    public var showFrames = false

    public init(
        croppingEffects: CroppingEffectSet = CroppingEffectSet([.dim(opacity: 0.4)]),
        allowedAdjustments: Set<Adjustment> = Set(Adjustment.allCases)
    ) {
        self.croppingEffects = croppingEffects
        self.allowedAdjustments = allowedAdjustments
    }
}
