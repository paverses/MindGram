import Foundation
import UIKit
import CoreImage
import CoreVideo
import Vision
import ImageIO

/// Applies a `MindGramRoundEffect` to upright square frames. Faces (Vision) are found every few frames
/// and reused in between; the person mask for background effects is made every frame.
public final class MindGramRoundRenderer {
    private struct Face {
        /// Normalized to the image, origin at the bottom left (Vision and Core Image agree on that).
        var box: CGRect
        var roll: CGFloat
        var leftEye: CGPoint?
        var rightEye: CGPoint?
    }

    private let context: CIContext
    private var frameIndex = 0
    private var faces: [Face] = []
    private var pool: CVPixelBufferPool?
    private var poolSize: CGSize = .zero
    private var poolFormat: OSType = 0
    private var overlayCache: [String: CIImage] = [:]

    public init() {
        self.context = CIContext(options: [.cacheIntermediates: false, .name: "MindGramRoundVideo"])
    }

    // MARK: Entry points

    /// A recorded frame (square BGRA from Telegram's round video pipeline): returns a new buffer with
    /// the effect, or nil when there is nothing to change.
    public func process(pixelBuffer: CVPixelBuffer, effect: MindGramRoundEffect) -> CVPixelBuffer? {
        guard effect != .off else {
            return nil
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let output = self.makeBuffer(width: width, height: height, pixelFormat: CVPixelBufferGetPixelFormatType(pixelBuffer)) else {
            return nil
        }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let result = self.render(image, effect: effect).cropped(to: image.extent)
        self.context.render(result, to: output, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        return output
    }

    /// A camera frame for the on-screen circle: rotated upright, cropped to a square of `side` pixels.
    public func previewImage(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, side: CGFloat, effect: MindGramRoundEffect) -> CGImage? {
        var image = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let square = min(image.extent.width, image.extent.height)
        image = image.cropped(to: CGRect(x: (image.extent.width - square) / 2.0, y: (image.extent.height - square) / 2.0, width: square, height: square))
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let scale = side / square
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rendered = self.render(image, effect: effect).cropped(to: image.extent)
        return self.context.createCGImage(rendered, from: image.extent)
    }

    // MARK: Rendering

    /// `image` must start at the origin.
    public func render(_ image: CIImage, effect: MindGramRoundEffect) -> CIImage {
        self.frameIndex += 1
        let extent = image.extent
        if effect.usesFaces && (self.frameIndex % 3 == 1 || self.faces.isEmpty) {
            self.detectFaces(in: image, landmarks: effect == .sunglasses)
        }

        switch effect {
        case .off:
            return image
        case .faceBlur:
            let sigma = 12.0 + 30.0 * MindGramRoundVideo.strength
            let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
            return self.blendOnFaces(blurred, over: image, softness: 0.25)
        case .facePixelate:
            let pixelScale = max(8.0, extent.width / CGFloat(40.0 - 28.0 * MindGramRoundVideo.strength))
            let pixelated = self.filter("CIPixellate", image.clampedToExtent(), [kCIInputScaleKey: pixelScale, kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY)])?.cropped(to: extent) ?? image
            return self.blendOnFaces(pixelated, over: image, softness: 0.05)
        case .backgroundBlur:
            let sigma = 6.0 + 22.0 * MindGramRoundVideo.strength
            let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
            return self.blendPerson(image, over: blurred)
        case .backgroundReplace:
            let preset = MindGramRoundVideo.backgrounds[MindGramRoundVideo.backgroundIndex]
            let gradient = self.filter("CILinearGradient", nil, [
                "inputPoint0": CIVector(x: 0.0, y: 0.0),
                "inputPoint1": CIVector(x: 0.0, y: extent.height),
                "inputColor0": CIColor(color: preset.bottom),
                "inputColor1": CIColor(color: preset.top)
            ])?.cropped(to: extent) ?? image
            return self.blendPerson(image, over: gradient)
        case .emojiMask:
            return self.placeOnFaces(image, overlay: self.emojiImage(MindGramRoundVideo.maskEmoji), widthFactor: 1.55, verticalOffset: 0.0)
        case .sunglasses:
            return self.placeSunglasses(image)
        case .crown:
            return self.placeOnFaces(image, overlay: self.emojiImage("👑"), widthFactor: 0.95, verticalOffset: 0.78)
        case .halo:
            return self.placeOnFaces(image, overlay: self.haloImage(), widthFactor: 1.05, verticalOffset: 0.8)
        case .horns:
            return self.placeOnFaces(image, overlay: self.hornsImage(), widthFactor: 1.15, verticalOffset: 0.62)
        case .noir:
            return self.filter("CIPhotoEffectNoir", image, [:]) ?? image
        case .vintage:
            let film = self.filter("CIPhotoEffectTransfer", image, [:]) ?? image
            return self.filter("CIVignette", film, [kCIInputIntensityKey: 1.3, kCIInputRadiusKey: 1.6])?.cropped(to: extent) ?? film
        case .comic:
            return self.filter("CIComicEffect", image, [:])?.cropped(to: extent) ?? image
        case .thermal:
            if let thermal = self.filter("CIThermal", image, [:]) {
                return thermal.cropped(to: extent)
            }
            return self.filter("CIFalseColor", image, ["inputColor0": CIColor(red: 0.1, green: 0.0, blue: 0.6), "inputColor1": CIColor(red: 1.0, green: 0.85, blue: 0.1)]) ?? image
        case .xray:
            if let xray = self.filter("CIXRay", image, [:]) {
                return xray.cropped(to: extent)
            }
            let mono = self.filter("CIPhotoEffectMono", image, [:]) ?? image
            return self.filter("CIColorInvert", mono, [:]) ?? image
        case .beauty:
            let smooth = image.clampedToExtent().applyingGaussianBlur(sigma: 3.0 + 4.0 * MindGramRoundVideo.strength).cropped(to: extent)
            let mixed = self.filter("CIDissolveTransition", image, [kCIInputTargetImageKey: smooth, kCIInputTimeKey: 0.55]) ?? image
            let skin = self.blendOnFaces(mixed, over: image, softness: 0.3)
            return self.filter("CIColorControls", skin, [kCIInputBrightnessKey: 0.035, kCIInputSaturationKey: 1.08, kCIInputContrastKey: 1.02]) ?? skin
        case .glitch:
            return self.glitch(image)
        case .vhs:
            return self.vhs(image)
        case .kaleidoscope:
            return self.filter("CIKaleidoscope", image.clampedToExtent(), ["inputCount": 6, kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY), kCIInputAngleKey: Double(self.frameIndex % 360) * .pi / 360.0])?.cropped(to: extent) ?? image
        }
    }

