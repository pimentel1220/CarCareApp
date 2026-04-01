import Foundation
import Combine

final class AppFeedbackCenter: ObservableObject {
    static let shared = AppFeedbackCenter()

    @Published var message: String?

    private init() {}

    func show(_ text: String) {
        message = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard self?.message == text else { return }
            self?.message = nil
        }
    }
}
