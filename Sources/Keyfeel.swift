import AppKit
import CoreAudio
import AVFoundation
import SwiftUI

enum Profile: String, CaseIterable, Identifiable {
    case kProRed = "keeby-k-pro-red"
    case topre = "topre-purple-hybrid-pbt"
    case red = "cherrymx-red-abs"
    case brown = "cherrymx-brown-pbt"
    case blue = "cherrymx-blue-pbt"

    static let available = allCases.filter { profile in
        Bundle.main.url(
            forResource: profile == .kProRed ? "alpha_down_01" : "recordings",
            withExtension: "wav", subdirectory: "Sounds/\(profile.rawValue)"
        ) != nil
    }

    static let preferred = available.contains(.kProRed) ? Profile.kProRed : .red

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kProRed: "Keychron K Pro Red"
        case .topre: "Topre Purple"
        case .red: "Cherry MX Red"
        case .brown: "Cherry MX Brown"
        case .blue: "Cherry MX Blue"
        }
    }

    var detail: String {
        switch self {
        case .kProRed: "Smooth linear"
        case .topre: "Deep and rounded"
        case .red: "Smooth linear"
        case .brown: "Soft tactile"
        case .blue: "Bright and clicky"
        }
    }
}

struct KeySounds {
    let down: AVAudioPCMBuffer
    let up: AVAudioPCMBuffer
}

enum SoundError: Error {
    case missingSamples
    case outputUnavailable
}

final class Playback {
    private let engine = AVAudioEngine()
    private let toneEQ = AVAudioUnitEQ(numberOfBands: 3)
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let voices = (0..<16).map { _ in AVAudioPlayerNode() }
    private var nextVoice = 0
    private var profile: Profile?
    private var samples: [String: [KeySounds]] = [:]
    private var nextVariant = 0

    init() {
        engine.attach(toneEQ)
        let mix = AVAudioMixerNode()
        engine.attach(mix)
        engine.connect(mix, to: toneEQ, format: nil)
        engine.connect(toneEQ, to: engine.mainMixerNode, format: nil)
        let bands = toneEQ.bands
        bands[0].filterType = .highShelf
        bands[0].frequency = 4_200
        bands[1].filterType = .parametric
        bands[1].frequency = 220
        bands[1].bandwidth = 1.4
        bands[2].filterType = .parametric
        bands[2].frequency = 2_700
        bands[2].bandwidth = 1.2
        setTone(CGPoint(x: 0.5, y: 0.5))
        for band in bands { band.bypass = false }
        for voice in voices {
            engine.attach(voice)
            engine.connect(voice, to: mix, format: format)
        }
    }

    func setTone(_ tone: CGPoint) {
        let brightness = Float(tone.x * 2 - 1)
        let clack = Float(tone.y * 2 - 1)
        toneEQ.bands[0].gain = brightness * 8
        toneEQ.bands[1].gain = -clack * 7
        toneEQ.bands[2].gain = clack * 6
        toneEQ.globalGain = -max(abs(brightness), abs(clack)) * 3
    }

    func load(_ profile: Profile) throws {
        guard self.profile != profile else { return }
        let folder = Bundle.main.resourceURL!.appendingPathComponent("Sounds/\(profile.rawValue)")
        let sounds = try profile == .kProRed ? loadKeeby(folder) : loadMechvibes(folder)
        normalizeLevel(sounds)
        samples = sounds
        self.profile = profile
        nextVariant = 0
    }

    private func normalizeLevel(_ sounds: [String: [KeySounds]]) {
        let variants = sounds.values.flatMap { $0 }
        let presses = variants.map { peak(of: $0.down) }.filter { $0 > 0 }.sorted()
        guard !presses.isEmpty else { return }
        let typicalPeak = presses[presses.count / 2]
        let loudestPeak = variants.map { max(peak(of: $0.down), peak(of: $0.up)) }.max() ?? typicalPeak
        let gain = min(0.36 / typicalPeak, 0.68 / loudestPeak, 6)
        for pair in variants {
            for buffer in [pair.down, pair.up] {
                guard let channel = buffer.floatChannelData?[0] else { continue }
                for frame in 0..<Int(buffer.frameLength) {
                    channel[frame] *= gain
                }
            }
        }
    }

