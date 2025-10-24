import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var currentColorScheme
    
    var body: some View {
        List {
            Section(header: Text("Theme")) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        print("🎨 User tapped: \(theme.rawValue)")
                        withAnimation {
                            themeManager.setTheme(theme)
                        }
                    } label: {
                        HStack {
                            Text(theme.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if themeManager.selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
            
            Section(header: Text("Current Status")) {
                HStack {
                    Text("Selected Theme:")
                    Spacer()
                    Text(themeManager.selectedTheme.rawValue)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Current Appearance:")
                    Spacer()
                    Text(currentColorScheme == .dark ? "Dark" : "Light")
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Text("Choose how MessageAI looks. The System option will automatically match your device's appearance settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(ThemeManager())
    }
}
