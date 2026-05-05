import ComposableArchitecture
import Foundation
import UIKit

struct MyProfile: Equatable, Sendable {
    let userId: String
    let email: String
    var nick: String
    var name: String?
    var introduction: String?
    var profileImagePath: String?
    var phoneNum: String?
    var hashTags: [String]

    init(dto: MyInfoResponseDTO) {
        userId = dto.userID
        email = dto.email
        nick = dto.nick
        name = dto.name
        introduction = dto.introduction
        profileImagePath = dto.profileImage
        phoneNum = dto.phoneNum
        hashTags = dto.hashTags
    }
}

@Reducer
struct MyPageFeature {
    @ObservableState
    struct State: Equatable {
        var profile: MyProfile? = nil
        var filters: [FeedItem] = []
        var selectedCategory: FilterCategory? = nil
        var nextCursor: String? = nil
        var isLoading: Bool = false
        var isFiltersLoading: Bool = false
        var hasMoreFilters: Bool = true
        var isSaving: Bool = false
        var isLoggingOut: Bool = false
        var isLogoutConfirmationPresented: Bool = false
        var isEditPresented: Bool = false
        var editNick: String = ""
        var editIntroduction: String = ""
        var editHashTagsText: String = ""
        var editImageData: Data? = nil
        var errorMessage: String? = nil
    }

    enum Action: Sendable {
        case onAppear
        case profileResponse(Result<MyInfoResponseDTO, any Error>)
        case filterCategorySelected(FilterCategory?)
        case loadMoreFilters
        case filtersResponse(Result<FilterSummaryPaginationListResponseDTO, any Error>, append: Bool)
        case filterTapped(id: String)
        case likedFiltersButtonTapped
        case editButtonTapped
        case editPresentationChanged(Bool)
        case editNickChanged(String)
        case editIntroductionChanged(String)
        case editHashTagsTextChanged(String)
        case editImageSelected(Data?)
        case saveTapped
        case editResponse(Result<MyInfoResponseDTO, any Error>)
        case logoutTapped
        case logoutConfirmationChanged(Bool)
        case logoutConfirmed
        case logoutResponse(Result<Void, any Error>)
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Sendable {
            case filterTapped(id: String)
            case likedFiltersRequested
            case logoutCompleted
        }
    }

