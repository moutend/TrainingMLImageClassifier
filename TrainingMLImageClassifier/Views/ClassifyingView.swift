import AVFoundation
import SwiftUI
import UIKit

struct ClassifyingView: View {
  enum ModelState {
    case unavailable
    case compiling
    case ready
    case classifying
  }

  let cameraManager = CameraManager()
  let imageClassifier = ImageClassifier()

  @EnvironmentObject var appConstants: AppConstants

  @State var predictions: [ImageClassifier.Prediction] = []
  @State var compilationTime: TimeInterval = 0.0
  @State var modelState: ModelState = .unavailable
  @State var isPreviewReady = false

  var body: some View {
    VStack {
      if self.isPreviewReady, let captureSession = self.cameraManager.captureSession {
        PreviewView(session: captureSession)
          .frame(width: UIScreen.main.bounds.size.width)
      }
      switch self.modelState {
      case .unavailable:
        Text("Please go back and train the model.")
          .padding()
      case .compiling:
        Text("Compiling the model, please one moment.")
          .padding()
      case .ready:
        Text("Setup Completed!")
          .padding()

        if self.compilationTime > 0.0 {
          Text("Compilation Time: \(self.compilationTime * 1000.0, specifier: "%.0f") ms")
            .padding()
        }

        Button(action: {
          self.modelState = .classifying
          self.cameraManager.delegate = self.imageClassifier
        }) {
          Text("Start Classifying")
            .padding()
            .foregroundColor(.white)
            .background(Color.indigo)
        }
        .padding()
      case .classifying:
        Text("Classification Result")
          .padding()

        if let prediction = self.predictions.first {
          Text("\(prediction.label) - \(prediction.confidence, specifier: "%.0f")%")
            .padding()
        }
      }
    }
    .onAppear {
      DispatchQueue.global(qos: .default).async {
        self.setupCamera()
      }
      if FileManager.default.fileExists(atPath: self.appConstants.mlmodelFile.path) {
        self.modelState = .compiling
        self.imageClassifier.compile(at: self.appConstants.mlmodelFile)
      }
    }
    .onDisappear {
      self.cameraManager.cleanup()
    }
    .onReceive(self.imageClassifier.ready) { compilationResult in
      if !compilationResult.compilationSkipped {
        self.compilationTime = compilationResult.compilationTime
      }

      self.modelState = .ready
    }
    .onReceive(self.imageClassifier.prediction) { predictions in
      self.predictions = predictions
    }
  }
  private func setupCamera() {
    do {
      try self.cameraManager.setup()
    } catch {
      fatalError("Failed to setup camera preview: \(error)")
    }

    self.cameraManager.startPreviewing()

    DispatchQueue.main.async {
      withAnimation {
        self.isPreviewReady = true
      }
    }
  }
}