    private func filter(_ name: String, _ input: CIImage?, _ parameters: [String: Any]) -> CIImage? {
        guard let filter = CIFilter(name: name) else {
            return nil
        }
        if let input {
            filter.setValue(input, forKey: kCIInputImageKey)
        }
        for (key, value) in parameters {
            filter.setValue(value, forKey: key)
        }
        return filter.outputImage
    }

    // MARK: Faces

    private func detectFaces(in image: CIImage, landmarks: Bool) {
        let request: VNImageBasedRequest = landmarks ? VNDetectFaceLandmarksRequest() : VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }
        let observations = (request.results as? [VNFaceObservation]) ?? []
        self.faces = observations.map { observation in
            var face = Face(box: observation.boundingBox, roll: CGFloat(observation.roll?.doubleValue ?? 0.0), leftEye: nil, rightEye: nil)
            if let landmarks = observation.landmarks {
                face.leftEye = self.center(landmarks.leftPupil ?? landmarks.leftEye, box: observation.boundingBox)
                face.rightEye = self.center(landmarks.rightPupil ?? landmarks.rightEye, box: observation.boundingBox)
            }
            return face
        }
    }

    private func center(_ region: VNFaceLandmarkRegion2D?, box: CGRect) -> CGPoint? {
        guard let region, region.pointCount > 0 else {
            return nil
        }
        var x: CGFloat = 0.0
        var y: CGFloat = 0.0
        for point in region.normalizedPoints {
            x += point.x
            y += point.y
        }
        x /= CGFloat(region.pointCount)
        y /= CGFloat(region.pointCount)
        return CGPoint(x: box.minX + x * box.width, y: box.minY + y * box.height)
    }

    private func faceRect(_ face: Face, in extent: CGRect) -> CGRect {
        return CGRect(x: face.box.minX * extent.width, y: face.box.minY * extent.height, width: face.box.width * extent.width, height: face.box.height * extent.height)
    }

    /// `effect` where faces are, `image` elsewhere, with soft oval edges.
    private func blendOnFaces(_ effect: CIImage, over image: CIImage, softness: CGFloat) -> CIImage {
        let extent = image.extent
        var mask: CIImage?
        for face in self.faces {
            let rect = self.faceRect(face, in: extent)
            let radius = max(rect.width, rect.height) * 0.62
            guard let oval = self.filter("CIRadialGradient", nil, [
                "inputCenter": CIVector(x: rect.midX, y: rect.midY + rect.height * 0.08),
                "inputRadius0": radius * (1.0 - softness),
                "inputRadius1": radius,
                "inputColor0": CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
                "inputColor1": CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            ])?.cropped(to: extent) else {
                continue
            }
            mask = mask.map { oval.composited(over: $0) } ?? oval
        }
        guard let mask else {
            return image
        }
        return self.filter("CIBlendWithMask", effect, [kCIInputBackgroundImageKey: image, kCIInputMaskImageKey: mask]) ?? image
    }

    /// Puts `overlay` on every face: `widthFactor` of the face width, moved up by `verticalOffset` face heights.
    private func placeOnFaces(_ image: CIImage, overlay: CIImage?, widthFactor: CGFloat, verticalOffset: CGFloat) -> CIImage {
        guard let overlay else {
            return image
        }
        var result = image
        for face in self.faces {
            let rect = self.faceRect(face, in: image.extent)
            let scale = rect.width * widthFactor / overlay.extent.width
            let center = CGPoint(x: rect.midX - sin(face.roll) * rect.height * verticalOffset, y: rect.midY + cos(face.roll) * rect.height * verticalOffset)
            var transform = CGAffineTransform(translationX: -overlay.extent.width / 2.0, y: -overlay.extent.height / 2.0)
            transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
            transform = transform.concatenating(CGAffineTransform(rotationAngle: face.roll))
            transform = transform.concatenating(CGAffineTransform(translationX: center.x, y: center.y))
            result = overlay.transformed(by: transform).composited(over: result)
        }
        return result.cropped(to: image.extent)
    }

    private func placeSunglasses(_ image: CIImage) -> CIImage {
        guard let glasses = self.emojiImage("🕶️") else {
            return image
        }
        var result = image
        let extent = image.extent
        for face in self.faces {
            let rect = self.faceRect(face, in: extent)
            var center = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.62)
            var angle = face.roll
            var width = rect.width * 1.05
            if let left = face.leftEye, let right = face.rightEye {
                let l = CGPoint(x: left.x * extent.width, y: left.y * extent.height)
                let r = CGPoint(x: right.x * extent.width, y: right.y * extent.height)
                center = CGPoint(x: (l.x + r.x) / 2.0, y: (l.y + r.y) / 2.0)
                angle = atan2(r.y - l.y, r.x - l.x)
                if abs(angle) > .pi / 2.0 {
                    angle += angle > 0 ? -.pi : .pi
                }
                width = max(width, hypot(r.x - l.x, r.y - l.y) * 2.3)
            }
            let scale = width / glasses.extent.width
            var transform = CGAffineTransform(translationX: -glasses.extent.width / 2.0, y: -glasses.extent.height / 2.0)
            transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
            transform = transform.concatenating(CGAffineTransform(rotationAngle: angle))
            transform = transform.concatenating(CGAffineTransform(translationX: center.x, y: center.y))
            result = glasses.transformed(by: transform).composited(over: result)
        }
        return result.cropped(to: extent)
    }

    // MARK: Person mask

    private func blendPerson(_ image: CIImage, over background: CIImage) -> CIImage {
        guard #available(iOS 15.0, *) else {
            return background
        }
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .fast
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return image
        }
        guard let maskBuffer = request.results?.first?.pixelBuffer else {
            return image
        }
        var mask = CIImage(cvPixelBuffer: maskBuffer)
        mask = mask.transformed(by: CGAffineTransform(scaleX: image.extent.width / mask.extent.width, y: image.extent.height / mask.extent.height))
        mask = mask.clampedToExtent().applyingGaussianBlur(sigma: 2.0).cropped(to: image.extent)
        return self.filter("CIBlendWithMask", image, [kCIInputBackgroundImageKey: background, kCIInputMaskImageKey: mask]) ?? image
    }

    // MARK: Filters with motion

    private func glitch(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let jitter = CGFloat((self.frameIndex * 7919) % 13) - 6.0
        let shift = (extent.width / 80.0) * (1.0 + 2.0 * CGFloat(MindGramRoundVideo.strength)) + jitter
        func channel(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, dx: CGFloat) -> CIImage? {
            return self.filter("CIColorMatrix", image.clampedToExtent(), [
                "inputRVector": CIVector(x: r, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: g, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: b, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])?.transformed(by: CGAffineTransform(translationX: dx, y: 0)).cropped(to: extent)
        }
        guard let red = channel(1, 0, 0, dx: shift), let green = channel(0, 1, 0, dx: 0), let blue = channel(0, 0, 1, dx: -shift) else {
            return image
        }
        let rg = self.filter("CIAdditionCompositing", red, [kCIInputBackgroundImageKey: green]) ?? image
        var result = self.filter("CIAdditionCompositing", rg, [kCIInputBackgroundImageKey: blue]) ?? image
        // Every few frames a band of the picture jumps sideways.
        if self.frameIndex % 9 < 3 {
            let bandHeight = extent.height / 9.0
            let bandY = CGFloat((self.frameIndex * 104729) % 8) * bandHeight
            let band = result.clampedToExtent().transformed(by: CGAffineTransform(translationX: shift * 3.0, y: 0)).cropped(to: CGRect(x: 0, y: bandY, width: extent.width, height: bandHeight))
            result = band.composited(over: result)
        }
        return result.cropped(to: extent)
    }

    private func vhs(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let soft = image.clampedToExtent().applyingGaussianBlur(sigma: 0.8).cropped(to: extent)
        let faded = self.filter("CIColorControls", soft, [kCIInputSaturationKey: 0.75, kCIInputContrastKey: 1.1]) ?? soft
        var result = self.glitchLight(faded)
        if let noise = self.filter("CIRandomGenerator", nil, [:]) {
            let offset = CGFloat((self.frameIndex * 7) % 200)
            let grain = self.filter("CIColorMatrix", noise.transformed(by: CGAffineTransform(translationX: offset, y: offset)), [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0.12, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
            ])?.cropped(to: extent)
            if let grain {
                result = grain.composited(over: result)
            }
        }
        if let stripes = self.filter("CIStripesGenerator", nil, [
            "inputColor0": CIColor(red: 0, green: 0, blue: 0, alpha: 0.22),
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
            "inputWidth": max(1.0, extent.height / 160.0),
            "inputSharpness": 1.0
        ]) {
            let lines = stripes.transformed(by: CGAffineTransform(rotationAngle: .pi / 2.0)).cropped(to: extent)
            result = lines.composited(over: result)
        }
        return result.cropped(to: extent)
    }

    private func glitchLight(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let shift = extent.width / 160.0
        guard let red = self.filter("CIColorMatrix", image.clampedToExtent(), [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])?.transformed(by: CGAffineTransform(translationX: shift, y: 0)).cropped(to: extent), let rest = self.filter("CIColorMatrix", image, [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]) else {
            return image
        }
        return self.filter("CIAdditionCompositing", red, [kCIInputBackgroundImageKey: rest])?.cropped(to: extent) ?? image
    }

    // MARK: Overlays

    private func emojiImage(_ emoji: String) -> CIImage? {
        if let cached = self.overlayCache[emoji] {
            return cached
        }
        let size = CGSize(width: 256.0, height: 256.0)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let text = NSAttributedString(string: emoji, attributes: [.font: UIFont.systemFont(ofSize: 210.0)])
            let textSize = text.size()
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2.0, y: (size.height - textSize.height) / 2.0))
        }
        guard let cgImage = rendered.cgImage else {
            return nil
        }
        let image = CIImage(cgImage: cgImage)
        self.overlayCache[emoji] = image
        return image
    }

    private func haloImage() -> CIImage? {
        if let cached = self.overlayCache["halo"] {
            return cached
        }
        let size = CGSize(width: 256.0, height: 96.0)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let ring = CGRect(x: 24.0, y: 22.0, width: size.width - 48.0, height: size.height - 44.0)
            cg.setShadow(offset: .zero, blur: 18.0, color: UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0).cgColor)
            cg.setStrokeColor(UIColor(red: 1.0, green: 0.84, blue: 0.3, alpha: 1.0).cgColor)
            cg.setLineWidth(12.0)
            cg.strokeEllipse(in: ring)
            cg.setShadow(offset: .zero, blur: 0.0, color: nil)
            cg.setStrokeColor(UIColor(red: 1.0, green: 0.97, blue: 0.8, alpha: 1.0).cgColor)
            cg.setLineWidth(4.0)
            cg.strokeEllipse(in: ring)
        }
        guard let cgImage = rendered.cgImage else {
            return nil
        }
        let image = CIImage(cgImage: cgImage)
        self.overlayCache["halo"] = image
        return image
    }

    private func hornsImage() -> CIImage? {
        if let cached = self.overlayCache["horns"] {
            return cached
        }
        let size = CGSize(width: 256.0, height: 120.0)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            func horn(baseX: CGFloat, direction: CGFloat) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: baseX - 26.0, y: size.height - 4.0))
                path.addQuadCurve(to: CGPoint(x: baseX + direction * 30.0, y: 6.0), controlPoint: CGPoint(x: baseX - direction * 30.0, y: size.height * 0.35))
                path.addQuadCurve(to: CGPoint(x: baseX + 26.0, y: size.height - 4.0), controlPoint: CGPoint(x: baseX + direction * 4.0, y: size.height * 0.45))
                path.close()
                cg.saveGState()
                cg.addPath(path.cgPath)
                cg.clip()
                let colors = [UIColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 1.0).cgColor, UIColor(red: 0.6, green: 0.0, blue: 0.05, alpha: 1.0).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
                    cg.drawLinearGradient(gradient, start: CGPoint(x: baseX, y: 0.0), end: CGPoint(x: baseX, y: size.height), options: [])
                }
                cg.restoreGState()
            }
            horn(baseX: 52.0, direction: -1.0)
            horn(baseX: size.width - 52.0, direction: 1.0)
        }
        guard let cgImage = rendered.cgImage else {
            return nil
        }
        let image = CIImage(cgImage: cgImage)
        self.overlayCache["horns"] = image
        return image
    }

    // MARK: Buffers

    /// A buffer like the input (size and pixel format), so the camera can keep its format description.
    private func makeBuffer(width: Int, height: Int, pixelFormat: OSType) -> CVPixelBuffer? {
        let size = CGSize(width: width, height: height)
        if self.pool == nil || self.poolSize != size || self.poolFormat != pixelFormat {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary
            ]
            var pool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(kCFAllocatorDefault, [kCVPixelBufferPoolMinimumBufferCountKey as String: 4] as CFDictionary, attributes as CFDictionary, &pool)
            self.pool = pool
            self.poolSize = size
            self.poolFormat = pixelFormat
        }
        guard let pool = self.pool else {
            return nil
        }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
        return buffer
    }
}

