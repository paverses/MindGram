import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import UndoUI
import MindGramCore

/// «Экспорт чата»: the last messages of a chat as a .txt, or as one self-contained .html — photos, videos and
/// voice messages embedded, replies as links, forwards, reactions, edits, date separators, search, dark theme.
enum MindGramChatExport {
    enum Format {
        case text
        case html
    }

    /// Loads up to `count` last messages (the view tracker fetches what is missing) and builds the file.
    static func export(context: AccountContext, peer: EnginePeer, count: Int, format: Format, completion: @escaping (URL?) -> Void) {
        let disposable = MetaDisposable()
        var latest: MessageHistoryView?
        var finished = false
        let finish: () -> Void = {
            if finished {
                return
            }
            finished = true
            disposable.dispose()
            let messages = (latest?.entries.map(\.message) ?? []).sorted(by: { $0.index < $1.index })
            DispatchQueue.global(qos: .userInitiated).async {
                let url = self.write(context: context, peer: peer, messages: messages, format: format)
                DispatchQueue.main.async {
                    completion(url)
                }
            }
        }
        disposable.set((context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peer.id, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: count, fixedCombinedReadStates: nil)
        |> deliverOnMainQueue).startStrict(next: { view, _, _ in
            latest = view
            if !view.isLoading && (!view.holeEarlier || view.entries.count >= count) {
                finish()
            }
        }))
        // Don't wait forever for the server: export what has loaded.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0, execute: {
            finish()
        })
    }

    private static func write(context: AccountContext, peer: EnginePeer, messages: [Message], format: Format) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let safeTitle = peer.compactDisplayTitle.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined(separator: "_")
        let name = "\(safeTitle.isEmpty ? "chat" : safeTitle)-\(dateFormatter.string(from: Date())).\(format == .html ? "html" : "txt")"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MindGramExport", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        // Written piece by piece: one string holding every embedded photo and video took hundreds of megabytes
        // and iOS closed the app.
        try? FileManager.default.removeItem(at: url)
        guard FileManager.default.createFile(atPath: url.path, contents: nil), let handle = try? FileHandle(forWritingTo: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }
        let output: (String) -> Void = { piece in
            if let data = piece.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        }
        switch format {
        case .text:
            output(self.text(context: context, peer: peer, messages: messages))
        case .html:
            self.html(context: context, peer: peer, messages: messages, output: output)
        }
        return url
    }

    // MARK: Pieces

    private static func authorName(_ message: Message, peer: EnginePeer) -> String {
        if let author = message.author {
            return EnginePeer(author).compactDisplayTitle
        }
        return peer.compactDisplayTitle
    }

    private static func mediaLabel(_ message: Message) -> String? {
        for media in message.media {
            if media is TelegramMediaImage {
                return "Фото"
            } else if let file = media as? TelegramMediaFile {
                if file.isVoice {
                    return "Голосовое"
                } else if file.isInstantVideo {
                    return "Кружок"
                } else if file.isSticker {
                    return "Стикер"
                } else if file.isAnimated {
                    return "GIF"
                } else if file.isVideo {
                    return "Видео"
                } else if file.isMusic {
                    return "Музыка"
                }
                return "Файл" + (file.fileName.map { " «\($0)»" } ?? "")
            } else if media is TelegramMediaPoll {
                return "Опрос"
            } else if media is TelegramMediaMap {
                return "Геопозиция"
            } else if media is TelegramMediaContact {
                return "Контакт"
            } else if media is TelegramMediaAction {
                return "Действие"
            }
        }
        return nil
    }

    private static func reactions(_ message: Message) -> [(String, Int32)] {
        guard let attribute = message.reactionsAttribute else {
            return []
        }
        return attribute.reactions.compactMap { reaction in
            switch reaction.value {
            case let .builtin(value):
                return (value, reaction.count)
            case .custom:
                return ("✨", reaction.count)
            case .stars:
                return ("⭐️", reaction.count)
            }
        }
    }

    private static func replyId(_ message: Message) -> MessageId? {
        for attribute in message.attributes {
            if let attribute = attribute as? ReplyMessageAttribute {
                return attribute.messageId
            }
        }
        return nil
    }

    private static func isEdited(_ message: Message) -> Bool {
        return message.attributes.contains(where: { $0 is EditedMessageAttribute })
    }

    private static func fullDate(_ timestamp: Int32) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    // MARK: Text

    private static func text(context: AccountContext, peer: EnginePeer, messages: [Message]) -> String {
        var lines: [String] = []
        lines.append("Чат: \(peer.compactDisplayTitle)")
        lines.append("Сообщений: \(messages.count) · экспорт \(self.fullDate(Int32(Date().timeIntervalSince1970))) · MindGram")
        lines.append("")
        let byId = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for message in messages {
            var head = "[\(self.fullDate(message.timestamp))] \(self.authorName(message, peer: peer))"
            if let forward = message.forwardInfo {
                head += " (переслано от \(forward.author.map { EnginePeer($0).compactDisplayTitle } ?? forward.authorSignature ?? "?"))"
            }
            lines.append(head + ":")
            if let replyId = self.replyId(message) {
                let replied = byId[replyId]
                let snippet = replied.map { String($0.text.prefix(60)) } ?? ""
                lines.append("  ↪ в ответ на «\(snippet)»")
            }
            if let media = self.mediaLabel(message) {
                lines.append("  [\(media)]")
            }
            if !message.text.isEmpty {
                lines.append(message.text.components(separatedBy: "\n").map { "  " + $0 }.joined(separator: "\n"))
            }
            let reactions = self.reactions(message)
            if !reactions.isEmpty {
                lines.append("  " + reactions.map { "\($0.0) \($0.1)" }.joined(separator: "  "))
            }
            if self.isEdited(message) {
                lines.append("  (изменено)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: HTML

    private static func escape(_ text: String) -> String {
        var result = text
        for (from, to) in [("&", "&amp;"), ("<", "&lt;"), (">", "&gt;"), ("\"", "&quot;")] {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }

    /// The message text with its formatting (bold, italic, code, links, spoilers) as HTML.
    private static func formattedHTML(_ message: Message) -> String {
        let text = message.text as NSString
        guard text.length > 0 else {
            return ""
        }
        var entities: [MessageTextEntity] = []
        for attribute in message.attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                entities = attribute.entities
            }
        }
        var boundaries = Set<Int>([0, text.length])
        for entity in entities {
            boundaries.insert(max(0, min(text.length, entity.range.lowerBound)))
            boundaries.insert(max(0, min(text.length, entity.range.upperBound)))
        }
        let points = boundaries.sorted()
        var html = ""
        for index in 0 ..< points.count - 1 {
            let start = points[index]
            let end = points[index + 1]
            guard end > start else {
                continue
            }
            var segment = self.escape(text.substring(with: NSRange(location: start, length: end - start)))
            for entity in entities where entity.range.lowerBound <= start && entity.range.upperBound >= end {
                switch entity.type {
                case .Bold:
                    segment = "<b>\(segment)</b>"
                case .Italic:
                    segment = "<i>\(segment)</i>"
                case .Underline:
                    segment = "<u>\(segment)</u>"
                case .Strikethrough:
                    segment = "<s>\(segment)</s>"
                case .Code:
                    segment = "<code>\(segment)</code>"
                case .Pre:
                    segment = "<pre>\(segment)</pre>"
                case .Spoiler:
                    segment = "<span class=\"spoiler\" onclick=\"this.classList.toggle('shown')\">\(segment)</span>"
                case let .TextUrl(url):
                    segment = "<a href=\"\(self.escape(url))\" target=\"_blank\">\(segment)</a>"
                case .Url:
                    let raw = text.substring(with: NSRange(location: start, length: end - start))
                    let link = raw.hasPrefix("http") ? raw : "https://\(raw)"
                    segment = "<a href=\"\(self.escape(link))\" target=\"_blank\">\(segment)</a>"
                default:
                    break
                }
            }
            html += segment
        }
        return html.replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func dataURI(path: String, mime: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }

    /// A downloaded photo, shrunk to 1280 px, as a data URI.
    private static func imageURI(path: String) -> String? {
        guard let image = UIImage(contentsOfFile: path) else {
            return nil
        }
        let maxSide: CGFloat = 1280.0
        let scale = min(1.0, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.75) else {
            return nil
        }
        return "data:image/jpeg;base64,\(data.base64EncodedString())"
    }

    private static func mediaHTML(context: AccountContext, message: Message, budget: inout Int) -> String {
        for media in message.media {
            if let image = media as? TelegramMediaImage {
                // The largest downloaded size.
                for representation in image.representations.reversed() {
                    if let path = context.engine.resources.completedResourcePath(id: EngineMediaResource.Id(representation.resource.id)), budget > 0, let uri = self.imageURI(path: path) {
                        budget -= uri.utf8.count
                        return "<img class=\"photo\" src=\"\(uri)\" loading=\"lazy\" onclick=\"window.open(this.src)\">"
                    }
                }
                return "<div class=\"media\">🖼 Фото (не скачано)</div>"
            } else if let file = media as? TelegramMediaFile {
                let size = file.size ?? 0
                let path = context.engine.resources.completedResourcePath(id: EngineMediaResource.Id(file.resource.id))
                if file.isVoice {
                    if let path, size < 4_000_000, budget > 0, let uri = self.dataURI(path: path, mime: "audio/ogg") {
                        budget -= uri.utf8.count
                        return "<div class=\"media\">🎤 Голосовое<br><audio controls src=\"\(uri)\"></audio></div>"
                    }
                    return "<div class=\"media\">🎤 Голосовое (не скачано)</div>"
                } else if file.isVideo || file.isInstantVideo || file.isAnimated {
                    let label = file.isInstantVideo ? "Кружок" : (file.isAnimated ? "GIF" : "Видео")
                    if let path, size < 8_000_000, budget > 0, let uri = self.dataURI(path: path, mime: file.mimeType.isEmpty ? "video/mp4" : file.mimeType) {
                        budget -= uri.utf8.count
                        let round = file.isInstantVideo ? " round" : ""
                        let loop = file.isAnimated ? " autoplay loop muted" : " controls"
                        return "<video class=\"video\(round)\" src=\"\(uri)\"\(loop) playsinline></video>"
                    }
                    if let thumb = file.previewRepresentations.last, let thumbPath = context.engine.resources.completedResourcePath(id: EngineMediaResource.Id(thumb.resource.id)), let uri = self.imageURI(path: thumbPath) {
                        return "<div class=\"media\"><img class=\"photo\" src=\"\(uri)\"><br>🎬 \(label) (не скачано)</div>"
                    }
                    return "<div class=\"media\">🎬 \(label) (не скачано)</div>"
                } else if file.isSticker {
                    var alt = "🖼"
                    for attribute in file.attributes {
                        if case let .Sticker(displayText, _, _) = attribute {
                            alt = displayText
                        }
                    }
                    return "<div class=\"sticker\">\(self.escape(alt))</div>"
                } else {
                    let name = file.fileName ?? "file"
                    return "<div class=\"media\">📎 \(self.escape(name)) · \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))</div>"
                }
            } else if let map = media as? TelegramMediaMap {
                return "<div class=\"media\">📍 <a href=\"https://maps.apple.com/?ll=\(map.latitude),\(map.longitude)\" target=\"_blank\">\(map.latitude), \(map.longitude)</a></div>"
            } else if let poll = media as? TelegramMediaPoll {
                let options = poll.options.map { "<li>\(self.escape($0.text))</li>" }.joined()
                return "<div class=\"media\">📊 \(self.escape(poll.text))<ul>\(options)</ul></div>"
            } else if let contact = media as? TelegramMediaContact {
                return "<div class=\"media\">👤 \(self.escape(contact.firstName + " " + contact.lastName)) · \(self.escape(contact.phoneNumber))</div>"
            }
        }
        return ""
    }

    private static func color(for id: Int64) -> String {
        let colors = ["#e17076", "#7bc862", "#e5ca77", "#65aadd", "#a695e7", "#ee7aae", "#6ec9cb", "#faa774"]
        return colors[Int(UInt64(bitPattern: id) % UInt64(colors.count))]
    }

    private static func html(context: AccountContext, peer: EnginePeer, messages: [Message], output: (String) -> Void) {
        let accountPeerId = context.account.peerId
        let byId = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Embedded media stops at about 60 MB of base64; later media are listed without the file.
        var budget = 60_000_000
        output(self.htmlHead(title: self.escape(peer.compactDisplayTitle), count: messages.count))
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d MMMM yyyy"
        dayFormatter.locale = Locale(identifier: "ru_RU")
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        var lastDay = ""
        for message in messages {
            autoreleasepool {
            let date = Date(timeIntervalSince1970: TimeInterval(message.timestamp))
            let day = dayFormatter.string(from: date)
            if day != lastDay {
                lastDay = day
                output("<div class=\"day\"><span>\(day)</span></div>\n")
            }
            let author = self.authorName(message, peer: peer)
            let authorId = message.author?.id.toInt64() ?? peer.id.toInt64()
            let outgoing = !message.effectivelyIncoming(accountPeerId)
            let initials = String(author.prefix(1)).uppercased()
            var bubble = ""
            if !outgoing || peer.id.namespace != Namespaces.Peer.CloudUser {
                bubble += "<div class=\"author\" style=\"color:\(self.color(for: authorId))\">\(self.escape(author))</div>"
            }
            if let forward = message.forwardInfo {
                let from = forward.author.map { EnginePeer($0).compactDisplayTitle } ?? forward.authorSignature ?? "?"
                bubble += "<div class=\"forward\">Переслано от <b>\(self.escape(from))</b></div>"
            }
            if let replyId = self.replyId(message) {
                if let replied = byId[replyId] {
                    let snippet = replied.text.isEmpty ? (self.mediaLabel(replied) ?? "") : String(replied.text.prefix(90))
                    bubble += "<a class=\"reply\" href=\"#m\(replyId.id)\" onclick=\"flash('m\(replyId.id)')\"><b>\(self.escape(self.authorName(replied, peer: peer)))</b><br>\(self.escape(snippet))</a>"
                } else {
                    bubble += "<div class=\"reply\">Ответ на сообщение вне экспорта</div>"
                }
            }
            bubble += self.mediaHTML(context: context, message: message, budget: &budget)
            let text = self.formattedHTML(message)
            if !text.isEmpty {
                bubble += "<div class=\"text\">\(text)</div>"
            }
            let reactions = self.reactions(message)
            if !reactions.isEmpty {
                bubble += "<div class=\"reactions\">" + reactions.map { "<span>\(self.escape($0.0)) \($0.1)</span>" }.joined() + "</div>"
            }
            bubble += "<div class=\"meta\">\(self.isEdited(message) ? "изменено · " : "")\(timeFormatter.string(from: date))</div>"
            let searchText = self.escape((author + " " + message.text).lowercased())
            output("<div class=\"row \(outgoing ? "out" : "in")\" id=\"m\(message.id.id)\" data-search=\"\(searchText)\"><div class=\"avatar\" style=\"background:\(self.color(for: authorId))\">\(self.escape(initials))</div><div class=\"bubble\">\(bubble)</div></div>\n")
            }
        }
        output(self.htmlTail)
    }

    private static func htmlHead(title: String, count: Int) -> String {
        return """
        <!DOCTYPE html>
        <html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(title) — MindGram</title>
        <style>
        :root{--bg:#e7ebf0;--bubble-in:#fff;--bubble-out:#e1ffc7;--text:#111;--muted:#6b7a8a;--accent:#3a8ee6;--bar:rgba(255,255,255,.85)}
        :root.dark{--bg:#0e1621;--bubble-in:#182533;--bubble-out:#2b5278;--text:#f2f4f7;--muted:#8a9aab;--accent:#64b5ef;--bar:rgba(23,33,43,.9)}
        @media (prefers-color-scheme:dark){:root:not(.light){--bg:#0e1621;--bubble-in:#182533;--bubble-out:#2b5278;--text:#f2f4f7;--muted:#8a9aab;--accent:#64b5ef;--bar:rgba(23,33,43,.9)}}
        *{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:15px/1.4 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
        header{position:sticky;top:0;z-index:5;background:var(--bar);backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px);padding:10px 14px;display:flex;gap:10px;align-items:center;border-bottom:1px solid rgba(127,127,127,.2)}
        header h1{font-size:17px;margin:0;flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}header small{color:var(--muted);font-weight:400}
        header input{flex:0 1 220px;border:0;border-radius:10px;padding:8px 10px;background:rgba(127,127,127,.15);color:var(--text);font-size:14px}
        header button{border:0;border-radius:10px;padding:8px 10px;background:rgba(127,127,127,.15);color:var(--text);cursor:pointer}
        main{max-width:760px;margin:0 auto;padding:10px 10px 40px}
        .day{text-align:center;margin:14px 0}.day span{background:rgba(0,0,0,.25);color:#fff;border-radius:12px;padding:3px 10px;font-size:13px}
        .row{display:flex;gap:8px;align-items:flex-end;margin:6px 0}.row.out{flex-direction:row-reverse}
        .avatar{width:34px;height:34px;border-radius:50%;color:#fff;display:flex;align-items:center;justify-content:center;font-weight:600;flex:none}
        .row.out .avatar{display:none}
        .bubble{max-width:78%;background:var(--bubble-in);border-radius:16px;padding:7px 10px 5px;box-shadow:0 1px 1px rgba(0,0,0,.08);word-wrap:break-word;overflow-wrap:anywhere}
        .row.out .bubble{background:var(--bubble-out)}
        .author{font-weight:600;font-size:14px;margin-bottom:2px}.forward{color:var(--accent);font-size:13px;margin-bottom:3px}
        .reply{display:block;border-left:3px solid var(--accent);padding:2px 8px;margin:2px 0 5px;font-size:13px;color:inherit;text-decoration:none;background:rgba(127,127,127,.1);border-radius:6px}
        .photo{max-width:100%;border-radius:12px;display:block;margin:2px 0;cursor:zoom-in}.video{max-width:100%;border-radius:12px;display:block}.video.round{width:240px;height:240px;border-radius:50%;object-fit:cover}
        .media{padding:4px 0}.sticker{font-size:64px;line-height:1}.text{white-space:normal}
        pre,code{font-family:ui-monospace,Menlo,monospace;background:rgba(127,127,127,.15);border-radius:6px;padding:1px 4px}pre{padding:8px;white-space:pre-wrap}
        a{color:var(--accent)}.spoiler{background:var(--muted);color:transparent;border-radius:4px;cursor:pointer}.spoiler.shown{background:none;color:inherit}
        .reactions{display:flex;flex-wrap:wrap;gap:4px;margin-top:4px}.reactions span{background:rgba(127,127,127,.18);border-radius:12px;padding:1px 8px;font-size:13px}
        .meta{text-align:right;color:var(--muted);font-size:12px;margin-top:2px}
        .flash .bubble{animation:flash 1.4s}@keyframes flash{0%,40%{box-shadow:0 0 0 3px var(--accent)}100%{box-shadow:0 1px 1px rgba(0,0,0,.08)}}
        .hidden{display:none}
        </style></head><body>
        <header><h1>\(title) <small>· \(count) сообщ.</small></h1><input id="q" placeholder="Поиск" oninput="search(this.value)"><button onclick="theme()">◐</button></header>
        <main>

        """
    }

    private static let htmlTail = """
        </main>
        <script>
        function search(q){q=q.trim().toLowerCase();document.querySelectorAll('.row').forEach(function(r){r.classList.toggle('hidden',q.length>0&&r.dataset.search.indexOf(q)<0)});document.querySelectorAll('.day').forEach(function(d){d.classList.toggle('hidden',q.length>0)})}
        function flash(id){var e=document.getElementById(id);if(!e)return;e.classList.remove('flash');void e.offsetWidth;e.classList.add('flash')}
        function theme(){var r=document.documentElement;var dark=r.classList.contains('dark')||(!r.classList.contains('light')&&matchMedia('(prefers-color-scheme: dark)').matches);r.classList.toggle('dark',!dark);r.classList.toggle('light',dark)}
        </script>
        <!-- Exported with MindGram -->
        </body></html>
        """
}

/// The export flow: format → how many messages → building → «В Избранное» or «Поделиться».
public func mindGramStartChatExport(context: AccountContext, peer: EnginePeer, present: @escaping (UIViewController) -> Void, presentInCurrent: @escaping (ViewController) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = MindGramStrings(presentationData)
    let toast: (String) -> Void = { text in
        presentInCurrent(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: 3.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
    }
    let deliver: (URL) -> Void = { url in
        let sheet = UIAlertController(title: url.lastPathComponent, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: strings.t("Отправить в Избранное", "Send to Saved Messages"), style: .default, handler: { _ in
            guard let data = try? Data(contentsOf: url) else {
                return
            }
            let id = Int64.random(in: Int64.min ... Int64.max)
            let resource = LocalFileMediaResource(fileId: id, size: Int64(data.count), isSecretRelated: false)
            context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data)
            let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: url.pathExtension == "html" ? "text/html" : "text/plain", size: Int64(data.count), attributes: [.FileName(fileName: url.lastPathComponent)], alternativeRepresentations: [])
            let _ = enqueueMessages(account: context.account, peerId: context.account.peerId, messages: [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).startStandalone()
            toast(strings.t("Экспорт отправлен в Избранное", "Export sent to Saved Messages"))
        }))
        sheet.addAction(UIAlertAction(title: strings.t("Поделиться…", "Share…"), style: .default, handler: { _ in
            present(UIActivityViewController(activityItems: [url], applicationActivities: nil))
        }))
        sheet.addAction(UIAlertAction(title: strings.t("Отмена", "Cancel"), style: .cancel))
        present(sheet)
    }
    let run: (MindGramChatExport.Format, Int) -> Void = { format, count in
        toast(strings.t("Собираю экспорт… медиа встраиваются только скачанные", "Building the export… only downloaded media are embedded"))
        MindGramChatExport.export(context: context, peer: peer, count: count, format: format, completion: { url in
            if let url {
                deliver(url)
            } else {
                toast(strings.t("Не удалось собрать экспорт", "Could not build the export"))
            }
        })
    }
    let chooseCount: (MindGramChatExport.Format) -> Void = { format in
        let sheet = UIAlertController(title: strings.t("Сколько сообщений", "How many messages"), message: nil, preferredStyle: .actionSheet)
        for count in [100, 500, 1000, 3000, 10000] {
            sheet.addAction(UIAlertAction(title: strings.t("Последние \(count)", "Last \(count)"), style: .default, handler: { _ in
                run(format, count)
            }))
        }
        sheet.addAction(UIAlertAction(title: strings.t("Отмена", "Cancel"), style: .cancel))
        present(sheet)
    }
    let sheet = UIAlertController(title: strings.t("Экспорт чата", "Export Chat"), message: peer.compactDisplayTitle, preferredStyle: .actionSheet)
    sheet.addAction(UIAlertAction(title: strings.t("HTML — с фото, видео, ответами и реакциями", "HTML — with photos, videos, replies and reactions"), style: .default, handler: { _ in
        chooseCount(.html)
    }))
    sheet.addAction(UIAlertAction(title: strings.t("TXT — только текст", "TXT — text only"), style: .default, handler: { _ in
        chooseCount(.text)
    }))
    sheet.addAction(UIAlertAction(title: strings.t("Отмена", "Cancel"), style: .cancel))
    present(sheet)
}
