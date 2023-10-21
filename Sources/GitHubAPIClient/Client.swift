import Dependencies
import Entity
import Foundation
import XCTestDynamicOverlay

public struct GitHubAPIClient {
  public var searchRepositories: @Sendable (_ query: String) async throws -> [Repository]
}

extension GitHubAPIClient: DependencyKey {
    public static let liveValue = Self { query in
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
}

private let jsonDecoder: JSONDecoder = {
  let decoder = JSONDecoder()
  decoder.keyDecodingStrategy = .convertFromSnakeCase
  return decoder
}()

extension GitHubAPIClient: TestDependencyKey {
    public static let previewValue = Self { _ in [] }

    public static let testValue = Self { query in
        unimplemented("\(Self.self).searchRepositories")
    }
}

extension DependencyValues {
  public var gitHubAPIClient: GitHubAPIClient {
    get { self[GitHubAPIClient.self] }
    set { self[GitHubAPIClient.self] = newValue }
  }
}
