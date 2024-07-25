import AVFoundation
import SwiftUI
import UIKit

struct ClassifyingView: View {
  enum ModelState {
    case unavailable
    case ready
    case compiling
    case compiled
    case classifying
  }

  let cameraManager = CameraManager()
  let imageClassifier = ImageClassifier()

  @EnvironmentObject var appConstants: AppConstants

  @State var predictions: [ImageClassifier.Prediction] = []
  @State var compilationTime: CFTimeInterval = 0.0
  @State var modelState: ModelState = .unavailable
  @State var isPreviewReady = false

  var body: some View {
    VStack {
      if self.isPreviewReady, let captureSession = self.cameraManager.captureSession {
        PreviewView(session: captureSession)
          .frame(width: UIScreen.main.bounds.size.width)
      }
      if self.modelState == .unavailable {
        Text("Please train the image classifier model at first.")
          .padding()
      }
      if self.modelState == .ready || self.modelState == .compiling {
        Button(action: {
          self.modelState = .compiling
          self.imageClassifier.setup(at: self.appConstants.mlmodelFile)
        }) {
          Text(
            "\(self.modelState == .compiling ? "Compiling..." : "Compile Image Classifier Model")"
          )
          .padding()
          .foregroundColor(.white)
          .background(Color.indigo)
          .padding()
        }
        .padding()
        .disabled(self.modelState == .compiling)
      }
      if self.modelState == .compiled {
        Text("Compilation Time - \(self.compilationTime, specifier: "%.0f") ms")
          .padding()
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
      }
      if self.modelState == .classifying {
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
        do {
          try self.cameraManager.setup()
        } catch {
          fatalError("Failed to setup camera preview: \(error)")
        }

        self.cameraManager.startPreviewing()

        let isModelAvailable = FileManager.default.fileExists(
          atPath: self.appConstants.mlmodelFile.path)

        DispatchQueue.main.async {
          withAnimation {
            self.isPreviewReady = true

            if isModelAvailable {
              self.modelState = .ready
            }
          }
        }
      }
    }
    .onDisappear {
      self.cameraManager.cleanup()
    }
    .onReceive(self.imageClassifier.ready) { compilationTime in
      self.compilationTime = compilationTime
      self.modelState = .compiled
    }
    .onReceive(self.imageClassifier.prediction) { predictions in
      self.predictions = predictions
    }
  }
}
