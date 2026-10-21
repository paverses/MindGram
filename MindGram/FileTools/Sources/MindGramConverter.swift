import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import MindGramShine

public enum MindGramConvertError: Error, CustomStringConvertible {
    case unreadable(String)
    case failed(String)

    public var description: String {
        switch self {
        case let .unreadable(text), let .failed(text):
            return text
        }
    }
}

/// Music tags the editor writes into a file.
public struct MindGramAudioTags {
    public var title: String
    public var artist: String
    /// JPEG data of the cover.
    public var artwork: Data?

    public init(title: String, artist: String, artwork: Data?) {
        self.title = title
        self.artist = artist
        self.artwork = artwork
    }

    /// Reads the tags a file already has.
    public static func read(from url: URL) -> MindGramAudioTags {
        let asset = AVURLAsset(url: url)
        var tags = MindGramAudioTags(title: "", artist: "", artwork: nil)
        for item in asset.commonMetadata {
            guard let key = item.commonKey else {
                continue
            }
            switch key {
            case .commonKeyTitle:
                tags.title = item.stringValue ?? tags.title
            case .commonKeyArtist:
                tags.artist = item.stringValue ?? tags.artist
            case .commonKeyArtwork:
                tags.artwork = item.dataValue ?? tags.artwork
            default:
                break
            }
        }
        return tags
    }
}

/// Converts files for the «Файл» editor. Every call runs off the main thread and completes on the main queue.
public enum MindGramConverter {
    private static let queue = DispatchQueue(label: "MindGram.converter", qos: .userInitiated)

    private static func finish(_ completion: @escaping (Result<URL, MindGramConvertError>) -> Void, _ result: Result<URL, MindGramConvertError>) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    // MARK: Audio

    /// `input` to `output` (format from its extension), with `tags` written into the result.
    public static func convertAudio(input: URL, output: URL, tags: MindGramAudioTags, completion: @escaping (Result<URL, MindGramConvertError>) -> Void) {
        let target = output.pathExtension.lowercased()
        let source = input.pathExtension.lowercased()
        self.queue.async {
            do {
                switch target {
                case "mp3":
                    var mp3: Data
                    if source == "mp3" {
                        mp3 = try Data(contentsOf: input)
                    } else {
                        mp3 = try self.encodeMP3(input: input, bitrate: MindGramFileTools.mp3Bitrate)
                    }
                    mp3 = self.replacingID3(in: mp3, tags: tags)
                    try mp3.write(to: output)
                    self.finish(completion, .success(output))
                case "m4a", "m4b", "m4r", "aac":
                    self.exportM4A(input: input, output: output, tags: tags, passthrough: source == "m4a" || source == "m4b" || source == "m4r", completion: completion)
                case "wav", "aiff", "aif", "caf":
                    try self.writePCM(input: input, output: output, bigEndian: target == "aiff" || target == "aif")
                    self.finish(completion, .success(output))
                default:
                    try FileManager.default.copyItem(at: input, to: output)
                    self.finish(completion, .success(output))
                }
            } catch let error as MindGramConvertError {
                self.finish(completion, .failure(error))
            } catch {
                self.finish(completion, .failure(.failed(error.localizedDescription)))
            }
        }
    }

