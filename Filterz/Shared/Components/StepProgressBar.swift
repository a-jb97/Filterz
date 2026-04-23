import SwiftUI

struct StepProgressBar: View {
    let totalSteps: Int
    let currentStep: Int  // 0-indexed

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.filterzAccent : Color.filterzBorder)
                    .frame(height: 3)
                    .frame(maxWidth: index == currentStep ? .infinity : 30)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(height: 3)
    }
}
