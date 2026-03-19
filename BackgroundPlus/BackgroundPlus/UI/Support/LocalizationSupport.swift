import Foundation

func localized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key))
}
