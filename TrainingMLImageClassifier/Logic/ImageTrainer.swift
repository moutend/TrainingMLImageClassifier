import Combine
import CreateML
import Foundation

class ImageTrainer: NSObject {
  struct TrainingResult {
    let elapsedTime: TimeInterval
    let modelSize: Int
    let trainingAccuracy: Double
    let validationAccuracy: Double
  }

  var result: AnyPublisher<TrainingResult, Never> {
    self.resultSubject.eraseToAnyPublisher()
  }

  private let resultSubject = PassthroughSubject<TrainingResult, Never>()

  private var job: MLJob<MLImageClassifier>? = nil
  private var resultCancellable: AnyCancellable? = nil
  private var trainingStartedDate: Date? = nil

  override init() {
    super.init()
  }
  func cancel() {
    guard let job = self.job else {
      return
    }

    job.cancel()
  }
  func train(from trainingDataDirectory: URL, to mlmodelFileURL: URL) {
    let parameters = MLImageClassifier.ModelParameters(
      validation: .split(strategy: .automatic),
      maxIterations: 50,
      augmentation: [],
      algorithm: .transferLearning(
        featureExtractor: .scenePrint(revision: nil),
        classifier: .logisticRegressor
      )
    )

    self.trainingStartedDate = Date()

    do {
      self.job = try MLImageClassifier.train(
        trainingData: .labeledDirectories(at: trainingDataDirectory),
        parameters: parameters
      )
    } catch {
      fatalError("Failed to start training: \(error)")
    }

    self.resultCancellable = self.job?.result.sink(
      receiveCompletion: { [weak self] completion in
        switch completion {
        case .failure(let err):
          // This error occurs as normal condition. For example, when the MLJob's cancel() method was called.
          print("Failed to complete training: \(err)")

          self?.job = nil

          break
        case .finished:
          break
        }
      },
      receiveValue: { [weak self] classifier in
        guard let trainingStartedDate = self?.trainingStartedDate else {
          fatalError("Failed to get the date training started.")
        }

        let metadata = MLModelMetadata(
          author: "Yoshiyuki Koyanagi",
          shortDescription: "Classifies north, east, west and south from the given images",
          license: "MIT"
        )

        let modelSize: Int

        do {
          try classifier.write(to: mlmodelFileURL, metadata: metadata)

          let attributes = try FileManager.default.attributesOfItem(atPath: mlmodelFileURL.path)

          modelSize = attributes[.size] as? Int ?? 0
        } catch {
          fatalError("Failed to save the image classifier model: \(error)")
        }

        let result = TrainingResult(
          elapsedTime: Date().timeIntervalSince(trainingStartedDate),
          modelSize: modelSize,
          trainingAccuracy: (1.0 - classifier.trainingMetrics.classificationError) * 100,
          validationAccuracy: (1.0 - classifier.validationMetrics.classificationError) * 100
        )

        DispatchQueue.main.async {
          self?.resultSubject.send(result)
        }

        self?.job = nil
      })
  }
}
