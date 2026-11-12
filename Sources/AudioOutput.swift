import CoreAudio
import Foundation

struct AudioOutput: Equatable, Identifiable {
    let id: String
    let name: String
    let device: AudioDeviceID

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static var defaultDevice: AudioDeviceID {
        var device = AudioDeviceID(kAudioObjectUnknown)
        var address = property(kAudioHardwarePropertyDefaultOutputDevice)
        var size = UInt32(MemoryLayout.size(ofValue: device))
        _ = AudioObjectGetPropertyData(system, &address, 0, nil, &size, &device)
        return device
    }

    static func available() -> [AudioOutput] {
        var address = property(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.stride)
        guard !devices.isEmpty else { return [] }
        let status = devices.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(system, &address, 0, nil, &size, $0.baseAddress!)
        }
        guard status == noErr else { return [] }
        return devices.prefix(Int(size) / MemoryLayout<AudioDeviceID>.stride).compactMap { device in
            var streams = property(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput)
            var hiddenProperty = property(kAudioDevicePropertyIsHidden)
            var hidden: UInt32 = 0
            var hiddenSize = UInt32(MemoryLayout.size(ofValue: hidden))
            _ = AudioObjectGetPropertyData(device, &hiddenProperty, 0, nil, &hiddenSize, &hidden)
            var bytes: UInt32 = 0
            guard hidden == 0,
                  AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &bytes) == noErr, bytes > 0,
                  let uid = string(kAudioDevicePropertyDeviceUID, device: device),
                  let name = string(kAudioObjectPropertyName, device: device),
                  !name.hasPrefix("CADefaultDeviceAggregate-") else { return nil }
            return AudioOutput(id: uid, name: name, device: device)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func property(_ selector: AudioObjectPropertySelector,
                                 scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func string(_ selector: AudioObjectPropertySelector, device: AudioDeviceID) -> String? {
        var address = property(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout.size(ofValue: value))
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}