    /// Decodes any audio iOS reads and encodes it to MP3 with Shine (44.1 kHz, mono or stereo).
    private static func encodeMP3(input: URL, bitrate: Int) throws -> Data {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: input)
        } catch {
            throw MindGramConvertError.unreadable("iOS не читает этот звук: \(error.localizedDescription)")
        }
        let channels = min(2, Int(file.processingFormat.channelCount))
        guard channels > 0, let outFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100.0, channels: AVAudioChannelCount(channels), interleaved: true), let converter = AVAudioConverter(from: file.processingFormat, to: outFormat), let inBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else {
            throw MindGramConvertError.failed("Не удалось подготовить конвертер звука")
        }

        var config = shine_config_t()
        shine_set_config_mpeg_defaults(&config.mpeg)
        config.wave.channels = channels == 1 ? PCM_MONO : PCM_STEREO
        config.wave.samplerate = 44100
        config.mpeg.bitr = Int32(bitrate)
        config.mpeg.mode = channels == 1 ? MONO : STEREO
        guard shine_check_config(44100, Int32(bitrate)) >= 0, let encoder = shine_initialise(&config) else {
            throw MindGramConvertError.failed("MP3: битрейт \(bitrate) не подходит")
        }
        defer {
            shine_close(encoder)
        }
        let samplesPerPass = Int(shine_samples_per_pass(encoder)) * channels

        var result = Data()
        var pending: [Int16] = []
        var endOfInput = false

        func encodePending(final: Bool) {
            var offset = 0
            while pending.count - offset >= samplesPerPass || (final && pending.count - offset > 0) {
                if pending.count - offset < samplesPerPass {
                    pending.append(contentsOf: [Int16](repeating: 0, count: samplesPerPass - (pending.count - offset)))
                }
                var written: Int32 = 0
                pending.withUnsafeMutableBufferPointer { buffer in
                    if let base = buffer.baseAddress, let data = shine_encode_buffer_interleaved(encoder, base.advanced(by: offset), &written), written > 0 {
                        result.append(data, count: Int(written))
                    }
                }
                offset += samplesPerPass
            }
            pending.removeFirst(min(offset, pending.count))
        }

        while true {
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: 4096) else {
                break
            }
            var conversionError: NSError?
            let status = converter.convert(to: outBuffer, error: &conversionError, withInputFrom: { packetCount, inputStatus in
                if endOfInput {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                do {
                    try file.read(into: inBuffer, frameCount: min(packetCount, 4096))
                } catch {
                    endOfInput = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                if inBuffer.frameLength == 0 {
                    endOfInput = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                return inBuffer
            })
            if outBuffer.frameLength > 0, let samples = outBuffer.int16ChannelData?[0] {
                pending.append(contentsOf: UnsafeBufferPointer(start: samples, count: Int(outBuffer.frameLength) * channels))
                encodePending(final: false)
            }
            if status == .error {
                throw MindGramConvertError.failed("Ошибка конвертации: \(conversionError?.localizedDescription ?? "?")")
            }
            if status == .endOfStream || (status == .inputRanDry && endOfInput) {
                break
            }
        }
        encodePending(final: true)
        var written: Int32 = 0
        if let data = shine_flush(encoder, &written), written > 0 {
            result.append(data, count: Int(written))
        }
        return result
    }

    /// Re-encodes into an M4A (AAC) file with the tags, or only rewrites tags when the source is M4A already.
    private static func exportM4A(input: URL, output: URL, tags: MindGramAudioTags, passthrough: Bool, completion: @escaping (Result<URL, MindGramConvertError>) -> Void) {
        let asset = AVURLAsset(url: input)
        guard let session = AVAssetExportSession(asset: asset, presetName: passthrough ? AVAssetExportPresetPassthrough : AVAssetExportPresetAppleM4A) else {
            self.finish(completion, .failure(.failed("iOS не может перекодировать этот файл в M4A")))
            return
        }
        session.outputURL = output
        session.outputFileType = .m4a
        session.metadata = self.metadataItems(tags)
        session.exportAsynchronously {
            if session.status == .completed {
                self.finish(completion, .success(output))
            } else {
                self.finish(completion, .failure(.failed("M4A: \(session.error?.localizedDescription ?? "ошибка экспорта")")))
            }
        }
    }

    private static func metadataItems(_ tags: MindGramAudioTags) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []
        if !tags.title.isEmpty {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierTitle
            item.value = tags.title as NSString
            items.append(item)
        }
        if !tags.artist.isEmpty {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierArtist
            item.value = tags.artist as NSString
            items.append(item)
        }
        if let artwork = tags.artwork {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierArtwork
            item.value = artwork as NSData
            item.dataType = kCMMetadataBaseDataType_JPEG as String
            items.append(item)
        }
        return items
    }

    /// Uncompressed 16-bit WAV / AIFF / CAF.
    private static func writePCM(input: URL, output: URL, bigEndian: Bool) throws {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: input)
        } catch {
            throw MindGramConvertError.unreadable("iOS не читает этот звук: \(error.localizedDescription)")
        }
        let format = file.processingFormat
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: bigEndian
        ]
        let out = try AVAudioFile(forWriting: output, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else {
            throw MindGramConvertError.failed("Не удалось выделить буфер")
        }
        while file.framePosition < file.length {
            try file.read(into: buffer)
            if buffer.frameLength == 0 {
                break
            }
            try out.write(from: buffer)
        }
    }

    /// An ID3v2.3 tag (title, artist, cover) in place of the MP3's own ID3v2 tag.
    static func replacingID3(in mp3: Data, tags: MindGramAudioTags) -> Data {
        var audio = mp3
        if audio.count > 10, audio[audio.startIndex] == 0x49, audio[audio.startIndex + 1] == 0x44, audio[audio.startIndex + 2] == 0x33 {
            let bytes = [UInt8](audio.prefix(10))
            let size = (Int(bytes[6]) << 21) | (Int(bytes[7]) << 14) | (Int(bytes[8]) << 7) | Int(bytes[9])
            let footer = (bytes[5] & 0x10) != 0 ? 10 : 0
            let total = min(audio.count, 10 + size + footer)
            audio = audio.subdata(in: audio.startIndex + total ..< audio.endIndex)
        }

        var frames = Data()
        func textFrame(_ id: String, _ text: String) {
            guard !text.isEmpty else {
                return
            }
            var body = Data([0x01, 0xFF, 0xFE])
            body.append(text.data(using: .utf16LittleEndian) ?? Data())
            frames.append(id.data(using: .ascii) ?? Data())
            frames.append(contentsOf: self.bigEndian32(body.count))
            frames.append(contentsOf: [0x00, 0x00])
            frames.append(body)
        }
        textFrame("TIT2", tags.title)
        textFrame("TPE1", tags.artist)
        if let artwork = tags.artwork {
            var body = Data([0x00])
            body.append("image/jpeg".data(using: .ascii) ?? Data())
            body.append(contentsOf: [0x00, 0x03, 0x00])
            body.append(artwork)
            frames.append("APIC".data(using: .ascii) ?? Data())
            frames.append(contentsOf: self.bigEndian32(body.count))
            frames.append(contentsOf: [0x00, 0x00])
            frames.append(body)
        }
        if frames.isEmpty {
            return audio
        }
        var tag = Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00])
        let size = frames.count
        tag.append(contentsOf: [UInt8((size >> 21) & 0x7F), UInt8((size >> 14) & 0x7F), UInt8((size >> 7) & 0x7F), UInt8(size & 0x7F)])
        tag.append(frames)
        tag.append(audio)
        return tag
    }

    private static func bigEndian32(_ value: Int) -> [UInt8] {
        return [UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    // MARK: Video

    /// MP4 / MOV re-encode, or only the sound as M4A.
    public static func convertVideo(input: URL, output: URL, completion: @escaping (Result<URL, MindGramConvertError>) -> Void) {
        let target = output.pathExtension.lowercased()
        let asset = AVURLAsset(url: input)
        let preset = target == "m4a" ? AVAssetExportPresetAppleM4A : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            self.finish(completion, .failure(.failed("iOS не может перекодировать это видео")))
            return
        }
        session.outputURL = output
        switch target {
        case "mov":
            session.outputFileType = .mov
        case "m4a":
            session.outputFileType = .m4a
        default:
            session.outputFileType = .mp4
        }
        session.shouldOptimizeForNetworkUse = true
        session.exportAsynchronously {
            if session.status == .completed {
                self.finish(completion, .success(output))
            } else {
                self.finish(completion, .failure(.failed("Видео: \(session.error?.localizedDescription ?? "ошибка экспорта")")))
            }
        }
    }

    // MARK: Images

    /// JPEG / PNG / HEIC.
    public static func convertImage(input: URL, output: URL, completion: @escaping (Result<URL, MindGramConvertError>) -> Void) {
        self.queue.async {
            let type: UTType
            switch output.pathExtension.lowercased() {
            case "png":
                type = .png
            case "heic", "heif":
                type = .heic
            default:
                type = .jpeg
            }
            guard let source = CGImageSourceCreateWithURL(input as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                self.finish(completion, .failure(.unreadable("iOS не читает эту картинку")))
                return
            }
            guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type.identifier as CFString, 1, nil) else {
                self.finish(completion, .failure(.failed("Этот формат картинки не поддерживается")))
                return
            }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            var options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.92]
            if let orientation = (properties as? [CFString: Any])?[kCGImagePropertyOrientation] {
                options[kCGImagePropertyOrientation] = orientation
            }
            CGImageDestinationAddImage(destination, image, options as CFDictionary)
            if CGImageDestinationFinalize(destination) {
                self.finish(completion, .success(output))
            } else {
                self.finish(completion, .failure(.failed("Не удалось сохранить картинку")))
            }
        }
    }
}
