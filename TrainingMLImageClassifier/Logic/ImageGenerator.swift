import AVFoundation
import Combine
import CoreImage

class ImageGenerator: NSObject {
  struct Progress {
    let imagesCount: Int
    let totalImagesCount: Int
  }

  struct Input {
    let movieFile: URL
    let outputDirectory: URL
  }

  var progress: AnyPublisher<Progress, Never> {
    self.progressSubject.eraseToAnyPublisher()
  }

  private let progressSubject = PassthroughSubject<Progress, Never>()
  private var imageGeneratorArray: [AVAssetImageGenerator] = []

  override init() {
    super.init()
  }
  func cancel() {
    for imageGenerator in self.imageGeneratorArray {
      imageGenerator.cancelAllCGImageGeneration()
    }
  }
  func generate(from inputs: [Input]) {
    var imagesCount = 0
    var totalImagesCount = 0
    var timesArray: [[NSValue]] = []

    if !self.imageGeneratorArray.isEmpty {
      self.cancel()
      self.imageGeneratorArray = []
    }
    for input in inputs {
      let asset = AVAsset(url: input.movieFile)
      let imageGenerator = AVAssetImageGenerator(asset: asset)

      imageGenerator.appliesPreferredTrackTransform = true

      let duration = asset.duration
      let durationInSeconds = CMTimeGetSeconds(duration)
      let times = stride(from: 0, to: durationInSeconds, by: 0.02).map { time -> NSValue in
        return NSValue(time: CMTime(seconds: time, preferredTimescale: 600))
      }

      totalImagesCount += times.count

      self.imageGeneratorArray.append(imageGenerator)
      timesArray.append(times)
    }

    let mutex = DispatchQueue(label: "com.example.TrainingMLImageClassifier.imageGenerationQueue")
    let stepCount = totalImagesCount / 100

    for i in 0..<inputs.count {
      let outputDirectory = inputs[i].outputDirectory
      let times = timesArray[i]
      let imageGenerator = self.imageGeneratorArray[i]

      imageGenerator.generateCGImagesAsynchronously(forTimes: times) {
        requestedTime, cgImage, actualTime, result, error in
        if let error = error {
          fatalError("Failed to generate image: \(error)")
        }
        guard let cgImage = cgImage else {
          return
        }

        let ciImage = CIImage(cgImage: cgImage)

        guard let squareImage = ciImage.square() else {
          return
        }
        guard let smallImage = squareImage.resize(targetSize: CGSize(width: 299, height: 299))
        else {
          return
        }

        let outputFile =
          outputDirectory
          .appendingPathComponent(UUID().uuidString + ".jpg")

        smallImage.save(to: outputFile)

        mutex.async {
          imagesCount += 1

          if imagesCount % stepCount == 0 || imagesCount == totalImagesCount {
            DispatchQueue.main.async {
              self.progressSubject.send(
                Progress(
                  imagesCount: imagesCount,
                  totalImagesCount: totalImagesCount))
            }
          }
        }
      }
    }
  }
}
