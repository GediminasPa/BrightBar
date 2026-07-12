import CoreGraphics

public enum GammaMath {
  public static func safeFactor(_ factor: CGFloat) -> CGFloat {
    guard factor.isFinite else { return 1.0 }
    return min(max(factor, 1.0), 8.0)
  }

  public static func scaled<T: BinaryFloatingPoint>(
    _ values: [T],
    factor: CGFloat
  ) -> [T] {
    let safe = T(safeFactor(factor))
    return values.map { $0 * safe }
  }
}
