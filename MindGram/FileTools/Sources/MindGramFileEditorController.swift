import Foundation
import UIKit
import PhotosUI

/// «Файл»: shown before sending one file picked in Files. Rename it, change its extension, edit music tags
/// and cover, convert audio / video / images, or edit code and text. «Отправить» hands the new file over.
public final class MindGramFileEditorController: UINavigationController {
    public init(url: URL, isRussian: Bool, isDark: Bool, send: @escaping (URL) -> Void) {
        let root = MindGramFileEditorRootController(url: url, isRussian: isRussian, send: send)
        super.init(rootViewController: root)
        self.overrideUserInterfaceStyle = isDark ? .dark : .light
        self.modalPresentationStyle = .formSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class MindGramFileEditorRootController: UITableViewController, UITextFieldDelegate, PHPickerViewControllerDelegate {
    private enum Section {
        case file
        case music
        case code
        case convert
    }

    private let send: (URL) -> Void
    private let isRussian: Bool
    private let workURL: URL?
    private let loadError: String?

    private var baseName: String
    private var ext: String
    private let originalExt: String
    private let kind: MindGramFileKind
    private let fileSize: Int64

    private var tags = MindGramAudioTags(title: "", artist: "", artwork: nil)
    private var originalTags = MindGramAudioTags(title: "", artist: "", artwork: nil)
    private var text: String?
    private var textEdited = false
    private var target: String?
    private var isWorking = false

    private var sections: [Section] = []

    init(url: URL, isRussian: Bool, send: @escaping (URL) -> Void) {
        self.send = send
        self.isRussian = isRussian
        let name = url.deletingPathExtension().lastPathComponent
        self.baseName = name
        self.ext = url.pathExtension
        self.originalExt = url.pathExtension.lowercased()
        self.kind = MindGramFileKind.of(extension: url.pathExtension)

        // Work on a private copy: the picked URL is security-scoped and may go away.
        var workURL: URL?
        var loadError: String?
        let accessing = url.startAccessingSecurityScopedResource()
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MindGramFiles", isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let copy = directory.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: copy)
            workURL = copy
        } catch {
            loadError = error.localizedDescription
        }
        if accessing {
            url.stopAccessingSecurityScopedResource()
        }
        self.workURL = workURL
        self.loadError = loadError
        self.fileSize = (workURL.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? NSNumber })?.int64Value ?? 0

        super.init(style: .insetGrouped)

        if let workURL {
            if self.kind == .audio {
                self.tags = MindGramAudioTags.read(from: workURL)
                self.originalTags = self.tags
            } else if self.kind == .text && self.fileSize < 4 * 1024 * 1024, let data = try? Data(contentsOf: workURL) {
                self.text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            }
        }
        self.updateSections()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func t(_ ru: String, _ en: String) -> String {
        return self.isRussian ? ru : en
    }

    private func updateSections() {
        var sections: [Section] = [.file]
        if self.kind == .audio {
            sections.append(.music)
        }
        if self.text != nil {
            sections.append(.code)
        }
        if self.kind != .text && self.kind != .other && MindGramFileKind.canConvert(from: self.originalExt) {
            sections.append(.convert)
        }
        self.sections = sections
    }

    private var targets: [String] {
        switch self.kind {
        case .audio:
            return MindGramFileKind.audioTargets
        case .video:
            return MindGramFileKind.videoTargets
        case .image:
            return MindGramFileKind.imageTargets
        default:
            return []
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = self.t("Файл", "File")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.t("Отправить", "Send"), style: .done, target: self, action: #selector(self.sendPressed))
        self.navigationItem.rightBarButtonItem?.isEnabled = self.workURL != nil
        self.tableView.keyboardDismissMode = .interactive
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.sections[section] {
        case .file:
            return 3
        case .music:
            return self.tags.artwork == nil ? 3 : 4
        case .code:
            return 1
        case .convert:
            return self.targets.count + 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch self.sections[section] {
        case .file:
            return self.t("ФАЙЛ", "FILE")
        case .music:
            return self.t("МУЗЫКА", "MUSIC")
        case .code:
            return MindGramFileKind.textLanguages[self.originalExt]?.uppercased() ?? self.t("ТЕКСТ", "TEXT")
        case .convert:
            return self.t("КОНВЕРТИРОВАТЬ", "CONVERT")
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch self.sections[section] {
        case .file:
            if let loadError = self.loadError {
                return self.t("Не удалось открыть файл: ", "Could not open the file: ") + loadError
            }
            return self.t("Расширение можно поменять на любое, например .py → .txt.", "You can change the extension to anything, e.g. .py → .txt.")
        case .music:
            return self.t("Название, исполнитель и обложка записываются в сам файл — их увидят в плеере Telegram и после скачивания.", "Title, artist and cover are written into the file itself, so the Telegram player and any download show them.")
        case .code:
            return nil
        case .convert:
            if self.kind == .audio {
                return self.t("MP3 — \(MindGramFileTools.mp3Bitrate) кбит/с. WAV, AIFF и CAF — без сжатия.", "MP3 at \(MindGramFileTools.mp3Bitrate) kbit/s. WAV, AIFF and CAF are uncompressed.")
            }
            return nil
        }
    }

    private func textFieldCell(title: String, value: String, placeholder: String, tag: Int) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        let label = UILabel()
        label.text = title
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        let field = UITextField()
        field.text = value
        field.placeholder = placeholder
        field.textAlignment = .right
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        field.tag = tag
        field.delegate = self
        field.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
        let stack = UIStackView(arrangedSubviews: [label, field])
        stack.spacing = 12.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11.0),
            stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11.0)
        ])
        return cell
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch self.sections[indexPath.section] {
        case .file:
            switch indexPath.row {
            case 0:
                return self.textFieldCell(title: self.t("Имя", "Name"), value: self.baseName, placeholder: self.t("имя файла", "file name"), tag: 1)
            case 1:
                return self.textFieldCell(title: self.t("Расширение", "Extension"), value: self.ext, placeholder: "txt", tag: 2)
            default:
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.selectionStyle = .none
                cell.textLabel?.text = self.t("Размер", "Size")
                cell.detailTextLabel?.text = ByteCountFormatter.string(fromByteCount: self.fileSize, countStyle: .file)
                return cell
            }
        case .music:
            switch indexPath.row {
            case 0:
                return self.textFieldCell(title: self.t("Название", "Title"), value: self.tags.title, placeholder: self.t("без названия", "untitled"), tag: 3)
            case 1:
                return self.textFieldCell(title: self.t("Исполнитель", "Artist"), value: self.tags.artist, placeholder: self.t("неизвестен", "unknown"), tag: 4)
            case 2:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = self.tags.artwork == nil ? self.t("Добавить обложку", "Add Cover") : self.t("Сменить обложку", "Change Cover")
                cell.textLabel?.textColor = self.view.tintColor
                if let artwork = self.tags.artwork, let image = UIImage(data: artwork) {
                    let imageView = UIImageView(image: image)
                    imageView.frame = CGRect(x: 0.0, y: 0.0, width: 36.0, height: 36.0)
                    imageView.contentMode = .scaleAspectFill
                    imageView.clipsToBounds = true
                    imageView.layer.cornerRadius = 6.0
                    cell.accessoryView = imageView
                }
                return cell
            default:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = self.t("Убрать обложку", "Remove Cover")
                cell.textLabel?.textColor = .systemRed
                return cell
            }
        case .code:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = self.t("Редактировать", "Edit")
            let lines = (self.text ?? "").components(separatedBy: "\n").count
            cell.detailTextLabel?.text = self.t("\(lines) строк", "\(lines) lines") + (self.textEdited ? self.t(" · изменено", " · edited") : "")
            cell.accessoryType = .disclosureIndicator
            return cell
        case .convert:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            if indexPath.row == 0 {
                cell.textLabel?.text = self.t("Оставить .\(self.originalExt)", "Keep .\(self.originalExt)")
                cell.accessoryType = self.target == nil ? .checkmark : .none
            } else {
                let format = self.targets[indexPath.row - 1]
                cell.textLabel?.text = format == "m4a" && self.kind == .video ? self.t("Только звук (M4A)", "Sound only (M4A)") : format.uppercased()
                cell.accessoryType = self.target == format ? .checkmark : .none
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch self.sections[indexPath.section] {
        case .music:
            if indexPath.row == 2 {
                var configuration = PHPickerConfiguration()
                configuration.filter = .images
                configuration.selectionLimit = 1
                let picker = PHPickerViewController(configuration: configuration)
                picker.delegate = self
                self.present(picker, animated: true)
            } else if indexPath.row == 3 {
                self.tags.artwork = nil
                tableView.reloadData()
            }
        case .code:
            let editor = MindGramCodeEditorController(text: self.text ?? "", title: "\(self.baseName).\(self.ext)", isRussian: self.isRussian, completion: { [weak self] text in
                guard let self else {
                    return
                }
                if text != self.text {
                    self.text = text
                    self.textEdited = true
                    self.tableView.reloadData()
                }
            })
            self.navigationController?.pushViewController(editor, animated: true)
        case .convert:
            if indexPath.row == 0 {
                self.target = nil
                self.ext = self.originalExt
            } else {
                let format = self.targets[indexPath.row - 1]
                self.target = format
                self.ext = format
            }
            tableView.reloadData()
        case .file:
            break
        }
    }

    // MARK: Editing

    @objc private func textFieldChanged(_ field: UITextField) {
        let value = field.text ?? ""
        switch field.tag {
        case 1:
            self.baseName = value
        case 2:
            self.ext = value.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        case 3:
            self.tags.title = value
        case 4:
            self.tags.artist = value
        default:
            break
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        provider.loadObject(ofClass: UIImage.self, completionHandler: { [weak self] object, _ in
            guard let image = object as? UIImage else {
                return
            }
            // A square cover, 600 px, like music services use.
            let side: CGFloat = 600.0
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let cover = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
                let scale = max(side / image.size.width, side / image.size.height)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                image.draw(in: CGRect(x: (side - size.width) / 2.0, y: (side - size.height) / 2.0, width: size.width, height: size.height))
            }
            DispatchQueue.main.async {
                self?.tags.artwork = cover.jpegData(compressionQuality: 0.88)
                self?.tableView.reloadData()
            }
        })
    }

    // MARK: Sending

    @objc private func cancelPressed() {
        self.dismiss(animated: true)
    }

    private func setWorking(_ working: Bool) {
        self.isWorking = working
        if working {
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.startAnimating()
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: indicator)
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.t("Отправить", "Send"), style: .done, target: self, action: #selector(self.sendPressed))
        }
        self.tableView.isUserInteractionEnabled = !working
    }

