import Foundation
internal import TelegramApi
import Postbox
import SwiftSignalKit
import MindGramGhost
import MtProtoKit

private typealias SignalKitTimer = SwiftSignalKit.Timer


private final class AccountPresenceManagerImpl {
    private let queue: Queue
    private let network: Network
    let isPerformingUpdate = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var shouldKeepOnlinePresenceDisposable: Disposable?
    private let currentRequestDisposable = MetaDisposable()
    private var onlineTimer: SignalKitTimer?
    
    private var wasOnline: Bool = false
    private var mindGramGhostObserver: NSObjectProtocol?
    private var mindGramGhostHidesOnline = false
    
    init(queue: Queue, shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network) {
        self.queue = queue
        self.network = network
        self.mindGramGhostHidesOnline = MindGramGhost.applies(.hideOnline, peerId: nil)
        self.mindGramGhostObserver = NotificationCenter.default.addObserver(forName: MindGramGhost.didChangeNotification, object: nil, queue: nil, using: { [weak self] _ in
            queue.async {
                guard let self else {
                    return
                }
                let hidesOnline = MindGramGhost.applies(.hideOnline, peerId: nil)
                if self.mindGramGhostHidesOnline != hidesOnline {
                    self.mindGramGhostHidesOnline = hidesOnline
                    self.updatePresence(self.wasOnline)
                }
            }
        })
        
        self.shouldKeepOnlinePresenceDisposable = (shouldKeepOnlinePresence
        |> distinctUntilChanged
        |> deliverOn(self.queue)).start(next: { [weak self] value in
            guard let `self` = self else {
                return
            }
            if self.wasOnline != value {
                self.wasOnline = value
                self.updatePresence(value)
            }
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.shouldKeepOnlinePresenceDisposable?.dispose()
        self.currentRequestDisposable.dispose()
        self.onlineTimer?.invalidate()
        if let mindGramGhostObserver = self.mindGramGhostObserver {
            NotificationCenter.default.removeObserver(mindGramGhostObserver)
        }
    }
    
    private func updatePresence(_ isOnline: Bool) {
        // MindGram: ghost mode "Скрыть «в сети»" always reports offline.
        let ghostOffline = isOnline && MindGramGhost.blocks(.hideOnline, peerId: nil)
        let isOnline = isOnline && !ghostOffline
        let request: Signal<Api.Bool, MTRpcError>
        if isOnline {
            let timer = SignalKitTimer(timeout: 30.0, repeat: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updatePresence(true)
            }, queue: self.queue)
            self.onlineTimer = timer
            timer.start()
            request = self.network.request(Api.functions.account.updateStatus(offline: .boolFalse))
        } else {
            self.onlineTimer?.invalidate()
            self.onlineTimer = nil
            if ghostOffline {
                let timer = SignalKitTimer(timeout: 20.0, repeat: false, completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.updatePresence(self.wasOnline)
                }, queue: self.queue)
                self.onlineTimer = timer
                timer.start()
            }
            request = self.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
        }
        self.isPerformingUpdate.set(true)
        self.currentRequestDisposable.set((request
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> deliverOn(self.queue)).start(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isPerformingUpdate.set(false)
        }))
    }
}

final class AccountPresenceManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<AccountPresenceManagerImpl>
    
    init(shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return AccountPresenceManagerImpl(queue: queue, shouldKeepOnlinePresence: shouldKeepOnlinePresence, network: network)
        })
    }
    
    func isPerformingUpdate() -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.isPerformingUpdate.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
}