    private func peak(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        return (0..<Int(buffer.frameLength)).reduce(0) { max($0, abs(channel[$1])) }
    }

    private func loadKeeby(_ folder: URL) throws -> [String: [KeySounds]] {
        let groups = [("KeyA", "alpha", 2), ("Space", "space", 1),
                      ("Enter", "enter", 1), ("Backspace", "backspace", 1)]
        var sounds: [String: [KeySounds]] = [:]
        for (key, group, count) in groups {
            sounds[key] = try (1...count).map { variant in
                func sample(_ action: String) throws -> AVAudioPCMBuffer {
                    let name = "\(group)_\(action)_0\(variant).wav"
                    let file = try AVAudioFile(forReading: folder.appendingPathComponent(name))
                    let end = Double(file.length) / file.processingFormat.sampleRate * 1_000
                    guard let buffer = try clip(file, range: [0, end], trimAttack: true) else {
                        throw SoundError.missingSamples
                    }
                    return buffer
                }
                return try KeySounds(down: sample("down"), up: sample("up"))
            }
        }
        return sounds
    }

    private func loadMechvibes(_ folder: URL) throws -> [String: [KeySounds]] {
        let timing = try JSONDecoder().decode(
            [String: [[Double]]].self,
            from: Data(contentsOf: folder.appendingPathComponent("timing.json"))
        )
        let file = try AVAudioFile(forReading: folder.appendingPathComponent("recordings.wav"))
        var sounds: [String: [KeySounds]] = [:]
        for (key, ranges) in timing where ranges.count == 2 {
            guard let down = try clip(file, range: ranges[0]),
                  let up = try clip(file, range: ranges[1]) else { continue }
            sounds[key] = [KeySounds(down: down, up: up)]
        }
        guard sounds["KeyA"] != nil else { throw SoundError.missingSamples }
        return sounds
    }

    private func clip(_ file: AVAudioFile, range: [Double],
                      trimAttack: Bool = false) throws -> AVAudioPCMBuffer? {
        guard range.count == 2 else { return nil }
        let rate = file.processingFormat.sampleRate
        let start = AVAudioFramePosition((range[0] * rate / 1_000).rounded())
        let end = min(file.length, AVAudioFramePosition((range[1] * rate / 1_000).rounded()))
        guard start >= 0, end > start, rate == format.sampleRate else { return nil }
        let capacity = AVAudioFrameCount(end - start)
        guard let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity),
              let channels = source.floatChannelData,
              let mono = buffer.floatChannelData?[0] else { return nil }
        file.framePosition = start
        try file.read(into: source)
        buffer.frameLength = source.frameLength
        var length = Int(buffer.frameLength)
        let channelCount = Int(source.format.channelCount)
        for index in 0..<length {
            var sample: Float = 0
            for channel in 0..<channelCount {
                sample += channels[channel][index]
            }
            mono[index] = sample / Float(channelCount)
        }
        if trimAttack {
            let peak = (0..<length).map { abs(mono[$0]) }.max() ?? 0
            if let onset = (0..<length).first(where: { abs(mono[$0]) >= peak * 0.045 }) {
                let leadIn = max(0, onset - 16)
                if leadIn > 0 {
                    length -= leadIn
                    memmove(mono, mono.advanced(by: leadIn), length * MemoryLayout<Float>.stride)
                    buffer.frameLength = AVAudioFrameCount(length)
                }
            }
        }
        let attack = min(trimAttack ? 16 : 80, length / 2)
        let decay = min(trimAttack ? 882 : 80, length / 2)
        for index in 0..<attack {
            mono[index] *= Float(index) / Float(attack)
        }
        for index in 0..<decay {
            mono[length - 1 - index] *= Float(index) / Float(decay)
        }
        return buffer
    }

    func play(_ key: String, released: Bool, pan: Float, volume: Float) throws {
        let sampleKey = profile == .kProRed && key == "Delete"
            ? "Backspace" : key
        guard let variants = samples[sampleKey] ?? samples["KeyA"] else { throw SoundError.missingSamples }
        let sound = variants[nextVariant % variants.count]
        if !released { nextVariant = (nextVariant + 1) % 2 }
        try warmUp()
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.pan = pan
        voice.volume = volume * (profile == .kProRed && released ? 0.57 : 1)
        voice.scheduleBuffer(released ? sound.up : sound.down, at: nil, options: .interrupts)
        if !voice.isPlaying { voice.play() }
    }

    var outputDevice: AudioDeviceID { engine.outputNode.auAudioUnit.deviceID }

    func route(to device: AudioDeviceID) throws {
        guard device != kAudioObjectUnknown else { throw SoundError.outputUnavailable }
        if outputDevice != device {
            engine.stop()
            for voice in voices { voice.stop() }
            try engine.outputNode.auAudioUnit.setDeviceID(device)
        }
        try warmUp()
        guard outputDevice == device else { throw SoundError.outputUnavailable }
    }

    func warmUp() throws {
        guard !engine.isRunning else { return }
        engine.prepare()
        try engine.start()
        for voice in voices where !voice.isPlaying { voice.play() }
    }

    func stop() {
        for voice in voices {
            voice.stop()
            if engine.isRunning { voice.play() }
        }
    }
}

