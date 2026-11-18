import SwiftUI

@main
struct KeepAudioAliveApp: App {
    @StateObject private var playback = KeepAlivePlayback()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Form {
                    Section {
                        LabeledContent("Output", value: playback.outputName)
                        Label(
                            playback.isRunning ? "Running" : "Stopped",
                            systemImage: playback.isRunning ? "waveform.circle.fill" : "waveform.circle"
                        )
                        Button(playback.isRunning ? "Stop" : "Start") {
                            if playback.isRunning {
                                playback.stop()
                            } else {
                                playback.start()
                            }
                        }
                    } footer: {
                        Text("Sends silence to the current audio output to keep compatible DACs awake.")
                    }

                    if let message = playback.message {
                        Section {
                            Text(message)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Keep Audio Alive")
            }
        }
    }
}
