import SwiftUI

struct TrainingView: View {
  enum TrainingState {
    case ready
    case generatingImages
    case training
    case finished
  }

  let imageGenerator = ImageGenerator()
  let imageTrainer = ImageTrainer()

  @EnvironmentObject var appConstants: AppConstants

  @State var trainingState: TrainingState = .ready

  @State var imagesCount = 0
  @State var totalImagesCount = 0
  @State var imageGenerationProgress: Double = 0.0

  @State var elapsedTime: TimeInterval = 0.0
  @State var modelSize: Int = 0
  @State var trainingAccuracy: Double = 0.0
  @State var validationAccuracy: Double = 0.0

  var body: some View {
    VStack {
      Text("Training")
        .font(.title)
        .padding()
      if self.trainingState == .ready {
        Button(action: {
          self.start()
        }) {
          Text("Start")
            .padding()
            .foregroundColor(.white)
            .background(Color.indigo)
        }
      }
      if self.trainingState == .generatingImages {
        ProgressView(value: self.imageGenerationProgress)
          .padding()
          .frame(width: 240)
        Text("Generating Images ... \(self.imagesCount) / \(self.totalImagesCount)")
          .padding()
      }
      if self.trainingState == .training {
        Text("Training the model ...")
          .padding()
        Text("This step takes a few minutes.")
          .padding()
      }
      if self.trainingState == .finished {
        Text("Completed!")
          .bold()
          .padding()
        VStack {
          Text("Elapsed Time: \(self.elapsedTime * 1000, specifier: "%.0f") ms")
            .padding()
          Text("Model Size: \(self.modelSize / 1024) KB")
            .padding()
          Text("Training Accuracy: \(self.trainingAccuracy, specifier: "%.0f")%")
            .padding()
          Text("Validation Accuracy: \(self.validationAccuracy, specifier: "%.0f")%")
            .padding()
        }
        .padding()
        Text("Please go back and try classifying.")
          .padding()
      }
    }
    .onDisappear {
      self.imageGenerator.cancel()
      self.imageTrainer.cancel()
    }
    .onReceive(self.imageGenerator.progress) { progress in
      self.imagesCount = progress.imagesCount
      self.totalImagesCount = progress.totalImagesCount
      self.imageGenerationProgress =
        Double(progress.imagesCount) / Double(progress.totalImagesCount)

      if progress.imagesCount == progress.totalImagesCount {
        DispatchQueue.global(qos: .default).async {
          DispatchQueue.main.async {
            self.trainingState = .training
          }

          self.imageTrainer.train(
            from: self.appConstants.trainingDataDirectory,
            to: self.appConstants.mlmodelFile
          )
        }
      }
    }
    .onReceive(self.imageTrainer.result) { result in
      self.elapsedTime = result.elapsedTime
      self.modelSize = result.modelSize
      self.trainingAccuracy = result.trainingAccuracy
      self.validationAccuracy = result.validationAccuracy
      self.trainingState = .finished
    }
  }

  private func start() {
    do {
      if FileManager.default.fileExists(atPath: self.appConstants.mlmodelDirectory.path) {
        try FileManager.default.removeItem(atPath: self.appConstants.mlmodelDirectory.path)
      }

      try FileManager.default.createDirectory(
        at: self.appConstants.mlmodelDirectory, withIntermediateDirectories: true, attributes: nil)

      for (_, labelDirectory) in self.appConstants.labelDirectories {
        if FileManager.default.fileExists(atPath: labelDirectory.path) {
          try FileManager.default.removeItem(atPath: labelDirectory.path)
        }

        try FileManager.default.createDirectory(
          at: labelDirectory, withIntermediateDirectories: true, attributes: nil)
      }
    } catch {
      fatalError("Failed to setup directories: \(error)")
    }

    let inputs = self.appConstants.names.map {
      name -> ImageGenerator.Input in
      guard let movieFile = self.appConstants.movieFiles[name] else {
        fatalError("Failed to get movie file URL")
      }
      guard let labelDirectory = self.appConstants.labelDirectories[name] else {
        fatalError("Failed to get label directory URL")
      }

      return ImageGenerator.Input(
        movieFile: movieFile,
        outputDirectory: labelDirectory
      )
    }

    self.imageGenerator.generate(from: inputs)
    self.trainingState = .generatingImages
  }
}
