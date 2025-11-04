import Foundation
import Combine

class AppState: ObservableObject {
    @Published var showTutorial: Bool

    private let hasLaunchedBeforeKey = "hasLaunchedBefore"

    init() {
        // TODO: For testing - always show tutorial
        // Remove this line and uncomment the code below for production
        self.showTutorial = true

        // Production code:
        // let hasLaunchedBefore = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        // self.showTutorial = !hasLaunchedBefore
        //
        // if !hasLaunchedBefore {
        //     UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
        // }
    }
}
