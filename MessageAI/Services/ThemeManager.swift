import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil  // nil means follow system
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("appTheme") private var storedTheme: String = AppTheme.system.rawValue
    
    @Published var selectedTheme: AppTheme = .system
    
    init() {
        // Load saved theme or default to system
        if let theme = AppTheme(rawValue: storedTheme) {
            selectedTheme = theme
        } else {
            selectedTheme = .system
        }
        print("📱 Theme initialized: \(selectedTheme.rawValue)")
    }
    
    var currentColorScheme: ColorScheme? {
        return selectedTheme.colorScheme
    }
    
    // Update theme and save to storage
    func setTheme(_ theme: AppTheme) {
        selectedTheme = theme
        storedTheme = theme.rawValue
        print("✅ Theme changed to: \(theme.rawValue)")
    }
}

