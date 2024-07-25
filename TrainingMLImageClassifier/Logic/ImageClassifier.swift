import Combine
import UIKit
import Vision

class ImageClassifier {
  struct Prediction: Identifiable {
    let id = UUID()

    let label: String
    let confidence: Float
  }

  var ready: AnyPublisher<CFTimeInterval, Never> {
    self.readySubject.eraseToAnyPublisher()
  }
  var prediction: AnyPublisher<[Prediction], Never> {
    self.predictionSubject.eraseToAnyPublisher()
  }

  private let readySubject = PassthroughSubject<CFTimeInterval, Never>()
  private let predictionSubject = PassthroughSubject<[Prediction], Never>()

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

    predictions = observations.map { observation in
      Prediction(
        label: observation.identifier,
        confidence: observation.confidence * 100.0
      )
    }
  }
  func setup(at mlmodelFileURL: URL) {
    Task {
      let startTime = CFAbsoluteTimeGetCurrent()

      do {
        let compiledModelURL = try await MLModel.compileModel(at: mlmodelFileURL)
        let mlmodel = try await MLModel.load(
          contentsOf: compiledModelURL, configuration: MLModelConfiguration())

        guard let model = try? VNCoreMLModel(for: mlmodel) else {
          fatalError("Failed to create a VNCoreMLModel instance.")
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = (endTime - startTime) * 1000.0

        self.model = model

        DispatchQueue.main.async {
          self.readySubject.send(duration)
        }
      } catch {
        fatalError("Failed to load the .mlmodel file: \(error)")
      }
    }
  }
  func makePredictions(for ciImage: CIImage) throws {
    let request = self.createImageClassificationRequest()
    let requests: [VNRequest] = [request]
    let handler = VNImageRequestHandler(ciImage: ciImage)

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
