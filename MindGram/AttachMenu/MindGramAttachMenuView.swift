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

/// The "+" menu (Оформление → Эксперименты): a Liquid Glass panel above the "+" button with a list of
/// attachment kinds. It opens showing about four rows and grows taller as the list is scrolled; a tap
/// closes it and calls `select` with the row's index (the caller opens Telegram's own screen for it).
public final class MindGramAttachMenuView: UIView, UIScrollViewDelegate {
    private let items: [MindGramAttachMenuItem]
    private let select: (Int) -> Void
    private let isDark: Bool

    private let dimView = UIView()
    private let panel = UIView()
    private let effectView: UIVisualEffectView
    private let scrollView = UIScrollView()
    private var rowViews: [UIView] = []

    private let rowHeight: CGFloat = 62.0
    private let panelWidthMax: CGFloat = 300.0
    private var anchor: CGRect = .zero
    private var panelHeight: CGFloat = 0.0
    private var minPanelHeight: CGFloat = 0.0
    private var maxPanelHeight: CGFloat = 0.0
    private var isDismissing = false

    public init(items: [MindGramAttachMenuItem], isDark: Bool, select: @escaping (Int) -> Void) {
        self.items = items
        self.select = select
        self.isDark = isDark
        if #available(iOS 26.0, *), !MindGramDesign.isClassic {
            self.effectView = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: isDark ? .systemThinMaterialDark : .systemThinMaterialLight))
        }
        super.init(frame: .zero)

        self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.08)
        self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapped)))
        self.addSubview(self.dimView)

        self.panel.layer.cornerRadius = 30.0
        self.panel.layer.cornerCurve = .continuous
        self.panel.layer.shadowColor = UIColor.black.cgColor
        self.panel.layer.shadowOpacity = isDark ? 0.4 : 0.16
        self.panel.layer.shadowRadius = 24.0
        self.panel.layer.shadowOffset = CGSize(width: 0.0, height: 8.0)
        self.addSubview(self.panel)

        self.effectView.layer.cornerRadius = 30.0
        self.effectView.layer.cornerCurve = .continuous
        self.effectView.clipsToBounds = true
        self.panel.addSubview(self.effectView)

        self.scrollView.delegate = self
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.effectView.contentView.addSubview(self.scrollView)

        for (index, item) in items.enumerated() {
            let row = self.makeRow(item: item, index: index)
            self.rowViews.append(row)
            self.scrollView.addSubview(row)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRow(item: MindGramAttachMenuItem, index: Int) -> UIView {
        let row = UIControl()
        row.tag = index
        row.addTarget(self, action: #selector(self.rowTapped(_:)), for: .touchUpInside)
        row.addTarget(self, action: #selector(self.rowHighlight(_:)), for: [.touchDown, .touchDragEnter])
        row.addTarget(self, action: #selector(self.rowUnhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        let circle = UIView()
        circle.backgroundColor = item.color
        circle.layer.cornerRadius = 20.0
        circle.isUserInteractionEnabled = false
        circle.tag = 1
        let gradient = CAGradientLayer()
        gradient.colors = [UIColor(white: 1.0, alpha: 0.28).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradient.cornerRadius = 20.0
        gradient.frame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 40.0)
        circle.layer.addSublayer(gradient)
        row.addSubview(circle)

        let icon = UIImageView(image: UIImage(systemName: item.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18.0, weight: .semibold)))
        icon.tintColor = .white
        icon.contentMode = .center
        icon.tag = 2
        circle.addSubview(icon)

        let label = UILabel()
        label.text = item.title
        label.font = UIFont.systemFont(ofSize: 20.0, weight: .regular)
        label.textColor = self.isDark ? .white : .black
        label.tag = 3
        row.addSubview(label)

        if item.badge {
            let badge = UIImageView(image: UIImage(systemName: "checkmark.seal.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)))
            badge.tintColor = UIColor(red: 0.2, green: 0.55, blue: 1.0, alpha: 1.0)
            badge.tag = 4
            row.addSubview(badge)
        }
        return row
    }

    /// Shows the menu over `container`, its bottom-left corner just above `anchor` (the "+" button).
    public func show(in container: UIView, anchor: CGRect) {
        self.anchor = anchor
        self.frame = container.bounds
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(self)
        self.layoutPanel()

        self.panel.layer.anchorPoint = CGPoint(x: 0.0, y: 1.0)
        self.layoutPanel()
        self.dimView.alpha = 0.0
        self.panel.alpha = 0.0
        self.panel.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIView.animate(withDuration: 0.45, delay: 0.0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.0, options: [.allowUserInteraction], animations: {
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
        UIView.animate(withDuration: 0.22, delay: 0.0, options: [.curveEaseIn], animations: {
            self.panel.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
            self.panel.alpha = 0.0
            self.dimView.alpha = 0.0
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }

    private func layoutPanel() {
        let bounds = self.bounds
        self.dimView.frame = bounds
        let width = min(self.panelWidthMax, bounds.width - 32.0)
        let topLimit = self.safeAreaInsets.top + 12.0
        let bottom = self.anchor.minY - 8.0
        self.minPanelHeight = min(CGFloat(min(self.items.count, 4)) * self.rowHeight + (self.items.count > 4 ? self.rowHeight * 0.5 : 0.0) + 20.0, bottom - topLimit)
        self.maxPanelHeight = max(self.minPanelHeight, min(CGFloat(self.items.count) * self.rowHeight + 20.0, bottom - topLimit))
        if self.panelHeight == 0.0 {
            self.panelHeight = self.minPanelHeight
        }
        self.panelHeight = max(self.minPanelHeight, min(self.maxPanelHeight, self.panelHeight))

        let x = max(16.0, min(self.anchor.minX - 4.0, bounds.width - width - 16.0))
        let transform = self.panel.transform
        self.panel.transform = .identity
        self.panel.bounds = CGRect(x: 0.0, y: 0.0, width: width, height: self.panelHeight)
        self.panel.center = CGPoint(x: x, y: bottom)
        self.panel.transform = transform
        self.panel.layer.shadowPath = UIBezierPath(roundedRect: self.panel.bounds, cornerRadius: 30.0).cgPath
        self.effectView.frame = self.panel.bounds
        self.scrollView.frame = self.panel.bounds

        for (index, row) in self.rowViews.enumerated() {
            row.frame = CGRect(x: 0.0, y: 10.0 + CGFloat(index) * self.rowHeight, width: width, height: self.rowHeight)
            if let circle = row.viewWithTag(1) {
                circle.frame = CGRect(x: 20.0, y: (self.rowHeight - 40.0) / 2.0, width: 40.0, height: 40.0)
                circle.viewWithTag(2)?.frame = circle.bounds
            }
            if let label = row.viewWithTag(3) as? UILabel {
                let size = label.sizeThatFits(CGSize(width: width - 120.0, height: 30.0))
                label.frame = CGRect(x: 78.0, y: (self.rowHeight - size.height) / 2.0, width: min(size.width, width - 120.0), height: size.height)
                if let badge = row.viewWithTag(4) {
                    badge.sizeToFit()
                    badge.center = CGPoint(x: label.frame.maxX + 6.0 + badge.bounds.width / 2.0, y: label.frame.midY)
                }
            }
        }
        self.scrollView.contentSize = CGSize(width: width, height: 20.0 + CGFloat(self.rowViews.count) * self.rowHeight)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        if !self.isDismissing {
            self.layoutPanel()
        }
    }

    // MARK: Growing while scrolling

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        if offset > 0.0 && self.panelHeight < self.maxPanelHeight {
            // Scrolling up into the list: the panel grows first, the list scrolls after.
            let grow = min(offset, self.maxPanelHeight - self.panelHeight)
            self.panelHeight += grow
            scrollView.contentOffset.y = offset - grow
            self.layoutPanel()
        } else if offset < 0.0 && self.panelHeight > self.minPanelHeight && scrollView.isDragging {
            // Pulling down at the top: the panel shrinks back first.
            let shrink = min(-offset, self.panelHeight - self.minPanelHeight)
            self.panelHeight -= shrink
            scrollView.contentOffset.y = offset + shrink
            self.layoutPanel()
        }
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView.contentOffset.y < -60.0 || (velocity.y < -1.8 && self.panelHeight <= self.minPanelHeight + 1.0) {
            self.dismiss()
        }
    }

    // MARK: Actions

    @objc private func dimTapped() {
        self.dismiss()
    }

    @objc private func rowHighlight(_ sender: UIControl) {
        UIView.animate(withDuration: 0.12, animations: {
            sender.backgroundColor = self.isDark ? UIColor(white: 1.0, alpha: 0.1) : UIColor(white: 0.0, alpha: 0.06)
            sender.viewWithTag(1)?.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        })
    }

    @objc private func rowUnhighlight(_ sender: UIControl) {
        UIView.animate(withDuration: 0.2, animations: {
            sender.backgroundColor = .clear
            sender.viewWithTag(1)?.transform = .identity
        })
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
