# HiveCompose

A reusable **non-destructive photo editor component for SwiftUI apps**.

HiveCompose is designed for apps that want to offer photo editing without destroying the original image. Instead of modifying source pixels directly, edits are stored as lightweight data that can be reapplied later to recreate the edited result.

## Why HiveCompose?

Many apps need simple photo editing features such as cropping, straightening, and image adjustments, but do not need a full photo management solution.

HiveCompose aims to provide:

- A reusable SwiftUI editing component
- Non-destructive editing
- Lightweight persisted edit data
- Consistent preview and export rendering
- Easy integration into existing apps

## Use Case

A seller picks a product photo before publishing an item.

You let them:

- Snap a picture (not using HiveCompose)
- Straighten the image with tilt
- Crop to a required aspect ratio like 1:1 or 4:5
- Slightly raise exposure
- Adjust contrast, saturation, or color

You store the edits as `LosslessEdits`, so:

- The original upload stays untouched
- The seller can reopen the editor and continue from the same edit state

## Requirements

- Swift 5.10 or later
- iOS 17 or later

> Note: macOS support is planned but not currently documented as a supported platform.

## Installation

Add HiveCompose as a Swift Package dependency.

In Xcode:

1. Choose **File > Add Package Dependencies…**
2. Enter:

   ```text
   https://github.com/hive604/HiveCompose.git
   ```

3. Add the **HiveCompose** library product to your app target.

## How It Works

Instead of saving a rewritten image after each edit, HiveCompose stores edit instructions separately.

If your app keeps:

- The original source image
- The associated `LosslessEdits`

…then it can regenerate the edited result at any time.

This enables:

- Re-editing later
- Smaller storage requirements
- Reliable previews
- Consistent exports
- Sync-friendly edit metadata

## Basic Usage

HiveCompose stores edits separately from the source image. Your app keeps the original image and persists the associated edit data.

A typical integration looks like this:

```swift
import HiveCompose
```

To present the editor, use code like this (assuming imageData is optional serialized photo data):

```swift
if let imageData, let image = UIImage(data: imageData) {
  PhotoEditor(
    $edits,
    image: image
)
```

The view is intended to be presented in a sheet, and will manage its own Cancel/OK buttons. It will always present in dark mode. You can override the tintColor if your app's tint doesn't work well, or if you want to make the photo editor feel like a separate component.

You can also apply the changes to an existing photo without the UI:

```
let editedImage = UIImage(data: imageData)?.applying(
  edits,
  outputSize: size
),
```

## Current Features

### Geometry

- Cropping
- Straightening / tilt rotation
- Zooming
- Cropping to common fixed aspect ratios
- Persisted aspect ratio selection

### Tone & Color

- Brightness
- Contrast
- Saturation
- Hue adjustment
- Basic warmth/tint-style color adjustments

## Future Ideas

Potential later features include:

- Perspective / skew correction
- Additional Core Image adjustments
- macOS support

## Contributing

HiveCompose is being built iteratively. Feedback, testing, and real-world integration ideas are valuable while the API is still taking shape.

Issues should be [reported on GitHub](https://github.com/hive604/HiveCompose/issues).

## License

HiveCompose is licensed under the MIT License. See [LICENSE](LICENSE) for details.
