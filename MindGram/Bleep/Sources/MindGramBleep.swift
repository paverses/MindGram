import Foundation
import AVFoundation
import Speech
import OpusBinding

/// «Запикивание мата» in voice messages and round videos.
public enum MindGramBleep {
    // MARK: Settings

    private static func bool(_ key: String, _ defaultValue: Bool) -> Bool {
        return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    private static func set(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: Notification.Name("MindGramSettingsDidChange"), object: nil)
    }

    public static var voiceEnabled: Bool {
        get { return self.bool("MindGram.bleep.voice", false) }
        set { self.set("MindGram.bleep.voice", newValue) }
    }

    public static var roundEnabled: Bool {
        get { return self.bool("MindGram.bleep.round", false) }
        set { self.set("MindGram.bleep.round", newValue) }
    }

    /// Beep (true) or silence (false).
    public static var usesBeep: Bool {
        get { return self.bool("MindGram.bleep.beep", true) }
        set { self.set("MindGram.bleep.beep", newValue) }
    }

    /// Extra words to hide, separated by commas or spaces.
    public static var customWords: String {
        get { return UserDefaults.standard.string(forKey: "MindGram.bleep.custom") ?? "" }
        set { self.set("MindGram.bleep.custom", newValue) }
    }

    // MARK: Words

    /// Russian swear-word roots (with the usual prefixes) and English ones.
    private static let patterns: [NSRegularExpression] = {
        let sources = [
            "^(вы|за|на|у|до|от|отъ|про|раз|разъ|въ|подъ|съ|об|объ|пере|при|недо|по)?(е|ё)б(а|у|ё|е|л|н|и|ы|ш|о|т|к)",
            "ху(й|е|ё|я|ю|и)",
            "пизд",
            "^бля",
            "^сук(а|и|у|ой|е|ин|и|ам|ами)?$",
            "^сучк|^сучар",
            "^муда(к|ч)|^мудил",
            "^пид(о|а)р",
            "^гандон|^гондон",
            "^залуп",
            "^дроч",
            "^шлюх|^шалав",
            "^хер(н|ов|а|ом|у|ня|ни)?",
            "^манд(а|у|ой|ы|ец|авош)",
            "fuck|shit|bitch|cunt|asshole|motherf|bastard|^dick|^cock|^whore|^slut"
        ]
        return sources.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    public static func isProfane(_ rawWord: String) -> Bool {
        let word = rawWord.lowercased().trimmingCharacters(in: CharacterSet.letters.inverted)
        if word.count < 2 {
            return false
        }
        let custom = self.customWords.lowercased().components(separatedBy: CharacterSet(charactersIn: ", \n")).filter { !$0.isEmpty }
        if custom.contains(where: { word.hasPrefix($0) }) {
            return true
        }
        let range = NSRange(word.startIndex..., in: word)
        return self.patterns.contains(where: { $0.firstMatch(in: word, options: [], range: range) != nil })
    }

    // MARK: Recognition

    /// Time ranges (seconds) of swear words in an audio file, from on-device speech recognition.
    static func profaneRanges(audioURL: URL, completion: @escaping ([ClosedRange<Double>]) -> Void) {
        let recognize = {
            let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
            guard let recognizer, recognizer.isAvailable else {
                completion([])
                return
            }
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            var finished = false
            recognizer.recognitionTask(with: request, resultHandler: { result, error in
                if finished {
                    return
                }
                if let result, result.isFinal {
                    finished = true
                    var ranges: [ClosedRange<Double>] = []
                    for segment in result.bestTranscription.segments where self.isProfane(segment.substring) {
                        let start = max(0.0, segment.timestamp - 0.06)
                        ranges.append(start ... segment.timestamp + max(segment.duration, 0.25) + 0.06)
                    }
                    completion(ranges)
                } else if error != nil {
                    finished = true
                    completion([])
                }
            })
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            recognize()
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                if status == .authorized {
                    recognize()
                } else {
                    completion([])
                }
            }
        default:
            completion([])
        }
    }

