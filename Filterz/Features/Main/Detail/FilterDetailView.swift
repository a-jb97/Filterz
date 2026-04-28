import SwiftUI
import ComposableArchitecture

struct FilterDetailView: View {
    @Bindable var store: StoreOf<FilterDetailFeature>

    var body: some View {
        VStack(spacing: 0) {
            detailNavBar

            ZStack {
                Color.filterzBlackBase.ignoresSafeArea()

                if store.isLoading {
                    ProgressView()
                        .tint(.filterzGray45)
                } else if let detail = store.detail {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            previewSection(detail: detail)
                            priceSection(detail: detail)
                            statsSection(detail: detail)
                            EXIFSection(exif: detail.exif)
                                .padding(.horizontal, 16)
                            FilterPresetsSection(presets: detail.presets, isUnlocked: detail.isDownloaded)
                                .padding(.horizontal, 16)
                            purchaseButton(detail: detail)
                                .padding(.horizontal, 16)
                            CreatorSection(
                                creator: detail.creator,
                                onDMTapped: { store.send(.dmCreatorTapped) }
                            )
                            .padding(.horizontal, 16)
                            hashtagsSection(detail: detail)
                            descriptionSection(detail: detail)
                        }
                        .padding(.bottom, 40)
                        .padding(.top, 8)
                    }
                } else if let error = store.errorMessage {
                    Text(error)
                        .font(.pretendard(14, weight: .regular))
                        .foregroundColor(.filterzGray60)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.filterzBlackBase.ignoresSafeArea())
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Navigation Bar

    private var detailNavBar: some View {
        HStack {
            Button { store.send(.backTapped) } label: {
                Image(systemName: "chevron.left")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 18)
                    .foregroundColor(.filterzGray60)
                    .padding(8)
            }
            .frame(width: 48, height: 48)

            Spacer()

            Text(store.detail?.title ?? "")
                .font(.filterzDisplay(18))
                .foregroundColor(.filterzGray30)
                .lineLimit(1)

            Spacer()

            Button { store.send(.likeTapped) } label: {
                Image(systemName: store.detail?.isLiked == true ? "heart.fill" : "heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 20)
                    .foregroundColor(store.detail?.isLiked == true ? .red : .filterzGray60)
                    .scaleEffect(store.detail?.isLiked == true ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: store.detail?.isLiked)
                    .padding(8)
            }
            .frame(width: 48, height: 48)
        }
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }

    // MARK: - Sections

    private func previewSection(detail: FilterDetail) -> some View {
        VStack(spacing: 12) {
            FilterPreviewView(
                afterImageURL: detail.imageURLs.first,
                beforeImageURL: detail.imageURLs.dropFirst().first,
                sliderOffset: store.previewSliderOffset,
                onSliderChanged: { store.send(.previewSliderChanged($0)) }
            )
            .padding(.horizontal, 16)

            AfterBeforeLabelRow(sliderOffset: store.previewSliderOffset)
        }
    }

    private func priceSection(detail: FilterDetail) -> some View {
        Text(detail.formattedPrice)
            .font(.filterzDisplay(32))
            .foregroundColor(.filterzGray30)
            .padding(.horizontal, 16)
    }

    private func statsSection(detail: FilterDetail) -> some View {
        HStack(spacing: 12) {
            statCard(title: "다운로드", value: "\(detail.buyerCount)+")
            statCard(title: "찜하기", value: "\(detail.likeCount)")
        }
        .padding(.horizontal, 16)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.pretendard(12, weight: .medium))
                .foregroundColor(.filterzGray75)
            Text(value)
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.filterzBlackTurquoise)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.filterzTranslucent, lineWidth: 1)
                )
        )
    }

    private func purchaseButton(detail: FilterDetail) -> some View {
        Button {
            if !detail.isDownloaded {
                store.send(.purchaseTapped)
            }
        } label: {
            Text(detail.isDownloaded ? "구매완료" : "결제하기")
        }
        .buttonStyle(CapsulePrimaryButtonStyle(
            isLoading: store.isPurchaseLoading,
            isDisabled: detail.isDownloaded
        ))
        .disabled(detail.isDownloaded || store.isPurchaseLoading)
    }

    private func hashtagsSection(detail: FilterDetail) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(detail.hashtags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.pretendard(13, weight: .medium))
                        .foregroundColor(.filterzGray60)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.filterzBlackTurquoise)
                        )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func descriptionSection(detail: FilterDetail) -> some View {
        Text(detail.description)
            .font(.pretendard(14, weight: .regular))
            .foregroundColor(.filterzGray60)
            .lineSpacing(8)
            .padding(.horizontal, 16)
    }
}
