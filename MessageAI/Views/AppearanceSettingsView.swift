import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "System"
    
    private let themes = ["Light", "Dark", "System"]
    
    var body: some View {
        List {
            Section {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(themes, id: \.self) { theme in
                        Text(theme).tag(theme)
                    }
                }
                .pickerStyle(.inline)
            } footer: {
                Text("Choose how MessageAI looks")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
