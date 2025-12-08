//
//  SettingsView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @State private var sendingTest = false
    @State private var inputValue: String = ""
    @State private var selectedUnit: TimeUnit = .minutes
    @State private var selectedCategory: SettingsCategory = .basic
    
    enum SettingsCategory: String, CaseIterable, Identifiable {
        case basic = "基本设置"
        case style = "通知样式"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .basic: return "bell.badge.fill"
            case .style: return "paintbrush.pointed.fill"
            }
        }
    }
    
    enum TimeUnit: String, CaseIterable {
        case seconds = "秒"
        case minutes = "分钟"
        
        var multiplier: Double {
            switch self {
            case .seconds: return 1
            case .minutes: return 60
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
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
            .toolbar(removing: .sidebarToggle) // 隐藏折叠按钮
        } detail: {
            // 右侧内容区
            ScrollView {
                if selectedCategory == .basic {
                    basicSettingsContent
                        .padding(24)
                } else {
                    styleSettingsContent
                        .padding(.top, 24)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 1000, height: 700)
        .onAppear {
            initializeInputValue()
        }
    }
    
    // MARK: - Basic Settings Tab
    
    private var basicSettingsContent: some View {
        VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue.gradient)
                    Text("提醒设置")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("自定义您的循环提醒")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Start/Stop Toggle Section
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: settings.isRunning ? "play.circle.fill" : "pause.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(settings.isRunning ? .green : .orange)
                                Text(settings.isRunning ? "运行中" : "已暂停")
                                    .font(.headline)
                                    .foregroundStyle(settings.isRunning ? .green : .orange)
                            }
                            Text(settings.isRunning ? "定时提醒已启动" : "点击启动按钮开始提醒")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settings.isRunning },
                            set: { newValue in
                                settings.isRunning = newValue
                                if newValue {
                                    controller.start(settings: settings)
                                } else {
                                    controller.stop()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.large)
                        .labelsHidden()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(settings.isRunning ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(settings.isRunning ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)

                // Notification Mode Section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("通知方式")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.purple)
                    }

                    Picker("", selection: $settings.notificationMode) {
                        ForEach(AppSettings.NotificationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(settings.isRunning)
                    
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.purple.opacity(0.6))
                        Text(settings.notificationMode == .system ? "使用macOS系统通知中心" : "在屏幕右上角显示遮罩通知")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.leading, 24)
                    
                    if settings.isRunning {
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("请先暂停才能修改通知方式")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                        .padding(.leading, 24)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .opacity(settings.isRunning ? 0.6 : 1.0)

                // Frequency Section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("通知频率")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            TextField("输入间隔", text: $inputValue)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .disabled(settings.isRunning)
                                .onChange(of: inputValue) { _, newValue in
                                    updateIntervalFromInput()
                                }
                            
                            Picker("", selection: $selectedUnit) {
                                ForEach(TimeUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                            .disabled(settings.isRunning)
                            .onChange(of: selectedUnit) { _, _ in
                                updateIntervalFromInput()
                            }
                            
                            Spacer()
                            
                            Text(settings.formattedInterval())
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                                .frame(minWidth: 80, alignment: .trailing)
                        }

                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.blue.opacity(0.6))
                            Text("范围：10秒到2小时；建议 15～60 分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.leading, 24)
                        
                        if settings.isRunning {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("请先暂停才能修改频率")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .opacity(settings.isRunning ? 0.6 : 1.0)

                // Notification Content Section
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("通知内容")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "text.bubble.fill")
                            .foregroundStyle(.green)
                    }

                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "textformat")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("标题", text: $settings.notifTitle)
                                .textFieldStyle(.roundedBorder)
                                .disabled(settings.isRunning)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                                .padding(.top, 6)
                            TextField("内容", text: $settings.notifBody, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...5)
                                .disabled(settings.isRunning)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "face.smiling")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("Emoji（显示在标题前）", text: $settings.notifEmoji)
                                .textFieldStyle(.roundedBorder)
                                .disabled(settings.isRunning)
                            Text(settings.notifEmoji.isEmpty ? "🔔" : settings.notifEmoji)
                                .font(.title2)
                                .frame(width: 40)
                        }

                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green.opacity(0.6))
                            Text("Emoji 使用 macOS 的 Apple Color Emoji 字体渲染")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.leading, 24)
                        
                        if settings.isRunning {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text("请先暂停才能修改内容")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .opacity(settings.isRunning ? 0.6 : 1.0)

                Spacer(minLength: 20)
        }
    }
    
    // MARK: - Style Settings Tab
    
    private var styleSettingsContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 24) {
                // 左侧：设置控制
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.title2)
                                .foregroundStyle(.pink.gradient)
                            Text("通知样式")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        Text("自定义屏幕遮罩通知外观")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)
                    
                    // 样式设置仅在overlay模式下可用
                    if settings.notificationMode == .overlay {
                        ScrollView {
                            VStack(spacing: 16) {
                                Group {
                                    // 位置
                                    settingRow(icon: "location.fill", iconColor: .blue, title: "位置") {
                                        Picker("", selection: $settings.overlayPosition) {
                                            ForEach(AppSettings.OverlayPosition.allCases, id: \.self) { position in
                                                Text(position.rawValue).tag(position)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .disabled(settings.isRunning)
                                        .frame(width: 120)
                                    }
                                    
                                    // 颜色
                                    VStack(alignment: .leading, spacing: 8) {
                                        settingRow(icon: "paintpalette.fill", iconColor: .purple, title: "颜色") {
                                            Picker("", selection: $settings.overlayColor) {
                                                ForEach(AppSettings.OverlayColor.allCases, id: \.self) { color in
                                                    Text(color.rawValue).tag(color)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            .disabled(settings.isRunning)
                                            .frame(width: 120)
                                        }
                                        
                                        if settings.overlayColor == .custom {
                                            HStack {
                                                Spacer().frame(width: 28)
                                                ColorPicker("自定义", selection: $settings.overlayCustomColor, supportsOpacity: false)
                                                    .disabled(settings.isRunning)
                                            }
                                        }
                                    }
                                    
                                    // 透明度
                                    settingRow(icon: "circle.lefthalf.filled", iconColor: .orange, title: "透明度") {
                                        HStack(spacing: 8) {
                                            Slider(value: $settings.overlayOpacity, in: 0.3...1.0, step: 0.05)
                                                .disabled(settings.isRunning)
                                                .frame(width: 120)
                                            Text(String(format: "%.0f%%", settings.overlayOpacity * 100))
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.orange)
                                                .frame(width: 50)
                                        }
                                    }
                                    
                                    Divider().padding(.vertical, 4)
                                    
                                    // 遮罩宽度
                                    settingRow(icon: "arrow.left.and.right", iconColor: .blue, title: "宽度") {
                                        HStack(spacing: 8) {
                                            Slider(value: $settings.overlayWidth, in: 200...600, step: 10)
                                                .disabled(settings.isRunning)
                                                .frame(width: 120)
                                            Text(String(format: "%.0f", settings.overlayWidth))
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.blue)
                                                .frame(width: 50)
                                        }
                                    }
                                    
                                    // 遮罩高度
                                    settingRow(icon: "arrow.up.and.down", iconColor: .green, title: "高度") {
                                        HStack(spacing: 8) {
                                            Slider(value: $settings.overlayHeight, in: 80...300, step: 10)
                                                .disabled(settings.isRunning)
                                                .frame(width: 120)
                                            Text(String(format: "%.0f", settings.overlayHeight))
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.green)
                                                .frame(width: 50)
                                        }
                                    }
                                    
                                    // 标题字号
                                    settingRow(icon: "textformat.size", iconColor: .purple, title: "标题字号") {
                                        HStack(spacing: 8) {
                                            Slider(value: $settings.overlayTitleFontSize, in: 12...32, step: 1)
                                                .disabled(settings.isRunning)
                                                .frame(width: 120)
                                            Text(String(format: "%.0f", settings.overlayTitleFontSize))
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.purple)
                                                .frame(width: 50)
                                        }
                                    }
                                    
                                    // 图标大小
                                    settingRow(icon: "face.smiling", iconColor: .orange, title: "图标大小") {
                                        HStack(spacing: 8) {
                                            Slider(value: $settings.overlayIconSize, in: 24...72, step: 2)
                                                .disabled(settings.isRunning)
                                                .frame(width: 120)
                                            Text(String(format: "%.0f", settings.overlayIconSize))
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.orange)
                                                .frame(width: 50)
                                        }
                                    }
                                    
                                    // 圆角
                                    settingRow(icon: "rectangle.roundedtop", iconColor: .teal, title: "圆角") {
                                        HStack(spacing: 8) {
                                            Slider(value: $settings.overlayCornerRadius, in: 0...40, step: 2)
                                                .disabled(settings.isRunning)
                                                .frame(width: 120)
                                            Text(String(format: "%.0f", settings.overlayCornerRadius))
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.teal)
                                                .frame(width: 50)
                                        }
                                    }
                                    
                                    // 边距
                                    settingRow(icon: "arrow.up.left.and.arrow-down.right", iconColor: .red, title: "屏幕边距") {
                                        HStack(spacing: 8) {
                                            Slider(value: $settings.overlayEdgePadding, in: 0...100, step: 5)
                                                .disabled(settings.isRunning)
                                                .frame(width: 120)
                                            Text(String(format: "%.0f", settings.overlayEdgePadding))
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.red)
                                                .frame(width: 50)
                                        }
                                    }
                                    
                                    // 内容间距
                                    settingRow(icon: "arrow.left.and.right", iconColor: .indigo, title: "内容间距") {
                                        HStack(spacing: 8) {
                                            Slider(value: $settings.overlayContentSpacing, in: 4...32, step: 2)
                                                .disabled(settings.isRunning)
                                                .frame(width: 120)
                                            Text(String(format: "%.0f", settings.overlayContentSpacing))
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.indigo)
                                                .frame(width: 50)
                                        }
                                    }
                                    
                                    Divider().padding(.vertical, 4)
                                    
                                    // 模糊背景
                                    settingRow(icon: "camera.filters", iconColor: .cyan, title: "模糊背景") {
                                        Toggle("", isOn: $settings.overlayUseBlur)
                                            .toggleStyle(.switch)
                                            .disabled(settings.isRunning)
                                    }
                                    
                                    // 模糊强度
                                    if settings.overlayUseBlur {
                                        settingRow(icon: "wand.and.stars", iconColor: .purple, title: "模糊强度") {
                                            HStack(spacing: 8) {
                                                Slider(value: $settings.overlayBlurIntensity, in: 0.1...1.0, step: 0.1)
                                                    .disabled(settings.isRunning)
                                                    .frame(width: 120)
                                                Text(String(format: "%.0f%%", settings.overlayBlurIntensity * 100))
                                                    .font(.system(.body, design: .rounded))
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.purple)
                                                    .frame(width: 50)
                                            }
                                        }
                                    }
                                    
                                    Divider().padding(.vertical, 4)
                                    
                                    // 淡化延迟
                                    settingRow(icon: "timer", iconColor: .orange, title: "淡化延迟") {
                                        HStack(spacing: 8) {
                                            Slider(value: $settings.overlayFadeStartDelay, in: 0...10, step: 0.5)
                                                .disabled(settings.isRunning)
                                                .frame(width: 120)
                                            Text(String(format: "%.1f秒", settings.overlayFadeStartDelay))
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.medium)
                                                .foregroundStyle(.orange)
                                                .frame(width: 50)
                                        }
                                    }
                                    
                                    // 淡化时长
                                    VStack(alignment: .leading, spacing: 8) {
                                        settingRow(icon: "clock.badge.checkmark.fill", iconColor: .green, title: "淡化时长") {
                                            if settings.overlayFadeDuration < 0 {
                                                HStack {
                                                    Text("自动")
                                                        .foregroundStyle(.secondary)
                                                    Button("手动") {
                                                        settings.overlayFadeDuration = 10
                                                    }
                                                    .buttonStyle(.bordered)
                                                    .controlSize(.small)
                                                    .disabled(settings.isRunning)
                                                }
                                            } else {
                                                HStack(spacing: 8) {
                                                    Slider(value: $settings.overlayFadeDuration, in: 1...60, step: 1)
                                                        .disabled(settings.isRunning)
                                                        .frame(width: 80)
                                                    Text("\(Int(settings.overlayFadeDuration))秒")
                                                        .font(.system(.body, design: .rounded))
                                                        .fontWeight(.medium)
                                                        .foregroundStyle(.green)
                                                        .frame(width: 40)
                                                    Button("自动") {
                                                        settings.overlayFadeDuration = -1
                                                    }
                                                    .buttonStyle(.bordered)
                                                    .controlSize(.small)
                                                    .disabled(settings.isRunning)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        .frame(maxHeight: .infinity)
                        
                        if settings.isRunning {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.orange)
                                Text("请先暂停才能修改样式")
                                    .font(.callout)
                                    .foregroundStyle(.orange)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }
                    } else {
                        // 系统通知模式提示
                        VStack(spacing: 12) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("仅在屏幕遮罩模式下可用")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("请在基本设置中将通知方式改为屏幕遮罩")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                    }
                }
                .frame(width: 500)
                
                // 右侧：实时预览
                if settings.notificationMode == .overlay {
                    VStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "eye.fill")
                                    .foregroundStyle(.blue)
                                Text("实时预览")
                                    .font(.headline)
                            }
                            
                            // 预览容器
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                                
                                // 预览通知
                                OverlayNotificationView(
                                    emoji: settings.notifEmoji.isEmpty ? "⏰" : settings.notifEmoji,
                                    title: settings.notifTitle.isEmpty ? "提醒" : settings.notifTitle,
                                    message: settings.notifBody.isEmpty ? "起来活动一下～" : settings.notifBody,
                                    backgroundColor: settings.getOverlayColor(),
                                    backgroundOpacity: settings.overlayOpacity,
                                    fadeStartDelay: 999,
                                    fadeDuration: 1,
                                    titleFontSize: settings.overlayTitleFontSize,
                                    iconSize: settings.overlayIconSize,
                                    cornerRadius: settings.overlayCornerRadius,
                                    contentSpacing: settings.overlayContentSpacing,
                                    useBlur: settings.overlayUseBlur,
                                    blurIntensity: settings.overlayBlurIntensity,
                                    overlayWidth: settings.overlayWidth,
                                    overlayHeight: settings.overlayHeight,
                                    onDismiss: {}
                                )
                                .scaleEffect(0.7)
                            }
                            .frame(width: 380, height: 400)
                            
                            Text("实际显示效果可能因系统设置而略有不同")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 测试按钮移到这里
                        Button {
                            sendingTest = true
                            Task {
                                await controller.sendTest(settings: settings)
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                sendingTest = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if sendingTest {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.caption)
                                }
                                Text(sendingTest ? "发送中..." : "发送测试通知")
                                    .font(.callout)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(sendingTest)
                        .frame(width: 380)
                        
                        Spacer()
                    }
                    .frame(width: 400)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func settingRow<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Label {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            content()
        }
        .padding(.vertical, 4)
    }
    
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
    
    private func updateIntervalFromInput() {
        guard let value = Double(inputValue), value > 0 else {
            return
        }
        
        var seconds = value * selectedUnit.multiplier
        
        // 自动修正：小于10秒则设为10秒
        if seconds < 10 {
            seconds = 10
            // 更新输入框显示
            if selectedUnit == .seconds {
                inputValue = "10"
            } else {
                inputValue = String(format: "%.1f", 10 / 60.0)
            }
        }
        
        // 限制范围：10秒到7200秒(2小时)
        if seconds >= 10 && seconds <= 7200 {
            settings.intervalSeconds = seconds
        }
    }
}
