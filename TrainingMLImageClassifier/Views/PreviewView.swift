import AVFoundation
import SwiftUI
import UIKit

struct PreviewView: UIViewRepresentable {
  let session: AVCaptureSession

  class Preview: UIView {
    override class var layerClass: AnyClass {
      AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
      layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
      get { previewLayer.session }
      set { previewLayer.session = newValue }
    }
  }

  func makeUIView(context: Context) -> Preview {
    let preview = Preview()

    preview.session = self.session
    preview.previewLayer.connection?.videoOrientation = .portrait

    return preview
  }
  func updateUIView(_ uiView: Preview, context: Context) {
    // Do nothing.
  }
}
