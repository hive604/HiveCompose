//
//  AngleExtensions.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-06-28.
//

import SwiftUI

extension Angle {
    static prefix func - (angle: Angle) -> Angle {
        .degrees(-angle.degrees)
    }

    static func - (lhs: Angle, rhs: Angle) -> Angle {
        .degrees(lhs.degrees - rhs.degrees)
    }

    static func + (lhs: Angle, rhs: Angle) -> Angle {
        .degrees(lhs.degrees + rhs.degrees)
    }

    var nearestQuarterTurn: Angle {
        .degrees(Double(roundedQuarterTurns) * 90)
    }

    var normalizedQuarterTurns: Int {
        ((roundedQuarterTurns % 4) + 4) % 4
    }

    var roundedQuarterTurns: Int {
        Int((degrees / 90).rounded())
    }
}
