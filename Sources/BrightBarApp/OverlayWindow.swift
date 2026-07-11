import AppKit

final class OverlayWindow: NSWindow {
  let overlay: EDROverlayView

  init?(screen: NSScreen) {
    guard
      let overlay = EDROverlayView.make(
        frame: NSRect(origin: .zero, size: screen.frame.size)
      )
    else {
      return nil
    }

    self.overlay = overlay
    super.init(
      contentRect: screen.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )

    setFrame(screen.frame, display: false)
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
