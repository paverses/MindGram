import Foundation
import UIKit
import PhotosUI
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import MindGramCore

/// «Обои профиля»: a picture behind profiles and Settings, chosen like a chat wallpaper — from the gallery or the
/// current chat wallpaper, with blur and dimming set in a preview before it is applied.
public enum MindGramProfileWallpaper {
    public enum Scope: Int {
        /// Your own profile and Settings.
        case own = 0
        /// Every profile.
        case all = 1
    }

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    private static func notify() {
        NotificationCenter.default.post(name: MindGramSettings.didChangeNotification, object: nil)
    }

    public static var isEnabled: Bool {
        get { return self.defaults.bool(forKey: "MindGram.profileWallpaper.enabled") }
        set {
            self.defaults.set(newValue, forKey: "MindGram.profileWallpaper.enabled")
            self.notify()
        }
    }

    public static var blur: Bool {
        get { return self.defaults.bool(forKey: "MindGram.profileWallpaper.blur") }
        set {
            self.defaults.set(newValue, forKey: "MindGram.profileWallpaper.blur")
            self.revision += 1
            self.notify()
        }
    }

    /// Darkening over the picture, 0–80 %.
    public static var dimPercent: Int {
        get {
            let value = self.defaults.object(forKey: "MindGram.profileWallpaper.dim") as? Int ?? 25
            return min(80, max(0, value))
        }
        set {
            self.defaults.set(min(80, max(0, newValue)), forKey: "MindGram.profileWallpaper.dim")
            self.revision += 1
            self.notify()
        }
    }

    public static var scope: Scope {
        get { return Scope(rawValue: self.defaults.integer(forKey: "MindGram.profileWallpaper.scope")) ?? .own }
        set {
            self.defaults.set(newValue.rawValue, forKey: "MindGram.profileWallpaper.scope")
            self.notify()
        }
    }

    /// Changes whenever the picture or its look changes, so screens know to redraw.
    public private(set) static var revision: Int {
        get { return self.defaults.integer(forKey: "MindGram.profileWallpaper.revision") }
        set { self.defaults.set(newValue, forKey: "MindGram.profileWallpaper.revision") }
    }

    private static var fileURL: URL? {
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = library.appendingPathComponent("MindGram", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("profile-wallpaper.jpg")
    }

    private static var cachedImage: (revision: Int, image: UIImage?)?

    /// The picture as set (without blur or dimming), or nil.
    public static var image: UIImage? {
        if let cachedImage = self.cachedImage, cachedImage.revision == self.revision {
            return cachedImage.image
        }
        let image = self.fileURL.flatMap { UIImage(contentsOfFile: $0.path) }
        self.cachedImage = (self.revision, image)
        return image
    }

    public static func setImage(_ image: UIImage, blur: Bool, dimPercent: Int) {
        guard let url = self.fileURL else {
            return
        }
        let maxSide: CGFloat = 1800.0
        let scale = min(1.0, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        try? resized.jpegData(compressionQuality: 0.9)?.write(to: url, options: .atomic)
        self.defaults.set(blur, forKey: "MindGram.profileWallpaper.blur")
        self.defaults.set(min(80, max(0, dimPercent)), forKey: "MindGram.profileWallpaper.dim")
        self.defaults.set(true, forKey: "MindGram.profileWallpaper.enabled")
        self.revision += 1
        self.notify()
    }

    public static func remove() {
        if let url = self.fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        self.defaults.set(false, forKey: "MindGram.profileWallpaper.enabled")
        self.revision += 1
        self.notify()
    }

    /// Whether a profile screen should show the wallpaper.
    public static func applies(isSettings: Bool, isOwnProfile: Bool) -> Bool {
        guard self.isEnabled, self.image != nil else {
            return false
        }
        switch self.scope {
        case .own:
            return isSettings || isOwnProfile
        case .all:
            return true
        }
    }

    /// The current chat wallpaper as a picture: a photo wallpaper's file, or its colours as a gradient.
    static func chatWallpaperImage(context: AccountContext, wallpaper: TelegramWallpaper, size: CGSize) -> UIImage? {
        let mediaBox = context.account.postbox.mediaBox
        var colors: [UInt32] = []
        switch wallpaper {
        case let .color(color):
            colors = [color]
        case let .gradient(gradient):
            colors = gradient.colors
        case let .image(representations, _):
            if let representation = representations.last, let path = mediaBox.completedResourcePath(representation.resource), let image = UIImage(contentsOfFile: path) {
                return image
            }
        case let .file(file):
            if !file.isPattern, let path = mediaBox.completedResourcePath(file.file.resource), let image = UIImage(contentsOfFile: path) {
                return image
            }
            colors = file.settings.colors
        case let .builtin(settings):
            colors = settings.colors
        case .emoticon:
            break
        }
        if colors.isEmpty {
            colors = [0x7fa381, 0xfff5c5, 0x336f55, 0xfbe37d]
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let cgColors = colors.map { UIColor(rgb: $0).cgColor }
            if cgColors.count == 1 {
                rendererContext.cgContext.setFillColor(cgColors[0])
                rendererContext.cgContext.fill(CGRect(origin: .zero, size: size))
            } else if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors as CFArray, locations: nil) {
                rendererContext.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: [])
            }
        }
    }
}

