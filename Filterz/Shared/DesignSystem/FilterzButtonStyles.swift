import SwiftUI

struct CapsulePrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .font(.filterzBody())
                .foregroundColor(.filterzAccent)
                .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
                    .tint(.filterzAccent)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Color.filterzBackground)
        .clipShape(Capsule())
        .opacity(isDisabled ? 0.45 : (configuration.isPressed ? 0.8 : 1.0))
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CapsuleOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.filterzBody())
            .foregroundColor(.filterzAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.filterzBackground)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
