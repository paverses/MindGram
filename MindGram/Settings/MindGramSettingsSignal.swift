import Foundation
import SwiftSignalKit
import MindGramCore

/// Emits once immediately and again every time a MindGram setting changes.
public func mindGramSettingsUpdated() -> Signal<Void, NoError> {
    return Signal { subscriber in
        subscriber.putNext(Void())
        let observer = NotificationCenter.default.addObserver(forName: MindGramSettings.didChangeNotification, object: nil, queue: .main, using: { _ in
            subscriber.putNext(Void())
        })
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
