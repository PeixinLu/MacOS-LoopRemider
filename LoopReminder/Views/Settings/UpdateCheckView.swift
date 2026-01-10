import SwiftUI

struct UpdateCheckView: View {
    @StateObject private var updater = AppUpdater.shared

    private var feedURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题
            HStack {
                PageHeader(
                    icon: "arrow.down.circle.fill",
                    iconColor: .blue,
                    title: "检查更新",
                    subtitle: "当前版本：\(updater.versionDescription)"
                )
                
                Spacer()
                
                Button("检查更新") {
                    updater.checkForUpdates()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.trailing, DesignTokens.Spacing.lg)
            
            Divider()
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                SettingsSection(showDivider: false) {
                    HStack {
                        Text("当前版本")
                        Spacer()
                        Text(updater.versionDescription)
                            .foregroundColor(.secondary)
                    }
                }

                if !feedURL.isEmpty {
                    SettingsSection(showDivider: false) {
                        Text("更新源：\(feedURL)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                SettingsSection(showDivider: false) {
                    Toggle(
                        "自动检查更新",
                        isOn: Binding(
                            get: { updater.automaticallyChecksForUpdates },
                            set: { newValue in
                                updater.setAutomaticallyChecksForUpdates(newValue)
                            }
                        )
                    )
                    .toggleStyle(.switch)
                }

                InfoHint("点击“检查更新”后，Sparkle 会提示安装并在安装后自动替换并重启应用。", color: .blue)
            }
            .padding(.trailing, DesignTokens.Spacing.lg)
            .frame(maxWidth: 520, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    UpdateCheckView()
}
