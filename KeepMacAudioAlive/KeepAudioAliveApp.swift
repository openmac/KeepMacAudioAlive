import SwiftUI
import AppKit
import CoreAudio
import AVFoundation
import ServiceManagement
internal import Combine

// MARK: - CoreAudio Engine
class AudioEngine: ObservableObject {
    @Published var isRunning = false
    @Published var devices: [AudioDevice] = []
    @Published var selectedDeviceUID: String? // We store UID for persistence
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    
    private var ioProcID: AudioDeviceIOProcID?
    private var currentDeviceID: AudioDeviceID?

    // Tracks whether the user wants audio kept alive, independent of whether it's
    // actually running right now (e.g. a Bluetooth dongle like the Creative BT-W6
    // can drop out and reconnect on its own). Only an explicit Stop clears this,
    // so a disconnect/reconnect cycle resumes automatically without undoing a
    // manual Stop.
    private var userWantsRunning: Bool {
        get { UserDefaults.standard.bool(forKey: "UserWantsRunning") }
        set { UserDefaults.standard.set(newValue, forKey: "UserWantsRunning") }
    }

    struct AudioDevice: Hashable, Identifiable {
        let id: AudioDeviceID
        let uid: String
        let name: String
    }

    init() {
        // Load saved device UID from UserDefaults
        self.selectedDeviceUID = UserDefaults.standard.string(forKey: "LastSelectedDeviceUID")

        refreshDevices()
        setupDeviceListener()
    }

    // MARK: - User-Facing Controls

    func userStart() {
        userWantsRunning = true
        start()
    }

    func userStop() {
        userWantsRunning = false
        stop()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            print("Failed to update launch-at-login: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Device Management
    
    func refreshDevices() {
        DispatchQueue.main.async {
            self._refreshDevicesInternal()
        }
    }
    
    private func _refreshDevicesInternal() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        
        var newDevices: [AudioDevice] = []
        
        for id in deviceIDs {
                    // Check for output streams
                    var outputStreamAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyStreams,
                        mScope: kAudioObjectPropertyScopeOutput,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    var streamSize: UInt32 = 0
                    AudioObjectGetPropertyDataSize(id, &outputStreamAddress, 0, nil, &streamSize)
                    
                    if streamSize > 0 {
                        // Get Name (Changed 'var' to 'let')
                        let name = getDeviceStringProperty(id: id, selector: kAudioObjectPropertyName)
                        // Get UID (Changed 'var' to 'let')
                        let uid = getDeviceStringProperty(id: id, selector: kAudioDevicePropertyDeviceUID)
                        
                        newDevices.append(AudioDevice(id: id, uid: uid, name: name))
                    }
                }
        
        self.devices = newDevices

        // Handle Disconnection Logic
        if isRunning, let currentID = currentDeviceID {
            // Check if our currently running device still exists in the new list
            let deviceStillExists = newDevices.contains { $0.id == currentID }
            if !deviceStillExists {
                print("Active device disconnected. Stopping.")
                stop()
            }
        }

        // Auto-select a default only when nothing has ever been chosen. Don't
        // overwrite an existing selection just because that device is
        // momentarily missing from the list (e.g. a Bluetooth device mid-reconnect)
        // — losing the selection here would prevent auto-resume once it comes back.
        if selectedDeviceUID == nil {
            selectedDeviceUID = newDevices.first?.uid
        }

        // Resume automatically if the user wants audio kept alive (e.g. the
        // Bluetooth dongle just reconnected) but it isn't running yet.
        if userWantsRunning && !isRunning {
            start()
        }
    }
    
    private func getDeviceStringProperty(id: AudioDeviceID, selector: AudioObjectPropertySelector) -> String {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            // 1. Use Unmanaged<CFString>? to handle the raw pointer safely
            var stringRef: Unmanaged<CFString>?
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            
            let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &stringRef)
            
            if status == noErr, let existingRef = stringRef {
                // 2. Take ownership of the retained value (CoreAudio gives us a +1 retain count)
                // This converts it to a standard Swift String and releases the CF reference correctly.
                return existingRef.takeRetainedValue() as String
            }
            
            return "Unknown"
        }
    // MARK: - Hardware Listener
    
