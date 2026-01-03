// Copied from prior version from above app


/*// MARK: - SwiftUI Interface
struct ContentView: View {
    
    // We use EnvironmentObject so we share the same engine instance across window re-opens
    @EnvironmentObject var engine: AudioEngine
    
    var body: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .foregroundColor(engine.isRunning ? .green : .secondary)
                .font(.title2)
            
            Button(action: {engine.isRunning ? engine.stop() : engine.start() } ) {
                Text (engine.isRunning ? "Stop" : "Start")
                    .frame (width: 50)
            }
            
            Picker("Device", selection: $engine.selectedDeviceUID) {
                ForEach(engine.devices) { device in
                    Text (device.name).tag(device.uid as String?)
                }
            }
            .labelsHidden()
            .frame (width: 170)
            .disabled(engine.isRunning)
        }
        .padding(16)
        .fixedSize()
    }
}*/

// MARK: - App Entry Point

