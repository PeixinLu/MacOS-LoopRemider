//
//  BasicSettingsView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI
import LaunchAtLogin

struct BasicSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    
    @Binding var inputValue: String
    @Binding var selectedUnit: TimeUnit

    @State private var restInputValue: String = ""
    @State private var restSelectedUnit: TimeUnit = .minutes

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
        VStack(spacing: 20) {
            // Header - 统一左对齐样式
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue.gradient)
                    Text("提醒设置")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Text("自定义您的循环提醒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            // 1. 通知内容 Section
            notificationContentSection
            
            // 2. 通知频率 Section
            notificationIntervalSection

            // 2.1 休息一下 Section
            restSection

            // 2.5 启动设置 Section
            launchSettingsSection
            
            // 3. 通知方式 Section
            notificationModeSection

            Spacer(minLength: 20)
        }
        .onAppear(perform: initializeRestInputValue)
    }
    
    // MARK: - Notification Content Section
    
    private var notificationContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("通知内容")
                    .font(.headline)
            } icon: {
                Image(systemName: "text.bubble.fill")
                    .foregroundStyle(.green)
            }

            VStack(spacing: 12) {
                // 标题
                HStack(spacing: 8) {
                    Text("标题")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("输入标题", text: $settings.notifTitle)
                        .textFieldStyle(.roundedBorder)
                        .disabled(settings.isRunning)
                }

                // 描述/内容
                HStack(alignment: .top, spacing: 8) {
                    Text("描述")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                        .padding(.top, 6)
                    TextField("输入描述内容", text: $settings.notifBody, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...5)
                        .disabled(settings.isRunning)
                }

                // Emoji图标
                HStack(spacing: 8) {
                    Text("图标")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("Emoji（显示在标题前）", text: $settings.notifEmoji)
                        .textFieldStyle(.roundedBorder)
                        .disabled(settings.isRunning)
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
    }
    
    // MARK: - Notification Interval Section
    
    private var notificationIntervalSection: some View {
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
                    
                    TextField("输入间隔", text: $inputValue, onEditingChanged: { isEditing in
                        if !isEditing {
                            validateAndUpdateInterval()
                        }
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .disabled(settings.isRunning)

                    Picker("", selection: $selectedUnit) {
                        ForEach(TimeUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .disabled(settings.isRunning)
                    .onChange(of: selectedUnit) { _, _ in
                        validateAndUpdateInterval()
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
                    Text("范围：5秒到2小时；建议 15～60 分钟")
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
    }

    // MARK: - Rest Section

    private var restSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("休息一下")
                    .font(.headline)
            } icon: {
                Image(systemName: "powersleep")
                    .foregroundStyle(.purple)
            }

            VStack(spacing: 8) {
                Toggle(isOn: $settings.isRestEnabled) {
                    Text("在每个通知之间插入一段休息时间")
                        .font(.subheadline)
                }
                .disabled(settings.isRunning)

                if settings.isRestEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        TextField("输入时长", text: $restInputValue, onEditingChanged: { isEditing in
                            if !isEditing {
                                validateAndUpdateRestInterval()
                            }
                        })
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .disabled(settings.isRunning)

                        Picker("", selection: $restSelectedUnit) {
                            ForEach(TimeUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .disabled(settings.isRunning)
                        .onChange(of: restSelectedUnit) { _, _ in
                            validateAndUpdateRestInterval()
                        }

                        Spacer()

                        Text(settings.formattedRestInterval())
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.purple)
                            .frame(minWidth: 80, alignment: .trailing)
                    }
                    .padding(.top, 4)
                }

                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.purple.opacity(0.6))
                    Text("休息期间，计时器将暂停")
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
                        Text("请先暂停才能修改")
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
    }
    
    // MARK: - Launch Settings Section
    
    private var launchSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("启动设置")
                    .font(.headline)
            } icon: {
                Image(systemName: "power")
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 8) {
                // 开机启动 - 使用 LaunchAtLogin 包
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "power.circle.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("开机启动")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("系统启动时自动运行此应用")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    LaunchAtLogin.Toggle()
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                
                Divider()
                
                // 静默启动
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("静默启动")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("启动时不自动打开设置页面")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Toggle("", isOn: $settings.silentLaunch)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
    
    // MARK: - Notification Mode Section
    
    private var notificationModeSection: some View {
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
    }
    
    // MARK: - Helper Methods

    private func initializeRestInputValue() {
        let seconds = settings.restSeconds
        if seconds >= 60 && Int(seconds) % 60 == 0 {
            restSelectedUnit = .minutes
            restInputValue = String(Int(seconds / 60))
        } else {
            restSelectedUnit = .seconds
            restInputValue = String(Int(seconds))
        }
    }

    private func validateAndUpdateInterval() {
        guard let value = Double(inputValue), value > 0 else {
            // 如果输入无效，恢复为当前设置的值
            initializeInputValue()
            return
        }
        
        var seconds = value * selectedUnit.multiplier

        // 限制范围：5秒到7200秒(2小时)
        if seconds < 5 { seconds = 5 }
        if seconds > 7200 { seconds = 7200 }

        settings.intervalSeconds = seconds

        // 更新输入框以反映修正后的值
        initializeInputValue()
    }

    private func validateAndUpdateRestInterval() {
        guard let value = Double(restInputValue), value > 0 else {
            // 如果输入无效，恢复为当前设置的值
            initializeRestInputValue()
            return
        }

        var seconds = value * restSelectedUnit.multiplier

        // 限制范围：5秒到7200秒(2小时)
        if seconds < 5 { seconds = 5 }
        if seconds > 7200 { seconds = 7200 }

        settings.restSeconds = seconds

        // 更新输入框以反映修正后的值
        initializeRestInputValue()
    }

    private func initializeInputValue() {
        let seconds = settings.intervalSeconds
        if seconds >= 60 && Int(seconds) % 60 == 0 {
            selectedUnit = .minutes
            inputValue = String(Int(seconds / 60))
        } else {
            selectedUnit = .seconds
            inputValue = String(Int(seconds))
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var inputValue = "30"
    @Previewable @State var selectedUnit = BasicSettingsView.TimeUnit.seconds
    
    BasicSettingsView(
        inputValue: $inputValue,
        selectedUnit: $selectedUnit
    )
    .environmentObject(AppSettings())
    .frame(width: 600)
    .padding()
}
