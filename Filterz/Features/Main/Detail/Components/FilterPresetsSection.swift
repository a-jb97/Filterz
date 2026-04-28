import SwiftUI

struct FilterPresetsSection: View {
    let presets: FilterPresetValues
    let isUnlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filter Presets")
                    .font(.pretendard(14, weight: .bold))
                    .foregroundColor(.filterzGray60)
                Spacer()
                Text("LUT")
                    .font(.pretendard(11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.filterzAccent))
            }

            if isUnlocked {
                unlockedGrid
            } else {
                lockedOverlay
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.filterzBlackTurquoise)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.filterzTranslucent, lineWidth: 1)
                )
        )
    }

    private var unlockedGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()),
                      GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            ForEach(presets.displayParams, id: \.name) { param in
                presetCell(name: param.name, value: param.value)
            }
        }
    }

    private func presetCell(name: String, value: Float) -> some View {
        VStack(spacing: 4) {
            Image(systemName: parameterIcon(for: name))
                .foregroundColor(.filterzGray45)
                .font(.system(size: 18))

            Text(String(format: "%.1f", value))
                .font(.pretendard(13, weight: .bold))
                .foregroundColor(.filterzGray30)
        }
    }

    private var lockedOverlay: some View {
        ZStack {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()),
                          GridItem(.flexible()), GridItem(.flexible())],
                spacing: 16
            ) {
                ForEach(0..<8, id: \.self) { _ in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color.filterzGray75)
                            .frame(width: 24, height: 24)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.filterzGray75)
                            .frame(width: 28, height: 10)
                    }
                }
            }
            .blur(radius: 5)

            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.filterzGray60)
                Text("결제가 필요한 유료 필터입니다")
                    .font(.pretendard(13, weight: .medium))
                    .foregroundColor(.filterzGray60)
            }
            .padding(.vertical, 16)
        }
    }

    private func parameterIcon(for name: String) -> String {
        switch name {
        case "Brightness":   return "sun.max"
        case "Exposure":     return "light.max"
        case "Contrast":     return "circle.lefthalf.filled"
        case "Saturation":   return "drop"
        case "Sharpness":    return "triangle"
        case "Blur":         return "camera.filters"
        case "Vignette":     return "camera"
        case "NR":           return "waveform.path.ecg"
        case "Highlights":   return "sun.min"
        case "Shadows":      return "shadow"
        case "Temperature":  return "thermometer.medium"
        case "BlackPoint":   return "circle.fill"
        default:             return "slider.horizontal.3"
        }
    }
}
