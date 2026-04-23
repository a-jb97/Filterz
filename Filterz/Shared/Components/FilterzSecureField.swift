import SwiftUI

struct FilterzSecureField: View {
    let placeholder: String
    @Binding var text: String
    var isVisible: Bool = false
    var onToggleVisibility: (() -> Void)? = nil
    var icon: String? = nil
    var error: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundColor(.filterzTextSecondary)
                        .frame(width: 20)
                }
                Group {
                    if isVisible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .foregroundColor(.filterzTextPrimary)
                .tint(.filterzAccent)
                .autocorrectionDisabled()
                .focused($isFocused)

                if onToggleVisibility != nil {
                    Button {
                        onToggleVisibility?()
                    } label: {
                        Image(systemName: isVisible ? "eye.slash" : "eye")
                            .foregroundColor(.filterzTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.filterzSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )

            if let error {
                Text(error)
                    .font(.filterzCaption())
                    .foregroundColor(.filterzError)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var borderColor: Color {
        if isFocused { return .filterzAccent }
        if error != nil { return .filterzError }
        return .filterzBorder
    }
}
