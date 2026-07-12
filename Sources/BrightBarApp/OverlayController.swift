import AppKit
import BrightBarCore
import CoreGraphics

final class OverlayController {
  private(set) var isEnabled = false
  var boost: CGFloat = 2.0 {
    didSet {
      guard !isDisabling else { return }
      targetBoost = boost
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

  private var windows: [OverlayWindow] = []
  private var appliedBoost: CGFloat = 1.0
  private var targetBoost: CGFloat = 1.0
  private var animationTimer: Timer?
  private var isDisabling = false
  private var engagementFrames = 0
  private var displaySignature: [String] = []

  private let animationFPS = 60
  private let idleFPS = 20
  private let smoothing: CGFloat = 0.18
  private let snapThreshold: CGFloat = 0.005
  private let engagementEpsilon: CGFloat = 0.001
  private let maximumEngagementFrames = 90

  func primeDisplaySignature() {
    displaySignature = currentDisplaySignature()
  }

  func setEnabled(_ enabled: Bool) {
    guard enabled != isEnabled else { return }
    isEnabled = enabled

    if enabled {
      isDisabling = false
      buildWindowsIfNeeded()
      appliedBoost = 1.0
      applyBoost()
      for window in windows {
        window.overlay.draw()
        window.orderFrontRegardless()
      }
      targetBoost = boost
      startAnimation()
    } else {
      isDisabling = true
      targetBoost = 1.0
      startAnimation()
    }
  }

  func handleScreenChange() {
    let nextSignature = currentDisplaySignature()
    let layoutChanged = nextSignature != displaySignature
    displaySignature = nextSignature

    guard isEnabled else { return }
    if layoutChanged {
      rebuildWindows()
    } else {
      applyBoost()
    }
  }

  func reapplyAfterWake() {
    guard isEnabled else { return }
    appliedBoost = 1.0
    targetBoost = boost
    for window in windows {
      window.orderFrontRegardless()
      window.overlay.draw()
    }
    startAnimation()
  }

  func resetImmediately() {
    stopAnimation()
    for window in windows {
      window.orderOut(nil)
    }
    windows.removeAll()
    CGDisplayRestoreColorSyncSettings()
    isEnabled = false
    isDisabling = false
    appliedBoost = 1.0
    targetBoost = 1.0
  }

  private func currentDisplaySignature() -> [String] {
    let displays = NSScreen.screens.map { screen -> DisplaySignature.DisplayInfo in
      let key = NSDeviceDescriptionKey("NSScreenNumber")
      let id = (screen.deviceDescription[key] as? NSNumber)?.intValue ?? 0
      return DisplaySignature.DisplayInfo(id: id, frame: screen.frame)
    }
    return DisplaySignature.make(from: displays)
  }

  private func buildWindowsIfNeeded() {
    guard windows.isEmpty else { return }
    windows = NSScreen.screens.compactMap { screen in
      guard
        BoostMath.isEDRCapable(
          screen.maximumPotentialExtendedDynamicRangeColorComponentValue
        )
      else {
        return nil
      }
      return OverlayWindow(screen: screen)
    }
  }

  private func rebuildWindows() {
    stopAnimation()
    for window in windows {
      window.orderOut(nil)
    }
    windows.removeAll()
    buildWindowsIfNeeded()
    appliedBoost = 1.0
    targetBoost = boost
    applyBoost()
    for window in windows {
      window.overlay.draw()
      window.orderFrontRegardless()
    }
    startAnimation()
  }

  private func startAnimation() {
    for window in windows {
      window.overlay.preferredFramesPerSecond = animationFPS
    }
    engagementFrames = 0
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
      applied: appliedBoost,
      target: targetBoost,
      smoothing: smoothing,
      snapThreshold: snapThreshold
    )
    appliedBoost = next.value
    let isStillEngaging = applyBoost()
    engagementFrames += 1

    if next.settled
      && (!isStillEngaging || engagementFrames >= maximumEngagementFrames)
    {
      finishAnimation()
    }
  }

  @discardableResult
  private func applyBoost() -> Bool {
    var isStillEngaging = false
    for window in windows {
      guard let screen = window.screen else { continue }
      let liveHeadroom = screen.maximumExtendedDynamicRangeColorComponentValue
      let presentedBoost = BoostMath.pacedBoost(
        appliedBoost,
        liveHeadroom: liveHeadroom
      )
      window.overlay.boost = presentedBoost
      if presentedBoost + engagementEpsilon < appliedBoost {
        isStillEngaging = true
      }
    }
    return isStillEngaging
  }

  private func finishAnimation() {
    stopAnimation()

    if isDisabling {
      isDisabling = false
      for window in windows {
        window.orderOut(nil)
      }
      windows.removeAll()
    } else {
      for window in windows {
        window.overlay.preferredFramesPerSecond = idleFPS
      }
    }
  }

  private func stopAnimation() {
    animationTimer?.invalidate()
    animationTimer = nil
  }
}
