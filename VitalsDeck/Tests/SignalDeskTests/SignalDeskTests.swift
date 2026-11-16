import Testing
@testable import VitalsDeck

@Test func caffeineDurationsExposeExpectedSeconds() {
    #expect(CaffeineDuration.minutes20.totalSeconds == 1_200)
    #expect(CaffeineDuration.minutes30.totalSeconds == 1_800)
    #expect(CaffeineDuration.hours1.totalSeconds == 3_600)
    #expect(CaffeineDuration.hours3.totalSeconds == 10_800)
    #expect(CaffeineDuration.indefinite.totalSeconds == nil)
    #expect(CaffeineDuration.custom(minutes: 45).totalSeconds == 2_700)
}

@Test func caffeineDurationLabelsAreStable() {
    #expect(CaffeineDuration.minutes20.label == "20m")
    #expect(CaffeineDuration.indefinite.label == "∞ Until Off")
    #expect(CaffeineDuration.custom(minutes: 45).label == "45m")
}

@Test @MainActor func cpuCounterDeltaIgnoresCounterReset() {
    #expect(SystemMonitor.cpuCounterDelta(15, 10) == 5)
    #expect(SystemMonitor.cpuCounterDelta(4, 10) == 0)
}
