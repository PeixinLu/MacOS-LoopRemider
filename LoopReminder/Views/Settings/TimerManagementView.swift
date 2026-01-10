//
//  TimerManagementView.swift
//  loopRemider
//
//  计时器管理页面
//

import SwiftUI
import Combine

struct TimerManagementView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController
    
    @State private var expandedTimerID: UUID? = nil
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField: Hashable {
        case timerEmoji(UUID)
        case timerTitle(UUID)
        case timerBody(UUID)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 页面标题
            PageHeader(
                icon: "bell.badge.fill",
                iconColor: .blue,
                title: "计时器管理",
                subtitle: "管理您的循环提醒计时器"
            )
            
            // 内容区域 - 可滚动
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        // 添加计时器按钮
                        addTimerButton
                        
                        // 计时器列表
                        ForEach($settings.timers) { $timer in
                            TimerItemCard(
                                timer: $timer,
                                isExpanded: Binding(
                                    get: { expandedTimerID == timer.id },
                                    set: { isExpanded in
                                        withAnimation(.spring(response: 0.3)) {
                                            if isExpanded {
                                                expandedTimerID = timer.id
                                                // 展开时设置为焦点
                                                settings.focusedTimerID = timer.id
                                            } else {
                                                if expandedTimerID == timer.id {
                                                    expandedTimerID = nil
                                                }
                                            }
                                        }
                                    }
                                ),
                                isFocused: settings.focusedTimerID == timer.id,
                                isRunning: settings.isRunning,
                                onFocus: {
                                    settings.focusedTimerID = timer.id
                                },
                                onDelete: {
                                    deleteTimer(timer)
                                },
                                focusedField: $focusedField
                            )
                        }
                        
                        // 提示信息
                        InfoHint("计时器的颜色配置会优先于\"通知样式\"页的全局颜色配置", color: .blue)
                    }
                    .padding(.bottom, DesignTokens.Spacing.xl)
                    .padding(.trailing, DesignTokens.Spacing.xl)
                    .frame(width: proxy.size.width - DesignTokens.Spacing.xl, alignment: .leading)
                }
            }
        }
        .onAppear {
            // 默认焦点在第一个计时器
            if settings.focusedTimerID == nil, let firstTimer = settings.timers.first {
                settings.focusedTimerID = firstTimer.id
            }
        }
    }
    
    // MARK: - Add Timer Button
    
    private var addTimerButton: some View {
        Button {
            addNewTimer()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                Text("添加新计时器")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        // .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    // MARK: - Helper Methods
    
    private func addNewTimer() {
        let timerNumber = settings.timers.count + 1
        let newTimer = TimerItem(
            emoji: "🔔",
            title: "计时器 \(timerNumber)",
            body: "起来活动一下"
        )
        settings.timers.append(newTimer)
        
        // 自动展开并设置焦点
        withAnimation(.spring(response: 0.3)) {
            expandedTimerID = newTimer.id
            settings.focusedTimerID = newTimer.id
        }
    }
    
    private func deleteTimer(_ timer: TimerItem) {
        // 至少保留一个计时器
        guard settings.timers.count > 1 else {
            return
        }
        
        withAnimation(.spring(response: 0.3)) {
            if let index = settings.timers.firstIndex(where: { $0.id == timer.id }) {
                settings.timers.remove(at: index)
                
                // 如果删除的是焦点计时器，焦点移到第一个
                if settings.focusedTimerID == timer.id {
                    settings.focusedTimerID = settings.timers.first?.id
                }
                
                // 如果删除的是展开的计时器，收起
                if expandedTimerID == timer.id {
                    expandedTimerID = nil
                }
            }
        }
    }
}

// MARK: - Timer Item Card

struct TimerItemCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController
    @Binding var timer: TimerItem
    @Binding var isExpanded: Bool
    var isFocused: Bool
    var isRunning: Bool
    var onFocus: () -> Void
    var onDelete: () -> Void
    var focusedField: FocusState<TimerManagementView.FocusedField?>.Binding
    
    @State private var intervalInputValue: String = ""
    @State private var intervalSelectedUnit: TimeUnit = .minutes
    @State private var restInputValue: String = ""
    @State private var restSelectedUnit: TimeUnit = .minutes
    @State private var selectedColorType: TimerItem.TimerColor.ColorType = .black
    @State private var customColor: Color = .gray
    @State private var countdownText: String = ""
    @State private var progressValue: Double = 0.0
    @State private var timerID: UUID = UUID() // 保存计时器ID，避免访问已删除的timer对象
    
    private let timer2 = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
        VStack(alignment: .leading, spacing: 0) {
            // 折叠状态显示
            collapsedView
            
            // 展开状态显示
            if isExpanded {
                expandedView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadius)
                .fill(isFocused ? Color.blue.opacity(0.05) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadius)
                .strokeBorder(isFocused ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            timerID = timer.id // 初始化时保存ID
            initializeInputValues()
            initializeColorSelection()
        }
    }
    
    // MARK: - Collapsed View
    
    private var collapsedView: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 计时器图标和名称
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(timer.emoji)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timer.displayName)
                            .font(.headline)
                        // 显示关键信息：频率和内容
                        HStack(spacing: 4) {
                            Text(timer.formattedInterval())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(timer.title.isEmpty ? timer.body : timer.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // 休息和自定义颜色标记
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if timer.isRestEnabled {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .help("休息 \(timer.formattedRestInterval())")
                    }
                    
                    if timer.customColor != nil {
                        Circle()
                            .fill(timer.customColor?.toColor() ?? .gray)
                            .frame(width: 10, height: 10)
                            .help("自定义颜色")
                    }
                }
                
                // 启动/停止按钮
                if timer.isContentValid() {
                    Button {
                        toggleTimerRunning()
                    } label: {
                        Image(systemName: isTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(isTimerRunning ? .orange : .green)
                    }
                    .buttonStyle(.plain)
                    .help(isTimerRunning ? "暂停计时器" : "启动计时器")
                }
                
                // 设置按钮（圆形）
                Button {
                    isExpanded.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 28, height: 28)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
                .help("编辑计时器")
            }
            .padding(DesignTokens.Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                onFocus()
            }
            
            // 进度条
            if isTimerRunning {
                GeometryReader { proxy in
                    let clampedProgress = max(0, min(1.0, progressValue))
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green.opacity(0.15))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: proxy.size.width * clampedProgress, height: 3)
                            .animation(.linear(duration: 0.3), value: clampedProgress)
                    }
                }
                .frame(height: 3)
                
                if !countdownText.isEmpty {
                    HStack {
                        Text(countdownText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.sm)
                }
            }
        }
    .onReceive(timer2) { _ in
            // 检查计时器是否仍然存在于数组中（防止删除后仍触发更新导致崩溃）
            guard settings.timers.contains(where: { $0.id == timerID }) else {
                return
            }
            if isTimerRunning {
                updateCountdown()
            }
        }
    }
    
    private var isTimerRunning: Bool {
        timer.isRunning
    }
    
    // MARK: - Expanded View
    
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Divider()
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // 计时器设置标题
                Text("计时器设置")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.secondary)
                
                // 通知内容
                SettingRow(icon: "face.smiling", iconColor: .green, title: "图标") {
                    HStack(spacing: 8) {
                        TextField("", text: $timer.emoji)
                            .textFieldStyle(.roundedBorder)
                            .disabled(settings.isRunning)
                            .focused(focusedField, equals: .timerEmoji(timer.id))
                            .frame(width: 60)
                        
                        Button {
                            // 聚焦到emoji输入框，触发emoji选择器
                            focusedField.wrappedValue = .timerEmoji(timer.id)
                            // 延迟一下再触发，确保聚焦已生效
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NSApp.orderFrontCharacterPalette(nil)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "face.smiling")
                                Text("选择 Emoji")
                            }
                        }
                        .disabled(settings.isRunning)
                    }
                }
                
                SettingRow(icon: "textformat", iconColor: .green, title: "标题") {
                    TextField("通知标题（也作为计时器名称）", text: $timer.title)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: DesignTokens.Layout.formFieldMaxWidth)
                        .disabled(settings.isRunning)
                        .focused(focusedField, equals: .timerTitle(timer.id))
                }
                
                SettingRow(icon: "text.alignleft", iconColor: .green, title: "描述") {
                    TextField("通知内容", text: $timer.body, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...5)
                        .frame(maxWidth: DesignTokens.Layout.formFieldMaxWidth)
                        .disabled(settings.isRunning)
                        .focused(focusedField, equals: .timerBody(timer.id))
                }
                
                // 通知频率
                SettingRow(icon: "timer", iconColor: .blue, title: "通知间隔") {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        TextField("间隔", text: $intervalInputValue, onEditingChanged: { isEditing in
                            if !isEditing {
                                validateAndUpdateInterval()
                            }
                        })
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .disabled(settings.isRunning)
                        .onSubmit {
                            // 按 Return 键时校验
                            validateAndUpdateInterval()
                        }
                        .onChange(of: intervalInputValue) { _, newValue in
                            // 实时验证输入是否为数字
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                intervalInputValue = filtered
                            }
                        }
                        
                        Picker("", selection: $intervalSelectedUnit) {
                            ForEach(TimeUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .disabled(settings.isRunning)
                        .onChange(of: intervalSelectedUnit) { _, _ in
                            validateAndUpdateInterval()
                        }
                        
                        Text(timer.formattedInterval())
                            .font(DesignTokens.Typography.value)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
                
                // 休息一下
                HStack {
                    Text("休息一下")
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $timer.isRestEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(settings.isRunning)
                }
                
                if timer.isRestEnabled {
                    SettingRow(icon: "pause.circle.fill", iconColor: .purple, title: "休息时长") {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            TextField("时长", text: $restInputValue, onEditingChanged: { isEditing in
                                if !isEditing {
                                    validateAndUpdateRestInterval()
                                }
                            })
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .disabled(settings.isRunning)
                            .onSubmit {
                                // 按 Return 键时校验
                                validateAndUpdateRestInterval()
                            }
                            .onChange(of: restInputValue) { _, newValue in
                                // 实时验证输入是否为数字
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered != newValue {
                                    restInputValue = filtered
                                }
                            }
                            
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
                            
                            Text(timer.formattedRestInterval())
                                .font(DesignTokens.Typography.value)
                                .fontWeight(.semibold)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                
                // 颜色配置
                colorConfigSection
                
                // 删除按钮
                if settings.timers.count > 1 {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("删除此计时器")
                        }
                        .frame(maxWidth: DesignTokens.Layout.formFieldMaxWidth)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(settings.isRunning)
                }
                
                if settings.isRunning {
                    LockHint("请先暂停才能修改")
                }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Color Config Section
    
    private var colorConfigSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("通知颜色")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { timer.customColor != nil },
                    set: { enabled in
                        if enabled {
                            // 启用自定义颜色，使用当前全局配置
                            timer.customColor = TimerItem.TimerColor.from(
                                appSettingsColor: settings.overlayColor,
                                customColor: settings.overlayCustomColor
                            )
                            selectedColorType = timer.customColor?.colorType ?? .black
                            if selectedColorType == .custom {
                                customColor = timer.customColor?.toColor() ?? .gray
                            }
                        } else {
                            // 禁用自定义颜色
                            timer.customColor = nil
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(settings.isRunning)
            }
            
            if timer.customColor != nil {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Picker("颜色", selection: $selectedColorType) {
                        ForEach(TimerItem.TimerColor.ColorType.allCases, id: \.self) { colorType in
                            Text(colorType.rawValue).tag(colorType)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(settings.isRunning)
                    .onChange(of: selectedColorType) { _, newValue in
                        updateTimerColor(newValue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if selectedColorType == .custom {
                        ColorPicker("自定义颜色", selection: $customColor)
                            .disabled(settings.isRunning)
                            .onChange(of: customColor) { _, newColor in
                                let components = newColor.components()
                                timer.customColor = TimerItem.TimerColor(
                                    colorType: .custom,
                                    customR: components.red,
                                    customG: components.green,
                                    customB: components.blue
                                )
                            }
                    }
                    
                    InfoHint("此计时器的颜色会优先于\"通知样式\"页的全局颜色", color: .orange)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeInputValues() {
        // 初始化间隔输入
        let intervalSeconds = timer.intervalSeconds
        if intervalSeconds >= 60 && Int(intervalSeconds) % 60 == 0 {
            intervalSelectedUnit = .minutes
            intervalInputValue = String(Int(intervalSeconds / 60))
        } else {
            intervalSelectedUnit = .seconds
            intervalInputValue = String(Int(intervalSeconds))
        }
        
        // 初始化休息输入
        let restSeconds = timer.restSeconds
        if restSeconds >= 60 && Int(restSeconds) % 60 == 0 {
            restSelectedUnit = .minutes
            restInputValue = String(Int(restSeconds / 60))
        } else {
            restSelectedUnit = .seconds
            restInputValue = String(Int(restSeconds))
        }
    }
    
    private func initializeColorSelection() {
        if let timerColor = timer.customColor {
            selectedColorType = timerColor.colorType
            if timerColor.colorType == .custom {
                customColor = timerColor.toColor()
            }
        }
    }
    
    private func validateAndUpdateInterval() {
        guard let value = Double(intervalInputValue), value > 0 else {
            initializeInputValues()
            return
        }
        
        var seconds = value * intervalSelectedUnit.multiplier
        if seconds < 5 { seconds = 5 }
        if seconds > 7200 { seconds = 7200 }
        
        timer.intervalSeconds = seconds
        initializeInputValues()
    }
    
    private func validateAndUpdateRestInterval() {
        guard let value = Double(restInputValue), value > 0 else {
            initializeInputValues()
            return
        }
        
        var seconds = value * restSelectedUnit.multiplier
        if seconds < 5 { seconds = 5 }
        if seconds > 7200 { seconds = 7200 }
        
        timer.restSeconds = seconds
        initializeInputValues()
    }
    
    private func updateTimerColor(_ colorType: TimerItem.TimerColor.ColorType) {
        if colorType == .custom {
            let components = customColor.components()
            timer.customColor = TimerItem.TimerColor(
                colorType: .custom,
                customR: components.red,
                customG: components.green,
                customB: components.blue
            )
        } else {
            timer.customColor = TimerItem.TimerColor(colorType: colorType)
        }
    }
    
    private func toggleTimerRunning() {
        if timer.isRunning {
            // 停止当前计时器
            controller.stopTimer(timer.id, settings: settings)
        } else {
            // 启动当前计时器
            controller.startTimer(timer.id, settings: settings)
        }
    }
    
    private func updateCountdown() {
        guard isTimerRunning else {
            countdownText = ""
            progressValue = 0.0
            return
        }
        
        let now = Date()
        let lastFire = timer.lastFireDate ?? now
        let nextFire = lastFire.addingTimeInterval(timer.intervalSeconds)
        let remaining = nextFire.timeIntervalSince(now)
        
        if remaining <= 1.0 {
            countdownText = "下次通知：即将发送..."
            progressValue = 1.0
            return
        }
        
        let elapsed = timer.intervalSeconds - remaining
        progressValue = max(0, min(1.0, elapsed / timer.intervalSeconds))
        
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

// MARK: - Preview

#Preview {
    TimerManagementView()
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
        .frame(width: 600, height: 700)
}
