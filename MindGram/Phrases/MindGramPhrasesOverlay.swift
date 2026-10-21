import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import GlassBackgroundComponent
import MindGramCore

/// The list of quick phrases above the message field while a trigger is typed. It copies Telegram's inline bot
/// results (VerticalListContextResultsChatInputContextPanelNode): the same glass panel, 75 pt rows with a square
/// letter icon, a title and two lines of text, and a button row on top like a bot's "switch to PM" button.
public final class MindGramPhrasesOverlay: UIView, UITableViewDataSource, UITableViewDelegate {
    private let backgroundView = GlassBackgroundView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var theme: PresentationTheme
    private var phrases: [MindGramPhrases.Phrase] = []
    private var trigger = "/"
    private let buttonTitle: String

    public var select: ((MindGramPhrases.Phrase) -> Void)?
    public var openSettings: (() -> Void)?

    public static let rowHeight: CGFloat = 75.0
    public static let buttonHeight: CGFloat = 44.0

    public init(theme: PresentationTheme, buttonTitle: String) {
        self.theme = theme
        self.buttonTitle = buttonTitle
        super.init(frame: .zero)

        self.backgroundView.isUserInteractionEnabled = false
        self.addSubview(self.backgroundView)

        self.tableView.backgroundColor = .clear
        self.tableView.rowHeight = MindGramPhrasesOverlay.rowHeight
        self.tableView.separatorStyle = .none
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.layer.cornerRadius = 20.0
        self.tableView.layer.cornerCurve = .continuous
        self.tableView.clipsToBounds = true
        self.addSubview(self.tableView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(phrases: [MindGramPhrases.Phrase], trigger: String, theme: PresentationTheme) {
        self.phrases = phrases
        self.trigger = trigger
        self.theme = theme
        self.tableView.reloadData()
    }

    /// The button row and up to three and a half phrases, like Telegram's inline results.
    public var preferredHeight: CGFloat {
        return MindGramPhrasesOverlay.buttonHeight + min(CGFloat(self.phrases.count), 3.5) * MindGramPhrasesOverlay.rowHeight
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.backgroundView.frame = self.bounds
        self.backgroundView.update(size: self.bounds.size, cornerRadius: 20.0, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: .immediate)
        self.tableView.frame = self.bounds
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : self.phrases.count
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? MindGramPhrasesOverlay.buttonHeight : MindGramPhrasesOverlay.rowHeight
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = MindGramPhraseButtonCell(style: .default, reuseIdentifier: nil)
            cell.update(title: self.buttonTitle, theme: self.theme)
            return cell
        }
        let cell = MindGramPhraseCell(style: .default, reuseIdentifier: nil)
        let phrase = self.phrases[indexPath.row]
        let text = phrase.text.replacingOccurrences(of: "\n", with: " ")
        cell.update(title: self.trigger + phrase.name, text: phrase.folder.isEmpty ? text : "\(phrase.folder) · \(text)", theme: self.theme)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            self.openSettings?()
            return
        }
        guard indexPath.row < self.phrases.count else {
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
        self.select?(self.phrases[indexPath.row])
    }
}

/// A phrase row: 55 pt square with the first letter at 12/11, title (medium 16) and text (regular 15, two lines) at 80.
private final class MindGramPhraseCell: UITableViewCell {
    private let iconBackground = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let textLabelView = UILabel()
    private let separator = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.iconBackground.backgroundColor = UIColor(rgb: 0xdfdfdf)
        self.iconBackground.layer.cornerRadius = 2.0
        self.contentView.addSubview(self.iconBackground)
        self.iconLabel.font = Font.medium(25.0)
        self.iconLabel.textColor = .white
        self.iconLabel.textAlignment = .center
        self.iconBackground.addSubview(self.iconLabel)
        self.titleLabel.font = Font.medium(16.0)
        self.contentView.addSubview(self.titleLabel)
        self.textLabelView.font = Font.regular(15.0)
        self.textLabelView.numberOfLines = 2
        self.contentView.addSubview(self.textLabelView)
        self.contentView.addSubview(self.separator)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, text: String, theme: PresentationTheme) {
        let name = title.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
        self.iconLabel.text = name.first.map { String($0).uppercased() } ?? "•"
        self.titleLabel.text = title
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.textLabelView.text = text
        self.textLabelView.textColor = theme.list.itemSecondaryTextColor
        self.separator.backgroundColor = theme.list.itemPlainSeparatorColor
        let selected = UIView()
        selected.backgroundColor = theme.list.itemHighlightedBackgroundColor
        self.selectedBackgroundView = selected
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.contentView.bounds.width
        self.iconBackground.frame = CGRect(x: 12.0, y: 11.0, width: 55.0, height: 55.0)
        self.iconLabel.frame = self.iconBackground.bounds.offsetBy(dx: 0.0, dy: 2.0)
        let titleSize = self.titleLabel.sizeThatFits(CGSize(width: width - 90.0, height: 30.0))
        self.titleLabel.frame = CGRect(x: 80.0, y: 9.0, width: width - 90.0, height: titleSize.height)
        let textSize = self.textLabelView.sizeThatFits(CGSize(width: width - 90.0, height: 60.0))
        self.textLabelView.frame = CGRect(x: 80.0, y: self.titleLabel.frame.maxY + 1.0, width: width - 90.0, height: min(textSize.height, 40.0))
        self.separator.frame = CGRect(x: 80.0, y: self.contentView.bounds.height - UIScreenPixel, width: width - 80.0, height: UIScreenPixel)
    }
}

/// The button row on top, like an inline bot's "switch to PM" button.
private final class MindGramPhraseButtonCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let separator = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.titleLabel.font = Font.regular(17.0)
        self.titleLabel.textAlignment = .center
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.separator)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, theme: PresentationTheme) {
        self.titleLabel.text = title
        self.titleLabel.textColor = theme.list.itemAccentColor
        self.separator.backgroundColor = theme.list.itemPlainSeparatorColor
        let selected = UIView()
        selected.backgroundColor = theme.list.itemHighlightedBackgroundColor
        self.selectedBackgroundView = selected
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.titleLabel.frame = self.contentView.bounds
        self.separator.frame = CGRect(x: 0.0, y: self.contentView.bounds.height - UIScreenPixel, width: self.contentView.bounds.width, height: UIScreenPixel)
    }
}
