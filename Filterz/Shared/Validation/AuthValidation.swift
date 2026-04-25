import Foundation

enum AuthValidation {

    // MARK: - Email

    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Password

    struct PasswordRequirements: Equatable {
        let hasMinLength: Bool
        let hasLetter: Bool
        let hasNumber: Bool
        let hasSpecialChar: Bool

        var isValid: Bool {
            hasMinLength && hasLetter && hasNumber && hasSpecialChar
        }
    }

    static func checkPasswordRequirements(_ password: String) -> PasswordRequirements {
        let specialChars = CharacterSet(charactersIn: "@$!%*#?&")
        return PasswordRequirements(
            hasMinLength:   password.count >= 8,
            hasLetter:      password.unicodeScalars.contains { CharacterSet.letters.contains($0) },
            hasNumber:      password.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) },
            hasSpecialChar: password.unicodeScalars.contains { specialChars.contains($0) }
        )
    }

    static func isValidPassword(_ password: String) -> Bool {
        checkPasswordRequirements(password).isValid
    }

    // MARK: - Nickname

    static func isValidNickname(_ nickname: String) -> Bool {
        let forbiddenPattern = #"[-.,?*@+^${}()|[\]\\]"#
        return nickname.range(of: forbiddenPattern, options: .regularExpression) == nil
    }
}