struct KeyboardKey {
    let sample: String
    let pan: Float

    static let keys: [UInt16: KeyboardKey] = {
        let rows: [[(UInt16, String)]] = [
            [(50,"Backquote"),(18,"Digit1"),(19,"Digit2"),(20,"Digit3"),(21,"Digit4"),(23,"Digit5"),
             (22,"Digit6"),(26,"Digit7"),(28,"Digit8"),(25,"Digit9"),(29,"Digit0"),(27,"Minus"),
             (24,"Equal"),(51,"Backspace")],
            [(48,"Tab"),(12,"KeyQ"),(13,"KeyW"),(14,"KeyE"),(15,"KeyR"),(17,"KeyT"),(16,"KeyY"),
             (32,"KeyU"),(34,"KeyI"),(31,"KeyO"),(35,"KeyP"),(33,"BracketLeft"),(30,"BracketRight"),
             (42,"Backslash")],
            [(57,"CapsLock"),(0,"KeyA"),(1,"KeyS"),(2,"KeyD"),(3,"KeyF"),(5,"KeyG"),(4,"KeyH"),
             (38,"KeyJ"),(40,"KeyK"),(37,"KeyL"),(41,"Semicolon"),(39,"Quote"),(36,"Enter")],
            [(56,"ShiftLeft"),(6,"KeyZ"),(7,"KeyX"),(8,"KeyC"),(9,"KeyV"),(11,"KeyB"),(45,"KeyN"),
             (46,"KeyM"),(43,"Comma"),(47,"Period"),(44,"Slash"),(60,"ShiftRight")],
            [(59,"ControlLeft"),(58,"AltLeft"),(55,"MetaLeft"),(49,"Space"),(54,"MetaRight"),
             (61,"AltRight"),(62,"ControlRight"),(123,"ArrowLeft"),(125,"ArrowDown"),(126,"ArrowUp"),
             (124,"ArrowRight")]
        ]
        var keys = Dictionary(uniqueKeysWithValues: rows.flatMap { row in
            row.enumerated().map { index, key in
                let pan = key.1 == "Space" ? 0 : (Float(index) / Float(row.count - 1) - 0.5) * 0.9
                return (key.0, KeyboardKey(sample: key.1, pan: pan))
            }
        })
        keys[76] = KeyboardKey(sample: "Enter", pan: 0.45)
        keys[117] = KeyboardKey(sample: "Delete", pan: 0.45)
        return keys
    }()

    static let modifierMasks: [UInt16: UInt64] = [
        54: 0x10, 55: 0x08, 56: 0x02, 58: 0x20, 59: 0x01,
        60: 0x04, 61: 0x40, 62: 0x2000
    ]
}

