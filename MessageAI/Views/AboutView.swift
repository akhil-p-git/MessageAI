import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://example.com/privacy")!) {
                    Text("Privacy Policy")
                }
                
                Link(destination: URL(string: "https://example.com/terms")!) {
                    Text("Terms of Service")
                }
            }
            
            Section {
                Link(destination: URL(string: "https://example.com/support")!) {
                    Text("Help & Support")
                }
                
                Link(destination: URL(string: "https://example.com/feedback")!) {
                    Text("Send Feedback")
                }
            }
            
            Section {
                Text("MessageAI")
                    .font(.headline)
                
                Text("A modern messaging app with AI capabilities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
