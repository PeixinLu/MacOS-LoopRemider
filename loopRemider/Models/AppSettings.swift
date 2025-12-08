//
//  AppSettings.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI
import Combine

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let isRunning = "isRunning"
        static let intervalSeconds = "intervalSeconds"
        static let notifTitle = "notifTitle"
        static let notifBody = "notifBody"
        static let notifEmoji = "notifEmoji"
        static let lastFire = "lastFire"
        static let notificationMode = "notificationMode"
        static let overlayPosition = "overlayPosition"
        static let overlayColor = "overlayColor"
        static let overlayOpacity = "overlayOpacity"
        static let overlayFadeDelay = "overlayFadeDelay"
        static let overlayFadeStartDelay = "overlayFadeStartDelay"
        static let overlayFadeDuration = "overlayFadeDuration"
        // 新增样式配置
        static let overlayTitleFontSize = "overlayTitleFontSize"
        static let overlayIconSize = "overlayIconSize"
        static let overlayCornerRadius = "overlayCornerRadius"
        static let overlayEdgePadding = "overlayEdgePadding"
        static let overlayContentSpacing = "overlayContentSpacing"
        static let overlayUseBlur = "overlayUseBlur"
        static let overlayBlurIntensity = "overlayBlurIntensity"
        static let overlayWidth = "overlayWidth"
        static let overlayHeight = "overlayHeight"
        static let overlayCustomColorR = "overlayCustomColorR"
        static let overlayCustomColorG = "overlayCustomColorG"
        static let overlayCustomColorB = "overlayCustomColorB"
    }

    private let defaults = UserDefaults.standard
    private var cancellables: Set<AnyCancellable> = []

    // Observable values - 基本设置
    @Published var isRunning: Bool
    @Published var intervalSeconds: Double
    @Published var notificationMode: NotificationMode

    @Published var notifTitle: String
    @Published var notifBody: String
    @Published var notifEmoji: String

    @Published var lastFireEpoch: Double
    
    // Observable values - 通知样式
    @Published var overlayPosition: OverlayPosition
    @Published var overlayColor: OverlayColor
    @Published var overlayOpacity: Double
    @Published var overlayFadeStartDelay: Double
    @Published var overlayFadeDuration: Double
    
    // 新增样式配置
    @Published var overlayTitleFontSize: Double
    @Published var overlayIconSize: Double
    @Published var overlayCornerRadius: Double
    @Published var overlayEdgePadding: Double
    @Published var overlayContentSpacing: Double
    @Published var overlayUseBlur: Bool
    @Published var overlayBlurIntensity: Double
    @Published var overlayWidth: Double
    @Published var overlayHeight: Double
    @Published var overlayCustomColor: Color
    
    enum NotificationMode: String, CaseIterable {
        case system = "系统通知"
        case overlay = "屏幕遮罩"
    }
    
    enum OverlayPosition: String, CaseIterable {
        case topRight = "右上角"
        case topLeft = "左上角"
        case topCenter = "顶部居中"
        case center = "屏幕中央"
    }
    
    enum OverlayColor: String, CaseIterable {
        case black = "黑色"
        case blue = "蓝色"
        case purple = "紫色"
        case green = "绿色"
        case orange = "橙色"
        case red = "红色"
        case teal = "青色"
        case custom = "自定义"
    }

    init() {
        // Load - 基本设置
        self.isRunning = defaults.object(forKey: Keys.isRunning) as? Bool ?? false
        self.intervalSeconds = defaults.object(forKey: Keys.intervalSeconds) as? Double ?? 1800
        self.notifTitle = defaults.string(forKey: Keys.notifTitle) ?? "提醒"
        self.notifBody = defaults.string(forKey: Keys.notifBody) ?? "起来活动一下～"
        self.notifEmoji = defaults.string(forKey: Keys.notifEmoji) ?? "⏰"
        self.lastFireEpoch = defaults.object(forKey: Keys.lastFire) as? Double ?? 0
        
        let modeRawValue = defaults.string(forKey: Keys.notificationMode) ?? NotificationMode.overlay.rawValue
        self.notificationMode = NotificationMode(rawValue: modeRawValue) ?? .overlay
        
        // Load - 通知样式
        let positionRawValue = defaults.string(forKey: Keys.overlayPosition) ?? OverlayPosition.topRight.rawValue
        self.overlayPosition = OverlayPosition(rawValue: positionRawValue) ?? .topRight
        
        let colorRawValue = defaults.string(forKey: Keys.overlayColor) ?? OverlayColor.black.rawValue
        self.overlayColor = OverlayColor(rawValue: colorRawValue) ?? .black
        
        self.overlayOpacity = defaults.object(forKey: Keys.overlayOpacity) as? Double ?? 0.85
        self.overlayFadeStartDelay = defaults.object(forKey: Keys.overlayFadeStartDelay) as? Double ?? 2.0
        self.overlayFadeDuration = defaults.object(forKey: Keys.overlayFadeDuration) as? Double ?? -1
        
        // Load - 新增样式配置
        self.overlayTitleFontSize = defaults.object(forKey: Keys.overlayTitleFontSize) as? Double ?? 17.0
        self.overlayIconSize = defaults.object(forKey: Keys.overlayIconSize) as? Double ?? 40.0
        self.overlayCornerRadius = defaults.object(forKey: Keys.overlayCornerRadius) as? Double ?? 12.0
        self.overlayEdgePadding = defaults.object(forKey: Keys.overlayEdgePadding) as? Double ?? 20.0
        self.overlayContentSpacing = defaults.object(forKey: Keys.overlayContentSpacing) as? Double ?? 12.0
        self.overlayUseBlur = defaults.object(forKey: Keys.overlayUseBlur) as? Bool ?? false
        self.overlayBlurIntensity = defaults.object(forKey: Keys.overlayBlurIntensity) as? Double ?? 0.5
        self.overlayWidth = defaults.object(forKey: Keys.overlayWidth) as? Double ?? 350.0
        self.overlayHeight = defaults.object(forKey: Keys.overlayHeight) as? Double ?? 120.0
        
        let r = defaults.object(forKey: Keys.overlayCustomColorR) as? Double ?? 0.5
        let g = defaults.object(forKey: Keys.overlayCustomColorG) as? Double ?? 0.5
        let b = defaults.object(forKey: Keys.overlayCustomColorB) as? Double ?? 0.5
        self.overlayCustomColor = Color(red: r, green: g, blue: b)

        // Persist changes - 基本设置
        $isRunning.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.isRunning) }.store(in: &cancellables)
        $intervalSeconds.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.intervalSeconds) }.store(in: &cancellables)
        $notifTitle.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifTitle) }.store(in: &cancellables)
        $notifBody.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifBody) }.store(in: &cancellables)
        $notifEmoji.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifEmoji) }.store(in: &cancellables)
        $lastFireEpoch.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.lastFire) }.store(in: &cancellables)
        $notificationMode.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.notificationMode) }.store(in: &cancellables)
        
        // Persist changes - 通知样式
        $overlayPosition.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayPosition) }.store(in: &cancellables)
        $overlayColor.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayColor) }.store(in: &cancellables)
        $overlayOpacity.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayOpacity) }.store(in: &cancellables)
        $overlayFadeStartDelay.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayFadeStartDelay) }.store(in: &cancellables)
        $overlayFadeDuration.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayFadeDuration) }.store(in: &cancellables)
        
        // Persist changes - 新增样式配置
        $overlayTitleFontSize.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayTitleFontSize) }.store(in: &cancellables)
        $overlayIconSize.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayIconSize) }.store(in: &cancellables)
        $overlayCornerRadius.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayCornerRadius) }.store(in: &cancellables)
        $overlayEdgePadding.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayEdgePadding) }.store(in: &cancellables)
        $overlayContentSpacing.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayContentSpacing) }.store(in: &cancellables)
        $overlayUseBlur.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayUseBlur) }.store(in: &cancellables)
        $overlayBlurIntensity.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayBlurIntensity) }.store(in: &cancellables)
        $overlayWidth.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayWidth) }.store(in: &cancellables)
        $overlayHeight.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayHeight) }.store(in: &cancellables)
        $overlayCustomColor.dropFirst().sink { [weak self] color in
            guard let self else { return }
            let components = color.components()
            self.defaults.set(components.red, forKey: Keys.overlayCustomColorR)
            self.defaults.set(components.green, forKey: Keys.overlayCustomColorG)
            self.defaults.set(components.blue, forKey: Keys.overlayCustomColorB)
        }.store(in: &cancellables)

        // Guardrail: 10秒到2小时
        if intervalSeconds < 10 { intervalSeconds = 10 }
        if intervalSeconds > 7200 { intervalSeconds = 7200 }
        
        // Guardrail: 透明度 0.3 - 1.0
        if overlayOpacity < 0.3 { overlayOpacity = 0.3 }
        if overlayOpacity > 1.0 { overlayOpacity = 1.0 }
    }

    var lastFireDate: Date? {
        guard lastFireEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: lastFireEpoch)
    }

    func markFiredNow() {
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
    
    func getFadeDuration() -> Double {
        if overlayFadeDuration < 0 {
            let remainingTime = intervalSeconds - overlayFadeStartDelay
            return max(remainingTime, 3)
        } else {
            return overlayFadeDuration
        }
    }
    
    func getOverlayColor() -> Color {
        switch overlayColor {
        case .black: return .black
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .teal: return .teal
        case .custom: return overlayCustomColor
        }
    }
}
