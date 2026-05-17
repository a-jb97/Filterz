// FilterMakerView.swift

import ComposableArchitecture
import SwiftUI
import UIKit

struct FilterMakerView: View {
    @Bindable var store: StoreOf<FilterMakerFeature>
    @State private var previewSource: FilterImageRenderer.PreviewSource?
    @State private var displayImage: UIImage?
    @State private var renderTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.filterzBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    navigationHeader
                    previewArea
                        .frame(maxWidth: .infinity)
                        .frame(height: max(320, proxy.size.height - 246))
                    controlsArea
                }
            }
        }
        .onAppear { store.send(.onAppear) }
        .filterzSwipeBack {
            store.send(.backTapped)
        }
        .task { preparePreviewSource() }
        .onDisappear { renderTask?.cancel() }
        .onChange(of: store.sourceImageData) { _, _ in preparePreviewSource() }
        .onChange(of: store.values) { _, _ in renderCurrentImage() }
        .onChange(of: store.isShowingOriginal) { _, _ in renderCurrentImage() }
        .alert("오류", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.send(.errorDismissed) } }
        )) {
            Button("확인") { store.send(.errorDismissed) }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var navigationHeader: some View {
        HStack {
            Button { store.send(.backTapped) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.filterzGray30)
                    .frame(width: 48, height: 56)
            }

            Spacer()

            Text("필터 제작")
                .font(.filterzDisplay(24))
                .foregroundStyle(Color.filterzGray30)

            Spacer()

            Button { store.send(.saveTapped) } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(Color.filterzAccent)
                    .frame(width: 48, height: 56)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(Color.filterzBackground)
    }

    private var previewArea: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Group {
                    if let displayImage {
                        Image(uiImage: displayImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    } else {
                        Color.filterzSurface
                            .overlay(ProgressView().tint(Color.filterzGray30))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()

                previewButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            }
        }
        .clipped()
    }

    private var previewButtons: some View {
        HStack(spacing: 8) {
            overlayButton(icon: "arrow.uturn.backward") {
                store.send(.undoTapped)
            }
            .disabled(store.undoStack.isEmpty)

            overlayButton(icon: "arrow.uturn.forward") {
                store.send(.redoTapped)
            }
            .disabled(store.redoStack.isEmpty)

            Spacer()

            overlayButton(icon: "rectangle.split.2x1") {}
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in store.send(.originalPressedChanged(true)) }
                        .onEnded { _ in store.send(.originalPressedChanged(false)) }
                )
        }
    }

    private func overlayButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.filterzBackground)
                .frame(width: 40, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.filterzTranslucent)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.filterzTranslucent, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var controlsArea: some View {
        VStack(spacing: 18) {
            sliderArea
            adjustmentList
        }
        .padding(.top, 14)
        .padding(.bottom, 20)
        .background(Color.filterzBackground)
    }

    private var sliderArea: some View {
        VStack(spacing: 8) {
            Text(valueText)
                .font(.pretendard(14, weight: .bold))
                .foregroundStyle(Color.filterzBackground)
                .frame(width: 44, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.filterzAccent)
                )

            Slider(
                value: Binding(
                    get: { Double(store.values[store.selectedAdjustment]) },
                    set: { store.send(.sliderChanged(Float($0))) }
                ),
                in: Double(store.selectedAdjustment.range.lowerBound)...Double(store.selectedAdjustment.range.upperBound),
                onEditingChanged: { isEditing in
                    store.send(isEditing ? .sliderEditingStarted : .sliderEditingEnded)
                }
            )
            .tint(.filterzAccent)
            .padding(.horizontal, 20)
        }
    }

    private var adjustmentList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FilterAdjustmentKey.allCases) { key in
                    adjustmentItem(key)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 80)
    }

    private func adjustmentItem(_ key: FilterAdjustmentKey) -> some View {
        let isSelected = store.selectedAdjustment == key
        return Button {
            store.send(.adjustmentSelected(key))
        } label: {
            VStack(spacing: 8) {
                Image(systemName: key.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.filterzAccent : Color.filterzGray30.opacity(0.9))
                    .frame(width: 32, height: 32)

                Text(key.title)
                    .font(.pretendard(10, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.filterzGray30 : Color.filterzGray30)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 62)
            }
            .frame(width: 62, height: 64)
        }
        .buttonStyle(.plain)
    }

    private var valueText: String {
        let value = store.values[store.selectedAdjustment]
        if store.selectedAdjustment == .temperature {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func updateDisplayImage() {
        renderCurrentImage()
    }

    private func preparePreviewSource() {
        guard let data = store.sourceImageData else {
            previewSource = nil
            displayImage = nil
            return
        }
        renderTask?.cancel()
        renderTask = Task.detached(priority: .userInitiated) {
            let source = FilterImageRenderer.makePreviewSource(from: data)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                previewSource = source
                displayImage = source?.image
                renderCurrentImage()
            }
        }
    }

    private func renderCurrentImage() {
        guard let previewSource else { return }
        renderTask?.cancel()

        if store.isShowingOriginal {
            displayImage = previewSource.image
            return
        }

        let source = previewSource
        let values = store.values
        renderTask = Task.detached(priority: .userInitiated) {
            let image = FilterImageRenderer.previewImage(from: source, values: values)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                displayImage = image
            }
        }
    }
}