/// The wallpaper as shown behind a profile: picture, optional blur, dimming. Fixed while the list scrolls.
public final class MindGramProfileWallpaperView: UIView {
    private let imageView = UIImageView()
    private let blurView = UIVisualEffectView(effect: nil)
    private let dimView = UIView()
    public private(set) var revision: Int = -1

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.imageView.contentMode = .scaleAspectFill
        self.addSubview(self.imageView)
        self.addSubview(self.blurView)
        self.dimView.backgroundColor = .black
        self.addSubview(self.dimView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(image: UIImage?, blur: Bool, dimPercent: Int, revision: Int) {
        self.revision = revision
        self.imageView.image = image
        self.blurView.effect = blur ? UIBlurEffect(style: .regular) : nil
        self.dimView.alpha = CGFloat(dimPercent) / 100.0
    }

    /// Shows the saved wallpaper.
    public func updateFromSettings() {
        if self.revision != MindGramProfileWallpaper.revision {
            self.update(image: MindGramProfileWallpaper.image, blur: MindGramProfileWallpaper.blur, dimPercent: MindGramProfileWallpaper.dimPercent, revision: MindGramProfileWallpaper.revision)
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.imageView.frame = self.bounds
        self.blurView.frame = self.bounds
        self.dimView.frame = self.bounds
    }
}

/// The preview before a wallpaper is set: the picture under a mock profile, with Blur and Dimming, like
/// Telegram's chat wallpaper preview.
final class MindGramProfileWallpaperPreviewController: UIViewController {
    private let image: UIImage
    private let isRussian: Bool
    private let completion: (Bool, Int) -> Void

    private let wallpaperView = MindGramProfileWallpaperView()
    private let blurSwitch = UISwitch()
    private let dimSlider = UISlider()
    private var blur = MindGramProfileWallpaper.blur
    private var dim = MindGramProfileWallpaper.dimPercent

    init(image: UIImage, isRussian: Bool, completion: @escaping (Bool, Int) -> Void) {
        self.image = image
        self.isRussian = isRussian
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func t(_ ru: String, _ en: String) -> String {
        return self.isRussian ? ru : en
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        self.overrideUserInterfaceStyle = .dark
        self.view.addSubview(self.wallpaperView)
        self.wallpaperView.translatesAutoresizingMaskIntoConstraints = false

        // A mock profile on top: photo, name, buttons and two glass rows.
        let avatar = UIView()
        avatar.backgroundColor = UIColor(white: 1.0, alpha: 0.25)
        avatar.layer.cornerRadius = 48.0
        let avatarIcon = UIImageView(image: UIImage(systemName: "person.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44.0)))
        avatarIcon.tintColor = .white
        avatarIcon.translatesAutoresizingMaskIntoConstraints = false
        avatar.addSubview(avatarIcon)
        let name = UILabel()
        name.text = "MindGram"
        name.font = UIFont.systemFont(ofSize: 26.0, weight: .semibold)
        name.textColor = .white
        let status = UILabel()
        status.text = self.t("в сети", "online")
        status.font = UIFont.systemFont(ofSize: 15.0)
        status.textColor = UIColor(white: 1.0, alpha: 0.7)
        let buttons = UIStackView()
        buttons.spacing = 14.0
        for symbol in ["phone.fill", "bell.fill", "magnifyingglass", "ellipsis"] {
            let circle = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            circle.layer.cornerRadius = 29.0
            circle.clipsToBounds = true
            let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20.0, weight: .semibold)))
            icon.tintColor = .white
            icon.translatesAutoresizingMaskIntoConstraints = false
            circle.contentView.addSubview(icon)
            circle.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: 58.0),
                circle.heightAnchor.constraint(equalToConstant: 58.0),
                icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
            ])
            buttons.addArrangedSubview(circle)
        }
        let rows = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        rows.layer.cornerRadius = 26.0
        rows.clipsToBounds = true
        let rowsLabel = UILabel()
        rowsLabel.numberOfLines = 0
        rowsLabel.text = self.t("имя пользователя\n@mindgram", "username\n@mindgram")
        rowsLabel.textColor = .white
        rowsLabel.font = UIFont.systemFont(ofSize: 17.0)
        rowsLabel.translatesAutoresizingMaskIntoConstraints = false
        rows.contentView.addSubview(rowsLabel)

