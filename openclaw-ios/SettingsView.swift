import Observation
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Gateway") {
                    TextField("ws://127.0.0.1:18789", text: $viewModel.gatewayUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Token", text: $viewModel.gatewayToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("保存") {
                        viewModel.save()
                        dismiss()
                    }
                    Button("清除 Token", role: .destructive) {
                        viewModel.clearToken()
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}
