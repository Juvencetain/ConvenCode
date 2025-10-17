import Foundation
import Combine
import IOKit
import IOKit.ps
import SystemConfiguration
import Darwin

// MARK: - SystemMonitor ViewModel
class SystemMonitorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var systemMonitorCPUUsage: Double = 0.0
    @Published var systemMonitorCPUCores: Int = 0
    @Published var systemMonitorCPUThreads: Int = 0
    @Published var systemMonitorCPUModel: String = "未知"
    @Published var systemMonitorCPUHistory: [Double] = []
    
    @Published var systemMonitorMemoryUsed: String = "0 GB"
    @Published var systemMonitorMemoryTotal: String = "0 GB"
    @Published var systemMonitorMemoryAvailable: String = "0 GB"
    @Published var systemMonitorMemoryCompressed: String = "0 GB"
    @Published var systemMonitorMemoryUsagePercentage: Double = 0.0
    @Published var systemMonitorMemoryActivePercentage: Double = 0.0
    @Published var systemMonitorMemoryWiredPercentage: Double = 0.0
    @Published var systemMonitorMemoryCompressedPercentage: Double = 0.0
    
    @Published var systemMonitorDiskUsed: String = "0 GB"
    @Published var systemMonitorDiskFree: String = "0 GB"
    @Published var systemMonitorDiskTotal: String = "0 GB"
    @Published var systemMonitorDiskUsagePercentage: Double = 0.0
    
    @Published var systemMonitorNetworkUpload: String = "0 KB/s"
    @Published var systemMonitorNetworkDownload: String = "0 KB/s"
    @Published var systemMonitorNetworkUploadSpeed: Double = 0
    @Published var systemMonitorNetworkDownloadSpeed: Double = 0
    @Published var systemMonitorNetworkUploadHistory: [Double] = []
    @Published var systemMonitorNetworkDownloadHistory: [Double] = []
    
    @Published var systemMonitorProcessCount: Int = 0
    @Published var systemMonitorAppProcessCount: Int = 0
    @Published var systemMonitorSystemProcessCount: Int = 0
    
    @Published var systemMonitorUptime: String = "0天 0小时"
    @Published var systemMonitorModelName: String = "未知"
    @Published var systemMonitorOSVersion: String = "未知"
    
    @Published var systemMonitorIsRefreshing: Bool = false
    @Published var systemMonitorIsMonitoring: Bool = false
    
    // MARK: - Private Properties
    private var systemMonitorTimer: Timer?
    private var systemMonitorPreviousNetworkBytes: (upload: UInt64, download: UInt64) = (0, 0)
    private var systemMonitorPreviousCPUInfo: (total: natural_t, idle: natural_t)?
    
    private let systemMonitorMaxHistoryCount = 30
    
    // MARK: - Init
    init() {
        systemMonitorLoadSystemInfo()
        systemMonitorLoadStaticInfo()
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        systemMonitorIsMonitoring = true
        systemMonitorLoadSystemInfo()
        
        systemMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.systemMonitorLoadSystemInfo()
        }
    }
    
    func stopMonitoring() {
        systemMonitorIsMonitoring = false
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = nil
    }
    
    func refreshSystemMonitorData() {
        systemMonitorIsRefreshing = true
        systemMonitorLoadSystemInfo()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.systemMonitorIsRefreshing = false
        }
    }
    
    // MARK: - Private Methods
    private func systemMonitorLoadSystemInfo() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let cpuUsage = self.systemMonitorGetCPUUsage()
            let cpuInfo = self.systemMonitorGetCPUInfo()
            let memoryInfo = self.systemMonitorGetMemoryInfo()
            let diskInfo = self.systemMonitorGetDiskInfo()
            let networkInfo = self.systemMonitorGetNetworkInfo()
            let processInfo = self.systemMonitorGetProcessInfo()
            let uptime = self.systemMonitorGetSystemUptime()
            
            DispatchQueue.main.async {
                // CPU
                self.systemMonitorCPUUsage = cpuUsage
                self.systemMonitorCPUCores = cpuInfo.cores
                self.systemMonitorCPUThreads = cpuInfo.threads
                self.systemMonitorUpdateCPUHistory(cpuUsage)
                
                // Memory
                self.systemMonitorMemoryUsed = memoryInfo.used
                self.systemMonitorMemoryTotal = memoryInfo.total
                self.systemMonitorMemoryAvailable = memoryInfo.available
                self.systemMonitorMemoryCompressed = memoryInfo.compressed
                self.systemMonitorMemoryUsagePercentage = memoryInfo.percentage
                self.systemMonitorMemoryActivePercentage = memoryInfo.activePercentage
                self.systemMonitorMemoryWiredPercentage = memoryInfo.wiredPercentage
                self.systemMonitorMemoryCompressedPercentage = memoryInfo.compressedPercentage
                
                // Disk
                self.systemMonitorDiskUsed = diskInfo.used
                self.systemMonitorDiskFree = diskInfo.free
                self.systemMonitorDiskTotal = diskInfo.total
                self.systemMonitorDiskUsagePercentage = diskInfo.percentage
                
                // Network
                self.systemMonitorNetworkUpload = networkInfo.upload
                self.systemMonitorNetworkDownload = networkInfo.download
                self.systemMonitorNetworkUploadSpeed = networkInfo.uploadSpeed
                self.systemMonitorNetworkDownloadSpeed = networkInfo.downloadSpeed
                self.systemMonitorUpdateNetworkHistory(networkInfo.uploadSpeed, networkInfo.downloadSpeed)
                
                // Process
                self.systemMonitorProcessCount = processInfo.total
                self.systemMonitorAppProcessCount = processInfo.app
                self.systemMonitorSystemProcessCount = processInfo.system
                
                // Uptime
                self.systemMonitorUptime = uptime
            }
        }
    }
    
    private func systemMonitorLoadStaticInfo() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let modelName = self.systemMonitorGetModelName()
            let osVersion = self.systemMonitorGetOSVersion()
            let cpuModel = self.systemMonitorGetCPUModel()
            
            DispatchQueue.main.async {
                self.systemMonitorModelName = modelName
                self.systemMonitorOSVersion = osVersion
                self.systemMonitorCPUModel = cpuModel
            }
        }
    }
    
    // MARK: - History Updates
    private func systemMonitorUpdateCPUHistory(_ value: Double) {
        systemMonitorCPUHistory.append(value)
        if systemMonitorCPUHistory.count > systemMonitorMaxHistoryCount {
            systemMonitorCPUHistory.removeFirst()
        }
    }
    
    private func systemMonitorUpdateNetworkHistory(_ upload: Double, _ download: Double) {
        systemMonitorNetworkUploadHistory.append(upload)
        systemMonitorNetworkDownloadHistory.append(download)
        
        if systemMonitorNetworkUploadHistory.count > systemMonitorMaxHistoryCount {
            systemMonitorNetworkUploadHistory.removeFirst()
        }
        if systemMonitorNetworkDownloadHistory.count > systemMonitorMaxHistoryCount {
            systemMonitorNetworkDownloadHistory.removeFirst()
        }
    }
    
    // MARK: - CPU Methods
    private func systemMonitorGetCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t!
        var numCPUInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        var totalUser: natural_t = 0
        var totalSystem: natural_t = 0
        var totalIdle: natural_t = 0
        var totalNice: natural_t = 0
        
        for i in 0..<Int(numCPUs) {
            let cpuLoadInfo = cpuInfo.advanced(by: Int(CPU_STATE_MAX) * i).withMemoryRebound(to: integer_t.self, capacity: Int(CPU_STATE_MAX)) { $0 }
            
            totalUser += natural_t(cpuLoadInfo[Int(CPU_STATE_USER)])
            totalSystem += natural_t(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            totalIdle += natural_t(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            totalNice += natural_t(cpuLoadInfo[Int(CPU_STATE_NICE)])
        }
        
        let total = totalUser + totalSystem + totalIdle + totalNice
        let idle = totalIdle
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUInfo))
        }
        
        if let previous = systemMonitorPreviousCPUInfo {
            let totalDelta = total - previous.total
            let idleDelta = idle - previous.idle
            
            if totalDelta > 0 {
                let usage = Double(totalDelta - idleDelta) / Double(totalDelta) * 100.0
                systemMonitorPreviousCPUInfo = (total, idle)
                return min(max(usage, 0), 100)
            }
        }
        
        systemMonitorPreviousCPUInfo = (total, idle)
        return 0.0
    }
    
    private func systemMonitorGetCPUInfo() -> (cores: Int, threads: Int) {
        let cores = ProcessInfo.processInfo.processorCount
        let threads = ProcessInfo.processInfo.activeProcessorCount
        return (cores, threads)
    }
    
    private func systemMonitorGetCPUModel() -> String {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        let cpuModel = String(cString: machine)
        
        // 简化处理器名称
        if cpuModel.contains("Apple") {
            let components = cpuModel.components(separatedBy: " ")
            if let appleIndex = components.firstIndex(of: "Apple"),
               appleIndex + 1 < components.count {
                return components[appleIndex + 1]
            }
        }
        
        return cpuModel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Memory Methods
    private func systemMonitorGetMemoryInfo() -> (used: String, total: String, available: String, compressed: String, percentage: Double, activePercentage: Double, wiredPercentage: Double, compressedPercentage: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return ("0 GB", "0 GB", "0 GB", "0 GB", 0.0, 0.0, 0.0, 0.0)
        }
        
        let pageSize = vm_kernel_page_size
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        let free = UInt64(stats.free_count) * UInt64(pageSize)
        let active = UInt64(stats.active_count) * UInt64(pageSize)
        let inactive = UInt64(stats.inactive_count) * UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        
        let used = active + wired + compressed
        let available = free + inactive
        let percentage = Double(used) / Double(totalMemory) * 100.0
        
        let activePercentage = Double(active) / Double(totalMemory) * 100.0
        let wiredPercentage = Double(wired) / Double(totalMemory) * 100.0
        let compressedPercentage = Double(compressed) / Double(totalMemory) * 100.0
        
        return (
            systemMonitorFormatBytes(used),
            systemMonitorFormatBytes(totalMemory),
            systemMonitorFormatBytes(available),
            systemMonitorFormatBytes(compressed),
            percentage,
            activePercentage,
            wiredPercentage,
            compressedPercentage
        )
    }
    
    // MARK: - Disk Methods
    private func systemMonitorGetDiskInfo() -> (used: String, free: String, total: String, percentage: Double) {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/") else {
            return ("0 GB", "0 GB", "0 GB", 0.0)
        }
        
        let totalSpace = attributes[.systemSize] as? UInt64 ?? 0
        let freeSpace = attributes[.systemFreeSize] as? UInt64 ?? 0
        let usedSpace = totalSpace - freeSpace
        
        let percentage = totalSpace > 0 ? Double(usedSpace) / Double(totalSpace) * 100.0 : 0.0
        
        return (
            systemMonitorFormatBytes(usedSpace),
            systemMonitorFormatBytes(freeSpace),
            systemMonitorFormatBytes(totalSpace),
            percentage
        )
    }
    
    // MARK: - Network Methods
    private func systemMonitorGetNetworkInfo() -> (upload: String, download: String, uploadSpeed: Double, downloadSpeed: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else {
            return ("0 KB/s", "0 KB/s", 0, 0)
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0
        
        var pointer = ifaddr
        while pointer != nil {
            defer { pointer = pointer?.pointee.ifa_next }
            
            guard let interface = pointer?.pointee,
                  let addr = interface.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK) else {
                continue
            }
            
            let name = String(cString: interface.ifa_name)
            
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") else {
                continue
            }
            
            if let stats = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                totalSent += UInt64(stats.pointee.ifi_obytes)
                totalReceived += UInt64(stats.pointee.ifi_ibytes)
            }
        }
        
        let uploadSpeed: UInt64
        let downloadSpeed: UInt64
        
        if systemMonitorPreviousNetworkBytes.upload > 0 {
            uploadSpeed = totalSent > systemMonitorPreviousNetworkBytes.upload ?
                (totalSent - systemMonitorPreviousNetworkBytes.upload) : 0
            downloadSpeed = totalReceived > systemMonitorPreviousNetworkBytes.download ?
                (totalReceived - systemMonitorPreviousNetworkBytes.download) : 0
        } else {
            uploadSpeed = 0
            downloadSpeed = 0
        }
        
        systemMonitorPreviousNetworkBytes = (totalSent, totalReceived)
        
        return (
            systemMonitorFormatSpeed(uploadSpeed),
            systemMonitorFormatSpeed(downloadSpeed),
            Double(uploadSpeed),
            Double(downloadSpeed)
        )
    }
    
    // MARK: - Process Methods
    private func systemMonitorGetProcessInfo() -> (total: Int, app: Int, system: Int) {
        var count: Int32 = 0
        let maxPids = 2048
        var pids = [pid_t](repeating: 0, count: maxPids)
        
        let result = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.stride * maxPids))
        
        guard result > 0 else {
            return (0, 0, 0)
        }
        
        let actualCount = Int(result)
        var appCount = 0
        var systemCount = 0
        
        // 定义常量
        let maxPathSize = 4096
        
        for i in 0..<min(actualCount, maxPids) {
            let pid = pids[i]
            var pathBuffer = [Int8](repeating: 0, count: maxPathSize)
            
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(maxPathSize))
            
            if pathLength > 0 {
                let path = String(cString: pathBuffer)
                if path.contains("/Applications/") || path.contains("/Users/") {
                    appCount += 1
                } else if path.contains("/System/") || path.contains("/usr/") {
                    systemCount += 1
                }
            }
        }
        
        return (actualCount, appCount, systemCount)
    }
    
    // MARK: - System Info Methods
    private func systemMonitorGetSystemUptime() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        
        if days > 0 {
            return "\(days)天 \(hours)小时 \(minutes)分钟"
        } else if hours > 0 {
            return "\(hours)小时 \(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private func systemMonitorGetModelName() -> String {
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private func systemMonitorGetOSVersion() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }
    
    // MARK: - Helper Methods
    private func systemMonitorFormatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
    
    func systemMonitorFormatSpeed(_ bytesPerSecond: UInt64) -> String {
        let mb = Double(bytesPerSecond) / 1_048_576
        if mb >= 1 {
            return String(format: "%.2f MB/s", mb)
        }
        let kb = Double(bytesPerSecond) / 1024
        if kb >= 1 {
            return String(format: "%.1f KB/s", kb)
        }
        return String(format: "%.0f B/s", Double(bytesPerSecond))
    }
}
