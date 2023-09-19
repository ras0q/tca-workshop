import ComposableArchitecture
import Entity
import Foundation
import SwiftUI

public struct RepositoryRow: Reducer {
  public struct State: Equatable, Identifiable {
    public var id: Int { repository.id }

    let repository: Repository

    public init(repository: Repository) {
      self.repository = repository
    }
  }

  public enum Action: Equatable {
    case rowTapped
    case delegate(Delegate)
    
    public enum Delegate: Equatable {
      case openRepositoryDetail(Repository)
    }
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .rowTapped:
        return .send(.delegate(.openRepositoryDetail(state.repository)))
      case .delegate:
        return .none
      }
    }
  }
}

struct RepositoryRowView: View {
  let store: StoreOf<RepositoryRow>

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Button {
        viewStore.send(.rowTapped)
      } label: {
        VStack(alignment: .leading, spacing: 8) {
          Text(viewStore.repository.fullName)
            .font(.title2.bold())
          Text(viewStore.repository.description ?? "")
            .font(.body)
            .lineLimit(2)
          HStack(alignment: .center, spacing: 32) {
            Label(
              title: {
                Text("\(viewStore.repository.stargazersCount)")
                  .font(.callout)
              },
              icon: {
                Image(systemName: "star.fill")
                  .foregroundStyle(.yellow)
              }
            )
            Label(
              title: {
                Text(viewStore.repository.language ?? "")
                  .font(.callout)
              },
              icon: {
                Image(systemName: "text.word.spacing")
                  .foregroundStyle(.gray)
              }
            )
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
    }
  }
}

#Preview {
  RepositoryRowView(
    store: .init(
      initialState: RepositoryRow.State(
        repository: .mock(id: 1)
      )
    ) {
      RepositoryRow()
    }
  )
  .padding()
}