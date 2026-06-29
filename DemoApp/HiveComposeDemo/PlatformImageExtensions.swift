//
//  PlatformImageExtensions.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-06-28.
//

import SwiftUI

#if canImport(AppKit)
extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let bitmap = bitmapImageRep else { return nil }

        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
    }

    func pngData() -> Data? {
        guard let bitmap = bitmapImageRep else { return nil }

        return bitmap.representation(
            using: .png,
            properties: [:]
        )
    }

    private var bitmapImageRep: NSBitmapImageRep? {
        guard let tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiffRepresentation)
    }
}
#endif
