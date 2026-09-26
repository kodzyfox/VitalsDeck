import Foundation
import AppKit
import Darwin

// libproc private SPI for direct process info without forking /bin/ps
private let PROC_PIDTASKINFO: Int32 = 4
private let MAXPATHLEN = 1024

private struct proc_taskinfo {
    var pti_virtual_size: UInt64 = 0
    var pti_resident_size: UInt64 = 0
    var pti_total_user: UInt64 = 0
    var pti_total_system: UInt64 = 0
    var pti_threads_user: UInt64 = 0
    var pti_threads_system: UInt64 = 0
    var pti_policy: Int32 = 0
    var pti_faults: Int32 = 0
    var pti_pageins: Int32 = 0
    var pti_cow_faults: Int32 = 0
    var pti_messages_sent: Int32 = 0
    var pti_messages_received: Int32 = 0
    var pti_syscalls_mach: Int32 = 0
    var pti_syscalls_unix: Int32 = 0
    var pti_csw: Int32 = 0
    var pti_threadnum: Int32 = 0
    var pti_numrunning: Int32 = 0
    var pti_priority: Int32 = 0
}

@_silgen_name("proc_pidinfo")
private func proc_pidinfo(
    _ pid: Int32,
    _ flavor: Int32,
    _ arg: UInt64,
    _ buffer: UnsafeMutableRawPointer,
    _ buffersize: Int32
) -> Int32

@_silgen_name("proc_name")
private func proc_name(_ pid: Int32, _ buffer: UnsafeMutablePointer<CChar>, _ buffersize: UInt32) -> Int32

