import ComposableArchitecture
import SwiftUI

struct FilterManagementView: View {
    @Bindable var store: StoreOf<FilterManagementFeature>

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
        }
        .background(Color.filterzBlackBase.ignoresSafeArea())
        .onAppear { store.send(.onAppear) }
        .refreshable { store.send(.refresh) }
        .alert("오류", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.send(.errorDismissed) } }
        )) {
            Button("확인") { store.send(.errorDismissed) }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.isCameraPresented },
            set: { if !$0 { store.send(.cameraDismissed) } }
        )) {
            FilterCameraView(
                filters: store.items,
                onDismiss: {
                    store.send(.cameraDismissed)
                }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("필터 관리")
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)

            Spacer()

            Button {
                store.send(.uploadButtonTapped)
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.filterzAccent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                store.send(.cameraButtonTapped)
            } label: {
                Image(systemName: "camera")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.filterzAccent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.filterzBlackBase)
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.items.isEmpty {
            ProgressView()
                .tint(.filterzGray45)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else if store.items.isEmpty {
            Text("구매한 필터가 없습니다")
                .font(.pretendard(14, weight: .regular))
                .foregroundColor(.filterzGray75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else {
            FeedListView(
                items: store.feedItems,
                tagStyle: .compactProfile,
                onItemTapped: { store.send(.filterTapped(id: $0)) },
                onAuthorTapped: { _ in }
            )
        }
    }
}
