import CasePaths
import ComposableArchitecture
import Dependencies
import Entity
import Foundation
import IdentifiedCollections
import SwiftUI
import SwiftUINavigationCore

public struct RepositoryList: Reducer {
  public struct State: Equatable {
    var repositoryRows: IdentifiedArrayOf<RepositoryRow.State> = []
    var isLoading: Bool = false
    @BindingState var query: String = ""
    @PresentationState var destination: Destination.State?

    public init() {}
  }

  public enum Action: Equatable, BindableAction {
    case onAppear
    case searchRepositoriesResponse(TaskResult<[Repository]>)
    case repositoryRow(id: RepositoryRow.State.ID, action: RepositoryRow.Action)
    case queryChangeDebounced
    case binding(BindingAction<State>)
    case destination(PresentationAction<Destination.Action>)
  }

  public init() {}

  private enum CancelID {
    case response
  }

  @Dependency(\.gitHubAPIClient) var gitHubAPIClient
  @Dependency(\.mainQueue) var mainQueue

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .onAppear:
        state.isLoading = true
        return searchRepositories(by: "composable")
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
          state.destination = .alert(.networkError)
          return .none
        }
      case .repositoryRow:
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

        return searchRepositories(by: state.query)
      case .binding:
        return .none
      case .destination:
        return .none
      }
    }
    .forEach(\.repositoryRows, action: /Action.repositoryRow(id:action:)) {
      RepositoryRow()
    }
  }

  func searchRepositories(by query: String) -> Effect<Action> {
    .run { send in
      await send(
        .searchRepositoriesResponse(
          TaskResult {
            try await gitHubAPIClient.searchRepositories(query)
          }
        )
      )
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

extension RepositoryList {
  public struct Destination: Reducer {
    public enum State: Equatable {
      case alert(AlertState<Action.Alert>)
      case repositoryDetail(RepositoryDetail.State)
    }
    
    public enum Action: Equatable {
      case alert(Alert)
      case repositoryDetail(RepositoryDetail.Action)
      
      public enum Alert: Equatable {}
    }

    public var body: some ReducerOf<Self> {
      Scope(state: /State.repositoryDetail, action: /Action.repositoryDetail) {
        RepositoryDetail()
      }
    }
  }
}