@_silgen_name("proc_listallpids")
private func proc_listallpids(_ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

public enum ProcessSortMode: String, CaseIterable, Identifiable, Sendable {
    case cpu = "CPU"
    case ram = "RAM"

    public var id: String { rawValue }
}

public struct MonitoredProcess: Identifiable, Equatable, @unchecked Sendable {
    public let id: Int32
    public let pid: Int32
    public let name: String
    public let command: String
    public let cpuPercent: Double
    public let memPercent: Double
    public let memBytes: UInt64
    public let memFormatted: String
    public let isSystemProtected: Bool
    public let appIcon: NSImage?

    public static func == (lhs: MonitoredProcess, rhs: MonitoredProcess) -> Bool {
        lhs.pid == rhs.pid &&
        lhs.cpuPercent == rhs.cpuPercent &&
        lhs.memPercent == rhs.memPercent &&
        lhs.name == rhs.name
    }
}

@MainActor
public final class ProcessMonitor: ObservableObject {
    public static let shared = ProcessMonitor()

    @Published public var topProcesses: [MonitoredProcess] = []
    @Published public var sortMode: ProcessSortMode = .cpu {
        didSet { refreshProcesses() }
    }
    @Published public var isRefreshing: Bool = false
    @Published public var lastKillStatus: String? = nil

    private let myPid: Int32

    // CPU time tracking per PID for delta-based % calculation
    private var prevCpuTimes: [Int32: UInt64] = [:]
    private var prevSampleTime: Date = Date()

    private nonisolated static let protectedProcessNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow",
        "Finder", "Dock", "SystemUIServer", "ControlCenter",
        "VitalsDeck", "sysmond", "diskarbitrationd", "coreaudiod",
        "opendirectoryd", "securityd", "powerd", "analyticsd",
        "configd", "distnoted", "mds", "mds_stores", "identityservicesd"
    ]

    // Total RAM in bytes for % calculation (read once at startup, immutable)
    private nonisolated static let totalRAMBytes: UInt64 = {
        var memSize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &size, nil, 0)
        return memSize > 0 ? memSize : 8 * 1024 * 1024 * 1024
    }()

    public init() {
        self.myPid = ProcessInfo.processInfo.processIdentifier
        refreshProcesses()
    }

    isolated deinit {}

    /// Timer is driven by SystemMonitor's unified DispatchSource — no independent timer needed
    public func startMonitoring() {}
    public func stopMonitoring() {}

    public func refreshProcesses() {
        guard !isRefreshing else { return }
        isRefreshing = true

        let currentSort = self.sortMode
        let pidToExclude = self.myPid
        let previousTimes = self.prevCpuTimes
        let sampleTime = self.prevSampleTime

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let (processes, newTimes) = Self.fetchTopProcessesLibproc(
                sort: currentSort,
                excludePid: pidToExclude,
                prevCpuTimes: previousTimes,
                prevSampleTime: sampleTime
            )

            Task { @MainActor [weak self] in
                self?.topProcesses = processes
                self?.prevCpuTimes = newTimes
                self?.prevSampleTime = Date()
                self?.isRefreshing = false
            }
        }
    }

    @discardableResult
    public func killProcess(pid: Int32, force: Bool = true) -> Bool {
        guard pid > 1 && pid != myPid else {
            self.lastKillStatus = "Cannot terminate protected system process"
            return false
        }

        if let proc = topProcesses.first(where: { $0.pid == pid }), proc.isSystemProtected {
            self.lastKillStatus = "Process '\(proc.name)' is protected"
            return false
        }

        let signal = force ? SIGKILL : SIGTERM
        let res = Darwin.kill(pid, signal)

        if res == 0 {
            self.lastKillStatus = "Killed #\(pid)"
            self.topProcesses.removeAll { $0.pid == pid }
            self.prevCpuTimes.removeValue(forKey: pid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refreshProcesses()
            }
            return true
        } else {
            let err = errno
            if err == EPERM {
                self.lastKillStatus = "Permission Denied (Root)"
            } else if err == ESRCH {
                self.lastKillStatus = "Process already exited"
                self.topProcesses.removeAll { $0.pid == pid }
            } else {
                self.lastKillStatus = "Error: \(err)"
            }
            return false
        }
    }

    // MARK: - libproc-based process scan (no subprocess fork)
    private nonisolated static func fetchTopProcessesLibproc(
        sort: ProcessSortMode,
        excludePid: Int32,
        prevCpuTimes: [Int32: UInt64],
        prevSampleTime: Date
    ) -> ([MonitoredProcess], [Int32: UInt64]) {

        // 1. Get all PIDs in one syscall
        let pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else { return ([], [:]) }

        var pids = [Int32](repeating: 0, count: Int(pidCount) + 32)
        let actualCount = proc_listallpids(&pids, Int32(pids.count) * 4)
        guard actualCount > 0 else { return ([], [:]) }

        pids = Array(pids.prefix(Int(actualCount)))

        let elapsed = max(Date().timeIntervalSince(prevSampleTime), 0.1)
        var newCpuTimes: [Int32: UInt64] = [:]

        var candidates: [(pid: Int32, name: String, cpuPercent: Double, memBytes: UInt64, isProtected: Bool)] = []

        var nameBuf = [CChar](repeating: 0, count: 1024)

        for pid in pids {
            guard pid > 1, pid != excludePid else { continue }

            // Get process name via proc_name (no fork, direct syscall)
            let nameLen = proc_name(pid, &nameBuf, UInt32(nameBuf.count))
            guard nameLen > 0 else { continue }
            // Use null-terminated safe conversion
            let procName = nameBuf.withUnsafeBufferPointer { buf in
                guard buf.baseAddress != nil else { return "" }
                return String(decoding: buf.prefix(while: { $0 != 0 }).map(UInt8.init), as: UTF8.self)
            }
            guard !procName.isEmpty, procName != "ps", procName != "head", procName != "grep" else { continue }

            // Get task info via proc_pidinfo
            var taskInfo = proc_taskinfo()
            let infoSize = Int32(MemoryLayout<proc_taskinfo>.size)
            let ret = withUnsafeMutableBytes(of: &taskInfo) { ptr in
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr.baseAddress!, infoSize)
            }
            guard ret == infoSize else { continue }

            // CPU % via delta of total cpu ticks
            let currentCpuTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            newCpuTimes[pid] = currentCpuTime

            let cpuPercent: Double
            if let prevTime = prevCpuTimes[pid], currentCpuTime >= prevTime {
                let delta = Double(currentCpuTime - prevTime)
                // pti_total_user/system are in nanoseconds on Apple platforms
                cpuPercent = min((delta / 1_000_000_000.0 / elapsed) * 100.0, 999.9)
            } else {
                cpuPercent = 0.0
            }

            let isProtected = protectedProcessNames.contains(procName) || pid <= 100

            candidates.append((
                pid: pid,
                name: procName,
                cpuPercent: cpuPercent,
                memBytes: taskInfo.pti_resident_size,
                isProtected: isProtected
            ))
        }

        // Sort and take top 3
        let sorted: [(pid: Int32, name: String, cpuPercent: Double, memBytes: UInt64, isProtected: Bool)]
        if sort == .cpu {
            sorted = candidates.sorted { $0.cpuPercent > $1.cpuPercent }
        } else {
            sorted = candidates.sorted { $0.memBytes > $1.memBytes }
        }

        let top3 = Array(sorted.prefix(3))

        // Build MonitoredProcess objects — NSRunningApplication lookup only for top 3
        var results: [MonitoredProcess] = []
        for item in top3 {
            let app = NSRunningApplication(processIdentifier: item.pid)
            let displayName = app?.localizedName ?? item.name
            let icon = app?.icon

            let memPercent = totalRAMBytes > 0
                ? (Double(item.memBytes) / Double(totalRAMBytes)) * 100.0
                : 0.0

            results.append(MonitoredProcess(
                id: item.pid,
                pid: item.pid,
                name: displayName,
                command: item.name,
                cpuPercent: item.cpuPercent,
                memPercent: memPercent,
                memBytes: item.memBytes,
                memFormatted: formatMemory(bytes: item.memBytes),
                isSystemProtected: item.isProtected,
                appIcon: icon
            ))
        }

        return (results, newCpuTimes)
    }

    private nonisolated static func formatMemory(bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        if mb >= 1000.0 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}
