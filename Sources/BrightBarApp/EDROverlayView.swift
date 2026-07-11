import AppKit
import Metal
import MetalKit
import QuartzCore

final class EDROverlayView: MTKView, MTKViewDelegate {
  var boost: CGFloat = 1.0 {
    didSet {
      clearColor = MTLClearColor(
        red: Double(boost),
        green: Double(boost),
        blue: Double(boost),
        alpha: 1.0
      )
    }
  }

  private let commandQueue: MTLCommandQueue

  static func make(frame: NSRect) -> EDROverlayView? {
    guard let device = MTLCreateSystemDefaultDevice(),
      let commandQueue = device.makeCommandQueue()
    else {
      return nil
    }

    return EDROverlayView(frame: frame, device: device, commandQueue: commandQueue)
  }

  private init(frame: NSRect, device: MTLDevice, commandQueue: MTLCommandQueue) {
    self.commandQueue = commandQueue
    super.init(frame: frame, device: device)

    colorPixelFormat = .rgba16Float
    colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
    framebufferOnly = true
    wantsLayer = true
    layer?.isOpaque = false
    layer?.compositingFilter = "multiply"
    (layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent = true

    preferredFramesPerSecond = 20
    enableSetNeedsDisplay = false
    isPaused = false
    delegate = self
    boost = 1.0
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    autoreleasepool {
      guard let renderPass = currentRenderPassDescriptor,
        let drawable = currentDrawable,
        let commandBuffer = commandQueue.makeCommandBuffer(),
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)
      else {
        return
      }

      encoder.endEncoding()
      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
  }
}
