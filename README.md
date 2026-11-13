# Klick

Klick plays mechanical keyboard sounds as you type on your Mac. Choose a switch, adjust the volume, or send typing sounds to a different audio output from the keyboard icon in the menu bar.

## Install

1. [Download Klick-macOS.zip](https://github.com/AdiArya05/klick/releases/latest/download/Klick-macOS.zip) for Apple silicon or Intel on macOS 14 or later.
2. If you have an older copy open, quit it from the menu bar. The app was previously called **Keyfeel**. Move the old Keyfeel app to the Trash before opening Klick. Unzip the download, move **Klick.app** to **Applications**, and choose **Replace** if asked. Open the copy in Applications.
3. If macOS blocks the first launch, dismiss the alert, then go to **System Settings → Privacy & Security → Open Anyway** for Klick and confirm **Open**. The ZIP is ad-hoc signed. [Apple’s first-launch instructions](https://support.apple.com/en-us/102445)
4. Click the keyboard icon in the menu bar. Under **Sound → Output**, choose your Mac’s built-in speakers if that’s where you want to hear the sound. Raise Klick’s **Volume** and press **▶** to test the selected output.
5. Choose **Enable Input Monitoring**, turn on Klick under **System Settings → Privacy & Security → Input Monitoring**, and reopen Klick if macOS prompts you. With **Typing sounds on**, type a few letters to test.

The preview button shows Pause while it plays. Click it again to stop the preview early. Klick stays quiet while an external keyboard is connected.

If the preview plays but typing is silent after replacing an older build, check Input Monitoring for the copy in **Applications**. If the permission is already on, remove that Klick entry, add the installed copy again, and reopen it. If the preview is silent too, check the selected **Output** and your Mac’s speaker volume.

Klick uses key events locally to trigger sounds and does not record what you type or send it over the network.

Drag the vertical Volume control to adjust loudness. Drag across the tone pad for warmth or brightness, and move up for more clack or down for more thock.

## Build from source

With Xcode or Xcode Command Line Tools installed, run:

```sh
./build.sh
```

This installs a build for the current Mac in `~/Applications`. To build a universal app in a separate directory, run `KEYFEEL_UNIVERSAL=1 ./build.sh ./dist/Klick.app`.

The downloadable build includes Cherry MX Red, Brown, and Blue, plus Topre Purple. The recordings come from [Mechvibes](https://github.com/hainguyents13/mechvibes/tree/56d7135bcdf6ceb7fe2f4e06f8ca0903277a9e68/soundpacks/keyboard) under the [included MIT license](Sounds/Mechvibes-LICENSE.txt).
