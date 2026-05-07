import ComposableArchitecture
import Network

struct NetworkStatusClient: Sendable {
    var observe: @Sendable () -> AsyncStream<Bool>
}

extension NetworkStatusClient: DependencyKey {
    static var liveValue: NetworkStatusClient {
        NetworkStatusClient {
            AsyncStream { continuation in
                let monitor = NWPathMonitor()
                let queue = DispatchQueue(label: "filterz.network-status")

                monitor.pathUpdateHandler = { path in
                    continuation.yield(path.status == .satisfied)
                }
                continuation.onTermination = { _ in
                    monitor.cancel()
                }
                monitor.start(queue: queue)
            }
        }
    }

    static var testValue: NetworkStatusClient {
        NetworkStatusClient {
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    }
}

extension DependencyValues {
    var networkStatusClient: NetworkStatusClient {
        get { self[NetworkStatusClient.self] }
        set { self[NetworkStatusClient.self] = newValue }
    }
}
