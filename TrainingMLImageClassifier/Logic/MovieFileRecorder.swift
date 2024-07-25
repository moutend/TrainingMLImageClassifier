import AVFoundation
import Combine

class MovieFileRecorder: NSObject {
  private(set) var captureSession: AVCaptureSession? = nil

  var progress: AnyPublisher<Double, Never> {
    self.progressSubject.eraseToAnyPublisher()
  }
  var result: AnyPublisher<URL, Never> {
    self.resultSubject.eraseToAnyPublisher()
  }

  private let progressSubject = PassthroughSubject<Double, Never>()
  private let resultSubject = PassthroughSubject<URL, Never>()

  private var movieFileOutput: AVCaptureMovieFileOutput? = nil
  private var timer: Timer? = nil
  private var timerCount = 0

  enum ConfigurationError: Error {
    case cameraUnavailable
    case inputUnavailable
    case outputUnavailable
  }

  override init() {
    super.init()
  }
  func setup() throws {
    let captureSession = AVCaptureSession()

    captureSession.sessionPreset = .inputPriority
    captureSession.beginConfiguration()

    guard
      let videoDevice = AVCaptureDevice.default(
        .builtInWideAngleCamera, for: .video, position: .back)
    else {
      throw ConfigurationError.cameraUnavailable
    }

    let videoInput = try AVCaptureDeviceInput(device: videoDevice)

    if captureSession.canAddInput(videoInput) {
      captureSession.addInput(videoInput)
    } else {
      throw ConfigurationError.inputUnavailable
    }

    let movieFileOutput = AVCaptureMovieFileOutput()

    if captureSession.canAddOutput(movieFileOutput) {
      captureSession.addOutput(movieFileOutput)
    } else {
      throw ConfigurationError.outputUnavailable
    }

    captureSession.commitConfiguration()

    self.movieFileOutput = movieFileOutput
    self.captureSession = captureSession
  }
  func cleanup() {
    if let captureSession = self.captureSession {
      captureSession.stopRunning()
    }

    self.captureSession = nil
    self.movieFileOutput = nil
  }
  func startPreviewing() {
    guard let captureSession = self.captureSession else {
      return
    }

    captureSession.startRunning()
  }
  func stopPreviewing() {
    guard let captureSession = self.captureSession else {
      return
    }

    captureSession.stopRunning()
  }
  func startRecording(to output: URL) {
    guard let movieFileOutput = self.movieFileOutput else {
      return
    }

    movieFileOutput.startRecording(to: output, recordingDelegate: self)

    self.timerCount = 0

    self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
      self.timerCount += 1

      DispatchQueue.main.async {
        self.progressSubject.send(Double(self.timerCount) / 100.0)
      }
      if self.timerCount == 100 {
        timer.invalidate()
        self.stopRecording()
      }
    }
  }
  func stopRecording() {
    guard let movieFileOutput = self.movieFileOutput else {
      return
    }

    movieFileOutput.stopRecording()
  }
  func toggleTorch() -> Bool {
    guard
      let videoDevice = AVCaptureDevice.default(
        .builtInWideAngleCamera, for: .video, position: .back)
    else {
      return false
    }
    do {
      try videoDevice.lockForConfiguration()

      if videoDevice.torchMode == .off {
        try videoDevice.setTorchModeOn(level: 1.0)
      } else {
        videoDevice.torchMode = .off
      }

      videoDevice.unlockForConfiguration()
    } catch {
      return false
    }

    return videoDevice.torchMode == .on
  }
}

extension MovieFileRecorder: AVCaptureFileOutputRecordingDelegate {
  func fileOutput(
    _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
    from connections: [AVCaptureConnection], error: Error?
  ) {
    defer {
      if let timer = self.timer {
        timer.invalidate()
      }

      self.timer = nil
    }
    if let err = error {
      // Stopped by user interrupt is normal situation.
      return
    }
    DispatchQueue.main.async {
      self.resultSubject.send(outputFileURL)
    }
  }
}
