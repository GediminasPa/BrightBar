import BrightBarCore
import CoreGraphics
import Darwin

private var failureCount = 0
private let accuracy: CGFloat = 0.000_001

private func check(
  _ condition: @autoclosure () -> Bool,
  _ name: String,
  file: StaticString = #fileID,
  line: UInt = #line
) {
  if condition() {
    print("PASS: \(name)")
  } else {
    failureCount += 1
    print("FAIL: \(name) [\(file):\(line)]")
  }
}

check(
  abs(BoostMath.clampedBoost(3.0, ceiling: 1.8) - 1.8) < accuracy,
  "Boost is capped to display headroom"
)
check(
  abs(BoostMath.clampedBoost(0.5, ceiling: 0.5) - 1.0) < accuracy,
  "Boost never darkens the display"
)
check(
  abs(BoostMath.clampedBoost(.nan, ceiling: 4.0) - 1.0) < accuracy,
  "Non-finite boost falls back to identity"
)
check(
  abs(BoostMath.clampedBoost(2.0, ceiling: .infinity) - 1.0) < accuracy,
  "Non-finite headroom falls back to identity"
)
check(
  abs(BoostMath.pacedBoost(4.0, liveHeadroom: 1.0) - 1.1) < accuracy,
  "Pacing stays near live headroom while EDR engages"
)
check(
  abs(BoostMath.pacedBoost(2.0, liveHeadroom: 2.0) - 2.0) < accuracy,
  "Pacing reaches target after EDR engages"
)

var easedValue: CGFloat = 1.0
let easedTarget: CGFloat = 2.0
var easingOvershot = false
for _ in 0..<100 {
  let result = BoostMath.easeStep(
    applied: easedValue,
    target: easedTarget,
    smoothing: 0.18,
    snapThreshold: 0.005
  )
  easedValue = result.value
  if easedValue > easedTarget { easingOvershot = true }
  if result.settled { break }
}
check(!easingOvershot, "Easing does not overshoot")
check(abs(easedValue - easedTarget) < accuracy, "Easing converges to its target")

check(!BoostMath.isEDRCapable(1.01), "EDR threshold is strict")
check(BoostMath.isEDRCapable(1.02), "EDR display is detected above threshold")

for headroom: CGFloat in [1.0, 1.4, 2.0, 4.0, 16.0] {
  let gentle = BrightnessLevel.gentle.boost(potentialHeadroom: headroom)
  let brighter = BrightnessLevel.brighter.boost(potentialHeadroom: headroom)
  let maximum = BrightnessLevel.maximum.boost(potentialHeadroom: headroom)
  check(gentle <= brighter && brighter <= maximum, "Levels stay ordered at \(headroom)x headroom")
}

check(
  BrightnessLevel.maximum.boost(potentialHeadroom: 3.5) == 3.5,
  "Maximum tracks headroom reported by macOS"
)
check(
  BrightnessLevel.restoring(100) == .brighter,
  "Invalid stored level restores the middle setting"
)

let signature = DisplaySignature.make(from: [
  DisplaySignature.DisplayInfo(
    id: 7,
    frame: CGRect(x: 0, y: 0, width: 1728, height: 1117)
  )
])
check(signature == ["7:0,0,1728,1117"], "Display signature captures ID and frame")

if failureCount > 0 {
  print("\n\(failureCount) test(s) failed.")
  exit(1)
}

print("\nAll BrightBar tests passed.")
