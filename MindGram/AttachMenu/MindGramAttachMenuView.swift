import Foundation
import UIKit
import MindGramCore

/// One row of the "+" menu.
public struct MindGramAttachMenuItem {
    public let title: String
    public let symbol: String
    public let color: UIColor
    public let badge: Bool

    public init(title: String, symbol: String, color: UIColor, badge: Bool = false) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.badge = badge
    }
}

/// The "+" menu (Оформление → Эксперименты): a Liquid Glass panel above the "+" button with one row per
/// attachment kind — Галерея, Файл, Геопозиция… — in a plain vertical list. A tap closes it and calls
/// `select` with the row's index (the caller opens Telegram's own screen for it).
public final class MindGramAttachMenuView: UIView, UIScrollViewDelegate {
    private let items: [MindGramAttachMenuItem]
    private let select: (Int) -> Void
    private let isDark: Bool

    private let dimView = UIView()
    private let panel = UIView()
    private let effectView: UIVisualEffectView
    private let scrollView = UIScrollView()
    private var rows: [MindGramAttachMenuRow] = []

    private let rowHeight: CGFloat = 50.0
    private let verticalInset: CGFloat = 8.0
    private let panelWidth: CGFloat = 250.0
    private var anchor: CGRect = .zero
    private var isDismissing = false
    /// Opens with three and a half rows; scrolling the list grows the panel up to all of them.
    private var panelHeight: CGFloat = 0.0
    private var minPanelHeight: CGFloat = 0.0
    private var maxPanelHeight: CGFloat = 0.0

    public init(items: [MindGramAttachMenuItem], isDark: Bool, select: @escaping (Int) -> Void) {
        self.items = items
        self.select = select
        self.isDark = isDark
        if #available(iOS 26.0, *), !MindGramDesign.isClassic {
            self.effectView = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: isDark ? .systemThickMaterialDark : .systemThickMaterialLight))
        }
        super.init(frame: .zero)
        self.overrideUserInterfaceStyle = isDark ? .dark : .light

        self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.08)
        self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapped)))
        self.addSubview(self.dimView)

        self.panel.layer.shadowColor = UIColor.black.cgColor
        self.panel.layer.shadowOpacity = isDark ? 0.4 : 0.16
        self.panel.layer.shadowRadius = 24.0
        self.panel.layer.shadowOffset = CGSize(width: 0.0, height: 8.0)
        self.addSubview(self.panel)

        // The glass is only the background; the rows sit in their own view above it.
        self.effectView.layer.cornerRadius = 26.0
        self.effectView.layer.cornerCurve = .continuous
        self.effectView.clipsToBounds = true
        self.effectView.isUserInteractionEnabled = false
        self.panel.addSubview(self.effectView)

        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.delegate = self
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.layer.cornerRadius = 26.0
        self.scrollView.layer.cornerCurve = .continuous
        self.scrollView.clipsToBounds = true
        self.panel.addSubview(self.scrollView)

        for (index, item) in items.enumerated() {
            let row = MindGramAttachMenuRow(item: item, isDark: isDark)
            row.tag = index
            row.addTarget(self, action: #selector(self.rowTapped(_:)), for: .touchUpInside)
            self.rows.append(row)
            self.scrollView.addSubview(row)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the menu over `container`, its bottom-left corner just above `anchor` (the "+" button).
    public func show(in container: UIView, anchor: CGRect) {
        self.anchor = anchor
        self.frame = container.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(self)
        self.layoutMenu()

        self.dimView.alpha = 0.0
        self.panel.alpha = 0.0
        let panelFrame = self.panel.frame
        // Grow out of the "+" button.
        self.panel.transform = CGAffineTransform(translationX: -panelFrame.width * 0.35, y: panelFrame.height * 0.35).scaledBy(x: 0.3, y: 0.3)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIView.animate(withDuration: 0.42, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: [.allowUserInteraction], animations: {
            self.panel.transform = .identity
            self.panel.alpha = 1.0
            self.dimView.alpha = 1.0
        })
    }

    public func dismiss(completion: (() -> Void)? = nil) {
        guard !self.isDismissing else {
            return
        }
        self.isDismissing = true
        let panelFrame = self.panel.frame
        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseIn], animations: {
            self.panel.transform = CGAffineTransform(translationX: -panelFrame.width * 0.3, y: panelFrame.height * 0.3).scaledBy(x: 0.4, y: 0.4)
            self.panel.alpha = 0.0
            self.dimView.alpha = 0.0
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }

    private func layoutMenu() {
        let bounds = self.bounds
        self.dimView.frame = bounds
        let width = min(self.panelWidth, bounds.width - 32.0)
        let topLimit = self.safeAreaInsets.top + 12.0
        let bottom = self.anchor.minY - 8.0
        let contentHeight = CGFloat(self.rows.count) * self.rowHeight + self.verticalInset * 2.0
        self.maxPanelHeight = max(self.rowHeight, min(contentHeight, bottom - topLimit))
        self.minPanelHeight = min(self.maxPanelHeight, self.rows.count > 4 ? self.rowHeight * 3.5 + self.verticalInset : contentHeight)
        if self.panelHeight == 0.0 {
            self.panelHeight = self.minPanelHeight
        }
        self.panelHeight = max(self.minPanelHeight, min(self.maxPanelHeight, self.panelHeight))
        let height = self.panelHeight

        let transform = self.panel.transform
        self.panel.transform = .identity
        self.panel.frame = CGRect(x: 12.0, y: bottom - height, width: width, height: height)
        self.panel.transform = transform
        self.panel.layer.shadowPath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: width, height: height)), cornerRadius: 26.0).cgPath
        self.effectView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        self.scrollView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        self.scrollView.contentSize = CGSize(width: width, height: contentHeight)
        for (index, row) in self.rows.enumerated() {
            row.frame = CGRect(x: 0.0, y: self.verticalInset + CGFloat(index) * self.rowHeight, width: width, height: self.rowHeight)
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        if !self.isDismissing {
            self.layoutMenu()
        }
    }

    @objc private func dimTapped() {
        self.dismiss()
    }

    @objc private func rowTapped(_ sender: UIControl) {
        let index = sender.tag
        UISelectionFeedbackGenerator().selectionChanged()
        let select = self.select
        self.dismiss(completion: {
            select(index)
        })
    }
}