        let profile = UIStackView(arrangedSubviews: [avatar, name, status, buttons, rows])
        profile.axis = .vertical
        profile.alignment = .center
        profile.spacing = 10.0
        profile.setCustomSpacing(22.0, after: status)
        profile.setCustomSpacing(22.0, after: buttons)
        profile.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(profile)

        // Controls, like Telegram's wallpaper preview.
        let blurLabel = UILabel()
        blurLabel.text = self.t("Размытие", "Blur")
        blurLabel.textColor = .white
        self.blurSwitch.isOn = self.blur
        self.blurSwitch.addTarget(self, action: #selector(self.blurChanged), for: .valueChanged)
        let blurRow = UIStackView(arrangedSubviews: [blurLabel, self.blurSwitch])
        let dimLabel = UILabel()
        dimLabel.text = self.t("Затемнение", "Dimming")
        dimLabel.textColor = .white
        self.dimSlider.minimumValue = 0.0
        self.dimSlider.maximumValue = 80.0
        self.dimSlider.value = Float(self.dim)
        self.dimSlider.addTarget(self, action: #selector(self.dimChanged), for: .valueChanged)
        let dimRow = UIStackView(arrangedSubviews: [dimLabel, self.dimSlider])
        dimRow.spacing = 16.0
        let cancel = UIButton(type: .system)
        cancel.setTitle(self.t("Отмена", "Cancel"), for: .normal)
        cancel.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .medium)
        cancel.tintColor = .white
        cancel.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        cancel.layer.cornerRadius = 14.0
        cancel.addTarget(self, action: #selector(self.cancelPressed), for: .touchUpInside)
        let apply = UIButton(type: .system)
        apply.setTitle(self.t("Установить", "Set"), for: .normal)
        apply.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        apply.tintColor = .white
        apply.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        apply.layer.cornerRadius = 14.0
        apply.addTarget(self, action: #selector(self.applyPressed), for: .touchUpInside)
        let buttonsRow = UIStackView(arrangedSubviews: [cancel, apply])
        buttonsRow.distribution = .fillEqually
        buttonsRow.spacing = 12.0
        let panel = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        panel.layer.cornerRadius = 26.0
        panel.clipsToBounds = true
        panel.translatesAutoresizingMaskIntoConstraints = false
        let controls = UIStackView(arrangedSubviews: [blurRow, dimRow, buttonsRow])
        controls.axis = .vertical
        controls.spacing = 14.0
        controls.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(controls)
        self.view.addSubview(panel)

        NSLayoutConstraint.activate([
            self.wallpaperView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.wallpaperView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.wallpaperView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.wallpaperView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 96.0),
            avatar.heightAnchor.constraint(equalToConstant: 96.0),
            avatarIcon.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            avatarIcon.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            rows.widthAnchor.constraint(equalTo: profile.widthAnchor),
            rowsLabel.leadingAnchor.constraint(equalTo: rows.contentView.leadingAnchor, constant: 18.0),
            rowsLabel.trailingAnchor.constraint(equalTo: rows.contentView.trailingAnchor, constant: -18.0),
            rowsLabel.topAnchor.constraint(equalTo: rows.contentView.topAnchor, constant: 14.0),
            rowsLabel.bottomAnchor.constraint(equalTo: rows.contentView.bottomAnchor, constant: -14.0),
            profile.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 40.0),
            profile.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20.0),
            profile.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20.0),
            panel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 12.0),
            panel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -12.0),
            panel.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -8.0),
            controls.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 18.0),
            controls.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -18.0),
            controls.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 16.0),
            controls.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -16.0),
            cancel.heightAnchor.constraint(equalToConstant: 50.0)
        ])
        self.updatePreview()
    }

    private func updatePreview() {
        self.wallpaperView.update(image: self.image, blur: self.blur, dimPercent: self.dim, revision: 0)
    }

    @objc private func blurChanged() {
        self.blur = self.blurSwitch.isOn
        self.updatePreview()
    }

    @objc private func dimChanged() {
        self.dim = Int(self.dimSlider.value.rounded())
        self.updatePreview()
    }

    @objc private func cancelPressed() {
        self.dismiss(animated: true)
    }

    @objc private func applyPressed() {
        let completion = self.completion
        let blur = self.blur
        let dim = self.dim
        self.dismiss(animated: true, completion: {
            completion(blur, dim)
        })
    }
}

