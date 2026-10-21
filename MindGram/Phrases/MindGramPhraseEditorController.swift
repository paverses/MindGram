import Foundation
import UIKit
import MindGramCore

private extension NSAttributedString.Key {
    static let mindGramFormat = NSAttributedString.Key("MindGram.phraseFormat")
}

/// The phrase editor: name, folder and a text with formatting buttons, like Telegram's article editor.
final class MindGramPhraseEditorController: UIViewController, UITextViewDelegate {
    private var phrase: MindGramPhrases.Phrase
    private let isNew: Bool
    private let isRussian: Bool

    private let nameField = UITextField()
    private let folderField = UITextField()
    private let textView = UITextView()
    private let toolbar = UIStackView()
    private let bodyFont = UIFont.systemFont(ofSize: 17.0)

    init(phrase: MindGramPhrases.Phrase?, isRussian: Bool) {
        self.isNew = phrase == nil
        self.phrase = phrase ?? MindGramPhrases.Phrase(name: "", folder: "", text: "", formats: [])
        self.isRussian = isRussian
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func t(_ ru: String, _ en: String) -> String {
        return self.isRussian ? ru : en
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemGroupedBackground
        self.title = self.isNew ? self.t("Новая фраза", "New Phrase") : self.t("Фраза", "Phrase")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.t("Сохранить", "Save"), style: .done, target: self, action: #selector(self.savePressed))

        for (field, placeholder, value) in [(self.nameField, self.t("Название — то, что пишете после символа", "Name — what you type after the trigger"), self.phrase.name), (self.folderField, self.t("Папка (необязательно)", "Folder (optional)"), self.phrase.folder)] {
            field.placeholder = placeholder
            field.text = value
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
            field.backgroundColor = .secondarySystemGroupedBackground
            field.layer.cornerRadius = 12.0
            field.leftView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 14.0, height: 10.0))
            field.leftViewMode = .always
            field.heightAnchor.constraint(equalToConstant: 46.0).isActive = true
        }

        self.textView.font = self.bodyFont
        self.textView.backgroundColor = .secondarySystemGroupedBackground
        self.textView.layer.cornerRadius = 12.0
        self.textView.textContainerInset = UIEdgeInsets(top: 12.0, left: 10.0, bottom: 12.0, right: 10.0)
        self.textView.delegate = self
        self.textView.attributedText = self.attributedText(text: self.phrase.text, formats: self.phrase.formats)

