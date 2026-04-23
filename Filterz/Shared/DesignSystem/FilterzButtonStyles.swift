import SwiftUI

struct CapsulePrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
                    .tint(.black)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(isDisabled ? Color.filterzBorder : Color.filterzAccent)
        .clipShape(Capsule())
        .opacity(configuration.isPressed ? 0.8 : 1.0)
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CapsuleOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.filterzTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .overlay(Capsule().stroke(Color.filterzBorder, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