final class Keyfeel: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "enabled")
            if !enabled { playback.stop() }
        }
    }
    @Published var profile = Profile.available.first {
        $0.rawValue == UserDefaults.standard.string(forKey: "soundProfile")
    } ?? .preferred {
        didSet {
            UserDefaults.standard.set(profile.rawValue, forKey: "soundProfile")
            loadProfile()
        }
    }
    @Published var volume = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.65 {
        didSet { UserDefaults.standard.set(volume, forKey: "volume") }
    }
    @Published var tone = CGPoint(
        x: min(1, max(0, UserDefaults.standard.object(forKey: "toneBrightness") as? Double ?? 0.5)),
        y: min(1, max(0, UserDefaults.standard.object(forKey: "toneClack") as? Double ?? 0.5))
    ) {
        didSet {
            UserDefaults.standard.set(Double(tone.x), forKey: "toneBrightness")
            UserDefaults.standard.set(Double(tone.y), forKey: "toneClack")
            playback.setTone(tone)
        }
    }

    @Published private(set) var monitoring = false
    @Published private(set) var permissionGranted = false
    @Published private(set) var audioFailed = false

    private let playback = Playback()
    @Published private(set) var outputs: [AudioOutput] = []
    @Published private(set) var outputNote: String?
    @Published var outputID = UserDefaults.standard.string(forKey: "outputUID") ?? "" {
        didSet {
            UserDefaults.standard.set(outputID, forKey: "outputUID")
            refreshOutput()
        }
    }

    private lazy var panel = KeyfeelPanel(model: self)
    private var outsideClick: Any?
    private var statusItem: NSStatusItem?
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        playback.setTone(tone)
        loadProfile()
        refreshOutput()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Klick")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        refreshPermission()
        permissionTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermission()
            self?.refreshOutput()
        }
        if let permissionTimer { RunLoop.main.add(permissionTimer, forMode: .common) }
        if !monitoring { togglePopover() }
    }

    private func loadProfile() {
        do {
            try playback.load(profile)
            audioFailed = false
        } catch {
            audioFailed = true
        }
    }

    private func refreshOutput() {
        let available = AudioOutput.available()
        if outputs != available { outputs = available }
        let selected = available.first { $0.id == outputID }
        let system = AudioOutput.defaultDevice
        let device = selected?.device ?? system
        var note: String? = !outputID.isEmpty && selected == nil ? "Using system output" : nil
        do {
            try playback.route(to: device)
        } catch {
            do {
                try playback.route(to: system)
                note = "Using system output"
            } catch {
                note = "Output unavailable"
            }
        }
        if outputNote != note { outputNote = note }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !panel.isVisible { togglePopover() }
        return false
    }

    @objc private func togglePopover() {
        if panel.isVisible {
            dismissPanel()
            return
        }
        guard let button = statusItem?.button, let window = button.window,
              let screen = window.screen else { return }
        refreshOutput()
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        panel.show(below: anchor, on: screen)
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in self?.dismissPanel()
        }
    }

    func dismissPanel() {
        panel.orderOut(nil)
        if let outsideClick { NSEvent.removeMonitor(outsideClick) }
        outsideClick = nil
    }

    func requestPermission() {
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        refreshPermission()
        if !monitoring,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshPermission() {
        let granted = CGPreflightListenEventAccess()
        if permissionGranted != granted { permissionGranted = granted }
        if !granted, let eventTap {
            if let eventSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, .commonModes) }
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
            eventSource = nil
            monitoring = false
        }
        guard granted, eventTap == nil else { return }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) {
            $0 | (1 << $1.rawValue)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: { _, type, event, context in
                if let context {
                    Unmanaged<Keyfeel>.fromOpaque(context).takeUnretainedValue().handle(type, event)
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return }
        eventTap = tap
        eventSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        monitoring = true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return
        }
        guard enabled, volume > 0, !audioFailed,
              event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
        let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let released: Bool
        switch type {
        case .keyDown: released = false
        case .keyUp: released = true
        case .flagsChanged:
            if code == 57 {
                released = false
            } else if let mask = KeyboardKey.modifierMasks[code] {
                released = event.flags.rawValue & mask == 0
            } else {
                return
            }
        default: return
        }
        let key = KeyboardKey.keys[code] ?? KeyboardKey(sample: "KeyA", pan: 0)
        play(key, released: released)
    }

    private func play(_ key: KeyboardKey, released: Bool) {
        do {
            try playback.play(key.sample, released: released, pan: key.pan, volume: Float(volume))
            audioFailed = false
        } catch {
            audioFailed = true
        }
    }

    func preview() {
        loadProfile()
        guard !audioFailed else { return }
        let profile = self.profile
        for (index, code) in [UInt16(3), 34, 37, 49].enumerated() {
            guard let key = KeyboardKey.keys[code] else { continue }
            for released in [false, true] {
                let delay = Double(index) * 0.13 + (released ? 0.075 : 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, self.profile == profile else { return }
                    self.play(key, released: released)
                }
            }
        }
    }
}
