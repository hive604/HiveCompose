//
//  ContentView.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-04-21.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import HiveCompose

struct ContentView: View {
    // Store only a lightweight reference (filename) in UserDefaults
    @AppStorage("selectedImageUUIDString") private var selectedImageUUIDString: String?

    // In-memory image for display
    @State private var displayedImage: UIImage?
    @State private var losslessEdits = LosslessEdits(crop: nil, rotation: .zero)

    // Temporary selection binding for the picker
    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingEditor = false
    @State private var isShowingEditorOptions = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingFileImporter = false
    @State private var isShowingCamera = false
    @State private var canPasteImage = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedPanel: EditorOptionsPanel.OptionsPanel = .crop

    private var configurableAdjustments: [PhotoEditConfiguration.Adjustment] {
        PhotoEditConfiguration.Adjustment.allCases.filter { $0 != .crop }
    }

    @State private var settings = DemoAppSettings.default

    private func persistSettingsModel() {
        guard let selectedImageUUIDString else { return }
        do {
            try AppDataStore.saveSettings(settings, uuid: selectedImageUUIDString)
        } catch {
            print("Failed to persist settings: \(error)")
        }
    }

    private func clearImage() {
        withAnimation {
            deleteImage()
            displayedImage = nil
            selectedImageUUIDString = nil
            settings = .default
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Group {
                    if let uiImage = displayedImage,
                       let rendered = uiImage.applying(losslessEdits, outputSize: uiImage.size) {
                        Image(platformImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.secondary, lineWidth: 1)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                let image = Image(platformImage: rendered)
                                ShareLink(item: image, preview: SharePreview("Edited Photo", image: image)) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .labelStyle(.iconOnly)
                                        .padding(10)
                                        .background(.thinMaterial, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                            }
                            .padding(.horizontal)
                    } else {
                        ContentUnavailableView(
                            "No Image Selected",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Pick a photo from your library to begin.")
                        )
                        .padding(.horizontal)
                    }
                }

                HStack {
                    Menu {
                        Menu {
                            Button {
                                isShowingPhotoLibrary = true
                            } label: {
                                Label("Photo Library", systemImage: "photo")
                            }

                            if canPasteImage {
                                Button {
                                    pasteImage()
                                } label: {
                                    Label("Paste", systemImage: "doc.on.clipboard")
                                }
                            }

                            Button {
                                isShowingFileImporter = true
                            } label: {
                                Label("File", systemImage: "folder")
                            }

#if canImport(UIKit)
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    isShowingCamera = true
                                } label: {
                                    Label("Camera", systemImage: "camera")
                                }
                            }
#endif
                        } label: {
                            Label("Set Photo", systemImage: "photo.badge.plus")
                        }

                        if displayedImage != nil {
                            Button(role: .destructive) {
                                clearImage()
                            } label: {
                                Label("Clear", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label("Photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        isShowingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(displayedImage == nil)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Photo Picker")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingEditorOptions = true
                    } label: {
                        Label("Demo Configuration", systemImage: "gearshape")
                    }
                    .popover(
                        isPresented: $isShowingEditorOptions,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .top
                    ) {
                        EditorOptionsPanel(
                            selectedPanel: $selectedPanel,
                            settings: $settings,
                            configurableAdjustments: configurableAdjustments,
                            persistSettings: persistSettingsModel
                        )
                        .padding(.vertical)
                        .frame(width: 420)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .task {
                loadImage()
                refreshPasteAvailability()
            }
            .fullScreenCover(isPresented: $isShowingEditor) {
                if let uiImage = displayedImage {
                    let config = PhotoEditConfiguration(
                        croppingEffects: settings.croppingEffects,
                        allowedAdjustments: settings.enabledAdjustments
                    )
                    HiveCompose.PhotoEditor(
                        $losslessEdits,
                        image: uiImage,
                        configuration: config
                    )
                }
            }
            .photosPicker(
                isPresented: $isShowingPhotoLibrary,
                selection: $photoItem,
                matching: .images,
                preferredItemEncoding: .automatic
            )
            .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.image]) { result in
                importImageFile(result)
            }
#if canImport(UIKit)
            .sheet(isPresented: $isShowingCamera) {
                CameraImagePicker { image in
                    importImage(image)
                }
            }
#endif
        }
        .task(id: photoItem) {
            guard let item = photoItem else { return }
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    try importImageData(data)
                }
            } catch {
                print("Failed to load/persist image: \(error)")
            }
        }
        .onChange(of: losslessEdits) { _, _ in
            persistLosslessEdits()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshPasteAvailability()
            }
        }
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            refreshPasteAvailability()
        }
#endif
    }
}

// MARK: - Import Helpers
private extension ContentView {
    func importImageData(_ data: Data) throws {
        guard let image = UIImage(data: data) else { return }

        selectedImageUUIDString = UUID().uuidString
        try saveImage(data)
        displayedImage = image
        losslessEdits = LosslessEdits(crop: nil, rotation: .zero)
        settings = .default
        persistSettingsModel()
        persistLosslessEdits()
    }

    func importImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.95) ?? image.pngData() else { return }

        do {
            try importImageData(data)
        } catch {
            print("Failed to import image: \(error)")
        }
    }

    func importImageFile(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            try importImageData(Data(contentsOf: url))
        } catch {
            print("Failed to import image file: \(error)")
        }
    }

    func pasteImage() {
#if canImport(UIKit)
        if let image = UIPasteboard.general.image {
            importImage(image)
        }
        refreshPasteAvailability()
#endif
    }

    func refreshPasteAvailability() {
#if canImport(UIKit)
        canPasteImage = UIPasteboard.general.hasImages
#else
        canPasteImage = false
#endif
    }
}

// MARK: - Persistence Helpers
private extension ContentView {
    func saveImage(_ data: Data) throws {
        guard let selectedImageUUIDString else { return }
        try AppDataStore.saveImageData(data, uuid: selectedImageUUIDString)
    }

    func loadImage() {
        guard let selectedImageUUIDString else {
            clearImage()
            return
        }

        if let data = AppDataStore.loadImageData(uuid: selectedImageUUIDString),
           let image = UIImage(data: data) {
            displayedImage = image
        } else {
            clearImage()
            return
        }

        if let decodedEdits = AppDataStore.loadLosslessEdits(uuid: selectedImageUUIDString) {
            losslessEdits = decodedEdits
        }

        settings = AppDataStore.loadSettings(uuid: selectedImageUUIDString) ?? .default
    }

    func deleteImage() {
        if let selectedImageUUIDString {
            AppDataStore.deleteAllData(uuid: selectedImageUUIDString)
        }
    }

    private func persistLosslessEdits() {
        guard let selectedImageUUIDString else { return }
        do {
            try AppDataStore.saveLosslessEdits(losslessEdits, uuid: selectedImageUUIDString)
        } catch {
            print("Failed to persist lossless edits: \(error)")
        }
    }
}

#if canImport(UIKit)
private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#endif

#Preview {
    ContentView()
}
