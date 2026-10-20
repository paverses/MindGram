import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import TabBarComponent
import GlassControls
import LottieSettings

final class TabBarControllerNode: ASDisplayNode {
    private struct Params: Equatable {
        let layout: ContainerViewLayout
        let toolbar: Toolbar?
        let isTabBarHidden: Bool
        let currentControllerSearchState: ViewController.TabBarSearchState?
        
        init(
            layout: ContainerViewLayout,
            toolbar: Toolbar?,
            isTabBarHidden: Bool,
            currentControllerSearchState: ViewController.TabBarSearchState?
        ) {
            self.layout = layout
            self.toolbar = toolbar
            self.isTabBarHidden = isTabBarHidden
            self.currentControllerSearchState = currentControllerSearchState
        }
    }
    
    private struct LayoutResult {
        let params: Params
        let bottomInset: CGFloat
        
        init(params: Params, bottomInset: CGFloat) {
            self.params = params
            self.bottomInset = bottomInset
        }
    }
    
    private final class View: UIView {
        var onLayout: (() -> Void)?
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            self.onLayout?()
        }
    }
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private let itemSelected: (Int, Bool, [ASDisplayNode]) -> Void
    private let itemHasDoubleTapAction: (Int) -> Bool
    private let itemDoubleTapped: (Int) -> Void
    private let contextAction: (Int, ContextExtractedContentContainingView, ContextGesture) -> Void
    
    private let tabBarView = ComponentView<Empty>()

    // MindGram classic design: the full-width tab bar Telegram used before the glass redesign.
    private let classicTabBarNode: TabBarNode?
    private let classicSeparatorNode: ASDisplayNode?
    private var classicToolbarNode: ToolbarNode?

    private let disabledOverlayNode: ASDisplayNode
    private var toolbar: ComponentView<Empty>?
    private let toolbarActionSelected: (ToolbarActionOption) -> Void
    private let disabledPressed: () -> Void
    private let activateSearch: () -> Void
    private let deactivateSearch: () -> Void
    
    private(set) var tabBarItems: [TabBarNodeItem] = []
    private(set) var selectedIndex: Int = 0

    private weak var currentController: ViewController?
    
    private var layoutResult: LayoutResult?
    private var isUpdateRequested: Bool = false
    private var isChangingSelectedIndex: Bool = false
    
    func setCurrentController(_ controller: ViewController?) -> () -> Void {
        guard controller !== self.currentController else {
            return {}
        }
        
        let previousNode = self.currentController?.displayNode
        self.currentController = controller
        if let currentControllerNode = self.currentController?.displayNode {
            if let previousNode {
                self.insertSubnode(currentControllerNode, aboveSubnode: previousNode)
            } else {
                self.insertSubnode(currentControllerNode, at: 0)
            }
            if let tabBarView = self.tabBarView.view {
                self.view.bringSubviewToFront(tabBarView)
            }
        }
        
        return { [weak self, weak previousNode] in
            if previousNode !== self?.currentController?.displayNode {
                previousNode?.removeFromSupernode()
            }
        }
    }

    var currentSearchNode: ASDisplayNode? {
        if let tabBarComponentView = self.tabBarView.view as? TabBarComponent.View {
            return tabBarComponentView.currentSearchNode
        }
        return nil
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, itemSelected: @escaping (Int, Bool, [ASDisplayNode]) -> Void, itemHasDoubleTapAction: @escaping (Int) -> Bool, itemDoubleTapped: @escaping (Int) -> Void, contextAction: @escaping (Int, ContextExtractedContentContainingView, ContextGesture) -> Void, swipeAction: @escaping (Int, TabBarItemSwipeDirection) -> Void, toolbarActionSelected: @escaping (ToolbarActionOption) -> Void, disabledPressed: @escaping () -> Void, activateSearch: @escaping () -> Void, deactivateSearch: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.itemSelected = itemSelected
        self.itemHasDoubleTapAction = itemHasDoubleTapAction
        self.itemDoubleTapped = itemDoubleTapped
        self.contextAction = contextAction
        self.disabledOverlayNode = ASDisplayNode()
        self.disabledOverlayNode.backgroundColor = theme.rootController.tabBar.backgroundColor.withAlphaComponent(0.5)
        self.disabledOverlayNode.alpha = 0.0
        self.toolbarActionSelected = toolbarActionSelected
        self.disabledPressed = disabledPressed
        self.activateSearch = activateSearch
        self.deactivateSearch = deactivateSearch

        if MindGramDesign.isClassic {
            self.classicTabBarNode = TabBarNode(theme: theme, itemSelected: itemSelected, contextAction: { _, _, _ in }, swipeAction: swipeAction, lottieSettings: .noAccountFallback)
            let classicSeparatorNode = ASDisplayNode()
            classicSeparatorNode.isLayerBacked = true
            classicSeparatorNode.backgroundColor = theme.rootController.tabBar.separatorColor
            self.classicSeparatorNode = classicSeparatorNode
        } else {
            self.classicTabBarNode = nil
            self.classicSeparatorNode = nil
        }

        super.init()
        
        self.setViewBlock({
            return View(frame: CGRect())
        })
        
        (self.view as? View)?.onLayout = { [weak self] in
            guard let self else {
                return
            }
            if self.isUpdateRequested {
                self.isUpdateRequested = false
                if let layoutResult = self.layoutResult {
                    let _ = self.updateImpl(params: layoutResult.params, transition: .immediate)
                }
            }
        }
        
        self.backgroundColor = theme.list.plainBackgroundColor
        
        //self.addSubnode(self.tabBarNode)
        //self.addSubnode(self.disabledOverlayNode)

        if let classicTabBarNode = self.classicTabBarNode, let classicSeparatorNode = self.classicSeparatorNode {
            self.addSubnode(classicTabBarNode)
            self.addSubnode(classicSeparatorNode)
            self.addSubnode(self.disabledOverlayNode)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.disabledOverlayNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.disabledTapGesture(_:))))
    }
    
    @objc private func disabledTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.disabledPressed()
        }
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.backgroundColor = theme.list.plainBackgroundColor
        
        self.disabledOverlayNode.backgroundColor = theme.rootController.tabBar.backgroundColor.withAlphaComponent(0.5)
        self.classicTabBarNode?.updateTheme(theme)
        self.classicSeparatorNode?.backgroundColor = theme.rootController.tabBar.separatorColor
        self.classicToolbarNode?.updateTheme(ToolbarTheme(rootControllerTheme: theme))
        self.requestUpdate()
    }
    
    func updateIsTabBarEnabled(_ value: Bool, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.disabledOverlayNode, alpha: value ? 0.0 : 1.0)
    }
    
    var tabBarHidden = false {
        didSet {
            if self.tabBarHidden != oldValue {
                self.requestUpdate()
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, toolbar: Toolbar?, transition: ContainedViewLayoutTransition) -> CGFloat {
        let params = Params(layout: layout, toolbar: toolbar, isTabBarHidden: self.tabBarHidden, currentControllerSearchState: self.currentController?.tabBarSearchState)
        if let layoutResult = self.layoutResult, layoutResult.params == params {
            return layoutResult.bottomInset
        } else {
            let bottomInset = self.updateImpl(params: params, transition: transition)
            self.layoutResult = LayoutResult(params: params, bottomInset: bottomInset)
            return bottomInset
        }
    }
    
    /// MindGram: forget the cached layout so the next pass re-reads the navbar size settings.
    func mindGramInvalidateLayout() {
        self.layoutResult = nil
    }

    private func requestUpdate() {
        self.isUpdateRequested = true
        self.view.setNeedsLayout()
    }
    
    private func updateClassicImpl(params: Params, classicTabBarNode: TabBarNode, classicSeparatorNode: ASDisplayNode, transition: ContainedViewLayoutTransition) -> CGFloat {
        let layout = params.layout
        var options: ContainerViewLayoutInsetOptions = []
        if layout.metrics.widthClass == .regular {
            options.insert(.input)
        }
        let bottomInset: CGFloat = layout.insets(options: options).bottom
        let tabBarHeight: CGFloat
        if !layout.safeInsets.left.isZero {
            tabBarHeight = 34.0 + bottomInset
        } else {
            tabBarHeight = 49.0 + bottomInset
        }

        let tabBarFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - (params.isTabBarHidden ? 0.0 : tabBarHeight)), size: CGSize(width: layout.size.width, height: tabBarHeight))

        transition.updateFrame(node: classicTabBarNode, frame: tabBarFrame)
        classicTabBarNode.updateLayout(size: layout.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: bottomInset, transition: transition)
        transition.updateFrame(node: classicSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: tabBarFrame.minY - UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.disabledOverlayNode, frame: tabBarFrame)

        if let toolbar = params.toolbar {
            if let toolbarNode = self.classicToolbarNode {
                transition.updateFrame(node: toolbarNode, frame: tabBarFrame)
                toolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: bottomInset, toolbar: toolbar, transition: transition)
            } else {
                let toolbarNode = ToolbarNode(theme: ToolbarTheme(rootControllerTheme: self.theme), displaySeparator: true, left: { [weak self] in
                    self?.toolbarActionSelected(.left)
                }, right: { [weak self] in
                    self?.toolbarActionSelected(.right)
                }, middle: { [weak self] in
                    self?.toolbarActionSelected(.middle)
                })
                toolbarNode.frame = tabBarFrame
                toolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: bottomInset, toolbar: toolbar, transition: .immediate)
                self.addSubnode(toolbarNode)
                self.classicToolbarNode = toolbarNode
                if transition.isAnimated {
                    toolbarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        } else if let toolbarNode = self.classicToolbarNode {
            self.classicToolbarNode = nil
            transition.updateAlpha(node: toolbarNode, alpha: 0.0, completion: { [weak toolbarNode] _ in
                toolbarNode?.removeFromSupernode()
            })
        }

        return layout.size.height - tabBarFrame.minY
    }

    private func updateImpl(params: Params, transition: ContainedViewLayoutTransition) -> CGFloat {
        if let classicTabBarNode = self.classicTabBarNode, let classicSeparatorNode = self.classicSeparatorNode {
            return self.updateClassicImpl(params: params, classicTabBarNode: classicTabBarNode, classicSeparatorNode: classicSeparatorNode, transition: transition)
        }

        var panelsBottomInset: CGFloat = params.layout.insets(options: []).bottom
        if params.layout.metrics.widthClass == .regular, let inputHeight = params.layout.inputHeight, inputHeight != 0.0 {
            panelsBottomInset = inputHeight + 8.0
        }
        if panelsBottomInset == 0.0 {
            panelsBottomInset = 8.0
        } else {
            panelsBottomInset = max(panelsBottomInset, 8.0)
        }

        var tabBarBottomInset: CGFloat = panelsBottomInset
        if let currentController = self.currentController {
            if let tabBarSearchState = currentController.tabBarSearchState, tabBarSearchState.isActive, let inputHeight = params.layout.inputHeight, inputHeight != 0.0 {
                tabBarBottomInset = max(tabBarBottomInset, inputHeight + 8.0)
            }
        }

        var sideInset: CGFloat = 12.0
        if tabBarBottomInset <= 28.0 {
            sideInset = 20.0
        }

        // MindGram: "Ширина навбара" scales the bar around its default width, up to the screen edges.
        let mindGramWidthScale = CGFloat(MindGramSettings.navbarWidthPercent) / 100.0
        if mindGramWidthScale != 1.0 {
            let defaultWidth = params.layout.size.width - sideInset * 2.0
            let scaledWidth = min(params.layout.size.width - 8.0, defaultWidth * mindGramWidthScale)
            sideInset = floor((params.layout.size.width - scaledWidth) * 0.5)
        }
        
        var selectedId: AnyHashable?
        if self.selectedIndex < self.tabBarItems.count {
            selectedId = ObjectIdentifier(self.tabBarItems[self.selectedIndex].item)
        }
        var tabBarTransition = ComponentTransition(transition)
        if self.isChangingSelectedIndex {
            self.isChangingSelectedIndex = false
            tabBarTransition = .spring(duration: 0.4)
        }
        if self.tabBarView.view == nil {
            tabBarTransition = .immediate
        }
        let tabBarSize = self.tabBarView.update(
            transition: tabBarTransition,
            component: AnyComponent(TabBarComponent(
                theme: self.theme,
                strings: self.strings,
                items: self.tabBarItems.map { item in
                    let itemId = AnyHashable(ObjectIdentifier(item.item))
                    
                    let index = self.tabBarItems.firstIndex(where: { AnyHashable(ObjectIdentifier($0.item)) == itemId }) ?? 0
                    
                    return TabBarComponent.Item(
                        content: .tabBarItem(item.item),
                        action: { [weak self] isLongTap in
                            guard let self else {
                                return
                            }
                            if let index = self.tabBarItems.firstIndex(where: { AnyHashable(ObjectIdentifier($0.item)) == itemId }) {
                                self.itemSelected(index, isLongTap, [])
                            }
                        },
                        doubleTapAction: self.itemHasDoubleTapAction(index) ? { [weak self] in
                            guard let self else {
                                return
                            }
                            if let index = self.tabBarItems.firstIndex(where: { AnyHashable(ObjectIdentifier($0.item)) == itemId }) {
                                self.itemDoubleTapped(index)
                            }
                        } : nil,
                        contextAction: { [weak self] gesture, sourceView in
                            guard let self else {
                                return
                            }
                            if let index = self.tabBarItems.firstIndex(where: { AnyHashable(ObjectIdentifier($0.item)) == itemId }) {
                                self.contextAction(index, sourceView, gesture)
                            }
                        }
                    )
                },
                search: self.currentController?.tabBarSearchState.flatMap { tabBarSearchState in
                    return TabBarComponent.Search(
                        isActive: tabBarSearchState.isActive,
                        activate: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.activateSearch()
                        },
                        deactivate: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.deactivateSearch()
                        }
                    )
                },
                selectedId: selectedId,
                outerInsets: UIEdgeInsets(top: 0.0, left: sideInset, bottom: tabBarBottomInset, right: sideInset)
            )),
            environment: {},
            containerSize: CGSize(width: params.layout.size.width - sideInset * 2.0, height: 100.0)
        )
        let tabBarFrame = CGRect(origin: CGPoint(x: floor((params.layout.size.width - tabBarSize.width) * 0.5), y: params.layout.size.height - (self.tabBarHidden ? 0.0 : (tabBarSize.height + tabBarBottomInset))), size: tabBarSize)
        
        if let tabBarComponentView = self.tabBarView.view {
            if tabBarComponentView.superview == nil {
                self.view.addSubview(tabBarComponentView)
            }
            transition.updateFrame(view: tabBarComponentView, frame: tabBarFrame)
            transition.updateAlpha(layer: tabBarComponentView.layer, alpha: params.toolbar == nil ? 1.0 : 0.0)
        }
        
        transition.updateFrame(node: self.disabledOverlayNode, frame: tabBarFrame)
        
        let toolbarHeight = 44.0
        let toolbarFrame = CGRect(origin: CGPoint(x: sideInset, y: params.layout.size.height - panelsBottomInset - toolbarHeight), size: CGSize(width: params.layout.size.width - sideInset * 2.0, height: toolbarHeight))
        
        if let toolbarData = params.toolbar {
            let toolbar: ComponentView<Empty>
            var toolbarTransition = ComponentTransition(transition)
            if let current = self.toolbar {
                toolbar = current
            } else {
                toolbar = ComponentView()
                self.toolbar = toolbar
                toolbarTransition = .immediate
            }
            
            let _ = toolbar.update(
                transition: toolbarTransition,
                component: AnyComponent(GlassControlPanelComponent(
                    theme: self.theme,
                    leftItem: toolbarData.leftAction.flatMap { value in
                        return GlassControlPanelComponent.Item(
                            items: [GlassControlGroupComponent.Item(
                                id: "left_" + value.title,
                                content: .text(value.title),
                                action: value.isEnabled ? { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.toolbarActionSelected(.left)
                                } : nil
                            )],
                            background: .panel
                        )
                    },
                    centralItem: toolbarData.middleAction.flatMap { value in
                        return GlassControlPanelComponent.Item(
                            items: [GlassControlGroupComponent.Item(
                                id: "right_" + value.title,
                                content: .text(value.title),
                                action: value.isEnabled ? { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.toolbarActionSelected(.middle)
                                } : nil
                            )],
                            background: .panel
                        )
                    },
                    rightItem: toolbarData.rightAction.flatMap { value in
                        return GlassControlPanelComponent.Item(
                            items: [GlassControlGroupComponent.Item(
                                id: "right_" + value.title,
                                content: .text(value.title),
                                action: value.isEnabled ? { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.toolbarActionSelected(.right)
                                } : nil
                            )],
                            background: .panel
                        )
                    },
                    centerAlignmentIfPossible: true
                )),
                environment: {},
                containerSize: toolbarFrame.size
            )
            
            if let toolbarView = toolbar.view {
                if toolbarView.superview == nil {
                    self.view.addSubview(toolbarView)
                    toolbarView.alpha = 0.0
                }
                toolbarTransition.setFrame(view: toolbarView, frame: toolbarFrame)
                ComponentTransition(transition).setAlpha(view: toolbarView, alpha: 1.0)
            }
        } else if let toolbar = self.toolbar {
            self.toolbar = nil
            if let toolbarView = toolbar.view {
                ComponentTransition(transition).setAlpha(view: toolbarView, alpha: 0.0, completion: { [weak toolbarView] _ in
                    toolbarView?.removeFromSuperview()
                })
            }
        }
        
        return params.layout.size.height - tabBarFrame.minY
    }
    
    func frameForControllerTab(at index: Int) -> CGRect? {
        if let classicTabBarNode = self.classicTabBarNode {
            guard index >= 0 && index < self.tabBarItems.count, let itemFrame = classicTabBarNode.frameForControllerTab(at: index) else {
                return nil
            }
            return self.view.convert(itemFrame, from: classicTabBarNode.view)
        }
        guard let tabBarView = self.tabBarView.view as? TabBarComponent.View else {
            return nil
        }
        guard let itemFrame = tabBarView.frameForItem(at: index) else {
            return nil
        }
        return self.view.convert(itemFrame, from: tabBarView)
    }
    
    func isPointInsideContentArea(point: CGPoint) -> Bool {
        if let classicTabBarNode = self.classicTabBarNode {
            return point.y < classicTabBarNode.frame.minY
        }
        guard let tabBarView = self.tabBarView.view else {
            return false
        }
        if point.y < tabBarView.frame.minY {
            return true
        }
        return false
    }
    
    func updateTabBarItems(items: [TabBarNodeItem]) {
        self.tabBarItems = items
        self.classicTabBarNode?.tabBarItems = items
        self.requestUpdate()
    }

    func updateSelectedIndex(index: Int) {
        self.selectedIndex = index
        self.classicTabBarNode?.selectedIndex = index
        self.isChangingSelectedIndex = true
        self.requestUpdate()
    }
}
