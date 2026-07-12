import AppKit

final class OverlayWindow: NSWindow {
  let overlay: EDROverlayView

  init?(screen: NSScreen) {
    let triggerFrame = NSRect(
      x: screen.frame.minX,
      y: screen.frame.minY,
      width: 1,
      height: 1
    )
    guard
      let overlay = EDROverlayView.make(
        frame: NSRect(origin: .zero, size: triggerFrame.size)
      )
    else {
      return nil
    }

    self.overlay = overlay
    super.init(
      contentRect: triggerFrame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )

    setFrame(triggerFrame, display: false)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    ignoresMouseEvents = true
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    sharingType = .none
    level = .screenSaver
    collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .ignoresCycle,
      .fullScreenAuxiliary,
    ]
    contentView = overlay
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}
