import Foundation
import Combine
import IOKit.pwr_mgt
import AppKit

public enum CaffeineDuration: Hashable, Identifiable {
    case minutes20
    case minutes30
    case hours1
    case hours2
    case hours3
    case indefinite
    case custom(minutes: Int)
    
    public var id: String {
        switch self {
        case .minutes20: return "20m"
        case .minutes30: return "30m"
        case .hours1: return "1h"
        case .hours2: return "2h"
        case .hours3: return "3h"
        case .indefinite: return "inf"
        case .custom(let m): return "c_\(m)"
        }
    }
    
    public var label: String {
        switch self {
        case .minutes20: return "20m"
        case .minutes30: return "30m"
        case .hours1: return "1h"
        case .hours2: return "2h"
        case .hours3: return "3h"
        case .indefinite: return "∞ Until Off"
        case .custom(let m): return "\(m)m"
        }
    }
    
    public var totalSeconds: TimeInterval? {
        switch self {
        case .minutes20: return 20 * 60
        case .minutes30: return 30 * 60
        case .hours1: return 60 * 60
        case .hours2: return 120 * 60
        case .hours3: return 180 * 60
        case .indefinite: return nil
        case .custom(let m): return TimeInterval(m * 60)
        }
    }
}

@MainActor
public final class CaffeineManager: ObservableObject {
    public static let shared = CaffeineManager()
    
    @Published public var isActive: Bool = false
    @Published public var currentDuration: CaffeineDuration = .minutes30
    @Published public var remainingSeconds: TimeInterval = 0
    @Published public var preventDisplaySleep: Bool = true
    @Published public var customMinutes: Int = 45
    
    private var assertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?
    
    public init() {}
    
    isolated deinit {
        if assertionID != 0 {
            _ = IOPMAssertionRelease(assertionID)
        }
        if displayAssertionID != 0 {
            _ = IOPMAssertionRelease(displayAssertionID)
        }
        countdownTimer?.invalidate()
    }
    
    public func toggleCaffeine(duration: CaffeineDuration? = nil) {
        if isActive {
            stopCaffeine()
        } else {
            startCaffeine(duration: duration ?? currentDuration)
        }
    }
    
    public func startCaffeine(duration: CaffeineDuration) {
        stopCaffeine()
        self.currentDuration = duration
        
        let reason = "SignalDesk Caffeine Mode" as CFString
        
        // System sleep prevention
        let sysResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        
        // Optional display sleep prevention
        if preventDisplaySleep {
            _ = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayAssertionID
            )
        }
        
        if sysResult == kIOReturnSuccess {
            isActive = true
            if let totalSec = duration.totalSeconds {
                remainingSeconds = totalSec
                startTimer()
            } else {
                remainingSeconds = 0 // Indefinite
            }
        }
    }
    
    public func stopCaffeine() {
        if assertionID != 0 {
            _ = IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        if displayAssertionID != 0 {
            _ = IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
        countdownTimer?.invalidate()
        countdownTimer = nil
        isActive = false
        remainingSeconds = 0
    }
    
    private func startTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.stopCaffeine()
                    NSSound.beep()
                }
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }
    
    public var formattedRemainingTime: String {
        guard isActive else { return "OFF" }
        if currentDuration.totalSeconds == nil {
            return "Active (∞)"
        }
        let total = Int(remainingSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    public var statusBadgeText: String {
        if !isActive { return "OFF" }
        if currentDuration.totalSeconds == nil { return "∞ INDEF" }
        let total = Int(remainingSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
