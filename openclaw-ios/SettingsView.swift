import Observation
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SettingsCard(title: "Gateway 地址") {
                        TextField("ws://127.0.0.1:18789", text: $viewModel.gatewayUrl)
                            .font(.system(.body, design: .rounded))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(ChatUIStyle.inputBackground)
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ChatUIStyle.inputBorder, lineWidth: 1)
                            )
                        Text("示例：ws://127.0.0.1:18789")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    SettingsCard(title: "Token") {
                        SecureField("请输入 Token", text: $viewModel.gatewayToken)
                            .font(.system(.body, design: .rounded))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(ChatUIStyle.inputBackground)
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ChatUIStyle.inputBorder, lineWidth: 1)
                            )
                        Text("Token 用于安全连接网关")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        saveAndDismiss()
                    } label: {
                        Text("保存并返回")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ChatUIStyle.sendButton)
                            .foregroundStyle(.white)
                            .clipShape(.rect(cornerRadius: 14))
                    }

                    Button(role: .destructive) {
                        viewModel.clearToken()
                    } label: {
                        Text("清除 Token")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(ChatUIStyle.errorText)
                            .background(Color.clear)
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(ChatUIStyle.errorText.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveAndDismiss()
                    }
                }
            }
        }
    }

    private func saveAndDismiss() {
        viewModel.save()
        dismiss()
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .background(ChatUIStyle.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ChatUIStyle.cardBorder, lineWidth: 1)
        )
    }
}
