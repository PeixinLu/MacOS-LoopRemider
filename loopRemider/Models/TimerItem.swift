import SwiftUI
import Foundation

// 计时器项目模型
struct TimerItem: Identifiable, Codable {
    var id: UUID
    var emoji: String // 图标
    var title: String // 通知标题（也作为计时器名称）
    var body: String // 通知内容
    var intervalSeconds: Double // 通知间隔（秒）
    var isRestEnabled: Bool // 是否启用休息
    var restSeconds: Double // 休息时长（秒）
    var customColor: TimerColor? // 自定义颜色（优先于全局样式）
    var lastFireEpoch: Double // 上次触发时间
    var isRunning: Bool = false // 是否正在运行（不持久化）
    
    // 计算属性：显示名称（使用标题，如果为空则用"计时器+数字"）
    var displayName: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "计时器" : trimmedTitle
    }
    
    /// 计时器颜色配置
    struct TimerColor: Codable, Equatable {
        var colorType: ColorType
        var customR: Double?
        var customG: Double?
        var customB: Double?
        
        enum ColorType: String, Codable, CaseIterable {
            case black = "黑色"
            case blue = "蓝色"
            case purple = "紫色"
            case green = "绿色"
            case orange = "橙色"
            case red = "红色"
            case teal = "青色"
            case custom = "自定义"
        }
        
        func toColor() -> Color {
            switch colorType {
            case .black: return .black
            case .blue: return .blue
            case .purple: return .purple
            case .green: return .green
            case .orange: return .orange
            case .red: return .red
            case .teal: return .teal
            case .custom:
                if let r = customR, let g = customG, let b = customB {
                    return Color(red: r, green: g, blue: b)
                }
                return .gray
            }
        }
        
        static func from(appSettingsColor: AppSettings.OverlayColor, customColor: Color? = nil) -> TimerColor {
            switch appSettingsColor {
            case .black:
                return TimerColor(colorType: .black)
            case .blue:
                return TimerColor(colorType: .blue)
            case .purple:
                return TimerColor(colorType: .purple)
            case .green:
                return TimerColor(colorType: .green)
            case .orange:
                return TimerColor(colorType: .orange)
            case .red:
                return TimerColor(colorType: .red)
            case .teal:
                return TimerColor(colorType: .teal)
            case .custom:
                if let color = customColor {
                    let components = color.components()
                    return TimerColor(
                        colorType: .custom,
                        customR: components.red,
                        customG: components.green,
                        customB: components.blue
                    )
                }
                return TimerColor(colorType: .custom, customR: 0.5, customG: 0.5, customB: 0.5)
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        emoji: String = "🔔",
        title: String = "提醒",
        body: String = "起来活动一下",
        intervalSeconds: Double = 1800,
        isRestEnabled: Bool = false,
        restSeconds: Double = 300,
        customColor: TimerColor? = nil,
        lastFireEpoch: Double = 0
    ) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.body = body
        self.intervalSeconds = intervalSeconds
        self.isRestEnabled = isRestEnabled
        self.restSeconds = restSeconds
        self.customColor = customColor
        self.lastFireEpoch = lastFireEpoch
        self.isRunning = false
    }
    
    var lastFireDate: Date? {
        guard lastFireEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: lastFireEpoch)
    }
    
    mutating func markFiredNow() {
        lastFireEpoch = Date().timeIntervalSince1970
    }
    
    func formattedInterval() -> String {
        let seconds = Int(intervalSeconds)
        if seconds < 60 {
            return "\(seconds) 秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) 分钟"
            } else {
                return "\(minutes) 分 \(remainingSeconds) 秒"
            }
        } else {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            if remainingMinutes == 0 {
                return "\(hours) 小时"
            } else {
                return "\(hours) 小时 \(remainingMinutes) 分钟"
            }
        }
    }
    
    func formattedRestInterval() -> String {
        let seconds = Int(restSeconds)
        if seconds < 60 {
            return "\(seconds) 秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) 分钟"
            } else {
                return "\(minutes) 分 \(remainingSeconds) 秒"
            }
        } else {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            if remainingMinutes == 0 {
                return "\(hours) 小时"
            } else {
                return "\(hours) 小时 \(remainingMinutes) 分钟"
            }
        }
    }
    
    /// 验证内容是否有效（至少有一项不为空）
    func isContentValid() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !trimmedTitle.isEmpty || !trimmedBody.isEmpty || !trimmedEmoji.isEmpty
    }
    
    // Codable: 不序列化 isRunning 字段
    enum CodingKeys: String, CodingKey {
        case id, emoji, title, body, intervalSeconds
        case isRestEnabled, restSeconds, customColor, lastFireEpoch
    }
}
