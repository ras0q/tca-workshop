import ComposableArchitecture
import Entity

public struct RepositoryRow: Reducer {
    public struct State: Equatable, Identifiable {
        public var id: Int { repository.id }
        let repository: Repository
    }

    public enum Action: Equatable {
        case rowTapped
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .rowTapped:
                return .none
            }
        }
    }
}