        let buttons: [(String, MindGramPhrases.Format.Kind)] = [
            ("bold", .bold), ("italic", .italic), ("underline", .underline), ("strikethrough", .strikethrough),
            ("chevron.left.forwardslash.chevron.right", .monospace), ("eye.slash", .spoiler), ("link", .link)
        ]
        self.toolbar.axis = .horizontal
        self.toolbar.distribution = .fillEqually
        self.toolbar.backgroundColor = .secondarySystemGroupedBackground
        self.toolbar.layer.cornerRadius = 12.0
        for (index, (symbol, _)) in buttons.enumerated() {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: symbol), for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(self.formatPressed(_:)), for: .touchUpInside)
            self.toolbar.addArrangedSubview(button)
        }
        self.toolbar.heightAnchor.constraint(equalToConstant: 44.0).isActive = true

        let hint = UILabel()
        hint.text = self.t("Выделите текст и нажмите кнопку формата. {имя}, {дата}, {время} подставятся при вставке.", "Select text and tap a format. {name}, {date}, {time} are filled in when inserted.")
        hint.font = UIFont.preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [self.nameField, self.folderField, self.toolbar, self.textView, hint])
        stack.axis = .vertical
        stack.spacing = 10.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
            stack.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -16.0),
            stack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 12.0),
            stack.bottomAnchor.constraint(equalTo: self.view.keyboardLayoutGuide.topAnchor, constant: -12.0)
        ])
    }

    private static let kinds: [MindGramPhrases.Format.Kind] = [.bold, .italic, .underline, .strikethrough, .monospace, .spoiler, .link]

    // MARK: Formatting

    private func attributes(for formats: [MindGramPhrases.Format]) -> [NSAttributedString.Key: Any] {
        var traits: UIFontDescriptor.SymbolicTraits = []
        var attributes: [NSAttributedString.Key: Any] = [:]
        var monospace = false
        for format in formats {
            switch format.kind {
            case .bold:
                traits.insert(.traitBold)
            case .italic:
                traits.insert(.traitItalic)
            case .underline:
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            case .strikethrough:
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            case .monospace:
                monospace = true
            case .spoiler:
                attributes[.backgroundColor] = UIColor.systemGray4
            case .link:
                attributes[.foregroundColor] = UIColor.systemBlue
            }
        }
        var font = monospace ? UIFont.monospacedSystemFont(ofSize: 16.0, weight: traits.contains(.traitBold) ? .bold : .regular) : self.bodyFont
        if !monospace, let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            font = UIFont(descriptor: descriptor, size: font.pointSize)
        }
        attributes[.font] = font
        if attributes[.foregroundColor] == nil {
            attributes[.foregroundColor] = UIColor.label
        }
        return attributes
    }

    /// The text with our formats stored as an attribute (an array of formats per range) and drawn.
    private func attributedText(text: String, formats: [MindGramPhrases.Format]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [.font: self.bodyFont, .foregroundColor: UIColor.label])
        let length = (text as NSString).length
        for index in 0 ..< length {
            let active = formats.filter { index >= $0.location && index < $0.location + $0.length }
            if !active.isEmpty {
                var attributes = self.attributes(for: active)
                attributes[.mindGramFormat] = active.map { "\($0.kind.rawValue)|\($0.url ?? "")" }
                result.addAttributes(attributes, range: NSRange(location: index, length: 1))
            }
        }
        return result
    }

    /// Formats back out of the text view: consecutive characters with the same format merge into one range.
    private func currentFormats() -> [MindGramPhrases.Format] {
        let text = self.textView.attributedText ?? NSAttributedString()
        var formats: [MindGramPhrases.Format] = []
        text.enumerateAttribute(.mindGramFormat, in: NSRange(location: 0, length: text.length), options: []) { value, range, _ in
            guard let items = value as? [String] else {
                return
            }
            for item in items {
                let parts = item.components(separatedBy: "|")
                guard let kind = MindGramPhrases.Format.Kind(rawValue: parts[0]) else {
                    continue
                }
                let url = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
                if let lastIndex = formats.lastIndex(where: { $0.kind == kind && $0.url == url && $0.location + $0.length == range.location }) {
                    formats[lastIndex].length += range.length
                } else {
                    formats.append(MindGramPhrases.Format(kind: kind, location: range.location, length: range.length, url: url))
                }
            }
        }
        return formats
    }

    @objc private func formatPressed(_ sender: UIButton) {
        let kind = MindGramPhraseEditorController.kinds[sender.tag]
        let range = self.textView.selectedRange
        guard range.length > 0 else {
            return
        }
        let apply: (String?) -> Void = { [weak self] url in
            guard let self else {
                return
            }
            var formats = self.currentFormats()
            // Toggle: remove when the whole selection already has it.
            let covered = formats.contains(where: { $0.kind == kind && $0.location <= range.location && $0.location + $0.length >= range.location + range.length })
            if covered {
                var updated: [MindGramPhrases.Format] = []
                for format in formats {
                    guard format.kind == kind else {
                        updated.append(format)
                        continue
                    }
                    let end = format.location + format.length
                    if format.location < range.location {
                        updated.append(MindGramPhrases.Format(kind: kind, location: format.location, length: min(end, range.location) - format.location, url: format.url))
                    }
                    if end > range.location + range.length {
                        let start = max(format.location, range.location + range.length)
                        updated.append(MindGramPhrases.Format(kind: kind, location: start, length: end - start, url: format.url))
                    }
                }
                formats = updated
            } else {
                formats.append(MindGramPhrases.Format(kind: kind, location: range.location, length: range.length, url: url))
            }
            let text = self.textView.text ?? ""
            self.textView.attributedText = self.attributedText(text: text, formats: formats)
            self.textView.selectedRange = range
        }
        if kind == .link {
            let alert = UIAlertController(title: self.t("Ссылка", "Link"), message: nil, preferredStyle: .alert)
            alert.addTextField { field in
                field.placeholder = "https://"
                field.keyboardType = .URL
                field.autocapitalizationType = .none
            }
            alert.addAction(UIAlertAction(title: self.t("Отмена", "Cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] _ in
                let value = alert?.textFields?.first?.text ?? ""
                if !value.isEmpty {
                    apply(value)
                }
            }))
            self.present(alert, animated: true)
        } else {
            apply(nil)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        // Typing continues with plain text.
        textView.typingAttributes = [.font: self.bodyFont, .foregroundColor: UIColor.label]
    }

    // MARK: Saving

    @objc private func cancelPressed() {
        self.dismiss(animated: true)
    }

    @objc private func savePressed() {
        let name = (self.nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
        let text = self.textView.text ?? ""
        guard !name.isEmpty, !text.isEmpty else {
            let alert = UIAlertController(title: self.t("Нужно название и текст", "A name and a text are needed"), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        self.phrase.name = name
        self.phrase.folder = (self.folderField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.phrase.text = text
        self.phrase.formats = self.currentFormats()
        MindGramPhrases.save(self.phrase)
        self.dismiss(animated: true)
    }
}
