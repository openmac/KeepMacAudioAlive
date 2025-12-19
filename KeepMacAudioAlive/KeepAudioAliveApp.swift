import SwiftUI
import CoreAudio
import AVFoundation
internal import Combine

// MARK: - CoreAudio Engine
// (Logic remains unchanged from previous version)
class AudioEngine: ObservableObject {
    @Published var isRunning = false
    @Published var devices: [AudioDevice] = []
    @Published var selectedDeviceID: AudioDeviceID?
    
    private var ioProcID: AudioDeviceIOProcID?
    
    struct AudioDevice: Hashable, Identifiable {
        let id: AudioDeviceID
        let name: String
    }
    
    init() {
        refreshDevices()
    }
    
    func refreshDevices() {
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
            var outputStreamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &outputStreamAddress, 0, nil, &streamSize)
            
            if streamSize > 0 {
                var nameAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioObjectPropertyName,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var name: CFString = "" as CFString
                var nameSize = UInt32(MemoryLayout<CFString>.size)
                AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name)
                
                newDevices.append(AudioDevice(id: id, name: name as String))
            }
        }
        
        self.devices = newDevices
        if selectedDeviceID == nil, let first = newDevices.first {
            selectedDeviceID = first.id
        }
    }
    
    private let renderCallback: AudioDeviceIOProc = { (inDevice, inNow, inInputData, inInputTime, outOutputData, inOutputTime, inClientData) -> OSStatus in
        let bufferList = UnsafeMutableAudioBufferListPointer(outOutputData)
        for buffer in bufferList {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
        return noErr
    }
    
    func start() {
        guard let deviceID = selectedDeviceID else { return }
        if isRunning { return }
        
        let status = AudioDeviceCreateIOProcID(deviceID, renderCallback, nil, &ioProcID)
        if status != noErr { return }
        
        let startStatus = AudioDeviceStart(deviceID, ioProcID)
        if startStatus != noErr { return }
        
        isRunning = true
    }
    
    func stop() {
        guard let deviceID = selectedDeviceID, let procID = ioProcID else { return }
        AudioDeviceStop(deviceID, procID)
        AudioDeviceDestroyIOProcID(deviceID, procID)
        ioProcID = nil
        isRunning = false
    }
}

// MARK: - Compact SwiftUI Interface
struct ContentView: View {
    @StateObject var engine = AudioEngine()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(engine.isRunning ? .green : .secondary)
                Text("Audio Keep Alive")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            // Device Selector
            Picker("Device", selection: $engine.selectedDeviceID) {
                ForEach(engine.devices) { device in
                    Text(device.name).tag(device.id as AudioDeviceID?)
                }
            }
            .labelsHidden() // Hide the label to save space, the context is clear
            .frame(width: 220) // Fixed width for the dropdown to prevent window jumping
            .disabled(engine.isRunning)
            
            // Controls
            HStack {
                Button(action: { engine.start() }) {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                }
                .disabled(engine.isRunning || engine.selectedDeviceID == nil)
                
                Button(action: { engine.stop() }) {
                    Text("Stop")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!engine.isRunning)
            }
            
            // Footer Status
            Text(engine.isRunning ? "Status: Active (Sending Silence)" : "Status: Inactive")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .padding(16) // Reasonable padding around the edges
        .fixedSize() // Forces the view to wrap its content tightly
    }
}

// MARK: - App Entry Point
@main
struct AudioKeepAliveApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // This removes the standard window title bar for a cleaner, smaller utility look
        .windowStyle(.hiddenTitleBar)
        // This ensures the window snaps to the size of the ContentView (macOS 13+)
        .windowResizability(.contentSize)
    }
}
