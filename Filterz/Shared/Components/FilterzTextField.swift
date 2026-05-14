import SwiftUI

struct FilterzTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var error: String? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundColor(.filterzTextSecondary)
                        .frame(width: 20)
                }
                TextField(placeholder, text: $text)
                    .foregroundColor(.filterzGray30)
                    .tint(.filterzAccent)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .focused($isFocused)
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
