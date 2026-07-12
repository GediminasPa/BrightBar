# BrightBar

BrightBar is a small, free, open-source macOS menu-bar app that unlocks the Extended Dynamic Range (EDR) brightness headroom of compatible Liquid Retina XDR displays.

It gives you three boost levels—Gentle, Brighter, and Maximum—with Maximum applying a 2× extended transfer factor. BrightBar uses Apple's public EDR/Metal rendering path, while macOS remains responsible for thermal and power limits.

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

Once running, click the sun icon in the macOS menu bar, choose a boost level, and select **Enable BrightBar**. The selected XDR boost engages immediately. F1 and F2 remain fully native and continue adjusting the Mac's underlying hardware brightness, with BrightBar's boost applied on top. No Accessibility or keyboard-monitoring permission is required.

BrightBar always starts with the boost switched off.

## How it works

BrightBar renders a one-pixel Metal trigger in an extended-linear color space to engage macOS's EDR headroom, then applies an extended display transfer curve to lift the whole desktop. Changes are eased to avoid a hard flash, and the original transfer table is restored whenever BrightBar is disabled or quits.

The app does not call private brightness APIs, alter display firmware, or disable thermal protections. Extra brightness still increases power use and heat, so it is best treated as an outdoor or short-term mode. Apps that also modify display gamma or color temperature may conflict with BrightBar while it is enabled.

## Tests

```bash
swift run BrightBarTests
```

## Acknowledgements

The original EDR overlay technique was adapted from [MaxNit](https://github.com/Solexec/MaxNit), released under the MIT License. The stronger gamma/EDR architecture was informed by the open-source [BrightIntosh](https://github.com/niklasr22/BrightIntosh) project. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT
