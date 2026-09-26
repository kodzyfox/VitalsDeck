import Foundation
import SwiftUI
import ServiceManagement

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en = "English"
    case ru = "Русский"
    
    public var id: String { rawValue }
    public var flag: String {
        switch self {
        case .en: return "🇺🇸"
        case .ru: return "🇷🇺"
        }
    }
}

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case cpuPercent = "CPU %"
    case cpuTemp = "CPU °C"
    case cpuAndGpuTemp = "CPU+GPU °C"
    case cpuAndTemp = "CPU % + °C"
    case cpuAndGpu = "CPU+GPU %"
    case ramPercent = "RAM %"
    case cpuAndRam = "CPU + RAM"
    case iconOnly = "Icon Only"
    
    public var id: String { rawValue }
}

public enum UpdateIntervalMode: Double, CaseIterable, Identifiable, Sendable {
    case fast = 1.0
    case balanced = 2.0
    case eco = 4.0
    
    public var id: Double { rawValue }
    
    public func label(lang: AppLanguage) -> String {
        switch self {
        case .fast:
            return lang == .ru ? "1.0с (Быстро)" : "1.0s (Fast)"
        case .balanced:
            return lang == .ru ? "2.0с (Норма)" : "2.0s (Balanced)"
        case .eco:
            return lang == .ru ? "4.0с (Эко)" : "4.0s (Eco)"
        }
    }
}

public enum L10n {
    public enum Key {
        case appSubtitle
        case telemetry
        case topConsumers
        case caffeineMode
        case hudOverlay
        case visualThemes
        case settingsTitle
        case modulesSection
        case telemetryMetricsSection
        case cpuLoadTemp
        case gpuUtilization
        case ramBreakdown
        case networkWaveSpeed
        case statusBatteryUptime
        case generalSection
        case languageLabel
        case updateIntervalLabel
        case menuBarDisplayLabel
        case launchAtLoginLabel
        case resetDefaultsLabel
        case backToDeck
        case keepMacAwake
        case stopCaffeine
        case keepScreenOn
        case customDuration
        case hideCustom
        case autoHide
        case edgeMagnet
        case visible
        case hidden
        case snapLabel
        case quitLabel
        case statusNominal
        case statusFair
        case statusSerious
        case statusCritical
        
        var en: String {
            switch self {
            case .appSubtitle: return "SYSTEM METRICS & HUD"
            case .telemetry: return "TELEMETRY"
            case .topConsumers: return "TOP CONSUMERS"
            case .caffeineMode: return "CAFFEINE MODE"
            case .hudOverlay: return "FLOATING HUD OVERLAY"
            case .visualThemes: return "VISUAL THEMES"
            case .settingsTitle: return "SETTINGS // CONFIG"
            case .modulesSection: return "DASHBOARD MODULES"
            case .telemetryMetricsSection: return "METRIC BARS"
            case .cpuLoadTemp: return "CPU Load & Temp"
            case .gpuUtilization: return "GPU Utilization"
            case .ramBreakdown: return "RAM Breakdown"
            case .networkWaveSpeed: return "Network Wave & Speed"
            case .statusBatteryUptime: return "Status, Battery & Uptime"
            case .generalSection: return "SYSTEM & GENERAL"
            case .languageLabel: return "Language"
            case .updateIntervalLabel: return "Update Interval"
            case .menuBarDisplayLabel: return "Menu Bar Display"
            case .launchAtLoginLabel: return "Launch at Startup"
            case .resetDefaultsLabel: return "Reset to Defaults"
            case .backToDeck: return "DECK"
            case .keepMacAwake: return "⚡ KEEP MAC AWAKE"
            case .stopCaffeine: return "🛑 STOP CAFFEINE"
            case .keepScreenOn: return "Keep Screen On"
            case .customDuration: return "Custom Duration..."
            case .hideCustom: return "Hide Custom"
            case .autoHide: return "Auto-Hide (Fade)"
            case .edgeMagnet: return "Edge Magnet"
            case .visible: return "Visible"
            case .hidden: return "Hidden"
            case .snapLabel: return "SNAP:"
            case .quitLabel: return "Quit"
            case .statusNominal: return "NOMINAL"
            case .statusFair: return "FAIR"
            case .statusSerious: return "SERIOUS"
            case .statusCritical: return "CRITICAL"
            }
        }
        
