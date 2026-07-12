import CoreGraphics

public enum BrightnessLevel: Int, CaseIterable {
  case one = 0
  case onePointFive = 1
  case two = 2
  case four = 3

  public var title: String {
    switch self {
    case .one: return "1×"
    case .onePointFive: return "1.5×"
    case .two: return "2×"
    case .four: return "4×"
    }
  }

  public func boost(potentialHeadroom: CGFloat) -> CGFloat {
    let requested: CGFloat
    switch self {
    case .one: requested = 1.0
    case .onePointFive: requested = 1.5
    case .two: requested = 2.0
    case .four: requested = 4.0
    }
    return BoostMath.clampedBoost(requested, ceiling: potentialHeadroom)
  }

  public static func restoring(_ rawValue: Int) -> BrightnessLevel {
    // Version 0.4 stored the removed 8× stop as raw value 4.
    if rawValue == 4 { return .four }
    return BrightnessLevel(rawValue: rawValue) ?? .two
  }
}
