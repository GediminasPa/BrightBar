import CoreGraphics

public enum BrightnessKey: Hashable {
  case up
  case down
}

public struct BrightnessKeyEvent: Equatable {
  public let key: BrightnessKey
  public let isPressed: Bool
  public let isRepeat: Bool

  public init(key: BrightnessKey, isPressed: Bool, isRepeat: Bool) {
    self.key = key
    self.isPressed = isPressed
    self.isRepeat = isRepeat
  }
}

public enum BrightnessKeyEventParser {
  private static let mediaBrightnessUp = 2
  private static let mediaBrightnessDown = 3
  private static let functionBrightnessUp = 144
  private static let functionBrightnessDown = 145

  public static func parseSystemDefined(data1: Int) -> BrightnessKeyEvent? {
    let keyCode = (data1 & 0xFFFF_0000) >> 16
    let keyFlags = data1 & 0x0000_FFFF
    let keyState = (keyFlags & 0xFF00) >> 8

    let key: BrightnessKey
    switch keyCode {
    case mediaBrightnessUp:
      key = .up
    case mediaBrightnessDown:
      key = .down
    default:
      return nil
    }

    return BrightnessKeyEvent(
      key: key,
      isPressed: keyState == 0xA,
      isRepeat: (keyFlags & 0x1) == 0x1
    )
  }

  public static func parseFunctionKey(
    keyCode: Int64,
    isPressed: Bool,
    isRepeat: Bool
  ) -> BrightnessKeyEvent? {
    let key: BrightnessKey
    switch Int(keyCode) {
    case functionBrightnessUp:
      key = .up
    case functionBrightnessDown:
      key = .down
    default:
      return nil
    }

    return BrightnessKeyEvent(key: key, isPressed: isPressed, isRepeat: isRepeat)
  }
}

public enum ExtendedBrightnessScale {
  public static func boost(
    progress: CGFloat,
    maximumBoost: CGFloat
  ) -> CGFloat {
    let safeProgress = progress.isFinite ? min(max(progress, 0.0), 1.0) : 0.0
    let safeMaximum = maximumBoost.isFinite ? max(maximumBoost, 1.0) : 1.0
    return 1.0 + (safeMaximum - 1.0) * safeProgress
  }

  public static func step(
    progress: CGFloat,
    direction: BrightnessKey,
    stepCount: Int = 16
  ) -> CGFloat {
    let safeStepCount = max(stepCount, 1)
    let amount = 1.0 / CGFloat(safeStepCount)
    let delta = direction == .up ? amount : -amount
    return min(max(progress + delta, 0.0), 1.0)
  }
}
