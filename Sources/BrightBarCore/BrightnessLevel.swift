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
      return BoostMath.clampedBoost(1.3, ceiling: potentialHeadroom)
    case .brighter:
      return BoostMath.clampedBoost(1.8, ceiling: potentialHeadroom)
    case .maximum:
      return BoostMath.clampedBoost(.greatestFiniteMagnitude, ceiling: potentialHeadroom)
    }
  }

  public static func restoring(_ rawValue: Int) -> BrightnessLevel {
    BrightnessLevel(rawValue: rawValue) ?? .brighter
  }
}
