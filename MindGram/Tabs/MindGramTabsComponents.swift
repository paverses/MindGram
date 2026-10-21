import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import SliderComponent
import TabBarComponent

/// Telegram's real tab bar (TabBarComponent, the same code the app's bottom bar runs) with the tabs
/// MindGram currently shows. It reads the tab bar size from MindGramSettings like the real one does.
final class MindGramTabBarPreviewComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let showContacts: Bool
    let showCalls: Bool
    let revision: Int
    let tabBarController: TabBarController?

    init(theme: PresentationTheme, strings: PresentationStrings, showContacts: Bool, showCalls: Bool, revision: Int, tabBarController: TabBarController? = nil) {
        self.tabBarController = tabBarController
        self.theme = theme
        self.strings = strings
        self.showContacts = showContacts
        self.showCalls = showCalls
        self.revision = revision
    }

    static func ==(lhs: MindGramTabBarPreviewComponent, rhs: MindGramTabBarPreviewComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.showContacts == rhs.showContacts && lhs.showCalls == rhs.showCalls && lhs.revision == rhs.revision
    }

    final class View: UIView {
        private let tabBar = ComponentView<Empty>()

        func update(component: MindGramTabBarPreviewComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            var items: [TabBarComponent.Item] = []
            // The app's real tabs (their animated icons, the account photo on Settings), as the bar shows them.
            var selectedId = AnyHashable("settings")
            if let tabBarController = component.tabBarController {
                for controller in tabBarController.controllers {
                    items.append(TabBarComponent.Item(content: .tabBarItem(controller.tabBarItem), action: { _ in }, doubleTapAction: nil, contextAction: nil))
                }
                if let last = tabBarController.controllers.last {
                    selectedId = AnyHashable(ObjectIdentifier(last.tabBarItem))
                }
            }
            func add(_ id: String, _ title: String, _ icon: String) {
                items.append(TabBarComponent.Item(
                    content: .customItem(TabBarComponent.Item.Content.CustomItem(id: AnyHashable(id), title: title, icon: .bundleIcon(name: icon))),
                    action: { _ in },
                    doubleTapAction: nil,
                    contextAction: nil
                ))
            }
            if items.isEmpty {
                if component.showContacts {
                    add("contacts", component.strings.Contacts_TabTitle, "Chat List/Tabs/IconContacts")
                }
                if component.showCalls {
                    add("calls", component.strings.Calls_TabTitle, "Chat List/Tabs/IconCalls")
                }
                add("chats", component.strings.DialogList_TabTitle, "Chat List/Tabs/IconChats")
                add("settings", component.strings.Settings_Title, "Chat List/Tabs/IconSettings")
            }

            // Same width rule as the real tab bar (TabBarControllerNode): default width × "Ширина навбара".
            let defaultWidth = availableSize.width - 16.0 * 2.0
            let scaledWidth = min(availableSize.width - 8.0, defaultWidth * CGFloat(MindGramSettings.navbarWidthPercent) / 100.0)
            let sideInset = floor((availableSize.width - scaledWidth) * 0.5)
            let tabBarSize = self.tabBar.update(
                transition: transition,
                component: AnyComponent(TabBarComponent(
                    theme: component.theme,
                    isLiftedStateEnabled: false,
                    strings: component.strings,
                    items: items,
                    search: nil,
                    selectedId: selectedId,
                    outerInsets: UIEdgeInsets()
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            if let tabBarView = self.tabBar.view {
                if tabBarView.superview == nil {
                    tabBarView.isUserInteractionEnabled = false
                    self.addSubview(tabBarView)
                }
                transition.setFrame(view: tabBarView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - tabBarSize.width) * 0.5), y: floor((availableSize.height - tabBarSize.height) * 0.5)), size: tabBarSize))
            }
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

/// A title with the current percent above Telegram's SliderComponent; 50–150 %.
final class MindGramPercentSliderComponent: Component {
    let theme: PresentationTheme
    let title: String
    let percent: Int
    let updated: (Int) -> Void

    init(theme: PresentationTheme, title: String, percent: Int, updated: @escaping (Int) -> Void) {
        self.theme = theme
        self.title = title
        self.percent = percent
        self.updated = updated
    }

    static func ==(lhs: MindGramPercentSliderComponent, rhs: MindGramPercentSliderComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.title == rhs.title && lhs.percent == rhs.percent
    }

    final class View: UIView {
        private let titleLabel = UILabel()
        private let valueLabel = UILabel()
        private let slider = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.titleLabel)
            self.addSubview(self.valueLabel)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: MindGramPercentSliderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let sideInset: CGFloat = 16.0
            self.titleLabel.text = component.title
            self.titleLabel.font = Font.regular(17.0)
            self.titleLabel.textColor = component.theme.list.itemPrimaryTextColor
            self.valueLabel.text = "\(component.percent) %"
            self.valueLabel.font = Font.regular(17.0)
            self.valueLabel.textColor = component.theme.list.itemSecondaryTextColor

            let titleSize = self.titleLabel.sizeThatFits(CGSize(width: availableSize.width, height: 30.0))
            let valueSize = self.valueLabel.sizeThatFits(CGSize(width: availableSize.width, height: 30.0))
            self.titleLabel.frame = CGRect(origin: CGPoint(x: sideInset, y: 12.0), size: titleSize)
            self.valueLabel.frame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - valueSize.width, y: 12.0), size: valueSize)

            let range = MindGramSettingsRange.navbar
            let normalized = CGFloat(component.percent - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
            let updated = component.updated
            let sliderSize = self.slider.update(
                transition: .immediate,
                component: AnyComponent(SliderComponent(
                    content: .continuous(SliderComponent.Continuous(
                        value: normalized,
                        valueUpdated: { value in
                            let percent = range.lowerBound + Int((value * CGFloat(range.upperBound - range.lowerBound)).rounded())
                            updated(percent)
                        }
                    )),
                    useNative: true,
                    trackBackgroundColor: component.theme.list.itemSwitchColors.frameColor,
                    trackForegroundColor: component.theme.list.itemAccentColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 44.0)
            )
            if let sliderView = self.slider.view {
                if sliderView.superview == nil {
                    self.addSubview(sliderView)
                }
                sliderView.frame = CGRect(origin: CGPoint(x: sideInset, y: 40.0), size: sliderSize)
            }
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

enum MindGramSettingsRange {
    static let navbar: ClosedRange<Int> = 50 ... 150
}
