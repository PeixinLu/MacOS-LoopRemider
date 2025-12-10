import SwiftUI

struct UpdateCheckView: View {
    @StateObject private var updateChecker = UpdateChecker()
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "arrow.down.circle")
                    .font(.title)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("检查更新")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("当前版本：\(updateChecker.currentVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top)
            
            Divider()
            
            // 内容区域
            if updateChecker.isChecking {
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在检查更新...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result = updateChecker.checkResult {
                resultView(for: result)
            } else {
                VStack(spacing: 15) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("点击下方按钮检查更新")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            // 底部按钮
            HStack {
                if updateChecker.checkResult == nil || !updateChecker.isChecking {
                    Button("检查更新") {
                        updateChecker.checkForUpdates()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
            .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func resultView(for result: UpdateCheckResult) -> some View {
        switch result {
        case .upToDate:
            VStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                Text("已是最新版本")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("当前版本：\(updateChecker.currentVersion)")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .newVersionAvailable(let release):
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // 新版本提示
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.orange)
                        Text("发现新版本")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    // 版本信息
                    VStack(alignment: .leading, spacing: 8) {
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
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // 更新说明
                    if !release.body.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("更新说明：")
                                .font(.headline)
                            Text(release.body)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("请前往GitHub下载并手动替换app⬇️")
                            
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
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
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            
        case .error(let message):
            VStack(spacing: 15) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                Text("检查更新失败")
                    .font(.title3)
                    .fontWeight(.medium)
                Text(message)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
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
