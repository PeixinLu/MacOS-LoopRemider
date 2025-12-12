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
            case .seconds:
                return 1
            case .minutes:
                return 60
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header - 统一左对齐样式
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "bell.badge.fill").font(.system(size: 28)).foregroundStyle(.blue.gradient)
                    Text("提醒设置").font(.title3).fontWeight(.semibold)
                }
                Text("自定义您的循环提醒").font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 12)

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
        }.onAppear(perform: initializeRestInputValue)
    }

    // MARK: - Notification Content Section

    private var notificationContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("通知内容").font(.headline)
            } icon: {
                Image(systemName: "text.bubble.fill").foregroundStyle(.green)
            }

            VStack(spacing: 12) {
                // 标题
                HStack(spacing: 8) {
                    Text("标题").font(.subheadline).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
                    TextField("输入标题", text: $settings.notifTitle).textFieldStyle(.roundedBorder).disabled(settings.isRunning)
                }

                // 描述/内容
                HStack(alignment: .top, spacing: 8) {
                    Text("描述").font(.subheadline).foregroundStyle(.secondary).frame(width: 60, alignment: .leading).padding(.top, 6)
                    TextField("输入描述内容", text: $settings.notifBody, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2 ... 5).disabled(settings.isRunning)
                }

                // Emoji图标
                HStack(spacing: 8) {
                    Text("图标").font(.subheadline).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
                    TextField("Emoji（显示在标题前）", text: $settings.notifEmoji)
                        .textFieldStyle(.roundedBorder)
                        .disabled(settings.isRunning)
                    
                    Button {
                        NSApp.orderFrontCharacterPalette(nil) // 打开系统表情/符号面板
                    } label: {
                        Image(systemName: "face.smiling.fill")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.borderless)
                    .help("打开系统表情与符号面板")
                }

                HStack {
                    Image(systemName: "info.circle.fill").font(.caption).foregroundStyle(.green.opacity(0.6))
                    Text("Emoji 使用 macOS 的 Apple Color Emoji 字体渲染").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }.padding(.leading, 24)

                if settings.isRunning {
                    HStack {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.orange)
                        Text("请先暂停才能修改内容").font(.caption).foregroundStyle(.orange)
                        Spacer()
                    }.padding(.leading, 24)
                }
            }
        }.padding(16).background(
            RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)).shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        ).opacity(settings.isRunning ? 0.6: 1.0)
    }

    // MARK: - Notification Interval Section

    private var notificationIntervalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("通知频率").font(.headline)
            } icon: {
                Image(systemName: "clock.fill").foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "timer").foregroundStyle(.secondary).frame(width: 20)

                    TextField("输入间隔", text: $inputValue, onEditingChanged: {
                        isEditing in
                        if !isEditing {
                            validateAndUpdateInterval()
                        }
                    }).textFieldStyle(.roundedBorder).frame(width: 100).disabled(settings.isRunning)

                    Picker("", selection: $selectedUnit) {
                        ForEach(TimeUnit.allCases, id: \.self) {
                            unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }.pickerStyle(.segmented).frame(width: 120).disabled(settings.isRunning).onChange(of: selectedUnit) {
                        _, _ in
                        validateAndUpdateInterval()
                    }

                    Spacer()

                    Text(settings.formattedInterval()).font(.system(.body, design: .rounded)).fontWeight(.semibold).foregroundStyle(.blue).frame(minWidth: 80, alignment: .trailing)
                }

                // ... existing code ...
                // 范围验证提示
                if let validationMessage = getIntervalValidationMessage() {
                    HStack(spacing: 6) {
                        Image(systemName: validationMessage.isWarning ? "exclamationmark.circle.fill": "checkmark.circle.fill").font(.caption).foregroundStyle(validationMessage.isWarning ? .orange: .green)
                        Text(validationMessage.text).font(.caption).foregroundStyle(validationMessage.isWarning ? .orange: .green)
                        Spacer()
                    }.padding(.leading, 24)
                }

                HStack {
                    Image(systemName: "info.circle.fill").font(.caption).foregroundStyle(.blue.opacity(0.6))
                    Text("范围：5秒到2小时；建议 15～60 分钟").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }.padding(.leading, 24)

                if settings.isRunning {
                    HStack {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.orange)
                        Text("请先暂停才能修改频率").font(.caption).foregroundStyle(.orange)
                        Spacer()
                    }.padding(.leading, 24)
                }
            }
        }.padding(16).background(
            RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)).shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        ).opacity(settings.isRunning ? 0.6: 1.0)
    }

    // MARK: - Rest Section

    private var restSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text("休息一下").font(.headline)
                } icon: {
                    Image(systemName: "powersleep").foregroundStyle(.purple)
                }

                Spacer()

                Toggle("", isOn: $settings.isRestEnabled).labelsHidden().toggleStyle(.switch).disabled(settings.isRunning)
            }

            VStack(spacing: 8) {
                if settings.isRestEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "timer").foregroundStyle(.secondary).frame(width: 20)

                        TextField("输入时长", text: $restInputValue, onEditingChanged: {
                            isEditing in
                            if !isEditing {
                                validateAndUpdateRestInterval()
                            }
                        }).textFieldStyle(.roundedBorder).frame(width: 100).disabled(settings.isRunning)

                        Picker("", selection: $restSelectedUnit) {
                            ForEach(TimeUnit.allCases, id: \.self) {
                                unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }.pickerStyle(.segmented).frame(width: 120).disabled(settings.isRunning).onChange(of: restSelectedUnit) {
                            _, _ in
                            validateAndUpdateRestInterval()
                        }

                        Spacer()

                        Text(settings.formattedRestInterval()).font(.system(.body, design: .rounded)).fontWeight(.semibold).foregroundStyle(.purple).frame(minWidth: 80, alignment: .trailing)
                    }.padding(.top, 4)
                    
                    // ... existing code ...
                    // 范围验证提示
                    if let validationMessage = getRestIntervalValidationMessage() {
                        HStack(spacing: 6) {
                            Image(systemName: validationMessage.isWarning ? "exclamationmark.circle.fill": "checkmark.circle.fill").font(.caption).foregroundStyle(validationMessage.isWarning ? .orange: .green)
                            Text(validationMessage.text).font(.caption).foregroundStyle(validationMessage.isWarning ? .orange: .green)
                            Spacer()
                        }.padding(.leading, 24)
                    }
                }

                HStack {
                    Image(systemName: "info.circle.fill").font(.caption).foregroundStyle(.purple.opacity(0.6))
                    Text("手动关闭通知时触发休息，休息时间内计时器暂停，休息完毕后继续计时").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }.padding(.leading, 24)

                if settings.isRunning {
                    HStack {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.orange)
                        Text("请先暂停才能修改").font(.caption).foregroundStyle(.orange)
                        Spacer()
                    }.padding(.leading, 24)
                }
            }
        }.padding(16).background(
            RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)).shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        ).opacity(settings.isRunning ? 0.6: 1.0)
    }

    // MARK: - Launch Settings Section

    private var launchSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("启动设置").font(.headline)
            } icon: {
                Image(systemName: "power").foregroundStyle(.orange)
            }

            VStack(spacing: 8) {
                // 开机启动 - 使用 LaunchAtLogin 包
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "power.circle.fill").foregroundStyle(.orange).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("开机启动").font(.subheadline).fontWeight(.medium)
                            Text("系统启动时自动运行此应用").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    LaunchAtLogin.Toggle().labelsHidden().toggleStyle(.switch)
                }

                Divider()

                // 静默启动
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash.fill").foregroundStyle(.gray).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("静默启动").font(.subheadline).fontWeight(.medium)
                            Text("启动时不自动打开设置页面").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Toggle("", isOn: $settings.silentLaunch).labelsHidden().toggleStyle(.switch)
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.rotation").foregroundStyle(.blue).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("从锁屏唤醒后重新计时").font(.subheadline).fontWeight(.medium)
                            Text("锁屏超过 5 分钟重新进入系统时，自动重置计时器").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Toggle("", isOn: $settings.resetOnWakeEnabled).labelsHidden().toggleStyle(.switch)
                }
            }
        }.padding(16).background(
            RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)).shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }

    // MARK: - Notification Mode Section

    private var notificationModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text("通知方式").font(.headline)
                } icon: {
                    Image(systemName: "bell.badge.fill").foregroundStyle(.purple)
                }

                Spacer()

                Picker("", selection: $settings.notificationMode) {
                    ForEach(AppSettings.NotificationMode.allCases, id: \.self) {
                        mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }.pickerStyle(.segmented).disabled(settings.isRunning)
            }

            HStack {
                Image(systemName: "info.circle.fill").font(.caption).foregroundStyle(.purple.opacity(0.6))
                Text(settings.notificationMode == .system ? "使用macOS系统通知中心": "在屏幕右上角显示遮罩通知").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding(.leading, 24)

            // 系统通知模式下的提示文本
            if settings.notificationMode == .system {
                VStack(alignment: .leading, spacing: 8) {
                    // 第一个提示
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge").font(.caption).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("提醒将发送到控制中心。需确保开启了通知权限").font(.caption).foregroundStyle(.secondary)
                            Button(action: openNotificationSettings) {
                                Text("[前往配置]").font(.caption).foregroundStyle(.blue)
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    Divider().padding(.vertical, 4)

                    HStack(spacing: 8) {
                        Image(systemName: "palette").font(.caption).foregroundStyle(.orange)
                        Text("系统通知模式下。配置的外观无法生效。").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "palette").font(.caption).foregroundStyle(.orange)
                        Text("推荐使用遮罩通知！由于macOS的通知机制，内容相似的通知将会被合并在一起，被静默收在通知中心，不会弹出，导致漏接通知提醒。").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                }.padding(10).background(Color.orange.opacity(0.08)).cornerRadius(8).padding(.leading, 24).padding(.trailing, 16)
            }

            if settings.isRunning {
                HStack {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.orange)
                    Text("请先暂停才能修改通知方式").font(.caption).foregroundStyle(.orange)
                    Spacer()
                }.padding(.leading, 24)
            }
        }.padding(16).background(
            RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)).shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        ).opacity(settings.isRunning ? 0.6: 1.0)
    }

    // MARK: - Helper Methods

    private func openNotificationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }

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
        if seconds < 5 {
            seconds = 5
        }
        if seconds > 7200 {
            seconds = 7200
        }

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
        if seconds < 5 {
            seconds = 5
        }
        if seconds > 7200 {
            seconds = 7200
        }

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

    // MARK: - Validation Message

    private struct ValidationMessage {
        let text: String
        let isWarning: Bool
    }

    private func getIntervalValidationMessage() -> ValidationMessage? {
        guard let value = Double(inputValue), value > 0 else {
            return nil
        }
            
        let seconds = value * selectedUnit.multiplier
            
        if seconds < 5 {
            return ValidationMessage(
                text: "⚠ 低于最小值 5 秒，已自动调整为 5 秒",
                isWarning: true
            )
        } else if seconds > 7200 {
            return ValidationMessage(
                text: "⚠ 超过最大值 2 小时，已自动调整为 2 小时",
                isWarning: true
            )
        } else if seconds >= 900 && seconds <= 3600 {
            return ValidationMessage(
                text: "✓ 在建议范围内",
                isWarning: false
            )
        }
            
        return nil
    }
        
    private func getRestIntervalValidationMessage() -> ValidationMessage? {
        guard let value = Double(restInputValue), value > 0 else {
            return nil
        }
            
        let seconds = value * restSelectedUnit.multiplier
            
        if seconds < 5 {
            return ValidationMessage(
                text: "⚠ 低于最小值 5 秒，已自动调整为 5 秒",
                isWarning: true
            )
        } else if seconds > 7200 {
            return ValidationMessage(
                text: "⚠ 超过最大值 2 小时，已自动调整为 2 小时",
                isWarning: true
            )
        } else if seconds >= 60 && seconds <= 900 {
            return ValidationMessage(
                text: "✓ 休息时间合理",
                isWarning: false
            )
        }
            
        return nil
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
