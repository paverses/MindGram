import Foundation
import UIKit
import UniformTypeIdentifiers
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import MindGramCore

enum MindGramSettingsArchive {
    private static let prefix = "MindGram."
    private static let maxFileSize = 2 * 1024 * 1024

    private static var directory: URL? {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("MindGram", isDirectory: true)
    }

    private static func encode(_ value: Any) -> Any? {
        switch value {
        case let value as Data:
            return ["__data": value.base64EncodedString()]
        case let value as Date:
            return ["__date": value.timeIntervalSince1970]
        case let value as [Any]:
            return value.compactMap { self.encode($0) }
        case let value as [String: Any]:
            var result: [String: Any] = [:]
            for (key, item) in value {
                if let item = self.encode(item) {
                    result[key] = item
                }
            }
            return result
        case is String, is NSNumber:
            return value
        default:
            return nil
        }
    }

    private static func decode(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            if dict.count == 1, let base64 = dict["__data"] as? String, let data = Data(base64Encoded: base64) {
                return data
            }
            if dict.count == 1, let interval = dict["__date"] as? Double {
                return Date(timeIntervalSince1970: interval)
            }
            return dict.mapValues { self.decode($0) }
        }
        if let array = value as? [Any] {
            return array.map { self.decode($0) }
        }
        return value
    }

    static func export() throws -> URL {
        var settings: [String: Any] = [:]
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() where key.hasPrefix(self.prefix) {
            if let encoded = self.encode(value) {
                settings[key] = encoded
            }
        }
        var files: [String: String] = [:]
        if let directory = self.directory, let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) {
            for url in urls where url.pathExtension == "json" {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                if size > 0 && size <= self.maxFileSize, let data = try? Data(contentsOf: url) {
                    files[url.lastPathComponent] = data.base64EncodedString()
                }
            }
        }
        let root: [String: Any] = [
            "format": "mindgram-settings",
            "version": 1,
            "date": Int(Date().timeIntervalSince1970),
            "settings": settings,
            "files": files
        ]
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MindGram-\(formatter.string(from: Date())).json")
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func importArchive(from url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url), data.count < 64 * 1024 * 1024, let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], root["format"] as? String == "mindgram-settings", let settings = root["settings"] as? [String: Any] else {
            return false
        }
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(self.prefix) {
            defaults.removeObject(forKey: key)
        }
        for (key, value) in settings where key.hasPrefix(self.prefix) {
            defaults.set(self.decode(value), forKey: key)
        }
        if let files = root["files"] as? [String: String], let directory = self.directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, base64) in files {
                let fileName = (name as NSString).lastPathComponent
                guard fileName.hasSuffix(".json"), let fileData = Data(base64Encoded: base64) else {
                    continue
                }
                try? fileData.write(to: directory.appendingPathComponent(fileName), options: .atomic)
            }
        }
        defaults.synchronize()
        return true
    }
}

private final class MindGramDocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let completion: (URL?) -> Void
    var retainedSelf: MindGramDocumentPickerDelegate?

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        super.init()
        self.retainedSelf = self
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.completion(urls.first)
        self.retainedSelf = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.completion(nil)
        self.retainedSelf = nil
    }
}

func mindGramSettingsExportController(context: AccountContext) -> ViewController {
    var presentImpl: ((ViewController) -> Void)?

    let topController: () -> UIViewController? = {
        var controller = context.sharedContext.mainWindow?.viewController as UIViewController?
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    let toast: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: 3.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
    }

    let arguments = MindGramListArguments(open: { id in
        let strings = MindGramStrings(context.sharedContext.currentPresentationData.with { $0 })
        if id == 1 {
            do {
                let url = try MindGramSettingsArchive.export()
                let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let view = topController()?.view {
                    activity.popoverPresentationController?.sourceView = view
                    activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1.0, height: 1.0)
                }
                topController()?.present(activity, animated: true)
            } catch {
                toast(strings.t("Не удалось сохранить настройки", "Couldn't save the settings"))
            }
        } else if id == 2 {
            let delegate = MindGramDocumentPickerDelegate(completion: { url in
                guard let url else {
                    return
                }
                if MindGramSettingsArchive.importArchive(from: url) {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    presentImpl?(textAlertController(context: context, title: strings.t("Настройки загружены", "Settings Imported"), text: strings.t("Перезапустите MindGram, чтобы применить их.", "Restart MindGram to apply them."), actions: [
                        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                        TextAlertAction(type: .defaultAction, title: strings.restartAction, action: {
                            exit(0)
                        })
                    ]))
                } else {
                    toast(strings.t("Это не файл настроек MindGram", "This isn't a MindGram settings file"))
                }
            })
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
            picker.delegate = delegate
            topController()?.present(picker, animated: true)
        }
    })

    let controller = mindGramListController(context: context, title: { $0.t("Экспорт", "Export") }, arguments: arguments, entries: { _, strings in
        return [
            .header(id: 0, section: 0, text: strings.t("НАСТРОЙКИ MINDGRAM", "MINDGRAM SETTINGS")),
            .action(id: 1, section: 0, title: strings.t("Экспорт", "Export")),
            .action(id: 2, section: 0, title: strings.t("Импорт", "Import")),
            .footer(id: 3, section: 0, text: strings.t("Все настройки сохраняются в файл JSON.", "All settings are saved to a JSON file."))
        ]
    })
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
