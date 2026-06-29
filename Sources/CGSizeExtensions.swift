//
//  CGSizeExtensions.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-06-28.
//

import SwiftUI

extension CGSize {
    func rotatedForLayout(by angle: Angle) -> CGSize {
        let normalizedQuarterTurns = angle.normalizedQuarterTurns
        switch normalizedQuarterTurns {
        case 1, 3:
            return CGSize(width: height, height: width)
        default:
            return self
        }
    }
}