    private func showError(_ text: String) {
        let alert = UIAlertController(title: self.t("Не получилось", "Failed"), message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    @objc private func sendPressed() {
        self.view.endEditing(true)
        guard let workURL = self.workURL, !self.isWorking else {
            return
        }
        var name = self.baseName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        if name.isEmpty {
            name = "file"
        }
        let fileName = self.ext.isEmpty ? name : "\(name).\(self.ext)"
        let output = workURL.deletingLastPathComponent().appendingPathComponent("out-\(UUID().uuidString.prefix(6))", isDirectory: true).appendingPathComponent(fileName)
        do {
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            self.showError(error.localizedDescription)
            return
        }

        let done: (Result<URL, MindGramConvertError>) -> Void = { [weak self] result in
            guard let self else {
                return
            }
            self.setWorking(false)
            switch result {
            case let .success(url):
                let send = self.send
                self.dismiss(animated: true, completion: {
                    send(url)
                })
            case let .failure(error):
                self.showError(error.description)
            }
        }

        let tagsChanged = self.tags.title != self.originalTags.title || self.tags.artist != self.originalTags.artist || self.tags.artwork != self.originalTags.artwork
        self.setWorking(true)

        if let target = self.target {
            switch self.kind {
            case .audio:
                MindGramConverter.convertAudio(input: workURL, output: output.deletingPathExtension().appendingPathExtension(target), tags: self.tags, completion: done)
            case .video:
                MindGramConverter.convertVideo(input: workURL, output: output.deletingPathExtension().appendingPathExtension(target), completion: done)
            case .image:
                MindGramConverter.convertImage(input: workURL, output: output.deletingPathExtension().appendingPathExtension(target), completion: done)
            default:
                done(.failure(.failed("?")))
            }
            return
        }
        if self.kind == .audio && tagsChanged && ["mp3", "m4a", "m4b", "m4r"].contains(self.originalExt) {
            // Same format, new tags: written into a copy under the new name.
            let sameFormat = output.deletingPathExtension().appendingPathExtension(self.originalExt)
            MindGramConverter.convertAudio(input: workURL, output: sameFormat, tags: self.tags, completion: { [weak self] result in
                guard let self else {
                    return
                }
                if case let .success(url) = result, url.pathExtension != self.ext {
                    // The user also changed the extension by hand: keep the name they typed.
                    try? FileManager.default.moveItem(at: url, to: output)
                    done(.success(output))
                } else {
                    done(result)
                }
            })
            return
        }
        do {
            if self.textEdited, let text = self.text {
                try text.write(to: output, atomically: true, encoding: .utf8)
            } else {
                try FileManager.default.copyItem(at: workURL, to: output)
            }
            done(.success(output))
        } catch {
            done(.failure(.failed(error.localizedDescription)))
        }
    }
}

/// A plain monospaced editor for code and text files.
private final class MindGramCodeEditorController: UIViewController {
    private let textView = UITextView()
    private let initialText: String
    private let isRussian: Bool
    private let completion: (String) -> Void

    init(text: String, title: String, isRussian: Bool, completion: @escaping (String) -> Void) {
        self.initialText = text
        self.isRussian = isRussian
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.textView.text = self.initialText
        self.textView.font = UIFont.monospacedSystemFont(ofSize: 14.0, weight: .regular)
        self.textView.autocorrectionType = .no
        self.textView.autocapitalizationType = .none
        self.textView.smartQuotesType = .no
        self.textView.smartDashesType = .no
        self.textView.smartInsertDeleteType = .no
        self.textView.spellCheckingType = .no
        self.textView.alwaysBounceVertical = true
        self.textView.keyboardDismissMode = .interactive
        self.textView.textContainerInset = UIEdgeInsets(top: 12.0, left: 8.0, bottom: 12.0, right: 8.0)
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.textView)
        NSLayoutConstraint.activate([
            self.textView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.textView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.textView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.textView.bottomAnchor.constraint(equalTo: self.view.keyboardLayoutGuide.topAnchor)
        ])
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.isRussian ? "Готово" : "Done", style: .done, target: self, action: #selector(self.donePressed))
    }

    @objc private func donePressed() {
        self.completion(self.textView.text ?? "")
        self.navigationController?.popViewController(animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.isMovingFromParent {
            self.completion(self.textView.text ?? "")
        }
    }
}
