# BrightBar

BrightBar is a small, free, open-source macOS menu-bar app that unlocks the Extended Dynamic Range (EDR) brightness headroom of compatible Liquid Retina XDR displays.

It gives you three boost levels—Gentle, Brighter, and Maximum—without changing gamma tables or bypassing macOS display protections. BrightBar uses Apple's public EDR/Metal rendering path, while macOS remains responsible for thermal and power limits.

## Requirements

- macOS 13 Ventura or newer
- A 14-inch or 16-inch Apple-silicon MacBook Pro with a Liquid Retina XDR display, or another EDR-capable display
- Apple Command Line Tools (`xcode-select --install`)

The 2019 Intel 16-inch MacBook Pro does not have a Liquid Retina XDR display and cannot gain extra brightness this way.

## Build and run

```bash
git clone https://github.com/GediminasPa/BrightBar.git
cd BrightBar
./scripts/build-app.sh
open dist/BrightBar.app
```

To install it in Applications:

```bash
./scripts/install.sh
```

Once running, click the sun icon in the macOS menu bar, choose a boost level, and select **Enable extra brightness**. For the strongest outdoor result, first set the normal macOS brightness to maximum.

BrightBar always starts with the boost switched off.

## How it works

BrightBar renders an invisible, click-through Metal layer in an extended-linear color space. The layer asks macOS for EDR headroom and multiply-blends the desktop uniformly. Brightness changes are eased and paced against the live headroom reported by macOS to reduce flashing and washed-out colors.

The app does not call private brightness APIs, alter display firmware, or disable thermal protections. Extra brightness still increases power use and heat, so it is best treated as an outdoor or short-term mode.

## Tests

```bash
swift run BrightBarTests
```

## Acknowledgements

The EDR overlay technique and safety-oriented pacing logic were adapted from [MaxNit](https://github.com/Solexec/MaxNit), released under the MIT License. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT
