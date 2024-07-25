import CoreImage

extension CIImage {
  func square() -> CIImage? {
    let originalWidth = self.extent.width
    let originalHeight = self.extent.height
    let squareSize = min(originalWidth, originalHeight)

    let originX = (originalWidth - squareSize) / 2
    let originY = (originalHeight - squareSize) / 2

    let cropRect = CGRect(x: originX, y: originY, width: squareSize, height: squareSize)

    return self.cropped(to: cropRect)
  }
  func resize(targetSize: CGSize) -> CIImage? {
    let originalWidth = self.extent.width
    let originalHeight = self.extent.height
    let scaleX = targetSize.width / originalWidth
    let scaleY = targetSize.height / originalHeight

    let scaleTransform = CGAffineTransform(scaleX: scaleX, y: scaleY)

    return self.transformed(by: scaleTransform)
  }
  func save(to outputFileURL: URL) {
    let context = CIContext()

    let colorSpace = self.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    let quality: CGFloat = 0.8
    let options: [CIImageRepresentationOption: Any] = [
      kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality
    ]

    guard
      let jpegData = context.jpegRepresentation(
        of: self, colorSpace: colorSpace, options: options)
    else {
      return
    }
    do {
      try jpegData.write(to: outputFileURL)
    } catch {
      fatalError("Failed to save a JPEG data: \(error)")
    }
  }
}
