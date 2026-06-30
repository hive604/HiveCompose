//
//  PhotoEditorPresentation.swift
//  HiveCompose
//
//  Created by Steven Fisher on 2026-06-30.
//

import SwiftUI

public extension View {
    @ViewBuilder
    func losslessPhotoEditor<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
#if canImport(UIKit)
        fullScreenCover(isPresented: isPresented) {
            content()
                .statusBarHidden(true)
        }
#else
        sheet(isPresented: isPresented) {
            content()
                .frame(minHeight: 560)
        }
#endif
    }
}
