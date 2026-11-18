# KeepMacAudioAlive
Keep Mac audio alive to prevent delays or pops with some DACs.

## How to use
1. Download the app from [releases](https://github.com/openmac/KeepMacAudioAlive/releases).
2. Allow the app to run via security settings on macOS settings, or build the app yourself using Xcode.
3. Open the app, it starts sending silence to the selected device automatically:
<img width="424" height="200" alt="appimage151" src="https://github.com/user-attachments/assets/92c47100-6bac-4640-918a-2b8b228b9b8e" />


4. You can stop and change it to another device then click Start again.

You can set this app to start at startup too (thanks to JIW's contributions).


## How to build
If you want to build it yourself:
1. Download the source code from this repository.
2. Download and install Xcode.
3. Open `KeepMacAudioAlive.xcodeproj` in Xcode and select the `KeepAudioAlive` scheme.
4. Set your own signing profile.
5. Build or Run.

## iPhone and iPad

1. Open `KeepMacAudioAlive.xcodeproj` in Xcode and select the `KeepAudioAliveiOS` scheme.
2. Select an iPhone or iPad running iOS or iPadOS 16 or later. Set your team under **Signing & Capabilities** for the `KeepAudioAliveiOS` target. If Xcode reports that the bundle identifier is unavailable, choose a unique one.
3. Run the app, connect your DAC, and confirm it is listed under **Output**. For wireless outputs, choose your device in Control Center.
4. Tap **Start** to send silence to the active output. The app mixes with other audio and requests background playback so it can keep running when you switch apps or lock the screen. Tap **Stop** to end the session. After an interruption, tap **Start** to resume. If your DAC disconnects, reconnect it before restarting playback.

Some DACs enter standby even while receiving digital silence. Test by pausing music, waiting for your DAC's usual standby interval, and resuming playback with Keep Audio Alive running. Distribution through the App Store is subject to [Apple’s background services guideline](https://developer.apple.com/app-store/review/guidelines/#software-requirements).

## Credits
This app and even its icon was made using Gemini 3 Pro, so all credits to them, and use it at your own risk.
