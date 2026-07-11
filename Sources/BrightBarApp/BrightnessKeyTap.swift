import AppKit
import ApplicationServices
import BrightBarCore
import CoreGraphics

final class BrightnessKeyTap {
  var onEvent: ((BrightnessKeyEvent) -> Bool)?

  private(set) var isRunning = false
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?

  static func hasAccessibilityPermission(prompt: Bool) -> Bool {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [promptKey: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  @discardableResult
  func start(promptForPermission: Bool) -> Bool {
    guard Self.hasAccessibilityPermission(prompt: promptForPermission) else {
      return false
    }
    guard !isRunning else { return true }

    let callback: CGEventTapCallBack = { _, type, event, userInfo in
      guard let userInfo else {
        return Unmanaged.passUnretained(event)
      }
      let keyTap = Unmanaged<BrightnessKeyTap>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
      return keyTap.handle(type: type, event: event)
    }

    let mask =
      CGEventMask(1 << NX_SYSDEFINED)
      | CGEventMask(1 << CGEventType.keyDown.rawValue)
      | CGEventMask(1 << CGEventType.keyUp.rawValue)

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      ),
      let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    else {
      return false
    }

    self.eventTap = eventTap
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    isRunning = true
    return true
  }

  func stop() {
    guard isRunning else { return }
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
      CFRunLoopSourceInvalidate(source)
    }
    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      CFMachPortInvalidate(eventTap)
    }
    runLoopSource = nil
    eventTap = nil
    isRunning = false
  }

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return Unmanaged.passUnretained(event)
    }

    let parsedEvent: BrightnessKeyEvent?
    if type.rawValue == UInt32(NX_SYSDEFINED),
      let appKitEvent = NSEvent(cgEvent: event),
      appKitEvent.subtype.rawValue == 8
    {
      parsedEvent = BrightnessKeyEventParser.parseSystemDefined(data1: appKitEvent.data1)
    } else if type == .keyDown || type == .keyUp {
      parsedEvent = BrightnessKeyEventParser.parseFunctionKey(
        keyCode: event.getIntegerValueField(.keyboardEventKeycode),
        isPressed: type == .keyDown,
        isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
      )
    } else {
      parsedEvent = nil
    }

    guard let parsedEvent else {
      return Unmanaged.passUnretained(event)
    }

    let shouldConsume = onEvent?(parsedEvent) ?? false
    return shouldConsume ? nil : Unmanaged.passUnretained(event)
  }

  deinit {
    stop()
  }
}
