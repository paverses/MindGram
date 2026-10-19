import Foundation
import UIKit

/// Records how far each launch got, so a launch crash can be diagnosed on a phone without Xcode.
///
/// Every launch writes its steps to Library/MindGramLaunch.txt; a crash adds the exception or signal and
/// the call stack. If a launch never reached `finish()`, the next launch shows that record on screen with
/// a Copy button instead of starting the app, and the launch after that starts normally again.
public enum MindGramLaunchTrace {
    private static let finishedMarker = "== launched"
    private static var handle: FileHandle?

    /// The record of the previous launch, when it did not finish.
    public private(set) static var pendingReport: String?

    private static var url: URL? {
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("MindGramLaunch.txt")
    }

    /// Call first thing in `didFinishLaunching`. Returns true when the previous launch crashed and
    /// its report should be shown instead of starting the app.
    public static func begin() -> Bool {
        guard let url = self.url else {
            return false
        }
        if let previous = try? String(contentsOf: url, encoding: .utf8), !previous.contains(self.finishedMarker) {
            self.pendingReport = previous
        }

        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let header = "MindGram \(version) (\(build)), iOS \(UIDevice.current.systemVersion), \(UIDevice.current.model), \(Date())\n"
        try? header.write(to: url, atomically: true, encoding: .utf8)
        self.handle = try? FileHandle(forWritingTo: url)
        self.handle?.seekToEndOfFile()

        if self.pendingReport != nil {
            // This launch only shows the report, so it counts as finished.
            self.finish()
            return true
        }

        NSSetUncaughtExceptionHandler { exception in
            MindGramLaunchTrace.write("exception: \(exception.name.rawValue): \(exception.reason ?? "")\n\(exception.callStackSymbols.joined(separator: "\n"))\n")
        }
        for signalNumber in [SIGABRT, SIGILL, SIGSEGV, SIGBUS, SIGFPE, SIGTRAP] {
            signal(signalNumber, mindGramLaunchTraceSignalHandler)
        }
        return false
    }

    public static func step(_ name: String) {
        self.write("step: \(name)\n")
    }

    public static func finish() {
        self.write(self.finishedMarker + "\n")
    }

    fileprivate static func write(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            return
        }
        self.handle?.write(data)
        self.handle?.synchronizeFile()
    }

    /// Shows the pending report in its own window in the given scene; nil when there is nothing to show.
    public static func presentPendingReport(in scene: UIWindowScene) -> UIWindow? {
        guard let report = self.pendingReport else {
            return nil
        }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = MindGramLaunchReportController(report: report)
        window.makeKeyAndVisible()
        return window
    }
}

private func mindGramLaunchTraceSignalHandler(_ signalNumber: Int32) {
    MindGramLaunchTrace.write("signal \(signalNumber)\n\(Thread.callStackSymbols.joined(separator: "\n"))\n")
    signal(signalNumber, SIG_DFL)
    raise(signalNumber)
}

private final class MindGramLaunchReportController: UIViewController {
    private let report: String

    init(report: String) {
        self.report = report
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground

        let title = UILabel()
        title.text = "MindGram упал при прошлом запуске"
        title.font = .boldSystemFont(ofSize: 17.0)
        title.numberOfLines = 0

        let textView = UITextView()
        textView.text = self.report
        textView.font = .monospacedSystemFont(ofSize: 11.0, weight: .regular)
        textView.isEditable = false
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 10.0

        let copyButton = UIButton(type: .system)
        copyButton.setTitle("Скопировать отчёт", for: .normal)
        copyButton.titleLabel?.font = .boldSystemFont(ofSize: 17.0)
        copyButton.addTarget(self, action: #selector(self.copyReport), for: .touchUpInside)

        let hint = UILabel()
        hint.text = "Отправь отчёт разработчику. Следующий запуск будет обычным."
        hint.font = .systemFont(ofSize: 13.0)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [title, textView, copyButton, hint])
        stack.axis = .vertical
        stack.spacing = 12.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16.0),
            stack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16.0),
            stack.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16.0)
        ])
    }

    @objc private func copyReport() {
        UIPasteboard.general.string = self.report
    }
}