        var ru: String {
            switch self {
            case .appSubtitle: return "МОНИТОР СИСТЕМЫ И HUD"
            case .telemetry: return "ТЕЛЕМЕТРИЯ"
            case .topConsumers: return "ТОП ПРОЦЕССОВ"
            case .caffeineMode: return "РЕЖИМ CAFFEINE"
            case .hudOverlay: return "ПЛАВАЮЩИЙ HUD"
            case .visualThemes: return "ТЕМЫ ОФОРМЛЕНИЯ"
            case .settingsTitle: return "НАСТРОЙКИ // КОНФИГ"
            case .modulesSection: return "МОДУЛИ ИНТЕРФЕЙСА"
            case .telemetryMetricsSection: return "ПОКАЗАТЕЛИ ТЕЛЕМЕТРИИ"
            case .cpuLoadTemp: return "Нагрузка CPU и темп."
            case .gpuUtilization: return "Использование GPU"
            case .ramBreakdown: return "Детализация RAM"
            case .networkWaveSpeed: return "График и скорость сети"
            case .statusBatteryUptime: return "Статус, батарея и аптайм"
            case .generalSection: return "ОСНОВНЫЕ НАСТРОЙКИ"
            case .languageLabel: return "Язык интерфейса"
            case .updateIntervalLabel: return "Интервал обновления"
            case .menuBarDisplayLabel: return "В строке меню"
            case .launchAtLoginLabel: return "Запуск при входе в систему"
            case .resetDefaultsLabel: return "Сбросить по умолчанию"
            case .backToDeck: return "ДЕКА"
            case .keepMacAwake: return "⚡ НЕ ДАВАТЬ УСНУТЬ"
            case .stopCaffeine: return "🛑 ВЫКЛЮЧИТЬ CAFFEINE"
            case .keepScreenOn: return "Не гасить дисплей"
            case .customDuration: return "Точное время..."
            case .hideCustom: return "Скрыть время"
            case .autoHide: return "Авто-скрытие (18%)"
            case .edgeMagnet: return "Магнит к краям"
            case .visible: return "Вкл"
            case .hidden: return "Выкл"
            case .snapLabel: return "МАГНИТ:"
            case .quitLabel: return "Выйти"
            case .statusNominal: return "НОРМА"
            case .statusFair: return "УМЕРЕННО"
            case .statusSerious: return "ВЫСОКО"
            case .statusCritical: return "КРИТИЧЕСКИ"
            }
        }
    }
    
