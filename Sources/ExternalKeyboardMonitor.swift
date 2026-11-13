import Foundation
import IOKit.hid

final class ExternalKeyboardMonitor {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
    private var keyboards: Set<IOHIDDevice> = []
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ] as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, _, device in
            guard result == kIOReturnSuccess, let context else { return }
            Unmanaged<ExternalKeyboardMonitor>.fromOpaque(context)
                .takeUnretainedValue().connect(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<ExternalKeyboardMonitor>.fromOpaque(context)
                .takeUnretainedValue().disconnect(device)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        keyboards = Set(devices.filter(Self.isExternalKeyboard))
        onChange(!keyboards.isEmpty)
    }

    deinit {
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    }

    private func connect(_ device: IOHIDDevice) {
        guard Self.isExternalKeyboard(device) else { return }
        let wasEmpty = keyboards.isEmpty
        keyboards.insert(device)
        if wasEmpty { onChange(true) }
    }

    private func disconnect(_ device: IOHIDDevice) {
        if keyboards.remove(device) != nil, keyboards.isEmpty { onChange(false) }
    }

    private static func isExternalKeyboard(_ device: IOHIDDevice) -> Bool {
        let builtIn = IOHIDDeviceGetProperty(device, kIOHIDBuiltInKey as CFString) as? NSNumber
        let virtual = IOHIDDeviceGetProperty(device, "VirtualHIDDevice" as CFString) as? NSNumber
        guard builtIn?.boolValue != true, virtual?.boolValue != true,
              let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String,
              transport == "USB" || transport.hasPrefix("Bluetooth") else { return false }
        let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
        let isPointingDevice = ["mouse", "trackpad", "trackball"].contains {
            product.localizedCaseInsensitiveContains($0)
        }
        return !isPointingDevice || product.localizedCaseInsensitiveContains("keyboard")
    }
}
