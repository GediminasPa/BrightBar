import AppKit
import BrightBarCore
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let controller = OverlayController()
  private let keyTap = BrightnessKeyTap()
  private let menu = NSMenu()

  private var statusItem: NSStatusItem!
  private var toggleItem: NSMenuItem!
  private var rangeItem: NSMenuItem!
  private var keyboardStatusItem: NSMenuItem!
  private var slider: NSSlider!

  private var level: BrightnessLevel = .brighter
  private var isFeatureEnabled = false
  private var extraProgress: CGFloat = 0.0
  private var normalRangeAtMaximum = true
  private var consumedKeyDowns: Set<BrightnessKey> = []
  private var permissionTimer: Timer?
  private var boundaryProbeCancellation = 0

  private let levelDefaultsKey = "BrightBar.level"
  private static let repositoryURL = "https://github.com/GediminasPa/BrightBar"

  func applicationDidFinishLaunching(_ notification: Notification) {
    if UserDefaults.standard.object(forKey: levelDefaultsKey) != nil {
      level = BrightnessLevel.restoring(
        UserDefaults.standard.integer(forKey: levelDefaultsKey)
      )
    }

    keyTap.onEvent = { [weak self] event in
      self?.handleBrightnessKey(event) ?? false
    }

    setupMenuBarItem()
    buildMenu()
    controller.primeDisplaySignature()
    registerObservers()
    updateInterface()
  }

  func applicationWillTerminate(_ notification: Notification) {
    permissionTimer?.invalidate()
    keyTap.stop()
  }

  private func setupMenuBarItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.menu = menu

    if let button = statusItem.button {
      button.image = statusIcon(enabled: false)
      button.image?.isTemplate = true
      button.toolTip = "BrightBar"
    }

    menu.delegate = self
  }

  private func buildMenu() {
    toggleItem = NSMenuItem(
      title: "Enable BrightBar",
      action: #selector(toggleBoost),
      keyEquivalent: ""
    )
    toggleItem.target = self
    menu.addItem(toggleItem)

    rangeItem = NSMenuItem(title: "XDR range: Off", action: nil, keyEquivalent: "")
    rangeItem.isEnabled = false
    menu.addItem(rangeItem)

    menu.addItem(.separator())
    menu.addItem(makeLevelControl())
    menu.addItem(.separator())

    keyboardStatusItem = NSMenuItem(
      title: "F1/F2 control activates with BrightBar",
      action: #selector(openAccessibilitySettings),
      keyEquivalent: ""
    )
    keyboardStatusItem.target = self
    keyboardStatusItem.isEnabled = false
    menu.addItem(keyboardStatusItem)

    let projectItem = NSMenuItem(
      title: "View BrightBar on GitHub",
      action: #selector(openRepository),
      keyEquivalent: ""
    )
    projectItem.target = self
    menu.addItem(projectItem)

    let quitItem = NSMenuItem(
      title: "Quit BrightBar",
      action: #selector(quit),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)
  }

  private func makeLevelControl() -> NSMenuItem {
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 76))

    let title = NSTextField(labelWithString: "Maximum XDR boost")
    title.frame = NSRect(x: 16, y: 52, width: 268, height: 16)
    title.font = .systemFont(ofSize: 11, weight: .medium)
    title.textColor = .secondaryLabelColor
    container.addSubview(title)

    slider = NSSlider(
      value: Double(level.rawValue),
      minValue: 0,
      maxValue: 2,
      target: self,
      action: #selector(levelChanged)
    )
    slider.frame = NSRect(x: 14, y: 27, width: 272, height: 20)
    slider.numberOfTickMarks = 3
    slider.allowsTickMarkValuesOnly = true
    slider.isContinuous = true
    container.addSubview(slider)

    let labels: [(String, NSRect, NSTextAlignment)] = [
      ("Gentle", NSRect(x: 12, y: 5, width: 88, height: 16), .left),
      ("Brighter", NSRect(x: 106, y: 5, width: 88, height: 16), .center),
      ("Maximum", NSRect(x: 200, y: 5, width: 88, height: 16), .right),
    ]

    for (text, frame, alignment) in labels {
      let label = NSTextField(labelWithString: text)
      label.frame = frame
      label.font = .systemFont(ofSize: 10)
      label.textColor = .secondaryLabelColor
      label.alignment = alignment
      container.addSubview(label)
    }

    let item = NSMenuItem()
    item.view = container
    return item
  }

  func menuWillOpen(_ menu: NSMenu) {
    if isFeatureEnabled, !keyTap.isRunning {
      _ = keyTap.start(promptForPermission: false)
    }
    updateInterface()
  }

  @objc private func toggleBoost() {
    if isFeatureEnabled {
      disableFeature()
      return
    }

    guard controller.hasEDRDisplay else {
      showUnsupportedDisplayAlert()
      return
    }

    isFeatureEnabled = true
    normalRangeAtMaximum = true
    setExtraProgress(1.0)

    if !keyTap.start(promptForPermission: true) {
      startPermissionMonitoring()
    }
    updateInterface()
  }

  private func disableFeature() {
    isFeatureEnabled = false
    boundaryProbeCancellation += 1
    consumedKeyDowns.removeAll()
    permissionTimer?.invalidate()
    permissionTimer = nil
    keyTap.stop()
    setExtraProgress(0.0)
    updateInterface()
  }

  @objc private func levelChanged() {
    level = BrightnessLevel.restoring(Int(slider.doubleValue.rounded()))
    UserDefaults.standard.set(level.rawValue, forKey: levelDefaultsKey)
    if isFeatureEnabled {
      setExtraProgress(extraProgress)
    }
  }

  private func handleBrightnessKey(_ event: BrightnessKeyEvent) -> Bool {
    guard isFeatureEnabled else { return false }

    if !event.isPressed {
      return consumedKeyDowns.remove(event.key) != nil
    }

    let shouldConsume: Bool
    switch event.key {
    case .down:
      boundaryProbeCancellation += 1
      if extraProgress > 0.000_1 {
        setExtraProgress(
          ExtendedBrightnessScale.step(progress: extraProgress, direction: .down)
        )
        shouldConsume = true
      } else {
        normalRangeAtMaximum = false
        shouldConsume = false
      }

    case .up:
      if extraProgress > 0.000_1 || normalRangeAtMaximum {
        setExtraProgress(
          ExtendedBrightnessScale.step(progress: extraProgress, direction: .up)
        )
        shouldConsume = true
      } else {
        probeForNormalMaximum(afterPassingUpKeyFrom: currentLiveHeadroom())
        shouldConsume = false
      }
    }

    if shouldConsume {
      consumedKeyDowns.insert(event.key)
    }
    return shouldConsume
  }

  private func probeForNormalMaximum(afterPassingUpKeyFrom headroomBefore: CGFloat) {
    let cancellation = boundaryProbeCancellation
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
      guard let self,
        self.isFeatureEnabled,
        self.extraProgress < 0.000_1,
        cancellation == self.boundaryProbeCancellation
      else { return }

      let headroomAfter = self.currentLiveHeadroom()
      if abs(headroomAfter - headroomBefore) < 0.002 {
        self.normalRangeAtMaximum = true
        self.setExtraProgress(
          ExtendedBrightnessScale.step(progress: 0.0, direction: .up)
        )
      }
    }
  }

  private func currentLiveHeadroom() -> CGFloat {
    let builtIn = NSScreen.screens.first { screen in
      let key = NSDeviceDescriptionKey("NSScreenNumber")
      guard let number = screen.deviceDescription[key] as? NSNumber else { return false }
      return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }
    return builtIn?.maximumExtendedDynamicRangeColorComponentValue ?? 1.0
  }

  private func setExtraProgress(_ progress: CGFloat) {
    extraProgress = min(max(progress, 0.0), 1.0)
    let maximumBoost = level.boost(
      potentialHeadroom: controller.maximumPotentialHeadroom
    )
    controller.boost = ExtendedBrightnessScale.boost(
      progress: extraProgress,
      maximumBoost: maximumBoost
    )

    if extraProgress > 0.000_1 {
      if !controller.isEnabled {
        controller.setEnabled(true)
      }
    } else if controller.isEnabled {
      controller.setEnabled(false)
    }

    updateInterface()
  }

  private func startPermissionMonitoring() {
    permissionTimer?.invalidate()
    let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
      guard let self, self.isFeatureEnabled else {
        timer.invalidate()
        return
      }
      if self.keyTap.start(promptForPermission: false) {
        timer.invalidate()
        self.permissionTimer = nil
        self.updateInterface()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    permissionTimer = timer
  }

  private func updateInterface() {
    guard toggleItem != nil else { return }

    toggleItem.state = isFeatureEnabled ? .on : .off
    toggleItem.title = isFeatureEnabled ? "BrightBar is on" : "Enable BrightBar"
    rangeItem.title =
      isFeatureEnabled
      ? "XDR range: \(Int((extraProgress * 100).rounded()))%"
      : "XDR range: Off"

    if !isFeatureEnabled {
      keyboardStatusItem.title = "F1/F2 control activates with BrightBar"
      keyboardStatusItem.isEnabled = false
    } else if keyTap.isRunning {
      keyboardStatusItem.title = "F1/F2 extended range is active"
      keyboardStatusItem.isEnabled = false
    } else {
      keyboardStatusItem.title = "Grant Accessibility for F1/F2…"
      keyboardStatusItem.isEnabled = true
    }

    statusItem.button?.image = statusIcon(enabled: isFeatureEnabled)
    statusItem.button?.image?.isTemplate = true
    slider?.doubleValue = Double(level.rawValue)
  }

  private func statusIcon(enabled: Bool) -> NSImage? {
    NSImage(
      systemSymbolName: enabled ? "sun.max.fill" : "sun.max",
      accessibilityDescription: enabled ? "BrightBar enabled" : "BrightBar disabled"
    )
  }

  private func registerObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenParametersChanged),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    for notification in [
      NSWorkspace.didWakeNotification,
      NSWorkspace.screensDidWakeNotification,
      NSWorkspace.activeSpaceDidChangeNotification,
      NSWorkspace.sessionDidBecomeActiveNotification,
    ] {
      workspaceCenter.addObserver(
        self,
        selector: #selector(reapplyAfterWake),
        name: notification,
        object: nil
      )
    }
  }

  @objc private func screenParametersChanged() {
    if isFeatureEnabled, extraProgress > 0.000_1 {
      setExtraProgress(extraProgress)
    }
    controller.handleScreenChange()
    updateInterface()
  }

  @objc private func reapplyAfterWake() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
      guard let self else { return }
      self.controller.reapplyAfterWake()
      if self.isFeatureEnabled, !self.keyTap.isRunning {
        _ = self.keyTap.start(promptForPermission: false)
      }
      self.updateInterface()
    }
  }

  private func showUnsupportedDisplayAlert() {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "No XDR display detected"
    alert.informativeText =
      "BrightBar requires a 14-inch or 16-inch Apple-silicon MacBook Pro with a Liquid Retina XDR display, or another EDR-capable display."
    alert.alertStyle = .informational
    alert.runModal()
  }

  @objc private func openAccessibilitySettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      )
    else { return }
    NSWorkspace.shared.open(url)
  }

  @objc private func openRepository() {
    guard let url = URL(string: Self.repositoryURL) else { return }
    NSWorkspace.shared.open(url)
  }

  @objc private func quit() {
    disableFeature()
    NSApp.terminate(nil)
  }
}
