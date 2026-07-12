import CoreGraphics

public enum BrightnessLevel: Int, CaseIterable {
  case gentle = 0
  case brighter = 1
  case maximum = 2

  public var title: String {
    switch self {
    case .gentle: return "Gentle"
    case .brighter: return "Brighter"
    case .maximum: return "Maximum"
    }
  }

  public func boost(potentialHeadroom: CGFloat) -> CGFloat {
    switch self {
    case .gentle:
      return GammaMath.safeFactor(1.2)
    case .brighter:
      return GammaMath.safeFactor(1.4)
    case .maximum:
      return GammaMath.safeFactor(2.0)
    }
  }

  public static func restoring(_ rawValue: Int) -> BrightnessLevel {
    BrightnessLevel(rawValue: rawValue) ?? .brighter
  }
}
