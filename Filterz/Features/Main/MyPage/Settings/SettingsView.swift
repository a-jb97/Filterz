import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    private let imageQualityOptions = ImageQualityOption.allCases
    private let sectionCornerRadius: CGFloat = 5

    var body: some View {
        List {
            Section {
                ForEach(Array(imageQualityOptions.enumerated()), id: \.element.rawValue) { index, option in
                    Button {
                        store.send(.qualitySelected(option))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.displayName)
                                    .font(.pretendard(15, weight: .regular))
                                    .foregroundColor(.filterzGray30)
                                Text(option.qualityDescription)
                                    .font(.pretendard(12, weight: .regular))
                                    .foregroundColor(.filterzGray30)
                            }
                            Spacer()
                            if store.selectedQuality == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.filterzAccent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(sectionBackground(row: index, rowCount: imageQualityOptions.count))
                }
            } header: {
                Text("이미지 전송 화질")
                    .font(.pretendard(12, weight: .semibold))
                    .foregroundColor(.filterzGray30)
                    .textCase(nil)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI 요약")
                            .font(.pretendard(15, weight: .regular))
                            .foregroundColor(.filterzGray30)
                        Text("읽지 않은 채팅을 요약")
                            .font(.pretendard(12, weight: .regular))
                            .foregroundColor(.filterzGray30)
                    }

                    Spacer()

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { store.isAISummaryEnabled },
                            set: { store.send(.aiSummaryEnabledChanged($0)) }
                        )
                    )
                    .labelsHidden()
                    .tint(.filterzAccent)
                }
                .listRowBackground(sectionBackground(row: 0, rowCount: 1))
            } header: {
                Text("채팅")
                    .font(.pretendard(12, weight: .semibold))
                    .foregroundColor(.filterzGray30)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.filterzBackground.ignoresSafeArea())
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
    }

    private func sectionBackground(row: Int, rowCount: Int) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: row == 0 ? sectionCornerRadius : 0,
            bottomLeadingRadius: row == rowCount - 1 ? sectionCornerRadius : 0,
            bottomTrailingRadius: row == rowCount - 1 ? sectionCornerRadius : 0,
            topTrailingRadius: row == 0 ? sectionCornerRadius : 0,
            style: .continuous
        )
        .fill(Color.filterzBackground)
    }
}
