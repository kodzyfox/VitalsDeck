import AppKit
import SwiftUI

@MainActor
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor = SystemMonitor.shared
    private let caffeine = CaffeineManager.shared
    private let hud = FloatingHUDManager.shared
    
    private var updateTimer: Timer?
    
    public override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        startStatusItemUpdater()
    }
    
    isolated deinit {
        updateTimer?.invalidate()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateButtonContent()
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 330, height: 640)
        popover.behavior = .transient
        popover.animates = true
        
        let contentView = VitalsDeckPopoverView(
            monitor: monitor,
            caffeine: caffeine,
            hud: hud,
            processMonitor: ProcessMonitor.shared,
            settings: settings
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
    }
    
    private func startStatusItemUpdater() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateButtonContent()
            }
        }
    }
    
    private let settings = AppSettings.shared
    
    private func updateButtonContent() {
        guard let button = statusItem.button else { return }
        
        // Show status based on caffeine or system stats
        if caffeine.isActive {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            button.image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Caffeine Active")?.withSymbolConfiguration(config)
            button.imagePosition = .imageLeft
            button.title = " \(caffeine.statusBadgeText)"
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            button.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Vitals Deck")?.withSymbolConfiguration(config)
            button.imagePosition = .imageLeft
            
            switch settings.menuBarDisplay {
            case .cpuPercent:
                button.title = String(format: " %.0f%%", monitor.cpuUsage)
            case .cpuTemp:
                button.title = " \(monitor.cpuTemperatureString)"
            case .cpuAndGpuTemp:
                if let gpuT = monitor.gpuTemperature {
                    let cpuT = monitor.cpuTemperature ?? Double(monitor.thermalEstimateCelsius)
                    button.title = String(format: " C:%.0f° G:%.0f°", cpuT, gpuT)
                } else {
                    button.title = " \(monitor.cpuTemperatureString)"
                }
            case .cpuAndTemp:
                button.title = String(format: " %.0f%% %@", monitor.cpuUsage, monitor.cpuTemperatureString)
            case .cpuAndGpu:
                button.title = String(format: " C:%.0f%% G:%.0f%%", monitor.cpuUsage, monitor.gpuUsage)
            case .ramPercent:
                button.title = String(format: " %.0f%%", monitor.ramUsagePercent)
            case .cpuAndRam:
                button.title = String(format: " C:%.0f%% R:%.0f%%", monitor.cpuUsage, monitor.ramUsagePercent)
            case .iconOnly:
                button.title = ""
            }
        }
        
        var tip = "VitalsDeck\nCPU: \(String(format: "%.0f%%", monitor.cpuUsage)) (\(monitor.cpuTemperatureString))"
        if !monitor.gpuTemperatureString.isEmpty {
            tip += "\nGPU: \(String(format: "%.0f%%", monitor.gpuUsage)) (\(monitor.gpuTemperatureString))"
        } else {
            tip += "\nGPU: \(String(format: "%.0f%%", monitor.gpuUsage))"
        }
        tip += "\nRAM: \(String(format: "%.0f%%", monitor.ramUsagePercent)) (\(SystemMonitor.formatBytesTotal(monitor.ramUsedBytes)) / \(SystemMonitor.formatBytesTotal(monitor.ramTotalBytes)))"
        tip += "\nUptime: \(monitor.uptimeString)"
        button.toolTip = tip
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) == true) {
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }
    
    public func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        // Title item
        let titleItem = NSMenuItem(title: "VITALS DECK", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // HUD toggle
        let isRu = settings.language == .ru
        let hudTitle = hud.isVisible ? (isRu ? "Скрыть плавающий HUD" : "Hide Floating HUD") : (isRu ? "Показать плавающий HUD" : "Show Floating HUD")
        let hudItem = NSMenuItem(
            title: hudTitle,
            action: #selector(contextToggleHUD),
            keyEquivalent: "h"
        )
        hudItem.target = self
        menu.addItem(hudItem)
        
        // Caffeine Submenu
        let caffeineItem = NSMenuItem(title: isRu ? "Режим Caffeine" : "Caffeine Sleep Inhibitor", action: nil, keyEquivalent: "")
        let caffeineSubmenu = NSMenu()
        
        let toggleTitle = caffeine.isActive ? (isRu ? "Выключить Caffeine" : "Stop Caffeine") : (isRu ? "Включить (30 мин)" : "Start (30 min)")
        let toggleCaffeineItem = NSMenuItem(
            title: toggleTitle,
            action: #selector(contextToggleCaffeine),
            keyEquivalent: ""
        )
        toggleCaffeineItem.target = self
        caffeineSubmenu.addItem(toggleCaffeineItem)
        caffeineSubmenu.addItem(NSMenuItem.separator())
        
        let presets: [(String, CaffeineDuration)] = [
            (isRu ? "20 минут" : "20 minutes", .minutes20),
            (isRu ? "30 минут" : "30 minutes", .minutes30),
            (isRu ? "1 час" : "1 hour", .hours1),
            (isRu ? "2 часа" : "2 hours", .hours2),
            (isRu ? "3 часа" : "3 hours", .hours3),
            (isRu ? "До отключения (∞)" : "Until Stopped (∞)", .indefinite)
        ]
        
        for (label, dur) in presets {
            let item = NSMenuItem(title: label, action: #selector(contextStartPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dur
            if caffeine.isActive && caffeine.currentDuration == dur {
                item.state = .on
            }
            caffeineSubmenu.addItem(item)
        }
        
        caffeineItem.submenu = caffeineSubmenu
        menu.addItem(caffeineItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Themes submenu
        let themeItem = NSMenuItem(title: isRu ? "Темы оформления" : "Visual Themes", action: nil, keyEquivalent: "")
        let themeSubmenu = NSMenu()
        let currentThemeStr = UserDefaults.standard.string(forKey: "VitalsDeck_CurrentTheme") ?? AppTheme.signalAmber.rawValue
        
        for theme in AppTheme.allCases {
            let item = NSMenuItem(title: theme.displayName, action: #selector(contextSelectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme
            if theme.rawValue == currentThemeStr {
                item.state = .on
            }
            themeSubmenu.addItem(item)
        }
        themeItem.submenu = themeSubmenu
        menu.addItem(themeItem)
        
        // Menu Bar Display submenu
        let displayItem = NSMenuItem(
            title: isRu ? "Отображение в меню" : "Menu Bar Display",
            action: nil,
            keyEquivalent: ""
        )
        let displaySubmenu = NSMenu()
        for mode in MenuBarDisplayMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(contextSelectDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            if mode == settings.menuBarDisplay {
                item.state = .on
            }
            displaySubmenu.addItem(item)
        }
        displayItem.submenu = displaySubmenu
        menu.addItem(displayItem)
        
        // Settings item
        let settingsItem = NSMenuItem(
            title: isRu ? "Настройки..." : "Preferences...",
            action: #selector(contextOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: isRu ? "Выйти из Vitals Deck" : "Quit Vitals Deck", action: #selector(contextQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }
    
    @objc private func contextToggleHUD() {
        hud.toggleHUD()
    }
    
    @objc private func contextSelectDisplayMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? MenuBarDisplayMode {
            settings.menuBarDisplay = mode
            updateButtonContent()
        }
    }
    
    @objc private func contextToggleCaffeine() {
        caffeine.toggleCaffeine()
    }
    
    @objc private func contextStartPreset(_ sender: NSMenuItem) {
        if let dur = sender.representedObject as? CaffeineDuration {
            caffeine.startCaffeine(duration: dur)
        }
    }
    
    @objc private func contextSelectTheme(_ sender: NSMenuItem) {
        if let theme = sender.representedObject as? AppTheme {
            UserDefaults.standard.set(theme.rawValue, forKey: "VitalsDeck_CurrentTheme")
        }
    }
    
    @objc private func contextOpenSettings() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    @objc private func contextQuit() {
        NSApplication.shared.terminate(nil)
    }
}
