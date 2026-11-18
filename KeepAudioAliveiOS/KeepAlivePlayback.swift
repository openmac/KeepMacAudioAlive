import AVFoundation
import Combine
import UIKit

@MainActor
final class KeepAlivePlayback: ObservableObject {
    @Published private(set) var outputName = "No audio output"
    @Published private(set) var message: String?
    @Published private var player: AVAudioPlayer?

    var isRunning: Bool { player != nil }

    private let session = AVAudioSession.sharedInstance()
    private var subscriptions = Set<AnyCancellable>()

    init() {
        refreshOutput()

        let notifications = NotificationCenter.default
        notifications.publisher(for: AVAudioSession.routeChangeNotification, object: session)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in self?.handleRouteChange(notification) }
            .store(in: &subscriptions)

        notifications.publisher(for: AVAudioSession.mediaServicesWereResetNotification, object: session)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.discardPlayback(message: "Audio services restarted. Tap Start to resume.")
                self?.refreshOutput()
            }
            .store(in: &subscriptions)

        notifications.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                if let player, !player.isPlaying {
                    stop()
                    message = "Playback stopped. Tap Start to resume."
                }
                refreshOutput()
            }
            .store(in: &subscriptions)

        observeInterruptions()
    }

    func start() {
        guard !isRunning else { return }
        guard let url = Bundle.main.url(forResource: "Silence", withExtension: "wav") else {
            message = "The silence audio file is missing from the app."
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)

            if player.play() {
                self.player = player
                message = nil
            } else {
                try? session.setActive(false)
                message = "Couldn’t start playback. Check the audio output and try again."
            }
        } catch {
            message = "Couldn’t start playback. \(error.localizedDescription)"
        }

        refreshOutput()
    }

    func stop() {
        guard let player else { return }
        player.stop()
        self.player = nil
        try? session.setActive(false)
        message = nil
    }

    private func refreshOutput() {
        let outputs = session.currentRoute.outputs.map(\.portName)
        outputName = outputs.isEmpty ? "No audio output" : outputs.joined(separator: ", ")
    }

    private func handleRouteChange(_ notification: Notification) {
        refreshOutput()
        guard isRunning,
              notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue,
              let previousRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey]
                as? AVAudioSessionRouteDescription,
              previousRoute.outputs.map(\.uid) != session.currentRoute.outputs.map(\.uid) else { return }

        stop()
        message = "The audio output disconnected. Tap Start to resume."
    }

    private func discardPlayback(message: String) {
        guard let player else { return }
        player.stop()
        self.player = nil
        self.message = message
    }

    private func observeInterruptions() {
        let notifications = NotificationCenter.default
        #if compiler(>=6.4)
        if #available(iOS 27, *) {
            notifications.publisher(for: AVAudioSession.didBecomeInactiveNotification, object: session)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    guard let context = notification.userInfo?[AVAudioSession.deactivationContextKey]
                            as? AVAudioSession.DeactivationContext,
                          context.source == .system else { return }
                    self?.discardPlayback(message: "Playback was interrupted. Tap Start to resume.")
                }
                .store(in: &subscriptions)
            return
        }
        #endif

        notifications.publisher(for: AVAudioSession.interruptionNotification, object: session)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                        == AVAudioSession.InterruptionType.began.rawValue else { return }
                self?.discardPlayback(message: "Playback was interrupted. Tap Start to resume.")
            }
            .store(in: &subscriptions)
    }
}
