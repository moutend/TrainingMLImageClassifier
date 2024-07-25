import SwiftUI

@main
struct TrainingMLImageClassifierApp: App {
  @StateObject var appConstants = AppConstants()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(self.appConstants)
    }
  }
}