    public static func tr(_ key: Key, _ lang: AppLanguage) -> String {
        lang == .ru ? key.ru : key.en
    }
}

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    // General
    @Published public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "VitalsDeck_Language")
        }
    }
    
    @Published public var menuBarDisplay: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(menuBarDisplay.rawValue, forKey: "VitalsDeck_MenuBarDisplay")
        }
    }
    
    @Published public var updateInterval: UpdateIntervalMode {
        didSet {
            UserDefaults.standard.set(updateInterval.rawValue, forKey: "VitalsDeck_UpdateInterval")
            SystemMonitor.shared.setUpdateInterval(updateInterval.rawValue)
        }
    }
    
    @Published public var launchAtLogin: Bool = false
    
    // Module Visibility in Popover
    @Published public var showTopConsumers: Bool {
        didSet { UserDefaults.standard.set(showTopConsumers, forKey: "VitalsDeck_ShowTopConsumers") }
    }
    @Published public var showCaffeine: Bool {
        didSet { UserDefaults.standard.set(showCaffeine, forKey: "VitalsDeck_ShowCaffeine") }
    }
    @Published public var showHUDControls: Bool {
        didSet { UserDefaults.standard.set(showHUDControls, forKey: "VitalsDeck_ShowHUDControls") }
    }
    @Published public var showThemeSelector: Bool {
        didSet { UserDefaults.standard.set(showThemeSelector, forKey: "VitalsDeck_ShowThemeSelector") }
    }
    
    // Metric Bars Visibility
    @Published public var showCpuMetric: Bool {
        didSet { UserDefaults.standard.set(showCpuMetric, forKey: "VitalsDeck_ShowCpu") }
    }
    @Published public var showGpuMetric: Bool {
        didSet { UserDefaults.standard.set(showGpuMetric, forKey: "VitalsDeck_ShowGpu") }
    }
    @Published public var showRamMetric: Bool {
        didSet { UserDefaults.standard.set(showRamMetric, forKey: "VitalsDeck_ShowRam") }
    }
    @Published public var showNetMetric: Bool {
        didSet { UserDefaults.standard.set(showNetMetric, forKey: "VitalsDeck_ShowNet") }
    }
    @Published public var showStatusRow: Bool {
        didSet { UserDefaults.standard.set(showStatusRow, forKey: "VitalsDeck_ShowStatusRow") }
    }
    
    public init() {
        // Language: default to Russian if locale is ru, else English
        if let savedLang = UserDefaults.standard.string(forKey: "VitalsDeck_Language"),
           let l = AppLanguage(rawValue: savedLang) {
            self.language = l
        } else {
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            self.language = preferred.hasPrefix("ru") ? .ru : .en
        }
        
        let savedDisplay = UserDefaults.standard.string(forKey: "VitalsDeck_MenuBarDisplay") ?? MenuBarDisplayMode.cpuPercent.rawValue
        self.menuBarDisplay = MenuBarDisplayMode(rawValue: savedDisplay) ?? .cpuPercent
        
        let savedInterval = UserDefaults.standard.double(forKey: "VitalsDeck_UpdateInterval")
        self.updateInterval = UpdateIntervalMode(rawValue: savedInterval > 0 ? savedInterval : 4.0) ?? .eco
        
        // Modules (defaults to true)
        self.showTopConsumers = UserDefaults.standard.object(forKey: "VitalsDeck_ShowTopConsumers") as? Bool ?? true
        self.showCaffeine = UserDefaults.standard.object(forKey: "VitalsDeck_ShowCaffeine") as? Bool ?? true
        self.showHUDControls = UserDefaults.standard.object(forKey: "VitalsDeck_ShowHUDControls") as? Bool ?? true
        self.showThemeSelector = UserDefaults.standard.object(forKey: "VitalsDeck_ShowThemeSelector") as? Bool ?? true
        
        // Metrics (defaults to true)
        self.showCpuMetric = UserDefaults.standard.object(forKey: "VitalsDeck_ShowCpu") as? Bool ?? true
        self.showGpuMetric = UserDefaults.standard.object(forKey: "VitalsDeck_ShowGpu") as? Bool ?? true
        self.showRamMetric = UserDefaults.standard.object(forKey: "VitalsDeck_ShowRam") as? Bool ?? true
        self.showNetMetric = UserDefaults.standard.object(forKey: "VitalsDeck_ShowNet") as? Bool ?? true
        self.showStatusRow = UserDefaults.standard.object(forKey: "VitalsDeck_ShowStatusRow") as? Bool ?? true
        
        // Check Launch at Login
        checkLaunchAtLoginStatus()
    }
    
    public func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    public func setLaunchAtLogin(_ enabled: Bool) {
        self.launchAtLogin = enabled
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("SMAppService failed: \(error)")
            }
        }
    }
    
    public func resetToDefaults() {
        self.showTopConsumers = true
        self.showCaffeine = true
        self.showHUDControls = true
        self.showThemeSelector = true
        
        self.showCpuMetric = true
        self.showGpuMetric = true
        self.showRamMetric = true
        self.showNetMetric = true
        self.showStatusRow = true
        
        self.menuBarDisplay = .cpuPercent
        self.updateInterval = .eco
    }
}
