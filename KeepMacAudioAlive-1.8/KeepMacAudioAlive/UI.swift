import SwiftUI

@main
struct AudioKeepAliveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Create the engine ONCE here. It lives as long as the app is running.
    @StateObject var engine = AudioEngine()
    
    var body: some Scene {
        MenuBarExtra {
            HStack{Button(action: {engine.isRunning ? engine.stop() : engine.start() } ) {
                Text (engine.isRunning ? "Stop" : "Start")
                    .frame (width: 50)
            }
                
                Picker("Device", selection: $engine.selectedDeviceUID) {
                    ForEach(engine.devices) { device in
                        Text (device.name).tag(device.uid as String?)
                    }
                }
                .frame (width: 180)
                .labelsHidden()
                .disabled(engine.isRunning)
                
                Button("Quit"){
                    NSApplication.shared.terminate(nil)
                }
                .frame (width: 50)
            }
            .padding(9)
        } label: {
            if engine.isRunning {
                Image(systemName: "waveform.circle.fill")
                    .padding(.horizontal, 8)
            } else {
                Image(systemName: "waveform.circle")
                    .padding(.horizontal, 8)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
