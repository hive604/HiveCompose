//
//  PlatformPasteboard.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-06-28.
//

import SwiftUI
import HiveCompose

struct PlatformPasteboard {
    static let shared = PlatformPasteboard()

    var containsImage: Bool {
#if canImport(UIKit)
        UIPasteboard.general.hasImages
#elseif canImport(AppKit)
        NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil)
            || NSPasteboard.general.availableType(from: [.png, .tiff]) != nil
#else
        false
#endif
    }

    var image: PlatformImage? {
#if canImport(UIKit)
        UIPasteboard.general.image
#elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general

        if let data = pasteboard.data(forType: .png),
           let image = NSImage(data: data) {
            return image
        }

        if let data = pasteboard.data(forType: .tiff),
           let image = NSImage(data: data) {
            return image
        }

        return pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
#else
        nil
#endif
    }
}
