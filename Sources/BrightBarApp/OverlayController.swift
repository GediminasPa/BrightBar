import AppKit
import BrightBarCore
import CoreGraphics

final class OverlayController {
  private(set) var isEnabled = false

  var boost: CGFloat = 1.4 {
    didSet {
      targetFactor = GammaMath.safeFactor(boost)
      if isEnabled { startAnimation() }
    }
  }

  var hasEDRDisplay: Bool {
    BoostMath.containsEDRDisplay(
      NSScreen.screens.map(\.maximumPotentialExtendedDynamicRangeColorComponentValue)
    )
  }

  var maximumPotentialHeadroom: CGFloat {
    BoostMath.maximumHeadroom(
      NSScreen.screens.map(\.maximumPotentialExtendedDynamicRangeColorComponentValue)
    )
  }

  private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
  private var gammaTables: [CGDirectDisplayID: GammaTable] = [:]
  private var appliedFactor: CGFloat = 1.0
  private var targetFactor: CGFloat = 1.0
  private var animationTimer: Timer?
  private var isDisabling = false
  private var displaySignature: [String] = []

  private let animationFPS = 60
  private let smoothing: CGFloat = 0.18
  private let snapThreshold: CGFloat = 0.002

  func primeDisplaySignature() {
    displaySignature = currentDisplaySignature()
  }

  func setEnabled(_ enabled: Bool) {
    guard enabled != isEnabled else { return }
    isEnabled = enabled

    if enabled {
      isDisabling = false
      buildResources()
      appliedFactor = 1.0
      targetFactor = GammaMath.safeFactor(boost)
      showTriggers()
      startAnimation()
    } else {
      isDisabling = true
      targetFactor = 1.0
      startAnimation()
    }
  }

  func handleScreenChange() {
    let nextSignature = currentDisplaySignature()
    let layoutChanged = nextSignature != displaySignature
    displaySignature = nextSignature

    guard isEnabled else { return }
    if layoutChanged {
      rebuildResources()
    } else {
      applyGammaFactor(appliedFactor)
    }
  }

  func reapplyAfterWake() {
    guard isEnabled else { return }
    showTriggers()
    appliedFactor = 1.0
    targetFactor = GammaMath.safeFactor(boost)
    startAnimation()
  }

  func resetImmediately() {
    stopAnimation()
    restoreDisplays()
    closeWindows()
    isEnabled = false
    isDisabling = false
    appliedFactor = 1.0
    targetFactor = 1.0
  }

  private func buildResources() {
    guard windows.isEmpty, gammaTables.isEmpty else { return }
    CGDisplayRestoreColorSyncSettings()

    for screen in NSScreen.screens
    where BoostMath.isEDRCapable(
      screen.maximumPotentialExtendedDynamicRangeColorComponentValue
    ) {
      guard let displayID = displayID(for: screen),
        let gammaTable = GammaTable.capture(displayID: displayID),
        let window = OverlayWindow(screen: screen)
      else {
        continue
      }

      gammaTables[displayID] = gammaTable
      windows[displayID] = window
    }
  }

  private func rebuildResources() {
    stopAnimation()
    restoreDisplays()
    closeWindows()
    buildResources()
    appliedFactor = 1.0
    targetFactor = GammaMath.safeFactor(boost)
    showTriggers()
    startAnimation()
  }

  private func showTriggers() {
    for window in windows.values {
      window.overlay.boost = 1.6
      window.overlay.draw()
      window.orderFrontRegardless()
    }
  }

  private func currentDisplaySignature() -> [String] {
    let displays = NSScreen.screens.map { screen -> DisplaySignature.DisplayInfo in
      DisplaySignature.DisplayInfo(
        id: Int(displayID(for: screen) ?? 0),
        frame: screen.frame
      )
    }
    return DisplaySignature.make(from: displays)
  }

  private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
  }

  private func startAnimation() {
    guard animationTimer == nil else { return }
    let timer = Timer(
      timeInterval: 1.0 / Double(animationFPS),
      repeats: true
    ) { [weak self] _ in
      self?.animationStep()
    }
    RunLoop.main.add(timer, forMode: .common)
    animationTimer = timer
  }

  private func animationStep() {
    let next = BoostMath.easeStep(
      applied: appliedFactor,
      target: targetFactor,
      smoothing: smoothing,
      snapThreshold: snapThreshold
    )
    appliedFactor = next.value
    applyGammaFactor(appliedFactor)

    if next.settled {
      finishAnimation()
    }
  }

  private func finishAnimation() {
    stopAnimation()
    guard isDisabling else { return }

    isDisabling = false
    restoreDisplays()
    closeWindows()
  }

  private func applyGammaFactor(_ factor: CGFloat) {
    for (displayID, table) in gammaTables {
      table.apply(displayID: displayID, factor: factor)
    }
  }

  private func restoreDisplays() {
    for (displayID, table) in gammaTables {
      table.apply(displayID: displayID, factor: 1.0)
    }
    gammaTables.removeAll()
    CGDisplayRestoreColorSyncSettings()
  }

  private func closeWindows() {
    for window in windows.values {
      window.orderOut(nil)
    }
    windows.removeAll()
  }

  private func stopAnimation() {
    animationTimer?.invalidate()
    animationTimer = nil
  }
}
