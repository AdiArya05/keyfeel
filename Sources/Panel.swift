import SwiftUI

final class KeyfeelPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(model: Keyfeel) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        title = "Keyfeel"
        appearance = NSAppearance(named: .aqua)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        let hosting = NSHostingView(rootView: Panel(model: model))
        let size = hosting.fittingSize
        let bounds = NSRect(origin: .zero, size: size)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: bounds)
            glass.style = .regular
            glass.cornerRadius = 24
            glass.tintColor = NSColor.white.withAlphaComponent(0.18)
            glass.contentView = hosting
            contentView = glass
        } else {
            let backdrop = NSVisualEffectView(frame: bounds)
            backdrop.material = .popover
            backdrop.blendingMode = .behindWindow
            backdrop.state = .active
            backdrop.wantsLayer = true
            backdrop.layer?.cornerRadius = 24
            backdrop.layer?.cornerCurve = .continuous
            backdrop.layer?.masksToBounds = true
            contentView = backdrop
            hosting.frame = backdrop.bounds
            hosting.autoresizingMask = [.width, .height]
            backdrop.addSubview(hosting)
        }
        setContentSize(size)
    }

    func show(below anchor: NSRect, on screen: NSScreen) {
        let bounds = screen.visibleFrame
        let x = min(bounds.maxX - frame.width - 8, max(bounds.minX + 8, anchor.midX - frame.width / 2))
        setFrameTopLeftPoint(NSPoint(x: x, y: min(anchor.minY, bounds.maxY) - 5))
        makeKeyAndOrderFront(nil)
    }
}

struct Panel: View {
    @ObservedObject var model: Keyfeel

    private var status: String {
        if model.audioFailed { return "Audio unavailable" }
        if !model.permissionGranted { return "Input Monitoring required" }
        if !model.monitoring { return "Reopen to start listening" }
        return model.enabled ? "Typing sounds on" : "Typing sounds paused"
    }

    private var outputTitle: String {
        guard !model.outputID.isEmpty else { return "System Default" }
        return model.outputs.first { $0.id == model.outputID }?.name ?? "Disconnected"
    }

    private var accent: Color { model.enabled ? .green : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyfeel")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ZStack {
                    Circle().strokeBorder(.secondary.opacity(0.19), lineWidth: 4)
                    Circle().trim(from: 0, to: model.enabled ? model.volume : 0)
                        .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(2)
                    Image(systemName: "keyboard").font(.system(size: 18, weight: .medium))
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.profile.title).font(.system(size: 16, weight: .semibold))
                    Text(status).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Toggle("Typing sounds", isOn: $model.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }

            Divider()

            VStack(alignment: .leading, spacing: 11) {
                Text("Sound").font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
                HStack {
                    Text("Switch")
                    Spacer()
                    Menu {
                        ForEach(Profile.available) { profile in
                            Button {
                                model.profile = profile
                            } label: {
                                if model.profile == profile { Label(profile.title, systemImage: "checkmark") }
                                else { Text(profile.title) }
                            }
                        }
                    } label: { menuValue(model.profile.title) }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("Switch")
                }
                HStack {
                    Text("Output")
                    Spacer(minLength: 8)
                    Menu {
                        outputChoice("System Default", id: "")
                        if !model.outputs.isEmpty { Divider() }
                        ForEach(model.outputs) { output in outputChoice(output.name, id: output.id) }
                    } label: { menuValue(outputTitle) }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("Audio output")
                }
                SoundControls(volume: $model.volume, tone: $model.tone)
            }
            .font(.system(size: 13))

            HStack {
                if !model.permissionGranted {
                    Button("Enable Input Monitoring") { model.requestPermission() }
                        .buttonStyle(.plain)
                } else {
                    Text(model.outputNote ?? model.profile.detail).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    model.preview()
                } label: {
                    Image(systemName: "play.fill").padding(.horizontal, 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview sound")
                .help("Preview sound")
                Menu {
                    Button("Quit Keyfeel") { NSApp.terminate(nil) }
                        .keyboardShortcut("q", modifiers: .command)
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("More")
            }
            .font(.system(size: 12))
        }
        .padding(20)
        .frame(width: 356)
        .onExitCommand { model.dismissPanel() }
    }

    private func menuValue(_ value: String) -> some View {
        HStack(spacing: 5) {
            Text(value).fontWeight(.semibold).lineLimit(1).truncationMode(.tail)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 210, alignment: .trailing)
    }

    private func outputChoice(_ title: String, id: String) -> some View {
        Button {
            model.outputID = id
        } label: {
            if model.outputID == id { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }
}
