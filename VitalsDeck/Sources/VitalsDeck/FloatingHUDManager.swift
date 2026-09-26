import SwiftUI
import AppKit

public enum HUDCorner: String, CaseIterable, Identifiable {
    case topLeft = "Top-Left"
    case topCenter = "Notch"
    case topRight = "Top-Right"
    case bottomLeft = "Bottom-Left"
    case bottomRight = "Bottom-Right"
    
    public var id: String { rawValue }
    
    public var symbol: String {
        switch self {
        case .topLeft: return "↖ TL"
        case .topCenter: return "⌃ Notch"
        case .topRight: return "↗ TR"
        case .bottomLeft: return "↙ BL"
        case .bottomRight: return "↘ BR"
        }
    }
}

@MainActor
public final class FloatingHUDManager: ObservableObject {
    public static let shared = FloatingHUDManager()
    
    @Published public var isVisible: Bool = false
    @Published public var layout: HUDLayout = .card
    @Published public var opacity: Double = 0.95
    @Published public var clickThrough: Bool = false
    @Published public var autoHide: Bool = false
    @Published public var magneticSnap: Bool = true
    
    private var hudPanel: NSPanel?
    private let monitor = SystemMonitor.shared
    private let caffeine = CaffeineManager.shared
    private var moveDebounceTimer: Timer?
    
    public init() {
        if UserDefaults.standard.object(forKey: "VitalsDeck_HUD_Visible") == nil {
            UserDefaults.standard.set(true, forKey: "VitalsDeck_HUD_Visible")
        }
        let savedVisible = UserDefaults.standard.bool(forKey: "VitalsDeck_HUD_Visible")
        let savedLayout = UserDefaults.standard.string(forKey: "VitalsDeck_HUD_Layout") ?? "Card Box"
        let savedOpacity = UserDefaults.standard.double(forKey: "VitalsDeck_HUD_Opacity")
        let savedAutoHide = UserDefaults.standard.bool(forKey: "VitalsDeck_HUD_AutoHide")
        let savedMagneticSnap = UserDefaults.standard.object(forKey: "VitalsDeck_HUD_MagneticSnap") as? Bool ?? true
        
        self.layout = HUDLayout(rawValue: savedLayout) ?? .card
        self.opacity = savedOpacity > 0.2 ? savedOpacity : 0.95
        self.autoHide = savedAutoHide
        self.magneticSnap = savedMagneticSnap
        
        if savedVisible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showHUD()
            }
        }
    }
    
    public func toggleHUD() {
        if isVisible {
            hideHUD()
        } else {
            showHUD()
        }
    }
    
    public func setAutoHide(_ enabled: Bool) {
        self.autoHide = enabled
        UserDefaults.standard.set(enabled, forKey: "VitalsDeck_HUD_AutoHide")
    }
    
    public func setMagneticSnap(_ enabled: Bool) {
        self.magneticSnap = enabled
        UserDefaults.standard.set(enabled, forKey: "VitalsDeck_HUD_MagneticSnap")
    }
    
    public func updatePanelSizeForLayout() {
        guard let panel = hudPanel else { return }
        let currentOrigin = panel.frame.origin
        let newSize: NSSize = (layout == .card) ? NSSize(width: 280, height: 270) : NSSize(width: 490, height: 42)
        panel.setFrame(NSRect(origin: currentOrigin, size: newSize), display: true, animate: true)
    }
    
    public func snapTo(corner: HUDCorner, animated: Bool = true) {
        showHUD()
        guard let panel = hudPanel else { return }
        guard let screen = panel.screen ?? NSScreen.main else { return }
        
        let visible = screen.visibleFrame
        let panelSize = panel.frame.size
        let margin: CGFloat = 16.0
        
        var origin = panel.frame.origin
        switch corner {
        case .topLeft:
            origin = NSPoint(x: visible.minX + margin, y: visible.maxY - panelSize.height - margin)
        case .topCenter:
            origin = NSPoint(x: visible.midX - (panelSize.width / 2.0), y: visible.maxY - panelSize.height - 8)
        case .topRight:
            origin = NSPoint(x: visible.maxX - panelSize.width - margin, y: visible.maxY - panelSize.height - margin)
        case .bottomLeft:
            origin = NSPoint(x: visible.minX + margin, y: visible.minY + margin)
        case .bottomRight:
            origin = NSPoint(x: visible.maxX - panelSize.width - margin, y: visible.minY + margin)
        }
        
        let targetRect = NSRect(origin: origin, size: panelSize)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetRect, display: true)
            }
        } else {
            panel.setFrame(targetRect, display: true)
        }
        UserDefaults.standard.set(NSStringFromRect(targetRect), forKey: "VitalsDeck_HUD_Frame")
    }
    
    public func showHUD() {
        guard hudPanel == nil else {
            hudPanel?.orderFrontRegardless()
            isVisible = true
            return
        }
        
        let initialSize: NSSize = (layout == .card) ? NSSize(width: 280, height: 270) : NSSize(width: 490, height: 42)
        let panel = NSPanel(
            contentRect: NSRect(origin: NSPoint(x: 100, y: 100), size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = clickThrough
        
        let hostingView = NSHostingView(
            rootView: FloatingHUDContainerView(
                manager: self,
                monitor: monitor,
                caffeine: caffeine
            )
        )
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        
        // Restore window position if available, else top right of main screen
        if let savedFrameString = UserDefaults.standard.string(forKey: "VitalsDeck_HUD_Frame") {
            let savedRect = NSRectFromString(savedFrameString)
            panel.setFrame(NSRect(origin: savedRect.origin, size: initialSize), display: true)
        } else if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - initialSize.width - 24
            let y = screenRect.maxY - initialSize.height - 24
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Window movement observation for magnetic edge snapping
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveNotification(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )
        
        panel.orderFrontRegardless()
        self.hudPanel = panel
        self.isVisible = true
        UserDefaults.standard.set(true, forKey: "VitalsDeck_HUD_Visible")
    }
    
    public func hideHUD() {
        if let panel = hudPanel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "VitalsDeck_HUD_Frame")
            panel.orderOut(nil)
            hudPanel = nil
        }
        isVisible = false
        UserDefaults.standard.set(false, forKey: "VitalsDeck_HUD_Visible")
    }
    
    public func updateClickThrough(_ ignoreClicks: Bool) {
        self.clickThrough = ignoreClicks
        hudPanel?.ignoresMouseEvents = ignoreClicks
    }
    
    @objc private func windowDidMoveNotification(_ notification: Notification) {
        moveDebounceTimer?.invalidate()
        moveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performMagneticEdgeSnap()
            }
        }
    }
    
    private func performMagneticEdgeSnap() {
        guard let panel = hudPanel else { return }
        guard magneticSnap else {
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "VitalsDeck_HUD_Frame")
            return
        }
        guard let screen = panel.screen ?? NSScreen.main else { return }
        
        let visible = screen.visibleFrame
        var targetOrigin = panel.frame.origin
        let threshold: CGFloat = 35.0
        let margin: CGFloat = 16.0
        var snapped = false
        
        // Horizontal snap
        if abs(panel.frame.minX - visible.minX) < threshold {
            targetOrigin.x = visible.minX + margin
            snapped = true
        } else if abs(panel.frame.maxX - visible.maxX) < threshold {
            targetOrigin.x = visible.maxX - panel.frame.width - margin
            snapped = true
        } else if abs(panel.frame.midX - visible.midX) < threshold {
            targetOrigin.x = visible.midX - (panel.frame.width / 2.0)
            snapped = true
        }
        
        // Vertical snap
        if abs(panel.frame.maxY - visible.maxY) < threshold {
            let isCenter = abs(targetOrigin.x - (visible.midX - (panel.frame.width / 2.0))) < 1.0
            targetOrigin.y = visible.maxY - panel.frame.height - (isCenter ? 8.0 : margin)
            snapped = true
        } else if abs(panel.frame.minY - visible.minY) < threshold {
            targetOrigin.y = visible.minY + margin
            snapped = true
        }
        
        let targetRect = NSRect(origin: targetOrigin, size: panel.frame.size)
        if snapped {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrameOrigin(targetOrigin)
            }
        }
        UserDefaults.standard.set(NSStringFromRect(targetRect), forKey: "VitalsDeck_HUD_Frame")
    }
}