    private func setupDeviceListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Pass 'self' as client data so the C callback can call our Swift method
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, hardwareListenerCallback, selfPointer)
    }
    
    private let renderCallback: AudioDeviceIOProc = { (inDevice, inNow, inInputData, inInputTime, outOutputData, inOutputTime, inClientData) -> OSStatus in
            
            // 1. Wrap the raw pointer in the Swift buffer list wrapper
            // This wrapper handles the iteration safely
            let bufferList = UnsafeMutableAudioBufferListPointer(outOutputData)
            
            // 2. Iterate through buffers
            for buffer in bufferList {
                // 3. Check if the memory pointer (mData) is not null and size is > 0
                if let dataPointer = buffer.mData, buffer.mDataByteSize > 0 {
                    memset(dataPointer, 0, Int(buffer.mDataByteSize))
                }
            }
            
            return noErr
        }
    
    func start() {
        guard let uid = selectedDeviceUID,
              let device = devices.first(where: { $0.uid == uid }) else { return }
        
        if isRunning { return }
        
        let deviceID = device.id
        
        let status = AudioDeviceCreateIOProcID(deviceID, renderCallback, nil, &ioProcID)
        if status != noErr { print("Error creating IOProc: \(status)"); return }
        
        let startStatus = AudioDeviceStart(deviceID, ioProcID)
        if startStatus != noErr { print("Error starting: \(startStatus)"); return }
        
        currentDeviceID = deviceID
        isRunning = true
        
        // Save preference
        UserDefaults.standard.set(uid, forKey: "LastSelectedDeviceUID")
    }
    
    func stop() {
        guard let deviceID = currentDeviceID, let procID = ioProcID else { return }
        
        AudioDeviceStop(deviceID, procID)
        AudioDeviceDestroyIOProcID(deviceID, procID)
        
        ioProcID = nil
        currentDeviceID = nil
        isRunning = false
    }
}

// C-Function for Hardware Listener
func hardwareListenerCallback(objectID: AudioObjectID,
                              numberAddresses: UInt32,
                              addresses: UnsafePointer<AudioObjectPropertyAddress>,
                              clientData: UnsafeMutableRawPointer?) -> OSStatus {
    if let clientData = clientData {
        let engine = Unmanaged<AudioEngine>.fromOpaque(clientData).takeUnretainedValue()
        engine.refreshDevices()
    }
    return noErr
}

// MARK: - SwiftUI Interface
struct ContentView: View {
    // We use EnvironmentObject so we share the same engine instance across window re-opens
    @EnvironmentObject var engine: AudioEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep Mac Audio Alive")
                .font(.headline)

            Picker("Device", selection: $engine.selectedDeviceUID) {
                ForEach(engine.devices) { device in
                    Text(device.name).tag(device.uid as String?)
                }
            }
            .labelsHidden()
            .disabled(engine.isRunning)

            Button(action: { engine.isRunning ? engine.userStop() : engine.userStart() }) {
                Text(engine.isRunning ? "Stop" : "Start")
                    .frame(maxWidth: .infinity)
            }

            Toggle("Launch at Login", isOn: Binding(
                get: { engine.launchAtLogin },
                set: { engine.setLaunchAtLogin($0) }
            ))

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 220)
    }
}

// MARK: - App Entry Point
@main
struct AudioKeepAliveApp: App {
    // Create the engine ONCE here. It lives as long as the app is running.
    @StateObject var engine = AudioEngine()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(engine) // Pass it down
        } label: {
            Image(systemName: engine.isRunning ? "waveform.circle.fill" : "waveform.circle")
        }
        .menuBarExtraStyle(.window)
    }
}
