import SwiftUI

struct SoundControls: View {
    @Binding var volume: Double
    @Binding var tone: CGPoint

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(spacing: 7) {
                volumeControl.frame(width: 44, height: 140)
                Text("Volume \(volume.formatted(.percent.precision(.fractionLength(0))))")
                    .monospacedDigit()
            }
            VStack(spacing: 7) {
                axisLabels("Warm", "Bright")
                tonePad.frame(height: 140)
                axisLabels("↓ Thock", "Clack ↑")
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private var volumeControl: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Capsule().fill(.secondary.opacity(0.18))
                Rectangle().fill(.white.opacity(0.96))
                    .frame(height: geometry.size.height * volume)
                Image(systemName: volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(volume > 0.18 ? Color.black.opacity(0.65) : Color.primary)
                    .padding(.bottom, 13)
            }
            .clipShape(Capsule())
            .overlay { Capsule().strokeBorder(.primary.opacity(0.08)) }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged {
                volume = Double(unit(1 - $0.location.y / geometry.size.height))
            })
        }
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue(volume.formatted(.percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction {
            switch $0 {
            case .increment: volume = Double(unit(volume + 0.05))
            case .decrement: volume = Double(unit(volume - 0.05))
            @unknown default: break
            }
        }
    }

    private var tonePad: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 13
            let width = geometry.size.width - 2 * inset
            let height = geometry.size.height - 2 * inset
            let marker = CGPoint(x: inset + tone.x * width, y: inset + (1 - tone.y) * height)
            let shape = RoundedRectangle(cornerRadius: 15)
            ZStack {
                shape.fill(.linearGradient(colors: [Color(white: 0.18), Color(white: 0.31)],
                                           startPoint: .top, endPoint: .bottomTrailing))
                Canvas { context, _ in
                    for column in 0...10 {
                        for row in 0...6 {
                            let x = inset + width * CGFloat(column) / 10
                            let y = inset + height * CGFloat(row) / 6
                            let highlighted = abs(x - marker.x) <= width / 20 ||
                                abs(y - marker.y) <= height / 12
                            let dot = CGRect(x: x - 1.35, y: y - 1.35, width: 2.7, height: 2.7)
                            context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(highlighted ? 0.41 : 0.19)))
                        }
                    }
                }
                Circle().fill(.white).frame(width: 15, height: 15)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                    .position(marker)
            }
            .overlay { shape.strokeBorder(.white.opacity(0.16)) }
            .contentShape(shape)
            .gesture(DragGesture(minimumDistance: 0).onChanged {
                tone = CGPoint(x: unit(($0.location.x - inset) / width),
                               y: unit(1 - ($0.location.y - inset) / height))
            })
        }
        .accessibilityRepresentation {
            Slider(value: $tone.x, in: 0...1) { Text("Brightness") }
            Slider(value: $tone.y, in: 0...1) { Text("Thock to clack") }
        }
    }

    private func axisLabels(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left)
            Spacer()
            Text(right)
        }
        .accessibilityHidden(true)
    }

    private func unit(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
}
