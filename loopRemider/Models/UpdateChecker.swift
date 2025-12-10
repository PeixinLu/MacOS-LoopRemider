import Foundation
import Combine
import AppKit

// GitHub Pages Release 数据模型
struct GitHubRelease: Codable {
    let version: String
    let url: String
    let notes: String
    let publishedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case version
        case url
        case notes
        case publishedAt = "published_at"
    }
    
    // 为了兼容旧代码，提供计算属性
    var tagName: String { version }
    var htmlUrl: String { url }
    var body: String { notes }
}

// 更新检查结果
enum UpdateCheckResult {
    case upToDate
    case newVersionAvailable(GitHubRelease)
    case error(String)
}

// 更新检查服务
class UpdateChecker: ObservableObject {
    @Published var isChecking = false
    @Published var checkResult: UpdateCheckResult?
    
    // 从 Info.plist 读取当前版本号
    var currentVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.0" // 默认版本
    }
    
    private let repoURL = "https://peixinlu.github.io/MacOS-LoopRemider/latest.json"
    
    // 检查更新
    func checkForUpdates() {
        isChecking = true
        checkResult = nil
        
        guard let url = URL(string: repoURL) else {
            checkResult = .error("无效的 URL")
            isChecking = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChecking = false
                
                if let error = error {
                    self?.checkResult = .error("网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self?.checkResult = .error("未收到数据")
                    return
                }
                
                // 调试：打印原始响应数据
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📝 GitHub API 响应:")
                    print(jsonString)
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    
                    // 比较版本号
                    if self?.isNewerVersion(release.tagName) == true {
                        self?.checkResult = .newVersionAvailable(release)
                    } else {
                        self?.checkResult = .upToDate
                    }
                } catch let decodingError {
                    print("❌ 解析错误: \(decodingError)")
                    if let decodingError = decodingError as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            self?.checkResult = .error("缺少字段: \(key.stringValue) - \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            self?.checkResult = .error("类型不匹配: \(type) - \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            self?.checkResult = .error("值为空: \(type) - \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            self?.checkResult = .error("数据损坏: \(context.debugDescription)")
                        @unknown default:
                            self?.checkResult = .error("解析数据失败: \(decodingError.localizedDescription)")
                        }
                    } else {
                        self?.checkResult = .error("解析数据失败: \(decodingError.localizedDescription)")
                    }
                }
            }
        }.resume()
    }
    
    // 比较版本号
    private func isNewerVersion(_ remoteVersion: String) -> Bool {
        let current = normalizeVersion(currentVersion)
        let remote = normalizeVersion(remoteVersion)
        
        // 调试信息
        print("🔍 版本比较:")
        print("  当前版本原始: \(currentVersion)")
        print("  当前版本标准化: \(current)")
        print("  远程版本原始: \(remoteVersion)")
        print("  远程版本标准化: \(remote)")
        
        let isNewer = remote.compare(current, options: .numeric) == .orderedDescending
        print("  是否有新版本: \(isNewer)")
        
        return isNewer
    }
    
    // 标准化版本号（去掉 v 或 Version 前缀，支持 Version0.1.x 格式）
    private func normalizeVersion(_ version: String) -> String {
        // 移除常见前缀：version, Version, v, V（注意顺序，先匹配长的）
        var normalized = version
            .replacingOccurrences(of: "^[vV]ersion", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "^[vV]", with: "", options: .regularExpression)
        
        // 移除空格
        normalized = normalized.trimmingCharacters(in: .whitespaces)
        
        return normalized
    }
    
    // 打开 Release 页面
    func openReleasePage(_ url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}