// Internal wrapper to bind theme and layout updates
struct FloatingHUDContainerView: View {
    @ObservedObject var manager: FloatingHUDManager
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var caffeine: CaffeineManager
    @AppStorage("VitalsDeck_CurrentTheme") private var storedTheme: String = AppTheme.signalAmber.rawValue
    
    var body: some View {
        let themeBinding = Binding<AppTheme>(
            get: { AppTheme(rawValue: storedTheme) ?? .signalAmber },
            set: { storedTheme = $0.rawValue }
        )
        let layoutBinding = Binding<HUDLayout>(
            get: { manager.layout },
            set: {
                manager.layout = $0
                UserDefaults.standard.set($0.rawValue, forKey: "VitalsDeck_HUD_Layout")
                manager.updatePanelSizeForLayout()
            }
        )
        let opacityBinding = Binding<Double>(
            get: { manager.opacity },
            set: {
                manager.opacity = $0
                UserDefaults.standard.set($0, forKey: "VitalsDeck_HUD_Opacity")
            }
        )
        
        FloatingHUDView(
            monitor: monitor,
            caffeine: caffeine,
            manager: manager,
            currentTheme: themeBinding,
            hudLayout: layoutBinding,
            hudOpacity: opacityBinding,
            onClose: {
                manager.hideHUD()
            }
        )
    }
}

