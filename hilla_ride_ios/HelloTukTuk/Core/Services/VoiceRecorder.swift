import AVFoundation
import Foundation

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedMs = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        fileURL = url
        isRecording = true
        elapsedMs = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedMs += 100
            }
        }
    }

    func stopRecording() -> (url: URL, durationMs: Int)? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        defer {
            recorder = nil
        }
        guard let fileURL, elapsedMs >= 800 else {
            try? FileManager.default.removeItem(at: fileURL!)
            return nil
        }
        return (fileURL, elapsedMs)
    }

    func cancelRecording() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        recorder = nil
        self.fileURL = nil
        elapsedMs = 0
    }
}

@MainActor
final class VoicePlayer: ObservableObject {
    private var player: AVAudioPlayer?

    func play(data: Data) throws {
        stop()
        player = try AVAudioPlayer(data: data)
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
