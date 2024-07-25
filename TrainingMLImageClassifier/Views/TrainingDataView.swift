import SwiftUI

struct TrainingDataView: View {
  @EnvironmentObject var appConstants: AppConstants

  @State var trainingData: [TrainingDataItem] = []
  @State var movieFile: URL = FileManager.default.temporaryDirectory
  @State var isMovieRecordingViewPresented = false
  @State var isTrainingProgressViewPresented = false

  var body: some View {
    VStack {
      Text("Training Data")
        .font(.title)
        .padding()
      ForEach(self.trainingData) { item in
        Button(action: {
          self.movieFile = item.movieFile
          self.isMovieRecordingViewPresented = true
        }) {
          (Text(Image(systemName: item.isCaptured ? "camera.fill" : "camera"))
            + Text(" \(item.name)"))
            .padding()
            .frame(width: 240, height: 80, alignment: .leading)
            .foregroundColor(.white)
            .background(.indigo)
        }
        .disabled(item.isCaptured)
        .opacity(item.isCaptured ? 0.75 : 1.0)
      }
      HStack {
        Button(action: self.clear) {
          Text("Clear")
            .padding()
            .foregroundColor(.white)
            .background(.indigo)
        }
        NavigationLink(
          destination: TrainingView()
        ) {
          Text("Next")
            .padding()
            .foregroundColor(.white)
            .background(Color.indigo)
        }
        .disabled(!self.trainingData.allCaptured)
        .opacity(!self.trainingData.allCaptured ? 0.75 : 1.0)
      }
      .padding()
    }
    .onAppear {
      self.trainingData.update(appConstants: self.appConstants)
    }
    .sheet(isPresented: self.$isMovieRecordingViewPresented) {
      MovieFileRecordingView(
        isPresented: self.$isMovieRecordingViewPresented,
        movieFile: self.$movieFile
      )
      .onDisappear {
        self.trainingData.update(appConstants: self.appConstants)
      }
    }
    .sheet(isPresented: self.$isTrainingProgressViewPresented) {
      VStack {
        Text("todo")
      }
    }
  }
  private func clear() {
    for item in self.trainingData {
      if !FileManager.default.fileExists(atPath: item.movieFile.path) {
        continue
      }

      do {
        try FileManager.default.removeItem(at: item.movieFile)
      } catch {
        fatalError("Failed to remove movie file: \(error)")
      }
    }

    self.trainingData.update(appConstants: self.appConstants)
  }
}

struct TrainingDataItem: Identifiable {
  let id = UUID()

  let name: String
  let isCaptured: Bool
  let movieFile: URL
  let labelDirectory: URL
}

extension Array where Element == TrainingDataItem {
  var allCaptured: Bool {
    return self.allSatisfy({ $0.isCaptured })
  }
  mutating func update(appConstants: AppConstants) {
    self = appConstants.names.map { name -> TrainingDataItem in
      guard let movieFile = appConstants.movieFiles[name] else {
        fatalError("Failed to get movie file URL")
      }
      guard let labelDirectory = appConstants.labelDirectories[name] else {
        fatalError("Failed to get label directory")
      }

      let isCaptured = FileManager.default.fileExists(atPath: movieFile.path)

      return TrainingDataItem(
        name: name,
        isCaptured: isCaptured,
        movieFile: movieFile,
        labelDirectory: labelDirectory
      )
    }
  }
}
