import BrightBarCore
import CoreGraphics

final class GammaTable {
  private static let capacity: UInt32 = 256

  private let red: [CGGammaValue]
  private let green: [CGGammaValue]
  private let blue: [CGGammaValue]
  private let sampleCount: UInt32

  private init(
    red: [CGGammaValue],
    green: [CGGammaValue],
    blue: [CGGammaValue],
    sampleCount: UInt32
  ) {
    self.red = red
    self.green = green
    self.blue = blue
    self.sampleCount = sampleCount
  }

  static func capture(displayID: CGDirectDisplayID) -> GammaTable? {
    var red = [CGGammaValue](repeating: 0, count: Int(capacity))
    var green = [CGGammaValue](repeating: 0, count: Int(capacity))
    var blue = [CGGammaValue](repeating: 0, count: Int(capacity))
    var sampleCount: UInt32 = 0

    let result = CGGetDisplayTransferByTable(
      displayID,
      capacity,
      &red,
      &green,
      &blue,
      &sampleCount
    )
    guard result == .success, sampleCount > 0 else { return nil }

    let count = Int(sampleCount)
    return GammaTable(
      red: Array(red.prefix(count)),
      green: Array(green.prefix(count)),
      blue: Array(blue.prefix(count)),
      sampleCount: sampleCount
    )
  }

  @discardableResult
  func apply(displayID: CGDirectDisplayID, factor: CGFloat) -> Bool {
    let safeFactor = GammaMath.safeFactor(factor)
    var adjustedRed = GammaMath.scaled(red, factor: safeFactor)
    var adjustedGreen = GammaMath.scaled(green, factor: safeFactor)
    var adjustedBlue = GammaMath.scaled(blue, factor: safeFactor)

    return CGSetDisplayTransferByTable(
      displayID,
      sampleCount,
      &adjustedRed,
      &adjustedGreen,
      &adjustedBlue
    ) == .success
  }
}