/// The camera's side of the effects: recorded frames and the live circle on screen.
public extension MindGramRoundVideo {
    private static let recordRenderer = MindGramRoundRenderer()
    private static let previewRenderer = MindGramRoundRenderer()
    private static let previewQueue = DispatchQueue(label: "MindGram.roundPreview", qos: .userInitiated)
    private static let sinkLock = NSLock()
    private static var sink: ((CGImage?) -> Void)?
    private static var previewBusy = false
    private static var previewShowing = false

    /// Set by the round video camera screen while it is open; gets the circle's picture with the effect,
    /// or nil when there is no effect (show the camera itself).
    static func setPreviewSink(_ value: ((CGImage?) -> Void)?) {
        self.sinkLock.lock()
        self.sink = value
        self.previewShowing = false
        self.sinkLock.unlock()
    }

    /// A recorded round video frame: the frame with the effect, or the same frame.
    static func processRecordedFrame(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        let effect = self.current
        guard effect != .off else {
            return pixelBuffer
        }
        return self.recordRenderer.process(pixelBuffer: pixelBuffer, effect: effect) ?? pixelBuffer
    }

    /// Every camera frame while the round video camera runs (single camera only).
    /// CameraNeo delivers sensor-oriented frames: rotate them upright (mirrored for the front camera).
    static func handleCameraFrame(_ pixelBuffer: CVPixelBuffer, front: Bool) {
        self.handleCameraFrame(pixelBuffer, orientation: front ? .leftMirrored : .right)
    }

    /// Every camera frame while the round video camera is open, with the rotation that makes it upright.
    static func handleCameraFrame(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        self.sinkLock.lock()
        guard let sink = self.sink else {
            self.sinkLock.unlock()
            return
        }
        let effect = self.current
        if effect == .off {
            let wasShowing = self.previewShowing
            self.previewShowing = false
            self.sinkLock.unlock()
            if wasShowing {
                DispatchQueue.main.async {
                    sink(nil)
                }
            }
            return
        }
        if self.previewBusy {
            self.sinkLock.unlock()
            return
        }
        self.previewBusy = true
        self.sinkLock.unlock()

        self.previewQueue.async {
            let image = self.previewRenderer.previewImage(pixelBuffer: pixelBuffer, orientation: orientation, side: 400.0, effect: effect)
            self.sinkLock.lock()
            self.previewBusy = false
            self.previewShowing = image != nil
            let currentSink = self.sink
            self.sinkLock.unlock()
            if let image, let currentSink {
                DispatchQueue.main.async {
                    currentSink(image)
                }
            }
        }
    }
}
