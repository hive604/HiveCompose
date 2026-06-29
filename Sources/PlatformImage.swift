//
//  PlatformImage.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-06-18.
//

import SwiftUI

#if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
public typealias PlatformImage = UIImage
#elseif os(macOS)
public typealias PlatformImage = NSImage
#else
// Fallback to UIKit if available; otherwise, no PlatformImage on this platform
#if canImport(UIKit)
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
public typealias PlatformImage = NSImage
#endif
#endif

public extension Image {
    /// Creates a SwiftUI Image from a cross-platform PlatformImage.
    /// - Parameter platformImage: A UIImage on iOS/tvOS/watchOS/visionOS or an NSImage on macOS.
    init(platformImage: PlatformImage) {
#if canImport(UIKit)
        self = Image(uiImage: platformImage)
#elseif canImport(AppKit)
        self = Image(nsImage: platformImage)
#else
        self = Image(systemName: "photo")
#endif
    }
}
