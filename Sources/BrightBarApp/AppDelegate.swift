import AppKit
import BrightBarCore
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let controller = OverlayController()
  private let menu = NSMenu()
  private var statusItem: NSStatusItem!
  private var toggleItem: NSMenuItem!
  private var slider: NSSlider!
  private var level: BrightnessLevel = .four

  private let levelDefaultsKey = "BrightBar.level.v2"
  private let legacyLevelDefaultsKey = "BrightBar.level"
  private static let repositoryURL = "https://github.com/GediminasPa/BrightBar"

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Undo color-table changes left behind by BrightBar 0.3.x or another
    // interrupted gamma-based run. The EDR backend never modifies ColorSync.
    CGDisplayRestoreColorSyncSettings()

    if UserDefaults.standard.object(forKey: levelDefaultsKey) != nil {
      level = BrightnessLevel.restoring(
        UserDefaults.standard.integer(forKey: levelDefaultsKey)
      )
    } else if UserDefaults.standard.object(forKey: legacyLevelDefaultsKey) != nil {
      level = migratedLegacyLevel(
        UserDefaults.standard.integer(forKey: legacyLevelDefaultsKey)
      )
      UserDefaults.standard.set(level.rawValue, forKey: levelDefaultsKey)
    }

    setupMenuBarItem()
    buildMenu()
    controller.primeDisplaySignature()
    applySelectedLevel()
    registerObservers()
    updateInterface()
  }

  func applicationWillTerminate(_ notification: Notification) {
    controller.resetImmediately()
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

    menu.addItem(.separator())
    menu.addItem(makeLevelControl())
    menu.addItem(.separator())

    let keyboardNote = NSMenuItem(
      title: "F1/F2 remain controlled by macOS",
      action: nil,
      keyEquivalent: ""
    )
    keyboardNote.isEnabled = false
    menu.addItem(keyboardNote)

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

    let title = NSTextField(labelWithString: "EDR brightness request")
    title.frame = NSRect(x: 16, y: 52, width: 268, height: 16)
    title.font = .systemFont(ofSize: 11, weight: .medium)
    title.textColor = .secondaryLabelColor
    container.addSubview(title)

    slider = NSSlider(
      value: Double(level.rawValue),
      minValue: 0,
      maxValue: Double(BrightnessLevel.allCases.count - 1),
      target: self,
      action: #selector(levelChanged)
    )
    slider.frame = NSRect(x: 14, y: 27, width: 272, height: 20)
    slider.numberOfTickMarks = BrightnessLevel.allCases.count
    slider.allowsTickMarkValuesOnly = true
    slider.isContinuous = true
    container.addSubview(slider)

    let labelWidth: CGFloat = 52
    let labelSpacing = (268 - labelWidth)
      / CGFloat(max(1, BrightnessLevel.allCases.count - 1))
    for (index, brightnessLevel) in BrightnessLevel.allCases.enumerated() {
      let label = NSTextField(labelWithString: brightnessLevel.title)
      label.frame = NSRect(
        x: 16 + CGFloat(index) * labelSpacing,
        y: 5,
        width: labelWidth,
        height: 16
      )
      label.font = .systemFont(ofSize: 10)
      label.textColor = .secondaryLabelColor
      label.alignment = .center
      container.addSubview(label)
    }

    let item = NSMenuItem()
    item.view = container
    return item
  }

  func menuWillOpen(_ menu: NSMenu) {
    applySelectedLevel()
    updateInterface()
  }

  @objc private func toggleBoost() {
    if controller.isEnabled {
      controller.setEnabled(false)
      updateInterface()
      return
    }

    guard controller.hasEDRDisplay else {
      showUnsupportedDisplayAlert()
      return
    }

    applySelectedLevel()
    controller.setEnabled(true)
    updateInterface()
  }

  @objc private func levelChanged() {
    level = BrightnessLevel.restoring(Int(slider.doubleValue.rounded()))
    UserDefaults.standard.set(level.rawValue, forKey: levelDefaultsKey)
    applySelectedLevel()
  }

  private func migratedLegacyLevel(_ rawValue: Int) -> BrightnessLevel {
    switch rawValue {
    case 0: return .onePointFive
    case 1: return .two
    case 2: return .four
    default: return .two
    }
  }

  private func applySelectedLevel() {
    controller.boost = level.boost(
      potentialHeadroom: controller.maximumPotentialHeadroom
    )
  }

  private func updateInterface() {
    let enabled = controller.isEnabled
    toggleItem.state = enabled ? .on : .off
    toggleItem.title = enabled ? "BrightBar is on" : "Enable BrightBar"
    statusItem.button?.image = statusIcon(enabled: enabled)
    statusItem.button?.image?.isTemplate = true
    slider?.doubleValue = Double(level.rawValue)
  }

  private func statusIcon(enabled: Bool) -> NSImage? {
    guard
      let url = Bundle.module.url(forResource: "StatusIcon", withExtension: "png"),
      let source = NSImage(contentsOf: url),
      let image = source.copy() as? NSImage
    else {
      return NSImage(
        systemSymbolName: enabled ? "sun.max.fill" : "sun.max",
        accessibilityDescription: enabled ? "BrightBar enabled" : "BrightBar disabled"
      )
    }

    let sourceSize = image.size
    let scale = 18 / max(sourceSize.width, sourceSize.height)
    image.size = NSSize(
      width: sourceSize.width * scale,
      height: sourceSize.height * scale
    )
    image.isTemplate = true
    image.accessibilityDescription = enabled ? "BrightBar enabled" : "BrightBar disabled"
    return image
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
    applySelectedLevel()
    controller.handleScreenChange()
    updateInterface()
  }

  @objc private func reapplyAfterWake() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
      self?.controller.reapplyAfterWake()
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

  @objc private func openRepository() {
    guard let url = URL(string: Self.repositoryURL) else { return }
    NSWorkspace.shared.open(url)
  }

  @objc private func quit() {
    controller.resetImmediately()
    NSApp.terminate(nil)
  }
}
