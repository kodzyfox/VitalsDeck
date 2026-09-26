import SwiftUI
import AppKit

public enum HUDLayout: String, CaseIterable, Identifiable {
    case card = "Card Box"
    case bar = "Horizontal Bar"
    
    public var id: String { rawValue }
}

public struct FloatingHUDView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var caffeine: CaffeineManager
    @ObservedObject var manager: FloatingHUDManager
    @Binding var currentTheme: AppTheme
    @Binding var hudLayout: HUDLayout
    @Binding var hudOpacity: Double
    var onClose: () -> Void
    
    @State private var isHovered: Bool = false
    
    public init(
        monitor: SystemMonitor = .shared,
        caffeine: CaffeineManager = .shared,
        manager: FloatingHUDManager = .shared,
        currentTheme: Binding<AppTheme>,
        hudLayout: Binding<HUDLayout>,
        hudOpacity: Binding<Double>,
        onClose: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.caffeine = caffeine
        self.manager = manager
        self._currentTheme = currentTheme
        self._hudLayout = hudLayout
        self._hudOpacity = hudOpacity
        self.onClose = onClose
    }
    
    private var effectiveOpacity: Double {
        if manager.autoHide && !isHovered {
            return 0.18
        }
        return hudOpacity
    }
    
    public var body: some View {
        Group {
            if hudLayout == .card {
                cardLayout
            } else {
                barLayout
            }
        }
        .opacity(effectiveOpacity)
        .animation(.easeInOut(duration: 0.2), value: effectiveOpacity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }
    
    // MARK: - Card Layout (Retro Cyber Box)
    private var cardLayout: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack(spacing: 6) {
                Text("┌ VITALS DECK")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                
                Spacer()
                
                if caffeine.isActive {
                    HStack(spacing: 3) {
                        Text("☕")
                            .font(.system(size: 10))
                        Text(caffeine.statusBadgeText)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(currentTheme.accent.opacity(0.2))
                    .foregroundColor(currentTheme.accent)
                    .cornerRadius(4)
                }
                
                // Snap to Corner Menu
                Menu {
                    ForEach(HUDCorner.allCases) { corner in
                        Button(action: {
                            manager.snapTo(corner: corner)
                        }) {
                            Text("Snap: \(corner.rawValue)")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(currentTheme.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Snap HUD to screen corner or notch")
                
                // Auto-Hide Toggle Button
                Button(action: {
                    manager.setAutoHide(!manager.autoHide)
                }) {
                    Image(systemName: manager.autoHide ? "eye.slash.fill" : "eye")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(manager.autoHide ? currentTheme.accent : currentTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(manager.autoHide ? "Auto-Hide Active (Fades to 18% when idle)" : "Enable Auto-Hide")
                
                // Switch Layout Button
                Button(action: {
                    withAnimation {
                        hudLayout = (hudLayout == .card ? .bar : .card)
                    }
                }) {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(currentTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Switch to compact bar layout")
                
                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(currentTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Hide HUD")
            }
            
            Divider()
                .background(currentTheme.border)
            
            // Core Metrics
            VStack(spacing: 5) {
                // CPU
                AsciiMeterView(
                    label: "CPU",
                    value: monitor.cpuUsage,
                    detail: monitor.cpuTemperatureString,
                    theme: currentTheme,
                    isHighlighted: monitor.cpuUsage > 80,
                    totalBlocks: 10
                )
                
                // GPU
                AsciiMeterView(
                    label: "GPU",
                    value: monitor.gpuUsage,
                    detail: monitor.gpuTemperatureString,
                    theme: currentTheme,
                    isHighlighted: monitor.gpuUsage > 80,
                    totalBlocks: 10
                )
                
                // RAM
                AsciiMeterView(
                    label: "RAM",
                    value: monitor.ramUsagePercent,
                    detail: SystemMonitor.formatBytesTotal(monitor.ramUsedBytes),
                    theme: currentTheme,
                    isHighlighted: monitor.ramUsagePercent > 85,
                    totalBlocks: 10
                )
                
                // Network
                NetworkWaveView(
                    historyDown: monitor.netHistoryDown,
                    historyUp: monitor.netHistoryUp,
                    downSpeed: monitor.netDownloadBps,
                    upSpeed: monitor.netUploadBps,
                    theme: currentTheme
                )
            }
            
            Divider()
                .background(currentTheme.border)
            
            // Footer: System Status
            HStack {
                Text("└ STATUS: \(monitor.thermalDescription.uppercased())")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                
                Spacer()
                
                if let bat = monitor.batteryPercent {
                    HStack(spacing: 2) {
                        Image(systemName: monitor.isCharging ? "bolt.fill" : (monitor.isAcPowered ? "powerplug.fill" : "battery.75"))
                            .font(.system(size: 8))
                        Text("\(bat)%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(currentTheme.textSecondary)
                }
                
                Text("UP: \(monitor.uptimeString)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(currentTheme.background.opacity(0.85))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(currentTheme.border, lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Bar Layout (Ultra Minimal Strip)
    private var barLayout: some View {
        HStack(spacing: 12) {
            // CPU
            HStack(spacing: 4) {
                Text("CPU")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                Text(String(format: "%.0f%%", monitor.cpuUsage))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(currentTheme.textPrimary)
                Text(monitor.cpuTemperatureString)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
            }
            
            Text("│")
                .foregroundColor(currentTheme.border)
            
            // GPU
            HStack(spacing: 4) {
                Text("GPU")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                Text(String(format: "%.0f%%", monitor.gpuUsage))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(currentTheme.textPrimary)
                if !monitor.gpuTemperatureString.isEmpty {
                    Text(monitor.gpuTemperatureString)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(currentTheme.textSecondary)
                }
            }
            
            Text("│")
                .foregroundColor(currentTheme.border)
            
            // RAM
            HStack(spacing: 4) {
                Text("RAM")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentTheme.accent)
                Text(String(format: "%.0f%%", monitor.ramUsagePercent))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(currentTheme.textPrimary)
            }
            
            Text("│")
                .foregroundColor(currentTheme.border)
            
            // NET
            HStack(spacing: 5) {
                Text("↓\(SystemMonitor.formatBytesRate(monitor.netDownloadBps))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(currentTheme.textPrimary)
                Text("↑\(SystemMonitor.formatBytesRate(monitor.netUploadBps))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(currentTheme.textSecondary)
            }
            
            if caffeine.isActive {
                Text("│")
                    .foregroundColor(currentTheme.border)
                HStack(spacing: 2) {
                    Text("☕")
                        .font(.system(size: 9))
                    Text(caffeine.statusBadgeText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(currentTheme.accent)
                }
            }
            
            Spacer(minLength: 4)
            
            // Snap to Corner Menu
            Menu {
                ForEach(HUDCorner.allCases) { corner in
                    Button(action: {
                        manager.snapTo(corner: corner)
                    }) {
                        Text("Snap: \(corner.rawValue)")
                    }
                }
            } label: {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(currentTheme.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Snap HUD to screen corner or notch")
            
            // Auto-Hide Toggle
            Button(action: {
                manager.setAutoHide(!manager.autoHide)
            }) {
                Image(systemName: manager.autoHide ? "eye.slash.fill" : "eye")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(manager.autoHide ? currentTheme.accent : currentTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(manager.autoHide ? "Auto-Hide Active (Fades to 18% when idle)" : "Enable Auto-Hide")
            
            // Toggle to card layout
            Button(action: {
                withAnimation {
                    hudLayout = .card
                }
            }) {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(currentTheme.textSecondary)
            }
            .buttonStyle(.plain)
            
            // Close
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(currentTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(currentTheme.background.opacity(0.85))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(currentTheme.border, lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}
