# Keyfeel

Keyfeel plays mechanical keyboard sounds as you type on your Mac. Choose a switch, adjust the volume, or send typing sounds to a different audio output from the keyboard icon in the menu bar.

## Install

1. Download **Keyfeel-macOS.zip** from the [latest release](https://github.com/AdiArya05/keyfeel/releases/latest).
2. Unzip it, move **Keyfeel.app** to Applications, and open it. The download supports Apple silicon and Intel Macs running macOS 14 or later.
3. If macOS blocks the first launch, the release is ad-hoc signed and has no Apple notarization. Apple documents the per-app **Open Anyway** option in [Privacy & Security](https://support.apple.com/en-us/102445).
4. In Keyfeel, choose **Enable Input Monitoring** and allow Keyfeel in System Settings. Reopen the app if macOS asks.

Use **Sound → Output** to select an output device for Keyfeel. **System Default** follows your Mac’s current audio output. Keyfeel uses key events locally to trigger sounds and does not record what you type or send it over the network.

Drag the vertical Volume control to adjust loudness. Drag across the tone pad for warmth or brightness, and move up for more clack or down for more thock.

## Build from source

With Xcode or Xcode Command Line Tools installed, run:

```sh
./build.sh
```

This installs a build for the current Mac in `~/Applications`. To build a universal app in a separate directory, run `KEYFEEL_UNIVERSAL=1 ./build.sh ./dist/Keyfeel.app`.

The downloadable build includes Cherry MX Red, Brown, and Blue, plus Topre Purple. The recordings come from [Mechvibes](https://github.com/hainguyents13/mechvibes/tree/56d7135bcdf6ceb7fe2f4e06f8ca0903277a9e68/soundpacks/keyboard) under the [included MIT license](Sounds/Mechvibes-LICENSE.txt).
