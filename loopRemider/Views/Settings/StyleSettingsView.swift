//
//  StyleSettingsView.swift
//  loopRemider
//
//  Created by 数源 on 2025/12/8.
//

import SwiftUI

struct StyleSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header - 统一左对齐样式
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.pink.gradient)
                    Text("通知样式")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Text("自定义屏幕遮罩通知外观")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            
            // 样式设置仅在overlay模式下可用
            if settings.notificationMode == .overlay {
                ScrollView {
                    VStack(spacing: 16) {
                        Group {
                            // 颜色
                            colorSection
                            
                            // 透明度
                            opacitySection
                            
                            Divider().padding(.vertical, 4)
                            
                            // 遮罩宽度
                            widthSection
                            
                            // 遮罩高度
                            heightSection
                            
                            Divider().padding(.vertical, 4)
                            
                            // 圆角
                            cornerRadiusSection
                            
                            // 边距
                            edgePaddingSection
                            
                            // 内容间距
                            contentSpacingSection
                            
                            Divider().padding(.vertical, 4)
                            
                            // 标题字号
                            titleFontSizeSection
                            
                            // 文本字号
                            bodyFontSizeSection
                            
                            // 图标大小
                            iconSizeSection
                            
                            Divider().padding(.vertical, 4)
                            
                            // 模糊效果
                            blurSection
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.bottom, 20)
                
                if settings.isRunning {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.orange)
                        Text("请先暂停才能修改样式设置")
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
    }
    
    // MARK: - Setting Sections
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow(icon: "paintpalette.fill", iconColor: .purple, title: "颜色") {
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
    }
    
    private var opacitySection: some View {
        SettingRow(icon: "circle.lefthalf.filled", iconColor: .orange, title: "透明度") {
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
    }
    
    private var widthSection: some View {
        SettingRow(icon: "arrow.left.and.right", iconColor: .blue, title: "宽度") {
            HStack(spacing: 8) {
                Slider(value: $settings.overlayWidth, in: 50...600, step: 10)
                    .disabled(settings.isRunning)
                    .frame(width: 120)
                Text(String(format: "%.0f", settings.overlayWidth))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .frame(width: 50)
            }
        }
    }
    
    private var heightSection: some View {
        SettingRow(icon: "arrow.up.and.down", iconColor: .green, title: "高度") {
            HStack(spacing: 8) {
                Slider(value: $settings.overlayHeight, in: 30...300, step: 10)
                    .disabled(settings.isRunning)
                    .frame(width: 120)
                Text(String(format: "%.0f", settings.overlayHeight))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .frame(width: 50)
            }
        }
    }
    
    private var cornerRadiusSection: some View {
        SettingRow(icon: "square.fill", iconColor: .indigo, title: "圆角") {
            HStack(spacing: 8) {
                Slider(value: $settings.overlayCornerRadius, in: 0...30, step: 2)
                    .disabled(settings.isRunning)
                    .frame(width: 120)
                Text(String(format: "%.0f", settings.overlayCornerRadius))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.indigo)
                    .frame(width: 50)
            }
        }
    }
    
    private var edgePaddingSection: some View {
        SettingRow(icon: "square.and.arrow.up.on.square", iconColor: .teal, title: "边距") {
            HStack(spacing: 8) {
                Slider(value: $settings.overlayEdgePadding, in: 0...100, step: 5)
                    .disabled(settings.isRunning)
                    .frame(width: 120)
                Text(String(format: "%.0f", settings.overlayEdgePadding))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.teal)
                    .frame(width: 50)
            }
        }
    }
    
    private var contentSpacingSection: some View {
        SettingRow(icon: "arrow.left.and.right.square", iconColor: .cyan, title: "内容间距") {
            HStack(spacing: 8) {
                Slider(value: $settings.overlayContentSpacing, in: 4...30, step: 2)
                    .disabled(settings.isRunning)
                    .frame(width: 120)
                Text(String(format: "%.0f", settings.overlayContentSpacing))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.cyan)
                    .frame(width: 50)
            }
        }
    }
    
    private var titleFontSizeSection: some View {
        SettingRow(icon: "textformat.size", iconColor: .red, title: "标题字号") {
            HStack(spacing: 8) {
                Slider(value: $settings.overlayTitleFontSize, in: 12...30, step: 1)
                    .disabled(settings.isRunning)
                    .frame(width: 120)
                Text(String(format: "%.0f", settings.overlayTitleFontSize))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .frame(width: 50)
            }
        }
    }
    
    private var bodyFontSizeSection: some View {
        SettingRow(icon: "text.alignleft", iconColor: .pink, title: "文本字号") {
            HStack(spacing: 8) {
                Slider(value: $settings.overlayBodyFontSize, in: 10...24, step: 1)
                    .disabled(settings.isRunning)
                    .frame(width: 120)
                Text(String(format: "%.0f", settings.overlayBodyFontSize))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.pink)
                    .frame(width: 50)
            }
        }
    }
    
    private var iconSizeSection: some View {
        SettingRow(icon: "star.fill", iconColor: .yellow, title: "图标大小") {
            HStack(spacing: 8) {
                Slider(value: $settings.overlayIconSize, in: 20...80, step: 5)
                    .disabled(settings.isRunning)
                    .frame(width: 120)
                Text(String(format: "%.0f", settings.overlayIconSize))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(.yellow)
                    .frame(width: 50)
            }
        }
    }
    
    private var blurSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow(icon: "camera.filters", iconColor: .purple, title: "模糊效果") {
                Toggle("", isOn: $settings.overlayUseBlur)
                    .toggleStyle(.switch)
                    .disabled(settings.isRunning)
                    .labelsHidden()
            }
            
            if settings.overlayUseBlur {
                SettingRow(icon: "slider.horizontal.3", iconColor: .purple, title: "模糊强度") {
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
        }
    }
}

// MARK: - Setting Row Helper

struct SettingRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack {
            Label {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            content()
        }
        .padding(.vertical, 4)
    }
}