    @Dependency(\.userClient) var userClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.filterClient) var filterClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let profileEffect = fetchProfile(&state)
                let filtersEffect = state.profile != nil && state.filters.isEmpty
                    ? fetchFilters(&state, append: false)
                    : Effect<Action>.none
                return .merge(profileEffect, filtersEffect)

            case .profileResponse(.success(let dto)):
                state.isLoading = false
                state.profile = MyProfile(dto: dto)
                return state.filters.isEmpty ? fetchFilters(&state, append: false) : .none

            case .profileResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = displayMessage(for: error)
                return .none

            case .filterCategorySelected(let category):
                guard state.selectedCategory != category else { return .none }
                state.selectedCategory = category
                return fetchFilters(&state, append: false)

            case .loadMoreFilters:
                return fetchFilters(&state, append: true)

            case .filtersResponse(.success(let dto), let append):
                state.isFiltersLoading = false
                let items = dto.data.map { FeedItem(dto: $0) }
                state.filters = append ? state.filters + items : items
                state.nextCursor = dto.nextCursor
                state.hasMoreFilters = dto.nextCursor != nil && dto.nextCursor != "0"
                return .none

            case .filtersResponse(.failure(let error), _):
                state.isFiltersLoading = false
                state.errorMessage = displayMessage(for: error)
                return .none

            case .filterTapped(let id):
                return .send(.delegate(.filterTapped(id: id)))

            case .likedFiltersButtonTapped:
                return .send(.delegate(.likedFiltersRequested))

            case .editButtonTapped:
                guard let profile = state.profile else { return .none }
                state.editNick = profile.nick
                state.editIntroduction = profile.introduction ?? ""
                state.editHashTagsText = profile.hashTags.joined(separator: " ")
                state.editImageData = nil
                state.isEditPresented = true
                return .none

            case .editPresentationChanged(let isPresented):
                state.isEditPresented = isPresented
                if !isPresented {
                    state.editImageData = nil
                }
                return .none

            case .editNickChanged(let nick):
                state.editNick = nick
                return .none

            case .editIntroductionChanged(let introduction):
                state.editIntroduction = introduction
                return .none

            case .editHashTagsTextChanged(let text):
                state.editHashTagsText = text
                return .none

            case .editImageSelected(let data):
                state.editImageData = data
                return .none

            case .saveTapped:
                guard let profile = state.profile, !state.isSaving else { return .none }
                let nick = state.editNick.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !nick.isEmpty else {
                    state.errorMessage = "닉네임을 입력해주세요."
                    return .none
                }

                let introduction = nilIfEmpty(state.editIntroduction)
                let hashTags = parseHashTags(state.editHashTagsText)
                let imageData = state.editImageData
                let queryBase = EditMyProfileRequestDTO(
                    nick: nick,
                    name: profile.name,
                    introduction: introduction,
                    phoneNum: profile.phoneNum,
                    profileImage: profile.profileImagePath,
                    hashTags: hashTags
                )
                state.isSaving = true
                state.errorMessage = nil

                return .run { send in
                    var query = queryBase
                    if let imageData {
                        let uploadData = makeProfileUploadData(from: imageData)
                        let profileImagePath = try await userClient.uploadProfileImage(uploadData)
                        query = EditMyProfileRequestDTO(
                            nick: queryBase.nick,
                            name: queryBase.name,
                            introduction: queryBase.introduction,
                            phoneNum: queryBase.phoneNum,
                            profileImage: profileImagePath ?? queryBase.profileImage,
                            hashTags: queryBase.hashTags
                        )
                    }
                    let dto = try await userClient.editMyProfile(query)
                    await send(.editResponse(.success(dto)))
                } catch: { error, send in
                    await send(.editResponse(.failure(error)))
                }

            case .editResponse(.success(let dto)):
                state.isSaving = false
                state.isEditPresented = false
                state.editImageData = nil
                state.profile = MyProfile(dto: dto)
                return .none

            case .editResponse(.failure(let error)):
                state.isSaving = false
                state.errorMessage = displayMessage(for: error)
                return .none

            case .logoutTapped:
                state.isLogoutConfirmationPresented = true
                return .none

            case .logoutConfirmationChanged(let isPresented):
                state.isLogoutConfirmationPresented = isPresented
                return .none

            case .logoutConfirmed:
                guard !state.isLoggingOut else { return .none }
                state.isLogoutConfirmationPresented = false
                state.isLoggingOut = true
                state.errorMessage = nil
                return .run { send in
                    await send(.logoutResponse(Result { try await authClient.logout() }))
                }

            case .logoutResponse(.success):
                state.isLoggingOut = false
                return .send(.delegate(.logoutCompleted))

            case .logoutResponse(.failure(let error)):
                state.isLoggingOut = false
                state.errorMessage = displayMessage(for: error)
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func fetchProfile(_ state: inout State) -> Effect<Action> {
        guard state.profile == nil, !state.isLoading else { return .none }
        state.isLoading = true
        state.errorMessage = nil
        return .run { send in
            await send(.profileResponse(Result { try await userClient.myInfo() }))
        }
    }

    private func fetchFilters(_ state: inout State, append: Bool) -> Effect<Action> {
        guard let userId = state.profile?.userId else { return .none }
        guard !state.isFiltersLoading else { return .none }
        guard !append || state.hasMoreFilters else { return .none }
        state.isFiltersLoading = true
        if !append {
            state.filters = []
            state.nextCursor = nil
            state.hasMoreFilters = true
        }
        state.errorMessage = nil
        let query = UserFilterListRequestDTO(
            next: append ? state.nextCursor : nil,
            limit: 10,
            category: state.selectedCategory?.categoryString
        )
        return .run { [filterClient] send in
            await send(.filtersResponse(
                Result { try await filterClient.getUserFilters(userId, query) },
                append: append
            ))
        }
    }
}

nonisolated private func parseHashTags(_ text: String) -> [String] {
    text
        .components(separatedBy: CharacterSet(charactersIn: ", \n\t"))
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# ")) }
        .filter { !$0.isEmpty }
}

nonisolated private func nilIfEmpty(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

nonisolated private func displayMessage(for error: any Error) -> String {
    (error as? NetworkError)?.errorDescription ?? error.localizedDescription
}

nonisolated private func makeProfileUploadData(from data: Data) -> Data {
    guard let image = UIImage(data: data),
          let jpeg = image.jpegData(compressionQuality: 0.82)
    else {
        return data
    }
    return jpeg
}
