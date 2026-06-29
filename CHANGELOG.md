# HiveCompose Change Log

## 1.0.3

* Reduced repeated Core Image work during crop interaction and unrelated UI refreshes.
* Removed temporary debug logging from PhotoEditor.
* Reorganized the demo app into DemoApp/HiveComposeDemo.xcodeproj.
* Changed the demo app to consume HiveCompose as a local Swift package instead of building an embedded framework target.
* Fixed the misspelled PllatformImage.swift filename.

## 1.0.2

* Added macOS 14 support to the package.
* Introduced a cross-platform PlatformImage abstraction so photo editing works with UIImage on Apple mobile platforms and NSImage on macOS.
* Updated PhotoEditor and CroppingView to use platform-neutral image rendering.
* Added macOS-compatible image resizing, Core Image conversion, color adjustment, and edit rendering paths.
* Updated previews to work across UIKit and AppKit platforms.
* Updated the demo app image display and sharing code to use platform-neutral SwiftUI image initialization.
* Updated the MIT license copyright holder to “Hive 604 Software Inc.”

## 1.0.1

* Improved documentation and other meta changes.
