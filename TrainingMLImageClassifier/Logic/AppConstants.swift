import Foundation

class AppConstants: NSObject, ObservableObject {
  let names = [
    "North",
    "East",
    "West",
    "South",
  ]

  let videoDirectory: URL
  let movieFiles: [String: URL]
  let trainingDataDirectory: URL
  let labelDirectories: [String: URL]
  let mlmodelDirectory: URL
  let mlmodelFile: URL

  override init() {
    do {
      let documentsDirectory = try FileManager.default.url(
        for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

      self.videoDirectory = documentsDirectory.appendingPathComponent("Video")
      self.trainingDataDirectory = documentsDirectory.appendingPathComponent("TrainingData")

      var movieFiles = [String: URL]()
      var labelDirectories = [String: URL]()

      for name in self.names {
        movieFiles[name] = self.videoDirectory.appendingPathComponent(name + ".mov")
        labelDirectories[name] = self.trainingDataDirectory.appendingPathComponent(name)
      }

      self.movieFiles = movieFiles
      self.labelDirectories = labelDirectories

      self.mlmodelDirectory = documentsDirectory.appendingPathComponent("MLModel")
      self.mlmodelFile = self.mlmodelDirectory.appendingPathComponent("NewsModelV1.mlmodel")
    } catch {
      fatalError("Failed to setup directories: \(error)")
    }

    super.init()
  }
}
