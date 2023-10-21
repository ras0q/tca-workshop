import ComposableArchitecture
import Entity
import Foundation
import IdentifiedCollections
import SwiftUI

public struct RepositoryList: Reducer {
    public struct State: Equatable {
        var repositoryRows: IdentifiedArrayOf<RepositoryRow.State> = []
        var isLoading: Bool = false
        @BindingState var query: String = ""

        public init() {}
    }

    public enum Action: Equatable, BindableAction {
        case onAppear
        case searchRepositoriesResponse(TaskResult<[Repository]>)
        case repositoryRow(id: RepositoryRow.State.ID, action: RepositoryRow.Action)
        case binding(BindingAction<State>)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(
                        .searchRepositoriesResponse(
                            TaskResult {
                                let query = "composable"
                                let url = URL(
                                  string: "https://api.github.com/search/repositories?q=\(query)&sort=stars"
                                )!
                                var request = URLRequest(url: url)
                                if let token = Bundle.main.infoDictionary?["GitHubPersonalAccessToken"] as? String {
                                  request.setValue(
                                    "Bearer \(token)",
                                    forHTTPHeaderField: "Authorization"
                                  )
                                }
                                let (data, _) = try await URLSession.shared.data(for: request)
                                let repositories = try jsonDecoder.decode(
                                  GithubSearchResult.self,
                                  from: data
                                ).items
                                return repositories
                            }
                        )
                    )
                }
            case let .searchRepositoriesResponse(result):
                state.isLoading = false

                switch result {
                case let .success(response):
                    state.repositoryRows = .init(
                        uniqueElements: response.map {
                            .init(repository: $0)
                        }
                    )
                    return .none
                case .failure:
                    // TODO: handling error
                    return .none
                }
            case .repositoryRow:
                return .none
            case .binding:
                return .none
            }
        }
        .forEach(\.repositoryRows, action: /Action.repositoryRow(id:action:)) {
            RepositoryRow()
        }
    }

    private let jsonDecoder: JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return decoder
    }()
}

public struct RepositoryListView: View {
    let store: StoreOf<RepositoryList>

    public init(store: StoreOf<RepositoryList>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if viewStore.isLoading {
                    ProgressView()
                } else {
                    List {
                        ForEachStore(
                            store.scope(
                                state: \.repositoryRows,
                                action: { .repositoryRow(id: $0, action: $1) }
                            ),
                            content: RepositoryRowView.init(store:)
                        )
                    }
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

#Preview {
    RepositoryListView(
        store: .init(
            initialState: RepositoryList.State()
        ) {
            RepositoryList()
                ._printChanges()
        }
    )
}
