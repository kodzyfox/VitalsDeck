import SwiftUI

public struct VitalsDeckPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var caffeine: CaffeineManager
    @ObservedObject var hud: FloatingHUDManager
    @ObservedObject var processMonitor: ProcessMonitor
    @ObservedObject var settings: AppSettings
    @AppStorage("VitalsDeck_CurrentTheme") private var storedTheme: String = AppTheme.signalAmber.rawValue
    
    @State private var showingSettings: Bool = false
    @State private var showingCustomDurationPicker: Bool = false
    @State private var tempCustomMinutes: Double = 45.0
    @State private var confirmingKillPid: Int32? = nil
    @State private var killFeedbackMessage: String? = nil
    @State private var resetTimer: Timer? = nil
    
    public init(
        monitor: SystemMonitor = .shared,
        caffeine: CaffeineManager = .shared,
        hud: FloatingHUDManager = .shared,
        processMonitor: ProcessMonitor = .shared,
        settings: AppSettings = .shared
    ) {
        self.monitor = monitor
        self.caffeine = caffeine
        self.hud = hud
        self.processMonitor = processMonitor
        self.settings = settings
    }
    
    private var currentTheme: AppTheme {
        AppTheme(rawValue: storedTheme) ?? .signalAmber
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Header Bar
                headerBar
                
                if showingSettings {
                    settingsView
                } else {
                    mainDashboardView
                }
            }
            .padding(14)
        }
        .frame(width: 330)
        .frame(maxHeight: 640)
        .background(currentTheme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(currentTheme.border, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("VITALS DECK")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                Text(L10n.tr(.appSubtitle, settings.language))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
            }
            
            Spacer()
            
            // Quick HUD toggle pill
            Button(action: {
                hud.toggleHUD()
            }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(hud.isVisible ? currentTheme.accent : currentTheme.meterEmpty)
                        .frame(width: 6, height: 6)
                    Text("HUD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(hud.isVisible ? currentTheme.accent : currentTheme.textSecondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(currentTheme.surface)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(hud.isVisible ? currentTheme.accent.opacity(0.5) : currentTheme.border, lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .help(settings.language == .ru ? "Переключить плавающий HUD" : "Toggle Floating HUD on/off")
            
            // Quick Caffeine toggle pill
            Button(action: {
                caffeine.toggleCaffeine()
            }) {
                HStack(spacing: 4) {
                    Text("☕")
                        .font(.system(size: 10))
                    Text(caffeine.isActive ? caffeine.statusBadgeText : "OFF")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(caffeine.isActive ? currentTheme.accent : currentTheme.textSecondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(currentTheme.surface)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(caffeine.isActive ? currentTheme.accent.opacity(0.6) : currentTheme.border, lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .help(settings.language == .ru ? "Переключить режим Caffeine" : "Toggle Caffeine mode on/off")
            
            // Quick Settings Gear Button
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showingSettings.toggle()
                }
            }) {
                Image(systemName: showingSettings ? "xmark" : "gearshape.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(showingSettings ? currentTheme.accent : currentTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(currentTheme.surface)
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(showingSettings ? currentTheme.accent.opacity(0.8) : currentTheme.border, lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
            .help(showingSettings ? (settings.language == .ru ? "Вернуться в дашборд" : "Back to Dashboard") : (settings.language == .ru ? "Настройки и конфигурация" : "Settings & Configuration"))
        }
    }
    
    // MARK: - Main Dashboard
    private var mainDashboardView: some View {
        VStack(spacing: 10) {
            // Telemetry Panel
            telemetryBox
            
            // Top Consumers (if enabled)
            if settings.showTopConsumers {
                topProcessesBox
            }
            
            // Caffeine Mode (if enabled)
            if settings.showCaffeine {
                caffeineBox
            }
            
            // HUD & Display Options (if enabled)
            if settings.showHUDControls {
                hudControlsBox
            }
            
            // Theme Selector (if enabled)
            if settings.showThemeSelector {
                themeSelectorBox
            }
            
            // Footer
            footerBar
        }
    }
    
    // MARK: - Telemetry Box
    private var telemetryBox: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("┌ \(L10n.tr(.telemetry, settings.language))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                Spacer()
                Text("\(monitor.cpuModelName)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
                    .lineLimit(1)
            }
            
            // CPU
            if settings.showCpuMetric {
                AsciiMeterView(
                    label: "CPU",
                    value: monitor.cpuUsage,
                    detail: monitor.cpuTemperatureString,
                    theme: currentTheme,
                    isHighlighted: monitor.cpuUsage > 80,
                    totalBlocks: 12
                )
            }
            
            // GPU
            if settings.showGpuMetric {
                let gpuDetail = monitor.gpuTemperatureString.isEmpty ? monitor.gpuModelName : monitor.gpuTemperatureString
                AsciiMeterView(
                    label: "GPU",
                    value: monitor.gpuUsage,
                    detail: gpuDetail,
                    theme: currentTheme,
                    isHighlighted: monitor.gpuUsage > 80,
                    totalBlocks: 12
                )
            }
            
            // RAM
            if settings.showRamMetric {
                AsciiMeterView(
                    label: "RAM",
                    value: monitor.ramUsagePercent,
                    detail: "\(SystemMonitor.formatBytesTotal(monitor.ramUsedBytes)) / \(SystemMonitor.formatBytesTotal(monitor.ramTotalBytes))",
                    theme: currentTheme,
                    isHighlighted: monitor.ramUsagePercent > 85,
                    totalBlocks: 12
                )
            }
            
            // Network
            if settings.showNetMetric {
                NetworkWaveView(
                    historyDown: monitor.netHistoryDown,
                    historyUp: monitor.netHistoryUp,
                    downSpeed: monitor.netDownloadBps,
                    upSpeed: monitor.netUploadBps,
                    theme: currentTheme
                )
            }
            
            // Thermal & Status row
            if settings.showStatusRow {
                HStack {
                    Text("└ STATUS: \(localizedThermalStatus)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.accent)
                    
                    if let ssd = monitor.ssdTemperature {
                        Text("• SSD: \(String(format: "%.0f°C", ssd))")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(currentTheme.textSecondary)
                    }
                    
                    Spacer()
                    if let bat = monitor.batteryPercent {
                        HStack(spacing: 2) {
                            Image(systemName: monitor.isCharging ? "bolt.fill" : (monitor.isAcPowered ? "powerplug.fill" : "battery.75"))
                                .font(.system(size: 8))
                            Text("\(bat)%")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            if let batTemp = monitor.batteryTemperature {
                                Text("(\(String(format: "%.0f°C", batTemp)))")
                                    .font(.system(size: 7, design: .monospaced))
                            }
                        }
                        .foregroundColor(currentTheme.textSecondary)
                    }
                    Text("UP: \(monitor.uptimeString)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(currentTheme.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(currentTheme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.border, lineWidth: 1.0)
        )
    }
    
    private var localizedThermalStatus: String {
        switch monitor.thermalState {
        case .nominal: return L10n.tr(.statusNominal, settings.language)
        case .fair: return L10n.tr(.statusFair, settings.language)
        case .serious: return L10n.tr(.statusSerious, settings.language)
        case .critical: return L10n.tr(.statusCritical, settings.language)
        @unknown default: return monitor.thermalDescription.uppercased()
        }
    }
    
    // MARK: - Top Consumers Box (Kill Switch)
    private var topProcessesBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("┌ \(L10n.tr(.topConsumers, settings.language))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                
                Spacer()
                
                // Sort Buttons: CPU / RAM
                HStack(spacing: 3) {
                    ForEach(ProcessSortMode.allCases) { mode in
                        let isSelected = processMonitor.sortMode == mode
                        Button(action: {
                            processMonitor.sortMode = mode
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(isSelected ? currentTheme.background : currentTheme.textSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(isSelected ? currentTheme.accent : currentTheme.background)
                                .cornerRadius(3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Refresh Button
                Button(action: {
                    processMonitor.refreshProcesses()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(currentTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(settings.language == .ru ? "Обновить список процессов" : "Refresh top processes")
            }
            
            if processMonitor.topProcesses.isEmpty {
                HStack {
                    Spacer()
                    Text(settings.language == .ru ? "Сканирование процессов..." : "Scanning active processes...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(currentTheme.textSecondary)
                        .padding(.vertical, 4)
                    Spacer()
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(processMonitor.topProcesses.enumerated()), id: \.element.id) { index, proc in
                        processRow(index: index + 1, proc: proc)
                    }
                }
            }
            
            // Status footer or message
            if let status = killFeedbackMessage ?? processMonitor.lastKillStatus {
                HStack {
                    Text("└ \(status)")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(status.contains("Killed") || status.contains("Terminated") ? currentTheme.accent : currentTheme.accentSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.top, 1)
            }
        }
        .padding(10)
        .background(currentTheme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.border, lineWidth: 1.0)
        )
    }
    
    private func processRow(index: Int, proc: MonitoredProcess) -> some View {
        let isConfirming = confirmingKillPid == proc.pid
        
        return HStack(spacing: 6) {
            // Index
            Text("\(index).")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(currentTheme.accent)
                .frame(width: 14, alignment: .leading)
            
            // App Icon
            if let icon = proc.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 13, height: 13)
                    .cornerRadius(2)
            } else {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 8))
                    .foregroundColor(currentTheme.textSecondary)
                    .frame(width: 13, height: 13)
            }
            
            // Process Name & PID
            VStack(alignment: .leading, spacing: 0) {
                Text(proc.name)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(currentTheme.textPrimary)
                    .lineLimit(1)
                
                Text("#\(proc.pid)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Usage Metric
            HStack(spacing: 3) {
                if processMonitor.sortMode == .cpu {
                    Text(String(format: "%.1f%%", proc.cpuPercent))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(proc.cpuPercent > 50 ? currentTheme.accentSecondary : currentTheme.textPrimary)
                } else {
                    Text(proc.memFormatted)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(proc.memPercent > 20 ? currentTheme.accentSecondary : currentTheme.textPrimary)
                }
            }
            .frame(width: 52, alignment: .trailing)
            
            // Kill Action Button
            if proc.isSystemProtected {
                Text("[SYS]")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary.opacity(0.6))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(currentTheme.background.opacity(0.5))
                    .cornerRadius(3)
                    .help(settings.language == .ru ? "Системный защищённый процесс (нельзя завершить)" : "Protected system process (cannot be killed)")
            } else {
                Button(action: {
                    handleKillClicked(for: proc)
                }) {
                    Text(isConfirming ? "KILL?" : "KILL")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(isConfirming ? .white : currentTheme.accentSecondary)
                        .padding(.horizontal, isConfirming ? 5 : 4)
                        .padding(.vertical, 2)
                        .background(isConfirming ? Color.red : currentTheme.accentSecondary.opacity(0.15))
                        .cornerRadius(3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(isConfirming ? Color.white.opacity(0.8) : currentTheme.accentSecondary.opacity(0.4), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .help(isConfirming ? (settings.language == .ru ? "Нажмите ещё раз для принудительного завершения" : "Click again to FORCE KILL") : (settings.language == .ru ? "Завершить процесс" : "Terminate process"))
            }
        }
        .padding(.vertical, 2)
    }
    
    private func handleKillClicked(for proc: MonitoredProcess) {
        if confirmingKillPid == proc.pid {
            // Confirmed! Execute Force Kill
            resetTimer?.invalidate()
            confirmingKillPid = nil
            let success = processMonitor.killProcess(pid: proc.pid, force: true)
            if success {
                killFeedbackMessage = settings.language == .ru ? "Завершён '\(proc.name)' (#\(proc.pid))" : "Terminated '\(proc.name)' (#\(proc.pid))"
            } else {
                killFeedbackMessage = settings.language == .ru ? "Не удалось завершить #\(proc.pid)" : "Failed to terminate #\(proc.pid)"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if killFeedbackMessage?.contains("\(proc.pid)") == true {
                    killFeedbackMessage = nil
                }
            }
        } else {
            // First click - ask confirmation
            confirmingKillPid = proc.pid
            resetTimer?.invalidate()
            resetTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
                Task { @MainActor in
                    if confirmingKillPid == proc.pid {
                        confirmingKillPid = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Caffeine Box
    private var caffeineBox: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 4) {
                    Text("☕")
                        .font(.system(size: 11))
                    Text(L10n.tr(.caffeineMode, settings.language))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.accent)
                }
                Spacer()
                Text(caffeine.isActive ? caffeine.formattedRemainingTime : (settings.language == .ru ? "Отключено" : "Inactive"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(caffeine.isActive ? currentTheme.accent : currentTheme.textSecondary)
            }
            
            // Presets grid
            HStack(spacing: 5) {
                presetButton(label: "20m", duration: .minutes20)
                presetButton(label: "30m", duration: .minutes30)
                presetButton(label: "1h", duration: .hours1)
                presetButton(label: "2h", duration: .hours2)
                presetButton(label: "3h", duration: .hours3)
                presetButton(label: "∞ Off", duration: .indefinite)
            }
            
            // Custom time toggle & slider
            HStack {
                Button(action: {
                    showingCustomDurationPicker.toggle()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 9))
                        Text(showingCustomDurationPicker ? L10n.tr(.hideCustom, settings.language) : L10n.tr(.customDuration, settings.language))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(currentTheme.textSecondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Prevent display sleep toggle
                Toggle(isOn: $caffeine.preventDisplaySleep) {
                    Text(L10n.tr(.keepScreenOn, settings.language))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(currentTheme.textSecondary)
                }
                .toggleStyle(.checkbox)
            }
            
            if showingCustomDurationPicker {
                VStack(spacing: 4) {
                    HStack {
                        Text(settings.language == .ru ? "Своё: \(Int(tempCustomMinutes)) мин" : "Custom: \(Int(tempCustomMinutes)) min")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(currentTheme.textPrimary)
                        Spacer()
                        Button(action: {
                            caffeine.startCaffeine(duration: .custom(minutes: Int(tempCustomMinutes)))
                        }) {
                            Text(settings.language == .ru ? "Старт \(Int(tempCustomMinutes))м" : "Start \(Int(tempCustomMinutes))m")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(currentTheme.background)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(currentTheme.accent)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Slider(value: $tempCustomMinutes, in: 5...360, step: 5)
                        .accentColor(currentTheme.accent)
                }
                .padding(6)
                .background(currentTheme.background.opacity(0.6))
                .cornerRadius(5)
            }
            
            // Master Action Button
            Button(action: {
                caffeine.toggleCaffeine()
            }) {
                HStack {
                    Spacer()
                    Text(caffeine.isActive ? L10n.tr(.stopCaffeine, settings.language) : L10n.tr(.keepMacAwake, settings.language))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(caffeine.isActive ? currentTheme.background : currentTheme.background)
                    Spacer()
                }
                .padding(.vertical, 6)
                .background(caffeine.isActive ? currentTheme.accentSecondary : currentTheme.accent)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(currentTheme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.border, lineWidth: 1.0)
        )
    }
    
    private func presetButton(label: String, duration: CaffeineDuration) -> some View {
        let isSelected = caffeine.isActive && caffeine.currentDuration == duration
        return Button(action: {
            caffeine.startCaffeine(duration: duration)
        }) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? currentTheme.background : currentTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(isSelected ? currentTheme.accent : currentTheme.background)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? currentTheme.accent : currentTheme.border, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - HUD Controls Box
    private var hudControlsBox: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(L10n.tr(.hudOverlay, settings.language))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                Spacer()
                Button(action: {
                    hud.toggleHUD()
                }) {
                    Text(hud.isVisible ? L10n.tr(.visible, settings.language) : L10n.tr(.hidden, settings.language))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(hud.isVisible ? currentTheme.accent : currentTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 8) {
                // Layout Picker
                Picker("", selection: $hud.layout) {
                    ForEach(HUDLayout.allCases) { lay in
                        Text(lay.rawValue).tag(lay)
                    }
                }
                .pickerStyle(.segmented)
                
                // Opacity slider
                HStack(spacing: 4) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 9))
                        .foregroundColor(currentTheme.textSecondary)
                    Slider(value: $hud.opacity, in: 0.3...1.0)
                        .accentColor(currentTheme.accent)
                }
                .frame(width: 90)
            }
            
            // Corner Snap Buttons row
            HStack(spacing: 4) {
                Text(L10n.tr(.snapLabel, settings.language))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
                ForEach(HUDCorner.allCases) { corner in
                    Button(action: {
                        hud.snapTo(corner: corner)
                    }) {
                        Text(corner.symbol)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(currentTheme.background)
                            .foregroundColor(currentTheme.textPrimary)
                            .cornerRadius(3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(currentTheme.border, lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(settings.language == .ru ? "Привязать HUD: \(corner.rawValue)" : "Snap HUD to \(corner.rawValue)")
                }
            }
            
            // Auto-Hide & Magnetic Snap Toggles
            HStack {
                Toggle(isOn: Binding(
                    get: { hud.autoHide },
                    set: { hud.setAutoHide($0) }
                )) {
                    HStack(spacing: 3) {
                        Image(systemName: hud.autoHide ? "eye.slash" : "eye")
                            .font(.system(size: 9))
                        Text(L10n.tr(.autoHide, settings.language))
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(currentTheme.textSecondary)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Toggle(isOn: Binding(
                    get: { hud.magneticSnap },
                    set: { hud.setMagneticSnap($0) }
                )) {
                    HStack(spacing: 3) {
                        Image(systemName: "magnet")
                            .font(.system(size: 9))
                        Text(L10n.tr(.edgeMagnet, settings.language))
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(currentTheme.textSecondary)
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding(10)
        .background(currentTheme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.border, lineWidth: 1.0)
        )
    }
    
    // MARK: - Theme Selector Box
    private var themeSelectorBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr(.visualThemes, settings.language))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(currentTheme.accent)
            
            HStack(spacing: 5) {
                ForEach(AppTheme.allCases) { theme in
                    let isSelected = theme == currentTheme
                    Button(action: {
                        storedTheme = theme.rawValue
                    }) {
                        VStack(spacing: 3) {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(isSelected ? 0.9 : 0.0), lineWidth: 1.5)
                                )
                            Text(theme.displayName.components(separatedBy: " ").first ?? "")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundColor(isSelected ? theme.accent : currentTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(isSelected ? currentTheme.background : Color.clear)
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isSelected ? currentTheme.accent.opacity(0.8) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(theme.subtitle)
                }
            }
        }
        .padding(10)
        .background(currentTheme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.border, lineWidth: 1.0)
        )
    }
    
    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            Text("VITALS DECK v1.1")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(currentTheme.textSecondary.opacity(0.7))
            
            Spacer()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "power")
                        .font(.system(size: 8))
                    Text(L10n.tr(.quitLabel, settings.language))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(currentTheme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(currentTheme.surface)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help(settings.language == .ru ? "Выйти из Vitals Deck" : "Quit Vitals Deck")
        }
    }
    
    // MARK: - Settings View (Modular Config)
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Dashboard Modules
            modulesSettingsBox
            
            // Metrics Bars
            metricsSettingsBox
            
            // System & General
            generalSettingsBox
            
            // Actions & Back
            settingsFooterActions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var modulesSettingsBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("┌ \(L10n.tr(.modulesSection, settings.language))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                settingToggleRow(
                    title: L10n.tr(.topConsumers, settings.language),
                    icon: "flame",
                    isOn: $settings.showTopConsumers
                )
                settingToggleRow(
                    title: L10n.tr(.caffeineMode, settings.language),
                    icon: "cup.and.saucer",
                    isOn: $settings.showCaffeine
                )
                settingToggleRow(
                    title: L10n.tr(.hudOverlay, settings.language),
                    icon: "macwindow.on.rectangle",
                    isOn: $settings.showHUDControls
                )
                settingToggleRow(
                    title: L10n.tr(.visualThemes, settings.language),
                    icon: "paintpalette",
                    isOn: $settings.showThemeSelector
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(currentTheme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.border, lineWidth: 1.0)
        )
    }
    
    private var metricsSettingsBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("┌ \(L10n.tr(.telemetryMetricsSection, settings.language))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                settingToggleRow(
                    title: L10n.tr(.cpuLoadTemp, settings.language),
                    icon: "cpu",
                    isOn: $settings.showCpuMetric
                )
                settingToggleRow(
                    title: L10n.tr(.gpuUtilization, settings.language),
                    icon: "display",
                    isOn: $settings.showGpuMetric
                )
                settingToggleRow(
                    title: L10n.tr(.ramBreakdown, settings.language),
                    icon: "memorychip",
                    isOn: $settings.showRamMetric
                )
                settingToggleRow(
                    title: L10n.tr(.networkWaveSpeed, settings.language),
                    icon: "waveform.path",
                    isOn: $settings.showNetMetric
                )
                settingToggleRow(
                    title: L10n.tr(.statusBatteryUptime, settings.language),
                    icon: "bolt",
                    isOn: $settings.showStatusRow
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(currentTheme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.border, lineWidth: 1.0)
        )
    }
    
    private var generalSettingsBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("┌ \(L10n.tr(.generalSection, settings.language))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                Spacer()
            }
            
            // Language selector
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr(.languageLabel, settings.language))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
                
                HStack(spacing: 6) {
                    ForEach(AppLanguage.allCases) { lang in
                        let isSelected = settings.language == lang
                        Button(action: {
                            settings.language = lang
                        }) {
                            HStack(spacing: 4) {
                                Text(lang.flag)
                                Text(lang.rawValue)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(isSelected ? currentTheme.accent : currentTheme.background)
                            .foregroundColor(isSelected ? currentTheme.background : currentTheme.textPrimary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isSelected ? currentTheme.accent : currentTheme.border, lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider().background(currentTheme.border)
            
            // Menu Bar Display selector
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr(.menuBarDisplayLabel, settings.language))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        let isSelected = settings.menuBarDisplay == mode
                        Button(action: {
                            settings.menuBarDisplay = mode
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 3)
                                .background(isSelected ? currentTheme.accent : currentTheme.background)
                                .foregroundColor(isSelected ? currentTheme.background : currentTheme.textPrimary)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(isSelected ? currentTheme.accent : currentTheme.border, lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider().background(currentTheme.border)
            
            // Update Interval
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr(.updateIntervalLabel, settings.language))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
                
                HStack(spacing: 4) {
                    ForEach(UpdateIntervalMode.allCases) { interval in
                        let isSelected = settings.updateInterval == interval
                        Button(action: {
                            settings.updateInterval = interval
                        }) {
                            Text(interval.label(lang: settings.language))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 3)
                                .background(isSelected ? currentTheme.accent : currentTheme.background)
                                .foregroundColor(isSelected ? currentTheme.background : currentTheme.textPrimary)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(isSelected ? currentTheme.accent : currentTheme.border, lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider().background(currentTheme.border)
            
            // Launch at Startup toggle
            Toggle(isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            )) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9))
                    Text(L10n.tr(.launchAtLoginLabel, settings.language))
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(currentTheme.textPrimary)
            }
            .toggleStyle(.checkbox)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(currentTheme.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.border, lineWidth: 1.0)
        )
    }
    
    private var settingsFooterActions: some View {
        HStack {
            Button(action: {
                settings.resetToDefaults()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8))
                    Text(L10n.tr(.resetDefaultsLabel, settings.language))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(currentTheme.accentSecondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showingSettings = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 8, weight: .bold))
                    Text(L10n.tr(.backToDeck, settings.language))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundColor(currentTheme.background)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(currentTheme.accent)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
    }
    
    private func settingToggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .frame(width: 14)
                    .foregroundColor(isOn.wrappedValue ? currentTheme.accent : currentTheme.textSecondary)
                Text(title)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(isOn.wrappedValue ? currentTheme.textPrimary : currentTheme.textSecondary)
                Spacer()
            }
        }
        .toggleStyle(.checkbox)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}
