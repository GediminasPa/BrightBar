import AppKit
import Metal
import MetalKit
import QuartzCore

final class EDROverlayView: MTKView, MTKViewDelegate {
  var boost: CGFloat = 1.6 {
    didSet {
      clearColor = MTLClearColor(
        red: Double(boost),
        green: Double(boost),
        blue: Double(boost),
        alpha: 1.0
      )
      draw()
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

    autoResizeDrawable = false
    drawableSize = CGSize(width: 1, height: 1)
    colorPixelFormat = .rgba16Float
    colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
    framebufferOnly = true
    wantsLayer = true

    if let metalLayer = layer as? CAMetalLayer {
      metalLayer.wantsExtendedDynamicRangeContent = true
      metalLayer.isOpaque = false
      metalLayer.backgroundColor = CGColor(
        red: 1.0,
        green: 1.0,
        blue: 1.0,
        alpha: 1.0
      )
      metalLayer.pixelFormat = .rgba16Float
    }

    preferredFramesPerSecond = 5
    enableSetNeedsDisplay = false
    isPaused = false
    delegate = self
    boost = 1.6
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
