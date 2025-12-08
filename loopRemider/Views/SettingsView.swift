//
//  SettingsView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @State private var sendingTest = false
    @State private var inputValue: String = ""
    @State private var selectedUnit: BasicSettingsView.TimeUnit = .minutes
    @State private var selectedCategory: SettingsCategory = .basic
    @State private var countdownText: String = ""
    @State private var progressValue: Double = 0.0
    
    // 定时器 Publisher，每秒触发
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    enum SettingsCategory: String, CaseIterable, Identifiable {
        case basic = "基本设置"
        case style = "通知样式"
        case animation = "动画和定位"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .basic: return "bell.badge.fill"
            case .style: return "paintbrush.pointed.fill"
            case .animation: return "wand.and.stars"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // 左侧导航栏
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(category.rawValue, systemImage: category.icon)
                    .tag(category)
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 180)
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle) // 隐藏折叠按钮
        } detail: {
            // 右侧内容区 - 水平布局
            HStack(alignment: .top, spacing: 24) {
                // 左侧：表单区域（可滚动）
                ScrollView {
                    Group {
                        switch selectedCategory {
                        case .basic:
                            BasicSettingsView(
                                inputValue: $inputValue,
                                selectedUnit: $selectedUnit
                            )
                        case .style:
                            StyleSettingsView()
                        case .animation:
                            AnimationSettingsView()
                        }
                    }
                    .padding(24)
                }
                .frame(width: 500)
                
                // 右侧：预览区域（固定不滚动）
                PreviewSectionView(
                    sendingTest: $sendingTest,
                    countdownText: $countdownText,
                    progressValue: $progressValue
                )
                .frame(width: 450)
                .padding(.top, 24)
                .padding(.trailing, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1200, height: 700)
        .onAppear {
            initializeInputValue()
            // 如果已在运行，立即更新倒计时
            if settings.isRunning {
                updateCountdown()
            }
        }
        .onReceive(timer) { _ in
            // 每秒更新倒计时
            if settings.isRunning {
                updateCountdown()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeInputValue() {
        let seconds = settings.intervalSeconds
        if seconds >= 60 && Int(seconds) % 60 == 0 {
            // 如果是整分钟，默认显示分钟
            selectedUnit = .minutes
            inputValue = String(Int(seconds / 60))
        } else {
            // 否则显示秒
            selectedUnit = .seconds
            inputValue = String(Int(seconds))
        }
    }
    
    private func updateCountdown() {
        guard settings.isRunning else {
            countdownText = ""
            progressValue = 0.0
            return
        }
        
        // 计算下次通知时间
        let now = Date()
        let lastFire = settings.lastFireDate ?? now
        let nextFire = lastFire.addingTimeInterval(settings.intervalSeconds)
        let remaining = nextFire.timeIntervalSince(now)
        
        // 如果已超时或剩余时间小于1秒，显示将立即发送
        if remaining <= 1.0 {
            countdownText = "下次通知：即将发送..."
            progressValue = 1.0
            return
        }
        
        // 计算进度（0-1）
        let elapsed = settings.intervalSeconds - remaining
        progressValue = max(0, min(1.0, elapsed / settings.intervalSeconds))
        
        // 格式化倒计时文本
        let seconds = Int(remaining)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            countdownText = String(format: "下次通知：%d:%02d:%02d", hours, minutes, secs)
        } else if minutes > 0 {
            countdownText = String(format: "下次通知：%d:%02d", minutes, secs)
        } else {
            countdownText = String(format: "下次通知：%d秒", secs)
        }
    }
}
