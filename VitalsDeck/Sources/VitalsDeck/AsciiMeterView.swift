import SwiftUI

// MARK: - ASCII / Segmented Meter View
public struct AsciiMeterView: View {
    public let label: String
    public let value: Double // 0.0 to 100.0
    public let detail: String
    public let theme: AppTheme
    public var isHighlighted: Bool = false
    public var totalBlocks: Int = 12
    
    public init(
        label: String,
        value: Double,
        detail: String = "",
        theme: AppTheme,
        isHighlighted: Bool = false,
        totalBlocks: Int = 12
    ) {
        self.label = label
        self.value = value
        self.detail = detail
        self.theme = theme
        self.isHighlighted = isHighlighted
        self.totalBlocks = totalBlocks
    }
    
    private var filledBlocksCount: Int {
        let clamped = max(0.0, min(100.0, value))
        return Int((clamped / 100.0 * Double(totalBlocks)).rounded())
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Label
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.accent)
                .frame(width: 36, alignment: .leading)
            
            // Bar Blocks
            HStack(spacing: 2) {
                ForEach(0..<totalBlocks, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(index < filledBlocksCount ? (isHighlighted ? theme.accentSecondary : theme.meterFilled) : theme.meterEmpty)
                        .frame(width: 8, height: 11)
                }
            }
            
            Spacer(minLength: 4)
            
            // Percentage
            Text(String(format: "%2.0f%%", value))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .frame(width: 36, alignment: .trailing)
            
            // Detail (e.g. °C, GB, etc.)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Sparkline Wave View
public struct NetworkWaveView: View {
    public let historyDown: [Double]
    public let historyUp: [Double]
    public let downSpeed: Double
    public let upSpeed: Double
    public let theme: AppTheme
    
    public init(
        historyDown: [Double],
        historyUp: [Double],
        downSpeed: Double,
        upSpeed: Double,
        theme: AppTheme
    ) {
        self.historyDown = historyDown
        self.historyUp = historyUp
        self.downSpeed = downSpeed
        self.upSpeed = upSpeed
        self.theme = theme
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("NET")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.accent)
                    .frame(width: 36, alignment: .leading)
                
                // Live speeds
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(theme.accent)
                        Text(SystemMonitor.formatBytesRate(downSpeed))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(theme.accentSecondary)
                        Text(SystemMonitor.formatBytesRate(upSpeed))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            // Mini ASCII / Wave Graph: ~~~~~~~~
            HStack(spacing: 2) {
                ForEach(0..<max(historyDown.count, 16), id: \.self) { idx in
                    let val = idx < historyDown.count ? historyDown[idx] : 0.0
                    let maxVal = max(50_000, (historyDown.max() ?? 100_000))
                    let normalized = min(1.0, val / maxVal)
                    let barH = max(2.0, normalized * 16.0)
                    
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 1)
                            .fill(val > 1024 ? theme.accent : theme.meterEmpty)
                            .frame(width: 7, height: CGFloat(barH))
                    }
                    .frame(height: 16)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }
}
