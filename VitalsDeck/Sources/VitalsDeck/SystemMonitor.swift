import Foundation
import Combine
import IOKit
import IOKit.ps
import Darwin

@MainActor
public final class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()
    
    // CPU
    @Published public var cpuUsage: Double = 0.0
    @Published public var cpuPerCore: [Double] = []
    @Published public var cpuCoreCount: Int = 8
    @Published public var cpuModelName: String = "Apple Silicon"
    
    // GPU
    @Published public var gpuUsage: Double = 0.0
    @Published public var gpuModelName: String = "Metal GPU"
    
    // RAM
    @Published public var ramUsagePercent: Double = 0.0
    @Published public var ramUsedBytes: UInt64 = 0
    @Published public var ramTotalBytes: UInt64 = 0
    @Published public var ramAppBytes: UInt64 = 0
    @Published public var ramWiredBytes: UInt64 = 0
    @Published public var ramCompressedBytes: UInt64 = 0
    
    // Network
    @Published public var netDownloadBps: Double = 0.0
    @Published public var netUploadBps: Double = 0.0
    @Published public var netHistoryDown: [Double] = Array(repeating: 0.0, count: 20)
    @Published public var netHistoryUp: [Double] = Array(repeating: 0.0, count: 20)
    
    // Thermal & Real Hardware Sensors
    @Published public var thermalState: ProcessInfo.ThermalState = .nominal
    @Published public var thermalEstimateCelsius: Int = 41
    @Published public var cpuTemperature: Double? = nil
    @Published public var cpuMaxTemperature: Double? = nil
    @Published public var gpuTemperature: Double? = nil
    @Published public var gpuMaxTemperature: Double? = nil
    @Published public var batteryTemperature: Double? = nil
    @Published public var ssdTemperature: Double? = nil
    @Published public var hasRealSensors: Bool = false
    @Published public var batteryPercent: Int? = nil
    @Published public var isAcPowered: Bool = true
    @Published public var isCharging: Bool = false
    @Published public var uptimeString: String = "0h 0m"
    
    public var cpuTemperatureString: String {
        if let t = cpuTemperature {
            return String(format: "%.0f°C", t)
        }
        return "\(thermalEstimateCelsius)°C"
    }
    
    public var gpuTemperatureString: String {
        if let t = gpuTemperature {
            return String(format: "%.0f°C", t)
        }
        return ""
    }
    
    // Internal state
    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuInfoCount: mach_msg_type_number_t = 0
    private var previousNetIn: UInt64 = 0
    private var previousNetOut: UInt64 = 0
    private var previousNetTime: Date = Date()
    private let pageSize: UInt64
    // Cached GPU IORegistry service — avoids full IORegistry scan every tick
    private var cachedGpuEntry: io_object_t = 0
    private var gpuCacheTime: Date = .distantPast
    
    public init() {
        var pSize: vm_size_t = 0
        _ = host_page_size(mach_host_self(), &pSize)
        self.pageSize = UInt64(pSize > 0 ? pSize : 4096)
        
        // Initial hardware specs
        var memSize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &memSize, &size, nil, 0) == 0 {
            self.ramTotalBytes = memSize
        }
        
        var ncpu: UInt32 = 0
        var ncpuSize = MemoryLayout<UInt32>.size
        if sysctlbyname("hw.ncpu", &ncpu, &ncpuSize, nil, 0) == 0 {
            self.cpuCoreCount = Int(ncpu)
        }
        
        var modelBuffer = [CChar](repeating: 0, count: 128)
        var modelSize = modelBuffer.count
        if sysctlbyname("machdep.cpu.brand_string", &modelBuffer, &modelSize, nil, 0) == 0 {
            let str = modelBuffer.withUnsafeBufferPointer { ptr in
                String(cString: ptr.baseAddress!)
            }.trimmingCharacters(in: .whitespacesAndNewlines)
            if !str.isEmpty {
                self.cpuModelName = str
            }
        } else {
            // Apple Silicon name fallback
            var chipBuffer = [CChar](repeating: 0, count: 128)
            var chipSize = chipBuffer.count
            if sysctlbyname("hw.model", &chipBuffer, &chipSize, nil, 0) == 0 {
                self.cpuModelName = chipBuffer.withUnsafeBufferPointer { ptr in
                    String(cString: ptr.baseAddress!)
                }
            }
        }
        
        // Start polling loop
        start()
    }
    
    isolated deinit {
        timerSource?.cancel()
        if cachedGpuEntry != 0 { IOObjectRelease(cachedGpuEntry) }
        if let prev = previousCpuInfo {
            let prevSize = vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            _ = vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: prev)), prevSize)
        }
    }
    
    private var updateInterval: Double = 4.0
    // Single DispatchSource timer — replaces NSTimer to avoid main-thread wake overhead
    private var timerSource: DispatchSourceTimer?
    private var tickCount: UInt64 = 0

    public func setUpdateInterval(_ interval: Double) {
        self.updateInterval = interval
        stop()
        start()
    }

    public func start() {
        guard timerSource == nil else { return }
        // Initial immediate update
        updateMetrics()

        let source = DispatchSource.makeTimerSource(flags: [], queue: .global(qos: .utility))
        let interval = self.updateInterval
        source.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(200))
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.tickCount &+= 1
                self.updateMetrics()
                // Kick ProcessMonitor every 2nd tick (phase-offset, avoids simultaneous spikes)
                if self.tickCount % 2 == 0 {
                    ProcessMonitor.shared.refreshProcesses()
                }
            }
        }
        source.resume()
        timerSource = source
    }

    public func stop() {
        timerSource?.cancel()
        timerSource = nil
    }
    
    public func updateMetrics() {
        updateCPU()
        updateGPU()
        updateRAM()
        updateNetwork()
        updateThermalAndBattery()
        updateUptime()
    }
    
    // MARK: - CPU Load
    private func updateCPU() {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numProcessors: natural_t = 0
        
        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numProcessors,
            &cpuInfo,
            &numCpuInfo
        )
        
        guard kr == KERN_SUCCESS, let cpuInfo = cpuInfo else { return }
        
        if let prev = previousCpuInfo {
            var coreUsages: [Double] = []
            var totalUser: UInt64 = 0
            var totalSystem: UInt64 = 0
            var totalNice: UInt64 = 0
            var totalIdle: UInt64 = 0

            for i in 0..<Int(numProcessors) {
                let offset = Int32(CPU_STATE_MAX) * Int32(i)
                let user = UInt64(cpuInfo[Int(offset + CPU_STATE_USER)] - prev[Int(offset + CPU_STATE_USER)])
                let system = UInt64(cpuInfo[Int(offset + CPU_STATE_SYSTEM)] - prev[Int(offset + CPU_STATE_SYSTEM)])
                let nice = UInt64(cpuInfo[Int(offset + CPU_STATE_NICE)] - prev[Int(offset + CPU_STATE_NICE)])
                let idle = UInt64(cpuInfo[Int(offset + CPU_STATE_IDLE)] - prev[Int(offset + CPU_STATE_IDLE)])

                let used = user + system + nice
                let total = used + idle
                let corePerc = total > 0 ? (Double(used) / Double(total)) * 100.0 : 0.0
                coreUsages.append(max(0.0, min(100.0, corePerc)))

                totalUser += user
                totalSystem += system
                totalNice += nice
                totalIdle += idle
            }

            let totalUsed = totalUser + totalSystem + totalNice
            let grandTotal = totalUsed + totalIdle
            let avgUsage = grandTotal > 0 ? (Double(totalUsed) / Double(grandTotal)) * 100.0 : 0.0

            // Already on @MainActor — assign directly, no GCD hop needed
            self.cpuUsage = max(0.0, min(100.0, avgUsage))
            self.cpuPerCore = coreUsages
            
            // Deallocate old previous info
            let prevSize = vm_size_t(previousCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            _ = vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: prev)), prevSize)
        }
        
        previousCpuInfo = cpuInfo
        previousCpuInfoCount = numCpuInfo
    }
    
    // MARK: - GPU Load (cached IORegistry entry — refreshed every 60 s)
    private func updateGPU() {
        let now = Date()
        // Re-discover the GPU service only if cache is stale or empty
        if cachedGpuEntry == 0 || now.timeIntervalSince(gpuCacheTime) > 60 {
            if cachedGpuEntry != 0 {
                IOObjectRelease(cachedGpuEntry)
                cachedGpuEntry = 0
            }
            var iterator: io_iterator_t = 0
            if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS {
                // Keep reference to the first (primary) accelerator
                let entry = IOIteratorNext(iterator)
                if entry != 0 { cachedGpuEntry = entry }
                // Drain and release remaining entries
                var next = IOIteratorNext(iterator)
                while next != 0 {
                    IOObjectRelease(next)
                    next = IOIteratorNext(iterator)
                }
                IOObjectRelease(iterator)
            }
            gpuCacheTime = now
        }

        guard cachedGpuEntry != 0 else { return }

        var props: Unmanaged<CFMutableDictionary>?
        var currentGpuPercent: Double = 0.0
        if IORegistryEntryCreateCFProperties(cachedGpuEntry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
           let dict = props?.takeRetainedValue() as? [String: Any],
           let perf = dict["PerformanceStatistics"] as? [String: Any] {
            if let devUtil = perf["Device Utilization %"] as? NSNumber {
                currentGpuPercent = devUtil.doubleValue
            } else if let gpuUtil = perf["GPU Activity %"] as? NSNumber {
                currentGpuPercent = gpuUtil.doubleValue
            }
        }
        // Already on @MainActor
        self.gpuUsage = max(0.0, min(100.0, currentGpuPercent))
    }
    
    // MARK: - RAM Load
    private func updateRAM() {
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let kr = withUnsafeMutablePointer(to: &vmStat) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard kr == KERN_SUCCESS else { return }
        
        let active = UInt64(vmStat.active_count) * pageSize
        let wired = UInt64(vmStat.wire_count) * pageSize
        let compressed = UInt64(vmStat.compressor_page_count) * pageSize
        let used = active + wired + compressed

        let percent = ramTotalBytes > 0 ? (Double(used) / Double(ramTotalBytes)) * 100.0 : 0.0

        // Already on @MainActor
        self.ramUsedBytes = used
        self.ramAppBytes = active
        self.ramWiredBytes = wired
        self.ramCompressedBytes = compressed
        self.ramUsagePercent = max(0.0, min(100.0, percent))
    }
    
    // MARK: - Network Throughput
    private func updateNetwork() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        
        while let p = ptr {
            let name = String(cString: p.pointee.ifa_name)
            if p.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK),
               let data = p.pointee.ifa_data {
                let netData = data.assumingMemoryBound(to: if_data.self)
                // Filter for primary hardware network interfaces
                if name.hasPrefix("en") || name.hasPrefix("pdp_ip") || name.hasPrefix("bridge") {
                    totalIn += UInt64(netData.pointee.ifi_ibytes)
                    totalOut += UInt64(netData.pointee.ifi_obytes)
                }
            }
            ptr = p.pointee.ifa_next
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(previousNetTime)
        
        if previousNetIn > 0 && interval > 0.4 {
            let deltaIn = totalIn >= previousNetIn ? totalIn - previousNetIn : 0
            let deltaOut = totalOut >= previousNetOut ? totalOut - previousNetOut : 0

            let downBps = Double(deltaIn) / interval
            let upBps = Double(deltaOut) / interval

            // Already on @MainActor — update directly
            self.netDownloadBps = downBps
            self.netUploadBps = upBps

            self.netHistoryDown.append(downBps)
            if self.netHistoryDown.count > 20 { self.netHistoryDown.removeFirst() }

            self.netHistoryUp.append(upBps)
            if self.netHistoryUp.count > 20 { self.netHistoryUp.removeFirst() }
        }
        
        previousNetIn = totalIn
        previousNetOut = totalOut
        previousNetTime = now
    }
    
    // MARK: - Thermal & Battery
    private func updateThermalAndBattery() {
        let currentThermal = ProcessInfo.processInfo.thermalState
        let currentCpuUsage = self.cpuUsage
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Read real hardware sensors via IOKit / Apple Silicon PMU
            let readings = HardwareSensors.shared.read()
            
            // Fallback estimate if hardware sensors are unavailable
            let baseTemp: Int
            switch currentThermal {
            case .nominal:  baseTemp = 38
            case .fair:     baseTemp = 55
            case .serious:  baseTemp = 75
            case .critical: baseTemp = 92
            @unknown default: baseTemp = 42
            }
            let dynamicTemp = baseTemp + Int((currentCpuUsage * 0.15).rounded())
            
            var batPerc: Int? = nil
            var isAc = true
            var isChg = false
            
            if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
               let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
                for ps in list {
                    if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] {
                        if let cur = desc["Current Capacity"] as? Int {
                            batPerc = cur
                        }
                        if let state = desc["Power Source State"] as? String {
                            isAc = (state == "AC Power")
                        }
                        if let chg = desc["Is Charging"] as? Bool {
                            isChg = chg
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.thermalState = currentThermal
                if let cpuTemp = readings.cpuTemp {
                    self.thermalEstimateCelsius = Int(cpuTemp.rounded())
                    self.cpuTemperature = cpuTemp
                    self.cpuMaxTemperature = readings.cpuMaxTemp
                    self.gpuTemperature = readings.gpuTemp
                    self.gpuMaxTemperature = readings.gpuMaxTemp
                    self.batteryTemperature = readings.batteryTemp
                    self.ssdTemperature = readings.ssdTemp
                    self.hasRealSensors = true
                } else {
                    self.thermalEstimateCelsius = min(105, dynamicTemp)
                    self.cpuTemperature = nil
                    self.cpuMaxTemperature = nil
                    self.gpuTemperature = nil
                    self.gpuMaxTemperature = nil
                    self.batteryTemperature = nil
                    self.ssdTemperature = nil
                    self.hasRealSensors = false
                }
                self.batteryPercent = batPerc
                self.isAcPowered = isAc
                self.isCharging = isChg
            }
        }
    }
    
    private func updateUptime() {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        // Already on @MainActor
        self.uptimeString = "\(hours)h \(minutes)m"
    }
    
    // MARK: - Formatters
    public static func formatBytesRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 {
            return String(format: "%.0f B/s", bytesPerSec)
        } else if bytesPerSec < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024.0)
        } else if bytesPerSec < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB/s", bytesPerSec / (1024.0 * 1024.0 * 1024.0))
        }
    }
    
    public static func formatBytesTotal(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        return String(format: "%.1f GB", gb)
    }
    
    public var thermalDescription: String {
        switch thermalState {
        case .nominal:  return "Nominal"
        case .fair:     return "Moderate"
        case .serious:  return "High"
        case .critical: return "Throttling"
        @unknown default: return "Standard"
        }
    }
}
