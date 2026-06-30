# HiveCompose Change Log

## 1.1.0

The 1.1.0 is mostly compatible with 1.0, but as the visual layout has changed you should change to presenting it with `losslessPhotoEditor(isPresented:content:)`.

- Added a public `losslessPhotoEditor(isPresented:content:)` presentation modifier for presenting the photo editor from client apps.
  - Uses `fullScreenCover` on UIKit platforms.
  - Hides the status bar while the editor is presented on UIKit.
  - Uses a sheet with a minimum height on AppKit platforms.
- Updated the photo editor layout so the accept/cancel controls float over the editor instead of occupying a fixed top bar.
  - The top controls now account for the top safe area.
  - The editor background now uses platform-native background colors instead of hardcoded black.
- Changed the adjustment editor layout so controls sit below the preview instead of overlaying the bottom of the image preview.
- Remove tint from rotate buttons.
- Added a macOS sheet minimum height for the shared photo editor presentation helper.

## 1.0.4

Package

* Share adjustment metadata between regular and compact controls.
* Reduce duplicated UI code.
* Fix crop draft state after layout size changes.
* Improve photo editor presentation on macOS with a minimum editor height.
* Improve macOS rendering for rotated and cropped images.

Demo

* Refresh the demo app with a renamed HiveComposeDemo target and reorganized source layout.
* Add cross-platform image import from Photos, files, pasteboard, and camera where available.
* Move demo configuration into a toolbar popover.

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
