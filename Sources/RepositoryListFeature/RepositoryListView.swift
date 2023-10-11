import CasePaths
import ComposableArchitecture
import Dependencies
import Entity
import GitHubAPIClient
import IdentifiedCollections
import RepositoryDetailFeature
import SwiftUI
import SwiftUINavigationCore

public struct RepositoryList: Reducer {
  public struct State: Equatable {
    var repositoryRows: IdentifiedArrayOf<RepositoryRow.State> = []
    var isLoading: Bool = false
    @BindingState var query: String = ""
    @PresentationState var destination: Destination.State?
    var path = StackState<Path.State>()

    public init() {}
  }

  public enum Action: Equatable, BindableAction {
    case onAppear
    case queryChangeDebounced
    case searchRepositoriesResponse(TaskResult<[Repository]>)
    case repositoryRows(id: RepositoryRow.State.ID, action: RepositoryRow.Action)
    case binding(BindingAction<State>)
    case destination(PresentationAction<Destination.Action>)
    case path(StackAction<Path.State, Path.Action>)

    public enum Alert: Equatable {}
  }

  @Dependency(\.gitHubAPIClient) var gitHubAPIClient
  @Dependency(\.mainQueue) var mainQueue
  
  public init() {}

  private enum CancelID {
    case response
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      switch action {
      case .onAppear:
        state.isLoading = true

        return .run { send in
          await send(
            .searchRepositoriesResponse(
              TaskResult {
                try await gitHubAPIClient.searchRepositories("composable")
              }
            )
          )
        }
      case let .searchRepositoriesResponse(result):
        state.isLoading = false

        switch result {
        case let .success(repositories):
          state.repositoryRows = .init(
            uniqueElements: repositories.map {
              .init(repository: $0)
            }
          )
          return .none
        case .failure:
          state.destination = .alert(.networkError)
          return .none
        }
      case let .repositoryRows(id, .delegate(.rowTapped)):
        guard let repository = state.repositoryRows[id: id]?.repository
        else { return .none }

        state.path.append(
          .repositoryDetail(
            .init(repository: repository)
          )
        )
        return .none
      case .repositoryRows:
        return .none
      case .binding(\.$query):
        return .run { send in
          await send(.queryChangeDebounced)
        }
        .debounce(
          id: CancelID.response,
          for: .seconds(0.3),
          scheduler: mainQueue
        )
      case .queryChangeDebounced:
        guard !state.query.isEmpty else {
          return .none
        }

        state.isLoading = true

        return .run { [query = state.query] send in
          await send(
            .searchRepositoriesResponse(
              TaskResult {
                try await gitHubAPIClient.searchRepositories(query)
              }
            )
          )
        }
      case .binding, .destination, .path:
        return .none
      }
    }
    .forEach(\.repositoryRows, action: /Action.repositoryRows(id:action:)) {
      RepositoryRow()
    }
    .forEach(\.path, action: /Action.path) {
      Path()
    }
    .ifLet(\.$destination, action: /Action.destination) {
      Destination()
    }
  }
}

extension RepositoryList {
  public struct Destination: Reducer {
    public enum State: Equatable {
      case alert(AlertState<Action.Alert>)
    }

    public enum Action: Equatable {
      case alert(Alert)
      
      public enum Alert: Equatable {}
    }
    
    public var body: some ReducerOf<Self> {
      EmptyReducer()
    }
  }

  public struct Path: Reducer {
    public enum State: Equatable {
      case repositoryDetail(RepositoryDetail.State)
    }

    public enum Action: Equatable {
      case repositoryDetail(RepositoryDetail.Action)
    }

    public var body: some ReducerOf<Self> {
      Scope(state: /State.repositoryDetail, action: /Action.repositoryDetail) {
        RepositoryDetail()
      }
    }
  }
}

extension AlertState where Action == RepositoryList.Destination.Action.Alert {
  static let networkError = Self {
    TextState("Network Error")
  } message: {
    TextState("Failed to fetch data.")
  }
}

public struct RepositoryListView: View {
  let store: StoreOf<RepositoryList>

  public init(store: StoreOf<RepositoryList>) {
    self.store = store
  }

  public var body: some View {
    NavigationStackStore(
      store.scope(
        state: \.path,
        action: { .path($0) }
      )
    ) {
      WithViewStore(store, observe: { $0 }) { viewStore in
        Group {
          if viewStore.isLoading {
            ProgressView()
          } else {
            List {
              ForEachStore(
                store.scope(
                  state: \.repositoryRows,
                  action: { .repositoryRows(id: $0, action: $1) }
                ),
                content: RepositoryRowView.init(store:)
              )
            }
          }
        }
        .onAppear {
          store.send(.onAppear)
        }
        .navigationTitle("Search Repositories")
        .alert(
          store: store.scope(
            state: \.$destination,
            action: { .destination($0) }
          ),
          state: /RepositoryList.Destination.State.alert,
          action: RepositoryList.Destination.Action.alert
        )
        .searchable(
          text: viewStore.$query,
          placement: .navigationBarDrawer,
          prompt: "Input query"
        )
      }
    } destination: { state in
      switch state {
      case .repositoryDetail:
        CaseLet(
          /RepositoryList.Path.State.repositoryDetail,
           action: RepositoryList.Path.Action.repositoryDetail,
           then: RepositoryDetailView.init(store:)
        )
      }
    }
  }
}

#Preview("API Succeeded") {
  RepositoryListView(
    store: .init(
      initialState: RepositoryList.State()
    ) {
      RepositoryList()
    } withDependencies: {
      $0.gitHubAPIClient.searchRepositories = { _ in
        (1...20).map { .mock(id: $0) }
      }
    }
  )
}

#Preview("API Failed") {
  enum PreviewError: Error {
    case fetchFailed
  }
  return RepositoryListView(
    store: .init(
      initialState: RepositoryList.State()
    ) {
      RepositoryList()
    } withDependencies: {
      $0.gitHubAPIClient.searchRepositories = { _ in
        throw PreviewError.fetchFailed
      }
    }
  )
}
