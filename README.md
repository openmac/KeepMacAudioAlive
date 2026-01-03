# Prelimanary anticipating current version is fully adopted.

# KeepMacAudioAlive
Keep Mac audio alive to prevent delays or pops with some DACs.

The app can be installed two ways: Downloading it or building it yourself.

## How to download and run
1. Download the app from [releases](https://github.com/openmac/KeepMacAudioAlive/releases).
2. Open the app. Click Done on the first prompt. 
3. Allow the app to run via Privacy & Security settings in macOS System Settings. 
4. Start the app and select the desired device from the list right of Start.  

   <img width="343" height="69" alt="Screenshot 2025-12-28 at 04 30 36" src="https://github.com/user-attachments/assets/f1a869cd-49ab-4047-80fc-3cfffadbbeec" />

   <img width="343" height="112" alt="Screenshot 2025-12-28 at 04 30 53" src="https://github.com/user-attachments/assets/151025de-2ab4-4318-b9b0-a227fe486259" />

   The selected device is shown when the list is closed and is identified by having a checkmark to the left of its name on the list.

   <img width="343" height="70" alt="Screenshot 2025-12-28 at 04 29 55" src="https://github.com/user-attachments/assets/0e0a647b-8249-4139-a270-c4fd6e307c1c" />

   <img width="343" height="88" alt="Screenshot 2025-12-28 at 04 30 11" src="https://github.com/user-attachments/assets/68110791-87fc-4e7b-8671-7448ada5b8c5" />

6. Click Start to have it begin sending silence to the selected device. This disables the choice of device, which is enabled again by clicking Stop.
   
   <img width="343" height="70" alt="Screenshot 2025-12-28 at 04 29 25" src="https://github.com/user-attachments/assets/bea5db0b-e8d1-445f-bb6b-170a0cf77dc9" />

   The selected device will be remembered on launch and the app will send silence right away the moment it is connected. It will always send silence on launch if the last selected device is available. If it is not, it will not send silence until another device is selected and Start is clicked or the last selected device is connected again.
   Note that when the logo is filled in, the app is sending silence and when it is empty, it is not. 

7. To launch at login, add this app to Login Items under Settings > General > Login Items & Extensions > Open at Login. As stated, when the last selected device is connected, it will send silence right away.

## How to build
If you want to build it yourself:
1. Download the source code from this repository.
2. Download and install Xcode.
3. Open KeepMacAudioAlive.xcodeproj on Xcode.
4. Set your own signing profile.
5. Build or Run.
6. Follow 4. through 6. for the download version.

## Credits
This app and even its icon were originally made using Gemini 3 Pro, so all credits to them for that, and use it at your own risk. The menubar UI was made by me/JIWIJ using LosslessSwitcher as inspiration and source of some code, particularly in the AppDelegate. 
