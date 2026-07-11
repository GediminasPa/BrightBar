import CoreGraphics

public enum DisplaySignature {
  public struct DisplayInfo: Equatable {
    public let id: Int
    public let frame: CGRect

    public init(id: Int, frame: CGRect) {
      self.id = id
      self.frame = frame
    }
  }

  public static func make(from displays: [DisplayInfo]) -> [String] {
    displays.map { display in
      let frame = display.frame
      return
        "\(display.id):\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width)),\(Int(frame.height))"
    }
  }
}
