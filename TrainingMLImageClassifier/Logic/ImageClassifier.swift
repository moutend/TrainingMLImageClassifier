import Combine
import UIKit
import Vision

class ImageClassifier {
  struct CompilationResult {
    let compilationTime: TimeInterval
    let compilationSkipped: Bool
    let compiledModelURL: URL
  }

  struct Prediction: Identifiable {
    let id = UUID()

    let elapsedTime: TimeInterval
    let label: String
    let confidence: Float
  }

  var ready: AnyPublisher<CompilationResult, Never> {
    self.readySubject.eraseToAnyPublisher()
  }
  var prediction: AnyPublisher<[Prediction], Never> {
    self.predictionSubject.eraseToAnyPublisher()
  }

  private let readySubject = PassthroughSubject<CompilationResult, Never>()
  private let predictionSubject = PassthroughSubject<[Prediction], Never>()

  private var requestedAt: Date = .now
  private var model: VNCoreMLModel? = nil

  private func createImageClassificationRequest() -> VNImageBasedRequest {
    guard let model = self.model else {
      fatalError("Please compile the model.")
    }

    let request = VNCoreMLRequest(
      model: model,
      completionHandler: self.visionRequestHandler
    )

    request.imageCropAndScaleOption = .centerCrop

    return request
  }
  private func visionRequestHandler(_ request: VNRequest, error: Error?) {
    var predictions: [Prediction] = []

    defer {
      DispatchQueue.main.async {
        self.predictionSubject.send(predictions)
      }
    }
    if let error = error {
      print("Cannot process request: \(error)")
      return
    }
    if request.results == nil {
      print("No results.")
      return
    }
    guard let observations = request.results as? [VNClassificationObservation] else {
      print("VNRequest produced the wrong result type.")
      return
    }

    let elapsedTime = Date().timeIntervalSince(self.requestedAt)

    predictions = observations.map { observation in
      Prediction(
        elapsedTime: elapsedTime,
        label: observation.identifier,
        confidence: observation.confidence * 100.0
      )
    }
  }
  func compile(at mlmodelFileURL: URL) {
    let mlmodelcURL =
      mlmodelFileURL
      .deletingPathExtension()
      .appendingPathExtension("mlmodelc")

    Task {
      do {
        let compiledModelURL: URL
        let compilationTime: TimeInterval
        let compilationSkipped: Bool

        if FileManager.default.fileExists(atPath: mlmodelcURL.path) {
          compiledModelURL = mlmodelcURL
          compilationTime = 0.0
          compilationSkipped = true
        } else {
          let startedAt = Date()

          compiledModelURL = try await MLModel.compileModel(at: mlmodelFileURL)
          compilationTime = Date().timeIntervalSince(startedAt)
          compilationSkipped = false

          try FileManager.default.copyItem(
            at: compiledModelURL,
            to: mlmodelcURL
          )
        }

        let mlmodel = try await MLModel.load(
          contentsOf: compiledModelURL, configuration: MLModelConfiguration())

        self.model = try VNCoreMLModel(for: mlmodel)

        DispatchQueue.main.async {
          self.readySubject.send(
            CompilationResult(
              compilationTime: compilationTime,
              compilationSkipped: compilationSkipped,
              compiledModelURL: compiledModelURL
            )
          )
        }
      } catch {
        fatalError("Failed to compile the model: \(error)")
      }
    }
  }
  func makePredictions(for ciImage: CIImage) throws {
    let request = self.createImageClassificationRequest()
    let requests: [VNRequest] = [request]
    let handler = VNImageRequestHandler(ciImage: ciImage)

    self.requestedAt = Date()

    try handler.perform(requests)
  }
}

extension ImageClassifier: CameraManagerDelegate {
  func processImage(cvPixelBuffer: CVPixelBuffer) {
    let ciImage = CIImage(cvPixelBuffer: cvPixelBuffer)
      .oriented(.right)

    guard let squareImage = ciImage.square() else {
      return
    }
    guard let smallImage = squareImage.resize(targetSize: CGSize(width: 299, height: 299)) else {
      return
    }
    do {
      try self.makePredictions(for: smallImage)
    } catch {
      fatalError("failed to make prediction: \(error)")
    }
  }
}