/// Picks one photo from the library with the system picker (no photo library permission needed).
private final class MindGramPhotoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private let completion: (UIImage?) -> Void
    private var keepAlive: MindGramPhotoPickerDelegate?

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        super.init()
        self.keepAlive = self
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let completion = self.completion
        self.keepAlive = nil
        picker.dismiss(animated: true, completion: {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                completion(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self, completionHandler: { object, _ in
                let image = object as? UIImage
                DispatchQueue.main.async {
                    completion(image)
                }
            })
        })
    }
}

/// Settings screen «Обои профиля».
func mindGramProfileWallpaperController(context: AccountContext) -> ViewController {
    var presentUIKitImpl: ((UIViewController) -> Void)?

    let openPreview: (UIImage) -> Void = { image in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let preview = MindGramProfileWallpaperPreviewController(image: image, isRussian: MindGramStrings(presentationData).isRussian, completion: { blur, dim in
            MindGramProfileWallpaper.setImage(image, blur: blur, dimPercent: dim)
        })
        presentUIKitImpl?(preview)
    }

    let arguments = MindGramListArguments(toggle: { id, value in
        switch id {
        case 0:
            MindGramProfileWallpaper.isEnabled = value
        case 5:
            MindGramProfileWallpaper.blur = value
        default:
            break
        }
    }, open: { id in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = MindGramStrings(presentationData)
        switch id {
        case 2:
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            let picker = PHPickerViewController(configuration: configuration)
            let delegate = MindGramPhotoPickerDelegate(completion: { image in
                if let image {
                    openPreview(image)
                }
            })
            picker.delegate = delegate
            presentUIKitImpl?(picker)
        case 3:
            let size = CGSize(width: 1170.0, height: 2532.0)
            if let image = MindGramProfileWallpaper.chatWallpaperImage(context: context, wallpaper: presentationData.chatWallpaper, size: size) {
                openPreview(image)
            }
        case 4:
            MindGramProfileWallpaper.remove()
        case 6:
            let sheet = UIAlertController(title: strings.t("Затемнение", "Dimming"), message: nil, preferredStyle: .actionSheet)
            for value in [0, 10, 20, 30, 40, 50, 60, 70, 80] {
                sheet.addAction(UIAlertAction(title: "\(value) %", style: .default, handler: { _ in
                    MindGramProfileWallpaper.dimPercent = value
                }))
            }
            sheet.addAction(UIAlertAction(title: strings.t("Отмена", "Cancel"), style: .cancel))
            presentUIKitImpl?(sheet)
        case 7:
            let sheet = UIAlertController(title: strings.t("Где показывать", "Where to Show"), message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: strings.t("Мой профиль и настройки", "My Profile and Settings"), style: .default, handler: { _ in
                MindGramProfileWallpaper.scope = .own
            }))
            sheet.addAction(UIAlertAction(title: strings.t("Все профили", "All Profiles"), style: .default, handler: { _ in
                MindGramProfileWallpaper.scope = .all
            }))
            sheet.addAction(UIAlertAction(title: strings.t("Отмена", "Cancel"), style: .cancel))
            presentUIKitImpl?(sheet)
        default:
            break
        }
    }, customItem: { _, presentationData, section in
        return mindGramPreviewItem(presentationData: presentationData, sectionId: section, height: 220.0, revision: MindGramProfileWallpaper.revision, build: { size, isDark in
            return MindGramPreviews.profileWallpaper(size: size, isDark: isDark)
        })
    })

    let controller = mindGramListController(context: context, title: { $0.t("Обои профиля", "Profile Wallpaper") }, arguments: arguments, entries: { _, strings in
        var entries: [MindGramListEntry] = []
        entries.append(.custom(id: 1, section: 0, key: "preview", revision: MindGramProfileWallpaper.revision * 4 + (MindGramProfileWallpaper.isEnabled ? 1 : 0)))
        entries.append(.toggle(id: 0, section: 1, title: strings.t("Обои профиля", "Profile Wallpaper"), info: strings.t("Картинка за профилем и настройками", "A picture behind profiles and Settings"), value: MindGramProfileWallpaper.isEnabled))
        entries.append(.action(id: 2, section: 1, title: strings.t("Выбрать из галереи", "Choose from Gallery")))
        entries.append(.action(id: 3, section: 1, title: strings.t("Как обои в чатах", "Same as Chat Wallpaper")))
        if MindGramProfileWallpaper.image != nil {
            entries.append(.action(id: 4, section: 1, title: strings.t("Убрать обои", "Remove Wallpaper")))
        }
        entries.append(.toggle(id: 5, section: 2, title: strings.t("Размытие", "Blur"), info: strings.t("Мягкий фон под текстом", "A soft background under text"), value: MindGramProfileWallpaper.blur))
        entries.append(.value(id: 6, section: 2, title: strings.t("Затемнение", "Dimming"), value: "\(MindGramProfileWallpaper.dimPercent) %"))
        entries.append(.value(id: 7, section: 2, title: strings.t("Где показывать", "Where to Show"), value: MindGramProfileWallpaper.scope == .own ? strings.t("Мой профиль", "My Profile") : strings.t("Все профили", "All Profiles")))
        entries.append(.footer(id: 8, section: 2, text: strings.t("Обои лучше всего смотрятся с «Liquid Glass в профиле» — разделы станут прозрачными.", "Wallpapers look best with Liquid Glass Profile: the sections become clear.")))
        return entries
    })
    presentUIKitImpl = { [weak controller] c in
        controller?.present(c, animated: true)
    }
    return controller
}
