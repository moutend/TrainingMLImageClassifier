import SwiftUI

struct ContentView: View {
  @EnvironmentObject var appConstants: AppConstants

  var body: some View {
    NavigationView {
      VStack {
        HStack {
          NavigationLink(
            destination: ClassifyingView()
          ) {
            VStack {
              Text(Image(systemName: "magnifyingglass"))
                .font(.largeTitle)
                .padding(4)
              Text("Classify")
                .font(.body)
                .bold()
            }
            .frame(width: 128, height: 144)
            .foregroundColor(.white)
            .background(Color.indigo)
          }
          NavigationLink(
            destination: TrainingDataView()
          ) {
            VStack {
              Text(Image(systemName: "book.fill"))
                .font(.largeTitle)
                .padding(4)
              Text("Train")
                .font(.body)
                .bold()
            }
            .frame(width: 128, height: 144)
            .foregroundColor(.white)
            .background(Color.indigo)
          }
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}
