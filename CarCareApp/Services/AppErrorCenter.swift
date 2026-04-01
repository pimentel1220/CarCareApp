import Foundation
import Combine

final class AppErrorCenter: ObservableObject {
    static let shared = AppErrorCenter()

    @Published var message: String?

    private init() {}
}
