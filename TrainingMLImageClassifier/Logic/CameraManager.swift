import AVFoundation
import Combine
import CoreImage

protocol CameraManagerDelegate {
  func processImage(cvPixelBuffer: CVPixelBuffer)
}

class CameraManager: NSObject {
  private(set) var captureSession: AVCaptureSession? = nil
  var delegate: CameraManagerDelegate? = nil

  private var photoOutput: AVCapturePhotoOutput? = nil
  private var videoDataOutput: AVCaptureVideoDataOutput? = nil

  private let videoQueue = DispatchQueue(
    label: "com.example.TrainingMLImageClassifier.CameraManagerQueue", qos: .userInteractive)

  private var lastCapturedTime = CFAbsoluteTimeGetCurrent()

  enum ConfigurationError: Error {
    case cameraUnavailable
    case inputUnavailable
    case photoOutputUnavailable
    case videoDataOutputUnavailable
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

    let photoOutput = AVCapturePhotoOutput()

    if captureSession.canAddOutput(photoOutput) {
      captureSession.addOutput(photoOutput)
    } else {
      throw ConfigurationError.photoOutputUnavailable
    }

    let videoDataOutput = AVCaptureVideoDataOutput()

    if captureSession.canAddOutput(videoDataOutput) {
      videoDataOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
      videoDataOutput.alwaysDiscardsLateVideoFrames = true

      captureSession.addOutput(videoDataOutput)
    } else {
      throw ConfigurationError.videoDataOutputUnavailable
    }

    captureSession.commitConfiguration()

    self.videoDataOutput = videoDataOutput
    self.photoOutput = photoOutput
    self.captureSession = captureSession
  }
  func cleanup() {
    if let captureSession = self.captureSession {
      captureSession.stopRunning()
    }

    self.captureSession = nil
    self.photoOutput = nil
    self.videoDataOutput = nil
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

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    let capturedTime = CFAbsoluteTimeGetCurrent()
    let duration = capturedTime - self.lastCapturedTime

    if duration < 1.0 {
      return
    }

    self.lastCapturedTime = capturedTime

    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    guard let delegate = self.delegate else {
      return
    }

    delegate.processImage(cvPixelBuffer: imageBuffer)
  }
}
