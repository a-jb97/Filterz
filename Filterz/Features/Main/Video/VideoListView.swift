import SwiftUI
import ComposableArchitecture

struct VideoListView: View {
    @Bindable var store: StoreOf<VideoListFeature>

    var body: some View {
        ZStack {
            Color.filterzBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                if store.isLoading && store.items.isEmpty {
                    Spacer()
                    ProgressView().tint(.filterzGray30)
                    Spacer()
                } else if store.items.isEmpty {
                    Spacer()
                    Text("등록된 비디오가 없습니다")
                        .font(.pretendard(14, weight: .regular))
                        .foregroundColor(.filterzGray30)
                    Spacer()
                } else {
                    listContent
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .filterzSwipeBack {
            store.send(.backTapped)
        }
        .onAppear { store.send(.onAppear) }
        .alert(
            "오류",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            )
        ) {
            Button("확인") { store.send(.errorDismissed) }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var navBar: some View {
        HStack {
            Button {
                store.send(.backTapped)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.filterzGray30)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("비디오")
                .font(.filterzDisplay(24))
                .foregroundColor(.filterzGray30)

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(Color.filterzBackground)
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(store.items) { item in
                    VideoListRowView(
                        item: item,
                        isLoadingStream: store.loadingStreamVideoId == item.id,
                        onTapped: { store.send(.videoTapped(id: item.id)) },
                        onLikeTapped: { store.send(.likeButtonTapped(id: item.id)) }
                    )

                    Divider()
                        .background(Color.filterzTranslucent)
                        .padding(.leading, 132)
                }

                if store.hasMore {
                    ProgressView()
                        .tint(.filterzGray30)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .onAppear { store.send(.loadMore) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}