/// A row: a coloured circle with the icon, then the title.
private final class MindGramAttachMenuRow: UIControl {
    private let circle = UIView()
    private let icon = UIImageView()
    private let label = UILabel()
    private let badge: UIImageView?
    private let isDark: Bool

    init(item: MindGramAttachMenuItem, isDark: Bool) {
        self.isDark = isDark
        if item.badge {
            let badge = UIImageView(image: UIImage(systemName: "checkmark.seal.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13.0, weight: .semibold)))
            badge.tintColor = UIColor(red: 0.2, green: 0.55, blue: 1.0, alpha: 1.0)
            self.badge = badge
        } else {
            self.badge = nil
        }
        super.init(frame: .zero)

        self.circle.backgroundColor = item.color
        self.circle.layer.cornerRadius = 16.0
        self.circle.isUserInteractionEnabled = false
        self.addSubview(self.circle)

        self.icon.image = UIImage(systemName: item.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14.0, weight: .semibold))
        self.icon.tintColor = .white
        self.icon.contentMode = .center
        self.circle.addSubview(self.icon)

        self.label.text = item.title
        self.label.font = UIFont.systemFont(ofSize: 17.0, weight: .regular)
        self.label.textColor = isDark ? .white : .black
        self.label.lineBreakMode = .byTruncatingTail
        self.label.isUserInteractionEnabled = false
        self.addSubview(self.label)

        if let badge = self.badge {
            badge.isUserInteractionEnabled = false
            self.addSubview(badge)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0.08 : 0.2, animations: {
                self.backgroundColor = self.isHighlighted ? (self.isDark ? UIColor(white: 1.0, alpha: 0.1) : UIColor(white: 0.0, alpha: 0.06)) : .clear
                self.circle.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
            })
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.bounds.size
        self.circle.transform = .identity
        self.circle.frame = CGRect(x: 14.0, y: floor((size.height - 32.0) / 2.0), width: 32.0, height: 32.0)
        self.icon.frame = self.circle.bounds
        let labelX: CGFloat = 58.0
        let badgeWidth: CGFloat = self.badge == nil ? 0.0 : 20.0
        let labelSize = self.label.sizeThatFits(CGSize(width: size.width - labelX - 14.0 - badgeWidth, height: size.height))
        let labelWidth = min(labelSize.width, size.width - labelX - 14.0 - badgeWidth)
        self.label.frame = CGRect(x: labelX, y: floor((size.height - labelSize.height) / 2.0), width: labelWidth, height: labelSize.height)
        if let badge = self.badge {
            badge.sizeToFit()
            badge.center = CGPoint(x: self.label.frame.maxX + 4.0 + badge.bounds.width / 2.0, y: self.label.frame.midY)
        }
    }
}

extension MindGramAttachMenuView {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        if offset > 0.0 && self.panelHeight < self.maxPanelHeight {
            // Scrolling into the list: the panel grows first, the list scrolls after.
            let grow = min(offset, self.maxPanelHeight - self.panelHeight)
            self.panelHeight += grow
            scrollView.contentOffset.y = offset - grow
            self.layoutMenu()
        } else if offset < 0.0 && self.panelHeight > self.minPanelHeight && scrollView.isDragging {
            // Pulling down at the top shrinks it back.
            let shrink = min(-offset, self.panelHeight - self.minPanelHeight)
            self.panelHeight -= shrink
            scrollView.contentOffset.y = offset + shrink
            self.layoutMenu()
        }
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView.contentOffset.y < -60.0 {
            self.dismiss()
        }
    }
}
