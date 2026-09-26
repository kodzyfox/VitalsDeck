import Foundation
import IOKit

// Private IOHID declarations for Apple Silicon thermal monitoring
@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: UnsafeMutableRawPointer, _ match: CFDictionary)

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: UnsafeMutableRawPointer) -> Unmanaged<CFArray>?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: AnyObject, _ property: CFString) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: AnyObject, _ type: Int64, _ options: Int64, _ timestamp: Int64) -> UnsafeMutableRawPointer?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: UnsafeMutableRawPointer, _ field: Int64) -> Double

public struct ThermalReadings: Sendable {
    public let cpuTemp: Double?
    public let cpuMaxTemp: Double?
    public let gpuTemp: Double?
    public let gpuMaxTemp: Double?
    public let batteryTemp: Double?
    public let ssdTemp: Double?
    
    public var isAvailable: Bool {
        cpuTemp != nil || gpuTemp != nil
    }
    
    public static let empty = ThermalReadings(
        cpuTemp: nil,
        cpuMaxTemp: nil,
        gpuTemp: nil,
        gpuMaxTemp: nil,
        batteryTemp: nil,
        ssdTemp: nil
    )
}

public final class HardwareSensors: @unchecked Sendable {
    public static let shared = HardwareSensors()
    
    private enum SensorCategory: Sendable {
        case cpu
        case gpu
        case battery
        case ssd
        case other
    }
    
    private struct TrackedSensor: @unchecked Sendable {
        let service: AnyObject
        let category: SensorCategory
        let name: String
    }
    
    private let queue = DispatchQueue(label: "com.vitalsdeck.hardwareSensors", qos: .utility)
    private var hidClient: UnsafeMutableRawPointer?
    private var trackedSensors: [TrackedSensor] = []
    private var lastServiceDiscovery: Date = .distantPast
    
    public init() {
        queue.async { [weak self] in
            self?.initHIDClient()
            self?.discoverServices()
        }
    }
    
    private func initHIDClient() {
        guard hidClient == nil else { return }
        if let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) {
            let filter: NSDictionary = [
                "PrimaryUsagePage": NSNumber(value: 0xFF00),
                "PrimaryUsage": NSNumber(value: 5)
            ]
            IOHIDEventSystemClientSetMatching(client, filter)
            self.hidClient = client
        }
    }
    
    private func discoverServices() {
        guard let client = hidClient else { return }
        guard let unmanagedServices = IOHIDEventSystemClientCopyServices(client) else { return }
        let services = unmanagedServices.takeRetainedValue()
        let count = CFArrayGetCount(services)
        
        var list: [TrackedSensor] = []
        
        for i in 0..<count {
            let service = CFArrayGetValueAtIndex(services, i)
            let serviceObj = unsafeBitCast(service, to: AnyObject.self)
            
            var productName: String = ""
            if let unmanagedProp = IOHIDServiceClientCopyProperty(serviceObj, "Product" as CFString) {
                let prop = unmanagedProp.takeRetainedValue()
                if let str = prop as? String {
                    productName = str
                }
            }
            
            let lower = productName.lowercased()
            let category: SensorCategory
            
            // GPU sensors on Apple Silicon: TP*g, gpu, gacc, MTR Temp Sensor GPU
            if (lower.contains("tp") && lower.hasSuffix("g")) || lower.contains("gpu") || lower.contains("gacc") {
                category = .gpu
            // CPU sensors on Apple Silicon: tdie, pacc, eacc, cpu, MTR Temp Sensor CPU
            } else if lower.contains("tdie") || lower.contains("pacc") || lower.contains("eacc") || lower.contains("cpu") {
                category = .cpu
            } else if lower.contains("battery") || lower.contains("gas gauge") {
                category = .battery
            } else if lower.contains("nand") || lower.contains("ssd") {
                category = .ssd
            } else {
                category = .other
            }
            
            if category != .other {
                list.append(TrackedSensor(service: serviceObj, category: category, name: productName))
            }
        }
        
        self.trackedSensors = list
        self.lastServiceDiscovery = Date()
    }
    
    /// Reads hardware temperature sensors synchronously on the private background queue
    public func read() -> ThermalReadings {
        queue.sync {
            // Re-discover if list is empty or older than 5 minutes
            if trackedSensors.isEmpty || Date().timeIntervalSince(lastServiceDiscovery) > 300 {
                initHIDClient()
                discoverServices()
            }
            
            guard !trackedSensors.isEmpty else {
                // If Apple Silicon IOHID returned 0 sensors, try Intel SMC fallback
                return readIntelSMCSensors()
            }
            
            var cpuValues: [Double] = []
            var gpuValues: [Double] = []
            var batteryValues: [Double] = []
            var ssdValues: [Double] = []
            
            for sensor in trackedSensors {
                // kIOHIDEventTypeTemperature = 15
                if let event = IOHIDServiceClientCopyEvent(sensor.service, 15, 0, 0) {
                    let temp = IOHIDEventGetFloatValue(event, Int64(15 << 16))
                    Unmanaged<AnyObject>.fromOpaque(event).release()
                    
                    // Filter out impossible or disconnected sensor values (below 1°C or above 130°C)
                    guard temp >= 1.0 && temp <= 130.0 else { continue }
                    
                    switch sensor.category {
                    case .cpu:
                        cpuValues.append(temp)
                    case .gpu:
                        gpuValues.append(temp)
                    case .battery:
                        batteryValues.append(temp)
                    case .ssd:
                        ssdValues.append(temp)
                    case .other:
                        break
                    }
                }
            }
            
            let cpuAvg = cpuValues.isEmpty ? nil : (cpuValues.reduce(0.0, +) / Double(cpuValues.count))
            let cpuMax = cpuValues.max()
            let gpuAvg = gpuValues.isEmpty ? nil : (gpuValues.reduce(0.0, +) / Double(gpuValues.count))
            let gpuMax = gpuValues.max()
            let batAvg = batteryValues.isEmpty ? nil : (batteryValues.reduce(0.0, +) / Double(batteryValues.count))
            let ssdAvg = ssdValues.isEmpty ? nil : (ssdValues.reduce(0.0, +) / Double(ssdValues.count))
            
            return ThermalReadings(
                cpuTemp: cpuAvg,
                cpuMaxTemp: cpuMax,
                gpuTemp: gpuAvg,
                gpuMaxTemp: gpuMax,
                batteryTemp: batAvg,
                ssdTemp: ssdAvg
            )
        }
    }
    
    // MARK: - Intel SMC Fallback
    private func readIntelSMCSensors() -> ThermalReadings {
        // Fallback for Intel Macs if SMC is accessible
        #if arch(x86_64)
        let matching = IOServiceMatching("AppleSMC")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return .empty }
        defer { IOObjectRelease(service) }
        
        var connect: io_connect_t = 0
        let kr = IOServiceOpen(service, mach_task_self_, 0, &connect)
        guard kr == KERN_SUCCESS else { return .empty }
        defer { IOServiceClose(connect) }
        
        // Return empty if direct SMC key protocol not loaded
        return .empty
        #else
        return .empty
        #endif
    }
}
