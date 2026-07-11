import CoreGraphics

public enum BoostMath {
  public static let edrThreshold: CGFloat = 1.01
  public static let engageFraction: CGFloat = 0.10
  public static let engageMinimumLead: CGFloat = 0.05

  public struct EaseResult: Equatable {
    public let value: CGFloat
    public let settled: Bool
  }

  public static func clampedBoost(_ requested: CGFloat, ceiling: CGFloat) -> CGFloat {
    let safeRequested = requested.isFinite ? max(1.0, requested) : 1.0
    let safeCeiling = ceiling.isFinite ? max(1.0, ceiling) : 1.0
    return min(safeRequested, safeCeiling)
  }

  public static func pacedBoost(_ requested: CGFloat, liveHeadroom: CGFloat) -> CGFloat {
    let safeLive = liveHeadroom.isFinite ? max(1.0, liveHeadroom) : 1.0
    let engagementCeiling = max(
      safeLive + engageMinimumLead,
      safeLive * (1.0 + engageFraction)
    )
    return clampedBoost(requested, ceiling: engagementCeiling)
  }

  public static func easeStep(
    applied: CGFloat,
    target: CGFloat,
    smoothing: CGFloat,
    snapThreshold: CGFloat
  ) -> EaseResult {
    let difference = target - applied
    if abs(difference) < snapThreshold {
      return EaseResult(value: target, settled: true)
    }

    return EaseResult(
      value: applied + difference * smoothing,
      settled: false
    )
  }

  public static func maximumHeadroom(_ values: [CGFloat]) -> CGFloat {
    values.filter(\.isFinite).max() ?? 1.0
  }

  public static func isEDRCapable(_ value: CGFloat) -> Bool {
    value.isFinite && value > edrThreshold
  }

  public static func containsEDRDisplay(_ values: [CGFloat]) -> Bool {
    values.contains(where: isEDRCapable)
  }
}
