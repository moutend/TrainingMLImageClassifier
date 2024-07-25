import SwiftUI

struct MovieFileRecordingView: View {
  enum RecordingState {
    case ready
    case inprogress
    case saving
  }

  let movieFileRecorder = MovieFileRecorder()

  @Binding var isPresented: Bool
  @Binding var movieFile: URL

  @State var recordingState: RecordingState = .ready
  @State var recordingProgress: Double = 0.0
  @State var isCameraPreviewReady = false
  @State var torchMode = false

  var buttonLabel: String {
    switch self.recordingState {
    case .ready:
      return "Capture"
    case .inprogress:
      return "Capturing..."
    case .saving:
      return "Saving..."
    }
  }

  var body: some View {
    VStack {
      if self.isCameraPreviewReady, let captureSession = self.movieFileRecorder.captureSession {
        PreviewView(session: captureSession)
          .frame(width: UIScreen.main.bounds.size.width)
      }
      ProgressView(value: self.recordingProgress)
        .padding()
        .frame(width: 240)
      HStack {
        Button(action: {
          self.torchMode = self.movieFileRecorder.toggleTorch()
        }) {
          Text(
            Image(
              systemName:
                self.torchMode
                ? "flashlight.off.fill"
                : "flashlight.on.fill"
            )
          )
          .padding()
          .foregroundColor(.white)
          .background(.indigo)
        }
        .accessibilityLabel(self.torchMode ? "Turn off torch" : "Turn on torch")
        Button(action: self.startCapturing) {
          Text(self.buttonLabel)
            .padding()
            .foregroundColor(.white)
            .background(.indigo)
        }
        .disabled(self.recordingState != .ready)
        .opacity(self.recordingState != .ready ? 0.75 : 1.0)
      }
      .padding()
    }
    .onAppear {
      DispatchQueue.global(qos: .default).async {
        self.onAppear()
      }
    }
    .onDisappear {
      self.onDisappear()
    }
    .onReceive(self.movieFileRecorder.progress) { progress in
      self.recordingProgress = progress
    }
    .onReceive(self.movieFileRecorder.result) { url in
      self.isPresented = false
    }
  }

  private func onAppear() {
    do {
      try self.movieFileRecorder.setup()
    } catch {
      fatalError("Failed to setup MovieFileRecorder: \(error)")
    }

    self.movieFileRecorder.startPreviewing()

    DispatchQueue.main.async {
      withAnimation {
        self.isCameraPreviewReady = true
      }
    }
  }
  private func onDisappear() {
    self.movieFileRecorder.cleanup()

    if self.recordingProgress < 1.0 {
      try? FileManager.default.removeItem(atPath: self.movieFile.path)
    }
  }
  private func startCapturing() {
    do {
      try FileManager.default.createDirectory(
        at: self.movieFile.deletingLastPathComponent(), withIntermediateDirectories: true,
        attributes: nil)
    } catch {
      fatalError("Failed to create directory: \(error)")
    }

    self.recordingState = .inprogress
    self.movieFileRecorder.startRecording(to: self.movieFile)
  }
}
