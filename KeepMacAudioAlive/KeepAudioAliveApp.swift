import SwiftUI
import CoreAudio
import AVFoundation
internal import Combine

// MARK: - CoreAudio Engine
class AudioEngine: ObservableObject {
    @Published var isRunning = false
    @Published var devices: [AudioDevice] = []
    @Published var selectedDeviceUID: String? // We store UID for persistence
    
    private var ioProcID: AudioDeviceIOProcID?
    private var currentDeviceID: AudioDeviceID?
    
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
                // Get Name
                var name = getDeviceStringProperty(id: id, selector: kAudioObjectPropertyName)
                // Get UID (Persistent ID)
                var uid = getDeviceStringProperty(id: id, selector: kAudioDevicePropertyDeviceUID)
                
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
        
        // Auto-select if we have a saved UID and nothing is selected
        if let savedUID = selectedDeviceUID, let match = newDevices.first(where: { $0.uid == savedUID }) {
            // We found our saved device
        } else if selectedDeviceUID == nil, let first = newDevices.first {
            selectedDeviceUID = first.uid
        }
    }
    
    private func getDeviceStringProperty(id: AudioDeviceID, selector: AudioObjectPropertySelector) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var stringRef: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &stringRef)
        if status == noErr {
            return stringRef as String
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
            
            // Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(engine.isRunning ? .green : .secondary)
                    .font(.title2)
                Text("Audio Keep Alive")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            // Device Selector
            Picker("Device", selection: $engine.selectedDeviceUID) {
                ForEach(engine.devices) { device in
                    Text(device.name).tag(device.uid as String?)
                }
            }
            .labelsHidden()
            .frame(width: 220)
            .disabled(engine.isRunning)
            
            // Controls
            HStack {
                Button(action: { engine.start() }) {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                }
                .disabled(engine.isRunning || engine.selectedDeviceUID == nil)
                
                Button(action: { engine.stop() }) {
                    Text("Stop")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!engine.isRunning)
            }
            
            // Footer Status
            Text(engine.isRunning ? "Status: Active" : "Status: Inactive")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .padding(16)
        .fixedSize()
    }
}

// MARK: - App Entry Point
@main
struct AudioKeepAliveApp: App {
    // Create the engine ONCE here. It lives as long as the app is running.
    @StateObject var engine = AudioEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine) // Pass it down
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
