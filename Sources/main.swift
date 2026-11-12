import AppKit

if CommandLine.arguments.contains("--check-output") {
    do {
        let playback = Playback()
        try playback.load(.preferred)
        let system = AudioOutput.defaultDevice
        try playback.route(to: system)
        for output in AudioOutput.available() {
            try playback.route(to: output.device)
            try playback.play("KeyA", released: false, pan: 0, volume: 0.4)
            Thread.sleep(forTimeInterval: 0.25)
            print("Verified output: \(output.name)")
        }
        try playback.route(to: system)
        guard AudioOutput.defaultDevice == system else { throw SoundError.outputUnavailable }
        exit(EXIT_SUCCESS)
    } catch {
        fputs("\(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

if CommandLine.arguments.contains("--check-audio") {
    do {
        let playback = Playback()
        guard Profile.available.contains(.red), Profile.available.count >= 4 else { throw SoundError.missingSamples }
        for profile in Profile.available {
            try playback.load(profile)
            if CommandLine.arguments.contains("--play-preview") {
                try playback.play("KeyA", released: false, pan: -0.2, volume: 0.45)
                Thread.sleep(forTimeInterval: 0.12)
                try playback.play("KeyA", released: true, pan: -0.2, volume: 0.45)
                Thread.sleep(forTimeInterval: 0.15)
            }
            print("Loaded \(profile.title)")
        }
        exit(EXIT_SUCCESS)
    } catch {
        fputs("\(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

let app = NSApplication.shared
let delegate = Keyfeel()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
