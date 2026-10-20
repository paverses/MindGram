import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import UndoUI
import MindGramCore

private enum ReportRow: Int32 {
    case statusHeader = 0
    // 1...: one status row per check
    case exportHeader = 100
    case copy = 101
    case sendToSaved = 102
    case sendToChat = 103
    case clearErrors = 104
    case footer = 105
}

/// Emits now and then every two seconds, so the counters on the screen stay current.
private func mindGramReportTicks() -> Signal<Void, NoError> {
    return Signal { subscriber in
        subscriber.putNext(Void())
        let timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: {
            subscriber.putNext(Void())
        }, queue: Queue.mainQueue())
        timer.start()
        return ActionDisposable {
            timer.invalidate()
        }
    }
}

/// Отчёт: what works and what doesn't, with exact errors; copy it or send it as a .txt file.
func mindGramReportController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?
    var presentImpl: ((ViewController) -> Void)?

    let showToast: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: 3.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
    }

    let send: (EnginePeer.Id, Bool) -> Void = { peerId, isSaved in
        let text = MindGramReport.text(context: context)
        guard let data = text.data(using: .utf8) else {
            MindGramLog.error("Отчёт", "Не удалось перевести отчёт в UTF-8")
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let fileName = "MindGram-\(build)-report-\(formatter.string(from: Date())).txt"

        let id = Int64.random(in: Int64.min ... Int64.max)
        let resource = LocalFileMediaResource(fileId: id, size: Int64(data.count), isSecretRelated: false)
        context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data)
        let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "text/plain", size: Int64(data.count), attributes: [.FileName(fileName: fileName)], alternativeRepresentations: [])
        let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
        let _ = (enqueueMessages(account: context.account, peerId: peerId, messages: [message])
        |> deliverOnMainQueue).startStandalone(next: { _ in
            showToast(isSaved ? "Отчёт отправлен в Избранное" : "Отчёт отправлен")
        })
    }

    let arguments = MindGramListArguments(open: { id in
        let checks = MindGramReport.checks(context: context)
        if id >= 1 && Int(id) <= checks.count {
            pushImpl?(mindGramReportCheckController(context: context, index: Int(id) - 1))
            return
        }
        switch ReportRow(rawValue: id) {
        case .copy:
            UIPasteboard.general.string = MindGramReport.text(context: context)
            showToast("Отчёт скопирован")
        case .sendToSaved:
            send(context.account.peerId, true)
        case .sendToChat:
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled], title: "Кому отправить отчёт"))
            controller.peerSelected = { [weak controller] peer, _ in
                controller?.dismiss()
                send(peer.id, peer.id == context.account.peerId)
            }
            pushImpl?(controller)
        case .clearErrors:
            MindGramLog.clear()
            showToast("Ошибки очищены")
        default:
            break
        }
    })

    let controller = mindGramListController(context: context, title: { $0.report }, arguments: arguments, extraUpdates: mindGramReportTicks(), entries: { _, strings in
        let checks = MindGramReport.checks(context: context)
        var entries: [MindGramListEntry] = []
        entries.append(.header(id: ReportRow.statusHeader.rawValue, section: 0, text: strings.reportStatusHeader))
        for (index, check) in checks.enumerated() {
            entries.append(.status(id: 1 + Int32(index), section: 0, title: check.title, value: check.status, tone: check.tone))
        }
        entries.append(.header(id: ReportRow.exportHeader.rawValue, section: 1, text: strings.reportExportHeader))
        entries.append(.action(id: ReportRow.copy.rawValue, section: 1, title: strings.reportCopy))
        entries.append(.action(id: ReportRow.sendToSaved.rawValue, section: 1, title: strings.reportSendToSaved))
        entries.append(.action(id: ReportRow.sendToChat.rawValue, section: 1, title: strings.reportSendToChat))
        if !MindGramLog.entries.isEmpty {
            entries.append(.action(id: ReportRow.clearErrors.rawValue, section: 1, title: strings.reportClearErrors))
        }
        entries.append(.footer(id: ReportRow.footer.rawValue, section: 1, text: strings.reportFooter))
        return entries
    })
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .current)
    }
    return controller
}

/// One check of the report: what it means in words, and the exact values in code.
private func mindGramReportCheckController(context: AccountContext, index: Int) -> ViewController {
    var presentImpl: ((ViewController) -> Void)?

    let arguments = MindGramListArguments(open: { id in
        guard id == 10 else {
            return
        }
        let checks = MindGramReport.checks(context: context)
        guard index < checks.count else {
            return
        }
        let check = checks[index]
        UIPasteboard.general.string = "\(check.title) — \(check.status)\nСловами: \(check.words)\nКод:\n\(check.code.joined(separator: "\n"))"
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: MindGramStrings(presentationData).copiedText, timeout: 2.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
    })

    let controller = mindGramListController(context: context, title: { _ in
        let checks = MindGramReport.checks(context: context)
        return index < checks.count ? checks[index].title : ""
    }, arguments: arguments, extraUpdates: mindGramReportTicks(), entries: { _, strings in
        let checks = MindGramReport.checks(context: context)
        guard index < checks.count else {
            return []
        }
        let check = checks[index]
        return [
            .status(id: 0, section: 0, title: strings.reportStatus, value: check.status, tone: check.tone),
            .header(id: 1, section: 1, text: strings.reportInWords),
            .text(id: 2, section: 1, text: check.words, monospace: false),
            .header(id: 3, section: 2, text: strings.reportInCode),
            .text(id: 4, section: 2, text: check.code.joined(separator: "\n"), monospace: true),
            .action(id: 10, section: 3, title: strings.reportCopy)
        ]
    })
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .current)
    }
    return controller
}
