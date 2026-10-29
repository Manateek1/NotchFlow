import AppKit
import SwiftUI

/// Custom NSHostingView that passes mouse events through to the underlying macOS menu bar and apps
/// whenever the cursor is outside the current Dynamic Island shape bounds.
public final class PassthroughHostingView: NSHostingView<IslandContainerView> {
    public weak var targetScreen: NSScreen?

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard IslandCoordinator.shared.displayState != .hidden else {
            return nil
        }

        let activeRect = currentActiveIslandRect()
        guard activeRect.contains(point) else {
            return nil
        }
        return super.hitTest(point)
    }

    public func currentActiveIslandRect() -> NSRect {
        let size = IslandCoordinator.shared.currentIslandSize(for: targetScreen)
        let b = bounds
        let x = (b.width - size.width) * 0.5
        // In NSView default coordinate system (isFlipped == false), top of view is at maxY
        let y = isFlipped ? 0 : (b.height - size.height - 12)
        return NSRect(x: x - 4, y: y - 4, width: size.width + 8, height: size.height + 16)
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    public override func otherMouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if currentActiveIslandRect().contains(loc), event.buttonNumber == 2 {
            IslandCoordinator.shared.handleMiddleClick()
        } else {
            super.otherMouseDown(with: event)
        }
    }

    public override func scrollWheel(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if currentActiveIslandRect().contains(loc) {
            IslandCoordinator.shared.handleScrollSwipe(
                deltaX: event.scrollingDeltaX,
                deltaY: event.scrollingDeltaY
            )
        } else {
            super.scrollWheel(with: event)
        }
    }
}

/// Non-activating, borderless floating panel anchored to the top of a target NSScreen.
public final class NotchIslandPanel: NSPanel {
    public static let canvasWidth: CGFloat = 580
    public static let canvasHeight: CGFloat = 350

    public private(set) var targetScreen: NSScreen?
    private var passthroughHostingView: PassthroughHostingView?

    public init(screen: NSScreen, onOpenSettings: @escaping () -> Void) {
        self.targetScreen = screen
        let initialFrame = Self.calculateCanvasFrame(for: screen)

        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.isMovable = false
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false

        let rootView = IslandContainerView(targetScreen: screen, onOpenSettings: onOpenSettings)
        let hosting = PassthroughHostingView(rootView: rootView)
        hosting.targetScreen = screen
        hosting.frame = NSRect(x: 0, y: 0, width: initialFrame.width, height: initialFrame.height)
        hosting.autoresizingMask = [.width, .height]

        self.contentView = hosting
        self.passthroughHostingView = hosting
    }

    public override var canBecomeKey: Bool {
        IslandCoordinator.shared.displayState == .expanded
    }

    public override var canBecomeMain: Bool {
        false
    }

    public func reposition(on screen: NSScreen, onOpenSettings: @escaping () -> Void) {
        self.targetScreen = screen
        let frame = Self.calculateCanvasFrame(for: screen)
        self.setFrame(frame, display: true)
        passthroughHostingView?.targetScreen = screen
        passthroughHostingView?.rootView = IslandContainerView(targetScreen: screen, onOpenSettings: onOpenSettings)
    }

    public func isScreenPointInsideActiveIsland(_ screenPoint: NSPoint) -> Bool {
        guard let hosting = passthroughHostingView else { return false }
        let windowPoint = convertPoint(fromScreen: screenPoint)
        let viewPoint = hosting.convert(windowPoint, from: nil)
        return hosting.currentActiveIslandRect().contains(viewPoint)
    }

    public static func calculateCanvasFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let x = screenFrame.midX - (canvasWidth * 0.5)
        let y = screenFrame.maxY - canvasHeight
        return NSRect(x: x, y: y, width: canvasWidth, height: canvasHeight)
    }
}
