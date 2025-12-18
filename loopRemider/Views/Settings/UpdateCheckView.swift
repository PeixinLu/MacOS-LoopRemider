import SwiftUI

struct UpdateCheckView: View {
    @StateObject private var updateChecker = UpdateChecker()
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题
            HStack {
                PageHeader(
                    icon: "arrow.down.circle.fill",
                    iconColor: .blue,
                    title: "检查更新",
                    subtitle: "当前版本：\(updateChecker.currentVersion)"
                )
                
                Spacer()
                
                if updateChecker.checkResult == nil || !updateChecker.isChecking {
                    Button("检查更新") {
                        updateChecker.checkForUpdates()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.trailing, DesignTokens.Spacing.lg)
            
            Divider()
            
            // 内容区域
            if updateChecker.isChecking {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在检查更新...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if let result = updateChecker.checkResult {
                resultView(for: result)
            } else {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "点击上方按钮检查更新"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func resultView(for result: UpdateCheckResult) -> some View {
        switch result {
        case .upToDate:
            VStack(spacing: DesignTokens.Spacing.lg) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                Text("已是最新版本")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("当前版本：\(updateChecker.currentVersion)")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
        case .newVersionAvailable(let release):
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // 新版本提示
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.orange)
                        Text("发现新版本")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    // 版本信息
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack {
                            Text("当前版本：")
                                .foregroundColor(.secondary)
                            Text(updateChecker.currentVersion)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("最新版本：")
                                .foregroundColor(.secondary)
                            Text(normalizeVersionDisplay(release.tagName))
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        if let publishedAt = release.publishedAt {
                            HStack {
                                Text("发布时间：")
                                    .foregroundColor(.secondary)
                                Text(formatDate(publishedAt))
                            }
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall))
                    
                    // 更新说明
                    if !release.body.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("更新说明：")
                                .font(.headline)
                            Text(release.body)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall))
                        
                        InfoHint("请前往GitHub下载并手动替换app", color: .orange)
                    }
                    
                    // 下载按钮
                    Button(action: {
                        updateChecker.openReleasePage(release.htmlUrl)
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("前往 GitHub 下载")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                        .padding(DesignTokens.Spacing.sm)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                }
                .padding(DesignTokens.Spacing.md)
            }
            
        case .error(let message):
            VStack(spacing: DesignTokens.Spacing.lg) {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                Text("检查更新失败")
                    .font(.title3)
                    .fontWeight(.medium)
                Text(message)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.md)
        }
    }
    
    // 格式化版本号显示（去掉 Version 前缀）
    private func normalizeVersionDisplay(_ version: String) -> String {
        return version
            .replacingOccurrences(of: "^[vV]ersion", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "^[vV]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    // 格式化日期
    private func formatDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoDate) else {
            return isoDate
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "zh_CN")
        return displayFormatter.string(from: date)
    }
}

#Preview {
    UpdateCheckView()
}
