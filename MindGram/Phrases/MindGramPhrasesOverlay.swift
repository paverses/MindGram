import Foundation
import UIKit
import MindGramCore

/// The list of quick phrases above the message field, shown while a trigger is typed (like inline bot
/// results). A tap calls `select` with the phrase.
public final class MindGramPhrasesOverlay: UIView, UITableViewDataSource, UITableViewDelegate {
    private let effectView: UIVisualEffectView
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var phrases: [MindGramPhrases.Phrase] = []
    private var trigger = "/"
    public var select: ((MindGramPhrases.Phrase) -> Void)?

    public static let rowHeight: CGFloat = 54.0

    public init(isDark: Bool) {
        if #available(iOS 26.0, *), !MindGramDesign.isClassic {
            self.effectView = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: isDark ? .systemThickMaterialDark : .systemThickMaterialLight))
        }
        super.init(frame: .zero)
        self.overrideUserInterfaceStyle = isDark ? .dark : .light
        self.layer.cornerRadius = 18.0
        self.layer.cornerCurve = .continuous
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = isDark ? 0.35 : 0.12
        self.layer.shadowRadius = 14.0
        self.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)

        self.effectView.layer.cornerRadius = 18.0
        self.effectView.layer.cornerCurve = .continuous
        self.effectView.clipsToBounds = true
        self.addSubview(self.effectView)

        self.tableView.backgroundColor = .clear
        self.tableView.rowHeight = MindGramPhrasesOverlay.rowHeight
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.separatorInset = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        self.effectView.contentView.addSubview(self.tableView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(phrases: [MindGramPhrases.Phrase], trigger: String) {
        self.phrases = phrases
        self.trigger = trigger
        self.tableView.reloadData()
    }

    /// Height for up to four rows.
    public var preferredHeight: CGFloat {
        return CGFloat(min(4, self.phrases.count)) * MindGramPhrasesOverlay.rowHeight
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.effectView.frame = self.bounds
        self.tableView.frame = self.bounds
        self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: 18.0).cgPath
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.phrases.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = .clear
        let phrase = self.phrases[indexPath.row]
        cell.textLabel?.text = self.trigger + phrase.name + (phrase.folder.isEmpty ? "" : "  ·  \(phrase.folder)")
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        cell.detailTextLabel?.text = phrase.text.replacingOccurrences(of: "\n", with: " ")
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14.0)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < self.phrases.count else {
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
        self.select?(self.phrases[indexPath.row])
    }
}
