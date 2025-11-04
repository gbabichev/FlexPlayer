import Foundation
import Combine

class AppState: ObservableObject {
    @Published var showTutorial: Bool

    private let hasLaunchedBeforeKey = "hasLaunchedBefore"

    init() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        self.showTutorial = !hasLaunchedBefore

        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
        }
    }
}