    /// Replaces `ranges` in mono/interleaved 16-bit samples with a 1 kHz beep or silence.
    static func bleep(samples: inout [Int16], sampleRate: Double, channels: Int, ranges: [ClosedRange<Double>]) {
        let frameCount = samples.count / max(1, channels)
        for range in ranges {
            let startFrame = max(0, Int(range.lowerBound * sampleRate))
            let endFrame = min(frameCount, Int(range.upperBound * sampleRate))
            guard startFrame < endFrame else {
                continue
            }
            for frame in startFrame ..< endFrame {
                var value: Int16 = 0
                if self.usesBeep {
                    // Short fades at the edges so the beep doesn't click.
                    let fade = min(1.0, Double(min(frame - startFrame, endFrame - frame)) / (sampleRate * 0.01))
                    value = Int16(sin(2.0 * Double.pi * 1000.0 * Double(frame) / sampleRate) * 9000.0 * fade)
                }
                for channel in 0 ..< channels {
                    samples[frame * channels + channel] = value
                }
            }
        }
    }

    private static let queue = DispatchQueue(label: "MindGram.bleep", qos: .userInitiated)

    private static func temporaryURL(_ ext: String) -> URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("mindgram-bleep-\(UUID().uuidString).\(ext)")
    }

    /// Writes 16-bit PCM to a WAV file for the recognizer.
    private static func writeWAV(samples: [Int16], sampleRate: Double, channels: Int, to url: URL) throws {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: AVAudioChannelCount(channels), interleaved: true), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count / channels)) else {
            throw NSError(domain: "MindGramBleep", code: 1)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count / channels)
        samples.withUnsafeBufferPointer { source in
            if let destination = buffer.int16ChannelData?[0], let base = source.baseAddress {
                destination.update(from: base, count: samples.count)
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatInt16, interleaved: true)
        try file.write(from: buffer)
    }

    // MARK: Voice messages

    /// An Ogg Opus voice message with swear words beeped; nil when there was nothing to change.
    public static func processVoice(_ data: Data, completion: @escaping (Data?) -> Void) {
        guard self.voiceEnabled else {
            completion(nil)
            return
        }
        self.queue.async {
            let oggURL = self.temporaryURL("ogg")
            let wavURL = self.temporaryURL("wav")
            defer {
                try? FileManager.default.removeItem(at: oggURL)
            }
            guard (try? data.write(to: oggURL)) != nil, let reader = OggOpusReader(path: oggURL.path) else {
                completion(nil)
                return
            }
            var samples: [Int16] = []
            var chunk = [Int16](repeating: 0, count: 5760)
            while true {
                let read = chunk.withUnsafeMutableBytes { reader.read($0.baseAddress!, bufSize: Int32(5760)) }
                if read <= 0 {
                    break
                }
                samples.append(contentsOf: chunk[0 ..< Int(read)])
            }
            guard !samples.isEmpty, (try? self.writeWAV(samples: samples, sampleRate: 48000.0, channels: 1, to: wavURL)) != nil else {
                completion(nil)
                return
            }
            self.profaneRanges(audioURL: wavURL, completion: { ranges in
                try? FileManager.default.removeItem(at: wavURL)
                guard !ranges.isEmpty else {
                    completion(nil)
                    return
                }
                self.queue.async {
                    var bleeped = samples
                    self.bleep(samples: &bleeped, sampleRate: 48000.0, channels: 1, ranges: ranges)
                    let item: TGDataItem = TGDataItem(data: Data())
                    let writer = TGOggOpusWriter()
                    guard writer.begin(with: item) else {
                        completion(nil)
                        return
                    }
                    let frame = 960
                    var offset = 0
                    while offset < bleeped.count {
                        let count = min(frame, bleeped.count - offset)
                        bleeped.withUnsafeMutableBufferPointer { buffer in
                            if let base = buffer.baseAddress {
                                let _ = writer.writeFrame(UnsafeMutableRawPointer(base.advanced(by: offset)).assumingMemoryBound(to: UInt8.self), frameByteCount: UInt(count * 2))
                            }
                        }
                        offset += count
                    }
                    let _ = writer.writeFrame(nil, frameByteCount: 0)
                    let result: Data = item.data()
                    completion(result.isEmpty ? nil : result)
                }
            })
        }
    }

    // MARK: Round videos

    /// Beeps swear words in round video files, in place. Calls back with whether any file changed.
    public static func processVideos(paths: [String], completion: @escaping (Bool) -> Void) {
        guard self.roundEnabled, !paths.isEmpty else {
            completion(false)
            return
        }
        var changed = false
        var remaining = paths
        func next() {
            guard let path = remaining.first else {
                DispatchQueue.main.async {
                    completion(changed)
                }
                return
            }
            remaining.removeFirst()
            self.processVideo(path: path, completion: { didChange in
                changed = changed || didChange
                next()
            })
        }
        next()
    }

    private static func processVideo(path: String, completion: @escaping (Bool) -> Void) {
        self.queue.async {
            let url = URL(fileURLWithPath: path)
            let asset = AVURLAsset(url: url)
            guard let audioTrack = asset.tracks(withMediaType: .audio).first, let videoTrack = asset.tracks(withMediaType: .video).first else {
                completion(false)
                return
            }
            // Decode the sound to 16-bit PCM.
            let sampleRate = 48000.0
            guard let reader = try? AVAssetReader(asset: asset) else {
                completion(false)
                return
            }
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ])
            reader.add(output)
            reader.startReading()
            var samples: [Int16] = []
            while let sampleBuffer = output.copyNextSampleBuffer() {
                if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                    let length = CMBlockBufferGetDataLength(blockBuffer)
                    var chunk = [Int16](repeating: 0, count: length / 2)
                    chunk.withUnsafeMutableBytes { bytes in
                        if let base = bytes.baseAddress {
                            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: base)
                        }
                    }
                    samples.append(contentsOf: chunk)
                }
            }
            let wavURL = self.temporaryURL("wav")
            guard !samples.isEmpty, (try? self.writeWAV(samples: samples, sampleRate: sampleRate, channels: 1, to: wavURL)) != nil else {
                completion(false)
                return
            }
            self.profaneRanges(audioURL: wavURL, completion: { ranges in
                guard !ranges.isEmpty else {
                    try? FileManager.default.removeItem(at: wavURL)
                    completion(false)
                    return
                }
                self.queue.async {
                    var bleeped = samples
                    self.bleep(samples: &bleeped, sampleRate: sampleRate, channels: 1, ranges: ranges)
                    let bleepedURL = self.temporaryURL("wav")
                    defer {
                        try? FileManager.default.removeItem(at: wavURL)
                        try? FileManager.default.removeItem(at: bleepedURL)
                    }
                    guard (try? self.writeWAV(samples: bleeped, sampleRate: sampleRate, channels: 1, to: bleepedURL)) != nil else {
                        completion(false)
                        return
                    }
                    // The same video with the new sound, re-encoded to the original file.
                    let composition = AVMutableComposition()
                    let bleepedAsset = AVURLAsset(url: bleepedURL)
                    guard let newAudio = bleepedAsset.tracks(withMediaType: .audio).first, let compositionVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid), let compositionAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                        completion(false)
                        return
                    }
                    let duration = asset.duration
                    do {
                        try compositionVideo.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
                        try compositionAudio.insertTimeRange(CMTimeRange(start: .zero, duration: min(duration, bleepedAsset.duration)), of: newAudio, at: .zero)
                    } catch {
                        completion(false)
                        return
                    }
                    compositionVideo.preferredTransform = videoTrack.preferredTransform
                    let outputURL = self.temporaryURL("mp4")
                    guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                        completion(false)
                        return
                    }
                    session.outputURL = outputURL
                    session.outputFileType = .mp4
                    session.exportAsynchronously {
                        guard session.status == .completed else {
                            completion(false)
                            return
                        }
                        do {
                            try FileManager.default.removeItem(at: url)
                            try FileManager.default.moveItem(at: outputURL, to: url)
                            completion(true)
                        } catch {
                            completion(false)
                        }
                    }
                }
            })
        }
    }
}
